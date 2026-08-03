import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';
import 'danmaku_service.dart';
import 'douban_cache_service.dart';
import 'live_service.dart';
import 'page_cache_service.dart';
import 'search_service.dart';
import 'user_data_service.dart';

/// 缓存目录加载函数。
typedef AppCacheDirectoriesLoader = Future<List<Directory>> Function();

/// 可用存储空间加载函数。
typedef AppAvailableStorageLoader = Future<int?> Function();

/// 总存储空间加载函数。
typedef AppTotalStorageLoader = Future<int?> Function();

/// 缓存清理函数。
typedef AppCacheClearer = Future<void> Function();

/// 应用缓存管理服务。
///
/// 只管理图片、临时文件和业务运行缓存，不清理服务器地址、账号、主题、
/// 弹幕配置等持久化设置。
class AppCacheService {
  /// 创建应用缓存管理服务。
  AppCacheService({
    AppCacheDirectoriesLoader? cacheDirectoriesLoader,
    AppAvailableStorageLoader? availableStorageLoader,
    AppTotalStorageLoader? totalStorageLoader,
    AppCacheClearer? businessCacheClearer,
    AppCacheClearer? imageDiskCacheClearer,
  })  : _cacheDirectoriesLoader =
            cacheDirectoriesLoader ?? _defaultCacheDirectories,
        _availableStorageLoader =
            availableStorageLoader ?? _loadAvailableStorageBytes,
        _totalStorageLoader = totalStorageLoader ?? _loadTotalStorageBytes,
        _businessCacheClearer = businessCacheClearer ?? _clearBusinessCaches,
        _imageDiskCacheClearer = imageDiskCacheClearer ?? _clearImageDiskCache;

  /// Android 原生存储空间通道。
  static const MethodChannel _storageChannel = MethodChannel('selene/storage');

  /// 应用默认缓存服务，供图片卡片、启动清理和 TV 设置页共享策略缓存。
  static final AppCacheService instance = AppCacheService();

  /// 低空间阈值，小于 200MB 时避免继续写入图片磁盘缓存。
  static const int lowStorageThresholdBytes = 200 * 1024 * 1024;

  /// 缓存目录加载函数。
  final AppCacheDirectoriesLoader _cacheDirectoriesLoader;

  /// 可用存储空间加载函数。
  final AppAvailableStorageLoader _availableStorageLoader;

  /// 总存储空间加载函数。
  final AppTotalStorageLoader _totalStorageLoader;

  /// 业务缓存清理函数。
  final AppCacheClearer _businessCacheClearer;

  /// 图片磁盘缓存清理函数。
  final AppCacheClearer _imageDiskCacheClearer;

  /// 缓存的图片磁盘写入判断。
  bool? _cachedUseImageDiskCache;

  /// 正在进行的图片磁盘缓存策略读取，合并同一批并发调用。
  Future<bool>? _imageDiskCachePolicyFuture;

  /// 图片缓存策略读取代数，避免清理缓存时旧请求回写结果。
  int _imageDiskCachePolicyGeneration = 0;

  /// 启动进入 App 前执行缓存整理。
  ///
  /// 常规启动会清理业务运行缓存和内存图片缓存；当系统剩余空间低于
  /// [lowStorageThresholdBytes] 时，额外清理图片磁盘缓存并让后续图片不落盘。
  Future<void> prepareBeforeAppEnter() async {
    await _businessCacheClearer();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final shouldUseDiskCache = await shouldUseImageDiskCache();
    if (!shouldUseDiskCache) {
      await _imageDiskCacheClearer();
    }
  }

  /// 判断当前是否允许图片写入磁盘缓存。
  Future<bool> shouldUseImageDiskCache() {
    if (_cachedUseImageDiskCache != null) {
      return Future<bool>.value(_cachedUseImageDiskCache!);
    }

    return _imageDiskCachePolicyFuture ??= _loadImageDiskCachePolicy();
  }

  /// 读取一次图片磁盘缓存策略，并复用给同一批卡片。
  Future<bool> _loadImageDiskCachePolicy() async {
    final generation = _imageDiskCachePolicyGeneration;
    try {
      final availableBytes = await _availableStorageLoader();
      final useDiskCache =
          availableBytes == null || availableBytes >= lowStorageThresholdBytes;
      if (generation == _imageDiskCachePolicyGeneration) {
        _cachedUseImageDiskCache = useDiskCache;
      }
      return useDiskCache;
    } finally {
      if (generation == _imageDiskCachePolicyGeneration) {
        _imageDiskCachePolicyFuture = null;
      }
    }
  }

  /// 读取系统存储空间摘要。
  Future<AppStorageSummary?> loadStorageSummary() async {
    final availableBytes = await _availableStorageLoader();
    final totalBytes = await _totalStorageLoader();
    if (availableBytes == null && totalBytes == null) {
      return null;
    }

    return AppStorageSummary(
      availableBytes: availableBytes,
      totalBytes: totalBytes,
      lowStorageThresholdBytes: lowStorageThresholdBytes,
    );
  }

  /// 计算当前缓存目录占用大小。
  Future<int> calculateCacheSizeBytes() async {
    final directories = await _cacheDirectoriesLoader();
    var totalBytes = 0;
    for (final directory in directories) {
      totalBytes += await _calculateDirectorySize(directory);
    }
    return totalBytes;
  }

  /// 清理所有缓存。
  ///
  /// 该方法会清理业务运行缓存、豆瓣缓存、HLS 脚本缓存、临时目录和图片磁盘缓存，
  /// 但不会清除登录状态、服务器地址、账号密码、主题色、弹幕配置等设置。
  Future<void> clearAllCaches() async {
    await _businessCacheClearer();
    await _imageDiskCacheClearer();

    final directories = await _cacheDirectoriesLoader();
    for (final directory in directories) {
      await _clearDirectoryContents(directory);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _cachedUseImageDiskCache = null;
    _imageDiskCachePolicyFuture = null;
    _imageDiskCachePolicyGeneration += 1;
  }

  /// 格式化缓存大小。
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// 加载默认缓存目录。
  static Future<List<Directory>> _defaultCacheDirectories() async {
    final directories = <Directory>[];
    final tempDirectory = await getTemporaryDirectory();
    directories.add(tempDirectory);

    final documentsDirectory = await getApplicationDocumentsDirectory();
    directories.add(Directory('${documentsDirectory.path}/douban_cache'));
    return directories;
  }

  /// 读取系统可用存储空间。
  static Future<int?> _loadAvailableStorageBytes() async {
    try {
      return await _storageChannel
          .invokeMethod<int>('getAvailableStorageBytes');
    } on MissingPluginException {
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('读取可用存储空间失败: $e');
      }
      return null;
    }
  }

  /// 读取系统总存储空间。
  static Future<int?> _loadTotalStorageBytes() async {
    try {
      return await _storageChannel.invokeMethod<int>('getTotalStorageBytes');
    } on MissingPluginException {
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('读取总存储空间失败: $e');
      }
      return null;
    }
  }

  /// 清理默认业务运行缓存。
  static Future<void> _clearBusinessCaches() async {
    LiveService.clearAllCache();
    PageCacheService().clearAllCache();
    ApiService.clearSourcesDataCache();
    SearchService.clearCache();
    DanmakuService().clearSearchCache();
    await DoubanCacheService().clearAll();
    await UserDataService.clearHlsJsCache();
  }

  /// 清理图片磁盘缓存。
  static Future<void> _clearImageDiskCache() async {
    await DefaultCacheManager().emptyCache();
  }

  /// 计算目录大小。
  static Future<int> _calculateDirectorySize(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    var totalBytes = 0;
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          totalBytes += await entity.length();
        } catch (_) {
          // 文件可能在统计期间被系统删除，忽略即可。
        }
      }
    }
    return totalBytes;
  }

  /// 清空目录内容但保留目录本身。
  static Future<void> _clearDirectoryContents(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity
        in directory.list(recursive: false, followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // 部分系统文件可能暂时被占用，跳过不影响主要清理流程。
      }
    }
  }
}

/// 系统存储空间摘要。
class AppStorageSummary {
  /// 创建系统存储空间摘要。
  const AppStorageSummary({
    required this.availableBytes,
    required this.totalBytes,
    required this.lowStorageThresholdBytes,
  });

  /// 剩余可用空间，无法读取时为空。
  final int? availableBytes;

  /// 系统总空间，无法读取时为空。
  final int? totalBytes;

  /// 低空间告警阈值。
  final int lowStorageThresholdBytes;

  /// 是否已经低于安全剩余空间。
  bool get isLowStorage =>
      availableBytes != null && availableBytes! < lowStorageThresholdBytes;
}
