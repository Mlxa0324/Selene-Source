import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/config/tv_player_kernel.dart';
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
import 'package:selene/tv_app/services/tv_perf_trace.dart';
import 'package:selene/tv_app/services/tv_search_result_session.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_play_record_service.dart';
import 'package:selene/tv_app/services/tv_search_recommend_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_route.dart';
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

/// TV 详情页搜索结果标题归一化函数。
typedef TvVideoSearchTitleNormalizer = String Function(String title);

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

/// TV 详情页自动去广告开关读取函数。
typedef TvDetailAdFilterLoader = Future<bool> Function();

/// TV 详情页 M3U8 代理地址读取函数。
typedef TvDetailProxyUrlLoader = Future<String> Function();

/// TV 详情页播放器内核读取函数。
typedef TvDetailPlayerKernelLoader = Future<TvPlayerKernel> Function();

/// TV 详情页续播记录读取函数。
typedef TvDetailResumeRecordsLoader = Future<List<PlayRecord>> Function(
  BuildContext context,
);

/// TV 详情页测试钩子。
///
/// 仅测试场景使用，用于在占位播放器下模拟“视频播放完成”这类播放器事件。
class TvVideoDetailScreenTestHooks {
  /// 视频播放完成回调。
  VoidCallback? onVideoCompleted;

  /// 默认播放器构建前最终使用的自动去广告开关。
  ValueChanged<bool>? onAdFilterResolved;
}

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
  /// 视频开始播放后延迟多久再加载相关推荐。
  ///
  /// 推荐 API 和首播流同时走网络时会互相争抢带宽。
  /// 设为 Duration.zero 表示播放开始后立即加载推荐；
  /// 设为正数表示等 N 秒后再加载，给首播流留出缓冲余量。
  /// 可根据实际体验随时调整，测试中可置零。
  // ignore: non_constant_identifier_names
  @visibleForTesting
  static Duration recommendsDelayAfterPlayback = const Duration(seconds: 2);

  /// 创建 TV 影视详情页。
  const TvVideoDetailScreen({
    super.key,
    required this.videoInfo,
    this.stype,
    this.prefetchedSources = const <SearchResult>[],
    this.prefetchedSearchSession,
    this.prefetchedSearchTitleKey = '',
    this.loadDetail,
    this.loadInitialSources,
    this.loadMoreSources,
    this.loadRecommends,
    this.playerBuilder,
    this.fullscreenPlayerBuilder,
    this.loadAdFilterEnabled,
    this.loadM3u8ProxyUrl,
    this.loadPlayerKernel,
    this.loadResumeRecords,
    this.testHooks,
  });

  /// 入口视频信息。
  final VideoInfo videoInfo;

  /// 搜索类型，沿用普通播放器的电影/剧集提示。
  final String? stype;

  /// 从搜索页提前带入的同片名候选资源。
  ///
  /// 当该列表非空且没有共享搜索会话时，详情页直接复用这些资源，
  /// 不再发起标题补源 SSE 搜索。
  final List<SearchResult> prefetchedSources;

  /// 从搜索页共享过来的同一轮搜索会话。
  ///
  /// 当搜索页进入详情页时，如果该轮 SSE 搜索还没有结束，
  /// 详情页需要继续订阅它的后续增量结果，而不是只消费进入瞬间的快照。
  final TvSearchResultSession? prefetchedSearchSession;

  /// 共享搜索会话在详情页内对应的标准化片名键。
  ///
  /// 搜索页的单次搜索结果里可能同时包含多部影片，这里只消费与当前详情页同片名的那一组。
  final String prefetchedSearchTitleKey;

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

  /// 自动去广告开关读取函数，测试时可注入。
  final TvDetailAdFilterLoader? loadAdFilterEnabled;

  /// M3U8 代理地址读取函数，测试时可注入。
  final TvDetailProxyUrlLoader? loadM3u8ProxyUrl;

  /// TV 播放器内核读取函数，测试时可注入。
  final TvDetailPlayerKernelLoader? loadPlayerKernel;

  /// 续播记录读取函数，测试时可注入。
  final TvDetailResumeRecordsLoader? loadResumeRecords;

  /// 测试钩子，允许 widget test 模拟播放器完成事件。
  final TvVideoDetailScreenTestHooks? testHooks;

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
    // 推荐不再阻塞默认加载路径。
    // 推荐数据由 _markPreviewPlaybackStarted 在播放开始后异步加载，
    // 避免 Douban API 和首播流争抢网速。

    return TvVideoDetailData(
      currentDetail: currentDetail,
      sources: sources,
      recommends: const <VideoInfo>[],
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

  /// 规范化标题，保证搜索页与详情页使用同一套归一化规则。
  static String normalizeSearchTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
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
      final existingIndex = target.indexWhere(
        (item) => item.source == source.source && item.id == source.id,
      );
      if (existingIndex < 0) {
        target.add(source);
        changed = true;
        continue;
      }

      final existingSource = target[existingIndex];
      if (_shouldReplaceSource(existingSource, source)) {
        // 后台补源可能返回同 source/id 的完整详情，要覆盖继续观看入口的空集数占位。
        target[existingIndex] = source;
        changed = true;
      }
    }
    return changed;
  }

  /// 判断同一播放源的新结果是否比旧结果更完整。
  static bool _shouldReplaceSource(
    SearchResult existingSource,
    SearchResult incomingSource,
  ) {
    return incomingSource.episodes.length > existingSource.episodes.length;
  }
}

class _TvVideoDetailScreenState extends State<TvVideoDetailScreen> {
  /// 标记当前是否运行在 `flutter test` 环境。
  ///
  /// widget test 中的 `pumpAndSettle` 会等待所有动画静止，loading 进度环需改为
  /// 静态值，避免测试因无限转圈动画超时。
  static bool get _isFlutterTestEnvironment {
    final flutterTest = Platform.environment['FLUTTER_TEST'];
    return flutterTest != null && flutterTest != 'false';
  }

  /// 选集分组大小，避免长剧集在 TV 端一次性横向铺满过长。
  static const int _episodeGroupSize = 20;

  /// 详情页线路卡片和选集卡片统一的基础高度。
  ///
  /// 选集短标题默认也要和线路卡片保持同档高度，避免上下两个列表切换时
  /// 视觉上出现选集卡片明显更矮的断层。
  static const double _detailChoiceChipMinHeight = 52;

  /// 详情页选项按钮最大宽度。
  static const double _detailChoiceChipMaxWidth = 180;

  /// 详情页选项按钮横向内边距。
  static const double _detailChoiceChipHorizontalPadding = 14;

  /// 详情页选项按钮纵向内边距。
  static const double _detailChoiceChipVerticalPadding = 8;

  /// 详情页播放器和分区标题的左基线留白。
  ///
  /// 页面外层已经保留 `TvLayout.pageHorizontalPadding`，这里不再额外缩进，
  /// 保证播放器、分区标题和顶部 `IvyTV` 共用同一条左基线。
  static const double _detailSectionLeadingInset =
      TvLayout.pageHorizontalPadding;

  /// 详情页横向列表的首尾焦点安全留白。
  ///
  /// 横向列表视口贴到屏幕边缘，列表内容滚动时可以从屏幕边缘直接进入或离开；
  /// 但任意获焦项停留在边界时都必须保留这段安全距离，避免焦点描边或放大效果
  /// 被屏幕裁切。该值与 `IvyTV`/分区标题的左基线对齐，因此首项默认状态、首项获焦
  /// 以及任意项滚到最左侧获焦时，左侧都稳定保留 36px。
  static const double _detailHorizontalListSafePadding =
      TvLayout.pageHorizontalPadding;

  /// 详情页横向列表的内容内边距。
  ///
  /// 左侧保持 36px 焦点安全区；右侧额外补两段页面边距，保证滚到末尾时
  /// 最后一个获焦项和焦点描边也能完整露出。
  static const EdgeInsets _detailHorizontalListPadding = EdgeInsets.only(
    left: _detailHorizontalListSafePadding,
    right: _detailHorizontalListSafePadding * 3,
  );

  /// 详情页横向列表从页面内容区扩到屏幕两侧的补偿宽度。
  ///
  /// 页面正文保留 36px 左右边距用于标题和播放器对齐，但遥控器横向列表滚动时
  /// 不允许保留首尾空白，因此列表视口需要反向抵消父级这段边距。
  static const double _detailHorizontalListOverflow =
      TvLayout.pageHorizontalPadding;

  /// 详情页纵向焦点跟随的稳定中线。
  ///
  /// 非全屏详情页更适合把焦点维持在屏幕上下的中间附近，
  /// 这样从播放器切到线路、再切到选集时只会做轻微位移，不会一跳一大截。
  static const double _detailVerticalFocusAlignment = 0.46;

  /// 详情页纵向跟焦的单次最大推进距离。
  static const double _detailVerticalFocusMaxStep = 96;

  /// 向下切到下一排时的最小轻推距离。
  static const double _detailVerticalFocusMinForwardStep = 18;

  /// 详情页纵向跟焦目标滚动容差。
  ///
  /// 上下切焦时目标位移很小时不再启动一轮滚动动画，减少 TV 端焦点发涩感。
  static const double _detailVerticalFocusOffsetEpsilon = 12;

  /// 详情页纵向跟焦时，为控件完整显示预留的可视安全边距。
  ///
  /// 大屏焦点边框会外扩 2px，且底部按钮获焦时不能贴着视口边缘，
  /// 因此这里统一预留一小段上下安全距离，避免看起来像被页面裁掉。
  static const double _detailVerticalFocusVisibleInset = 12;

  /// 详情页线路横向焦点记忆分组。
  static const String _sourceFocusGroupKey = 'tv-detail-source-list';

  /// 详情页选集横向焦点记忆分组。
  static const String _episodeFocusGroupKey = 'tv-detail-episode-list';

  /// 详情页选集分组横向焦点记忆分组。
  static const String _episodeGroupFocusGroupKey =
      'tv-detail-episode-group-list';

  /// 详情页推荐横向焦点记忆分组。
  static const String _recommendFocusGroupKey = 'tv-detail-recommend-list';

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

  /// 推荐横向列表滚动控制器。
  final ScrollController _recommendListScrollController = ScrollController();

  /// 播放器控制器。
  VideoPlayerWidgetController? _playerController;

  /// 当前源详情。
  SearchResult? _currentDetail;

  /// 所有可用播放源。
  List<SearchResult> _sources = const [];

  /// 按集数倒序缓存后的线路列表。
  ///
  /// 详情页会频繁因为焦点变化和顶部时间刷新触发 rebuild，这里把排序结果缓存起来，
  /// 避免每次访问都重新遍历 `_sources`。
  List<SearchResult> _cachedSourcesByEpisodeCountDesc = const [];

  /// 当前详情页展示用的线路缓存。
  ///
  /// 首次进入详情页时，当前线路会被固定展示在第一位；用户在详情页或全屏内
  /// 主动切换线路后，则恢复为纯“集数倒序 + 原始顺序稳定”展示。
  /// 该缓存仅在 `_sources` 或 `_currentDetail` 变化时重算一次。
  List<SearchResult> _cachedDisplaySources = const [];

  /// 是否仍需要把当前播放线路固定展示在第一位。
  ///
  /// 仅首次进入详情页时开启，避免后台补源完成后把当前线路前后顺序冲乱；
  /// 用户主动切换线路后，展示顺序恢复为纯排序结果，减少列表来回跳动。
  bool _pinCurrentDetailFirst = true;

  /// 相关推荐。
  List<VideoInfo> _recommends = const [];

  /// 当前是否存在可展示的相关推荐。
  ///
  /// 详情页没有相关推荐时，不再渲染相关推荐区和底部回到顶部按钮，
  /// 这样页面尾部不会留下无意义的空白占位。
  bool get _hasVisibleRecommends => _recommends.isNotEmpty;

  /// 当前选集下标。
  int _episodeIndex = 0;

  /// 当前选集分组下标。
  int _episodeGroupIndex = 0;

  /// 初始续播选集下标。
  int _initialResumeEpisodeIndex = 0;

  /// 当前用于续播匹配的入口视频信息。
  ///
  /// 手机端播放器会在初始化时重新读取播放记录；TV 端也需要用最新记录修正入口
  /// `VideoInfo` 中可能过期的集数和播放秒数。
  late VideoInfo _resumeVideoInfo;

  /// 初始续播时间，仅首次起播消费。
  Duration? _pendingInitialPlaybackPosition;

  /// 等待真实进度信号确认的续播 seek 位置。
  Duration? _pendingResumeSeekPosition;

  /// 当前续播 seek 已重试次数。
  int _pendingResumeSeekRetryCount = 0;

  /// 入口续播时间快照，供全屏在小播放器进度未回传时兜底。
  Duration? _initialResumePlaybackPositionSnapshot;

  /// 是否已经消费过初始续播时间。
  bool _hasAppliedInitialPlaybackPosition = false;

  /// 最近一次下发给播放器的地址，避免同一地址重复覆盖续播位置。
  String? _lastRequestedPlaybackUrl;

  /// 续播记录是否已经完成首轮读取。
  bool _hasLoadedResumeRecord = false;

  /// 续播记录未返回前缓存一次首播请求，待记录就绪后再真正下发。
  bool _hasPendingInitialPlaybackAfterResumeLoad = false;

  /// 详情页小播放器是否正在加载当前视频。
  bool _previewPlayerLoading = false;

  /// 当前预览播放是否已经由真实进度确认起播。
  bool _previewPlaybackStarted = false;

  /// 本轮小播放器 loading 开始时的播放位置。
  Duration? _previewLoadingAnchorPosition;

  /// 当前自动去广告开关状态。
  bool _adFilterEnabled = true;

  /// 当前 TV 播放器内核配置。
  TvPlayerKernel _tvPlayerKernel = TvPlayerKernel.exo;

  /// 是否已完成 TV 播放器内核读取。
  bool _hasResolvedTvPlayerKernel = false;

  /// 当前已预热完成的 M3U8 代理地址。
  ///
  /// 代理配置属于播放增强能力，不应该反向阻塞详情页首播。
  /// 因此这里仅在后台更新缓存，真正起播时直接优先使用当前已拿到的结果。
  String _m3u8ProxyUrl = '';

  /// M3U8 代理地址是否已经完成过一次读取。
  bool _hasResolvedM3u8ProxyUrl = false;

  /// 当前是否收藏。
  bool _isFavorite = false;

  /// 是否展示详情页内全屏覆盖层。
  bool _fullscreenOverlayVisible = false;

  /// 是否消费全屏关闭后的同一次详情页返回事件。
  bool _consumeFullscreenOverlayBack = false;

  /// 详情页是否已经进入退出流程。
  ///
  /// 返回键和路由销毁之间可能还有源加载、播放器创建、post-frame 等异步回调晚到，
  /// 统一用该标记阻止它们继续起播或刷新焦点。
  bool _isExitingDetail = false;

  /// 首屏详情是否仍在等待可播数据。
  bool _isInitialDetailLoading = true;

  /// 精确源详情是否加载完成。
  bool _initialSourcesLoaded = false;

  /// 后台补源是否加载完成。
  bool _moreSourcesLoaded = false;

  /// 当前已订阅的共享搜索会话。
  TvSearchResultSession? _subscribedPrefetchedSearchSession;

  /// 当前共享搜索会话的监听回调。
  VoidCallback? _prefetchedSearchSessionListener;

  /// 是否需要按播放记录优先恢复保存线路。
  bool get _shouldPrioritizeResumeSource {
    return TvPlayRecordService.hasResumeHint(_resumeVideoInfo) &&
        _resumeVideoInfo.source.isNotEmpty;
  }

  /// 当前详情页是否仍可执行 UI 和播放动作。
  bool get _canUseDetailRoute => mounted && !_isExitingDetail;

  /// 推荐内容是否已经开始加载。
  bool _hasStartedRecommends = false;

  /// 首个预览播放请求是否已经真正下发。
  ///
  /// 相关推荐属于次要任务，首播请求没有发出去前不应抢先启动，
  /// 否则会让用户体感成“像在等相关推荐出来才能播”。
  bool _hasDispatchedInitialPreviewPlayback = false;

  /// 当前加载批次，避免旧页面异步结果回写。
  int _loadSerial = 0;

  /// 顶部当前时间刷新定时器。
  Timer? _clockTimer;

  /// 推荐加载延迟计时器。
  ///
  /// 播放开始后按 [_recommendsDelayAfterPlayback] 延迟触发推荐加载，
  /// 避免推荐 API 和首播流争抢网速。
  Timer? _recommendsLoadTimer;

  /// 顶部右侧当前时间。
  late String _currentTime;

  /// 上次保存播放进度的时间。
  DateTime? _lastSaveTime;

  /// 上次保存播放进度的秒数。
  int? _lastSavePosition;

  /// 换源记录任务序号，避免快速换源时旧任务误清理。
  int _sourceSwitchRecordSerial = 0;

  /// 最近一次获焦的线路稳定标识。
  String? _lastFocusedSourceKey;

  /// 最近一次获焦的选集下标。
  int? _lastFocusedEpisodeIndex;

  /// 最近一次获焦的选集分组下标。
  int? _lastFocusedEpisodeGroupIndex;

  /// 最近一次获焦的推荐稳定标识。
  String? _lastFocusedRecommendKey;

  /// 下一次获焦时跳过横向归位的分组。
  ///
  /// 仅用于上下跨列表恢复焦点：焦点回到上次停留项即可，横向滚动位置保持用户离开时
  /// 的状态，避免上下移动时列表又被程序主动贴回左侧。
  final Set<String> _suppressedHorizontalRevealGroups = <String>{};

  /// 播放进度保存间隔，对齐手机端节流策略。
  static const Duration _saveProgressInterval = Duration(seconds: 10);

  /// 低端 Android 播放器 ready 前可能吞掉 seek，限制补偿次数避免高频打扰播放。
  static const int _pendingResumeSeekRetryLimit = 5;

  /// 安全刷新小播放器暂停控制层。
  ///
  /// 播放器可能在子组件构建或平台回调中同步通知播放状态，统一延后可避免 build 阶段 setState。
  void _schedulePreviewChromeRefresh() {
    if (!_canUseDetailRoute) {
      return;
    }

    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final isBuildRelatedPhase =
        schedulerPhase == SchedulerPhase.persistentCallbacks ||
            schedulerPhase == SchedulerPhase.transientCallbacks ||
            schedulerPhase == SchedulerPhase.midFrameMicrotasks;

    if (isBuildRelatedPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canUseDetailRoute) {
          setState(() {});
        }
      });
      return;
    }

    setState(() {});
  }

  /// 线路横向列表滚动控制器。
  final ScrollController _sourceListScrollController = ScrollController();

  /// 选集横向列表滚动控制器。
  final ScrollController _episodeListScrollController = ScrollController();

  /// 选集分组横向列表滚动控制器。
  final ScrollController _episodeGroupListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TvPerfTrace.instant(
      'TV详情页:initState',
      arguments: {'title': widget.videoInfo.title},
    );
    HardwareKeyboard.instance.addHandler(_handleGlobalBackKeyEvent);
    _bindTestHooks();
    _resumeVideoInfo = widget.videoInfo;
    _markPreviewPlayerLoading();
    _currentTime = _formatCurrentTime(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _currentTime = _formatCurrentTime(DateTime.now()));
    });
    // 提前预热代理配置，但不让它阻塞详情页首播链路。
    unawaited(_loadM3u8ProxyUrl());
    unawaited(_loadResumeRecord());
    _startDetailLoading();
    _loadFavoriteState();
    _loadAdFilterPreference();
    _loadPlayerKernelPreference();
  }

  @override
  void didUpdateWidget(covariant TvVideoDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.testHooks, widget.testHooks)) {
      oldWidget.testHooks?.onVideoCompleted = null;
      _bindTestHooks();
    }
  }

  @override
  void dispose() {
    _isExitingDetail = true;
    _loadSerial++;
    widget.testHooks?.onVideoCompleted = null;
    _detachPrefetchedSearchSession();
    HardwareKeyboard.instance.removeHandler(_handleGlobalBackKeyEvent);
    _clockTimer?.cancel();
    _recommendsLoadTimer?.cancel();
    // 路由销毁前兜底补一次异步保存，避免返回过快时错过定时节流窗口。
    unawaited(_saveProgress(force: true, scene: '详情页销毁'));
    unawaited(_playerController?.pause());
    // 播放器实例由子组件自己管理，详情页销毁时只解绑进度监听，
    // 避免预览播放器和全屏共享控制器被父页面重复释放。
    _playerController?.removeProgressListener(_onVideoProgressUpdate);
    _playerController?.removeNetworkSpeedListener(_onPreviewNetworkSpeedUpdate);
    _playerController = null;
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
    _sourceListScrollController.dispose();
    _episodeListScrollController.dispose();
    _episodeGroupListScrollController.dispose();
    _recommendListScrollController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 绑定测试钩子。
  void _bindTestHooks() {
    widget.testHooks?.onVideoCompleted = _handlePreviewVideoCompleted;
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
      TvPerfTrace.instant(
        'TV详情页:开始详情加载',
        arguments: {'mode': 'legacy'},
      );
      unawaited(_loadLegacyDetail(serial));
      return;
    }

    TvPerfTrace.instant(
      'TV详情页:开始详情加载',
      arguments: {'mode': 'split'},
    );
    unawaited(_loadInitialSources(serial));
    unawaited(_loadMoreSources(serial));
  }

  /// 异步读取最新续播记录，但不阻塞详情源加载启动。
  ///
  /// 详情页应尽快进入精确源加载，让首个可播源先到达；
  /// 续播记录只负责在首次真正起播前补齐目标集数和 `startAt`。
  Future<void> _loadResumeRecord() async {
    await TvPerfTrace.async(
      'TV详情页:读取续播记录',
      () async {
        try {
          final loader = widget.loadResumeRecords ?? _defaultLoadResumeRecords;
          final records = await loader(context);
          if (!_canUseDetailRoute) {
            return;
          }
          final previousResumeVideoInfo = _resumeVideoInfo;
          final matchedRecord = _matchingResumeRecord(records);
          if (matchedRecord != null) {
            TvPerfTrace.instant(
              'TV详情页:命中续播记录',
              arguments: {
                'episode': matchedRecord.index,
                'playTime': matchedRecord.playTime,
              },
            );
            _resumeVideoInfo = VideoInfo.fromPlayRecord(
              matchedRecord,
              doubanId: widget.videoInfo.doubanId,
              bangumiId: widget.videoInfo.bangumiId,
              rate: widget.videoInfo.rate,
            );
            _syncPendingPlaybackWithLatestResumeRecord(
              previousResumeVideoInfo: previousResumeVideoInfo,
            );
          }
        } catch (error) {
          debugPrint('TV 详情页读取续播记录失败: $error');
        } finally {
          if (_canUseDetailRoute) {
            _hasLoadedResumeRecord = true;
            final restoredSavedSource =
                _restoreSavedSourceAfterResumeRecordLoaded();
            if (_currentDetail != null &&
                !_hasDispatchedInitialPreviewPlayback &&
                _canUseDetailRoute) {
              setState(() {
                _applyInitialResumeState(_currentDetail!);
              });
            }
            if (_hasPendingInitialPlaybackAfterResumeLoad) {
              _hasPendingInitialPlaybackAfterResumeLoad = false;
              unawaited(_playCurrentEpisode());
            } else if (restoredSavedSource &&
                !_hasDispatchedInitialPreviewPlayback) {
              unawaited(_playCurrentEpisode());
            }
          }
        }
      },
      arguments: {'title': widget.videoInfo.title},
    );
  }

  /// 默认读取续播记录。
  Future<List<PlayRecord>> _defaultLoadResumeRecords(
      BuildContext context) async {
    final result = await PageCacheService().getPlayRecords(context);
    return result.success && result.data != null ? result.data! : const [];
  }

  /// 查找和入口影片一致的最新播放记录。
  PlayRecord? _matchingResumeRecord(List<PlayRecord> records) {
    for (final record in records) {
      if (record.source == widget.videoInfo.source &&
          record.id == widget.videoInfo.id) {
        return record;
      }
    }
    if (!TvPlayRecordService.hasResumeHint(widget.videoInfo)) {
      return null;
    }
    final sameSourceNameRecords = records
        .where(
          (record) =>
              _matchesEntrySourceName(record) &&
              _matchesEntryVideoIdentity(record),
        )
        .toList();
    if (sameSourceNameRecords.isEmpty) {
      return null;
    }
    sameSourceNameRecords.sort((a, b) => b.saveTime.compareTo(a.saveTime));
    return sameSourceNameRecords.first;
  }

  /// 判断播放记录线路名是否与入口一致。
  bool _matchesEntrySourceName(PlayRecord record) {
    final entrySourceName = _normalizeResumeRecordKey(
      widget.videoInfo.sourceName,
    );
    if (entrySourceName.isEmpty) {
      return false;
    }
    return _normalizeResumeRecordKey(record.sourceName) == entrySourceName;
  }

  /// 判断播放记录是否属于当前入口影片。
  bool _matchesEntryVideoIdentity(PlayRecord record) {
    final entryTitle = _normalizeResumeRecordKey(widget.videoInfo.title);
    final entrySearchTitle =
        _normalizeResumeRecordKey(widget.videoInfo.searchTitle);
    final recordTitle = _normalizeResumeRecordKey(record.title);
    final recordSearchTitle = _normalizeResumeRecordKey(record.searchTitle);

    final titleMatched = entryTitle.isNotEmpty && entryTitle == recordTitle;
    final searchTitleMatched =
        entrySearchTitle.isNotEmpty && entrySearchTitle == recordSearchTitle;
    if (!titleMatched && !searchTitleMatched) {
      return false;
    }
    if (_isUnknownResumeYear(widget.videoInfo.year) ||
        _isUnknownResumeYear(record.year)) {
      return true;
    }
    return widget.videoInfo.year.trim().toLowerCase() ==
        record.year.trim().toLowerCase();
  }

  /// 判断播放记录年份是否缺失。
  bool _isUnknownResumeYear(String year) {
    final normalized = year.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'unknown' || normalized == '未知';
  }

  /// 标准化播放记录匹配关键字。
  String _normalizeResumeRecordKey(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  /// 查找第一个满足条件的播放源。
  SearchResult? _firstWhereOrNull(
    List<SearchResult> sources,
    bool Function(SearchResult source) test,
  ) {
    for (final source in sources) {
      if (test(source)) {
        return source;
      }
    }
    return null;
  }

  /// 续播记录晚到时，把首屏临时选中的线路纠正为保存线路。
  bool _restoreSavedSourceAfterResumeRecordLoaded() {
    if (!_canUseDetailRoute || !_shouldPrioritizeResumeSource) {
      return false;
    }
    final savedSource = _resolveSavedSourceCandidate(_sources);
    if (savedSource == null) {
      return false;
    }
    final currentDetail = _currentDetail;
    if (currentDetail?.source == savedSource.source &&
        currentDetail?.id == savedSource.id) {
      return false;
    }

    setState(() {
      // 续播记录是入口真实意图，晚到时要覆盖首屏临时源。
      _currentDetail = savedSource;
      _pinCurrentDetailFirst = true;
      _lastRequestedPlaybackUrl = null;
      _applyInitialResumeState(savedSource);
      _refreshSourceDisplayCaches(sourcesChanged: false);
      _refreshInitialLoadingState();
    });
    return true;
  }

  /// 是否使用旧的聚合加载入口。
  bool get _shouldUseLegacyLoader {
    return widget.loadDetail != null &&
        widget.loadInitialSources == null &&
        widget.loadMoreSources == null &&
        widget.loadRecommends == null;
  }

  /// 计算按集数倒序展示的线路列表。
  ///
  /// 集数相同时保留原始返回顺序，避免同集数线路在刷新后位置抖动。
  List<SearchResult> _buildSourcesByEpisodeCountDesc(
      List<SearchResult> sources) {
    final indexedSources = List<({int index, SearchResult source})>.generate(
      sources.length,
      (index) => (index: index, source: sources[index]),
    );
    indexedSources.sort((a, b) {
      final countCompare =
          b.source.episodes.length.compareTo(a.source.episodes.length);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.index.compareTo(b.index);
    });
    return indexedSources.map((entry) => entry.source).toList();
  }

  /// 计算详情页当前用于展示的线路列表。
  ///
  /// 首次进入详情页时，当前播放线路要固定落在第一位，
  /// 其余线路再按“集数倒序 + 原始顺序稳定”的规则继续追加到右侧，
  /// 避免补源完成后在当前线路前后同时插入其它线路，导致顺序看起来混乱。
  List<SearchResult> _buildDisplaySources({
    required List<SearchResult> sortedSources,
    required SearchResult? detail,
    required bool pinCurrentDetailFirst,
  }) {
    if (!pinCurrentDetailFirst || detail == null || sortedSources.isEmpty) {
      return sortedSources;
    }
    final selectedSourceIndex = sortedSources.indexWhere(
      (source) => source.source == detail.source && source.id == detail.id,
    );
    if (selectedSourceIndex <= 0) {
      return sortedSources;
    }
    return [
      sortedSources[selectedSourceIndex],
      ...sortedSources.take(selectedSourceIndex),
      ...sortedSources.skip(selectedSourceIndex + 1),
    ];
  }

  /// 刷新按集数倒序的线路排序缓存。
  ///
  /// 仅在 `_sources` 变化时调用，避免单纯切换当前线路时再次遍历原始源列表。
  void _refreshSortedSourceCache() {
    final sortedSources = _buildSourcesByEpisodeCountDesc(_sources);
    _cachedSourcesByEpisodeCountDesc = List<SearchResult>.unmodifiable(
      sortedSources,
    );
  }

  /// 刷新详情页展示用的线路缓存。
  ///
  /// 当前线路变化时只需要基于已排好序的结果重组展示顺序，不必重复读取 `_sources`。
  void _refreshDisplaySourceCache() {
    _cachedDisplaySources = List<SearchResult>.unmodifiable(
      _buildDisplaySources(
        sortedSources: _cachedSourcesByEpisodeCountDesc,
        detail: _currentDetail,
        pinCurrentDetailFirst: _pinCurrentDetailFirst,
      ),
    );
  }

  /// 按变化类型刷新详情页线路缓存。
  ///
  /// `_sources` 变化时同时刷新排序缓存和展示缓存；
  /// 仅 `_currentDetail` 变化时只重排展示顺序。
  void _refreshSourceDisplayCaches({required bool sourcesChanged}) {
    if (sourcesChanged) {
      _refreshSortedSourceCache();
    }
    _refreshDisplaySourceCache();
  }

  /// 当前是否带着搜索页共享搜索会话进入详情页。
  bool get _hasPrefetchedSearchSession {
    return widget.prefetchedSearchSession != null &&
        widget.prefetchedSearchTitleKey.isNotEmpty;
  }

  /// 从共享搜索会话里筛出当前详情页所属的同片名候选资源。
  List<SearchResult> _prefetchedSearchSessionSources() {
    final session = widget.prefetchedSearchSession;
    if (session == null || widget.prefetchedSearchTitleKey.isEmpty) {
      return const <SearchResult>[];
    }
    return session.results
        .where(
          (result) =>
              TvVideoDetailScreen.normalizeSearchTitle(result.title) ==
              widget.prefetchedSearchTitleKey,
        )
        .toList(growable: false);
  }

  /// 绑定并消费搜索页共享过来的搜索会话。
  ///
  /// 详情页进入时先吃掉当前快照；如果该轮搜索还没结束，再继续订阅后续增量。
  void _attachPrefetchedSearchSession(int serial) {
    if (!_canUseDetailRoute) {
      return;
    }
    final session = widget.prefetchedSearchSession;
    if (session == null || widget.prefetchedSearchTitleKey.isEmpty) {
      _markMoreSourcesLoaded();
      return;
    }

    _detachPrefetchedSearchSession();

    void handleSessionChanged() {
      if (!_canUseDetailRoute || serial != _loadSerial) {
        _detachPrefetchedSearchSession();
        return;
      }

      final prefetchedSources = _prefetchedSearchSessionSources();
      if (prefetchedSources.isNotEmpty) {
        _mergeSources(
          prefetchedSources,
          preferAsCurrent: false,
          allowResumeFallback: session.isFinished,
        );
      }

      if (session.isFinished) {
        _detachPrefetchedSearchSession();
        _markMoreSourcesLoaded();
      }
    }

    _subscribedPrefetchedSearchSession = session;
    _prefetchedSearchSessionListener = handleSessionChanged;
    session.addListener(handleSessionChanged);
    handleSessionChanged();
  }

  /// 解绑当前共享搜索会话监听。
  void _detachPrefetchedSearchSession() {
    final session = _subscribedPrefetchedSearchSession;
    final listener = _prefetchedSearchSessionListener;
    if (session != null && listener != null) {
      session.removeListener(listener);
    }
    _subscribedPrefetchedSearchSession = null;
    _prefetchedSearchSessionListener = null;
  }

  /// 加载收藏状态。
  Future<void> _loadFavoriteState() async {
    await TvPerfTrace.async(
      'TV详情页:读取收藏状态',
      () async {
        final isFavorite = PageCacheService().isFavoritedSync(
          widget.videoInfo.source,
          widget.videoInfo.id,
        );
        if (_canUseDetailRoute) {
          setState(() => _isFavorite = isFavorite);
        }
      },
    );
  }

  /// 加载 TV 详情页自动去广告偏好。
  Future<void> _loadAdFilterPreference() async {
    await TvPerfTrace.async(
      'TV详情页:读取去广告配置',
      () async {
        final loader =
            widget.loadAdFilterEnabled ?? UserDataService.getAdFilterEnabled;
        final adFilterEnabled = await loader();
        if (!_canUseDetailRoute) {
          return;
        }
        setState(() {
          _adFilterEnabled = adFilterEnabled;
        });
      },
    );
  }

  /// 读取 TV 播放器内核配置。
  Future<void> _loadPlayerKernelPreference() async {
    final loader = widget.loadPlayerKernel ?? UserDataService.getTvPlayerKernel;
    final playerKernel = await loader();
    if (!_canUseDetailRoute) {
      return;
    }
    final shouldReplayPendingEpisode =
        !_hasResolvedTvPlayerKernel && _currentDetail != null;
    if (_tvPlayerKernel == playerKernel && _hasResolvedTvPlayerKernel) {
      return;
    }
    setState(() {
      _tvPlayerKernel = playerKernel;
      _hasResolvedTvPlayerKernel = true;
    });
    if (shouldReplayPendingEpisode) {
      unawaited(_playCurrentEpisode());
    }
  }

  /// 后台预热 M3U8 代理地址。
  Future<void> _loadM3u8ProxyUrl() async {
    await TvPerfTrace.async(
      'TV详情页:预热M3U8代理',
      () async {
        final loader =
            widget.loadM3u8ProxyUrl ?? UserDataService.getM3u8ProxyUrl;
        final proxyUrl = await loader();
        if (!_canUseDetailRoute) {
          return;
        }

        // 代理地址只给后续播放动作复用，不触发额外 rebuild，避免影响当前画面。
        _m3u8ProxyUrl = proxyUrl;
        _hasResolvedM3u8ProxyUrl = true;
      },
    );
  }

  /// 使用旧聚合加载函数加载详情。
  Future<void> _loadLegacyDetail(int serial) async {
    await TvPerfTrace.async(
      'TV详情页:旧聚合加载',
      () async {
        try {
          final data = await widget.loadDetail!(context, widget.videoInfo);
          if (!_canUseDetailRoute || serial != _loadSerial) {
            return;
          }

          setState(() {
            _currentDetail = data.currentDetail;
            _sources = data.sources;
            _recommends = data.recommends;
            _refreshSourceDisplayCaches(sourcesChanged: true);
            if (_currentDetail != null) {
              _applyInitialResumeState(_currentDetail!);
            }
            _isInitialDetailLoading = false;
            _initialSourcesLoaded = true;
            _moreSourcesLoaded = true;
          });
          if (data.currentDetail != null) {
            TvPerfTrace.instant(
              'TV详情页:旧聚合可播源',
              arguments: {
                'source': data.currentDetail!.sourceName,
                'episodes': data.currentDetail!.episodes.length,
                'sources': data.sources.length,
                'recommends': data.recommends.length,
              },
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureCurrentSelectionsVisible();
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _playCurrentEpisode());
        } catch (error) {
          debugPrint('TV 详情页聚合加载失败: $error');
          if (_canUseDetailRoute && serial == _loadSerial) {
            setState(() {
              _isInitialDetailLoading = false;
              _initialSourcesLoaded = true;
              _moreSourcesLoaded = true;
            });
          }
        }
      },
      arguments: {'serial': serial},
    );
  }

  /// 加载入口精确源，优先让详情页有可播数据。
  Future<void> _loadInitialSources(int serial) async {
    await TvPerfTrace.async(
      'TV详情页:加载精确源',
      () async {
        if (_hasPrefetchedSearchSession) {
          final sessionSources = _prefetchedSearchSessionSources();
          if (sessionSources.isNotEmpty) {
            _mergeSources(sessionSources, preferAsCurrent: true);
          }
        }

        if (widget.prefetchedSources.isNotEmpty) {
          _mergeSources(widget.prefetchedSources, preferAsCurrent: true);
        }

        final loader = widget.loadInitialSources ??
            TvVideoDetailScreen.defaultLoadInitialSources;
        try {
          final sources = await loader(context, widget.videoInfo);
          if (!_canUseDetailRoute || serial != _loadSerial) {
            return;
          }

          _mergeSources(sources, preferAsCurrent: true);
        } catch (error) {
          debugPrint('TV 详情页精确源加载失败: $error');
        }
        _markInitialSourcesLoaded();
      },
      arguments: {
        'serial': serial,
        'prefetched': widget.prefetchedSources.length,
        'sharedSession': _hasPrefetchedSearchSession,
      },
    );
  }

  /// 后台搜索并增量追加其它播放源。
  Future<void> _loadMoreSources(int serial) async {
    await TvPerfTrace.async(
      'TV详情页:后台补源',
      () async {
        if (_hasPrefetchedSearchSession) {
          _attachPrefetchedSearchSession(serial);
          return;
        }

        if (widget.prefetchedSources.isNotEmpty) {
          _markMoreSourcesLoaded();
          return;
        }

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
              if (!_canUseDetailRoute || serial != _loadSerial) {
                return;
              }
              TvPerfTrace.instant(
                'TV详情页:补源增量',
                arguments: {'count': incrementalResults.length},
              );
              _mergeSources(incrementalResults, preferAsCurrent: false);
            },
          );
          if (!_canUseDetailRoute || serial != _loadSerial) {
            return;
          }

          _mergeSources(
            sources,
            preferAsCurrent: false,
            allowResumeFallback: true,
          );
        } catch (error) {
          debugPrint('TV 详情页后台补源失败: $error');
        }
        _markMoreSourcesLoaded();
      },
      arguments: {
        'serial': serial,
        'prefetched': widget.prefetchedSources.length,
        'sharedSession': _hasPrefetchedSearchSession,
      },
    );
  }

  /// 标记精确源加载完成。
  void _markInitialSourcesLoaded() {
    if (!_canUseDetailRoute) {
      return;
    }
    setState(() {
      _initialSourcesLoaded = true;
      _refreshInitialLoadingState();
    });
  }

  /// 标记后台补源加载完成。
  void _markMoreSourcesLoaded() {
    if (!_canUseDetailRoute) {
      return;
    }
    setState(() {
      _moreSourcesLoaded = true;
      _refreshInitialLoadingState();
    });
  }

  /// 合并新播放源并在首次命中时立即起播。
  void _mergeSources(
    List<SearchResult> incoming, {
    required bool preferAsCurrent,
    bool allowResumeFallback = false,
  }) {
    if (incoming.isEmpty && _currentDetail != null) {
      return;
    }

    var shouldPlay = false;
    var shouldEnterPreviewLoading = false;
    SearchResult? firstPlayableTraceSource;
    if (!_canUseDetailRoute) {
      return;
    }
    setState(() {
      final mutableSources = List<SearchResult>.from(_sources);
      final changed =
          TvVideoDetailScreen._addUniqueSources(mutableSources, incoming);
      if (changed) {
        _sources = List<SearchResult>.unmodifiable(mutableSources);
      }

      if (_currentDetail != null) {
        final currentDetail = _currentDetail!;
        final refreshedCurrentDetail = _firstWhereOrNull(
          mutableSources,
          (source) =>
              source.source == currentDetail.source &&
              source.id == currentDetail.id,
        );
        if (refreshedCurrentDetail != null &&
            TvVideoDetailScreen._shouldReplaceSource(
              currentDetail,
              refreshedCurrentDetail,
            )) {
          final hadPlayableEpisodes = currentDetail.episodes.isNotEmpty;
          _currentDetail = refreshedCurrentDetail;
          if (hadPlayableEpisodes) {
            final maxEpisodeIndex = refreshedCurrentDetail.episodes.length - 1;
            _episodeIndex = _episodeIndex.clamp(0, maxEpisodeIndex).toInt();
            _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
          } else {
            // 空集数占位被真实源替换后，重新应用继续观看集数和时间。
            _applyInitialResumeState(refreshedCurrentDetail);
            shouldPlay = refreshedCurrentDetail.episodes.isNotEmpty;
            shouldEnterPreviewLoading = shouldPlay;
          }
        }
      }

      // 首个可播源到达后立刻结束首屏整页转圈，并切到播放器首帧等待态。
      if (_currentDetail == null && mutableSources.isNotEmpty) {
        final selectedSource = _resolveInitialPlayableSource(
          incoming: incoming,
          allSources: mutableSources,
          preferAsCurrent: preferAsCurrent,
          allowResumeFallback: allowResumeFallback,
        );
        if (selectedSource != null) {
          _currentDetail = selectedSource;
          firstPlayableTraceSource = selectedSource;
          _applyInitialResumeState(_currentDetail!);
          shouldPlay = true;
          shouldEnterPreviewLoading = true;
        }
      }

      if (changed || shouldPlay) {
        _refreshSourceDisplayCaches(sourcesChanged: changed);
      }

      _refreshInitialLoadingState();
    });

    final firstPlayableSource = firstPlayableTraceSource;
    if (firstPlayableSource != null) {
      TvPerfTrace.instant(
        'TV详情页:首个可播源',
        arguments: {
          'source': firstPlayableSource.sourceName,
          'episodes': firstPlayableSource.episodes.length,
          'incoming': incoming.length,
        },
      );
    }

    if (shouldEnterPreviewLoading) {
      _markPreviewPlayerLoading();
      _schedulePreviewChromeRefresh();
    }

    if (shouldPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_canUseDetailRoute) {
          return;
        }
        _ensureCurrentSelectionsVisible();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canUseDetailRoute) {
          _playCurrentEpisode();
        }
      });
    } else {
      _loadRecommendsIfNeeded();
    }
  }

  /// 解析详情页初始起播源。
  SearchResult? _resolveInitialPlayableSource({
    required List<SearchResult> incoming,
    required List<SearchResult> allSources,
    required bool preferAsCurrent,
    required bool allowResumeFallback,
  }) {
    if (!_shouldPrioritizeResumeSource) {
      return preferAsCurrent && incoming.isNotEmpty
          ? incoming.first
          : allSources.first;
    }

    final savedSource = _firstWhereOrNull(allSources, _matchesSavedSource);
    if (savedSource != null) {
      return savedSource;
    }

    final sameSourceKey = _firstWhereOrNull(allSources, _matchesSavedSourceKey);
    if (sameSourceKey != null) {
      return sameSourceKey;
    }

    final sameSourceName =
        _firstWhereOrNull(allSources, _matchesSavedSourceName);
    if (sameSourceName != null) {
      return sameSourceName;
    }

    if (!allowResumeFallback) {
      return null;
    }

    final sameEpisodeCountSource = _firstWhereOrNull(
      allSources,
      _hasSameEpisodeCountAsRecord,
    );
    return sameEpisodeCountSource ?? _randomSource(allSources);
  }

  /// 判断播放源是否就是播放记录保存的线路。
  bool _matchesSavedSource(SearchResult source) {
    return source.source == _resumeVideoInfo.source &&
        source.id == _resumeVideoInfo.id;
  }

  /// 判断播放源是否来自播放记录保存的资源站。
  bool _matchesSavedSourceKey(SearchResult source) {
    return _resumeVideoInfo.source.isNotEmpty &&
        source.source == _resumeVideoInfo.source;
  }

  /// 判断播放源线路名是否与播放记录保存线路一致。
  bool _matchesSavedSourceName(SearchResult source) {
    final savedSourceName = _normalizeResumeRecordKey(
      _resumeVideoInfo.sourceName,
    );
    if (savedSourceName.isEmpty) {
      return false;
    }
    return _normalizeResumeRecordKey(source.sourceName) == savedSourceName;
  }

  /// 按强到弱解析保存线路候选。
  SearchResult? _resolveSavedSourceCandidate(List<SearchResult> sources) {
    return _firstWhereOrNull(sources, _matchesSavedSource) ??
        _firstWhereOrNull(sources, _matchesSavedSourceKey) ??
        _firstWhereOrNull(sources, _matchesSavedSourceName);
  }

  /// 判断播放源集数是否与播放记录一致。
  bool _hasSameEpisodeCountAsRecord(SearchResult source) {
    return _resumeVideoInfo.totalEpisodes > 0 &&
        source.episodes.length == _resumeVideoInfo.totalEpisodes;
  }

  /// 从可用播放源中随机选择一个兜底线路。
  SearchResult _randomSource(List<SearchResult> sources) {
    return sources[math.Random().nextInt(sources.length)];
  }

  /// 刷新首屏加载状态。
  void _refreshInitialLoadingState() {
    if (_currentDetail != null ||
        (_initialSourcesLoaded && _moreSourcesLoaded)) {
      _isInitialDetailLoading = false;
    }
    if (_currentDetail == null &&
        _initialSourcesLoaded &&
        _moreSourcesLoaded &&
        _previewPlayerLoading) {
      _previewPlayerLoading = false;
    }
  }

  /// 应用入口播放记录中的续播集数和时间。
  void _applyInitialResumeState(SearchResult detail) {
    if (TvPlayRecordService.hasResumeHint(_resumeVideoInfo) &&
        _matchesVideoInfoRecord(detail)) {
      _initialResumeEpisodeIndex =
          TvPlayRecordService.episodeIndexFromVideoInfo(
        _resumeVideoInfo,
        detail.episodes.length,
      );
      _episodeIndex = _initialResumeEpisodeIndex;
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      final resumePosition =
          TvPlayRecordService.resumePositionFromVideoInfo(_resumeVideoInfo);
      _pendingInitialPlaybackPosition = resumePosition;
      _initialResumePlaybackPositionSnapshot =
          resumePosition != null && resumePosition > Duration.zero
              ? resumePosition
              : null;
      _hasAppliedInitialPlaybackPosition = false;
      return;
    }

    _initialResumeEpisodeIndex = 0;
    _episodeIndex = 0;
    _episodeGroupIndex = 0;
    _pendingInitialPlaybackPosition = null;
    _initialResumePlaybackPositionSnapshot = null;
    _hasAppliedInitialPlaybackPosition = true;
  }

  /// 判断当前源是否匹配入口播放记录。
  bool _matchesVideoInfoRecord(SearchResult detail) {
    if (_resumeVideoInfo.source.isNotEmpty &&
        _resumeVideoInfo.id.isNotEmpty &&
        detail.source == _resumeVideoInfo.source &&
        detail.id == _resumeVideoInfo.id) {
      return true;
    }

    return TvPlayRecordService.isSameVideoForPlayRecord(
      record: PlayRecord(
        id: _resumeVideoInfo.id,
        source: _resumeVideoInfo.source,
        title: _resumeVideoInfo.title,
        sourceName: _resumeVideoInfo.sourceName,
        year: _resumeVideoInfo.year,
        cover: _resumeVideoInfo.cover,
        index: _resumeVideoInfo.index,
        totalEpisodes: _resumeVideoInfo.totalEpisodes,
        playTime: _resumeVideoInfo.playTime,
        totalTime: _resumeVideoInfo.totalTime,
        saveTime: _resumeVideoInfo.saveTime,
        searchTitle: _resumeVideoInfo.searchTitle,
      ),
      targetSource: detail,
      searchTitle: _resumeVideoInfo.searchTitle.trim().isNotEmpty
          ? _resumeVideoInfo.searchTitle
          : _resumeVideoInfo.title,
    );
  }

  /// 续播记录晚于首屏源返回时，按最新记录对齐待下发的首次播放位置。
  ///
  /// 这里不主动重发起播请求，避免为了补续播信息把刚拿到的首播链路重新打断；
  /// 仅在首次 `updateDataSource(startAt)` 还没真正拿走之前，补齐待消费的续播点。
  void _syncPendingPlaybackWithLatestResumeRecord({
    required VideoInfo previousResumeVideoInfo,
  }) {
    final detail = _currentDetail;
    if (detail == null || _hasAppliedInitialPlaybackPosition) {
      return;
    }

    final previousResumePosition =
        TvPlayRecordService.resumePositionFromVideoInfo(
            previousResumeVideoInfo);
    final latestResumePosition =
        TvPlayRecordService.resumePositionFromVideoInfo(_resumeVideoInfo);
    final previousEpisodeIndex = TvPlayRecordService.episodeIndexFromVideoInfo(
      previousResumeVideoInfo,
      detail.episodes.length,
    );
    final latestEpisodeIndex = TvPlayRecordService.episodeIndexFromVideoInfo(
      _resumeVideoInfo,
      detail.episodes.length,
    );

    final resumeChanged = previousResumePosition != latestResumePosition ||
        previousEpisodeIndex != latestEpisodeIndex;
    if (!resumeChanged || !_matchesVideoInfoRecord(detail)) {
      return;
    }

    _initialResumeEpisodeIndex = latestEpisodeIndex;
    _episodeIndex = latestEpisodeIndex;
    _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
    _pendingInitialPlaybackPosition =
        latestResumePosition != null && latestResumePosition > Duration.zero
            ? latestResumePosition
            : null;
    _initialResumePlaybackPositionSnapshot = _pendingInitialPlaybackPosition;
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

  /// 记录需要用真实进度信号确认的续播 seek。
  void _rememberPendingResumeSeek(Duration? position) {
    if (position == null || position <= Duration.zero) {
      _clearPendingResumeSeek();
      return;
    }
    _pendingResumeSeekPosition = position;
    _pendingResumeSeekRetryCount = 0;
  }

  /// 清理已确认或已放弃的续播 seek。
  void _clearPendingResumeSeek() {
    _pendingResumeSeekPosition = null;
    _pendingResumeSeekRetryCount = 0;
  }

  /// 判断播放器真实进度是否已经到达续播点附近。
  bool _isAtResumePosition(Duration currentPosition, Duration resumePosition) {
    return currentPosition + const Duration(seconds: 1) >= resumePosition;
  }

  /// 真实进度仍停在续播点之前时，补一次 seek。
  ///
  /// 部分低端 Android WebView 会在 `loadedmetadata` 之前吞掉首个 seek，
  /// 这里等进度事件确认后再补偿，避免 Flutter 侧的乐观进度误判为已经续播成功。
  Future<void> _retryPendingResumeSeekAfterProgress() async {
    final resumePosition = _pendingResumeSeekPosition;
    final controller = _playerController;
    if (resumePosition == null || controller == null) {
      return;
    }

    final currentPosition = controller.currentPosition;
    if (currentPosition != null &&
        _isAtResumePosition(currentPosition, resumePosition)) {
      _clearPendingResumeSeek();
      return;
    }

    if (_pendingResumeSeekRetryCount >= _pendingResumeSeekRetryLimit) {
      debugPrint(
        'TV 详情页续播 seek 重试达到上限: ${resumePosition.inSeconds}s',
      );
      _clearPendingResumeSeek();
      return;
    }

    _pendingResumeSeekRetryCount++;
    try {
      await controller.seekTo(resumePosition);
    } catch (error) {
      debugPrint('TV 详情页续播 seek 重试失败: $error');
    }
  }

  /// 计算当前分组选集列表的动态高度。
  ///
  /// 选集标题可能比线路名长很多，这里按当前分组里最长标题实时测量文本高度，
  /// 让行高跟着内容增长，避免被固定高度压成省略号。
  double _resolveEpisodeListHeight(
    SearchResult? detail,
    List<int> visibleIndexes,
    List<String> episodes,
  ) {
    if (visibleIndexes.isEmpty) {
      return _detailChoiceChipMinHeight;
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: null,
    );
    final textStyle = FontUtils.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    const maxTextWidth =
        _detailChoiceChipMaxWidth - (_detailChoiceChipHorizontalPadding * 2);

    var maxHeight = _detailChoiceChipMinHeight;
    for (final index in visibleIndexes) {
      final title = detail?.episodesTitles.length == episodes.length
          ? detail!.episodesTitles[index]
          : '${index + 1}';
      final displayTitle = title.isEmpty ? '${index + 1}' : title;
      textPainter.text = TextSpan(text: displayTitle, style: textStyle);
      textPainter.layout(maxWidth: maxTextWidth);
      final chipHeight = math.max(
        _detailChoiceChipMinHeight,
        textPainter.height + (_detailChoiceChipVerticalPadding * 2),
      );
      maxHeight = math.max(maxHeight, chipHeight.ceilToDouble());
    }
    return maxHeight;
  }

  /// 按需加载相关推荐。
  void _loadRecommendsIfNeeded({bool forceWhenEmpty = false}) {
    if (!_canUseDetailRoute) {
      return;
    }
    if (_hasStartedRecommends) {
      return;
    }
    if (_currentDetail != null && !_hasDispatchedInitialPreviewPlayback) {
      return;
    }
    if (_currentDetail == null && !forceWhenEmpty) {
      return;
    }
    _hasStartedRecommends = true;
    TvPerfTrace.instant(
      'TV详情页:启动相关推荐任务',
      arguments: {
        'forceWhenEmpty': forceWhenEmpty,
        'hasCurrentDetail': _currentDetail != null,
      },
    );
    unawaited(_loadRecommendsAsync(_loadSerial));
  }

  /// 异步加载相关推荐。
  Future<void> _loadRecommendsAsync(int serial) async {
    await TvPerfTrace.async(
      'TV详情页:加载相关推荐',
      () async {
        final loader =
            widget.loadRecommends ?? TvVideoDetailScreen._loadRecommends;
        try {
          final recommends =
              await loader(context, widget.videoInfo, _currentDetail);
          if (!_canUseDetailRoute || serial != _loadSerial) {
            return;
          }
          setState(() => _recommends = recommends);
          TvPerfTrace.instant(
            'TV详情页:相关推荐完成',
            arguments: {'count': recommends.length},
          );

          // 搜索页推荐改为被动复用最近打开过的详情页相关推荐，不额外主动查询。
          TvSearchRecommendService.recordDetailRecommends(
            videoInfo: widget.videoInfo,
            recommends: recommends,
          );
        } catch (error) {
          debugPrint('TV 详情页推荐加载失败: $error');
        }
      },
      arguments: {'serial': serial},
    );
  }

  /// 记录播放器控制器并挂载进度监听。
  void _attachPlayerController(VideoPlayerWidgetController controller) {
    if (!_canUseDetailRoute) {
      unawaited(controller.pause());
      return;
    }
    if (identical(_playerController, controller)) {
      TvPerfTrace.instant('TV详情页:复用播放器控制器');
      _playCurrentEpisode();
      return;
    }

    TvPerfTrace.instant('TV详情页:挂载播放器控制器');
    _playerController?.removeProgressListener(_onVideoProgressUpdate);
    _playerController?.removeNetworkSpeedListener(_onPreviewNetworkSpeedUpdate);
    _playerController = controller;
    _lastRequestedPlaybackUrl = null;
    controller.addProgressListener(_onVideoProgressUpdate);
    controller.addNetworkSpeedListener(_onPreviewNetworkSpeedUpdate);
    _schedulePreviewChromeRefresh();
    _playCurrentEpisode();
  }

  /// 标记小播放器开始加载。
  void _markPreviewPlayerLoading({Duration? anchorPosition}) {
    if (!_canUseDetailRoute) {
      return;
    }
    _previewPlayerLoading = true;
    _previewPlaybackStarted = false;
    _previewLoadingAnchorPosition =
        anchorPosition ?? _playerController?.currentPosition;
    TvPerfTrace.instant(
      'TV详情页:预览loading开始',
      arguments: {
        'anchorMs': _previewLoadingAnchorPosition?.inMilliseconds,
      },
    );
  }

  /// 结束小播放器加载态，调用方必须先确认播放时间点已经前进。
  void _finishPreviewPlayerLoading() {
    if (!_previewPlayerLoading) {
      return;
    }
    _previewPlayerLoading = false;
    _previewLoadingAnchorPosition = null;
    _schedulePreviewChromeRefresh();
  }

  /// 标记当前预览视频已经真正起播。
  void _markPreviewPlaybackStarted() {
    if (_previewPlaybackStarted) {
      return;
    }
    TvPerfTrace.instant(
      'TV详情页:真实进度恢复',
      arguments: {
        'positionMs': _playerController?.currentPosition?.inMilliseconds,
      },
    );
    _previewPlaybackStarted = true;
    _finishPreviewPlayerLoading();
    _recommendsLoadTimer?.cancel();
    _recommendsLoadTimer = Timer(
      TvVideoDetailScreen.recommendsDelayAfterPlayback,
      () {
        if (_canUseDetailRoute) {
          _loadRecommendsIfNeeded();
        }
      },
    );
  }

  /// 播放进度变化时按手机端节流策略保存。
  void _onVideoProgressUpdate() {
    if (!_canUseDetailRoute) {
      return;
    }
    final position = _playerController?.currentPosition;
    if (_hasPlaybackPositionAdvanced(
      current: position,
      anchor: _previewLoadingAnchorPosition,
    )) {
      _markPreviewPlaybackStarted();
    }
    unawaited(_retryPendingResumeSeekAfterProgress());
    unawaited(_saveProgress(scene: '定时保存'));
    if (_playerController?.isPlaying == false) {
      _schedulePreviewChromeRefresh();
    }
  }

  /// 判断播放时间是否已经从本轮 loading 起点向前推进。
  bool _hasPlaybackPositionAdvanced({
    required Duration? current,
    required Duration? anchor,
  }) {
    if (current == null) {
      return false;
    }
    final baseline = anchor ?? Duration.zero;
    return current > baseline;
  }

  /// 网速变化时刷新外层 loading 文案。
  void _onPreviewNetworkSpeedUpdate() {
    if (!_canUseDetailRoute) {
      return;
    }
    _schedulePreviewChromeRefresh();
  }

  /// 保存当前播放进度。
  Future<void> _saveProgress(
      {bool force = false, required String scene}) async {
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

    final saved = await TvPlayRecordService.saveRecordAndCleanupOtherSources(
      context: context,
      playRecord: playRecord,
      keepSource: detail,
      videoInfo: widget.videoInfo,
    );
    if (!saved) {
      debugPrint('TV 保存播放进度失败 [场景: $scene]');
    }
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

    final saved = await TvPlayRecordService.saveRecordAndCleanupOtherSources(
      context: context,
      playRecord: playRecord,
      keepSource: source,
      videoInfo: widget.videoInfo,
    );
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
  }

  /// 播放当前选集。
  Future<void> _playCurrentEpisode() async {
    await TvPerfTrace.async(
      'TV详情页:播放当前选集',
      () async {
        if (!_canUseDetailRoute) {
          return;
        }
        final detail = _currentDetail;
        final controller = _playerController;
        if (detail == null || controller == null || detail.episodes.isEmpty) {
          return;
        }
        if (!_hasLoadedResumeRecord) {
          _hasPendingInitialPlaybackAfterResumeLoad = true;
          TvPerfTrace.instant('TV详情页:等待续播记录后起播');
          return;
        }
        if (!_hasResolvedTvPlayerKernel) {
          TvPerfTrace.instant('TV详情页:等待播放器内核配置后起播');
          return;
        }
        if (!_canUseDetailRoute) {
          return;
        }

        final index = _episodeIndex.clamp(0, detail.episodes.length - 1);
        final url = _resolvePlaybackUrl(detail.episodes[index]);
        final startAt = _takeInitialPlaybackPosition();
        if (_lastRequestedPlaybackUrl == url && startAt == null) {
          TvPerfTrace.instant(
            'TV详情页:跳过重复播放地址',
            arguments: {'episode': index + 1},
          );
          return;
        }
        _lastRequestedPlaybackUrl = url;
        _rememberPendingResumeSeek(startAt);
        _markPreviewPlayerLoading(anchorPosition: startAt);
        _schedulePreviewChromeRefresh();
        await TvPerfTrace.async(
          'TV详情页:播放器updateDataSource',
          () {
            return controller.updateDataSource(url, startAt: startAt);
          },
          arguments: {
            'episode': index + 1,
            'source': detail.sourceName,
            'startAtMs': startAt?.inMilliseconds,
            'proxied':
                _m3u8ProxyUrl.isNotEmpty && url.startsWith(_m3u8ProxyUrl),
          },
        );
        if (!_canUseDetailRoute) {
          return;
        }
        if (!_hasDispatchedInitialPreviewPlayback) {
          _hasDispatchedInitialPreviewPlayback = true;
          TvPerfTrace.instant('TV详情页:首次播放地址已下发');
        }
        await _seekToInitialPlaybackPositionIfNeeded(controller, startAt);
      },
      arguments: {
        'episode': _episodeIndex + 1,
        'hasDetail': _currentDetail != null,
        'hasController': _playerController != null,
      },
    );
  }

  /// 在底层播放器没有吃到 `startAt` 时，按手机端逻辑再补一次 seek。
  Future<void> _seekToInitialPlaybackPositionIfNeeded(
    VideoPlayerWidgetController controller,
    Duration? startAt,
  ) async {
    if (startAt == null || startAt <= Duration.zero) {
      return;
    }

    final currentPosition = controller.currentPosition;
    final alreadyAtResumePosition = currentPosition != null &&
        (currentPosition - startAt).abs() <= const Duration(seconds: 1);
    if (alreadyAtResumePosition) {
      return;
    }
    if (currentPosition != null &&
        currentPosition > Duration.zero &&
        currentPosition > startAt) {
      // 播放器已推进到续播点之后时保留真实进度，避免初始化兜底把进度回拉到旧记录。
      return;
    }

    try {
      await controller.seekTo(startAt);
    } catch (error) {
      debugPrint('TV 详情页续播 seek 兜底失败: $error');
    }
  }

  /// 解析当前可直接下发给播放器的播放地址。
  ///
  /// 详情页首播优先保证“先播起来”，代理配置如果还在后台读取，就先用原地址起播，
  /// 待缓存就绪后再给后续换集、换源和进全屏动作复用。
  String _resolvePlaybackUrl(String url) {
    if (!_hasResolvedM3u8ProxyUrl ||
        _m3u8ProxyUrl.isEmpty ||
        !url.startsWith('http')) {
      return url;
    }
    final proxiedUrl = '$_m3u8ProxyUrl${Uri.encodeComponent(url)}';
    if (_tvPlayerKernel == TvPlayerKernel.exo) {
      // Exo 内核内部已有专用 M3U8 过滤代理，避免再叠加用户配置的外部代理。
      return resolveAndroidTvExoSourceUrl(url: proxiedUrl, originalUrl: url);
    }
    return proxiedUrl;
  }

  /// 切换播放源。
  void _switchSource(SearchResult source) {
    if (!_canUseDetailRoute) {
      return;
    }
    if (_currentDetail?.source == source.source &&
        _currentDetail?.id == source.id) {
      return;
    }
    final switchSerial = ++_sourceSwitchRecordSerial;
    final currentPlaybackPosition = _playerController?.currentPosition;
    final currentProgress =
        currentPlaybackPosition?.inSeconds ?? _lastSavePosition ?? 0;
    final currentTotalTime =
        _playerController?.duration?.inSeconds ?? widget.videoInfo.totalTime;
    final currentEpisode = _episodeIndex;

    setState(() {
      // 用户在详情页里主动切换过线路后，列表顺序恢复为纯排序结果，
      // 不再继续把当前线路强行挪到第一位。
      _pinCurrentDetailFirst = false;
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = currentEpisode.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = currentPlaybackPosition != null &&
              currentPlaybackPosition > Duration.zero
          ? currentPlaybackPosition
          : null;
      _initialResumePlaybackPositionSnapshot = null;
      _hasAppliedInitialPlaybackPosition =
          _pendingInitialPlaybackPosition == null;
      _lastRequestedPlaybackUrl = null;
      _refreshSourceDisplayCaches(sourcesChanged: false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseDetailRoute) {
        return;
      }
      _ensureCurrentSelectionsVisible();
      _playCurrentEpisode();
    });
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
    if (!_canUseDetailRoute || index == _episodeIndex) {
      return;
    }
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = index ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _initialResumePlaybackPositionSnapshot = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseDetailRoute) {
        return;
      }
      _ensureCurrentSelectionsVisible();
    });
  }

  /// 同步全屏覆盖层内切换后的播放线路。
  void _handleFullscreenSourceChanged(SearchResult source) {
    if (!_canUseDetailRoute) {
      return;
    }
    final currentPlaybackPosition = _playerController?.currentPosition;
    setState(() {
      // 全屏内的主动换线路也属于用户显式选择，返回详情页后继续沿用排序顺序。
      _pinCurrentDetailFirst = false;
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = _episodeIndex.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = currentPlaybackPosition != null &&
              currentPlaybackPosition > Duration.zero
          ? currentPlaybackPosition
          : null;
      _initialResumePlaybackPositionSnapshot = null;
      _hasAppliedInitialPlaybackPosition =
          _pendingInitialPlaybackPosition == null;
      _lastRequestedPlaybackUrl = null;
      _refreshSourceDisplayCaches(sourcesChanged: false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseDetailRoute) {
        return;
      }
      _ensureCurrentSelectionsVisible();
    });
  }

  /// 切换选集。
  void _switchEpisode(int index) {
    _switchEpisodeWithScene(index, scene: '切换选集前');
  }

  /// 按指定场景切换选集。
  void _switchEpisodeWithScene(int index, {required String scene}) {
    if (!_canUseDetailRoute) {
      return;
    }
    unawaited(_saveProgress(force: true, scene: scene));
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = index ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition = null;
      _initialResumePlaybackPositionSnapshot = null;
      _hasAppliedInitialPlaybackPosition = true;
      _lastRequestedPlaybackUrl = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canUseDetailRoute) {
        return;
      }
      _ensureCurrentSelectionsVisible();
      _playCurrentEpisode();
    });
  }

  /// 处理详情页播放器播放完成后的自动下一集。
  void _handlePreviewVideoCompleted() {
    final detail = _currentDetail;
    if (detail == null || _episodeIndex >= detail.episodes.length - 1) {
      return;
    }
    _switchEpisodeWithScene(
      _episodeIndex + 1,
      scene: '自动播放下一集',
    );
  }

  /// 切换选集分组。
  void _switchEpisodeGroup(
    int index, {
    bool pinCurrentWhenUnchanged = true,
  }) {
    _commitEpisodeGroupSwitch(
      index,
      pinCurrentWhenUnchanged: pinCurrentWhenUnchanged,
    );
  }

  /// 提交选集分组切换并刷新可见选集。
  void _commitEpisodeGroupSwitch(
    int index, {
    bool pinCurrentWhenUnchanged = true,
  }) {
    if (_episodeGroupIndex == index) {
      if (pinCurrentWhenUnchanged) {
        _pinEpisodeGroupAndEpisodeNearLeadingEdge(index, _episodeIndex);
      }
      return;
    }
    setState(() => _episodeGroupIndex = index);
    final groupIndexes = _episodeIndexesForGroup(
      _currentDetail?.episodes.length ?? 0,
      index,
    );
    int? targetEpisodeIndex;
    if (!_episodeBelongsToGroup(_episodeIndex, index) &&
        groupIndexes.isNotEmpty) {
      targetEpisodeIndex = groupIndexes.first;
      _rememberFocusedEpisode(targetEpisodeIndex);
    } else {
      targetEpisodeIndex = _episodeIndex;
    }
    _pinEpisodeGroupAndEpisodeNearLeadingEdge(index, targetEpisodeIndex);
  }

  /// 延后定位分组和选集，等待列表完成本轮构建。
  void _pinEpisodeGroupAndEpisodeNearLeadingEdge(
    int groupIndex,
    int? episodeIndex,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _pinEpisodeGroupNearLeadingEdge(groupIndex);
      if (episodeIndex != null) {
        _pinEpisodeNearLeadingEdge(episodeIndex);
      }
    });
  }

  /// 获取选集分组数量。
  int _episodeGroupCount(int total) {
    if (total <= _episodeGroupSize) {
      return 0;
    }
    return ((total - 1) ~/ _episodeGroupSize) + 1;
  }

  /// 判断指定选集是否属于某个分组。
  bool _episodeBelongsToGroup(int episodeIndex, int groupIndex) {
    final detail = _currentDetail;
    if (detail == null ||
        episodeIndex < 0 ||
        episodeIndex >= detail.episodes.length) {
      return false;
    }
    return episodeIndex ~/ _episodeGroupSize == groupIndex;
  }

  /// 获取选集分组标题。
  String _episodeGroupLabel(int groupIndex, int total) {
    final start = groupIndex * _episodeGroupSize + 1;
    final rawEnd = start + _episodeGroupSize - 1;
    final end = rawEnd > total ? total : rawEnd;
    return start == end ? '$start' : '$start-$end';
  }

  /// 吞掉边界方向键，避免默认焦点系统跳到非预期控件。
  void _keepCurrentFocusAtBoundary() {}

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
      _scrollToTop();
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

    final targetNode = bestNode ?? _playerFocusNode;
    targetNode.requestFocus();
    // 线路向上回到预览播放器时，要露出完整画面而不是只显示播放器底边。
    if (targetNode == _playerFocusNode) {
      _scrollToTop();
    }
  }

  /// 处理换源列表边界方向键。
  ///
  /// 最左和最右线路继续横向移动时，要同时保住当前焦点和边界抖动反馈，
  /// 避免焦点短暂漂移后白色描边消失。
  void _handleSourceBoundaryArrow(
    SearchResult source,
    GlobalKey<TvEdgeShakeState> edgeShakeKey,
    AxisDirection direction,
  ) {
    final node = _sourceFocusNodeFor(source);
    _rememberFocusedSource(source);
    edgeShakeKey.currentState?.shake(direction);
    if (!node.canRequestFocus) {
      return;
    }
    node.requestFocus();
    _ensureHorizontalTargetVisible(_sourceTargetKeyFor(source));
  }

  /// 记录最近一次获焦的线路。
  void _rememberFocusedSource(SearchResult source) {
    _lastFocusedSourceKey = _sourceFocusKey(source);
  }

  /// 记录最近一次获焦的选集。
  void _rememberFocusedEpisode(int index) {
    _lastFocusedEpisodeIndex = index;
  }

  /// 记录最近一次获焦的选集分组。
  void _rememberFocusedEpisodeGroup(int index) {
    _lastFocusedEpisodeGroupIndex = index;
  }

  /// 记录最近一次获焦的推荐卡片。
  void _rememberFocusedRecommend(VideoInfo videoInfo) {
    _lastFocusedRecommendKey = _recommendFocusKey(videoInfo);
  }

  /// 标记指定横向列表本次只恢复焦点，不自动修正横向滚动位置。
  void _suppressNextHorizontalReveal(String groupKey) {
    _suppressedHorizontalRevealGroups.add(groupKey);
  }

  /// 若本次获焦来自纵向焦点恢复，则消费跳过标记。
  bool _consumeHorizontalRevealSuppression(String groupKey) {
    return _suppressedHorizontalRevealGroups.remove(groupKey);
  }

  /// 纵向恢复焦点时保留横向 offset，普通左右移动时仍按安全区滚动。
  bool _scheduleHorizontalTargetRevealIfNeeded({
    required String groupKey,
    required ScrollController controller,
    required GlobalKey targetKey,
    double focusedScale = 1,
  }) {
    if (_consumeHorizontalRevealSuppression(groupKey)) {
      return false;
    }
    _scheduleHorizontalTargetToSafeLeadingInset(
      controller: controller,
      targetKey: targetKey,
      focusedScale: focusedScale,
    );
    return true;
  }

  /// 在条目真正获焦后，再按安全留白把目标推到屏幕左边。
  void _scheduleHorizontalTargetToSafeLeadingInset({
    required ScrollController controller,
    required GlobalKey targetKey,
    double focusedScale = 1,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateHorizontalListTargetToSafeLeadingInset(
          controller: controller,
          targetKey: targetKey,
          focusedScale: focusedScale,
        );
      }
    });
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

  /// 临时控制选集分组是否允许获焦。
  void _setEpisodeGroupFocusEnabled(bool enabled) {
    for (final node in _episodeGroupFocusNodes.values) {
      node.canRequestFocus = enabled;
    }
  }

  /// 临时控制选集以外区域是否允许获焦。
  void _setNonEpisodeFocusEnabled(bool enabled) {
    _playerFocusNode.canRequestFocus = enabled;
    _fullscreenFocusNode.canRequestFocus = enabled;
    _favoriteFocusNode.canRequestFocus = enabled;
    _searchFocusNode.canRequestFocus = enabled;
    for (final node in _sourceFocusNodes.values) {
      node.canRequestFocus = enabled;
    }
    for (final node in _recommendFocusNodes.values) {
      node.canRequestFocus = enabled;
    }
    _bottomActionFocusNode.canRequestFocus = enabled;
  }

  /// 左右跨组选集时短暂锁住非选集行焦点。
  void _lockNonEpisodeRowsDuringHorizontalEpisodeMove() {
    // 选集左右跨组会先重建当前选集行。过渡期间锁住非选集焦点，
    // 避免 FocusScope 临时回落到推荐区，再被下一帧拉回目标选集造成抖动。
    _setEpisodeGroupFocusEnabled(false);
    _setNonEpisodeFocusEnabled(false);
  }

  /// 恢复非选集行焦点能力。
  void _unlockNonEpisodeRowsAfterHorizontalEpisodeMove() {
    _setEpisodeGroupFocusEnabled(true);
    _setNonEpisodeFocusEnabled(true);
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
    final targetNode = _preferredVisibleSourceFocusNode();
    if (targetNode == null) {
      return;
    }
    _suppressNextHorizontalReveal(_sourceFocusGroupKey);
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(
      targetNode,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
  }

  /// 从播放器向下进入当前线路或最近停留的线路。
  void _focusPreferredSource() {
    final targetNode = _preferredVisibleSourceFocusNode();
    if (targetNode == null) {
      return;
    }
    _suppressNextHorizontalReveal(_sourceFocusGroupKey);
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(
      targetNode,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
  }

  /// 从换源列表向下进入当前分组里与当前线路最近的选集。
  void _focusPreferredEpisodeInCurrentGroup() {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      _focusPreferredRecommend();
      return;
    }
    final node = _nearestVisibleEpisodeFocusNodeFromCurrentFocus() ??
        _preferredVisibleEpisodeFocusNode();
    if (node == null) {
      return;
    }
    _suppressNextHorizontalReveal(_episodeFocusGroupKey);
    node.requestFocus();
    _ensureFocusedNodeVisible(
      node,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
  }

  /// 从选集向下进入与当前选集最近的分组或推荐。
  void _focusPreferredEpisodeDownTarget() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount > 1) {
      final node = _nearestVisibleEpisodeGroupFocusNodeFromCurrentFocus() ??
          _preferredVisibleEpisodeGroupFocusNode();
      if (node != null) {
        _suppressNextHorizontalReveal(_episodeGroupFocusGroupKey);
        node.requestFocus();
        _ensureFocusedNodeVisible(
          node,
          minimumForwardScroll: _detailVerticalFocusMinForwardStep,
        );
      }
      return;
    }
    _focusPreferredRecommend();
  }

  /// 从分组向上回到对应分组内的选集。
  ///
  /// 分组选项和选集列表是上下两条独立横向列表，用户停在哪个分组，
  /// 上键就回到这个分组里的就近选集，保持焦点移动符合当前视觉位置。
  void _focusEpisodeOptionForGroup(
    int groupIndex, {
    int? preferredEpisodeIndex,
    bool useNearestVisible = false,
  }) {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return;
    }
    final groupCount = _episodeGroupCount(detail.episodes.length);
    final normalizedGroupIndex =
        groupCount == 0 ? 0 : groupIndex.clamp(0, groupCount - 1).toInt();

    bool requestEpisodeFocus() {
      if (!mounted) {
        return false;
      }
      if (_focusEpisodeOptionInGroup(
        normalizedGroupIndex,
        preferredEpisodeIndex,
      )) {
        return true;
      }
      if (useNearestVisible &&
          _focusNearestVisibleEpisodeOptionInGroup(normalizedGroupIndex)) {
        return true;
      }
      if (_focusEpisodeOptionInGroup(
        normalizedGroupIndex,
        _lastFocusedEpisodeIndex,
      )) {
        return true;
      }
      if (_focusEpisodeOptionInGroup(normalizedGroupIndex, _episodeIndex)) {
        return true;
      }
      return _focusFirstVisibleEpisodeOption(groupIndex: normalizedGroupIndex);
    }

    if (_episodeGroupIndex == normalizedGroupIndex) {
      if (requestEpisodeFocus()) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestEpisodeFocus();
      });
      return;
    }

    final groupIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      normalizedGroupIndex,
    );
    setState(() {
      _episodeGroupIndex = normalizedGroupIndex;
      if (!_episodeBelongsToGroup(
            _lastFocusedEpisodeIndex ?? _episodeIndex,
            normalizedGroupIndex,
          ) &&
          groupIndexes.isNotEmpty) {
        _lastFocusedEpisodeIndex = groupIndexes.first;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestEpisodeFocus();
    });
  }

  /// 分组内最后一集继续右移时，进入下一组选集的第一集。
  void _focusNextEpisodeGroupFirstItemOrShake(
    int groupIndex,
    GlobalKey<TvEdgeShakeState> edgeShakeKey,
  ) {
    final detail = _currentDetail;
    final total = detail?.episodes.length ?? 0;
    final groupCount = _episodeGroupCount(total);
    final nextGroupIndex = groupIndex + 1;
    if (detail == null || groupCount <= 1 || nextGroupIndex >= groupCount) {
      // 没有下一组选集时保留原来的边界抖动反馈。
      edgeShakeKey.currentState?.shake(AxisDirection.right);
      return;
    }

    final nextGroupEpisodeIndexes = _episodeIndexesForGroup(
      total,
      nextGroupIndex,
    );
    if (nextGroupEpisodeIndexes.isEmpty) {
      // 分组数据异常时也只停留在当前边界，不让焦点跳到未知位置。
      edgeShakeKey.currentState?.shake(AxisDirection.right);
      return;
    }

    final firstEpisodeIndex = nextGroupEpisodeIndexes.first;
    _lockNonEpisodeRowsDuringHorizontalEpisodeMove();
    if (_episodeListScrollController.hasClients) {
      // 从上一组末尾进入下一组时先回到组首，确保虚拟列表构建下一组第一集。
      _episodeListScrollController.jumpTo(0);
    }
    _focusEpisodeOptionForGroup(
      nextGroupIndex,
      preferredEpisodeIndex: firstEpisodeIndex,
    );
    _pinEpisodeGroupAndEpisodeNearLeadingEdge(
      nextGroupIndex,
      firstEpisodeIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _unlockNonEpisodeRowsAfterHorizontalEpisodeMove();
        }
      });
    });
  }

  /// 分组内第一集继续左移时，进入上一组选集的最后一集。
  void _focusPreviousEpisodeGroupLastItemOrShake(
    int groupIndex,
    GlobalKey<TvEdgeShakeState> edgeShakeKey,
  ) {
    final detail = _currentDetail;
    final total = detail?.episodes.length ?? 0;
    final groupCount = _episodeGroupCount(total);
    final previousGroupIndex = groupIndex - 1;
    if (detail == null || groupCount <= 1 || previousGroupIndex < 0) {
      // 没有上一组选集时保留原来的边界抖动反馈。
      edgeShakeKey.currentState?.shake(AxisDirection.left);
      return;
    }

    final previousGroupEpisodeIndexes = _episodeIndexesForGroup(
      total,
      previousGroupIndex,
    );
    if (previousGroupEpisodeIndexes.isEmpty) {
      // 分组数据异常时也只停留在当前边界，不让焦点跳到未知位置。
      edgeShakeKey.currentState?.shake(AxisDirection.left);
      return;
    }

    final lastEpisodeIndex = previousGroupEpisodeIndexes.last;
    _lastFocusedEpisodeIndex = lastEpisodeIndex;
    _lockNonEpisodeRowsDuringHorizontalEpisodeMove();
    setState(() => _episodeGroupIndex = previousGroupIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_episodeListScrollController.hasClients) {
        // 上一组最后一集通常在懒加载列表尾部，先滚到尾部确保节点构建。
        final position = _episodeListScrollController.position;
        _episodeListScrollController.jumpTo(position.maxScrollExtent);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final focused = _focusEpisodeOptionInGroup(
          previousGroupIndex,
          lastEpisodeIndex,
        );
        if (!focused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _focusEpisodeOptionInGroup(
                previousGroupIndex,
                lastEpisodeIndex,
              );
              _unlockNonEpisodeRowsAfterHorizontalEpisodeMove();
            }
          });
        } else {
          _unlockNonEpisodeRowsAfterHorizontalEpisodeMove();
        }
        _pinEpisodeGroupAndEpisodeNearLeadingEdge(
          previousGroupIndex,
          lastEpisodeIndex,
        );
      });
    });
  }

  /// 聚焦指定分组里的选集。
  bool _focusEpisodeOptionInGroup(int groupIndex, int? episodeIndex) {
    if (episodeIndex == null ||
        !_episodeBelongsToGroup(episodeIndex, groupIndex)) {
      return false;
    }
    final node = _visibleNodeForIndex(
      _episodeTargetKeys,
      _episodeFocusNodes,
      episodeIndex,
    );
    if (node == null) {
      return false;
    }
    _rememberFocusedEpisode(episodeIndex);
    _suppressNextHorizontalReveal(_episodeFocusGroupKey);
    node.requestFocus();
    _ensureFocusedNodeVisible(
      node,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
    return true;
  }

  /// 在当前选集行内左右移动到相邻集数。
  bool _focusEpisodeNeighborInCurrentGroup(int groupIndex, int episodeIndex) {
    if (!_episodeBelongsToGroup(episodeIndex, groupIndex)) {
      return false;
    }
    final node = _visibleNodeForIndex(
      _episodeTargetKeys,
      _episodeFocusNodes,
      episodeIndex,
    );
    if (node == null) {
      return false;
    }
    _rememberFocusedEpisode(episodeIndex);
    node.requestFocus();
    _ensureFocusedNodeVisible(
      node,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
    return true;
  }

  /// 聚焦当前分组内第一条已构建的选集。
  bool _focusFirstVisibleEpisodeOption({required int groupIndex}) {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return false;
    }
    final visibleIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      groupIndex,
    );
    for (final index in visibleIndexes) {
      if (_focusEpisodeOptionInGroup(groupIndex, index)) {
        return true;
      }
    }
    return false;
  }

  /// 从选集或分组向上回到与当前选集最近的播放源。
  void _focusSelectedSourceFromBelow() {
    final node = _nearestVisibleSourceFocusNodeFromCurrentFocus() ??
        _preferredVisibleSourceFocusNode();
    if (node == null) {
      return;
    }
    _suppressNextHorizontalReveal(_sourceFocusGroupKey);
    node.requestFocus();
    _ensureFocusedNodeVisible(node);
  }

  /// 从分组向下进入最近停留的推荐。
  void _focusPreferredRecommend() {
    final targetNode = _preferredVisibleRecommendNode();
    if (targetNode == null) {
      _focusBottomAction();
      return;
    }
    _suppressNextHorizontalReveal(_recommendFocusGroupKey);
    targetNode.requestFocus();
    _ensureFocusedNodeVisible(
      targetNode,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
  }

  /// 从推荐向下进入底部回到顶部按钮。
  void _focusBottomAction() {
    if (!_bottomActionFocusNode.canRequestFocus) {
      return;
    }
    _bottomActionFocusNode.requestFocus();
    _ensureFocusedNodeVisible(
      _bottomActionFocusNode,
      minimumForwardScroll: _detailVerticalFocusMinForwardStep,
    );
  }

  /// 从推荐向上回到选集分组或选集。
  void _focusRecommendationUpTarget() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount > 1) {
      final groupNode = _preferredVisibleEpisodeGroupFocusNode();
      if (groupNode != null) {
        _suppressNextHorizontalReveal(_episodeGroupFocusGroupKey);
        groupNode.requestFocus();
        _ensureFocusedNodeVisible(groupNode);
        return;
      }
    }
    final episodeNode = _preferredVisibleEpisodeFocusNode();
    if (episodeNode != null) {
      _suppressNextHorizontalReveal(_episodeFocusGroupKey);
      episodeNode.requestFocus();
      _ensureFocusedNodeVisible(episodeNode);
      return;
    }
    _focusPreferredEpisodeInCurrentGroup();
  }

  /// 让指定焦点节点对应控件在详情页外层滚动视口中可见。
  void _ensureFocusedNodeVisible(
    FocusNode node, {
    double minimumForwardScroll = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = node.context;
      if (context == null || !context.mounted) {
        return;
      }
      _animateDetailVerticalFocusIntoPosition(
        context,
        minimumForwardScroll: minimumForwardScroll,
      );
    });
  }

  /// 安排详情页滚动到底部。
  ///
  /// 推荐卡片获焦时，用户期望直接看到相关推荐和底部区域；
  /// 延后一帧执行可避开同一轮焦点恢复里的中线对齐动画。
  void _scheduleDetailPageScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final position = _scrollController.position;
        final targetOffset = position.maxScrollExtent;
        if ((position.pixels - targetOffset).abs() <
            _detailVerticalFocusOffsetEpsilon) {
          return;
        }
        position.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  /// 让详情页外层滚动容器把当前焦点平滑推到中线附近。
  ///
  /// 线路、选集、分组这些控件都嵌在横向列表里，直接调用 `Scrollable.maybeOf`
  /// 只能拿到它们自己的横向滚动容器，导致整页不会跟着轻推。
  /// 这里改成显式驱动详情页外层 `SingleChildScrollView`，保持“焦点基本待在屏幕中间”
  /// 的纵向浏览手感。
  void _animateDetailVerticalFocusIntoPosition(
    BuildContext targetContext, {
    double minimumForwardScroll = 0,
  }) {
    if (!_scrollController.hasClients) {
      return;
    }

    final targetRect = _globalRectForContext(targetContext);
    if (targetRect == null) {
      return;
    }

    final viewportContext =
        _scrollController.position.context.notificationContext;
    if (viewportContext == null || !viewportContext.mounted) {
      return;
    }
    final viewportRect = _globalRectForContext(viewportContext);
    if (viewportRect == null) {
      return;
    }

    final position = _scrollController.position;
    final desiredTop = viewportRect.top +
        ((viewportRect.height - targetRect.height) *
            _detailVerticalFocusAlignment);
    var delta = targetRect.top - desiredTop;
    if (delta > 0 && delta < minimumForwardScroll) {
      delta = minimumForwardScroll;
    }
    if (delta > _detailVerticalFocusMaxStep) {
      delta = _detailVerticalFocusMaxStep;
    } else if (delta < -_detailVerticalFocusMaxStep) {
      delta = -_detailVerticalFocusMaxStep;
    }
    final requiredVisibleDelta = _requiredVisibleDelta(
      targetRect: targetRect,
      viewportRect: viewportRect,
    );
    if (requiredVisibleDelta > 0 && requiredVisibleDelta > delta) {
      // 向下滚动时，完整可见优先级高于“单次最多轻推一步”。
      delta = requiredVisibleDelta;
    } else if (requiredVisibleDelta < 0 && requiredVisibleDelta < delta) {
      // 向上滚动时同样先保证焦点不要被顶部裁掉，再谈中线对齐。
      delta = requiredVisibleDelta;
    }
    final targetOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() <
        _detailVerticalFocusOffsetEpsilon) {
      return;
    }
    position.animateTo(
      targetOffset.toDouble(),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// 计算“至少完整显示当前焦点控件”所需的最小滚动距离。
  ///
  /// 返回正值表示需要继续向下滚，负值表示需要继续向上滚，0 表示当前已完整可见。
  double _requiredVisibleDelta({
    required Rect targetRect,
    required Rect viewportRect,
  }) {
    final visibleTop = viewportRect.top + _detailVerticalFocusVisibleInset;
    final visibleBottom =
        viewportRect.bottom - _detailVerticalFocusVisibleInset;
    if (targetRect.top < visibleTop) {
      return targetRect.top - visibleTop;
    }
    if (targetRect.bottom > visibleBottom) {
      return targetRect.bottom - visibleBottom;
    }
    return 0;
  }

  /// 让选集尽量贴到横向列表最左侧。
  void _pinEpisodeNearLeadingEdge(int episodeIndex) {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return;
    }
    final groupCount = _episodeGroupCount(detail.episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      groupIndex,
    );
    final localIndex = visibleIndexes.indexOf(episodeIndex);
    if (localIndex < 0) {
      return;
    }
    if (_animateHorizontalListTargetToSafeLeadingInset(
      controller: _episodeListScrollController,
      targetKey: _episodeTargetKeyFor(episodeIndex),
    )) {
      return;
    }
    _animateHorizontalListToLeadingIndex(
      controller: _episodeListScrollController,
      index: localIndex,
      itemCount: visibleIndexes.length,
      spacing: 10,
      fallbackItemExtent: 98,
    );
  }

  /// 让选集分组尽量贴到横向列表最左侧。
  void _pinEpisodeGroupNearLeadingEdge(int groupIndex) {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount <= 1 || groupIndex < 0 || groupIndex >= groupCount) {
      return;
    }
    _animateHorizontalListTargetToSafeLeadingInset(
      controller: _episodeGroupListScrollController,
      targetKey: _episodeGroupTargetKeyFor(groupIndex),
    );
  }

  /// 确保当前选中的线路、选集和分组默认落在可视窗口内。
  void _ensureCurrentSelectionsVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final detail = _currentDetail;
      if (detail == null) {
        return;
      }

      final displaySources = _cachedDisplaySources;
      final selectedSourceIndex = displaySources.indexWhere(
        (source) => source.source == detail.source && source.id == detail.id,
      );
      if (selectedSourceIndex >= 0) {
        _jumpHorizontalListToLeadingIndex(
          controller: _sourceListScrollController,
          index: selectedSourceIndex,
          itemCount: displaySources.length,
          spacing: 12,
          fallbackItemExtent: 148,
        );
      }

      if (detail.episodes.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _ensureHorizontalTargetVisible(_sourceTargetKeyFor(detail));
        });
        return;
      }

      final episodeGroupCount = _episodeGroupCount(detail.episodes.length);
      final selectedGroupIndex = episodeGroupCount == 0
          ? 0
          : _episodeGroupIndex.clamp(0, episodeGroupCount - 1).toInt();
      if (episodeGroupCount > 1) {
        _jumpHorizontalListToLeadingIndex(
          controller: _episodeGroupListScrollController,
          index: selectedGroupIndex,
          itemCount: episodeGroupCount,
          spacing: 18,
          fallbackItemExtent: 110,
        );
      }

      final visibleEpisodeIndexes = _episodeIndexesForGroup(
        detail.episodes.length,
        selectedGroupIndex,
      );
      final selectedEpisodeLocalIndex = visibleEpisodeIndexes.indexOf(
        _episodeIndex,
      );
      if (selectedEpisodeLocalIndex >= 0) {
        _jumpHorizontalListToLeadingIndex(
          controller: _episodeListScrollController,
          index: selectedEpisodeLocalIndex,
          itemCount: visibleEpisodeIndexes.length,
          spacing: 10,
          fallbackItemExtent: 98,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _ensureHorizontalTargetVisible(_sourceTargetKeyFor(detail));
        if (episodeGroupCount > 1) {
          _ensureHorizontalTargetVisible(
            _episodeGroupTargetKeyFor(selectedGroupIndex),
          );
        }
        if (!_jumpHorizontalListTargetToSafeLeadingInset(
          controller: _episodeListScrollController,
          targetKey: _episodeTargetKeyFor(_episodeIndex),
        )) {
          _ensureHorizontalTargetVisible(_episodeTargetKeyFor(_episodeIndex));
        }
      });
    });
  }

  /// 按索引把横向列表先跳到左侧起点，避免首屏仍停在中间。
  void _jumpHorizontalListToLeadingIndex({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required double spacing,
    required double fallbackItemExtent,
  }) {
    if (!controller.hasClients || itemCount <= 0 || index < 0) {
      return;
    }
    final position = controller.position;
    final viewportExtent = position.viewportDimension;
    if (viewportExtent <= 0) {
      return;
    }
    final totalSpacing = math.max(0, itemCount - 1) * spacing;
    final estimatedItemExtent =
        ((position.maxScrollExtent + viewportExtent - totalSpacing) / itemCount)
            .clamp(fallbackItemExtent, double.infinity);
    final itemExtent = estimatedItemExtent.isFinite && estimatedItemExtent > 0
        ? estimatedItemExtent
        : fallbackItemExtent;
    final targetOffset = (index * (itemExtent + spacing)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() < 1) {
      return;
    }
    controller.jumpTo(targetOffset.toDouble());
  }

  /// 按真实组件位置把横向列表立即校正到左安全区。
  ///
  /// 初始进入详情页时先按索引粗略跳到当前选集，让目标项参与构建；随后再用真实
  /// 渲染位置补一次无动画校正，避免估算宽度把左右 padding 平摊进 item 后导致贴边。
  bool _jumpHorizontalListTargetToSafeLeadingInset({
    required ScrollController controller,
    required GlobalKey targetKey,
  }) {
    final targetOffset = _horizontalListTargetSafeLeadingOffset(
      controller: controller,
      targetKey: targetKey,
    );
    if (targetOffset == null) {
      return false;
    }
    if ((controller.position.pixels - targetOffset).abs() < 1) {
      return true;
    }
    controller.jumpTo(targetOffset);
    return true;
  }

  /// 按索引把横向列表尽量滚到左侧起点，保持当前焦点项排在前面。
  void _animateHorizontalListToLeadingIndex({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required double spacing,
    required double fallbackItemExtent,
  }) {
    if (!controller.hasClients || itemCount <= 0 || index < 0) {
      return;
    }
    final position = controller.position;
    final viewportExtent = position.viewportDimension;
    if (viewportExtent <= 0) {
      return;
    }
    final totalSpacing = math.max(0, itemCount - 1) * spacing;
    final estimatedItemExtent =
        ((position.maxScrollExtent + viewportExtent - totalSpacing) / itemCount)
            .clamp(fallbackItemExtent, double.infinity);
    final itemExtent = estimatedItemExtent.isFinite && estimatedItemExtent > 0
        ? estimatedItemExtent
        : fallbackItemExtent;
    final targetOffset = (index * (itemExtent + spacing)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() < 1) {
      return;
    }
    position.animateTo(
      targetOffset.toDouble(),
      duration: TvFocusScroll.duration,
      curve: TvFocusScroll.curve,
    );
  }

  /// 按真实组件位置把横向列表推到左安全区。
  ///
  /// 线路按钮宽度差异比较大，单纯按平均宽度估算会偏得很厉害，
  /// 这里改成读取真实渲染位置，确保获焦项能回到默认 36px 安全区。
  bool _animateHorizontalListTargetToSafeLeadingInset({
    required ScrollController controller,
    required GlobalKey targetKey,
    double focusedScale = 1,
  }) {
    final targetOffset = _horizontalListTargetSafeLeadingOffset(
      controller: controller,
      targetKey: targetKey,
      focusedScale: focusedScale,
    );
    if (targetOffset == null) {
      return false;
    }
    if ((controller.position.pixels - targetOffset).abs() < 1) {
      return true;
    }
    controller.position.animateTo(
      targetOffset,
      duration: TvFocusScroll.duration,
      curve: TvFocusScroll.curve,
    );
    return true;
  }

  /// 计算目标控件对齐左安全区时的横向滚动位置。
  double? _horizontalListTargetSafeLeadingOffset({
    required ScrollController controller,
    required GlobalKey targetKey,
    double focusedScale = 1,
  }) {
    if (!controller.hasClients) {
      return null;
    }
    final targetRect = _globalRectForKey(targetKey);
    if (targetRect == null) {
      return null;
    }

    final listContext = controller.position.context.notificationContext;
    if (listContext == null || !listContext.mounted) {
      return null;
    }
    final listRect = _globalRectForContext(listContext);
    if (listRect == null) {
      return null;
    }

    final position = controller.position;
    final scaleLeadingOverflow =
        focusedScale <= 1 ? 0.0 : targetRect.width * (focusedScale - 1) / 2;
    final deltaToLeadingEdge = targetRect.left -
        listRect.left -
        _detailHorizontalListSafePadding -
        scaleLeadingOverflow;
    return (position.pixels + deltaToLeadingEdge)
        .clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        )
        .toDouble();
  }

  /// 使用真实组件上下文微调横向列表，让目标项稳定落在可视窗口内。
  void _ensureHorizontalTargetVisible(GlobalKey targetKey) {
    final targetContext = targetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      return;
    }
    TvFocusScroll.ensureVisible(
      targetContext,
      horizontalTriggerFraction: _tvDetailOptionScrollTriggerFraction,
    );
  }

  /// 构建详情页全屏宽度横向列表视口。
  ///
  /// 仅横向列表使用这个容器：标题和播放器仍沿用页面 36px 内容边距，
  /// 列表本身则向左右各扩出 36px，使滚动内容可以直接贴到屏幕边缘。
  Widget _buildFlushHorizontalViewport({
    required double height,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return SizedBox(
            height: height,
            child: child,
          );
        }

        final width =
            constraints.maxWidth + (_detailHorizontalListOverflow * 2);
        return SizedBox(
          height: height,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        );
      },
    );
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
    for (final source in _cachedDisplaySources) {
      final node = _visibleSourceFocusNodeFor(source);
      if (node != null) {
        return node;
      }
    }
    return null;
  }

  /// 按当前焦点的水平位置获取最近的可见播放源。
  FocusNode? _nearestVisibleSourceFocusNodeFromCurrentFocus() {
    final anchorRect = _currentFocusRect();
    if (anchorRect == null) {
      return _firstVisibleSourceFocusNode();
    }
    FocusNode? nearestNode;
    var nearestDistance = double.infinity;
    for (final source in _cachedDisplaySources) {
      final node = _visibleSourceFocusNodeFor(source);
      if (node == null) {
        continue;
      }
      final rect = _globalRectForKey(_sourceTargetKeyFor(source));
      if (rect == null) {
        continue;
      }
      final distance = (rect.center.dx - anchorRect.center.dx).abs();
      if (distance < nearestDistance) {
        nearestNode = node;
        nearestDistance = distance;
      }
    }
    return nearestNode ?? _firstVisibleSourceFocusNode();
  }

  /// 获取当前线路或最近停留线路对应的可见焦点节点。
  FocusNode? _preferredVisibleSourceFocusNode() {
    final rememberedFocusKey = _lastFocusedSourceKey;
    if (rememberedFocusKey != null) {
      for (final source in _cachedSourcesByEpisodeCountDesc) {
        if (_sourceFocusKey(source) != rememberedFocusKey) {
          continue;
        }
        final rememberedNode = _visibleSourceFocusNodeFor(source);
        if (rememberedNode != null) {
          return rememberedNode;
        }
        break;
      }
    }

    final detail = _currentDetail;
    if (detail != null) {
      final selectedNode = _visibleSourceFocusNodeFor(detail);
      if (selectedNode != null) {
        return selectedNode;
      }
    }
    return _firstVisibleSourceFocusNode();
  }

  /// 按当前焦点的水平位置获取当前分组里最近的可见选集。
  FocusNode? _nearestVisibleEpisodeFocusNodeFromCurrentFocus() {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return null;
    }
    final groupCount = _episodeGroupCount(detail.episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      groupIndex,
    );
    return _nearestVisibleIndexedNode(
      targetKeys: _episodeTargetKeys,
      focusNodes: _episodeFocusNodes,
      indexes: visibleIndexes,
      anchorRect: _currentFocusRect(),
    );
  }

  /// 聚焦指定分组里距离当前焦点最近的选集。
  bool _focusNearestVisibleEpisodeOptionInGroup(int groupIndex) {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return false;
    }
    final visibleIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      groupIndex,
    );
    final nearestIndex = _nearestVisibleIndex(
      targetKeys: _episodeTargetKeys,
      focusNodes: _episodeFocusNodes,
      indexes: visibleIndexes,
      anchorRect: _currentFocusRect(),
    );
    if (nearestIndex == null) {
      return false;
    }
    return _focusEpisodeOptionInGroup(groupIndex, nearestIndex);
  }

  /// 获取当前分组里最近停留的选集焦点节点。
  FocusNode? _preferredVisibleEpisodeFocusNode() {
    final detail = _currentDetail;
    if (detail == null || detail.episodes.isEmpty) {
      return null;
    }

    final groupCount = _episodeGroupCount(detail.episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes = _episodeIndexesForGroup(
      detail.episodes.length,
      groupIndex,
    );

    final rememberedIndex = _lastFocusedEpisodeIndex;
    if (rememberedIndex != null && visibleIndexes.contains(rememberedIndex)) {
      final rememberedNode = _visibleNodeForIndex(
        _episodeTargetKeys,
        _episodeFocusNodes,
        rememberedIndex,
      );
      if (rememberedNode != null) {
        return rememberedNode;
      }
    }

    if (visibleIndexes.contains(_episodeIndex)) {
      final selectedNode = _visibleNodeForIndex(
        _episodeTargetKeys,
        _episodeFocusNodes,
        _episodeIndex,
      );
      if (selectedNode != null) {
        return selectedNode;
      }
    }

    for (final index in visibleIndexes) {
      final node = _visibleNodeForIndex(
        _episodeTargetKeys,
        _episodeFocusNodes,
        index,
      );
      if (node != null) {
        return node;
      }
    }
    return null;
  }

  /// 按当前焦点的水平位置获取最近的可见选集分组。
  FocusNode? _nearestVisibleEpisodeGroupFocusNodeFromCurrentFocus() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount <= 1) {
      return null;
    }
    return _nearestVisibleIndexedNode(
      targetKeys: _episodeGroupTargetKeys,
      focusNodes: _episodeGroupFocusNodes,
      indexes: List<int>.generate(groupCount, (index) => index),
      anchorRect: _currentFocusRect(),
    );
  }

  /// 获取最近停留或当前选中的分组焦点节点。
  FocusNode? _preferredVisibleEpisodeGroupFocusNode() {
    final detail = _currentDetail;
    final groupCount = _episodeGroupCount(detail?.episodes.length ?? 0);
    if (groupCount <= 1) {
      return null;
    }

    final rememberedIndex = _lastFocusedEpisodeGroupIndex;
    if (rememberedIndex != null &&
        rememberedIndex >= 0 &&
        rememberedIndex < groupCount) {
      final rememberedNode = _visibleNodeForIndex(
        _episodeGroupTargetKeys,
        _episodeGroupFocusNodes,
        rememberedIndex,
      );
      if (rememberedNode != null) {
        return rememberedNode;
      }
    }

    final selectedGroupIndex = _episodeGroupIndex.clamp(0, groupCount - 1);
    final selectedNode = _visibleNodeForIndex(
      _episodeGroupTargetKeys,
      _episodeGroupFocusNodes,
      selectedGroupIndex.toInt(),
    );
    if (selectedNode != null) {
      return selectedNode;
    }
    return _firstVisibleIndexedNode(
      _episodeGroupTargetKeys,
      _episodeGroupFocusNodes,
    );
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

  /// 获取最近停留的推荐焦点节点。
  FocusNode? _preferredVisibleRecommendNode() {
    final rememberedFocusKey = _lastFocusedRecommendKey;
    if (rememberedFocusKey != null) {
      final targetKey = _recommendTargetKeys[rememberedFocusKey];
      final node = _recommendFocusNodes[rememberedFocusKey];
      if (targetKey?.currentContext != null &&
          node != null &&
          node.canRequestFocus) {
        return node;
      }
    }
    return _firstVisibleRecommendNode();
  }

  /// 获取指定 Key 对应控件的全局矩形。
  Rect? _globalRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    return _globalRectForContext(context);
  }

  /// 获取当前主焦点控件的全局矩形。
  Rect? _currentFocusRect() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) {
      return null;
    }
    return _globalRectForContext(context);
  }

  /// 获取与指定位置水平中心最近的可见索引节点。
  FocusNode? _nearestVisibleIndexedNode({
    required Map<int, GlobalKey> targetKeys,
    required Map<int, FocusNode> focusNodes,
    required Iterable<int> indexes,
    required Rect? anchorRect,
  }) {
    final index = _nearestVisibleIndex(
      targetKeys: targetKeys,
      focusNodes: focusNodes,
      indexes: indexes,
      anchorRect: anchorRect,
    );
    return index == null ? null : focusNodes[index];
  }

  /// 获取与指定位置水平中心最近的可见索引。
  int? _nearestVisibleIndex({
    required Map<int, GlobalKey> targetKeys,
    required Map<int, FocusNode> focusNodes,
    required Iterable<int> indexes,
    required Rect? anchorRect,
  }) {
    if (anchorRect == null) {
      for (final index in indexes) {
        if (_visibleNodeForIndex(targetKeys, focusNodes, index) != null) {
          return index;
        }
      }
      return null;
    }

    int? nearestIndex;
    var nearestDistance = double.infinity;
    for (final index in indexes) {
      if (_visibleNodeForIndex(targetKeys, focusNodes, index) == null) {
        continue;
      }
      final targetKey = targetKeys[index];
      if (targetKey == null) {
        continue;
      }
      final rect = _globalRectForKey(targetKey);
      if (rect == null) {
        continue;
      }
      final distance = (rect.center.dx - anchorRect.center.dx).abs();
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    return nearestIndex;
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
    _consumeFullscreenOverlayBack = true;
    setState(() => _fullscreenOverlayVisible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.microtask(() {
        if (mounted) {
          _consumeFullscreenOverlayBack = false;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToTopAndFocusPlayer();
      }
    });
  }

  /// 处理详情页返回键，避免全屏关闭事件继续弹出详情页路由。
  Future<bool> _handleDetailBackPressed() async {
    if (_isExitingDetail) {
      return true;
    }
    if (_fullscreenOverlayVisible) {
      _closeFullscreenOverlay();
      return true;
    }
    if (_consumeFullscreenOverlayBack) {
      _consumeFullscreenOverlayBack = false;
      return true;
    }
    _isExitingDetail = true;
    _loadSerial++;
    final controller = _playerController;
    if (controller != null) {
      unawaited(controller.pause());
    }
    // 真正离开详情页前强制保存当前进度，保持与普通端返回语义一致。
    await _saveProgress(force: true, scene: '详情页返回');
    if (!mounted) {
      return true;
    }
    Navigator.of(context).pop(true);
    return true;
  }

  /// 处理详情页全局返回按键，兜底平台视图等会抢走焦点的场景。
  bool _handleGlobalBackKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (!TvBackIntent.isBackKey(event.logicalKey)) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) {
      return false;
    }
    // 当前焦点仍在详情页 Focus 树里时，交给已有 TvBackHandler 处理，避免重复返回。
    if (_isPrimaryFocusInsideDetailTree()) {
      return false;
    }
    unawaited(_dispatchDetailBackFromGlobal());
    return true;
  }

  /// 判断当前主焦点是否仍在详情页内部。
  bool _isPrimaryFocusInsideDetailTree() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    if (identical(focusContext, context)) {
      return true;
    }
    var isInside = false;
    focusContext.visitAncestorElements((ancestor) {
      if (identical(ancestor, context)) {
        isInside = true;
        return false;
      }
      return true;
    });
    return isInside;
  }

  /// 从全局返回兜底链路分发详情页返回动作。
  Future<void> _dispatchDetailBackFromGlobal() async {
    await _handleDetailBackPressed();
  }

  /// 打开 TV 搜索页。
  void _openSearch() {
    _isExitingDetail = true;
    _loadSerial++;
    unawaited(_playerController?.pause());
    TvRoute.pushReplacement<void, void>(context, const TvSearchScreen());
  }

  /// 将详情页操作区焦点送回顶部搜索入口。
  void _focusSearchAction() {
    _searchFocusNode.requestFocus();
  }

  /// 将顶部搜索入口焦点送到详情页全屏按钮。
  void _focusFullscreenAction() {
    _fullscreenFocusNode.requestFocus();
  }

  /// 将顶部搜索入口焦点送回左侧预览播放器。
  ///
  /// 搜索按钮位于固定顶栏，焦点左移后需要同步滚回顶部，保证播放器完整可见。
  void _focusPlayerFromSearchAction() {
    _playerFocusNode.requestFocus();
    _scrollToTop();
  }

  /// 回到页面顶部。
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// 回到页面顶部并把焦点送回预览播放器。
  void _scrollToTopAndFocusPlayer() {
    _scrollToTop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canUseDetailRoute) {
        _playerFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageBackgroundColor = TvTheme.backgroundOf(context).color;
    return TvBackHandler(
      onBackPressed: _handleDetailBackPressed,
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _detailHorizontalListSafePadding,
                            20,
                            _detailHorizontalListSafePadding,
                            15,
                          ),
                          child: _buildPageGuide(),
                        ),
                        Expanded(
                          child: _isInitialDetailLoading &&
                                  _currentDetail == null
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: TvTheme.of(context).accent,
                                  ),
                                )
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 56),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildHeroArea(),
                                      const SizedBox(height: 30),
                                      _buildSourcesSection(),
                                      const SizedBox(height: 28),
                                      _buildEpisodesSection(),
                                      if (_hasVisibleRecommends) ...[
                                        const SizedBox(height: 34),
                                        _buildRecommendsSection(),
                                        const SizedBox(height: 38),
                                        _buildBottomActions(),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          onArrowLeft: _focusPlayerFromSearchAction,
          onArrowRight: _keepCurrentFocusAtBoundary,
          onArrowUp: _keepCurrentFocusAtBoundary,
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
    final fullscreenInitialPosition = _resolveFullscreenInitialPosition();
    return Positioned.fill(
      child: TvFullscreenPlayerScreen(
        videoInfo: widget.videoInfo,
        currentDetail: _currentDetail,
        sources: _sources,
        stype: widget.stype,
        initialEpisodeIndex: _episodeIndex,
        initialPlaybackPosition: fullscreenInitialPosition,
        initialPlaybackWasPlaying: _playerController?.isPlaying ?? true,
        initialPlaybackStarted: _hasPreviewPlaybackStarted,
        playbackController: widget.fullscreenPlayerBuilder == null
            ? _TvDetailFullscreenPlaybackController(
                () => _playerController,
                fallbackPosition: fullscreenInitialPosition,
              )
            : null,
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
        loadPlayerKernel: widget.loadPlayerKernel,
        reuseExistingPlayer: widget.fullscreenPlayerBuilder == null,
      ),
    );
  }

  /// 解析进入全屏时使用的播放位置。
  ///
  /// 继续观看首播刚下发 `startAt` 时，小播放器进度可能还没从 0 跳到记录时间；
  /// 此时全屏需要沿用入口续播时间，等播放器真实进度大于 0 后再由控制器位置接管。
  Duration? _resolveFullscreenInitialPosition() {
    final currentPosition = _playerController?.currentPosition;
    if (currentPosition != null && currentPosition > Duration.zero) {
      return currentPosition;
    }
    return _initialResumePlaybackPositionSnapshot;
  }

  /// 构建播放器和简介区域。
  Widget _buildHeroArea() {
    final detail = _currentDetail;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: _detailHorizontalListSafePadding),
      child: LayoutBuilder(
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
      ),
    );
  }

  /// 构建播放器区域。
  Widget _buildPlayerBox(SearchResult? detail) {
    final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
    return TvEdgeShake(
      key: edgeShakeKey,
      child: KeyedSubtree(
        key: _playerTargetKey,
        child: TvFocusable(
          focusNode: _playerFocusNode,
          autofocus: true,
          autoScrollOnFocus: false,
          onArrowLeft: () {
            edgeShakeKey.currentState?.shake(AxisDirection.left);
            _keepCurrentFocusAtBoundary();
          },
          onArrowDown: _focusPreferredSource,
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _fullscreenOverlayVisible
                            ? const ColoredBox(color: Colors.black)
                            : _buildSharedPlayer(detail),
                      ),
                      if (_shouldShowPreviewLoadingOverlay)
                        _buildPreviewLoadingOverlay(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 详情页播放器是否需要展示外层 loading。
  bool get _shouldShowPreviewLoadingOverlay {
    if (_fullscreenOverlayVisible || _currentDetail == null) {
      return false;
    }
    final controller = _playerController;
    if (controller == null) {
      // 播放器子树已经进入黑底初始化，但控制器可能稍后才回调。
      // 这段时间外层 TV loading 仍要给用户反馈，避免首帧等待时空黑屏。
      return _previewPlayerLoading;
    }
    if (_previewPlayerLoading &&
        (_hasPendingInitialPlaybackAfterResumeLoad ||
            _hasDispatchedInitialPreviewPlayback ||
            controller.isLoading)) {
      return true;
    }
    return !_previewPlaybackStarted && controller.isLoading;
  }

  /// 构建详情页播放器 loading 转圈和网速提示。
  Widget _buildPreviewLoadingOverlay() {
    final networkSpeedText = _playerController?.networkSpeedText ?? '0KB/s';
    final shadowColor = Colors.black.withValues(alpha: 0.42);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('tv-detail-preview-loading'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Transform.translate(
                          offset: const Offset(0, 2),
                          child: CircularProgressIndicator(
                            color: shadowColor,
                            strokeWidth: 3,
                            value: _isFlutterTestEnvironment ? 0.72 : null,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          color: TvTheme.of(context).accent,
                          strokeWidth: 3,
                          value: _isFlutterTestEnvironment ? 0.72 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  networkSpeedText,
                  style: FontUtils.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ).copyWith(
                    shadows: <Shadow>[
                      Shadow(
                        color: shadowColor,
                        blurRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 当前预览视频是否已经真正起播。
  bool get _hasPreviewPlaybackStarted {
    return _previewPlaybackStarted;
  }

  /// 构建预览和全屏共用的播放器。
  Widget _buildSharedPlayer(
    SearchResult? detail, {
    void Function(VideoPlayerWidgetController controller)?
        onControllerCreatedOverride,
  }) {
    widget.testHooks?.onAdFilterResolved?.call(_adFilterEnabled);

    void controllerCreated(VideoPlayerWidgetController controller) {
      _attachPlayerController(controller);
      if (onControllerCreatedOverride != null) {
        onControllerCreatedOverride(controller);
      }
    }

    return KeyedSubtree(
      key: _sharedPlayerKey,
      child: FocusScope(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        descendantsAreTraversable: false,
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
              showLoadingIndicator: false,
              backgroundColor: Colors.transparent,
              adFilterEnabled: _adFilterEnabled,
              tvPlayerKernel: _tvPlayerKernel,
              onControllerCreated: controllerCreated,
              onFullscreenChanged: (_) {},
              onReady: _handlePreviewReadySignal,
              onPlay: _handlePreviewPlaySignal,
              onPause: _schedulePreviewChromeRefresh,
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
              onVideoCompleted: _handlePreviewVideoCompleted,
            ),
      ),
    );
  }

  /// 处理底层播放器 ready 信号。
  ///
  /// `ready` 只说明元数据或播放器壳已就绪，不代表首帧已经真正出画；
  /// 这里仅尝试按当前更严格条件结束 loading，并刷新外层控制层。
  void _handlePreviewReadySignal() {
    _schedulePreviewChromeRefresh();
  }

  /// 处理底层播放器 play 信号。
  ///
  /// `playing=true` 可能早于真实首帧出现，因此这里只把它当作辅助探针，
  /// 真正结束 loading 仍要等进度侧确认“画面已经开始恢复可见”。
  void _handlePreviewPlaySignal() {
    _schedulePreviewChromeRefresh();
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
            Builder(
              builder: (context) {
                final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                return TvEdgeShake(
                  key: edgeShakeKey,
                  child: KeyedSubtree(
                    key: _favoriteTargetKey,
                    child: _TvDetailActionButton(
                      label: _isFavorite ? '已收藏' : '收藏',
                      icon: LucideIcons.heart,
                      focusNode: _favoriteFocusNode,
                      focusMemoryGroupKey: 'tv-detail-actions',
                      iconColor:
                          _isFavorite ? const Color(0xFFE50914) : Colors.white,
                      onArrowRight: () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right),
                      onArrowUp: _focusSearchAction,
                      onArrowDown:
                          _sources.isEmpty ? null : _focusSelectedSource,
                      onPressed: _toggleFavorite,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建换源区。
  Widget _buildSourcesSection() {
    final sources = _cachedDisplaySources;
    return _TvDetailSection(
      title: '切换线路',
      subtitle: '遇播放卡顿，音画不同步或无法播放时，请切换播放线路',
      contentHorizontalInset: _detailSectionLeadingInset,
      child: sources.isEmpty
          ? (_shouldShowEmptyPlaybackHint
              ? _buildEmptyPlaybackHint()
              : _buildEmptyText('暂无可用源'))
          : _buildFlushHorizontalViewport(
              height: _detailChoiceChipMinHeight,
              child: ListView.separated(
                key: const ValueKey('tv-detail-source-list'),
                controller: _sourceListScrollController,
                padding: _detailHorizontalListPadding,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: sources.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final selected = source.source == _currentDetail?.source &&
                      source.id == _currentDetail?.id;
                  final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
                  final isFirstItem = index == 0;
                  final isLastItem = index == sources.length - 1;
                  return KeyedSubtree(
                    key: _sourceTargetKeyFor(source),
                    child: TvEdgeShake(
                      key: edgeShakeKey,
                      child: Builder(
                        builder: (chipContext) => _TvChoiceChip(
                          label: source.sourceName,
                          trailingText: '（${source.episodes.length}）',
                          selected: selected,
                          focusNode: _sourceFocusNodeFor(source),
                          focusMemoryGroupKey: _sourceFocusGroupKey,
                          onArrowLeft: isFirstItem
                              ? () => _handleSourceBoundaryArrow(
                                    source,
                                    edgeShakeKey,
                                    AxisDirection.left,
                                  )
                              : null,
                          onArrowRight: isLastItem
                              ? () => _handleSourceBoundaryArrow(
                                    source,
                                    edgeShakeKey,
                                    AxisDirection.right,
                                  )
                              : null,
                          onArrowUp: () =>
                              _focusNearestHeroControlFrom(chipContext),
                          onArrowDown: _focusPreferredEpisodeInCurrentGroup,
                          onFocus: () {
                            // 任意线路获焦时都保留 36px 左安全区：首项与标题对齐，
                            // 滚到最左侧获焦时焦点描边也不会被屏幕裁掉。
                            _rememberFocusedSource(source);
                            _scheduleHorizontalTargetRevealIfNeeded(
                              groupKey: _sourceFocusGroupKey,
                              controller: _sourceListScrollController,
                              targetKey: _sourceTargetKeyFor(source),
                              focusedScale: TvVideoCard.focusedScale,
                            );
                          },
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
    final episodeListHeight = _resolveEpisodeListHeight(
      detail,
      visibleIndexes,
      episodes,
    );
    return _TvDetailSection(
      title: '选集',
      contentHorizontalInset: _detailSectionLeadingInset,
      child: episodes.isEmpty
          ? _buildEmptyText('暂无选集')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFlushHorizontalViewport(
                  height: episodeListHeight,
                  child: ListView.separated(
                    key: const ValueKey('tv-detail-episode-list'),
                    controller: _episodeListScrollController,
                    padding: _detailHorizontalListPadding,
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
                            focusMemoryGroupKey: _episodeFocusGroupKey,
                            allowMultiline: true,
                            onArrowLeft: isFirstItem
                                ? () =>
                                    _focusPreviousEpisodeGroupLastItemOrShake(
                                      groupIndex,
                                      edgeShakeKey,
                                    )
                                : () => _focusEpisodeNeighborInCurrentGroup(
                                      groupIndex,
                                      visibleIndexes[itemIndex - 1],
                                    ),
                            onArrowRight: isLastItem
                                ? () => _focusNextEpisodeGroupFirstItemOrShake(
                                      groupIndex,
                                      edgeShakeKey,
                                    )
                                : () => _focusEpisodeNeighborInCurrentGroup(
                                      groupIndex,
                                      visibleIndexes[itemIndex + 1],
                                    ),
                            onArrowUp: _focusSelectedSourceFromBelow,
                            onArrowDown: _focusPreferredEpisodeDownTarget,
                            onFocus: () {
                              // 任意选集获焦时都保留 36px 左安全区，滚到最左侧也不裁焦点框。
                              // 复用按真实渲染位置定位的方案，避免选集宽度估算误差把焦点
                              // 推过安全区，和线路/分组/推荐保持一致的贴边手感。
                              _rememberFocusedEpisode(index);
                              _scheduleHorizontalTargetRevealIfNeeded(
                                groupKey: _episodeFocusGroupKey,
                                controller: _episodeListScrollController,
                                targetKey: _episodeTargetKeyFor(index),
                                focusedScale: TvVideoCard.focusedScale,
                              );
                            },
                            onPressed: () => _switchEpisode(index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (groupCount > 1) ...[
                  const SizedBox(height: 12),
                  _buildFlushHorizontalViewport(
                    height: 40,
                    child: ListView.separated(
                      key: const ValueKey('tv-detail-episode-group-list'),
                      controller: _episodeGroupListScrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: _detailHorizontalListSafePadding,
                      ),
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
                              focusMemoryGroupKey: _episodeGroupFocusGroupKey,
                              onArrowLeft: isFirstItem
                                  ? () => edgeShakeKey.currentState
                                      ?.shake(AxisDirection.left)
                                  : null,
                              onArrowRight: isLastItem
                                  ? () => edgeShakeKey.currentState
                                      ?.shake(AxisDirection.right)
                                  : null,
                              onArrowUp: () => _focusEpisodeOptionForGroup(
                                groupIndex,
                                useNearestVisible: true,
                              ),
                              onArrowDown: _focusPreferredRecommend,
                              onFocus: () {
                                // 分组获焦只记录停留位置，真正切换必须等确认键。
                                _rememberFocusedEpisodeGroup(index);
                                _scheduleHorizontalTargetRevealIfNeeded(
                                  groupKey: _episodeGroupFocusGroupKey,
                                  controller: _episodeGroupListScrollController,
                                  targetKey: _episodeGroupTargetKeyFor(index),
                                  focusedScale: TvVideoCard.focusedScale,
                                );
                              },
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
      contentHorizontalInset: _detailSectionLeadingInset,
      child: _buildFlushHorizontalViewport(
        height: TvVideoCard.height + 28,
        child: ListView.separated(
          key: const ValueKey('tv-detail-recommend-list'),
          controller: _recommendListScrollController,
          padding: _detailHorizontalListPadding,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: _recommends.length,
          separatorBuilder: (_, __) => const SizedBox(width: 18),
          itemBuilder: (context, index) {
            final videoInfo = _recommends[index];
            final edgeShakeKey = GlobalKey<TvEdgeShakeState>();
            final isFirstItem = index == 0;
            final isLastItem = index == _recommends.length - 1;
            return TvEdgeShake(
              key: edgeShakeKey,
              child: KeyedSubtree(
                key: _recommendTargetKeyFor(videoInfo),
                child: TvVideoCard(
                  videoInfo: videoInfo,
                  focusNode: _recommendFocusNodeFor(videoInfo),
                  focusMemoryGroupKey: _recommendFocusGroupKey,
                  onArrowLeft: isFirstItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right)
                      : null,
                  onArrowUp: _focusRecommendationUpTarget,
                  onArrowDown: _focusBottomAction,
                  onFocusChanged: (hasFocus) {
                    if (hasFocus) {
                      // 推荐卡片获焦时，横向保留安全区，纵向直接滚到底部。
                      _rememberFocusedRecommend(videoInfo);
                      _scheduleHorizontalTargetRevealIfNeeded(
                        groupKey: _recommendFocusGroupKey,
                        controller: _recommendListScrollController,
                        targetKey: _recommendTargetKeyFor(videoInfo),
                      );
                      _scheduleDetailPageScrollToBottom();
                    }
                  },
                  onPressed: () {
                    TvRoute.pushReplacement<void, void>(
                      context,
                      TvVideoDetailScreen(
                        videoInfo: videoInfo,
                      ),
                    );
                  },
                ),
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
            onArrowLeft: _keepCurrentFocusAtBoundary,
            onArrowRight: _keepCurrentFocusAtBoundary,
            onArrowDown: _keepCurrentFocusAtBoundary,
            onArrowUp: _focusPreferredRecommend,
            onPressed: _scrollToTopAndFocusPlayer,
          ),
        ],
      ),
    );
  }

  /// 当前是否应展示“搜索完成但无播放信息”的空状态。
  bool get _shouldShowEmptyPlaybackHint {
    return _sources.isEmpty &&
        _initialSourcesLoaded &&
        _moreSourcesLoaded &&
        !_isInitialDetailLoading;
  }

  /// 构建“未找到可播放信息”空状态。
  ///
  /// 仅在详情页补源完整结束后仍无线路时展示，明确告诉用户当前不是还在搜索。
  Widget _buildEmptyPlaybackHint() {
    return Container(
      key: const ValueKey('tv-detail-empty-playback-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16191B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2F32)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 20,
            color: Color(0xFF98A2A8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '搜索已完成，未找到可播放信息',
              style: FontUtils.poppins(
                fontSize: 16,
                color: const Color(0xFF98A2A8),
              ),
            ),
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

/// 详情页共享播放器给全屏壳使用的播放控制适配器。
class _TvDetailFullscreenPlaybackController
    implements
        TvFullscreenPlaybackController,
        TvFullscreenVideoControllerProvider {
  /// 创建详情页共享播放器控制适配器。
  const _TvDetailFullscreenPlaybackController(
    this._controllerGetter, {
    this.fallbackPosition,
  });

  /// 详情页当前播放器控制器获取函数。
  ///
  /// 全屏覆盖层和详情页共用同一个播放器实例，控制器可能在全屏打开后才挂上，
  /// 因此这里必须实时读取最新控制器，不能在创建适配器时拍一次快照。
  final VideoPlayerWidgetController? Function() _controllerGetter;

  /// 控制器尚未回传有效进度时使用的兜底位置。
  final Duration? fallbackPosition;

  /// 当前最新可用的详情页播放器控制器。
  VideoPlayerWidgetController? get _controller => _controllerGetter();

  @override
  VideoPlayerWidgetController? get videoController => _controller;

  @override
  Duration? get currentPosition {
    final position = _controller?.currentPosition;
    if (position != null && position > Duration.zero) {
      return position;
    }
    return fallbackPosition ?? position;
  }

  @override
  Duration? get totalDuration => _controller?.duration;

  @override
  bool get isPlaying => _controller?.isPlaying ?? false;

  @override
  bool get isLoading => _controller?.isLoading ?? false;

  @override
  String get networkSpeedText => _controller?.networkSpeedText ?? '0KB/s';

  @override
  void addNetworkSpeedListener(VoidCallback listener) {
    _controller?.addNetworkSpeedListener(listener);
  }

  @override
  void removeNetworkSpeedListener(VoidCallback listener) {
    _controller?.removeNetworkSpeedListener(listener);
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }
}

/// TV 详情页分区。
class _TvDetailSection extends StatelessWidget {
  /// 创建 TV 详情页分区。
  const _TvDetailSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.contentHorizontalInset = 0,
  });

  /// 分区标题。
  final String title;

  /// 分区副标题。
  final String? subtitle;

  /// 分区内容的统一横向基线留白。
  ///
  /// 标题、副标题和下方横向列表需要共用同一条左基线时，
  /// 通过这个值把标题区同步推入内容安全留白内侧。
  final double contentHorizontalInset;

  /// 分区内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: contentHorizontalInset),
          child: Text(
            title,
            style: FontUtils.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: contentHorizontalInset),
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF98A2A8),
              ),
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
    this.onArrowLeft,
    this.onArrowRight,
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

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

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
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: TvThemeColors.cardSurface,
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
    this.onFocus,
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

  /// 焦点进入回调。
  final VoidCallback? onFocus;

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
      autoScrollOnFocus: false,
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
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      builder: (context, hasFocus) {
        final highlight = hasFocus || selected;
        return AnimatedScale(
          scale: hasFocus ? TvVideoCard.focusedScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: 17,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? palette.accent : const Color(0xFFD9E2E0),
              ).copyWith(
                decoration:
                    hasFocus ? TextDecoration.underline : TextDecoration.none,
                decorationColor: palette.accent,
                decorationThickness: 2,
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
    this.trailingText,
    this.allowMultiline = false,
    this.onFocus,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.focusMemoryGroupKey,
  });

  /// 文案。
  final String label;

  /// 文案右侧补充信息。
  final String? trailingText;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 是否允许多行展示文案。
  final bool allowMultiline;

  /// 焦点进入回调。
  final VoidCallback? onFocus;

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
      autoScrollOnFocus: false,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      horizontalFocusScrollTriggerFraction:
          _tvDetailOptionScrollTriggerFraction,
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      builder: (context, hasFocus) {
        return AnimatedScale(
          scale: hasFocus ? TvVideoCard.focusedScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(
              minWidth: 86,
              maxWidth: _TvVideoDetailScreenState._detailChoiceChipMaxWidth,
              minHeight: _TvVideoDetailScreenState._detailChoiceChipMinHeight,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal:
                  _TvVideoDetailScreenState._detailChoiceChipHorizontalPadding,
              vertical:
                  _TvVideoDetailScreenState._detailChoiceChipVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.accent : TvThemeColors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasFocus
                    ? Colors.white
                    : selected
                        ? palette.accent
                        : TvThemeColors.cardSurfaceBorder,
                width: hasFocus ? 2 : 1,
              ),
            ),
            child: _buildLabelText(palette),
          ),
        );
      },
    );
  }

  /// 构建主文案和右侧补充文案。
  Widget _buildLabelText(TvThemePalette palette) {
    final style = FontUtils.poppins(
      fontSize: 15,
      color: selected ? palette.selectedText : const Color(0xFFD9E2E0),
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final extraText = trailingText;
    if (extraText == null || extraText.isEmpty) {
      return Text(
        label,
        textAlign: TextAlign.center,
        maxLines: allowMultiline ? null : 1,
        softWrap: allowMultiline,
        overflow: allowMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Text(extraText, style: style),
      ],
    );
  }
}
