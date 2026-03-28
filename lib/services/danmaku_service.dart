import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/danmaku_model.dart';

/// 弹幕服务 - 负责弹幕 API 调用和设置管理
class DanmakuService {
  static const String _baseApiKey = 'danmaku_base_api';
  static const String _settingsKey = 'danmaku_settings';
  static const String _manualMatchKey = 'danmaku_manual_matches';

  // 搜索缓存
  static final Map<String, (DanmakuSearchResult, DateTime)> _searchCache = {};
  static const Duration _searchCacheTtl = Duration(seconds: 3600);

  /// 清除弹幕搜索缓存
  void clearSearchCache() {
    _searchCache.clear();
  }

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // 单例模式
  static final DanmakuService _instance = DanmakuService._internal();
  factory DanmakuService() => _instance;
  DanmakuService._internal();

  String _manualMatchStorageKey(String source, String id, int episodeIndex) {
    return '${source}_${id}_$episodeIndex';
  }

  Map<String, dynamic> _decodeManualMatches(String? matchesJson) {
    if (matchesJson == null || matchesJson.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(matchesJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return {};
  }

  /// 获取手动匹配的剧集ID
  Future<int?> getManualMatch(
      String source, String id, int episodeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final matches = _decodeManualMatches(prefs.getString(_manualMatchKey));
    final key = _manualMatchStorageKey(source, id, episodeIndex);
    final record = matches[key];

    if (record is num) {
      return record.toInt();
    }
    if (record is Map<String, dynamic>) {
      return (record['episodeId'] as num?)?.toInt();
    }
    if (record is Map) {
      return (record['episodeId'] as num?)?.toInt();
    }
    return null;
  }

  /// 获取手动匹配时使用的搜索词
  Future<String?> getManualMatchQuery(
      String source, String id, int episodeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final matches = _decodeManualMatches(prefs.getString(_manualMatchKey));
    final key = _manualMatchStorageKey(source, id, episodeIndex);
    final record = matches[key];

    if (record is Map<String, dynamic>) {
      final query = record['searchKeyword']?.toString().trim();
      return (query == null || query.isEmpty) ? null : query;
    }
    if (record is Map) {
      final query = record['searchKeyword']?.toString().trim();
      return (query == null || query.isEmpty) ? null : query;
    }
    return null;
  }

  /// 保存手动匹配的剧集ID
  Future<void> saveManualMatch(
      String source, String id, int episodeIndex, int episodeId,
      {String? searchKeyword}) async {
    final prefs = await SharedPreferences.getInstance();
    final matches = _decodeManualMatches(prefs.getString(_manualMatchKey));
    final key = _manualMatchStorageKey(source, id, episodeIndex);
    final cleanKeyword = searchKeyword?.trim();
    matches[key] = {
      'episodeId': episodeId,
      if (cleanKeyword != null && cleanKeyword.isNotEmpty)
        'searchKeyword': cleanKeyword,
    };
    await prefs.setString(_manualMatchKey, jsonEncode(matches));
  }

  /// 清除所有手动匹配记录
  Future<void> clearAllManualMatches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualMatchKey);
  }

  /// 获取 baseApi
  Future<String?> getBaseApi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseApiKey);
  }

  /// 设置 baseApi
  Future<void> setBaseApi(String baseApi) async {
    final prefs = await SharedPreferences.getInstance();
    // 确保 baseApi 以 / 结尾
    if (!baseApi.endsWith('/')) {
      baseApi = '$baseApi/';
    }
    await prefs.setString(_baseApiKey, baseApi);
  }

  /// 获取弹幕设置
  Future<DanmakuSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString != null) {
      try {
        return DanmakuSettings.fromJson(jsonDecode(jsonString));
      } catch (_) {}
    }
    return const DanmakuSettings();
  }

  /// 保存弹幕设置
  Future<void> saveSettings(DanmakuSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// 匹配弹幕源
  /// [fileName] 格式: "影视名 S1E1 @来源"
  Future<DanmakuMatchResult?> matchDanmaku(String fileName) async {
    final baseApi = await getBaseApi();
    if (baseApi == null || baseApi.isEmpty) return null;

    try {
      final response = await _dio.post(
        '${baseApi}api/v2/match',
        data: {'fileName': fileName},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return DanmakuMatchResult.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('弹幕匹配失败: $e');
    }
    return null;
  }

  /// 搜索弹幕剧集
  Future<DanmakuSearchResult?> searchEpisodes(String animeName) async {
    final cleanName = animeName.trim();
    if (cleanName.isEmpty) return null;

    // 检查缓存
    if (_searchCache.containsKey(cleanName)) {
      final (result, timestamp) = _searchCache[cleanName]!;
      if (DateTime.now().difference(timestamp) < _searchCacheTtl) {
        return result;
      } else {
        _searchCache.remove(cleanName);
      }
    }

    final baseApi = await getBaseApi();
    if (baseApi == null || baseApi.isEmpty) return null;

    try {
      final response = await _dio.get(
        '${baseApi}api/v2/search/episodes',
        queryParameters: {'anime': cleanName},
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = DanmakuSearchResult.fromJson(response.data);

        // 存入缓存
        if (result.success) {
          _searchCache[cleanName] = (result, DateTime.now());
        }

        return result;
      }
    } catch (e) {
      debugPrint('搜索弹幕失败: $e');
    }
    return null;
  }

  /// 获取弹幕列表
  Future<List<DanmakuComment>> getDanmakuList(int episodeId) async {
    final baseApi = await getBaseApi();
    if (baseApi == null || baseApi.isEmpty) return [];

    try {
      final response = await _dio.get(
        '${baseApi}api/v2/comment/$episodeId',
        queryParameters: {'format': 'json'},
      );

      if (response.statusCode == 200 && response.data != null) {
        final result = DanmakuListResult.fromJson(response.data);
        // 按时间排序
        result.comments.sort((a, b) => a.time.compareTo(b.time));
        return result.comments;
      }
    } catch (e) {
      debugPrint('获取弹幕列表失败: $e');
    }
    return [];
  }

  /// 构建匹配用的文件名
  /// [title] 影视名
  /// [episodeIndex] 集数索引（从0开始）
  /// [sourceName] 来源名称
  static String buildFileName(
      String title, int? episodeIndex, String? sourceName) {
    final buffer = StringBuffer(title);
    if (episodeIndex != null) {
      buffer.write(' S1E${episodeIndex + 1}');
    }
    if (sourceName != null && sourceName.isNotEmpty) {
      buffer.write(' @$sourceName');
    }
    return buffer.toString();
  }

  /// 将 DanmakuComment 转换为 canvas_danmaku 的 DanmakuContentItem
  static DanmakuContentItem<int> convertToDanmakuItem(DanmakuComment comment) {
    return DanmakuContentItem(
      comment.m,
      type: _parseType(comment.type),
      color: Color(comment.color | 0xFF000000),
    );
  }

  /// 解析弹幕类型
  static DanmakuItemType _parseType(int type) {
    switch (type) {
      case 4:
        return DanmakuItemType.bottom;
      case 5:
        return DanmakuItemType.top;
      default:
        return DanmakuItemType.scroll;
    }
  }
}
