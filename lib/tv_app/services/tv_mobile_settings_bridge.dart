import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// TV 手机端配置草稿。
///
/// 负责承载 TV 设置页里适合用手机录入的核心字段。
class TvMobileSettingsDraft {
  /// 创建 TV 手机端配置草稿。
  const TvMobileSettingsDraft({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.doubanImageSource,
    required this.adFilterEnabled,
    required this.danmakuBaseApi,
  });

  /// TV 端支持的图片代理选项。
  static const List<String> availableDoubanImageSources = <String>[
    '直连',
    '豆瓣官方精品 CDN',
    '豆瓣 CDN By CMLiussss（腾讯云）',
    '豆瓣 CDN By CMLiussss（阿里云）',
  ];

  /// 空草稿。
  factory TvMobileSettingsDraft.empty() {
    return const TvMobileSettingsDraft(
      serverUrl: '',
      username: '',
      password: '',
      doubanImageSource: '直连',
      adFilterEnabled: true,
      danmakuBaseApi: '',
    );
  }

  /// 服务器地址。
  final String serverUrl;

  /// 登录账号。
  final String username;

  /// 登录密码。
  final String password;

  /// 图片代理显示名称。
  final String doubanImageSource;

  /// 是否开启自动去广告。
  final bool adFilterEnabled;

  /// 弹幕服务器地址。
  final String danmakuBaseApi;

  /// 将当前草稿转成网页表单可直接消费的字段值。
  Map<String, String> toFormFields() {
    return <String, String>{
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'doubanImageSource': doubanImageSource,
      'adFilterEnabled': adFilterEnabled ? 'true' : 'false',
      'danmakuBaseApi': danmakuBaseApi,
    };
  }

  /// 根据手机网页提交的表单字段重建草稿。
  factory TvMobileSettingsDraft.fromFormFields(Map<String, String> fields) {
    final imageSource = fields['doubanImageSource']?.trim() ?? '直连';
    return TvMobileSettingsDraft(
      serverUrl: fields['serverUrl']?.trim() ?? '',
      username: fields['username']?.trim() ?? '',
      password: fields['password'] ?? '',
      doubanImageSource: availableDoubanImageSources.contains(imageSource)
          ? imageSource
          : '直连',
      adFilterEnabled: _parseBool(fields['adFilterEnabled']),
      danmakuBaseApi: fields['danmakuBaseApi']?.trim() ?? '',
    );
  }

  /// 解析表单中的布尔值。
  static bool _parseBool(String? rawValue) {
    final normalized = (rawValue ?? '').trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'on';
  }
}

/// TV 手机配置桥接会话。
///
/// 设置页通过它拿到二维码链接、实时状态文案以及草稿同步能力。
class TvMobileSettingsBridgeSession {
  /// 创建 TV 手机配置桥接会话。
  const TvMobileSettingsBridgeSession({
    required this.shareUri,
    required this.statusNotifier,
    required this.updateDraft,
    required this.dispose,
  });

  /// 手机扫码后打开的局域网地址。
  final Uri? shareUri;

  /// 当前会话状态文案。
  final ValueNotifier<String> statusNotifier;

  /// 把 TV 当前草稿同步给手机网页。
  final ValueChanged<TvMobileSettingsDraft> updateDraft;

  /// 关闭会话并释放底层资源。
  final Future<void> Function() dispose;
}

/// TV 手机配置桥接服务。
///
/// 负责在局域网里起一个轻量网页，让手机扫码后填写配置并回传给电视。
class TvMobileSettingsBridge {
  /// 手机扫码配置起始端口。
  ///
  /// 默认优先从这个端口开始尝试，方便局域网里人工核对地址。
  static const int initialSharePort = 18321;

  /// 手机网页可用时的默认提示。
  static const String readyStatus = '请使用与电视同一局域网的手机扫码填写配置';

  /// 手机配置已提交后的提示。
  static const String appliedStatus = '已从手机接收配置，返回电视后确认保存即可';

  /// 局域网地址不可用时的提示。
  static const String unavailableStatus = '未获取到局域网地址，请检查电视网络连接';

  /// 当前 App 生命周期内缓存的分享主机地址。
  ///
  /// 只要应用进程不退出，就尽量复用第一次成功解析出的地址，避免二维码频繁变动。
  static String? _cachedShareHost;

  /// 下一个优先尝试的分享端口。
  ///
  /// 每次手动重生成二维码后都会递增，确保新的二维码地址确实发生变化。
  static int _nextPreferredPort = initialSharePort;

  /// 启动一个新的手机配置桥接会话。
  static Future<TvMobileSettingsBridgeSession> startSession(
    TvMobileSettingsDraft initialDraft,
    ValueChanged<TvMobileSettingsDraft> onDraftSubmitted, {
    InternetAddress? bindAddress,
    String? preferredHost,
    bool allocateNewPort = false,
  }) async {
    final shareHost = await _resolveShareHost(preferredHost);
    final statusNotifier = ValueNotifier<String>(
      shareHost == null ? unavailableStatus : readyStatus,
    );
    if (shareHost == null) {
      return TvMobileSettingsBridgeSession(
        shareUri: null,
        statusNotifier: statusNotifier,
        updateDraft: (_) {},
        dispose: () async {
          statusNotifier.dispose();
        },
      );
    }

    final server = await _bindShareServer(
      bindAddress: bindAddress ?? InternetAddress.anyIPv4,
      allocateNewPort: allocateNewPort,
    );
    final runner = _RunningTvMobileSettingsBridge(
      server: server,
      shareHost: shareHost,
      statusNotifier: statusNotifier,
      initialDraft: initialDraft,
      onDraftSubmitted: onDraftSubmitted,
    );
    runner.start();
    return TvMobileSettingsBridgeSession(
      shareUri: Uri.parse('http://$shareHost:${server.port}'),
      statusNotifier: statusNotifier,
      updateDraft: runner.updateDraft,
      dispose: runner.dispose,
    );
  }

  /// 绑定扫码配置服务端口。
  static Future<HttpServer> _bindShareServer({
    required InternetAddress bindAddress,
    required bool allocateNewPort,
  }) async {
    final preferredPort = allocateNewPort ? _nextPreferredPort + 1 : _nextPreferredPort;
    var candidatePort = preferredPort;
    while (true) {
      try {
        final server = await HttpServer.bind(bindAddress, candidatePort);
        _nextPreferredPort = server.port;
        return server;
      } on SocketException {
        candidatePort++;
      }
    }
  }

  /// 解析当前设备对手机可见的局域网地址。
  static Future<String?> _resolveShareHost(String? preferredHost) async {
    final normalizedPreferredHost = preferredHost?.trim();
    if (normalizedPreferredHost != null && normalizedPreferredHost.isNotEmpty) {
      _cachedShareHost = normalizedPreferredHost;
      return normalizedPreferredHost;
    }

    final cachedShareHost = _cachedShareHost;
    if (cachedShareHost != null && cachedShareHost.isNotEmpty) {
      return cachedShareHost;
    }

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        // 优先选择常见的内网 IPv4 地址，避免把不可达地址暴露给手机。
        if (!address.isLoopback && _isPrivateIpv4(address.address)) {
          _cachedShareHost = address.address;
          return address.address;
        }
      }
    }

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          _cachedShareHost = address.address;
          return address.address;
        }
      }
    }
    return null;
  }

  /// 判断是否属于常见私有 IPv4 地址段。
  static bool _isPrivateIpv4(String address) {
    final octets = address.split('.');
    if (octets.length != 4) {
      return false;
    }
    final first = int.tryParse(octets[0]);
    final second = int.tryParse(octets[1]);
    if (first == null || second == null) {
      return false;
    }
    if (first == 10) {
      return true;
    }
    if (first == 172 && second >= 16 && second <= 31) {
      return true;
    }
    if (first == 192 && second == 168) {
      return true;
    }
    return false;
  }
}

/// 正在运行的手机配置桥接实例。
///
/// 内部持有 HttpServer 和最新草稿，负责处理局域网请求。
class _RunningTvMobileSettingsBridge {
  /// 创建运行中的桥接实例。
  _RunningTvMobileSettingsBridge({
    required HttpServer server,
    required this.shareHost,
    required this.statusNotifier,
    required TvMobileSettingsDraft initialDraft,
    required this.onDraftSubmitted,
  })  : _server = server,
        _draft = initialDraft;

  /// 局域网页面绑定的 HttpServer。
  final HttpServer _server;

  /// 暴露给手机访问的主机地址。
  final String shareHost;

  /// 当前状态文案。
  final ValueNotifier<String> statusNotifier;

  /// 手机上报新草稿后的回调。
  final ValueChanged<TvMobileSettingsDraft> onDraftSubmitted;

  /// 最近一次同步给手机的草稿。
  TvMobileSettingsDraft _draft;

  /// 当前请求订阅。
  StreamSubscription<HttpRequest>? _subscription;

  /// 启动请求监听。
  void start() {
    _subscription = _server.listen(_handleRequest);
  }

  /// 更新当前草稿。
  void updateDraft(TvMobileSettingsDraft draft) {
    _draft = draft;
  }

  /// 释放服务资源。
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _server.close(force: true);
    statusNotifier.dispose();
  }

  /// 处理手机端请求。
  Future<void> _handleRequest(HttpRequest request) async {
    final isRootPath = request.uri.path.isEmpty || request.uri.path == '/';
    if (!isRootPath) {
      await _writeNotFound(request.response);
      return;
    }

    // GET 返回表单页面，POST 则把手机提交的草稿推回电视。
    if (request.method == 'GET') {
      await _writeHtml(
        request.response,
        _buildHtmlPage(
          draft: _draft,
          actionPath: '/',
          successMessage: null,
        ),
      );
      return;
    }

    if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final fields = Uri.splitQueryString(body);
      final nextDraft = TvMobileSettingsDraft.fromFormFields(fields);
      _draft = nextDraft;
      onDraftSubmitted(nextDraft);
      statusNotifier.value = TvMobileSettingsBridge.appliedStatus;
      await _writeHtml(
        request.response,
        _buildHtmlPage(
          draft: nextDraft,
          actionPath: '/',
          successMessage: '配置已发送到电视，请回到电视确认保存。',
        ),
      );
      return;
    }

    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
  }

  /// 输出 404 页面。
  Future<void> _writeNotFound(HttpResponse response) async {
    response.statusCode = HttpStatus.notFound;
    await _writeHtml(
      response,
      '<html><body><h1>404</h1><p>配置页面不存在。</p></body></html>',
    );
  }

  /// 输出 HTML 文本响应。
  Future<void> _writeHtml(HttpResponse response, String html) async {
    response.headers.contentType = ContentType.html;
    response.write(html);
    await response.close();
  }

  /// 构建手机端配置网页。
  String _buildHtmlPage({
    required TvMobileSettingsDraft draft,
    required String actionPath,
    required String? successMessage,
  }) {
    final escapedServerUrl = _escapeHtml(draft.serverUrl);
    final escapedUsername = _escapeHtml(draft.username);
    final escapedPassword = _escapeHtml(draft.password);
    final escapedDanmakuBaseApi = _escapeHtml(draft.danmakuBaseApi);
    final imageSourceOptions =
        TvMobileSettingsDraft.availableDoubanImageSources.map((option) {
      final selected = option == draft.doubanImageSource ? 'selected' : '';
      return '<option value="${_escapeHtml(option)}" $selected>${_escapeHtml(option)}</option>';
    }).join();
    final adFilterChecked = draft.adFilterEnabled ? 'checked' : '';

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Selene TV 手机配置</title>
  <style>
    body {
      margin: 0;
      background: #0f1417;
      color: #e7f1ee;
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Segoe UI", sans-serif;
    }
    .shell {
      max-width: 720px;
      margin: 0 auto;
      padding: 24px 18px 48px;
    }
    .card {
      background: #151b1f;
      border: 1px solid #263036;
      border-radius: 18px;
      padding: 20px;
      box-shadow: 0 18px 42px rgba(0, 0, 0, 0.26);
    }
    h1 {
      margin: 0 0 8px;
      font-size: 24px;
    }
    p {
      margin: 0 0 16px;
      color: #96a3aa;
      line-height: 1.6;
    }
    .success {
      margin: 0 0 16px;
      padding: 12px 14px;
      border-radius: 12px;
      background: rgba(92, 181, 131, 0.14);
      color: #9fe2b6;
    }
    label {
      display: block;
      margin: 18px 0 8px;
      font-size: 14px;
      color: #b9c7c3;
    }
    input, select {
      width: 100%;
      box-sizing: border-box;
      border: 1px solid #334148;
      border-radius: 12px;
      background: #0f1417;
      color: #ffffff;
      padding: 14px 16px;
      font-size: 16px;
    }
    .toggle {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-top: 18px;
      color: #d7e3df;
    }
    button {
      width: 100%;
      margin-top: 24px;
      border: none;
      border-radius: 14px;
      background: #5cb583;
      color: #08110d;
      padding: 16px;
      font-size: 17px;
      font-weight: 700;
    }
    .meta {
      margin-top: 18px;
      font-size: 13px;
      color: #708087;
    }
  </style>
</head>
<body>
  <div class="shell">
    <div class="card">
      <h1>Selene TV 手机配置</h1>
      <p>在手机里填好服务器、图片代理和弹幕地址后提交，电视会自动回填表单，最后回到电视确认保存即可。</p>
      ${successMessage == null ? '' : '<div class="success">${_escapeHtml(successMessage)}</div>'}
      <form method="post" action="$actionPath">
        <label for="serverUrl">服务器地址</label>
        <input id="serverUrl" name="serverUrl" value="$escapedServerUrl" placeholder="https://example.com" />

        <label for="username">账号</label>
        <input id="username" name="username" value="$escapedUsername" placeholder="请输入账号" />

        <label for="password">密码</label>
        <input id="password" name="password" type="password" value="$escapedPassword" placeholder="请输入密码" />

        <label for="doubanImageSource">图片代理</label>
        <select id="doubanImageSource" name="doubanImageSource">
          $imageSourceOptions
        </select>

        <label for="danmakuBaseApi">弹幕服务器地址</label>
        <input id="danmakuBaseApi" name="danmakuBaseApi" value="$escapedDanmakuBaseApi" placeholder="https://danmaku.example.com/" />

        <label class="toggle" for="adFilterEnabled">
          <input id="adFilterEnabled" name="adFilterEnabled" type="checkbox" value="true" $adFilterChecked style="width: 18px; height: 18px;" />
          自动去广告
        </label>

        <button type="submit">同步到电视</button>
      </form>
      <div class="meta">当前电视地址：$shareHost:${_server.port}</div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// 简单转义 HTML 特殊字符，避免输入内容打断页面结构。
  String _escapeHtml(String rawValue) {
    return rawValue
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
