import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'm3u8_service.dart';

/// TV Exo 专用的 M3U8 清单代理服务。
///
/// 该服务只代理播放清单本身，不代理媒体分片数据：
/// 1. 先拉取远端 M3U8 清单。
/// 2. 过滤广告标签与明确的广告片段块。
/// 3. 将嵌套的子清单地址改写回本地代理，保证多级 M3U8 继续经过过滤。
/// 4. 普通分片、密钥和初始化片段则直接改写为绝对远端地址，由 Exo 自己去拉流。
class TvExoM3u8ProxyService {
  /// 私有构造，统一走单例。
  TvExoM3u8ProxyService._();

  /// 全局单例。
  static final TvExoM3u8ProxyService instance = TvExoM3u8ProxyService._();

  /// 会话保活时间，避免播放器长时间不用后还持有旧请求上下文。
  static const Duration _sessionTtl = Duration(minutes: 30);

  /// 用于改写标签内 URI 属性的正则。
  static final RegExp _uriAttributePattern =
      RegExp(r'URI=["\x27]([^"\x27]+)["\x27]');

  /// 远端清单拉取客户端。
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
      followRedirects: true,
      validateStatus: (status) => status != null && status >= 200 && status < 400,
    ),
  );

  /// 当前本地代理服务实例。
  HttpServer? _server;

  /// 当前本地代理根地址。
  Uri? _baseUri;

  /// 自增会话号。
  int _nextSessionId = 0;

  /// 当前有效的代理会话。
  final Map<String, _TvExoM3u8ProxySession> _sessions =
      <String, _TvExoM3u8ProxySession>{};

  /// 为 Exo 解析最终可播放地址。
  ///
  /// 只有在开启自动去广告且地址看起来像 M3U8 清单时，才切到本地代理链路；
  /// 其它地址保持原样，避免额外增加 Dart 层转发开销。
  Future<String> resolvePlaybackUrl({
    required String url,
    required bool adFilterEnabled,
    Map<String, String>? headers,
  }) async {
    if (!adFilterEnabled || !M3U8Service.looksLikeM3u8Url(url)) {
      return url;
    }

    try {
      await _ensureServerStarted();
      _cleanupExpiredSessions();
      final sessionToken = _createSessionToken();
      _sessions[sessionToken] = _TvExoM3u8ProxySession(
        headers: Map<String, String>.from(headers ?? const <String, String>{}),
        createdAt: DateTime.now(),
      );
      return _buildProxyUri(
        token: sessionToken,
        targetUrl: url,
      ).toString();
    } catch (error) {
      debugPrint('TV Exo M3U8 代理初始化失败，回退原地址: $error');
      return url;
    }
  }

  /// 重置本地代理，供测试隔离使用。
  @visibleForTesting
  Future<void> debugReset() async {
    final server = _server;
    _server = null;
    _baseUri = null;
    _sessions.clear();
    _nextSessionId = 0;
    if (server != null) {
      await server.close(force: true);
    }
  }

  /// 确保本地代理服务已经启动。
  Future<void> _ensureServerStarted() async {
    if (_server != null && _baseUri != null) {
      return;
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _baseUri = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );
    unawaited(_serveRequests(server));
  }

  /// 后台循环处理 Exo 发来的清单请求。
  Future<void> _serveRequests(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handleRequest(request));
      }
    } catch (error) {
      // 服务关闭时会自然结束监听，这里只保留调试日志，不向上抛异常。
      debugPrint('TV Exo M3U8 代理监听结束: $error');
    }
  }

  /// 处理单次清单请求。
  Future<void> _handleRequest(HttpRequest request) async {
    _cleanupExpiredSessions();

    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    final token = request.uri.queryParameters['token'];
    final targetUrl = request.uri.queryParameters['url'];
    if (token == null || token.isEmpty || targetUrl == null || targetUrl.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final session = _sessions[token];
    if (session == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final upstream = await _dio.get<String>(
        targetUrl,
        options: Options(
          method: request.method,
          headers: session.headers,
        ),
      );

      final contentType = upstream.headers.value(Headers.contentTypeHeader);
      if (contentType != null && contentType.isNotEmpty) {
        request.response.headers.contentType = ContentType.parse(contentType);
      } else {
        request.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl');
      }

      request.response.statusCode = HttpStatus.ok;
      if (request.method == 'HEAD') {
        await request.response.close();
        return;
      }

      final manifestContent = upstream.data?.toString() ?? '';
      final filteredManifest = M3U8Service.filterAdsFromM3U8(
        manifestContent,
        targetUrl,
      );
      final proxiedManifest = _rewriteManifestUris(
        manifestContent: filteredManifest,
        manifestUrl: targetUrl,
        token: token,
      );

      request.response.write(proxiedManifest);
      await request.response.close();
    } catch (error) {
      request.response.statusCode = HttpStatus.badGateway;
      request.response.write('proxy_error:$error');
      await request.response.close();
    }
  }

  /// 把清单里的子清单地址继续改写回本地代理。
  ///
  /// 这样 Exo 在继续请求多级 M3U8 时，仍能经过同一套广告过滤逻辑。
  String _rewriteManifestUris({
    required String manifestContent,
    required String manifestUrl,
    required String token,
  }) {
    final lines = manifestContent.split('\n');
    final rewrittenLines = <String>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        rewrittenLines.add(line);
        continue;
      }

      if (trimmedLine.startsWith('#')) {
        rewrittenLines.add(
          _rewriteTagUriAttributes(
            line: line,
            baseUrl: manifestUrl,
            token: token,
          ),
        );
        continue;
      }

      final resolvedUrl = M3U8Service.resolveUrl(trimmedLine, manifestUrl);
      if (M3U8Service.looksLikeM3u8Url(resolvedUrl)) {
        rewrittenLines.add(
          _buildProxyUri(token: token, targetUrl: resolvedUrl).toString(),
        );
      } else {
        rewrittenLines.add(resolvedUrl);
      }
    }

    return rewrittenLines.join('\n');
  }

  /// 改写标签内的 `URI="..."` 属性。
  ///
  /// 子清单继续走代理；密钥和初始化片段仍保留绝对远端地址。
  String _rewriteTagUriAttributes({
    required String line,
    required String baseUrl,
    required String token,
  }) {
    final match = _uriAttributePattern.firstMatch(line);
    if (match == null) {
      return line;
    }

    final rawUri = match.group(1)!;
    final resolvedUrl = M3U8Service.resolveUrl(rawUri, baseUrl);
    final shouldProxyNestedManifest =
        !line.contains('#EXT-X-KEY') &&
            !line.contains('#EXT-X-MAP') &&
            M3U8Service.looksLikeM3u8Url(resolvedUrl);

    final replacement = shouldProxyNestedManifest
        ? _buildProxyUri(token: token, targetUrl: resolvedUrl).toString()
        : resolvedUrl;
    return line.replaceFirst(rawUri, replacement);
  }

  /// 构建本地代理入口地址。
  Uri _buildProxyUri({
    required String token,
    required String targetUrl,
  }) {
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw StateError('TV Exo M3U8 代理尚未启动');
    }
    return baseUri.replace(
      path: '/manifest',
      queryParameters: <String, String>{
        'token': token,
        'url': targetUrl,
      },
    );
  }

  /// 生成新的会话标识。
  String _createSessionToken() {
    _nextSessionId++;
    return 'session_${DateTime.now().microsecondsSinceEpoch}_$_nextSessionId';
  }

  /// 清理过期的代理会话。
  void _cleanupExpiredSessions() {
    final now = DateTime.now();
    _sessions.removeWhere((_, session) {
      return now.difference(session.createdAt) >= _sessionTtl;
    });
  }
}

/// 单次 Exo 清单代理会话。
class _TvExoM3u8ProxySession {
  /// 创建清单代理会话。
  const _TvExoM3u8ProxySession({
    required this.headers,
    required this.createdAt,
  });

  /// 拉取远端清单时需要透传的请求头。
  final Map<String, String> headers;

  /// 会话创建时间。
  final DateTime createdAt;
}
