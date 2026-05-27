import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/services/danmaku_service.dart';

/// TV 端弹幕加载结果。
///
/// 统一承载命中的弹幕剧集 ID 和对应的弹幕列表，
/// 方便 TV 全屏播放器复用自动匹配与手动匹配的同一条渲染链路。
class TvDanmakuLoadResult {
  /// 创建 TV 端弹幕加载结果。
  const TvDanmakuLoadResult({
    required this.episodeId,
    required this.comments,
  });

  /// 命中的弹幕剧集 ID。
  final int episodeId;

  /// 当前剧集的弹幕列表。
  final List<DanmakuComment> comments;
}

/// TV 端弹幕服务。
///
/// TV 侧复用手机端/PC 端的弹幕数据服务与持久化存储，
/// 但把自动匹配、手动匹配和渲染参数拼装收口到 TV 专属文件里，
/// 避免 TV 播放器直接依赖普通端页面实现。
class TvDanmakuService {
  /// 创建 TV 端弹幕服务。
  TvDanmakuService({
    DanmakuService? baseService,
  }) : _baseService = baseService ?? DanmakuService();

  /// 底层共享弹幕服务。
  final DanmakuService _baseService;

  /// 读取当前弹幕设置。
  Future<DanmakuSettings> getSettings() {
    return _baseService.getSettings();
  }

  /// 保存当前弹幕设置。
  Future<void> saveSettings(DanmakuSettings settings) {
    return _baseService.saveSettings(settings);
  }

  /// 查询当前弹幕服务器地址。
  Future<String?> getBaseApi() {
    return _baseService.getBaseApi();
  }

  /// 自动优先加载当前剧集的弹幕。
  ///
  /// 先尝试当前源当前集的手动匹配缓存；
  /// 如果未命中，再按 TV 端当前标题和选集信息构造自动匹配候选名逐个尝试。
  Future<TvDanmakuLoadResult?> loadDanmaku({
    required String currentSource,
    required String currentId,
    required int episodeIndex,
    required String videoTitle,
    required String sourceName,
    String? episodeTitle,
  }) async {
    final baseApi = await _baseService.getBaseApi();
    if (baseApi == null || baseApi.isEmpty) {
      return null;
    }

    int? episodeId;

    // 优先命中当前源当前集的手动匹配结果，保证用户修正后稳定复用。
    if (currentSource.isNotEmpty && currentId.isNotEmpty) {
      episodeId = await _baseService.getManualMatch(
        currentSource,
        currentId,
        episodeIndex,
      );
    }

    // 手动匹配未命中时，退回自动匹配候选名列表。
    if (episodeId == null) {
      final candidates = buildMatchFileNames(
        videoTitle: videoTitle,
        sourceName: sourceName,
        episodeIndex: episodeIndex,
        episodeTitle: episodeTitle,
      );
      for (final candidate in candidates) {
        final matchResult = await _baseService.matchDanmaku(candidate);
        if (matchResult == null ||
            !matchResult.success ||
            !matchResult.isMatched ||
            matchResult.matches.isEmpty) {
          continue;
        }
        episodeId = matchResult.matches.first.episodeId;
        break;
      }
    }

    if (episodeId == null) {
      return null;
    }

    final comments = await _baseService.getDanmakuList(episodeId);
    return TvDanmakuLoadResult(
      episodeId: episodeId,
      comments: comments,
    );
  }

  /// 按弹幕剧集 ID 直接拉取弹幕列表。
  Future<List<DanmakuComment>> loadDanmakuByEpisodeId(int episodeId) {
    return _baseService.getDanmakuList(episodeId);
  }

  /// 查询弹幕剧集搜索结果。
  Future<DanmakuSearchResult?> searchEpisodes(String query) {
    return _baseService.searchEpisodes(query);
  }

  /// 保存 TV 手动匹配结果。
  ///
  /// 命中某一集后，同时把该搜索词记到标题级缓存里，
  /// 方便后续同片名复用搜索上下文。
  Future<void> saveManualSelection({
    required String currentSource,
    required String currentId,
    required int episodeIndex,
    required int episodeId,
    required String searchKeyword,
    required String fallbackTitle,
    List<DanmakuSearchEpisode>? orderedEpisodes,
    int? selectedEpisodeOffset,
  }) async {
    if (currentSource.isNotEmpty && currentId.isNotEmpty) {
      if (orderedEpisodes != null &&
          orderedEpisodes.isNotEmpty &&
          selectedEpisodeOffset != null &&
          selectedEpisodeOffset >= 0 &&
          selectedEpisodeOffset < orderedEpisodes.length) {
        await _baseService.saveManualMatchSeries(
          currentSource,
          currentId,
          episodeIndex,
          orderedEpisodes.map((episode) => episode.episodeId).toList(),
          selectedEpisodeOffset: selectedEpisodeOffset,
          searchKeyword: searchKeyword,
        );
      } else {
        await _baseService.saveManualMatch(
          currentSource,
          currentId,
          episodeIndex,
          episodeId,
          searchKeyword: searchKeyword,
        );
      }
    }

    final cleanTitle = fallbackTitle.trim();
    final cleanKeyword = searchKeyword.trim();
    if (cleanTitle.isNotEmpty && cleanKeyword.isNotEmpty) {
      await _baseService.saveLastManualMatchQueryForTitle(
        cleanTitle,
        cleanKeyword,
      );
    }
  }

  /// 读取 TV 手动匹配面板的初始搜索词。
  ///
  /// 默认优先使用当前源当前集的精确缓存，其次回退到同标题最近一次搜索词；
  /// 两者都没有时回退到当前视频标题。
  Future<String> resolveInitialMatchQuery({
    required String currentSource,
    required String currentId,
    required int episodeIndex,
    required String fallbackTitle,
    required String videoTitle,
  }) async {
    if (currentSource.isNotEmpty && currentId.isNotEmpty) {
      final query = await _baseService.resolveManualMatchQuery(
        currentSource,
        currentId,
        episodeIndex,
        fallbackTitle: fallbackTitle,
      );
      if (query != null && query.trim().isNotEmpty) {
        return query;
      }
    }

    final titleQuery =
        await _baseService.getLastManualMatchQueryForTitle(fallbackTitle);
    if (titleQuery != null && titleQuery.trim().isNotEmpty) {
      return titleQuery;
    }

    return videoTitle;
  }

  /// 构建 TV 弹幕渲染配置。
  ///
  /// 与普通端复用同一套配置语义，但放在 TV 专属服务里集中管理，
  /// 方便后续 TV 独立调优字号、速度和布局。
  static DanmakuOption buildDanmakuOption(
    DanmakuSettings settings, {
    double playbackSpeed = 1.0,
  }) {
    final safePlaybackSpeed =
        playbackSpeed.isFinite && playbackSpeed > 0 ? playbackSpeed : 1.0;
    final duration = settings.syncVideoSpeed
        ? (settings.duration / safePlaybackSpeed)
        : settings.duration;
    return DanmakuOption(
      fontSize: settings.fontSize * settings.scale,
      opacity: settings.opacity,
      duration: duration,
      hideScroll: settings.hideScroll,
      hideTop: settings.hideTop,
      hideBottom: settings.hideBottom,
      lineHeight: settings.lineSpacing,
      fontWeight: (settings.fontWeight * 4).round().clamp(1, 9),
      massiveMode: !settings.preventOverlap,
    );
  }

  /// 构建自动匹配候选文件名列表。
  ///
  /// 候选顺序与普通端一致：
  /// 1. 标题 + 当前集索引
  /// 2. 标题 + 原始选集标题
  /// 3. 从选集标题里解析出的真实集数
  static List<String> buildMatchFileNames({
    required String videoTitle,
    required String sourceName,
    required int episodeIndex,
    String? episodeTitle,
  }) {
    final candidates = <String>[];

    void addCandidate(String value) {
      if (!candidates.contains(value)) {
        candidates.add(value);
      }
    }

    addCandidate(DanmakuService.buildFileName(
      videoTitle,
      episodeIndex,
      sourceName,
    ));

    final cleanEpisodeTitle = episodeTitle?.trim();
    if (cleanEpisodeTitle == null || cleanEpisodeTitle.isEmpty) {
      return candidates;
    }

    addCandidate(DanmakuService.buildFileName(
      '$videoTitle $cleanEpisodeTitle',
      null,
      sourceName,
    ));

    final parsedEpisode = _extractEpisodeNumberFromText(cleanEpisodeTitle);
    if (parsedEpisode != null && parsedEpisode > 0) {
      addCandidate(DanmakuService.buildFileName(
        videoTitle,
        parsedEpisode - 1,
        sourceName,
      ));
    }

    return candidates;
  }

  /// 从文本中提取剧集号或期数。
  static int? _extractEpisodeNumberFromText(String text) {
    final patterns = <RegExp>[
      RegExp(r'[第EPep]\s*(\d{1,4})'),
      RegExp(r'(\d{1,4})\s*[集话期回]'),
      RegExp(r'S\d{1,2}\s*E(\d{1,4})', caseSensitive: false),
      RegExp(r'^\s*(\d{1,4})\s*$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > 0) {
        return value;
      }
    }
    return null;
  }
}
