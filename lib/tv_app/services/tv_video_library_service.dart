import 'package:flutter/material.dart';
import 'package:selene/models/favorite_item.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';

/// TV 视频库数据服务。
///
/// 统一封装播放历史与收藏夹的数据读取和模型转换，避免首页和独立页面各自维护一套逻辑。
class TvVideoLibraryService {
  /// TV 视频库服务不需要实例化。
  const TvVideoLibraryService._();

  /// 加载播放历史列表。
  static Future<List<VideoInfo>> loadHistory(BuildContext context) async {
    final cacheService = PageCacheService();
    try {
      final result = await cacheService.getPlayRecords(context);
      return (result.data ?? <PlayRecord>[])
          .map(VideoInfo.fromPlayRecord)
          .toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 直接从接口加载播放历史列表。
  ///
  /// TV 首页“继续观看”要优先展示远端最新状态，不能只依赖缓存命中。
  static Future<List<VideoInfo>> loadHistoryDirect(BuildContext context) async {
    final cacheService = PageCacheService();
    try {
      final result = await cacheService.getPlayRecordsDirect(context);
      return (result.data ?? <PlayRecord>[])
          .map(VideoInfo.fromPlayRecord)
          .toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载收藏夹列表。
  static Future<List<VideoInfo>> loadFavorites(BuildContext context) async {
    final cacheService = PageCacheService();
    try {
      final result = await cacheService.getFavorites(context);
      return (result.data ?? <FavoriteItem>[])
          .map(_favoriteToVideoInfo)
          .toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 删除单个播放历史。
  static Future<bool> deleteHistoryItem(
    BuildContext context,
    VideoInfo videoInfo,
  ) async {
    final result = await PageCacheService().deletePlayRecord(
      videoInfo.source,
      videoInfo.id,
      context,
    );
    return result.success;
  }

  /// 清空播放历史。
  static Future<bool> clearHistory(BuildContext context) async {
    final result = await PageCacheService().clearPlayRecord(context);
    return result.success;
  }

  /// 删除单个收藏项。
  static Future<bool> deleteFavoriteItem(
    BuildContext context,
    VideoInfo videoInfo,
  ) async {
    final result = await PageCacheService().removeFavorite(
      videoInfo.source,
      videoInfo.id,
      context,
    );
    return result.success;
  }

  /// 清空收藏夹。
  static Future<bool> clearFavorites(BuildContext context) async {
    final result = await PageCacheService().clearFavorites(context);
    return result.success;
  }

  /// 把收藏条目转换为 TV 卡片展示结构。
  static VideoInfo _favoriteToVideoInfo(FavoriteItem item) {
    return VideoInfo(
      id: item.id,
      source: item.source,
      title: item.title,
      sourceName: item.sourceName,
      year: item.year,
      cover: item.cover,
      index: 1,
      totalEpisodes: item.totalEpisodes,
      playTime: 0,
      totalTime: 0,
      saveTime: item.saveTime,
      searchTitle: item.title,
    );
  }
}
