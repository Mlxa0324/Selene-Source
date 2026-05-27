import 'package:flutter/material.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';

/// TV 播放记录服务。
///
/// 对齐手机端播放器的播放记录策略：先保存新记录，保存成功后再清理其它源。
class TvPlayRecordService {
  /// 私有构造，避免工具类被实例化。
  const TvPlayRecordService._();

  /// 判断入口视频是否带有续播记录。
  static bool hasResumeHint(VideoInfo videoInfo) {
    return videoInfo.playTime > 0 || videoInfo.index > 1;
  }

  /// 根据播放记录换算安全选集下标。
  static int episodeIndexFromVideoInfo(VideoInfo videoInfo, int totalEpisodes) {
    if (totalEpisodes <= 0) {
      return 0;
    }
    final rawIndex = videoInfo.index > 0 ? videoInfo.index - 1 : 0;
    return rawIndex.clamp(0, totalEpisodes - 1).toInt();
  }

  /// 根据播放记录换算续播时间。
  static Duration? resumePositionFromVideoInfo(VideoInfo videoInfo) {
    if (videoInfo.playTime < 1) {
      return null;
    }
    return Duration(seconds: videoInfo.playTime);
  }

  /// 创建当前播放进度记录。
  static PlayRecord buildRecord({
    required VideoInfo videoInfo,
    required SearchResult detail,
    required int episodeIndex,
    required int playTime,
    required int totalTime,
    DateTime? now,
  }) {
    final safePlayTime = playTime < 0 ? 0 : playTime;
    final safeTotalTime =
        totalTime > safePlayTime ? totalTime : safePlayTime + 1;
    final safeEpisodeNumber = episodeIndex + 1;
    final recordTime = now ?? DateTime.now();

    return PlayRecord(
      id: detail.id,
      source: detail.source,
      title: detail.title,
      sourceName: detail.sourceName,
      year: detail.year,
      cover: detail.poster,
      index: safeEpisodeNumber,
      totalEpisodes: detail.episodes.length,
      playTime: safePlayTime,
      totalTime: safeTotalTime,
      saveTime: recordTime.millisecondsSinceEpoch,
      searchTitle: resolveSearchTitle(videoInfo),
    );
  }

  /// 解析播放记录匹配用的搜索标题。
  ///
  /// 对齐手机端语义：优先沿用入口搜索标题，只有为空时才回退到影片标题。
  static String resolveSearchTitle(VideoInfo videoInfo) {
    return videoInfo.searchTitle.trim().isNotEmpty
        ? videoInfo.searchTitle
        : videoInfo.title;
  }

  /// 保存当前播放进度。
  static Future<bool> saveRecord(
    BuildContext context,
    PlayRecord playRecord,
  ) async {
    try {
      final result = await PageCacheService().savePlayRecord(
        playRecord,
        context,
      );
      return result.success;
    } catch (error) {
      debugPrint('TV 保存播放记录异常: $error');
      return false;
    }
  }

  /// 判断播放记录是否属于当前影片的其它源。
  static bool isSameVideoForPlayRecord({
    required PlayRecord record,
    required SearchResult targetSource,
    required String searchTitle,
  }) {
    final targetTitle = _normalizeRecordKey(targetSource.title);
    final recordTitle = _normalizeRecordKey(record.title);
    final targetSearchTitle = _normalizeRecordKey(searchTitle);
    final recordSearchTitle = _normalizeRecordKey(record.searchTitle);

    final titleMatched = targetTitle.isNotEmpty && recordTitle == targetTitle;
    final searchTitleMatched =
        targetSearchTitle.isNotEmpty && recordSearchTitle == targetSearchTitle;

    if (!titleMatched && !searchTitleMatched) {
      return false;
    }

    if (_isUnknownYear(targetSource.year) || _isUnknownYear(record.year)) {
      return true;
    }

    return targetSource.year.trim().toLowerCase() ==
        record.year.trim().toLowerCase();
  }

  /// 清理同影片其它源播放记录。
  static Future<void> cleanupOtherSourceRecords({
    required BuildContext context,
    required SearchResult keepSource,
    required String searchTitle,
  }) async {
    try {
      final cacheService = PageCacheService();
      final recordsResult = await cacheService.getPlayRecords(context);
      final records = recordsResult.data;
      if (!recordsResult.success || records == null || records.isEmpty) {
        return;
      }

      final toDelete = records
          .where(
            (record) =>
                !(record.source == keepSource.source &&
                    record.id == keepSource.id) &&
                isSameVideoForPlayRecord(
                  record: record,
                  targetSource: keepSource,
                  searchTitle: searchTitle,
                ),
          )
          .toList();
      if (toDelete.isEmpty) {
        return;
      }

      for (final record in toDelete) {
        final result = await cacheService.deletePlayRecord(
          record.source,
          record.id,
          // 调用方负责 mounted 保护，这里需要沿用同一个 context 调服务层删除旧源记录。
          // ignore: use_build_context_synchronously
          context,
        );
        if (!result.success) {
          debugPrint('TV 清理其它源播放记录失败: ${record.source}+${record.id}');
        }
      }
    } catch (error) {
      debugPrint('TV 清理其它源播放记录异常: $error');
    }
  }

  /// 按当前入口视频语义清理同影片其它源播放记录。
  ///
  /// 统一复用手机端同片判断关键字，避免详情页和全屏页各自拼接不一致。
  static Future<void> cleanupOtherSourceRecordsForVideo({
    required BuildContext context,
    required SearchResult keepSource,
    required VideoInfo videoInfo,
  }) {
    return cleanupOtherSourceRecords(
      context: context,
      keepSource: keepSource,
      searchTitle: resolveSearchTitle(videoInfo),
    );
  }

  /// 标准化同影片匹配关键字。
  static String _normalizeRecordKey(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  /// 判断年份是否缺失。
  static bool _isUnknownYear(String year) {
    final normalized = year.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'unknown' || normalized == '未知';
  }
}
