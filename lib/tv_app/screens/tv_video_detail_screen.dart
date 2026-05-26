import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/api_service.dart';
import 'package:selene/services/douban_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/search_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';
import 'package:selene/tv_app/screens/tv_search_screen.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_play_record_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

/// TV 详情页换源、选集和分组列表的横向滚动触发线。
const double _tvDetailOptionScrollTriggerFraction = 0.5;

/// TV 详情页数据加载函数。
typedef TvVideoDetailLoader = Future<TvVideoDetailData> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

/// TV 详情页初始可播源加载函数。
typedef TvVideoInitialSourcesLoader = Future<List<SearchResult>> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

/// TV 详情页后台补源加载函数。
typedef TvVideoMoreSourcesLoader = Future<List<SearchResult>> Function(
  BuildContext context,
  VideoInfo videoInfo,
  ValueChanged<List<SearchResult>> onIncrementalResults,
);

/// TV 详情页推荐加载函数。
typedef TvVideoRecommendsLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
  VideoInfo videoInfo,
  SearchResult? currentDetail,
);

/// TV 详情页播放器构建函数。
typedef TvDetailPlayerBuilder = Widget Function(
  BuildContext context,
  void Function(VideoPlayerWidgetController controller) onControllerCreated,
);

/// TV 详情页聚合数据。
class TvVideoDetailData {
  /// 创建 TV 详情页聚合数据。
  const TvVideoDetailData({
    required this.currentDetail,
    required this.sources,
    required this.recommends,
  });

  /// 当前播放源详情。
  final SearchResult? currentDetail;

  /// 可切换播放源。
  final List<SearchResult> sources;

  /// 相关推荐。
  final List<VideoInfo> recommends;
}

/// TV 影视详情页。
///
/// TV 卡片点击后先进入该页面，再从页面内进行播放、换源、选集和推荐跳转。
class TvVideoDetailScreen extends StatefulWidget {
  /// 创建 TV 影视详情页。
  const TvVideoDetailScreen({
    super.key,
    required this.videoInfo,
    this.stype,
    this.loadDetail,
    this.loadInitialSources,
    this.loadMoreSources,
    this.loadRecommends,
    this.playerBuilder,
    this.fullscreenPlayerBuilder,
  });

  /// 入口视频信息。
  final VideoInfo videoInfo;

  /// 搜索类型，沿用普通播放器的电影/剧集提示。
  final String? stype;

  /// 详情加载函数，测试时可注入。
  final TvVideoDetailLoader? loadDetail;

  /// 初始可播源加载函数，测试时可注入。
  final TvVideoInitialSourcesLoader? loadInitialSources;

  /// 后台补源加载函数，测试时可注入。
  final TvVideoMoreSourcesLoader? loadMoreSources;

  /// 推荐加载函数，测试时可注入。
  final TvVideoRecommendsLoader? loadRecommends;

  /// 播放器构建函数，测试时可替换。
  final TvDetailPlayerBuilder? playerBuilder;

  /// 全屏播放器构建函数，测试时可替换。
  final TvFullscreenPlayerBuilder? fullscreenPlayerBuilder;

  @override
  State<TvVideoDetailScreen> createState() => _TvVideoDetailScreenState();

  /// 默认详情加载逻辑。
  static Future<TvVideoDetailData> defaultLoadDetail(
    BuildContext context,
    VideoInfo videoInfo,
  ) async {
    final sources = <SearchResult>[];

    final exact = await defaultLoadInitialSources(context, videoInfo);
    _addUniqueSources(sources, exact);

    final searched = await _loadMoreSourcesByQuery(
      videoInfo,
      stype: null,
      onIncrementalResults: (_) {},
      allowEarlyReturn: false,
    );
    _addUniqueSources(sources, searched);

    final currentDetail = sources.isNotEmpty ? sources.first : null;
    // 静态加载函数没有 State.mounted，可取消时由 FutureBuilder 丢弃页面结果。
    // ignore: use_build_context_synchronously
    final recommends = await _loadRecommends(context, videoInfo, currentDetail);

    return TvVideoDetailData(
      currentDetail: currentDetail,
      sources: sources,
      recommends: recommends,
    );
  }

  /// 默认加载入口视频对应的精确详情。
  static Future<List<SearchResult>> defaultLoadInitialSources(
    BuildContext context,
    VideoInfo videoInfo,
  ) async {
    if (!_hasPlayableIdentity(videoInfo)) {
      return const [];
    }

    final isLocalMode = await UserDataService.getIsLocalMode();
    return isLocalMode
        ? SearchService.getDetailSync(videoInfo.source, videoInfo.id)
        : ApiService.fetchSourceDetail(videoInfo.source, videoInfo.id);
  }

  /// 默认按标题后台补全播放源。
  static Future<List<SearchResult>> defaultLoadMoreSources(
    BuildContext context,
    VideoInfo videoInfo,
    ValueChanged<List<SearchResult>> onIncrementalResults,
  ) {
    return _loadMoreSourcesByQuery(
      videoInfo,
      stype: null,
      onIncrementalResults: onIncrementalResults,
    );
  }

  /// 加载豆瓣相关推荐。
  static Future<List<VideoInfo>> _loadRecommends(
    BuildContext context,
    VideoInfo videoInfo,
    SearchResult? currentDetail,
  ) async {
    final doubanId = currentDetail?.doubanId?.toString() ?? videoInfo.doubanId;
    if (doubanId == null || doubanId.isEmpty || doubanId == '0') {
      return const [];
    }

    final response = await DoubanService.getDoubanDetails(
      context,
      doubanId: doubanId,
    );
    return response.data?.recommends
            .map((recommend) => recommend.toVideoInfo())
            .toList() ??
        const [];
  }

  /// 判断入口信息是否能直接请求播放详情。
  static bool _hasPlayableIdentity(VideoInfo videoInfo) {
    return videoInfo.source.isNotEmpty &&
        videoInfo.id.isNotEmpty &&
        videoInfo.source != 'douban' &&
        videoInfo.source != 'bangumi';
  }

  /// 按标题搜索更多源，支持服务器流式增量回调。
  static Future<List<SearchResult>> _loadMoreSourcesByQuery(
    VideoInfo videoInfo, {
    required String? stype,
    required ValueChanged<List<SearchResult>> onIncrementalResults,
    bool allowEarlyReturn = true,
  }) async {
    final query = videoInfo.searchTitle.trim().isNotEmpty
        ? videoInfo.searchTitle.trim()
        : videoInfo.title.trim();
    if (query.isEmpty) {
      return const [];
    }

    List<SearchResult> filterResults(List<SearchResult> results) {
      return results
          .where((result) => _matchesSearchResult(videoInfo, stype, result))
          .toList();
    }

    final isLocalSearch = await UserDataService.getLocalSearch();
    final isLocalMode = await UserDataService.getIsLocalMode();

    if (isLocalSearch || isLocalMode) {
      final results = filterResults(await SearchService.searchSync(query));
      onIncrementalResults(results);
      return results;
    }

    final results = await ApiService.fetchSourcesData(
      query,
      onIncrementalResults: (incrementalResults) {
        onIncrementalResults(filterResults(incrementalResults));
      },
      earlyReturnMatcher: (result) =>
          _matchesSearchResult(videoInfo, stype, result),
      allowEarlyReturn: allowEarlyReturn,
    );
    return filterResults(results);
  }

  /// 判断搜索结果是否匹配当前影片。
  static bool _matchesSearchResult(
    VideoInfo videoInfo,
    String? stype,
    SearchResult result,
  ) {
    final sourceTitle = result.title.replaceAll(' ', '').toLowerCase();
    final targetTitle = videoInfo.title.replaceAll(' ', '').toLowerCase();
    final titleMatch = sourceTitle == targetTitle;
    final year = videoInfo.year.trim().toLowerCase();
    final resultYear = result.year.trim().toLowerCase();
    final yearMatch = year.isEmpty || year == 'unknown' || resultYear == year;
    var typeMatch = true;

    if (stype == 'tv') {
      typeMatch = result.episodes.length > 1;
    } else if (stype == 'movie') {
      typeMatch = result.episodes.length == 1;
    }

    return titleMatch && yearMatch && typeMatch;
  }

  /// 去重追加播放源。
  static bool _addUniqueSources(
    List<SearchResult> target,
    List<SearchResult> incoming,
  ) {
    var changed = false;
    for (final source in incoming) {
      final exists = target.any(
        (item) => item.source == source.source && item.id == source.id,
      );
      if (!exists) {
        target.add(source);
        changed = true;
      }
    }
    return changed;
  }
}

class _TvVideoDetailScreenState extends State<TvVideoDetailScreen> {
  /// 选集分组大小，避免长剧集在 TV 端一次性横向铺满过长。
  static const int _episodeGroupSize = 20;

  /// 页面滚动控制器。
  final ScrollController _scrollController = ScrollController();

  /// 播放器入口焦点节点。
  final FocusNode _playerFocusNode = FocusNode(debugLabel: 'tv-detail-player');

  /// 全屏按钮焦点节点。
  final FocusNode _fullscreenFocusNode =
      FocusNode(debugLabel: 'tv-detail-fullscreen');

  /// 收藏按钮焦点节点。
  final FocusNode _favoriteFocusNode =
      FocusNode(debugLabel: 'tv-detail-favorite');

  /// 播放器入口位置 Key。
  final GlobalKey _playerTargetKey = GlobalKey();

  /// 共享播放器 Key。
  ///
  /// 预览和全屏覆盖层共用同一个 `VideoPlayerWidget`，避免进全屏时重建播放器。
  final GlobalKey _sharedPlayerKey = GlobalKey();

  /// 全屏按钮位置 Key。
  final GlobalKey _fullscreenTargetKey = GlobalKey();

  /// 收藏按钮位置 Key。
  final GlobalKey _favoriteTargetKey = GlobalKey();

  /// 底部回到顶部按钮焦点节点。
  final FocusNode _bottomActionFocusNode =
      FocusNode(debugLabel: 'tv-detail-bottom-action');

  /// 底部回到顶部按钮位置 Key。
  final GlobalKey _bottomActionTargetKey = GlobalKey();

  /// 顶部搜索按钮焦点节点。
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'tv-detail-search');

  /// 换源列表焦点节点表。
  ///
  /// 顶部操作按钮按下时需要稳定回到当前播放源，不能只依赖系统几何焦点猜测。
  final Map<String, FocusNode> _sourceFocusNodes = <String, FocusNode>{};

  /// 换源列表可见性定位 Key 表。
  final Map<String, GlobalKey> _sourceTargetKeys = <String, GlobalKey>{};

  /// 选集列表焦点节点表。
  final Map<int, FocusNode> _episodeFocusNodes = <int, FocusNode>{};

  /// 选集列表定位 Key 表。
  final Map<int, GlobalKey> _episodeTargetKeys = <int, GlobalKey>{};

  /// 选集分组焦点节点表。
  final Map<int, FocusNode> _episodeGroupFocusNodes = <int, FocusNode>{};

  /// 选集分组定位 Key 表。
  final Map<int, GlobalKey> _episodeGroupTargetKeys = <int, GlobalKey>{};

  /// 推荐卡片焦点节点表。
  final Map<String, FocusNode> _recommendFocusNodes = <String, FocusNode>{};

  /// 推荐卡片定位 Key 表。
  final Map<String, GlobalKey> _recommendTargetKeys = <String, GlobalKey>{};

  /// 播放器控制器。
  VideoPlayerWidgetController? _playerController;

  /// 当前源详情。
  SearchResult? _currentDetail;

  /// 所有可用播放源。
  List<SearchResult> _sources = const [];

  /// 相关推荐。
  List<VideoInfo> _recommends = const [];

  /// 当前选集下标。
  int _episodeIndex = 0;

  /// 当前选集分组下标。
  int _episodeGroupIndex = 0;

  /// 初始续播选集下标。
  int _initialResumeEpisodeIndex = 0;

  /// 初始续播时间，仅首次起播消费。
  Duration? _pendingInitialPlaybackPosition;

  /// 是否已经消费过初始续播时间。
  bool _hasAppliedInitialPlaybackPosition = false;

  /// 最近一次下发给播放器的地址，避免同一地址重复覆盖续播位置。
  String? _lastRequestedPlaybackUrl;

  /// 当前是否收藏。
  bool _isFavorite = false;

  /// 是否展示详情页内全屏覆盖层。
  bool _fullscreenOverlayVisible = false;

  /// 首屏详情是否仍在等待可播数据。
  bool _isInitialDetailLoading = true;

  /// 精确源详情是否加载完成。
  bool _initialSourcesLoaded = false;

  /// 后台补源是否加载完成。
  bool _moreSourcesLoaded = false;

  /// 推荐内容是否已经开始加载。
  bool _hasStartedRecommends = false;

  /// 当前加载批次，避免旧页面异步结果回写。
  int _loadSerial = 0;

  /// 顶部当前时间刷新定时器。
  Timer? _clockTimer;

  /// 顶部右侧当前时间。
  late String _currentTime;

  /// 上次保存播放进度的时间。
  DateTime? _lastSaveTime;

  /// 上次保存播放进度的秒数。
  int? _lastSavePosition;

  /// 换源记录任务序号，避免快速换源时旧任务误清理。
  int _sourceSwitchRecordSerial = 0;

  /// 播放进度保存间隔，对齐手机端节流策略。
  static const Duration _saveProgressInterval = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _currentTime = _formatCurrentTime(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _currentTime = _formatCurrentTime(DateTime.now()));
    });
    _startDetailLoading();
    _loadFavoriteState();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _playerController?.removeProgressListener(_onVideoProgressUpdate);
    _playerController?.dispose();
    _playerFocusNode.dispose();
    _fullscreenFocusNode.dispose();
    _favoriteFocusNode.dispose();
    _bottomActionFocusNode.dispose();
    _searchFocusNode.dispose();
    for (final node in _sourceFocusNodes.values) {
      node.dispose();
    }
    for (final node in _episodeFocusNodes.values) {
      node.dispose();
    }
    for (final node in _episodeGroupFocusNodes.values) {
      node.dispose();
    }
    for (final node in _recommendFocusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// 将当前时间格式化为顶部短时间。
  static String _formatCurrentTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 开始详情数据加载。
  void _startDetailLoading() {
    final serial = ++_loadSerial;
    if (_shouldUseLegacyLoader) {
      unawaited(_loadLegacyDetail(serial));
      return;
    }

    unawaited(_loadInitialSources(serial));
    unawaited(_loadMoreSources(serial));
  }

  /// 是否使用旧的聚合加载入口。
  bool get _shouldUseLegacyLoader {
    return widget.loadDetail != null &&
        widget.loadInitialSources == null &&
        widget.loadMoreSources == null &&
        widget.loadRecommends == null;
  }

  /// 加载收藏状态。
  Future<void> _loadFavoriteState() async {
    final isFavorite = PageCacheService().isFavoritedSync(
      widget.videoInfo.source,
      widget.videoInfo.id,
    );
    if (mounted) {
      setState(() => _isFavorite = isFavorite);
    }
  }

  /// 使用旧聚合加载函数加载详情。
  Future<void> _loadLegacyDetail(int serial) async {
    try {
      final data = await widget.loadDetail!(context, widget.videoInfo);
      if (!mounted || serial != _loadSerial) {
        return;
      }

      setState(() {
        _currentDetail = data.currentDetail;
        _sources = data.sources;
        _recommends = data.recommends;
        if (_currentDetail != null) {
          _applyInitialResumeState(_currentDetail!);
        }
        _isInitialDetailLoading = false;
        _initialSourcesLoaded = true;
        _moreSourcesLoaded = true;
        _hasStartedRecommends = true;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _playCurrentEpisode());
    } catch (error) {
      debugPrint('TV 详情页聚合加载失败: $error');
      if (mounted && serial == _loadSerial) {
        setState(() {
          _isInitialDetailLoading = false;
          _initialSourcesLoaded = true;
          _moreSourcesLoaded = true;
        });
      }
    }
  }

  /// 加载入口精确源，优先让详情页有可播数据。
  Future<void> _loadInitialSources(int serial) async {
    final loader = widget.loadInitialSources ??
        TvVideoDetailScreen.defaultLoadInitialSources;
    try {
      final sources = await loader(context, widget.videoInfo);
      if (!mounted || serial != _loadSerial) {
        return;
      }

      _mergeSources(sources, preferAsCurrent: true);
    } catch (error) {
      debugPrint('TV 详情页精确源加载失败: $error');
    }
    _markInitialSourcesLoaded();
  }

  /// 后台搜索并增量追加其它播放源。
  Future<void> _loadMoreSources(int serial) async {
    final loader = widget.loadMoreSources ??
        (
          BuildContext context,
          VideoInfo videoInfo,
          ValueChanged<List<SearchResult>> onIncrementalResults,
        ) {
          return TvVideoDetailScreen._loadMoreSourcesByQuery(
            videoInfo,
            stype: widget.stype,
            onIncrementalResults: onIncrementalResults,
          );
        };

    try {
      final sources = await loader(
        context,
        widget.videoInfo,
        (incrementalResults) {
          if (!mounted || serial != _loadSerial) {
            return;
          }
          _mergeSources(incrementalResults, preferAsCurrent: false);
        },
      );
      if (!mounted || serial != _loadSerial) {
        return;
      }

      _mergeSources(sources, preferAsCurrent: false);
    } catch (error) {
      debugPrint('TV 详情页后台补源失败: $error');
    }
    _markMoreSourcesLoaded();
  }

  /// 标记精确源加载完成。
  void _markInitialSourcesLoaded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _initialSourcesLoaded = true;
      _refreshInitialLoadingState();
    });
    _loadRecommendsIfNeeded();
  }

  /// 标记后台补源加载完成。
  void _markMoreSourcesLoaded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _moreSourcesLoaded = true;
      _refreshInitialLoadingState();
    });
    _loadRecommendsIfNeeded(
      forceWhenEmpty: _initialSourcesLoaded && _currentDetail == null,
    );
  }

  /// 合并新播放源并在首次命中时立即起播。
  void _mergeSources(
    List<SearchResult> incoming, {
    required bool preferAsCurrent,
  }) {
    if (incoming.isEmpty && _currentDetail != null) {
      return;
    }

    var shouldPlay = false;
    setState(() {
      final mutableSources = List<SearchResult>.from(_sources);
      final changed =
          TvVideoDetailScreen._addUniqueSources(mutableSources, incoming);
      if (changed) {
        _sources = List<SearchResult>.unmodifiable(mutableSources);
      }

      // 首个可播源到达后立刻结束首屏转圈。
      if (_currentDetail == null && mutableSources.isNotEmpty) {
        _currentDetail =
            preferAsCurrent ? incoming.first : mutableSources.first;
        _applyInitialResumeState(_currentDetail!);
        shouldPlay = true;
      }

      _refreshInitialLoadingState();
    });

    if (shouldPlay) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _playCurrentEpisode());
    }
    _loadRecommendsIfNeeded();
  }

  /// 刷新首屏加载状态。
  void _refreshInitialLoadingState() {
    if (_currentDetail != null ||
        (_initialSourcesLoaded && _moreSourcesLoaded)) {
      _isInitialDetailLoading = false;
    }
  }

  /// 应用入口播放记录中的续播集数和时间。
  void _applyInitialResumeState(SearchResult detail) {
    if (TvPlayRecordService.hasResumeHint(widget.videoInfo) &&
        _matchesVideoInfoRecord(detail)) {
      _initialResumeEpisodeIndex =
          TvPlayRecordService.episodeIndexFromVideoInfo(
        widget.videoInfo,
        detail.episodes.length,
      );
      _episodeIndex = _initialResumeEpisodeIndex;
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition =
          TvPlayRecordService.resumePositionFromVideoInfo(widget.videoInfo);
      _hasAppliedInitialPlaybackPosition = false;
      return;
    }

    _initialResumeEpisodeIndex = 0;
    _episodeIndex = 0;
    _episodeGroupIndex = 0;
    _pendingInitialPlaybackPosition = null;
    _hasAppliedInitialPlaybackPosition = true;
  }

  /// 判断当前源是否匹配入口播放记录。
  bool _matchesVideoInfoRecord(SearchResult detail) {
    if (widget.videoInfo.source.isNotEmpty &&
        widget.videoInfo.id.isNotEmpty &&
        detail.source == widget.videoInfo.source &&
        detail.id == widget.videoInfo.id) {
      return true;
    }

    return TvPlayRecordService.isSameVideoForPlayRecord(
      record: PlayRecord(
        id: widget.videoInfo.id,
        source: widget.videoInfo.source,
        title: widget.videoInfo.title,
        sourceName: widget.videoInfo.sourceName,
        year: widget.videoInfo.year,
        cover: widget.videoInfo.cover,
        index: widget.videoInfo.index,
        totalEpisodes: widget.videoInfo.totalEpisodes,
        playTime: widget.videoInfo.playTime,
        totalTime: widget.videoInfo.totalTime,
        saveTime: widget.videoInfo.saveTime,
        searchTitle: widget.videoInfo.searchTitle,
      ),
      targetSource: detail,
      searchTitle: widget.videoInfo.searchTitle.trim().isNotEmpty
          ? widget.videoInfo.searchTitle
          : widget.videoInfo.title,
    );
  }

  /// 取出一次性初始续播时间。
  Duration? _takeInitialPlaybackPosition() {
    if (_hasAppliedInitialPlaybackPosition) {
      return null;
    }
    _hasAppliedInitialPlaybackPosition = true;
    final position = _pendingInitialPlaybackPosition;
    _pendingInitialPlaybackPosition = null;
    return position;
  }

  /// 按需加载相关推荐。
  void _loadRecommendsIfNeeded({bool forceWhenEmpty = false}) {
    if (_hasStartedRecommends) {
      return;
    }
    if (_currentDetail == null && !forceWhenEmpty) {
      return;
    }
    _hasStartedRecommends = true;
    unawaited(_loadRecommendsAsync(_loadSerial));
  }

  /// 异步加载相关推荐。
  Future<void> _loadRecommendsAsync(int serial) async {
    final loader = widget.loadRecommends ?? TvVideoDetailScreen._loadRecommends;
    try {
      final recommends =
          await loader(context, widget.videoInfo, _currentDetail);
      if (!mounted || serial != _loadSerial) {
        return;
      }
      setState(() => _recommends = recommends);
    } catch (error) {
      debugPrint('TV 详情页推荐加载失败: $error');
    }
  }

  /// 记录播放器控制器并挂载进度监听。
  void _attachPlayerController(VideoPlayerWidgetController controller) {
    if (identical(_playerController, controller)) {
      _playCurrentEpisode();
      return;
    }

    _playerController?.removeProgressListener(_onVideoProgressUpdate);
    _playerController = controller;
    _lastRequestedPlaybackUrl = null;
    controller.addProgressListener(_onVideoProgressUpdate);
    _playCurrentEpisode();
  }

  /// 播放进度变化时按手机端节流策略保存。
  void _onVideoProgressUpdate() {
    _saveProgress(scene: '定时保存');
  }

  /// 保存当前播放进度。
  void _saveProgress({bool force = false, required String scene}) {
    final detail = _currentDetail;
    final controller = _playerController;
    if (detail == null || controller == null) {
      return;
    }

    final position = controller.currentPosition;
    final duration = controller.duration;
    if (position == null || duration == null || position.inSeconds < 1) {
      return;
    }

    final playTime = position.inSeconds;
    if (!force) {
      final now = DateTime.now();
      if (_lastSaveTime != null &&
          now.difference(_lastSaveTime!) < _saveProgressInterval) {
        return;
      }
      if (_lastSavePosition != null && playTime == _lastSavePosition) {
        return;
      }
    }

    _lastSaveTime = DateTime.now();
    _lastSavePosition = playTime;

    final playRecord = TvPlayRecordService.buildRecord(
      videoInfo: widget.videoInfo,
      detail: detail,
      episodeIndex: _episodeIndex,
      playTime: playTime,
      totalTime: duration.inSeconds,
    );

    unawaited(
      TvPlayRecordService.saveRecord(context, playRecord).then((saved) {
        if (!saved) {
          debugPrint('TV 保存播放进度失败 [场景: $scene]');
        }
      }),
    );
  }

  /// 保存换源后的新播放记录，成功后再清理旧源记录。
  Future<void> _saveSwitchedSourceRecord({
    required SearchResult source,
    required int switchSerial,
    required int episodeIndex,
    required int playTime,
    required int totalTime,
  }) async {
    if (playTime < 1) {
      return;
    }

    final playRecord = TvPlayRecordService.buildRecord(
      videoInfo: widget.videoInfo,
      detail: source,
      episodeIndex: episodeIndex,
      playTime: playTime,
      totalTime: totalTime,
    );
    _lastSaveTime = DateTime.now();
    _lastSavePosition = playTime;

    final saved = await TvPlayRecordService.saveRecord(context, playRecord);
    if (!saved) {
      debugPrint('TV 换源记录保护：新记录保存失败，跳过旧记录清理');
      return;
    }

    if (!mounted ||
        switchSerial != _sourceSwitchRecordSerial ||
        _currentDetail?.source != source.source ||
        _currentDetail?.id != source.id) {
      debugPrint('TV 换源记录保护：切源任务已过期，跳过旧记录清理');
      return;
    }

    await TvPlayRecordService.cleanupOtherSourceRecords(
      context: context,
      keepSource: source,
      searchTitle: widget.videoInfo.searchTitle.trim().isNotEmpty
          ? widget.videoInfo.searchTitle
          : widget.videoInfo.title,
    );
  }

  /// 播放当前选集。
  Future<void> _playCurrentEpisode() async {
    final detail = _currentDetail;
    final controller = _playerController;
    if (detail == null || controller == null || detail.episodes.isEmpty) {
      return;
    }

    final index = _episodeIndex.clamp(0, detail.episodes.length - 1);
    var url = detail.episodes[index];
    final proxy = await UserDataService.getM3u8ProxyUrl();
    if (proxy.isNotEmpty && url.startsWith('http')) {
      url = '$proxy${Uri.encodeComponent(url)}';
    }
    final startAt = _takeInitialPlaybackPosition();
    if (_lastRequestedPlaybackUrl == url && startAt == null) {
      return;
    }
    _lastRequestedPlaybackUrl = url;
    await controller.updateDataSource(url, startAt: startAt);
  }

  /// 切换播放源。
  void _switchSource(SearchResult source) {
    if (_currentDetail?.source == source.source &&
        _currentDetail?.id == source.id) {
      return;
    }
    final switchSerial = ++_sourceSwitchRecordSerial;
    final currentProgress =
        _playerController?.currentPosition?.inSeconds ?? _lastSavePosition ?? 0;
    final currentTotalTime =
        _playerController?.duration?.inSeconds ?? widget.videoInfo.totalTime;
    final currentEpisode = _episodeIndex;

    setState(() {
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = currentEpisode.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentEpisode());
    unawaited(
      _saveSwitchedSourceRecord(
        source: source,
        switchSerial: switchSerial,
        episodeIndex: _episodeIndex,
        playTime: currentProgress,
        totalTime: currentTotalTime,
      ),
    );
  }

  /// 同步全屏覆盖层内切换后的选集。
  void _handleFullscreenEpisodeChanged(int index) {
    if (!mounted || index == _episodeIndex) {
      return;
    }
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = index ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
  }

  /// 同步全屏覆盖层内切换后的播放线路。
  void _handleFullscreenSourceChanged(SearchResult source) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = _episodeIndex.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
  }

  /// 切换选集。
  void _switchEpisode(int index) {
    _saveProgress(force: true, scene: '切换选集前');
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = index ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentEpisode());
  }

  /// 切换选集分组。
  void _switchEpisodeGroup(int index) {
    setState(() => _episodeGroupIndex = index);
  }

  /// 获取选集分组数量。
  int _episodeGroupCount(int total) {
    if (total <= _episodeGroupSize) {
      return 0;
    }
    return ((total - 1) ~/ _episodeGroupSize) + 1;
  }

  /// 获取选集分组标题。
  String _episodeGroupLabel(int groupIndex, int total) {
    final start = groupIndex * _episodeGroupSize + 1;
    final rawEnd = start + _episodeGroupSize - 1;
    final end = rawEnd > total ? total : rawEnd;
    return start == end ? '$start' : '$start-$end';
  }

  /// 获取当前分组内的选集下标。
  List<int> _episodeIndexesForGroup(int total, int groupIndex) {
    final start = groupIndex * _episodeGroupSize;
    final rawEnd = start + _episodeGroupSize;
    final end = rawEnd > total ? total : rawEnd;
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  /// 从换源卡片向上移动到最近的顶部控件。
  void _focusNearestHeroControlFrom(BuildContext sourceContext) {
    final sourceRect = _globalRectForContext(sourceContext);
    if (sourceRect == null) {
      _playerFocusNode.requestFocus();
      return;
    }

    FocusNode? bestNode;
    double? bestScore;
    final candidates = [
      (key: _playerTargetKey, node: _playerFocusNode),
      (key: _fullscreenTargetKey, node: _fullscreenFocusNode),
      (key: _favoriteTargetKey, node: _favoriteFocusNode),
    ];

    for (final candidate in candidates) {
      if (!candidate.node.canRequestFocus) {
        continue;
      }
      final targetRect = _globalRectForKey(candidate.key);
      if (targetRect == null || targetRect.center.dy >= sourceRect.center.dy) {
        continue;
      }
      final dx = targetRect.center.dx - sourceRect.center.dx;
      final dy = targetRect.center.dy - sourceRect.center.dy;
      final score = dx * dx + dy * dy;
      if (bestScore == null || score < bestScore) {
        bestScore = score;
        bestNode = candidate.node;
      }
    }

    (bestNode ?? _playerFocusNode).requestFocus();
  }

  /// 获取播放源的稳定标识。
  String _sourceFocusKey(SearchResult source) {
    return '${source.source}::${source.id}';
  }

  /// 获取播放源对应的焦点节点。
  FocusNode _sourceFocusNodeFor(SearchResult source) {
    final focusKey = _sourceFocusKey(source);
    return _sourceFocusNodes.putIfAbsent(
      focusKey,
      () => FocusNode(debugLabel: 'tv-detail-source-$focusKey'),
    );
  }

  /// 获取播放源对应的定位 Key。
  GlobalKey _sourceTargetKeyFor(SearchResult source) {
    final focusKey = _sourceFocusKey(source);
    return _sourceTargetKeys.putIfAbsent(
      focusKey,
      () => GlobalKey(debugLabel: 'tv-detail-source-$focusKey'),
    );
  }

  /// 获取选集焦点节点。
  FocusNode _episodeFocusNodeFor(int index) {
    return _episodeFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'tv-detail-episode-$index'),
    );
  }

  /// 获取选集定位 Key。
  GlobalKey _episodeTargetKeyFor(int index) {
    return _episodeTargetKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'tv-detail-episode-$index'),
    );
  }

  /// 获取选集分组焦点节点。
  FocusNode _episodeGroupFocusNodeFor(int index) {
    return _episodeGroupFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'tv-detail-episode-group-$index'),
    );
  }

  /// 获取选集分组定位 Key。
  GlobalKey _episodeGroupTargetKeyFor(int index) {
    return _episodeGroupTargetKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'tv-detail-episode-group-$index'),
    );
  }

  /// 获取推荐卡片的稳定标识。
  String _recommendFocusKey(VideoInfo videoInfo) {
    return '${videoInfo.source}::${videoInfo.id}';
  }

  /// 获取推荐卡片焦点节点。
  FocusNode _recommendFocusNodeFor(VideoInfo videoInfo) {
    final focusKey = _recommendFocusKey(videoInfo);
    return _recommendFocusNodes.putIfAbsent(
      focusKey,
      () => FocusNode(debugLabel: 'tv-detail-recommend-$focusKey'),
    );
  }

  /// 获取推荐卡片定位 Key。
  GlobalKey _recommendTargetKeyFor(VideoInfo videoInfo) {
    final focusKey = _recommendFocusKey(videoInfo);
    return _recommendTargetKeys.putIfAbsent(
      focusKey,
      () => GlobalKey(debugLabel: 'tv-detail-recommend-$focusKey'),
    );
  }

  /// 从顶部操作按钮向下稳定聚焦当前播放源。
  void _focusSelectedSource() {
    final targetNode = _firstVisibleSourceFocusNode();
    if (targetNode == null) {
      return;
    }
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(targetNode);
  }

  /// 从播放器向下进入第一条播放线路。
  void _focusFirstSource() {
    final targetNode = _firstVisibleSourceFocusNode();
    if (targetNode == null) {
      return;
    }
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(targetNode);
  }

  /// 从换源列表向下进入当前分组第一集。
  void _focusFirstEpisodeInCurrentGroup() {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      _focusFirstRecommend();
      return;
    }
    final node =
        _firstVisibleIndexedNode(_episodeTargetKeys, _episodeFocusNodes);
    if (node == null) {
      return;
    }
    node.requestFocus();
    _ensureFocusedNodeVisible(node);
  }

  /// 从选集向下进入分组或推荐。
  void _focusEpisodeDownTarget() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount > 1) {
      final node = _firstVisibleIndexedNode(
        _episodeGroupTargetKeys,
        _episodeGroupFocusNodes,
      );
      node?.requestFocus();
      if (node != null) {
        _ensureFocusedNodeVisible(node);
      }
      return;
    }
    _focusFirstRecommend();
  }

  /// 从选集或分组向上回到当前播放源。
  void _focusSelectedSourceFromBelow() {
    _focusSelectedSource();
  }

  /// 从分组向下进入推荐。
  void _focusFirstRecommend() {
    final targetNode = _firstVisibleRecommendNode();
    if (targetNode == null) {
      _focusBottomAction();
      return;
    }
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(targetNode);
  }

  /// 从推荐向下进入底部回到顶部按钮。
  void _focusBottomAction() {
    if (!_bottomActionFocusNode.canRequestFocus) {
      return;
    }
    _bottomActionFocusNode.requestFocus();
    _ensureFocusedNodeVisible(_bottomActionFocusNode);
  }

  /// 从推荐向上回到选集分组或选集。
  void _focusRecommendationUpTarget() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount > 1) {
      final groupNode = _firstVisibleIndexedNode(
        _episodeGroupTargetKeys,
        _episodeGroupFocusNodes,
      );
      if (groupNode != null) {
        groupNode.requestFocus();
        _ensureFocusedNodeVisible(groupNode);
        return;
      }
    }
    _focusFirstEpisodeInCurrentGroup();
  }

  /// 让指定焦点节点对应控件在详情页外层滚动视口中可见。
  void _ensureFocusedNodeVisible(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = node.context;
      if (context == null || !context.mounted) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: TvFocusScroll.defaultAlignment,
        duration: TvFocusScroll.duration,
        curve: TvFocusScroll.curve,
      );
    });
  }

  /// 获取当前已构建的索引焦点节点。
  FocusNode? _visibleNodeForIndex(
    Map<int, GlobalKey> targetKeys,
    Map<int, FocusNode> focusNodes,
    int index,
  ) {
    final targetKey = targetKeys[index];
    if (targetKey?.currentContext == null) {
      return null;
    }
    final node = focusNodes[index];
    if (node == null || !node.canRequestFocus) {
      return null;
    }
    return node;
  }

  /// 获取第一个已构建的索引焦点节点。
  FocusNode? _firstVisibleIndexedNode(
    Map<int, GlobalKey> targetKeys,
    Map<int, FocusNode> focusNodes,
  ) {
    final sortedIndexes = targetKeys.keys.toList()..sort();
    for (final index in sortedIndexes) {
      final node = _visibleNodeForIndex(targetKeys, focusNodes, index);
      if (node != null) {
        return node;
      }
    }
    return null;
  }

  /// 获取当前已构建且可见的播放源焦点节点。
  FocusNode? _visibleSourceFocusNodeFor(SearchResult source) {
    final focusKey = _sourceFocusKey(source);
    final targetKey = _sourceTargetKeys[focusKey];
    if (targetKey?.currentContext == null) {
      return null;
    }
    final node = _sourceFocusNodes[focusKey];
    if (node == null || !node.canRequestFocus) {
      return null;
    }
    return node;
  }

  /// 获取第一个已构建的播放源焦点节点，避免焦点落到未渲染项后看起来消失。
  FocusNode? _firstVisibleSourceFocusNode() {
    for (final source in _sources) {
      final node = _visibleSourceFocusNodeFor(source);
      if (node != null) {
        return node;
      }
    }
    return null;
  }

  /// 获取第一个已构建的推荐焦点节点。
  FocusNode? _firstVisibleRecommendNode() {
    for (final videoInfo in _recommends) {
      final focusKey = _recommendFocusKey(videoInfo);
      final targetKey = _recommendTargetKeys[focusKey];
      if (targetKey?.currentContext == null) {
        continue;
      }
      final node = _recommendFocusNodes[focusKey];
      if (node != null && node.canRequestFocus) {
        return node;
      }
    }
    return null;
  }

  /// 获取指定 Key 对应控件的全局矩形。
  Rect? _globalRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    return _globalRectForContext(context);
  }

  /// 获取指定上下文对应控件的全局矩形。
  Rect? _globalRectForContext(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & size;
  }

  /// 切换收藏状态。
  Future<void> _toggleFavorite() async {
    final detail = _currentDetail;
    if (detail == null) {
      return;
    }

    if (_isFavorite) {
      final result = await PageCacheService()
          .removeFavorite(detail.source, detail.id, context);
      if (result.success && mounted) {
        setState(() => _isFavorite = false);
      }
      return;
    }

    final favoriteData = {
      'cover': detail.poster,
      'save_time': DateTime.now().millisecondsSinceEpoch,
      'source_name': detail.sourceName,
      'title': detail.title,
      'total_episodes': detail.episodes.length,
      'year': detail.year,
    };
    final result = await PageCacheService().addFavorite(
      detail.source,
      detail.id,
      favoriteData,
      context,
    );
    if (result.success && mounted) {
      setState(() => _isFavorite = true);
    }
  }

  /// 进入 TV 专属全屏播放器页。
  void _openFullscreenPlayer() {
    setState(() => _fullscreenOverlayVisible = true);
  }

  /// 退出详情页内全屏覆盖层。
  void _closeFullscreenOverlay() {
    setState(() => _fullscreenOverlayVisible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _playerFocusNode.requestFocus();
      }
    });
  }

  /// 打开 TV 搜索页。
  void _openSearch() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const TvSearchScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// 将详情页操作区焦点送回顶部搜索入口。
  void _focusSearchAction() {
    _searchFocusNode.requestFocus();
  }

  /// 将顶部搜索入口焦点送到详情页全屏按钮。
  void _focusFullscreenAction() {
    _fullscreenFocusNode.requestFocus();
  }

  /// 回到页面顶部。
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D0E),
        body: SafeArea(
          child: Stack(
            children: [
              _isInitialDetailLoading && _currentDetail == null
                  ? Center(
                      child: CircularProgressIndicator(
                        color: TvTheme.of(context).accent,
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        TvLayout.pageHorizontalPadding,
                        38,
                        TvLayout.pageHorizontalPadding,
                        56,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageGuide(),
                          const SizedBox(height: 26),
                          _buildHeroArea(),
                          const SizedBox(height: 30),
                          _buildSourcesSection(),
                          const SizedBox(height: 28),
                          _buildEpisodesSection(),
                          const SizedBox(height: 34),
                          _buildRecommendsSection(),
                          const SizedBox(height: 38),
                          _buildBottomActions(),
                        ],
                      ),
                    ),
              if (_fullscreenOverlayVisible) _buildFullscreenOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建顶部说明、搜索按钮和当前时间。
  Widget _buildPageGuide() {
    return Row(
      children: [
        Text(
          'IvyTV',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FontUtils.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            '按返回键返回上一页 | 全屏时向下键可进行播放设置（倍数，其它）',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF98A2A8),
            ),
          ),
        ),
        const SizedBox(width: 22),
        _TvDetailActionButton(
          key: const ValueKey('tv-detail-search-action'),
          label: '搜索',
          icon: LucideIcons.search,
          focusNode: _searchFocusNode,
          borderRadius: 22,
          onArrowDown: _focusFullscreenAction,
          onPressed: _openSearch,
        ),
        const SizedBox(width: 18),
        Text(
          key: const ValueKey('tv-detail-clock'),
          _currentTime,
          style: FontUtils.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFB6C2BF),
          ),
        ),
      ],
    );
  }

  /// 构建同页全屏覆盖层。
  Widget _buildFullscreenOverlay() {
    return Positioned.fill(
      child: TvFullscreenPlayerScreen(
        videoInfo: widget.videoInfo,
        currentDetail: _currentDetail,
        sources: _sources,
        stype: widget.stype,
        initialEpisodeIndex: _episodeIndex,
        initialPlaybackPosition: _playerController?.currentPosition,
        initialPlaybackWasPlaying: _playerController?.isPlaying ?? true,
        playerBuilder: (context, onControllerCreated) {
          final player = widget.fullscreenPlayerBuilder?.call(
            context,
            onControllerCreated,
          );
          if (player != null) {
            return player;
          }
          return _buildSharedPlayer(
            _currentDetail,
            onControllerCreatedOverride: onControllerCreated,
          );
        },
        onExitRequested: _closeFullscreenOverlay,
        onEpisodeChanged: _handleFullscreenEpisodeChanged,
        onSourceChanged: _handleFullscreenSourceChanged,
        reuseExistingPlayer: widget.fullscreenPlayerBuilder == null,
      ),
    );
  }

  /// 构建播放器和简介区域。
  Widget _buildHeroArea() {
    final detail = _currentDetail;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 980;
        final playerWidth = useVerticalLayout ? constraints.maxWidth : 620.0;
        final player = SizedBox(
          width: playerWidth,
          child: _buildPlayerBox(detail),
        );
        final info = _buildInfoPanel(detail);

        if (useVerticalLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player,
              const SizedBox(height: 22),
              info,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            player,
            const SizedBox(width: 34),
            Expanded(child: info),
          ],
        );
      },
    );
  }

  /// 构建播放器区域。
  Widget _buildPlayerBox(SearchResult? detail) {
    return KeyedSubtree(
      key: _playerTargetKey,
      child: TvFocusable(
        focusNode: _playerFocusNode,
        autofocus: true,
        autoScrollOnFocus: false,
        onArrowDown: _focusFirstSource,
        onPressed: _openFullscreenPlayer,
        builder: (context, hasFocus) {
          return AnimatedContainer(
            key: const ValueKey('tv-detail-player-entry'),
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasFocus ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _fullscreenOverlayVisible
                    ? const ColoredBox(color: Colors.black)
                    : _buildSharedPlayer(detail),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建预览和全屏共用的播放器。
  Widget _buildSharedPlayer(
    SearchResult? detail, {
    void Function(VideoPlayerWidgetController controller)?
        onControllerCreatedOverride,
  }) {
    final controllerCreated =
        onControllerCreatedOverride ?? _attachPlayerController;
    return KeyedSubtree(
      key: _sharedPlayerKey,
      child: widget.playerBuilder?.call(
            context,
            controllerCreated,
          ) ??
          VideoPlayerWidget(
            surface: VideoPlayerSurface.desktop,
            url: null,
            videoTitle: detail?.title ?? widget.videoInfo.title,
            videoYear: detail?.year ?? widget.videoInfo.year,
            videoCover: detail?.poster ?? widget.videoInfo.cover,
            currentEpisodeIndex: _episodeIndex,
            totalEpisodes: detail?.episodes.length ?? 0,
            episodesTitles: detail?.episodesTitles,
            isShortDrama: false,
            sourceName: detail?.sourceName ?? widget.videoInfo.sourceName,
            showControls: false,
            enablePip: false,
            onControllerCreated: controllerCreated,
            onFullscreenChanged: (_) {},
            onEpisodeChanged: _switchEpisode,
            onNextEpisode: () {
              final total = detail?.episodes.length ?? 0;
              if (_episodeIndex + 1 < total) {
                _switchEpisode(_episodeIndex + 1);
              }
            },
            onPreviousEpisode: () {
              if (_episodeIndex > 0) {
                _switchEpisode(_episodeIndex - 1);
              }
            },
            onVideoCompleted: () {},
          ),
    );
  }

  /// 构建右侧简介和按钮。
  Widget _buildInfoPanel(SearchResult? detail) {
    final title = detail?.title ?? widget.videoInfo.title;
    final meta = [
      if ((detail?.year ?? widget.videoInfo.year).isNotEmpty)
        detail?.year ?? widget.videoInfo.year,
      if ((detail?.sourceName ?? widget.videoInfo.sourceName).isNotEmpty)
        detail?.sourceName ?? widget.videoInfo.sourceName,
      if ((detail?.episodes.length ?? widget.videoInfo.totalEpisodes) > 0)
        '共 ${detail?.episodes.length ?? widget.videoInfo.totalEpisodes} 集',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FontUtils.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          meta,
          style: FontUtils.poppins(
            fontSize: 15,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          (detail?.desc?.trim().isNotEmpty == true)
              ? detail!.desc!.trim()
              : '暂无简介',
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: FontUtils.poppins(
            fontSize: 16,
            height: 1.45,
            color: const Color(0xFFD9E2E0),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            KeyedSubtree(
              key: _fullscreenTargetKey,
              child: _TvDetailActionButton(
                label: '全屏',
                icon: LucideIcons.maximize2,
                focusNode: _fullscreenFocusNode,
                focusMemoryGroupKey: 'tv-detail-actions',
                onArrowUp: _focusSearchAction,
                onArrowDown: _sources.isEmpty ? null : _focusSelectedSource,
                onPressed: _openFullscreenPlayer,
              ),
            ),
            KeyedSubtree(
              key: _favoriteTargetKey,
              child: _TvDetailActionButton(
                label: _isFavorite ? '已收藏' : '收藏',
                icon: LucideIcons.heart,
                focusNode: _favoriteFocusNode,
                focusMemoryGroupKey: 'tv-detail-actions',
                iconColor: _isFavorite ? const Color(0xFFE50914) : Colors.white,
                onArrowUp: _focusSearchAction,
                onArrowDown: _sources.isEmpty ? null : _focusSelectedSource,
                onPressed: _toggleFavorite,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建换源区。
  Widget _buildSourcesSection() {
    return _TvDetailSection(
      title: '切换线路',
      subtitle: '遇播放卡顿，音画不同步或无法播放时，请切换播放线路',
      child: _sources.isEmpty
          ? _buildEmptyText('暂无可用源')
          : SizedBox(
              height: 52,
              child: ListView.separated(
                key: const ValueKey('tv-detail-source-list'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _sources.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final source = _sources[index];
                  final selected = source.source == _currentDetail?.source &&
                      source.id == _currentDetail?.id;
                  final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                  final isFirstItem = index == 0;
                  final isLastItem = index == _sources.length - 1;
                  return KeyedSubtree(
                    key: _sourceTargetKeyFor(source),
                    child: TvEdgeShake(
                      key: edgeShakeKey,
                      child: Builder(
                        builder: (chipContext) => _TvChoiceChip(
                          label: source.sourceName,
                          selected: selected,
                          focusNode: _sourceFocusNodeFor(source),
                          focusMemoryGroupKey: 'tv-detail-source-list',
                          onArrowLeft: isFirstItem
                              ? () => edgeShakeKey.currentState
                                  ?.shake(AxisDirection.left)
                              : null,
                          onArrowRight: isLastItem
                              ? () => edgeShakeKey.currentState
                                  ?.shake(AxisDirection.right)
                              : null,
                          onArrowUp: () =>
                              _focusNearestHeroControlFrom(chipContext),
                          onArrowDown: _focusFirstEpisodeInCurrentGroup,
                          onPressed: () => _switchSource(source),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// 构建选集区。
  Widget _buildEpisodesSection() {
    final detail = _currentDetail;
    final episodes = detail?.episodes ?? const <String>[];
    final groupCount = _episodeGroupCount(episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes = _episodeIndexesForGroup(episodes.length, groupIndex);
    return _TvDetailSection(
      title: '选集',
      child: episodes.isEmpty
          ? _buildEmptyText('暂无选集')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    key: const ValueKey('tv-detail-episode-list'),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: visibleIndexes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, itemIndex) {
                      final index = visibleIndexes[itemIndex];
                      final title =
                          detail?.episodesTitles.length == episodes.length
                              ? detail!.episodesTitles[index]
                              : '${index + 1}';
                      final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                      final isFirstItem = itemIndex == 0;
                      final isLastItem = itemIndex == visibleIndexes.length - 1;
                      return TvEdgeShake(
                        key: edgeShakeKey,
                        child: KeyedSubtree(
                          key: _episodeTargetKeyFor(index),
                          child: _TvChoiceChip(
                            label: title.isEmpty ? '${index + 1}' : title,
                            selected: index == _episodeIndex,
                            focusNode: _episodeFocusNodeFor(index),
                            focusMemoryGroupKey: 'tv-detail-episode-list',
                            onArrowLeft: isFirstItem
                                ? () => edgeShakeKey.currentState
                                    ?.shake(AxisDirection.left)
                                : null,
                            onArrowRight: isLastItem
                                ? () => edgeShakeKey.currentState
                                    ?.shake(AxisDirection.right)
                                : null,
                            onArrowUp: _focusSelectedSourceFromBelow,
                            onArrowDown: _focusEpisodeDownTarget,
                            onPressed: () => _switchEpisode(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (groupCount > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      key: const ValueKey('tv-detail-episode-group-list'),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: groupCount,
                      separatorBuilder: (_, __) => const SizedBox(width: 18),
                      itemBuilder: (context, index) {
                        final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                        final isFirstItem = index == 0;
                        final isLastItem = index == groupCount - 1;
                        return TvEdgeShake(
                          key: edgeShakeKey,
                          child: KeyedSubtree(
                            key: _episodeGroupTargetKeyFor(index),
                            child: _TvTextChoice(
                              label: _episodeGroupLabel(index, episodes.length),
                              selected: index == groupIndex,
                              focusNode: _episodeGroupFocusNodeFor(index),
                              focusMemoryGroupKey:
                                  'tv-detail-episode-group-list',
                              onArrowLeft: isFirstItem
                                  ? () => edgeShakeKey.currentState
                                      ?.shake(AxisDirection.left)
                                  : null,
                              onArrowRight: isLastItem
                                  ? () => edgeShakeKey.currentState
                                      ?.shake(AxisDirection.right)
                                  : null,
                              onArrowUp: _focusFirstEpisodeInCurrentGroup,
                              onArrowDown: _focusFirstRecommend,
                              onPressed: () => _switchEpisodeGroup(index),
                              throttleGroupKey: 'tv-detail-episode-group-list',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// 构建相关推荐区。
  Widget _buildRecommendsSection() {
    return _TvDetailSection(
      title: '相关推荐',
      child: _recommends.isEmpty
          ? _buildEmptyText('暂无推荐')
          : SizedBox(
              height: TvVideoCard.height + 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _recommends.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final videoInfo = _recommends[index];
                  return KeyedSubtree(
                    key: _recommendTargetKeyFor(videoInfo),
                    child: TvVideoCard(
                      videoInfo: videoInfo,
                      focusNode: _recommendFocusNodeFor(videoInfo),
                      focusMemoryGroupKey: 'tv-detail-recommend-list',
                      onArrowUp: _focusRecommendationUpTarget,
                      onArrowDown: _focusBottomAction,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => TvVideoDetailScreen(
                              videoInfo: videoInfo,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  /// 构建底部操作。
  Widget _buildBottomActions() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          _TvDetailActionButton(
            key: _bottomActionTargetKey,
            label: '回到顶部',
            icon: LucideIcons.arrowUp,
            focusNode: _bottomActionFocusNode,
            focusMemoryGroupKey: 'tv-detail-bottom-actions',
            onPressed: _scrollToTop,
          ),
        ],
      ),
    );
  }

  /// 构建空状态文案。
  Widget _buildEmptyText(String text) {
    return Text(
      text,
      style: FontUtils.poppins(
        fontSize: 16,
        color: const Color(0xFF98A2A8),
      ),
    );
  }
}

/// TV 详情页分区。
class _TvDetailSection extends StatelessWidget {
  /// 创建 TV 详情页分区。
  const _TvDetailSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  /// 分区标题。
  final String title;

  /// 分区副标题。
  final String? subtitle;

  /// 分区内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FontUtils.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF98A2A8),
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// TV 详情页操作按钮。
class _TvDetailActionButton extends StatelessWidget {
  /// 创建 TV 详情页操作按钮。
  const _TvDetailActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.focusMemoryGroupKey,
    this.iconColor = Colors.white,
    this.borderRadius = 8,
    this.onArrowUp,
    this.onArrowDown,
  });

  /// 按钮文案。
  final String label;

  /// 按钮图标。
  final IconData icon;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 图标颜色。
  final Color iconColor;

  /// 按钮圆角数值。
  final double borderRadius;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      focusMemoryGroupKey: focusMemoryGroupKey,
      autoScrollOnFocus: false,
      onPressed: onPressed,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xCC1B2127),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: FontUtils.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// TV 详情页纯文字选项。
///
/// 用于选集分组这类轻量级切换，不展示按钮底色和边框。
class _TvTextChoice extends StatelessWidget {
  /// 创建 TV 详情页纯文字选项。
  const _TvTextChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.focusMemoryGroupKey,
    this.throttleGroupKey,
  });

  /// 文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 长按方向键节流分组 Key。
  final Object? throttleGroupKey;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      horizontalFocusScrollTriggerFraction:
          _tvDetailOptionScrollTriggerFraction,
      // 分组切换改成纯文字列表后，需要保留逐项经过的焦点节奏。
      focusMemoryGroupKey: focusMemoryGroupKey,
      directionalRepeatThrottleGroupKey: throttleGroupKey,
      builder: (context, hasFocus) {
        final highlight = hasFocus || selected;
        return AnimatedScale(
          scale: hasFocus ? 1.08 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: 15,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? palette.accent : const Color(0xFFD9E2E0),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TV 详情页选项按钮。
class _TvChoiceChip extends StatelessWidget {
  /// 创建 TV 详情页选项按钮。
  const _TvChoiceChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.focusMemoryGroupKey,
  });

  /// 文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      focusMemoryGroupKey: focusMemoryGroupKey,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      horizontalFocusScrollTriggerFraction:
          _tvDetailOptionScrollTriggerFraction,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 86, maxWidth: 180),
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? palette.accent : const Color(0xFF15191B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus
                  ? Colors.white
                  : selected
                      ? palette.accent
                      : const Color(0xFF293136),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 15,
              color: selected ? palette.selectedText : const Color(0xFFD9E2E0),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
