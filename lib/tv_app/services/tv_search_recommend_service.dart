import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';

/// TV 搜索页推荐数据加载函数。
typedef TvSearchRecommendFallbackLoader = Future<List<VideoInfo>> Function();

/// TV 搜索页推荐缓存服务。
///
/// 搜索页推荐不主动额外查详情推荐，而是被动复用最近打开过的两个详情页底部
/// “相关推荐”结果；如果当前还没有详情页沉淀过任何相关推荐，则回退到
/// 热门剧集 + 热门综艺各 10 条组成的兜底推荐列表。
class TvSearchRecommendService {
  /// 服务工具类不需要实例化。
  const TvSearchRecommendService._();

  /// 最多缓存两组详情页相关推荐。
  static const int _maxCachedGroups = 2;

  /// 最近两个详情页相关推荐分组。
  static final List<_TvSearchRecommendGroup> _recommendGroups =
      <_TvSearchRecommendGroup>[];

  /// 记录详情页相关推荐。
  ///
  /// 新分组会插入到顶部；超过两组时，自动淘汰最老的一组。
  static void recordDetailRecommends({
    required VideoInfo videoInfo,
    required List<VideoInfo> recommends,
  }) {
    if (recommends.isEmpty) {
      return;
    }

    final normalizedItems = _dedupeVideos(recommends);
    if (normalizedItems.isEmpty) {
      return;
    }

    final groupKey = _buildGroupKey(videoInfo);
    _recommendGroups.removeWhere((group) => group.key == groupKey);
    _recommendGroups.insert(
      0,
      _TvSearchRecommendGroup(
        key: groupKey,
        videos: normalizedItems,
      ),
    );

    if (_recommendGroups.length > _maxCachedGroups) {
      _recommendGroups.removeRange(_maxCachedGroups, _recommendGroups.length);
    }
  }

  /// 加载搜索页推荐列表。
  ///
  /// 优先返回最近两组详情页相关推荐的合并结果；没有缓存时，再走兜底热门剧集
  /// 与热门综艺列表。
  static Future<List<VideoInfo>> loadSearchRecommends({
    required TvSearchRecommendFallbackLoader fallbackLoader,
  }) async {
    final cachedVideos = _mergeCachedRecommendGroups();
    if (cachedVideos.isNotEmpty) {
      return cachedVideos;
    }
    return _dedupeVideos(await fallbackLoader());
  }

  /// 默认兜底推荐加载逻辑。
  ///
  /// 不主动查电影热门，只拼热门剧集和热门综艺各 10 条。
  static Future<List<VideoInfo>> loadFallbackHotRecommends(
    BuildContext context,
  ) async {
    final cacheService = PageCacheService();

    final tvShowsFuture = cacheService.getHotTvShows(context);
    final hotShowsFuture = cacheService.getHotShows(context);
    final tvShows = await tvShowsFuture;
    final hotShows = await hotShowsFuture;

    final tvVideos =
        (tvShows ?? []).take(10).map((item) => item.toVideoInfo()).toList();
    final showVideos =
        (hotShows ?? []).take(10).map((item) => item.toVideoInfo()).toList();

    return _dedupeVideos([
      ...tvVideos,
      ...showVideos,
    ]);
  }

  /// 测试辅助：清空内存推荐缓存。
  static void clearDebugCache() {
    _recommendGroups.clear();
  }

  /// 合并最近两组详情页相关推荐。
  ///
  /// 新分组在前，组内保留原顺序；跨组重复影片只保留第一次出现的版本。
  static List<VideoInfo> _mergeCachedRecommendGroups() {
    final merged = <VideoInfo>[];
    final seenKeys = <String>{};

    for (final group in _recommendGroups) {
      for (final videoInfo in group.videos) {
        final dedupeKey = _buildVideoKey(videoInfo);
        if (!seenKeys.add(dedupeKey)) {
          continue;
        }
        merged.add(videoInfo);
      }
    }
    return merged;
  }

  /// 对视频列表做稳定去重。
  ///
  /// 搜索页推荐展示更关心“同片是否重复出现”，这里优先按归一化标题去重；
  /// 标题缺失时才回退到 `source + id`。
  static List<VideoInfo> _dedupeVideos(List<VideoInfo> videos) {
    final deduped = <VideoInfo>[];
    final seenKeys = <String>{};
    for (final video in videos) {
      final dedupeKey = _buildVideoKey(video);
      if (dedupeKey.isEmpty || !seenKeys.add(dedupeKey)) {
        continue;
      }
      deduped.add(video);
    }
    return deduped;
  }

  /// 生成详情页推荐分组 Key。
  static String _buildGroupKey(VideoInfo videoInfo) {
    return '${videoInfo.source}::${videoInfo.id}::${_normalizeTitle(videoInfo.title)}';
  }

  /// 生成推荐卡片去重 Key。
  static String _buildVideoKey(VideoInfo videoInfo) {
    final normalizedTitle = _normalizeTitle(videoInfo.title);
    if (normalizedTitle.isNotEmpty) {
      return normalizedTitle;
    }
    if (videoInfo.source.isNotEmpty && videoInfo.id.isNotEmpty) {
      return '${videoInfo.source}::${videoInfo.id}';
    }
    return '';
  }

  /// 归一化标题。
  static String _normalizeTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }
}

/// TV 搜索页推荐分组。
class _TvSearchRecommendGroup {
  /// 创建推荐分组。
  const _TvSearchRecommendGroup({
    required this.key,
    required this.videos,
  });

  /// 分组唯一键。
  final String key;

  /// 当前分组的相关推荐。
  final List<VideoInfo> videos;
}
