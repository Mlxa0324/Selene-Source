import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/models/favorite_item.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/bangumi_service.dart';
import 'package:selene/services/douban_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/tv_app/screens/tv_live_screen.dart';
import 'package:selene/tv_app/screens/tv_search_screen.dart';
import 'package:selene/tv_app/screens/tv_settings_screen.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_category_filter_panel.dart';
import 'package:selene/tv_app/widgets/tv_home_section.dart';
import 'package:selene/tv_app/widgets/tv_top_nav.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

/// TV 首页数据加载函数。
///
/// [context] 用于复用现有 service 中的请求上下文。
typedef TvHomeDataLoader = Future<TvHomeData> Function(BuildContext context);

/// TV 分类筛选数据加载函数。
///
/// [kind] 表示当前大类，[filters] 保存已确认的筛选项。
typedef TvCategoryDataLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
  TvCategoryFilterKind kind,
  Map<String, TvCategoryFilterOption> filters,
  int page,
);

/// TV 详情页面构建函数。
///
/// [videoInfo] 是当前选中的视频，[stype] 用于保留电影等类型上下文。
typedef TvDetailPageBuilder = Widget Function(
  VideoInfo videoInfo,
  String? stype,
);

/// TV 搜索页面构建函数。
///
/// 用于测试替换真实搜索页，避免触发搜索页自身的网络和缓存逻辑。
typedef TvSearchPageBuilder = Widget Function();

/// TV 首页聚合数据。
///
/// 只承载页面展示所需列表，避免 TV 页面直接依赖普通端组件状态。
class TvHomeData {
  /// 创建 TV 首页聚合数据。
  const TvHomeData({
    required this.continueWatching,
    required this.hotMovies,
    required this.hotTvShows,
    required this.bangumiCalendar,
    required this.hotShows,
    required this.history,
    required this.favorites,
  });

  /// 继续观看列表。
  final List<VideoInfo> continueWatching;

  /// 热门电影列表。
  final List<VideoInfo> hotMovies;

  /// 热门剧集列表。
  final List<VideoInfo> hotTvShows;

  /// 新番放送列表。
  final List<VideoInfo> bangumiCalendar;

  /// 热门综艺列表。
  final List<VideoInfo> hotShows;

  /// 播放历史列表。
  final List<VideoInfo> history;

  /// 收藏夹列表。
  final List<VideoInfo> favorites;

  /// 创建空数据，用于加载中、失败和测试场景。
  factory TvHomeData.empty() {
    return const TvHomeData(
      continueWatching: [],
      hotMovies: [],
      hotTvShows: [],
      bangumiCalendar: [],
      hotShows: [],
      history: [],
      favorites: [],
    );
  }
}

/// TV 首页页面。
///
/// 内容结构对齐普通首页，布局和焦点交互为 TV 端独立实现。
class TvHomeScreen extends StatefulWidget {
  /// 创建 TV 首页页面。
  ///
  /// [loadHomeData] 可在测试中注入数据加载逻辑。
  /// [buildDetailPage] 可在测试中替换详情页，生产环境默认打开 TV 详情页。
  /// [buildSearchPage] 可在测试中替换搜索页，生产环境默认打开普通搜索页。
  const TvHomeScreen({
    super.key,
    this.loadHomeData,
    this.loadCategoryData,
    this.buildDetailPage,
    this.buildSearchPage,
  });

  /// 首页数据加载函数。
  final TvHomeDataLoader? loadHomeData;

  /// 分类筛选数据加载函数。
  final TvCategoryDataLoader? loadCategoryData;

  /// 详情页面构建函数。
  final TvDetailPageBuilder? buildDetailPage;

  /// 搜索页面构建函数。
  final TvSearchPageBuilder? buildSearchPage;

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();

  /// 默认首页数据加载逻辑。
  static Future<TvHomeData> defaultLoadHomeData(BuildContext context) async {
    final cacheService = PageCacheService();
    final playRecordsFuture = _loadPlayRecords(context, cacheService);
    final favoritesFuture = _loadFavorites(context, cacheService);
    final hotMoviesFuture = _loadHotMovies(context, cacheService);
    final hotTvShowsFuture = _loadHotTvShows(context, cacheService);
    final bangumiCalendarFuture = _loadBangumiCalendar(context);
    final hotShowsFuture = _loadHotShows(context, cacheService);

    final playRecords = await playRecordsFuture;
    final favorites = await favoritesFuture;
    final hotMovies = await hotMoviesFuture;
    final hotTvShows = await hotTvShowsFuture;
    final bangumiCalendar = await bangumiCalendarFuture;
    final hotShows = await hotShowsFuture;

    return TvHomeData(
      continueWatching: playRecords
          .where((video) => video.source != 'local')
          .take(20)
          .toList(),
      hotMovies: hotMovies.take(20).toList(),
      hotTvShows: hotTvShows.take(20).toList(),
      bangumiCalendar: bangumiCalendar.take(20).toList(),
      hotShows: hotShows.take(20).toList(),
      history: playRecords.take(60).toList(),
      favorites: favorites.take(60).toList(),
    );
  }

  /// 默认分类筛选查询逻辑。
  ///
  /// 复用普通端豆瓣推荐接口，TV 端只负责把筛选项转换为查询参数。
  static Future<List<VideoInfo>> defaultLoadCategoryData(
    BuildContext context,
    TvCategoryFilterKind kind,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    final params = _buildCategoryQueryParams(kind, filters, page: page);
    final response = await DoubanService.fetchDoubanRecommends(
      context,
      params,
    );
    return (response.data ?? []).map((movie) => movie.toVideoInfo()).toList();
  }

  /// 根据 TV 分类筛选项构建豆瓣推荐查询参数。
  static DoubanRecommendsParams _buildCategoryQueryParams(
      TvCategoryFilterKind kind, Map<String, TvCategoryFilterOption> filters,
      {required int page}) {
    final type = _filterLabel(filters, '类型');
    final region = _filterLabel(filters, '地区');
    final year = _filterLabel(filters, '年份');
    final sort = _filterValue(filters, '排序', fallback: 'T');

    switch (kind) {
      case TvCategoryFilterKind.movie:
        return DoubanRecommendsParams(
          kind: 'movie',
          category: type,
          region: region,
          year: year,
          sort: sort,
          pageLimit: 30,
          page: page,
        );
      case TvCategoryFilterKind.series:
        return DoubanRecommendsParams(
          kind: 'tv',
          category: type,
          format: '电视剧',
          region: region,
          year: year,
          sort: sort,
          pageLimit: 30,
          page: page,
        );
      case TvCategoryFilterKind.anime:
        return DoubanRecommendsParams(
          kind: 'tv',
          category: '动画',
          label: type,
          region: region,
          year: year,
          sort: sort,
          pageLimit: 30,
          page: page,
        );
      case TvCategoryFilterKind.variety:
        return DoubanRecommendsParams(
          kind: 'tv',
          category: type,
          format: '综艺',
          region: region,
          year: year,
          sort: sort,
          pageLimit: 30,
          page: page,
        );
    }
  }

  /// 获取筛选项标签，全部场景转换为接口默认值。
  static String _filterLabel(
    Map<String, TvCategoryFilterOption> filters,
    String rowTitle,
  ) {
    final option = filters[rowTitle];
    if (option == null || option.value == 'all') {
      return 'all';
    }
    return option.label;
  }

  /// 获取筛选项值，全部场景使用指定默认值。
  static String _filterValue(
    Map<String, TvCategoryFilterOption> filters,
    String rowTitle, {
    required String fallback,
  }) {
    final option = filters[rowTitle];
    if (option == null || option.value == 'all') {
      return fallback;
    }
    return option.value;
  }

  /// 加载播放记录。
  static Future<List<VideoInfo>> _loadPlayRecords(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final result = await cacheService.getPlayRecords(context);
      return (result.data ?? <PlayRecord>[])
          .map(VideoInfo.fromPlayRecord)
          .toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载收藏夹。
  static Future<List<VideoInfo>> _loadFavorites(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final result = await cacheService.getFavorites(context);
      return (result.data ?? <FavoriteItem>[])
          .map(_favoriteToVideoInfo)
          .toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载热门电影。
  static Future<List<VideoInfo>> _loadHotMovies(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final movies = await cacheService.getHotMovies(context);
      return (movies ?? []).map((movie) => movie.toVideoInfo()).toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载热门剧集。
  static Future<List<VideoInfo>> _loadHotTvShows(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final shows = await cacheService.getHotTvShows(context);
      return (shows ?? []).map((show) => show.toVideoInfo()).toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载新番放送。
  static Future<List<VideoInfo>> _loadBangumiCalendar(
    BuildContext context,
  ) async {
    try {
      final response = await BangumiService.getTodayCalendar(context);
      return (response.data ?? []).map((item) => item.toVideoInfo()).toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 加载热门综艺。
  static Future<List<VideoInfo>> _loadHotShows(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final shows = await cacheService.getHotShows(context);
      return (shows ?? []).map((show) => show.toVideoInfo()).toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 将收藏数据转换为视频卡片数据。
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

class _TvHomeScreenState extends State<TvHomeScreen>
    with SingleTickerProviderStateMixin {
  /// TV 顶部固定区域半透遮罩色。
  static const Color _topScrimColor = Color(0xD00B0D0E);

  /// 顶部菜单收起动画时长。
  static const Duration _topNavAnimationDuration = Duration(milliseconds: 240);

  /// 分类筛选面板展开动画时长。
  static const Duration _filterAnimationDuration = Duration(milliseconds: 340);

  /// 标签页内容左右切换动画时长。
  static const Duration _tabSwitchAnimationDuration =
      Duration(milliseconds: 260);

  /// 当前分类筛选区是否处于紧凑摘要态。
  ///
  /// 展开后焦点进入列表时收起为摘要，焦点回到顶部再恢复完整态。
  bool _categoryFilterCompact = false;

  /// TV 首页顶部导航项。
  static const List<String> _tabs = [
    '首页',
    '电影',
    '剧集',
    '动漫',
    '综艺',
    '直播',
  ];

  /// 当前选中的顶部导航下标。
  int _selectedIndex = 0;

  /// 正在切出的顶部导航下标。
  int? _outgoingTabIndex;

  /// 标签页内容切换方向，1 为向右切换，-1 为向左切换。
  double _tabSwitchDirection = 1;

  /// 标签页内容切换动画控制器。
  late final AnimationController _tabSwitchController = AnimationController(
    vsync: this,
    duration: _tabSwitchAnimationDuration,
  );

  /// 首页“继续观看”第一个卡片焦点。
  final FocusNode _continueWatchingFirstFocusNode =
      FocusNode(debugLabel: 'tv-home-continue-first');

  /// 顶部导航控制器。
  final TvTopNavController _topNavController = TvTopNavController();

  /// 分类页首张卡片焦点。
  ///
  /// 顶部分类菜单按下时直接回到首张卡片，避免默认焦点搜索跳到历史卡片位置。
  late final Map<TvCategoryFilterKind, FocusNode> _categoryFirstFocusNodes = {
    for (final kind in TvCategoryFilterKind.values)
      kind: FocusNode(debugLabel: 'tv-category-first-${kind.name}'),
  };

  /// 首页数据加载任务。
  Future<TvHomeData>? _homeDataFuture;

  /// 分类页筛选面板是否已显示。
  bool _categoryFilterVisible = false;

  /// 各分类页当前已确认的筛选项。
  final Map<TvCategoryFilterKind, Map<String, TvCategoryFilterOption>>
      _categoryFilters = {};

  /// 各分类页筛选查询任务。
  final Map<TvCategoryFilterKind, Future<List<VideoInfo>>>
      _categoryDataFutures = {};

  /// 各分类页当前展示数据。
  final Map<TvCategoryFilterKind, List<VideoInfo>> _categoryVideos = {};

  /// 各分类页下一次要请求的页码。
  final Map<TvCategoryFilterKind, int> _categoryNextPages = {};

  /// 各分类页是否仍有更多数据。
  final Map<TvCategoryFilterKind, bool> _categoryHasMore = {};

  /// 各分类页是否正在加载下一页。
  final Map<TvCategoryFilterKind, bool> _categoryLoadingMore = {};

  /// 各分类页请求序号，用于丢弃过期筛选和分页请求。
  final Map<TvCategoryFilterKind, int> _categoryRequestSerials = {};

  /// 分类筛选面板展开后优先回到的筛选行。
  ///
  /// 初次展开从排序开始；内容区回到筛选区时优先落到年份行。
  String? _categoryFilterPreferredFocusRowTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _homeDataFuture ??=
        (widget.loadHomeData ?? TvHomeScreen.defaultLoadHomeData)(context);
  }

  @override
  void initState() {
    super.initState();
    _tabSwitchController.value = 1;
    _tabSwitchController.addStatusListener(_handleTabSwitchStatus);
  }

  @override
  void dispose() {
    _continueWatchingFirstFocusNode.dispose();
    for (final node in _categoryFirstFocusNodes.values) {
      node.dispose();
    }
    _tabSwitchController
      ..removeStatusListener(_handleTabSwitchStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_categoryFilterVisible,
      onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D0E),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnimatedTopNav(),
              Expanded(
                child: ClipRect(
                  key: const ValueKey('tv-home-content-clip'),
                  child: FutureBuilder<TvHomeData>(
                    future: _homeDataFuture,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? TvHomeData.empty();
                      final isLoading =
                          snapshot.connectionState != ConnectionState.done;

                      return _buildAnimatedSelectedTab(data, isLoading);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建带收起动画的顶部导航。
  Widget _buildAnimatedTopNav() {
    return AnimatedSwitcher(
      duration: _topNavAnimationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: _categoryFilterVisible
          ? const SizedBox.shrink(key: ValueKey('tv-top-nav-hidden'))
          : DecoratedBox(
              key: const ValueKey('tv-top-nav-visible'),
              decoration: BoxDecoration(
                color:
                    _selectedIndex == 0 ? Colors.transparent : _topScrimColor,
              ),
              child: TvTopNav(
                tabs: _tabs,
                selectedIndex: _selectedIndex,
                controller: _topNavController,
                onSearchPressed: _openSearch,
                onHistoryPressed: () => _selectTab(6),
                onFavoritesPressed: () => _selectTab(7),
                onSettingsPressed: () => _selectTab(8),
                onTabArrowUp: _handleTopNavArrowUp,
                onTabArrowDown: _handleTopNavArrowDown,
                onChanged: _selectTab,
              ),
            ),
    );
  }

  /// 构建带左右滑页动画的当前标签内容。
  Widget _buildAnimatedSelectedTab(TvHomeData data, bool isLoading) {
    final outgoingIndex = _outgoingTabIndex;
    return AnimatedBuilder(
      animation: _tabSwitchController,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          _tabSwitchController.value,
        );
        final incomingOffset = Offset((1 - progress) * _tabSwitchDirection, 0);
        final outgoingOffset = Offset(-progress * _tabSwitchDirection, 0);
        final showOutgoing =
            outgoingIndex != null && _tabSwitchController.value < 1;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (showOutgoing)
              _buildTabTransitionLayer(
                key: ValueKey('tv-home-tab-outgoing-$outgoingIndex'),
                offset: outgoingOffset,
                child: _buildSelectedTabByIndex(
                  outgoingIndex,
                  data,
                  isLoading,
                ),
              ),
            _buildTabTransitionLayer(
              key: ValueKey('tv-home-tab-incoming-$_selectedIndex'),
              offset: incomingOffset,
              child: _buildSelectedTab(data, isLoading),
            ),
          ],
        );
      },
    );
  }

  /// 构建单层标签页切换动画。
  Widget _buildTabTransitionLayer({
    required Key key,
    required Offset offset,
    required Widget child,
  }) {
    return SlideTransition(
      key: key,
      position: AlwaysStoppedAnimation<Offset>(offset),
      child: child,
    );
  }

  /// 构建当前选中的 TV 标签内容。
  Widget _buildSelectedTab(TvHomeData data, bool isLoading) {
    return _buildSelectedTabByIndex(_selectedIndex, data, isLoading);
  }

  /// 按指定下标构建 TV 标签内容。
  Widget _buildSelectedTabByIndex(
    int index,
    TvHomeData data,
    bool isLoading,
  ) {
    switch (index) {
      case 1:
        return _buildMovieTab(data, isLoading);
      case 2:
        return _buildSeriesTab(data, isLoading);
      case 3:
        return _buildAnimeTab(data, isLoading);
      case 4:
        return _buildVarietyTab(data, isLoading);
      case 5:
        return const TvLiveScreen();
      case 6:
        return _buildHistoryTab(data, isLoading);
      case 7:
        return _buildFavoritesTab(data, isLoading);
      case 8:
        return const TvSettingsScreen();
      case 0:
      default:
        return _buildHomeTab(data, isLoading);
    }
  }

  /// 构建 TV 首页标签内容。
  Widget _buildHomeTab(TvHomeData data, bool isLoading) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleSelectedTabBackKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvHomeSection(
              title: '继续观看',
              videos: data.continueWatching,
              isLoading: isLoading,
              onVideoPressed: _openVideoFromRecord,
              autofocusFirstItem: true,
              firstItemFocusNode: _continueWatchingFirstFocusNode,
              // “继续观看”的“查看更多”进入播放历史页，而不是直播页。
              onMorePressed: () => _selectTab(6),
            ),
            TvHomeSection(
              title: '热门电影',
              videos: data.hotMovies,
              isLoading: isLoading,
              onVideoPressed: (video) => _openVideo(video, stype: 'movie'),
              onMorePressed: () => _selectTab(1),
            ),
            TvHomeSection(
              title: '热门剧集',
              videos: data.hotTvShows,
              isLoading: isLoading,
              onVideoPressed: _openVideo,
              onMorePressed: () => _selectTab(2),
            ),
            TvHomeSection(
              title: '新番放送',
              videos: data.bangumiCalendar,
              isLoading: isLoading,
              onVideoPressed: _openVideo,
              onMorePressed: () => _selectTab(3),
            ),
            TvHomeSection(
              title: '热门综艺',
              videos: data.hotShows,
              isLoading: isLoading,
              onVideoPressed: _openVideo,
              onMorePressed: () => _selectTab(4),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建电影分类标签内容。
  Widget _buildMovieTab(TvHomeData data, bool isLoading) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.movie,
      title: '电影',
      videos: data.hotMovies,
      isLoading: isLoading,
      onVideoPressed: (video) => _openVideo(video, stype: 'movie'),
    );
  }

  /// 构建剧集分类标签内容。
  Widget _buildSeriesTab(TvHomeData data, bool isLoading) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.series,
      title: '剧集',
      videos: data.hotTvShows,
      isLoading: isLoading,
      onVideoPressed: _openVideo,
    );
  }

  /// 构建动漫分类标签内容。
  Widget _buildAnimeTab(TvHomeData data, bool isLoading) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.anime,
      title: '动漫',
      videos: data.bangumiCalendar,
      isLoading: isLoading,
      onVideoPressed: _openVideo,
    );
  }

  /// 构建综艺分类标签内容。
  Widget _buildVarietyTab(TvHomeData data, bool isLoading) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.variety,
      title: '综艺',
      videos: data.hotShows,
      isLoading: isLoading,
      onVideoPressed: _openVideo,
    );
  }

  /// 构建带筛选面板的分类页。
  Widget _buildCategoryTab({
    required TvCategoryFilterKind kind,
    required String title,
    required List<VideoInfo> videos,
    required bool isLoading,
    required TvVideoPressed onVideoPressed,
  }) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        if (_isBackKey(event.logicalKey) && _categoryFilterVisible) {
          _hideCategoryFilter();
          return KeyEventResult.handled;
        }
        if (_isBackKey(event.logicalKey) &&
            !_topNavController.hasFocus &&
            _topNavController.requestSelectedFocus()) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedCategoryFilter(kind),
          Expanded(
            child: ClipRect(
              key: const ValueKey('tv-category-grid-clip'),
              child: _buildCategoryGrid(
                kind: kind,
                title: title,
                videos: videos,
                isLoading: isLoading,
                onVideoPressed: onVideoPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类页 Grid。
  ///
  /// 未选择筛选项时展示首页聚合数据；确认筛选后改用筛选查询结果。
  Widget _buildCategoryGrid({
    required TvCategoryFilterKind kind,
    required String title,
    required List<VideoInfo> videos,
    required bool isLoading,
    required TvVideoPressed onVideoPressed,
  }) {
    final filterFuture = _categoryDataFutures[kind];
    if (filterFuture == null) {
      final currentVideos = _categoryVideos[kind] ?? videos;
      return TvVideoGrid(
        title: title,
        videos: currentVideos,
        isLoading: isLoading,
        isLoadingMore: _categoryLoadingMore[kind] ?? false,
        hasMore: _categoryHasMore[kind] ?? true,
        onLoadMore: () => _loadMoreCategoryVideos(
          kind,
          seedVideos: currentVideos,
        ),
        firstItemFocusNode: _categoryFirstFocusNodes[kind],
        focusMemoryGroupKey: 'tv-category-grid-${kind.name}',
        onVideoPressed: onVideoPressed,
        onVideoFocusChanged: _handleCategoryGridFocusChanged,
        onArrowUp: _categoryFilterVisible && _categoryFilterCompact
            ? _expandCategoryFilter
            : null,
      );
    }

    return FutureBuilder<List<VideoInfo>>(
      future: filterFuture,
      builder: (context, snapshot) {
        final filterLoading = snapshot.connectionState != ConnectionState.done;
        final currentVideos =
            _categoryVideos[kind] ?? snapshot.data ?? const [];
        return TvVideoGrid(
          title: title,
          videos: currentVideos,
          isLoading: filterLoading,
          isLoadingMore: _categoryLoadingMore[kind] ?? false,
          hasMore: _categoryHasMore[kind] ?? false,
          onLoadMore: () => _loadMoreCategoryVideos(
            kind,
            seedVideos: currentVideos,
          ),
          firstItemFocusNode: _categoryFirstFocusNodes[kind],
          focusMemoryGroupKey: 'tv-category-grid-${kind.name}',
          onVideoPressed: onVideoPressed,
          onVideoFocusChanged: _handleCategoryGridFocusChanged,
          onArrowUp: _categoryFilterVisible && _categoryFilterCompact
              ? _expandCategoryFilter
              : null,
        );
      },
    );
  }

  /// 构建从顶部下滑展开的分类筛选面板。
  Widget _buildAnimatedCategoryFilter(TvCategoryFilterKind kind) {
    return AnimatedSwitcher(
      duration: _filterAnimationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, -0.18),
          end: Offset.zero,
        ).animate(curvedAnimation);

        return SizeTransition(
          sizeFactor: curvedAnimation,
          axisAlignment: -1,
          child: SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          ),
        );
      },
      child: _categoryFilterVisible
          ? TvCategoryFilterPanel(
              key: ValueKey(
                _categoryFilterCompact
                    ? 'tv-category-filter-compact'
                    : 'tv-category-filter-visible',
              ),
              kind: kind,
              mode: _categoryFilterCompact
                  ? TvCategoryFilterPanelMode.compact
                  : TvCategoryFilterPanelMode.expanded,
              preferredFocusRowTitle: _categoryFilterPreferredFocusRowTitle,
              selectedOptions: Map<String, TvCategoryFilterOption>.unmodifiable(
                _categoryFilters[kind] ??
                    const <String, TvCategoryFilterOption>{},
              ),
              onChanged: (rowTitle, option) => _handleCategoryFilterChanged(
                kind,
                rowTitle,
                option,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('tv-category-filter-hidden')),
    );
  }

  /// 处理分类筛选确认。
  void _handleCategoryFilterChanged(
    TvCategoryFilterKind kind,
    String rowTitle,
    TvCategoryFilterOption option,
  ) {
    final currentFilters = Map<String, TvCategoryFilterOption>.from(
      _categoryFilters[kind] ?? const <String, TvCategoryFilterOption>{},
    );
    currentFilters[rowTitle] = option;

    final loader =
        widget.loadCategoryData ?? TvHomeScreen.defaultLoadCategoryData;
    final requestSerial = _nextCategoryRequestSerial(kind);
    final filtersSnapshot =
        Map<String, TvCategoryFilterOption>.unmodifiable(currentFilters);
    final firstPageFuture = loader(
      context,
      kind,
      filtersSnapshot,
      0,
    );

    // 确认筛选后立即发起第一页查询，并用结果刷新下方 Grid。
    setState(() {
      _categoryFilters[kind] = currentFilters;
      _categoryDataFutures[kind] = firstPageFuture;
      _categoryVideos.remove(kind);
      _categoryNextPages[kind] = 1;
      _categoryHasMore[kind] = true;
      _categoryLoadingMore[kind] = false;
    });

    firstPageFuture.then((items) {
      if (!mounted || !_isCurrentCategoryRequest(kind, requestSerial)) {
        return;
      }
      setState(() {
        _categoryVideos[kind] = items;
        _categoryHasMore[kind] = items.isNotEmpty;
      });
    }).catchError((_) {
      if (!mounted || !_isCurrentCategoryRequest(kind, requestSerial)) {
        return;
      }
      setState(() {
        _categoryVideos[kind] = const <VideoInfo>[];
        _categoryHasMore[kind] = false;
      });
    });
  }

  /// 加载当前分类页下一页数据。
  Future<void> _loadMoreCategoryVideos(
    TvCategoryFilterKind kind, {
    required List<VideoInfo> seedVideos,
  }) async {
    if (_categoryLoadingMore[kind] == true ||
        (_categoryHasMore[kind] ?? true) == false) {
      return;
    }

    final loader =
        widget.loadCategoryData ?? TvHomeScreen.defaultLoadCategoryData;
    final filters = Map<String, TvCategoryFilterOption>.unmodifiable(
      _categoryFilters[kind] ?? const <String, TvCategoryFilterOption>{},
    );
    final page = _categoryNextPages[kind] ?? 1;
    final requestSerial = _categoryRequestSerials[kind] ?? 0;

    setState(() {
      _categoryVideos[kind] = seedVideos;
      _categoryLoadingMore[kind] = true;
    });

    try {
      final nextItems = await loader(context, kind, filters, page);
      if (!mounted || !_isCurrentCategoryRequest(kind, requestSerial)) {
        return;
      }

      setState(() {
        final merged = _mergeCategoryVideos(seedVideos, nextItems);
        _categoryVideos[kind] = merged;
        _categoryNextPages[kind] = page + 1;
        _categoryHasMore[kind] = nextItems.isNotEmpty;
        _categoryLoadingMore[kind] = false;
      });
    } catch (_) {
      if (!mounted || !_isCurrentCategoryRequest(kind, requestSerial)) {
        return;
      }
      setState(() {
        _categoryHasMore[kind] = false;
        _categoryLoadingMore[kind] = false;
      });
    }
  }

  /// 合并分类分页数据，避免同一视频重复出现。
  List<VideoInfo> _mergeCategoryVideos(
    List<VideoInfo> currentVideos,
    List<VideoInfo> nextItems,
  ) {
    final merged = List<VideoInfo>.of(currentVideos);
    final seenKeys = merged.map(_categoryVideoKey).toSet();
    for (final item in nextItems) {
      // 豆瓣分页偶尔会返回重复条目，追加前按 source + id 去重。
      if (seenKeys.add(_categoryVideoKey(item))) {
        merged.add(item);
      }
    }
    return merged;
  }

  /// 构建分类视频去重键。
  String _categoryVideoKey(VideoInfo videoInfo) {
    return '${videoInfo.source}::${videoInfo.id}';
  }

  /// 生成当前分类页的最新请求序号。
  int _nextCategoryRequestSerial(TvCategoryFilterKind kind) {
    final nextSerial = (_categoryRequestSerials[kind] ?? 0) + 1;
    _categoryRequestSerials[kind] = nextSerial;
    return nextSerial;
  }

  /// 判断分类页请求是否仍属于当前筛选条件。
  bool _isCurrentCategoryRequest(TvCategoryFilterKind kind, int requestSerial) {
    return requestSerial == (_categoryRequestSerials[kind] ?? 0);
  }

  /// 展示分类筛选面板。
  void _showCategoryFilter() {
    setState(() {
      _categoryFilterVisible = true;
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle ??= '排序';
    });
  }

  /// 把摘要态筛选区重新展开为完整筛选面板。
  void _expandCategoryFilter() {
    if (!_categoryFilterVisible || !_categoryFilterCompact) {
      return;
    }
    setState(() {
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle = '年份';
    });
  }

  /// 处理顶部菜单项获焦后的上方向键。
  void _handleTopNavArrowUp(int index) {
    if (!_isCategoryTabIndex(index)) {
      return;
    }
    _showCategoryFilter();
  }

  /// 处理顶部菜单项获焦后的下方向键。
  bool _handleTopNavArrowDown(int index) {
    if (index == 0) {
      if (_continueWatchingFirstFocusNode.canRequestFocus) {
        _continueWatchingFirstFocusNode.requestFocus();
        return true;
      }
      return false;
    }

    if (!_isCategoryTabIndex(index)) {
      return false;
    }

    final kind = _categoryKindForTabIndex(index);
    final focusNode = kind == null ? null : _categoryFirstFocusNodes[kind];
    if (focusNode?.canRequestFocus == true) {
      focusNode!.requestFocus();
      return true;
    }
    return false;
  }

  /// 根据顶部菜单下标获取分类类型。
  TvCategoryFilterKind? _categoryKindForTabIndex(int index) {
    return switch (index) {
      1 => TvCategoryFilterKind.movie,
      2 => TvCategoryFilterKind.series,
      3 => TvCategoryFilterKind.anime,
      4 => TvCategoryFilterKind.variety,
      _ => null,
    };
  }

  /// 判断顶部菜单下标是否为可筛选分类页。
  bool _isCategoryTabIndex(int index) {
    return index >= 1 && index <= 4;
  }

  /// 隐藏分类筛选面板。
  void _hideCategoryFilter() {
    if (!_categoryFilterVisible) {
      return;
    }
    setState(() {
      _categoryFilterVisible = false;
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle = null;
    });

    // 筛选面板关闭后顶部导航会重新挂载，下一帧再把焦点还给当前分类 Tab。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _topNavController.requestSelectedFocus();
    });
  }

  /// 处理分类 Grid 卡片获焦。
  ///
  /// 焦点进入内容区后，把完整筛选栏压成摘要态，给列表留出更多高度。
  void _handleCategoryGridFocusChanged(bool hasFocus) {
    if (!hasFocus || !_categoryFilterVisible || _categoryFilterCompact) {
      return;
    }
    setState(() => _categoryFilterCompact = true);
  }

  /// 处理系统返回。
  void _handlePopInvoked(bool didPop) {
    if (didPop || !_categoryFilterVisible) {
      return;
    }
    _hideCategoryFilter();
  }

  /// 判断是否为返回类按键。
  bool _isBackKey(LogicalKeyboardKey key) {
    return TvBackIntent.isBackKey(key);
  }

  /// 构建播放历史标签内容。
  Widget _buildHistoryTab(TvHomeData data, bool isLoading) {
    return TvVideoGrid(
      title: '播放历史',
      videos: data.history,
      isLoading: isLoading,
      onVideoPressed: _openVideoFromRecord,
    );
  }

  /// 构建收藏夹标签内容。
  Widget _buildFavoritesTab(TvHomeData data, bool isLoading) {
    return TvVideoGrid(
      title: '收藏夹',
      videos: data.favorites,
      isLoading: isLoading,
      onVideoPressed: _openVideoFromRecord,
    );
  }

  /// 按播放记录语义打开视频。
  void _openVideoFromRecord(VideoInfo videoInfo) {
    _openVideo(
      videoInfo,
    );
  }

  /// 切换到指定顶部菜单。
  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _outgoingTabIndex = _selectedIndex;
      _tabSwitchDirection = index > _selectedIndex ? 1 : -1;
      _selectedIndex = index;
      _categoryFilterVisible = false;
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle = null;
    });
    _tabSwitchController.forward(from: 0);
  }

  /// 标签页切换完成后清理旧页面。
  void _handleTabSwitchStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _outgoingTabIndex == null) {
      return;
    }
    if (mounted) {
      setState(() => _outgoingTabIndex = null);
    }
  }

  /// 打开现有播放器页面。
  void _openVideo(
    VideoInfo videoInfo, {
    String? stype,
  }) {
    final detailPage = widget.buildDetailPage?.call(videoInfo, stype) ??
        TvVideoDetailScreen(
          videoInfo: videoInfo,
          stype: stype,
        );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => detailPage,
      ),
    );
  }

  /// 打开搜索页面。
  void _openSearch() {
    final searchPage = widget.buildSearchPage?.call() ?? const TvSearchScreen();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => searchPage,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
