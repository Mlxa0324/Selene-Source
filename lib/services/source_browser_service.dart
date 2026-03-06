import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/search_resource.dart';
import 'api_service.dart';
import 'local_mode_storage_service.dart';
import 'user_data_service.dart';

class SourceBrowserCategory {
  final String id;
  final String name;
  final String? parentId;

  const SourceBrowserCategory({
    required this.id,
    required this.name,
    this.parentId,
  });
}

class SourceBrowserVideo {
  final String id;
  final String title;
  final String poster;
  final String year;
  final String remarks;
  final int? doubanId;

  const SourceBrowserVideo({
    required this.id,
    required this.title,
    required this.poster,
    required this.year,
    required this.remarks,
    this.doubanId,
  });
}

class SourceBrowserPageResult {
  final List<SourceBrowserVideo> videos;
  final int page;
  final bool hasMore;

  const SourceBrowserPageResult({
    required this.videos,
    required this.page,
    required this.hasMore,
  });
}

class SourceBrowserService {
  static const int _defaultPageSize = 20;
  static const _allCategoryAliases = {
    '',
    '*',
    'all',
    '0',
    '-1',
    '全部',
    '不限',
    '全部分类',
  };

  static Future<List<SearchResource>> getAvailableSources() async {
    final isLocalMode = await UserDataService.getIsLocalMode();
    final allSources = isLocalMode
        ? await LocalModeStorageService.getSearchSources()
        : await ApiService.getSearchResources();
    return allSources
        .where((item) => !item.disabled && item.api.trim().isNotEmpty)
        .toList();
  }

  static Future<List<SourceBrowserCategory>> fetchCategories(
      SearchResource source) async {
    final uri = _buildApiUri(source.api, {
      'ac': 'class',
    });
    final payload = await _fetchJson(uri);
    return _extractCategories(payload);
  }

  static Future<SourceBrowserPageResult> fetchVideos({
    required SearchResource source,
    required String categoryId,
    required int page,
  }) async {
    final normalizedCategoryId = _normalizeCategoryId(categoryId);
    final params = <String, String>{
      'ac': 'videolist',
      'pg': '$page',
    };
    if (normalizedCategoryId.isNotEmpty) {
      params['t'] = normalizedCategoryId;
    }

    final uri = _buildApiUri(source.api, params);
    final payload = await _fetchJson(uri);
    final list = _extractVideoList(payload);
    final videos = list.map(_toVideo).whereType<SourceBrowserVideo>().toList();
    final hasMore = _inferHasMore(
      payload: payload,
      requestedPage: page,
      fetchedCount: videos.length,
      currentVideoCount: ((page - 1) * _defaultPageSize) + videos.length,
      defaultPageSize: _defaultPageSize,
    );
    return SourceBrowserPageResult(videos: videos, page: page, hasMore: hasMore);
  }

  static Uri _buildApiUri(String api, Map<String, String> extraParams) {
    var uri = Uri.parse(api.trim());
    final merged = <String, String>{};
    merged.addAll(uri.queryParameters);
    merged.addAll(extraParams);
    uri = uri.replace(queryParameters: merged);
    return uri;
  }

  static Future<dynamic> _fetchJson(Uri uri) async {
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json,text/plain,*/*',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('请求失败: ${response.statusCode}');
    }

    final decoded = utf8.decode(response.bodyBytes, allowMalformed: true);
    return json.decode(decoded);
  }

  static String _normalizeCategoryId(String? categoryId) {
    if (categoryId == null) return '';
    final raw = categoryId.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (_allCategoryAliases.contains(raw) || _allCategoryAliases.contains(lower)) {
      return '';
    }
    return raw;
  }

  static List<dynamic> _toArray(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList();
    if (value is String) {
      try {
        final decoded = json.decode(value);
        return _toArray(decoded);
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static List<SourceBrowserCategory> _extractCategories(dynamic payload) {
    final candidates = <dynamic>[];
    if (payload is List) {
      candidates.add(payload);
    }
    if (payload is Map) {
      candidates.addAll([
        payload['class'],
        payload['classes'],
        payload['class_list'],
        payload['classlist'],
        payload['list'],
        payload['typelist'],
      ]);
      final data = payload['data'];
      if (data is Map) {
        candidates.addAll([
          data['class'],
          data['classes'],
          data['class_list'],
          data['classlist'],
          data['list'],
          data['typelist'],
        ]);
      } else {
        candidates.add(data);
      }
    }

    final map = <String, SourceBrowserCategory>{};
    for (final candidate in candidates) {
      for (final item in _toArray(candidate)) {
        final parsed = _toCategory(item);
        if (parsed == null) continue;
        map['${parsed.id}::${parsed.name}'] = parsed;
      }
    }
    return map.values.toList();
  }

  static SourceBrowserCategory? _toCategory(dynamic value) {
    if (value is! Map) return null;
    String? typeId = _toScalar(value['type_id']) ??
        _toScalar(value['typeId']) ??
        _toScalar(value['id']) ??
        _toScalar(value['tid']);
    String? typeName = _toScalar(value['type_name']) ??
        _toScalar(value['typeName']) ??
        _toScalar(value['name']) ??
        _toScalar(value['type']);
    if (typeId == null || typeName == null) {
      return null;
    }
    return SourceBrowserCategory(
      id: typeId,
      name: typeName,
      parentId: _toScalar(value['type_pid']) ??
          _toScalar(value['typePid']) ??
          _toScalar(value['pid']),
    );
  }

  static String? _toScalar(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static List<dynamic> _extractVideoList(dynamic payload) {
    if (payload is Map) {
      final list = payload['list'];
      if (list is List) return list;
      final data = payload['data'];
      if (data is Map && data['list'] is List) {
        return data['list'] as List<dynamic>;
      }
    }
    return [];
  }

  static SourceBrowserVideo? _toVideo(dynamic value) {
    if (value is! Map) return null;
    final id = _toScalar(value['vod_id']) ?? _toScalar(value['id']) ?? '';
    final title = _toScalar(value['vod_name']) ?? _toScalar(value['title']) ?? '';
    if (id.isEmpty || title.isEmpty) {
      return null;
    }
    return SourceBrowserVideo(
      id: id,
      title: title,
      poster: _toScalar(value['vod_pic']) ?? _toScalar(value['poster']) ?? '',
      year: _toScalar(value['vod_year']) ?? _toScalar(value['year']) ?? '',
      remarks: _toScalar(value['vod_remarks']) ?? _toScalar(value['remarks']) ?? '',
      doubanId: int.tryParse(
        _toScalar(value['vod_douban_id']) ?? _toScalar(value['douban_id']) ?? '',
      ),
    );
  }

  static bool _inferHasMore({
    required dynamic payload,
    required int requestedPage,
    required int fetchedCount,
    required int currentVideoCount,
    required int defaultPageSize,
  }) {
    if (payload is! Map) {
      return fetchedCount >= defaultPageSize;
    }
    final total = _toInt(payload['total']);
    if (total != null) {
      return currentVideoCount < total;
    }
    final pageCount = _toInt(payload['pagecount']);
    if (pageCount != null) {
      final responsePage = _toInt(payload['page']) ?? requestedPage;
      return responsePage < pageCount;
    }
    final pageSize =
        _toInt(payload['limit']) ?? _toInt(payload['page_size']) ?? defaultPageSize;
    return fetchedCount >= pageSize;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is num) return value >= 0 ? value.floor() : null;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed >= 0 ? parsed : null;
    }
    return null;
  }
}
