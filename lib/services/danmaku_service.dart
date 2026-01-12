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

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // 单例模式
  static final DanmakuService _instance = DanmakuService._internal();
  factory DanmakuService() => _instance;
  DanmakuService._internal();

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
    final baseApi = await getBaseApi();
    if (baseApi == null || baseApi.isEmpty) return null;

    try {
      final response = await _dio.get(
        '${baseApi}api/v2/search/episodes',
        queryParameters: {'anime': animeName},
      );

      if (response.statusCode == 200 && response.data != null) {
        return DanmakuSearchResult.fromJson(response.data);
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
  static String buildFileName(String title, int? episodeIndex, String? sourceName) {
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
