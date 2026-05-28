import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../models/bangumi.dart';
import 'api_service.dart';
import 'douban_cache_service.dart';

/// Bangumi 数据服务（函数级缓存，一天过期）
class BangumiService {
  static final DoubanCacheService _cache = DoubanCacheService();
  static bool _initialized = false;
  static const String _calendarLogTag = 'BangumiService[calendar]';
  static const String _calendarPrimaryApiUrl = 'https://api.bgm.tv/calendar';
  static const String _calendarCacheKey = 'bangumi_calendar_raw_v1';
  static const String _calendarFallbackCacheKey =
      'bangumi_calendar_raw_fallback_v1';
  static const Duration _calendarApiTimeout = Duration(seconds: 3);
  static const Duration _calendarPageTimeout = Duration(seconds: 3);
  static const List<String> _calendarProxyApiPrefixes = <String>[
    // Bangumi 日历接口代理前缀列表，后续新增代理时继续往这里追加即可。
    'https://pz.v88.qzz.io/?url=',
  ];
  static const List<String> _calendarPageUrls = <String>[
    'https://bangumi.tv/calendar',
    'https://bgm.tv/calendar',
    'https://chii.in/calendar',
  ];
  static Future<http.Response> Function(
    Uri uri,
    Map<String, String> headers,
  )? _calendarHttpGetForTest;
  static Future<List<dynamic>?> Function(
    String cacheKey,
    bool allowExpired,
  )? _calendarCacheReaderForTest;
  static Future<String?> Function()? _calendarPageHtmlLoaderForTest;
  static Duration? _calendarApiTimeoutForTest;
  static bool _skipCacheInitForTest = false;

  /// 测试专用日历请求函数。
  @visibleForTesting
  static set calendarHttpGetForTest(
    Future<http.Response> Function(
      Uri uri,
      Map<String, String> headers,
    )? loader,
  ) {
    _calendarHttpGetForTest = loader;
  }

  /// 测试专用日历缓存读取函数。
  @visibleForTesting
  static set calendarCacheReaderForTest(
    Future<List<dynamic>?> Function(String cacheKey, bool allowExpired)? reader,
  ) {
    _calendarCacheReaderForTest = reader;
  }

  /// 测试专用日历页面 HTML 读取函数。
  @visibleForTesting
  static set calendarPageHtmlLoaderForTest(
    Future<String?> Function()? loader,
  ) {
    _calendarPageHtmlLoaderForTest = loader;
  }

  /// 测试专用主接口超时时间。
  @visibleForTesting
  static set calendarApiTimeoutForTest(Duration? duration) {
    _calendarApiTimeoutForTest = duration;
  }

  /// 重置测试注入状态。
  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
    _calendarHttpGetForTest = null;
    _calendarCacheReaderForTest = null;
    _calendarPageHtmlLoaderForTest = null;
    _calendarApiTimeoutForTest = null;
    _skipCacheInitForTest = false;
  }

  /// 测试时跳过真实磁盘缓存初始化。
  @visibleForTesting
  static void skipCacheInitForTest() {
    _skipCacheInitForTest = true;
    _initialized = true;
  }

  static Future<void> _initCache() async {
    if (_skipCacheInitForTest) {
      return;
    }
    if (!_initialized) {
      await _cache.init();
      _initialized = true;
    }
  }

  /// 输出 Bangumi 日历链路调试日志。
  ///
  /// 这里统一带上固定前缀，方便在控制台里直接按关键字过滤 5 秒兜底链路。
  static void _logCalendarDebug(String message) {
    debugPrint('$_calendarLogTag $message');
  }

  /// 获取当天的新番放送（根据当前星期几）
  static Future<ApiResponse<List<BangumiItem>>> getTodayCalendar(
    BuildContext context,
  ) async {
    final weekday = DateTime.now().weekday; // 1..7
    final now = DateTime.now();
    _logCalendarDebug(
      'device now=${now.toIso8601String()}, weekday=${now.weekday}, timezoneOffset=${now.timeZoneOffset.inHours}h.',
    );
    return getCalendarByWeekday(context, weekday);
  }

  /// 获取指定星期的新番放送
  static Future<ApiResponse<List<BangumiItem>>> getCalendarByWeekday(
    BuildContext context,
    int weekday, // 1..7 (Monday..Sunday)
  ) async {
    await _initCache();
    final stopwatch = Stopwatch()..start();
    final apiTimeout = _calendarApiTimeoutForTest ?? _calendarApiTimeout;
    _logCalendarDebug(
      'weekday=$weekday start, timeout=${apiTimeout.inMilliseconds}ms.',
    );

    // 先尝试读取原始数组缓存
    final cachedItems = await _getCachedCalendarItems(
      weekday,
      allowExpired: false,
    );
    if (cachedItems != null) {
      _logCalendarDebug(
        'weekday=$weekday served by fresh cache, items=${cachedItems.length}, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      return ApiResponse.success(cachedItems);
    }

    // 未命中缓存，请求接口
    final headers = {
      'User-Agent':
          'senshinya/selene/1.0.0 (Android) (http://github.com/senshinya/selene)',
      'Accept': 'application/json',
    };

    // 第一层优先命中官方日历接口。
    final primaryApiPayload = await _requestCalendarPayloadFromApi(
      weekday: weekday,
      requestLabel: 'primary-api',
      requestUrl: _calendarPrimaryApiUrl,
      headers: headers,
      timeout: apiTimeout,
      stopwatch: stopwatch,
    );
    if (primaryApiPayload != null) {
      return _buildCalendarSuccessResponse(
        weekday: weekday,
        sourceLabel: 'primary-api',
        rawPayload: primaryApiPayload,
        stopwatch: stopwatch,
        statusCode: 200,
      );
    }

    // 第二层按列表顺序尝试代理接口，方便后续继续追加新的中转源。
    final proxyApiUrls = _buildCalendarProxyApiUrls();
    for (var index = 0; index < proxyApiUrls.length; index++) {
      final requestLabel = 'proxy-api-${index + 1}';
      final proxyApiPayload = await _requestCalendarPayloadFromApi(
        weekday: weekday,
        requestLabel: requestLabel,
        requestUrl: proxyApiUrls[index],
        headers: headers,
        timeout: apiTimeout,
        stopwatch: stopwatch,
      );
      if (proxyApiPayload != null) {
        return _buildCalendarSuccessResponse(
          weekday: weekday,
          sourceLabel: requestLabel,
          rawPayload: proxyApiPayload,
          stopwatch: stopwatch,
          statusCode: 200,
        );
      }
    }

    _logCalendarDebug(
      'weekday=$weekday api layers unavailable, switching to page fallback.',
    );
    final htmlFallbackItems = await _getCalendarItemsFromPageFallback(weekday);
    if (htmlFallbackItems != null) {
      _logCalendarDebug(
        'weekday=$weekday page fallback success, items=${htmlFallbackItems.length}, totalElapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      return ApiResponse.success(htmlFallbackItems);
    }

    final staleItems = await _getFallbackCalendarItems(weekday);
    if (staleItems != null) {
      _logCalendarDebug(
        'weekday=$weekday stale cache fallback success, items=${staleItems.length}, totalElapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      return ApiResponse.success(staleItems);
    }

    _logCalendarDebug(
      'weekday=$weekday all fallbacks failed, totalElapsed=${stopwatch.elapsedMilliseconds}ms.',
    );
    return ApiResponse.error('Bangumi 数据请求异常: 官方接口、代理接口与页面兜底均失败');
  }

  /// 构建代理接口 URL 列表。
  ///
  /// 当前约定代理前缀直接以 `?url=` 结尾，统一在这里补上编码后的官方接口地址。
  static List<String> _buildCalendarProxyApiUrls() {
    final encodedTargetUrl = Uri.encodeComponent(_calendarPrimaryApiUrl);
    return _calendarProxyApiPrefixes
        .map((prefix) => '$prefix$encodedTargetUrl')
        .toList();
  }

  /// 请求 Bangumi 日历 JSON。
  ///
  /// 官方接口和代理接口共用这条链路，只在日志里区分当前属于哪一层。
  static Future<List<dynamic>?> _requestCalendarPayloadFromApi({
    required int weekday,
    required String requestLabel,
    required String requestUrl,
    required Map<String, String> headers,
    required Duration timeout,
    required Stopwatch stopwatch,
  }) async {
    try {
      final uri = Uri.parse(requestUrl);
      _logCalendarDebug(
        'weekday=$weekday $requestLabel request start, url=$requestUrl, timeout=${timeout.inMilliseconds}ms.',
      );
      final response = await (_calendarHttpGetForTest?.call(uri, headers) ??
              http.get(uri, headers: headers))
          .timeout(timeout);
      _logCalendarDebug(
        'weekday=$weekday $requestLabel completed, status=${response.statusCode}, bodyBytes=${response.body.length}, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      if (response.statusCode != 200) {
        _logCalendarDebug(
          'weekday=$weekday $requestLabel returned non-200 status=${response.statusCode}.',
        );
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! List<dynamic>) {
        _logCalendarDebug(
          'weekday=$weekday $requestLabel response is not List payload, actualType=${decoded.runtimeType}.',
        );
        return null;
      }
      return decoded;
    } catch (error) {
      _logCalendarDebug(
        'weekday=$weekday $requestLabel exception, type=${error.runtimeType}, message=$error, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      return null;
    }
  }

  /// 把成功拿到的整周 payload 转成首页需要的当天结果，并统一写缓存。
  static Future<ApiResponse<List<BangumiItem>>> _buildCalendarSuccessResponse({
    required int weekday,
    required String sourceLabel,
    required List<dynamic> rawPayload,
    required Stopwatch stopwatch,
    int? statusCode,
  }) async {
    final items = _extractCalendarItemsFromPayload(rawPayload, weekday);
    final weekdaySummary = _buildWeekdayCountSummary(rawPayload);
    final titlePreview = _buildBangumiTitlePreview(items);
    _logCalendarDebug(
      'weekday=$weekday $sourceLabel success, items=${items.length}, weekdaySummary=$weekdaySummary, preview=$titlePreview, writing fresh and fallback cache.',
    );

    // 成功拿到整周 JSON 后统一回写缓存，后续首页可以直接走本地缓存秒回。
    try {
      await _cache.set(
        _calendarCacheKey,
        rawPayload,
        const Duration(days: 1),
      );
      await _cache.set(
        _calendarFallbackCacheKey,
        rawPayload,
        const Duration(days: 14),
      );
      _logCalendarDebug(
        'weekday=$weekday $sourceLabel cache write success, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (cacheError) {
      _logCalendarDebug(
        'weekday=$weekday $sourceLabel cache write failed, type=${cacheError.runtimeType}, message=$cacheError.',
      );
    }

    return ApiResponse.success(items, statusCode: statusCode);
  }

  /// 读取网络失败时的最后可用日历。
  static Future<List<BangumiItem>?> _getFallbackCalendarItems(
    int weekday,
  ) async {
    final fallbackItems = await _getCachedCalendarItems(
      weekday,
      allowExpired: true,
      cacheKey: _calendarFallbackCacheKey,
    );
    if (fallbackItems != null) {
      return fallbackItems;
    }

    return _getCachedCalendarItems(
      weekday,
      allowExpired: true,
      cacheKey: _calendarCacheKey,
    );
  }

  /// 读取指定星期的日历缓存。
  static Future<List<BangumiItem>?> _getCachedCalendarItems(
    int weekday, {
    required bool allowExpired,
    String cacheKey = _calendarCacheKey,
  }) async {
    try {
      final injectedReader = _calendarCacheReaderForTest;
      final cachedRaw = injectedReader != null
          ? await injectedReader(cacheKey, allowExpired)
          : allowExpired
              ? await _cache.getStale<List<dynamic>>(
                  cacheKey,
                  (raw) => raw as List<dynamic>,
                )
              : await _cache.get<List<dynamic>>(
                  cacheKey,
                  (raw) => raw as List<dynamic>,
                );
      if (cachedRaw == null || cachedRaw.isEmpty) {
        _logCalendarDebug(
          'weekday=$weekday cache miss, key=$cacheKey, allowExpired=$allowExpired.',
        );
        return null;
      }
      final items = _extractCalendarItemsFromPayload(cachedRaw, weekday);
      final weekdaySummary = _buildWeekdayCountSummary(cachedRaw);
      _logCalendarDebug(
        'weekday=$weekday cache hit, key=$cacheKey, allowExpired=$allowExpired, rawDays=${cachedRaw.length}, items=${items.length}, weekdaySummary=$weekdaySummary.',
      );
      return items;
    } catch (error) {
      _logCalendarDebug(
        'weekday=$weekday cache read failed, key=$cacheKey, allowExpired=$allowExpired, type=${error.runtimeType}, message=$error.',
      );
      return null;
    }
  }

  /// 从页面兜底链路中读取指定星期的新番数据。
  static Future<List<BangumiItem>?> _getCalendarItemsFromPageFallback(
    int weekday,
  ) async {
    try {
      _logCalendarDebug('weekday=$weekday starting page fallback.');
      final pagePayload = await _loadCalendarPayloadFromPage();
      if (pagePayload == null || pagePayload.isEmpty) {
        _logCalendarDebug(
          'weekday=$weekday page fallback produced empty payload.',
        );
        return null;
      }

      // 页面兜底成功后仍回写整周缓存，后续所有端都继续复用同一份缓存。
      try {
        await _cache.set(
          _calendarCacheKey,
          pagePayload,
          const Duration(days: 1),
        );
        await _cache.set(
          _calendarFallbackCacheKey,
          pagePayload,
          const Duration(days: 14),
        );
        _logCalendarDebug(
          'weekday=$weekday page fallback cache write success.',
        );
      } catch (cacheError) {
        _logCalendarDebug(
          'weekday=$weekday page fallback cache write failed, type=${cacheError.runtimeType}, message=$cacheError.',
        );
      }

      final totalCount = pagePayload.fold<int>(
        0,
        (sum, day) =>
            sum + ((day as Map<String, dynamic>)['items'] as List).length,
      );
      final weekdayItems = _extractCalendarItemsFromPayload(pagePayload, weekday);
      final weekdaySummary = _buildWeekdayCountSummary(pagePayload);
      final titlePreview = _buildBangumiTitlePreview(weekdayItems);
      debugPrint(
        '$_calendarLogTag weekday=$weekday page fallback parsed ${pagePayload.length} weekdays, total $totalCount items, currentWeekdayItems=${weekdayItems.length}, weekdaySummary=$weekdaySummary, preview=$titlePreview.',
      );
      return weekdayItems;
    } catch (error) {
      _logCalendarDebug(
        'weekday=$weekday page fallback failed, type=${error.runtimeType}, message=$error.',
      );
      return null;
    }
  }

  /// 通过整周原始 payload 提取指定星期的数据。
  static List<BangumiItem> _extractCalendarItemsFromPayload(
    List<dynamic> rawPayload,
    int weekday,
  ) {
    final calendar = rawPayload
        .map(
          (item) => BangumiCalendarResponse.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();

    for (final day in calendar) {
      if (day.weekday.id == weekday) {
        return day.items;
      }
    }
    return <BangumiItem>[];
  }

  /// 构建整周条目数量摘要。
  ///
  /// 用于快速判断是“整个页面没解析到数据”，还是“只有今天这一列为空”。
  static String _buildWeekdayCountSummary(List<dynamic> rawPayload) {
    try {
      final calendar = rawPayload
          .map(
            (item) => BangumiCalendarResponse.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      final weekdayCounts = <String>[];
      for (final day in calendar) {
        weekdayCounts.add('${day.weekday.id}:${day.items.length}');
      }
      return '[${weekdayCounts.join(', ')}]';
    } catch (_) {
      return '[parse-failed]';
    }
  }

  /// 构建当天命中标题预览。
  ///
  /// 只取前几个标题，避免控制台被整批番剧名称刷满。
  static String _buildBangumiTitlePreview(
    List<BangumiItem> items, {
    int limit = 5,
  }) {
    if (items.isEmpty) {
      return '[]';
    }
    final previewTitles = items
        .take(limit)
        .map((item) {
          final chineseTitle = item.nameCn?.trim() ?? '';
          final originalTitle = item.name.trim();
          return chineseTitle.isNotEmpty ? chineseTitle : originalTitle;
        })
        .where((title) => title.isNotEmpty)
        .toList();
    return '[${previewTitles.join(' | ')}]';
  }

  /// 读取 Bangumi 日历页面并解析成整周 payload。
  static Future<List<dynamic>?> _loadCalendarPayloadFromPage() async {
    final html = await _loadCalendarPageHtml();
    if (html == null || html.trim().isEmpty) {
      _logCalendarDebug('page fallback html empty.');
      return null;
    }
    _logCalendarDebug(
      'page fallback html loaded, length=${html.length}.',
    );

    final payload = _parseCalendarPayloadFromHtml(html);
    final totalCount = payload.fold<int>(
      0,
      (sum, day) => sum + ((day['items'] as List<dynamic>?)?.length ?? 0),
    );
    _logCalendarDebug(
      'page fallback html parsed, weekdays=${payload.length}, totalItems=$totalCount.',
    );
    if (totalCount <= 0) {
      return null;
    }
    return payload;
  }

  /// 读取 Bangumi 日历页面 HTML。
  static Future<String?> _loadCalendarPageHtml() async {
    final injectedLoader = _calendarPageHtmlLoaderForTest;
    if (injectedLoader != null) {
      _logCalendarDebug('loading calendar html from injected test loader.');
      return injectedLoader();
    }

    // 测试环境未注入页面数据时直接返回，避免误起真实 WebView。
    if (_skipCacheInitForTest) {
      _logCalendarDebug('skipCacheInitForTest=true, skip real WebView html loading.');
      return null;
    }

    for (final pageUrl in _calendarPageUrls) {
      _logCalendarDebug('trying page fallback mirror: $pageUrl');
      final html = await _loadCalendarPageHtmlByWebView(pageUrl);
      if (_looksLikeBangumiCalendarHtml(html)) {
        _logCalendarDebug(
          'page fallback mirror succeeded: $pageUrl, htmlLength=${html?.length ?? 0}.',
        );
        return html;
      }
      _logCalendarDebug('page fallback mirror did not return valid calendar html: $pageUrl');
    }

    _logCalendarDebug('all page fallback mirrors failed.');
    return null;
  }

  /// 通过内嵌浏览器内核加载页面，绕过接口链路不可达时的 TLS 限制。
  static Future<String?> _loadCalendarPageHtmlByWebView(String pageUrl) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;
    final stopwatch = Stopwatch()..start();

    void completeOnce(String? html) {
      if (!completer.isCompleted) {
        completer.complete(html);
      }
    }

    try {
      _logCalendarDebug('webview loading start: $pageUrl');
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
        initialSettings: InAppWebViewSettings(
          isInspectable: kDebugMode,
          javaScriptEnabled: true,
          transparentBackground: true,
        ),
        onLoadStop: (controller, url) async {
          try {
            final html = await controller.getHtml();
            _logCalendarDebug(
              'webview load stop: $pageUrl, elapsed=${stopwatch.elapsedMilliseconds}ms, htmlLength=${html?.length ?? 0}.',
            );
            completeOnce(html);
          } catch (error) {
            _logCalendarDebug(
              'webview getHtml failed: $pageUrl, type=${error.runtimeType}, message=$error.',
            );
            completeOnce(null);
          }
        },
        onReceivedError: (controller, request, error) {
          // 只处理主文档失败，子资源异常不应提前打断整页 HTML 抓取。
          if (request.isForMainFrame ?? true) {
            _logCalendarDebug(
              'webview main frame error: $pageUrl, code=${error.type}, description=${error.description}.',
            );
            completeOnce(null);
          }
        },
        onReceivedHttpError: (controller, request, errorResponse) {
          // 主文档返回 HTTP 错误时直接判定本次镜像不可用。
          if (request.isForMainFrame ?? true) {
            _logCalendarDebug(
              'webview main frame http error: $pageUrl, status=${errorResponse.statusCode}, reason=${errorResponse.reasonPhrase}.',
            );
            completeOnce(null);
          }
        },
      );

      await headlessWebView.run();
      final html = await completer.future.timeout(
        _calendarPageTimeout,
        onTimeout: () {
          _logCalendarDebug(
            'webview load timeout: $pageUrl, elapsed=${stopwatch.elapsedMilliseconds}ms.',
          );
          return null;
        },
      );
      _logCalendarDebug(
        'webview loading end: $pageUrl, elapsed=${stopwatch.elapsedMilliseconds}ms, success=${html != null && html.isNotEmpty}.',
      );
      return html;
    } catch (error) {
      _logCalendarDebug(
        'webview loading crashed: $pageUrl, type=${error.runtimeType}, message=$error.',
      );
      return null;
    } finally {
      try {
        await headlessWebView?.dispose();
      } catch (_) {}
    }
  }

  /// 判断当前 HTML 是否已经拿到 Bangumi 每日放送页面主体。
  static bool _looksLikeBangumiCalendarHtml(String? html) {
    if (html == null || html.isEmpty) {
      return false;
    }
    return html.contains('BgmCalendar') && html.contains('每日放送');
  }

  /// 把日历页面解析成与官方接口结构兼容的整周 payload。
  static List<Map<String, dynamic>> _parseCalendarPayloadFromHtml(String html) {
    final Map<int, List<Map<String, dynamic>>> weekdayItems =
        <int, List<Map<String, dynamic>>>{
      for (var weekday = 1; weekday <= 7; weekday++)
        weekday: <Map<String, dynamic>>[],
    };

    final sectionRegex = RegExp(
      r'<dt[^>]*>\s*<div[^>]*>\s*<h3[^>]*>\s*(星期[一二三四五六日天])\s*</h3>\s*</div>\s*</dt>\s*<dd[^>]*>([\s\S]*?)</dd>',
      caseSensitive: false,
    );

    for (final match in sectionRegex.allMatches(html)) {
      final weekdayLabel = _stripCalendarHtmlText(match.group(1) ?? '');
      final weekdayId = _weekdayTextToId(weekdayLabel);
      if (weekdayId == null) {
        continue;
      }

      final weekdayHtml = match.group(2) ?? '';
      weekdayItems[weekdayId] = _parseWeekdayItemsFromHtml(
        weekdayHtml,
        weekdayId,
      );
    }

    return List<Map<String, dynamic>>.generate(
      7,
      (index) {
        final weekdayId = index + 1;
        return <String, dynamic>{
          'weekday': _buildWeekdayPayload(weekdayId),
          'items': weekdayItems[weekdayId] ?? <Map<String, dynamic>>[],
        };
      },
    );
  }

  /// 解析某个星期分组内的全部番剧条目。
  static List<Map<String, dynamic>> _parseWeekdayItemsFromHtml(
    String weekdayHtml,
    int weekdayId,
  ) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    final itemRegex = RegExp(
      r'<li\b[^>]*>([\s\S]*?)</li>',
      caseSensitive: false,
    );
    final paragraphRegex = RegExp(
      r'<p[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    );
    final subjectIdRegex = RegExp(
      r'''href=['"][^'"]*/subject/(\d+)['"]''',
      caseSensitive: false,
    );
    final coverRegex = RegExp(
      r'''url\((['"]?)([^)'"]+)\1\)''',
      caseSensitive: false,
    );

    for (final match in itemRegex.allMatches(weekdayHtml)) {
      final itemHtml = match.group(0) ?? '';
      final idMatch = subjectIdRegex.firstMatch(itemHtml);
      if (idMatch == null) {
        continue;
      }

      final subjectId = int.tryParse(idMatch.group(1) ?? '');
      if (subjectId == null) {
        continue;
      }

      final paragraphMatches = paragraphRegex.allMatches(itemHtml).toList();
      final primaryTitle = paragraphMatches.isNotEmpty
          ? _stripCalendarHtmlText(paragraphMatches.first.group(1) ?? '')
          : '';
      final secondaryTitle = paragraphMatches.length > 1
          ? _stripCalendarHtmlText(paragraphMatches[1].group(1) ?? '')
          : '';
      final displayTitle =
          secondaryTitle.isNotEmpty ? secondaryTitle : primaryTitle;
      if (displayTitle.isEmpty) {
        continue;
      }

      final coverMatch = coverRegex.firstMatch(itemHtml);
      final coverUrl = _normalizeBangumiCoverUrl(coverMatch?.group(2));

      items.add(<String, dynamic>{
        'id': subjectId,
        'url': 'https://bangumi.tv/subject/$subjectId',
        'type': 2,
        'name': displayTitle,
        'name_cn': primaryTitle.isNotEmpty ? primaryTitle : null,
        'summary': '',
        'air_date': '',
        'air_weekday': weekdayId,
        'rating': <String, dynamic>{
          'total': 0,
          'count': <String, int>{},
          'score': 0,
        },
        'rank': 0,
        'images': <String, dynamic>{
          'large': coverUrl,
          'common': coverUrl,
          'medium': coverUrl,
          'small': coverUrl,
          'grid': coverUrl,
        },
        'collection': <String, dynamic>{
          'doing': 0,
          'on_hold': 0,
          'dropped': 0,
          'wish': 0,
          'collect': 0,
        },
      });
    }

    return items;
  }

  /// 构造与 Bangumi 官方接口一致的星期字段。
  static Map<String, dynamic> _buildWeekdayPayload(int weekdayId) {
    const weekdayEn = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    const weekdayCn = <int, String>{
      1: '星期一',
      2: '星期二',
      3: '星期三',
      4: '星期四',
      5: '星期五',
      6: '星期六',
      7: '星期日',
    };
    const weekdayJa = <int, String>{
      1: '月曜日',
      2: '火曜日',
      3: '水曜日',
      4: '木曜日',
      5: '金曜日',
      6: '土曜日',
      7: '日曜日',
    };

    return <String, dynamic>{
      'en': weekdayEn[weekdayId] ?? '',
      'cn': weekdayCn[weekdayId] ?? '',
      'ja': weekdayJa[weekdayId] ?? '',
      'id': weekdayId,
    };
  }

  /// 把页面里的中文星期文案转换成接口所用 weekday id。
  static int? _weekdayTextToId(String weekdayText) {
    switch (weekdayText) {
      case '星期一':
        return 1;
      case '星期二':
        return 2;
      case '星期三':
        return 3;
      case '星期四':
        return 4;
      case '星期五':
        return 5;
      case '星期六':
        return 6;
      case '星期日':
      case '星期天':
        return 7;
      default:
        return null;
    }
  }

  /// 清理页面片段中的标签与多余空白，保留纯文本标题。
  static String _stripCalendarHtmlText(String htmlText) {
    const htmlEntities = <String, String>{
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': '\'',
      '&apos;': '\'',
    };

    var text = htmlText.replaceAll(RegExp(r'<[^>]+>'), ' ');
    htmlEntities.forEach((entity, replacement) {
      text = text.replaceAll(entity, replacement);
    });
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 归一化页面中的封面地址，统一补齐协议和主域。
  static String _normalizeBangumiCoverUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return '';
    }

    final normalized = rawUrl.trim();
    if (normalized.startsWith('//')) {
      return 'https:$normalized';
    }
    if (normalized.startsWith('/')) {
      return 'https://bangumi.tv$normalized';
    }
    return normalized;
  }

  /// 获取 Bangumi 详情数据
  ///
  /// 参数说明：
  /// - bangumiId: Bangumi ID
  static Future<ApiResponse<BangumiDetails>> getBangumiDetails(
    BuildContext context, {
    required String bangumiId,
  }) async {
    await _initCache();

    // 生成缓存键
    final cacheKey = _cache.generateBangumiDetailsCacheKey(
      bangumiId: bangumiId,
    );

    // 尝试从缓存获取数据
    try {
      final cachedData = await _cache.get<BangumiDetails>(
        cacheKey,
        (raw) {
          if (raw is! Map<String, dynamic>) {
            throw FormatException('Bangumi 缓存数据格式错误: ${raw.runtimeType}');
          }
          return BangumiDetails.fromJson(raw);
        },
      );

      if (cachedData != null) {
        return ApiResponse.success(cachedData);
      }
    } catch (e) {
      // 缓存读取失败，清理可能损坏的缓存，继续执行网络请求
      try {
        // 清理这个特定的缓存项
        await _cache.set(cacheKey, null, Duration.zero);
      } catch (_) {}
    }

    try {
      final apiUrl = 'https://api.bgm.tv/v0/subjects/$bangumiId';
      final headers = {
        'User-Agent':
            'senshinya/selene/1.0.0 (Android) (http://github.com/senshinya/selene)',
        'Accept': 'application/json',
      };

      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          final details = BangumiDetails.fromJson(data);

          // 缓存成功的结果，缓存时间为24小时
          try {
            await _cache.set(
              cacheKey,
              details.toJson(),
              const Duration(days: 3),
            );
          } catch (cacheError) {
            // 静默处理缓存错误
          }

          return ApiResponse.success(details, statusCode: response.statusCode);
        } catch (parseError) {
          return ApiResponse.error(
              'Bangumi 详情数据解析失败: ${parseError.toString()}');
        }
      } else {
        return ApiResponse.error(
          '获取 Bangumi 详情数据失败: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Bangumi 详情数据请求异常: ${e.toString()}');
    }
  }
}
