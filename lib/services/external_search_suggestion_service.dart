import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 外部站点首字母联想服务。
///
/// 负责聚合腾讯、爱奇艺和芒果的公开联想接口，
/// 将首字母查询统一转换为去重后的片名列表。
class ExternalSearchSuggestionService {
  /// 创建外部站点首字母联想服务。
  ///
  /// [httpClient] 允许在测试中注入假客户端，避免依赖真实网络。
  ExternalSearchSuggestionService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// 请求超时时间。
  static const Duration _requestTimeout = Duration(seconds: 5);

  /// HTTP 客户端。
  final http.Client _httpClient;

  /// 聚合首字母联想结果。
  ///
  /// 只有纯英文字母或数字查询才会触发外部联想，避免中文整词搜索误走首字母接口。
  Future<List<String>> fetchSuggestions(String query) async {
    final normalizedQuery = query.trim().toUpperCase();
    if (normalizedQuery.isEmpty ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(normalizedQuery)) {
      return <String>[];
    }

    _logSuggestionSummary(
      query: normalizedQuery,
      stage: '开始请求',
      platformLogs: const <_SuggestionPlatformLog>[],
      mergedSuggestions: const <String>[],
      dedupedSuggestions: const <String>[],
    );

    final platformRequests = <_SuggestionPlatformRequest>[
      _SuggestionPlatformRequest(
        platform: '腾讯视频',
        future: _fetchTencentSuggestions(normalizedQuery),
      ),
      _SuggestionPlatformRequest(
        platform: '爱奇艺',
        future: _fetchIqiyiSuggestions(normalizedQuery.toLowerCase()),
      ),
      _SuggestionPlatformRequest(
        platform: '芒果 TV',
        future: _fetchMgtvSuggestions(normalizedQuery.toLowerCase()),
      ),
    ];

    final platformLogs = <_SuggestionPlatformLog>[];
    final mergedSuggestions = <String>[];

    for (final request in platformRequests) {
      final suggestions = await request.future;
      platformLogs.add(
        _SuggestionPlatformLog(
          platform: request.platform,
          suggestions: suggestions,
        ),
      );
      mergedSuggestions.addAll(suggestions);
    }

    final dedupedSuggestions = _dedupeSuggestions(mergedSuggestions);
    _logSuggestionSummary(
      query: normalizedQuery,
      stage: '请求完成',
      platformLogs: platformLogs,
      mergedSuggestions: mergedSuggestions,
      dedupedSuggestions: dedupedSuggestions,
    );
    return dedupedSuggestions;
  }

  /// 请求腾讯视频联想词。
  Future<List<String>> _fetchTencentSuggestions(String query) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse(
              'https://actapi.video.qq.com/'
              'trpc.videosearch.smartboxServer.SugRecallHttp/GetSugHttp'
              '?vplatform=2',
            ),
            headers: const <String, String>{
              'accept': 'application/json',
              'content-type': 'application/json',
              'origin': 'https://film.qq.com',
              'referer': 'https://film.qq.com/',
              'user-agent': _defaultUserAgent,
            },
            body: json.encode(<String, dynamic>{
              'query': query,
              'page_num': 0,
              'page_size': 10,
              'scene_id': 5,
              'sug_id': 'selene_$query',
              'auth_info': <String, String>{
                'app_id': '3172',
                'app_key': 'lGhFIPeD3HsO9xEp',
              },
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return <String>[];
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic> resultList =
          ((data['data'] as Map<String, dynamic>?)?['result_list']
                  as Map<String, dynamic>?) ??
              const <String, dynamic>{};
      final List<dynamic> rawItems =
          (resultList['item_list'] as List<dynamic>?) ?? <dynamic>[];

      final suggestions = <String>[];
      for (final rawItem in rawItems) {
        if (rawItem is! Map<String, dynamic>) {
          continue;
        }
        final view = rawItem['view'];
        if (view is! Map<String, dynamic>) {
          continue;
        }
        final lines = view['lines'];
        if (lines is! List<dynamic> || lines.isEmpty) {
          continue;
        }
        final firstLine = lines.first;
        if (firstLine is! Map<String, dynamic>) {
          continue;
        }
        final text = firstLine['text']?.toString() ?? '';
        final cleanText = text.replaceAll(RegExp(r'</?em>'), '').trim();
        if (cleanText.isNotEmpty) {
          suggestions.add(cleanText);
        }
      }
      return suggestions;
    } catch (_) {
      return <String>[];
    }
  }

  /// 请求爱奇艺联想词。
  Future<List<String>> _fetchIqiyiSuggestions(String query) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse(
              'https://mesh.if.iqiyi.com/portal/lw/search/searchKeyWord'
              '?key=$query'
              '&version=17.054.25384'
              '&deviceId=6ab07a4f0966c704610f0448494b67cb'
              '&appMode='
              '&os='
              '&pcv=17.054.25384',
            ),
            headers: const <String, String>{
              'accept': '*/*',
              'origin': 'https://www.iqiyi.com',
              'referer': 'https://www.iqiyi.com/',
              'user-agent': _defaultUserAgent,
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return <String>[];
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawItems =
          ((data['data'] as Map<String, dynamic>?)?['keyWordData']
                  as List<dynamic>?) ??
              <dynamic>[];

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => item['name']?.toString().trim() ?? '')
          .where((title) => title.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  /// 请求芒果 TV 联想词。
  Future<List<String>> _fetchMgtvSuggestions(String query) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse(
              'https://mobileso.bz.mgtv.com/pc/suggest/v1'
              '?allowedRC=1'
              '&src=mgtv'
              '&did=5bbe5b75-33e3-471c-87df-de12d62291f2'
              '&pc=1'
              '&q=$query'
              '&_support=10000000',
            ),
            headers: const <String, String>{
              'accept': 'application/json, text/plain, */*',
              'origin': 'https://www.mgtv.com',
              'referer': 'https://www.mgtv.com/',
              'user-agent': _defaultUserAgent,
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        return <String>[];
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> rawItems =
          ((data['data'] as Map<String, dynamic>?)?['suggest']
                  as List<dynamic>?) ??
              <dynamic>[];

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => item['title']?.toString().trim() ?? '')
          .where((title) => title.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  /// 对聚合后的联想结果做有序去重。
  List<String> _dedupeSuggestions(List<String> suggestions) {
    final orderedSuggestions = <String>[];
    final seenSuggestions = <String>{};
    for (final suggestion in suggestions) {
      final normalizedSuggestion = suggestion
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (normalizedSuggestion.isEmpty ||
          !seenSuggestions.add(normalizedSuggestion)) {
        continue;
      }
      orderedSuggestions.add(normalizedSuggestion);
    }
    return orderedSuggestions;
  }

  /// 打印首字母联想聚合统计。
  ///
  /// 方便在控制台快速查看各平台命中词、原始总数和最终去重结果。
  void _logSuggestionSummary({
    required String query,
    required String stage,
    required List<_SuggestionPlatformLog> platformLogs,
    required List<String> mergedSuggestions,
    required List<String> dedupedSuggestions,
  }) {
    final buffer = StringBuffer()
      ..writeln('[首字母联想] $stage')
      ..writeln('[首字母联想] 查询词: $query')
      ..writeln('[首字母联想] 接入平台数: ${platformLogs.length}');

    for (final platformLog in platformLogs) {
      buffer
        ..writeln(
          '[首字母联想] ${platformLog.platform} 命中数量: ${platformLog.suggestions.length}',
        )
        ..writeln(
          '[首字母联想] ${platformLog.platform} 命中词: ${platformLog.suggestions.join(' | ')}',
        );
    }

    if (platformLogs.isNotEmpty) {
      buffer
        ..writeln('[首字母联想] 聚合前总数量: ${mergedSuggestions.length}')
        ..writeln('[首字母联想] 去重后数量: ${dedupedSuggestions.length}')
        ..writeln(
          '[首字母联想] 最终联想词: ${dedupedSuggestions.join(' | ')}',
        );
    }

    debugPrint(buffer.toString().trimRight());
  }

  /// 默认浏览器请求头 UA。
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/148.0.0.0 Safari/537.36';
}

/// 单个平台的联想请求描述。
class _SuggestionPlatformRequest {
  /// 创建单个平台联想请求。
  const _SuggestionPlatformRequest({
    required this.platform,
    required this.future,
  });

  /// 平台名称。
  final String platform;

  /// 平台请求任务。
  final Future<List<String>> future;
}

/// 单个平台的联想结果日志。
class _SuggestionPlatformLog {
  /// 创建单个平台联想结果日志。
  const _SuggestionPlatformLog({
    required this.platform,
    required this.suggestions,
  });

  /// 平台名称。
  final String platform;

  /// 当前平台返回的联想词。
  final List<String> suggestions;
}
