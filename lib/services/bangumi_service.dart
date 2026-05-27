import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bangumi.dart';
import 'api_service.dart';
import 'douban_cache_service.dart';

/// Bangumi 数据服务（函数级缓存，一天过期）
class BangumiService {
  static final DoubanCacheService _cache = DoubanCacheService();
  static bool _initialized = false;
  static const String _calendarCacheKey = 'bangumi_calendar_raw_v1';
  static const String _calendarFallbackCacheKey =
      'bangumi_calendar_raw_fallback_v1';
  static Future<http.Response> Function(
    Uri uri,
    Map<String, String> headers,
  )? _calendarHttpGetForTest;
  static Future<List<dynamic>?> Function(
    String cacheKey,
    bool allowExpired,
  )? _calendarCacheReaderForTest;
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

  /// 重置测试注入状态。
  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
    _calendarHttpGetForTest = null;
    _calendarCacheReaderForTest = null;
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

  /// 获取当天的新番放送（根据当前星期几）
  static Future<ApiResponse<List<BangumiItem>>> getTodayCalendar(
    BuildContext context,
  ) async {
    final weekday = DateTime.now().weekday; // 1..7
    return getCalendarByWeekday(context, weekday);
  }

  /// 获取指定星期的新番放送
  static Future<ApiResponse<List<BangumiItem>>> getCalendarByWeekday(
    BuildContext context,
    int weekday, // 1..7 (Monday..Sunday)
  ) async {
    await _initCache();

    // 先尝试读取原始数组缓存
    final cachedItems = await _getCachedCalendarItems(
      weekday,
      allowExpired: false,
    );
    if (cachedItems != null) {
      return ApiResponse.success(cachedItems);
    }

    // 未命中缓存，请求接口
    try {
      const apiUrl = 'https://api.bgm.tv/calendar';
      final headers = {
        'User-Agent':
            'senshinya/selene/1.0.0 (Android) (http://github.com/senshinya/selene)',
        'Accept': 'application/json',
      };

      final uri = Uri.parse(apiUrl);
      final response = await (_calendarHttpGetForTest?.call(uri, headers) ??
              http.get(uri, headers: headers))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        // 解析所有星期数据
        final List<BangumiCalendarResponse> calendarData = responseData
            .map((item) =>
                BangumiCalendarResponse.fromJson(item as Map<String, dynamic>))
            .toList();

        BangumiCalendarResponse? targetDay;
        for (final day in calendarData) {
          if (day.weekday.id == weekday) {
            targetDay = day;
            break;
          }
        }

        final items = targetDay?.items ?? <BangumiItem>[];

        // 写入接口级缓存：原始数组
        try {
          await _cache.set(
            _calendarCacheKey,
            responseData,
            const Duration(days: 1),
          );
          await _cache.set(
            _calendarFallbackCacheKey,
            responseData,
            const Duration(days: 14),
          );
        } catch (_) {}

        return ApiResponse.success(items, statusCode: response.statusCode);
      } else {
        final staleItems = await _getFallbackCalendarItems(weekday);
        if (staleItems != null) {
          return ApiResponse.success(staleItems);
        }
        return ApiResponse.error(
          '获取 Bangumi 日历失败: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      final staleItems = await _getFallbackCalendarItems(weekday);
      if (staleItems != null) {
        return ApiResponse.success(staleItems);
      }
      return ApiResponse.error('Bangumi 数据请求异常: ${e.toString()}');
    }
  }

  /// 读取网络失败时的最后可用日历。
  static Future<List<BangumiItem>?> _getFallbackCalendarItems(
      int weekday) async {
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
        return null;
      }

      final calendar = cachedRaw
          .map(
            (item) => BangumiCalendarResponse.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      BangumiCalendarResponse? targetDay;
      for (final day in calendar) {
        if (day.weekday.id == weekday) {
          targetDay = day;
          break;
        }
      }
      return targetDay?.items ?? <BangumiItem>[];
    } catch (_) {
      return null;
    }
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
