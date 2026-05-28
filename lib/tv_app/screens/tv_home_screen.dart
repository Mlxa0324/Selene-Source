import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/bangumi_service.dart';
import 'package:selene/services/douban_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/tv_app/screens/tv_favorites_screen.dart';
import 'package:selene/tv_app/screens/tv_history_screen.dart';
import 'package:selene/tv_app/screens/tv_live_screen.dart';
import 'package:selene/tv_app/screens/tv_search_screen.dart';
import 'package:selene/tv_app/screens/tv_settings_screen.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/services/tv_video_library_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_category_filter_panel.dart';
import 'package:selene/tv_app/widgets/tv_confirm_dialog.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
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

/// TV 独立功能页构建函数。
///
/// 用于测试替换快捷入口打开的新页面。
typedef TvStandalonePageBuilder = Widget Function();

/// TV 首页继续观看删除函数。
///
/// 用于测试替换真实播放记录删除逻辑。
typedef TvContinueWatchingDeleter = Future<bool> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

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
    this.deleteContinueWatchingItem,
    this.buildDetailPage,
    this.buildSearchPage,
    this.buildHistoryPage,
    this.buildFavoritesPage,
    this.buildSettingsPage,
  });

  /// 首页数据加载函数。
  final TvHomeDataLoader? loadHomeData;

  /// 分类筛选数据加载函数。
  final TvCategoryDataLoader? loadCategoryData;

  /// 继续观看删除函数。
  final TvContinueWatchingDeleter? deleteContinueWatchingItem;

  /// 详情页面构建函数。
  final TvDetailPageBuilder? buildDetailPage;

  /// 搜索页面构建函数。
  final TvSearchPageBuilder? buildSearchPage;

  /// 播放历史页面构建函数。
  final TvStandalonePageBuilder? buildHistoryPage;

  /// 收藏夹页面构建函数。
  final TvStandalonePageBuilder? buildFavoritesPage;

  /// 设置页面构建函数。
  final TvStandalonePageBuilder? buildSettingsPage;

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();

  /// 默认首页数据加载逻辑。
  static Future<TvHomeData> defaultLoadHomeData(BuildContext context) async {
    final cacheService = PageCacheService();
    final continueWatchingFuture =
        TvVideoLibraryService.loadHistoryDirect(context);
    final favoritesFuture = TvVideoLibraryService.loadFavorites(context);
    final hotMoviesFuture = _loadHotMovies(context, cacheService);
    final hotTvShowsFuture = _loadHotTvShows(context, cacheService);
    final bangumiCalendarFuture = _loadBangumiCalendar(context);
    final hotShowsFuture = _loadHotShows(context, cacheService);

    final continueWatching = await continueWatchingFuture;
    final favorites = await favoritesFuture;
    final hotMovies = await hotMoviesFuture;
    final hotTvShows = await hotTvShowsFuture;
    final bangumiCalendar = await bangumiCalendarFuture;
    final hotShows = await hotShowsFuture;

    return TvHomeData(
      continueWatching: continueWatching
          .where((video) => video.source != 'local')
          .take(20)
          .toList(),
      hotMovies: hotMovies.take(20).toList(),
      hotTvShows: hotTvShows.take(20).toList(),
      bangumiCalendar: bangumiCalendar.take(20).toList(),
      hotShows: hotShows.take(20).toList(),
      history: continueWatching.take(60).toList(),
      favorites: favorites.take(60).toList(),
    );
  }

  /// 默认分类筛选查询逻辑。
  ///
  /// 复用手机端同一套豆瓣与 Bangumi 请求分支，TV 端只保留大屏样式和焦点交互。
  static Future<List<VideoInfo>> defaultLoadCategoryData(
    BuildContext context,
    TvCategoryFilterKind kind,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    switch (kind) {
      case TvCategoryFilterKind.movie:
        return _loadMovieCategoryData(context, filters, page);
      case TvCategoryFilterKind.series:
        return _loadSeriesCategoryData(context, filters, page);
      case TvCategoryFilterKind.anime:
        return _loadAnimeCategoryData(context, filters, page);
      case TvCategoryFilterKind.variety:
        return _loadVarietyCategoryData(context, filters, page);
    }
  }

  /// 加载电影分类筛选数据。
  static Future<List<VideoInfo>> _loadMovieCategoryData(
    BuildContext context,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    final category = TvCategoryFilterOptions.selectedOptionFor(
      filters,
      '分类',
      TvCategoryFilterOptions.movieCategoryOptions,
      defaultValue: '热门',
    );
    if (category.value != '全部') {
      final response = await DoubanService.getCategoryData(
        context,
        kind: 'movie',
        category: category.value,
        type: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '地区',
          TvCategoryFilterOptions.movieSimpleRegionOptions,
          '全部',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      );
      return (response.data ?? []).map((movie) => movie.toVideoInfo()).toList();
    }

    return _loadDoubanRecommends(
      context,
      DoubanRecommendsParams(
        kind: 'movie',
        category: TvCategoryFilterOptions.labelOrAll(
          filters,
          '类型',
          TvCategoryFilterOptions.movieTypeOptions,
        ),
        region: TvCategoryFilterOptions.labelOrAll(
          filters,
          '地区',
          TvCategoryFilterOptions.regionOptions,
        ),
        year: TvCategoryFilterOptions.labelOrAll(
          filters,
          '年代',
          TvCategoryFilterOptions.yearOptions,
        ),
        platform: TvCategoryFilterOptions.labelOrAll(
          filters,
          '平台',
          TvCategoryFilterOptions.platformOptions,
        ),
        sort: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '排序',
          TvCategoryFilterOptions.movieSortOptions,
          'T',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      ),
    );
  }

  /// 加载剧集分类筛选数据。
  static Future<List<VideoInfo>> _loadSeriesCategoryData(
    BuildContext context,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    final category = TvCategoryFilterOptions.selectedOptionFor(
      filters,
      '分类',
      TvCategoryFilterOptions.seriesCategoryOptions,
      defaultValue: '最近热门',
    );
    if (category.value != '全部') {
      final response = await DoubanService.getCategoryData(
        context,
        kind: 'tv',
        category: category.value,
        type: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '类型',
          TvCategoryFilterOptions.seriesSimpleTypeOptions,
          'tv',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      );
      return (response.data ?? []).map((movie) => movie.toVideoInfo()).toList();
    }

    return _loadDoubanRecommends(
      context,
      DoubanRecommendsParams(
        kind: 'tv',
        category: TvCategoryFilterOptions.labelOrAll(
          filters,
          '类型',
          TvCategoryFilterOptions.seriesTypeOptions,
        ),
        format: '电视剧',
        region: TvCategoryFilterOptions.labelOrAll(
          filters,
          '地区',
          TvCategoryFilterOptions.regionOptions,
        ),
        year: TvCategoryFilterOptions.labelOrAll(
          filters,
          '年代',
          TvCategoryFilterOptions.yearOptions,
        ),
        platform: TvCategoryFilterOptions.labelOrAll(
          filters,
          '平台',
          TvCategoryFilterOptions.platformOptions,
        ),
        sort: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '排序',
          TvCategoryFilterOptions.seriesSortOptions,
          'T',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      ),
    );
  }

  /// 加载动漫分类筛选数据。
  static Future<List<VideoInfo>> _loadAnimeCategoryData(
    BuildContext context,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    final category = TvCategoryFilterOptions.selectedOptionFor(
      filters,
      '分类',
      TvCategoryFilterOptions.animeCategoryOptions,
      defaultValue: '每日放送',
    );
    if (category.value == '每日放送') {
      final weekday = int.tryParse(
            TvCategoryFilterOptions.valueOrDefault(
              filters,
              '星期',
              TvCategoryFilterOptions.weekdayOptions,
              DateTime.now().weekday.toString(),
            ),
          ) ??
          DateTime.now().weekday;
      final response = await BangumiService.getCalendarByWeekday(
        context,
        weekday,
      );
      return (response.data ?? []).map((item) => item.toVideoInfo()).toList();
    }

    final isSeries = category.value == '番剧';
    return _loadDoubanRecommends(
      context,
      DoubanRecommendsParams(
        kind: isSeries ? 'tv' : 'movie',
        category: '动画',
        label: TvCategoryFilterOptions.labelOrAll(
          filters,
          '类型',
          isSeries
              ? TvCategoryFilterOptions.animeSeriesTypeOptions
              : TvCategoryFilterOptions.animeMovieTypeOptions,
        ),
        format: isSeries ? '电视剧' : 'all',
        region: TvCategoryFilterOptions.labelOrAll(
          filters,
          '地区',
          TvCategoryFilterOptions.regionOptions,
        ),
        year: TvCategoryFilterOptions.labelOrAll(
          filters,
          '年代',
          TvCategoryFilterOptions.yearOptions,
        ),
        platform: isSeries
            ? TvCategoryFilterOptions.labelOrAll(
                filters,
                '平台',
                TvCategoryFilterOptions.platformOptions,
              )
            : 'all',
        sort: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '排序',
          TvCategoryFilterOptions.animeSortOptions,
          'T',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      ),
    );
  }

  /// 加载综艺分类筛选数据。
  static Future<List<VideoInfo>> _loadVarietyCategoryData(
    BuildContext context,
    Map<String, TvCategoryFilterOption> filters,
    int page,
  ) async {
    final category = TvCategoryFilterOptions.selectedOptionFor(
      filters,
      '分类',
      TvCategoryFilterOptions.varietyCategoryOptions,
      defaultValue: '最近热门',
    );
    if (category.value != '全部') {
      final response = await DoubanService.getCategoryData(
        context,
        kind: 'tv',
        category: 'show',
        type: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '类型',
          TvCategoryFilterOptions.varietySimpleTypeOptions,
          'show',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      );
      return (response.data ?? []).map((movie) => movie.toVideoInfo()).toList();
    }

    return _loadDoubanRecommends(
      context,
      DoubanRecommendsParams(
        kind: 'tv',
        category: TvCategoryFilterOptions.labelOrAll(
          filters,
          '类型',
          TvCategoryFilterOptions.varietyTypeOptions,
        ),
        format: '综艺',
        region: TvCategoryFilterOptions.labelOrAll(
          filters,
          '地区',
          TvCategoryFilterOptions.regionOptions,
        ),
        year: TvCategoryFilterOptions.labelOrAll(
          filters,
          '年代',
          TvCategoryFilterOptions.yearOptions,
        ),
        platform: TvCategoryFilterOptions.labelOrAll(
          filters,
          '平台',
          TvCategoryFilterOptions.platformOptions,
        ),
        sort: TvCategoryFilterOptions.valueOrDefault(
          filters,
          '排序',
          TvCategoryFilterOptions.varietySortOptions,
          'T',
        ),
        pageLimit: TvCategoryFilterOptions.pageLimit,
        page: page,
      ),
    );
  }

  /// 执行豆瓣推荐请求并转换为 TV 卡片数据。
  static Future<List<VideoInfo>> _loadDoubanRecommends(
    BuildContext context,
    DoubanRecommendsParams params,
  ) async {
    final response = await DoubanService.fetchDoubanRecommends(
      context,
      params,
    );
    return (response.data ?? []).map((movie) => movie.toVideoInfo()).toList();
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
}

class _TvHomeScreenState extends State<TvHomeScreen>
    with SingleTickerProviderStateMixin {
  /// 根页退出确认弹框显示态。
  ///
  /// 避免长按返回键或 `Esc` 时重复弹出多层退出确认。
  bool _exitDialogVisible = false;

  /// 首页横向分区焦点记忆分组。
  static const String _continueWatchingSectionFocusGroup =
      'tv-home-section-继续观看';
  static const String _hotMoviesSectionFocusGroup = 'tv-home-section-热门电影';
  static const String _hotSeriesSectionFocusGroup = 'tv-home-section-热门剧集';
  static const String _hotAnimeSectionFocusGroup = 'tv-home-section-新番放送';
  static const String _hotVarietySectionFocusGroup = 'tv-home-section-热门综艺';

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

  /// 首页每个横向分区的首张卡片焦点。
  final FocusNode _hotMoviesFirstFocusNode =
      FocusNode(debugLabel: 'tv-home-hot-movies-first');
  final FocusNode _hotSeriesFirstFocusNode =
      FocusNode(debugLabel: 'tv-home-hot-series-first');
  final FocusNode _hotAnimeFirstFocusNode =
      FocusNode(debugLabel: 'tv-home-hot-anime-first');
  final FocusNode _hotVarietyFirstFocusNode =
      FocusNode(debugLabel: 'tv-home-hot-variety-first');

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

  /// 分类筛选面板展开后各行优先回到的筛选项值。
  ///
  /// 记录用户最近一次停留的横向位置，便于上下切换行或从 Grid 返回时恢复手感。
  final Map<TvCategoryFilterKind, Map<String, String>>
      _categoryFilterPreferredFocusOptionValues = {};

  /// 首页横向分区滚动控制器。
  ///
  /// 用于首页首次进入和开发期重载后把每个分区恢复到最左侧，
  /// 避免横向滚动位置残留，导致视觉上像“默认焦点从中间卡片开始”。
  final ScrollController _continueWatchingScrollController =
      ScrollController(keepScrollOffset: false);
  final ScrollController _hotMoviesScrollController =
      ScrollController(keepScrollOffset: false);
  final ScrollController _hotSeriesScrollController =
      ScrollController(keepScrollOffset: false);
  final ScrollController _hotAnimeScrollController =
      ScrollController(keepScrollOffset: false);
  final ScrollController _hotVarietyScrollController =
      ScrollController(keepScrollOffset: false);

  /// 首页分区初始入口状态是否待重置。
  bool _shouldResetHomeEntryState = true;

  /// “继续观看”删除后优先恢复的焦点卡片 ID。
  String? _pendingContinueWatchingFocusVideoId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _homeDataFuture ??= _createHomeDataFuture();
  }

  @override
  void initState() {
    super.initState();
    _tabSwitchController.value = 1;
    _tabSwitchController.addStatusListener(_handleTabSwitchStatus);
    _resetHomeSectionFocusMemory();
  }

  @override
  void reassemble() {
    super.reassemble();
    _resetHomeSectionFocusMemory();
    _shouldResetHomeEntryState = true;
  }

  @override
  void dispose() {
    _continueWatchingFirstFocusNode.dispose();
    _hotMoviesFirstFocusNode.dispose();
    _hotSeriesFirstFocusNode.dispose();
    _hotAnimeFirstFocusNode.dispose();
    _hotVarietyFirstFocusNode.dispose();
    _continueWatchingScrollController.dispose();
    _hotMoviesScrollController.dispose();
    _hotSeriesScrollController.dispose();
    _hotAnimeScrollController.dispose();
    _hotVarietyScrollController.dispose();
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          _handlePopInvokedWithResult(didPop),
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
                onHistoryPressed: _openHistory,
                onFavoritesPressed: _openFavorites,
                onSettingsPressed: _openSettings,
                onTabPressed: _handleTopNavPressed,
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
      case 0:
      default:
        return _buildHomeTab(data, isLoading);
    }
  }

  /// 构建 TV 首页标签内容。
  Widget _buildHomeTab(TvHomeData data, bool isLoading) {
    _scheduleInitialHomeEntryState();
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleSelectedTabBackKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvHomeSection(
              title: '继续观看',
              titleHint: '长按删除',
              pendingFocusVideoId: _pendingContinueWatchingFocusVideoId,
              videos: data.continueWatching,
              isLoading: isLoading,
              scrollController: _continueWatchingScrollController,
              onVideoPressed: _openVideoFromRecord,
              onVideoLongPressed: _deleteContinueWatchingItem,
              autofocusFirstItem: true,
              firstItemFocusNode: _continueWatchingFirstFocusNode,
              onArrowUpFromFirstItem: _topNavController.requestSelectedFocus,
              onArrowDownToNextSection: () => _requestHomeSectionFocus(
                focusGroupKey: _hotMoviesSectionFocusGroup,
                fallbackFocusNode: _hotMoviesFirstFocusNode,
              ),
              // “继续观看”的“查看更多”进入独立播放历史页。
              onMorePressed: _openHistory,
            ),
            TvHomeSection(
              title: '热门电影',
              videos: data.hotMovies,
              isLoading: isLoading,
              scrollController: _hotMoviesScrollController,
              onVideoPressed: (video) => _openVideo(video, stype: 'movie'),
              firstItemFocusNode: _hotMoviesFirstFocusNode,
              onArrowUpFromFirstItem: () => _requestHomeSectionFocus(
                focusGroupKey: _continueWatchingSectionFocusGroup,
                fallbackFocusNode: _continueWatchingFirstFocusNode,
              ),
              onArrowDownToNextSection: () => _requestHomeSectionFocus(
                focusGroupKey: _hotSeriesSectionFocusGroup,
                fallbackFocusNode: _hotSeriesFirstFocusNode,
              ),
              onMorePressed: () => _selectTab(1),
            ),
            TvHomeSection(
              title: '热门剧集',
              videos: data.hotTvShows,
              isLoading: isLoading,
              scrollController: _hotSeriesScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotSeriesFirstFocusNode,
              onArrowUpFromFirstItem: () => _requestHomeSectionFocus(
                focusGroupKey: _hotMoviesSectionFocusGroup,
                fallbackFocusNode: _hotMoviesFirstFocusNode,
              ),
              onArrowDownToNextSection: () => _requestHomeSectionFocus(
                focusGroupKey: _hotAnimeSectionFocusGroup,
                fallbackFocusNode: _hotAnimeFirstFocusNode,
              ),
              onMorePressed: () => _selectTab(2),
            ),
            TvHomeSection(
              title: '新番放送',
              videos: data.bangumiCalendar,
              isLoading: isLoading,
              scrollController: _hotAnimeScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotAnimeFirstFocusNode,
              onArrowUpFromFirstItem: () => _requestHomeSectionFocus(
                focusGroupKey: _hotSeriesSectionFocusGroup,
                fallbackFocusNode: _hotSeriesFirstFocusNode,
              ),
              onArrowDownToNextSection: () => _requestHomeSectionFocus(
                focusGroupKey: _hotVarietySectionFocusGroup,
                fallbackFocusNode: _hotVarietyFirstFocusNode,
              ),
              onMorePressed: () => _selectTab(3),
            ),
            TvHomeSection(
              title: '热门综艺',
              videos: data.hotShows,
              isLoading: isLoading,
              scrollController: _hotVarietyScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotVarietyFirstFocusNode,
              onArrowUpFromFirstItem: () => _requestHomeSectionFocus(
                focusGroupKey: _hotAnimeSectionFocusGroup,
                fallbackFocusNode: _hotAnimeFirstFocusNode,
              ),
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
        titleHint: !_categoryFilterVisible ? '按确认键打开分类筛选' : null,
        videos: currentVideos,
        rightPadding: 0,
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
          titleHint: !_categoryFilterVisible ? '按确认键打开分类筛选' : null,
          videos: currentVideos,
          rightPadding: 0,
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
              preferredFocusOptionValues: Map<String, String>.unmodifiable(
                _categoryFilterPreferredFocusOptionValues[kind] ??
                    const <String, String>{},
              ),
              selectedOptions: Map<String, TvCategoryFilterOption>.unmodifiable(
                _categoryFilters[kind] ??
                    const <String, TvCategoryFilterOption>{},
              ),
              onChanged: (rowTitle, option) => _handleCategoryFilterChanged(
                kind,
                rowTitle,
                option,
              ),
              onFocusChanged: (rowTitle, option) =>
                  _handleCategoryFilterFocusChanged(
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
    _pruneUnavailableCategoryFilters(kind, currentFilters);

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
      _categoryFilterPreferredFocusRowTitle = rowTitle;
      (_categoryFilterPreferredFocusOptionValues[kind] ??= {})[rowTitle] =
          option.value;
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

  /// 记录分类筛选面板最近一次停留的焦点位置。
  void _handleCategoryFilterFocusChanged(
    TvCategoryFilterKind kind,
    String rowTitle,
    TvCategoryFilterOption option,
  ) {
    final rowMemories = _categoryFilterPreferredFocusOptionValues.putIfAbsent(
      kind,
      () => <String, String>{},
    );
    rowMemories[rowTitle] = option.value;
    _categoryFilterPreferredFocusRowTitle = rowTitle;
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

  /// 清理当前分类模式下已经不可见的筛选项。
  ///
  /// 例如电影从“全部”切回“热门电影”后，类型/年代/平台等高级筛选不再参与请求。
  void _pruneUnavailableCategoryFilters(
    TvCategoryFilterKind kind,
    Map<String, TvCategoryFilterOption> filters,
  ) {
    final rows = TvCategoryFilterOptions.rowsFor(kind, filters);
    final visibleRows = {
      for (final row in rows) row.title: row,
    };
    filters.removeWhere((rowTitle, option) {
      final row = visibleRows[rowTitle];
      if (row == null) {
        return true;
      }
      return !row.options.any((item) => item.value == option.value);
    });
  }

  /// 展示分类筛选面板。
  void _showCategoryFilter() {
    setState(() {
      _categoryFilterVisible = true;
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle ??= '分类';
    });
  }

  /// 把摘要态筛选区重新展开为完整筛选面板。
  void _expandCategoryFilter() {
    if (!_categoryFilterVisible || !_categoryFilterCompact) {
      return;
    }
    final kind = _categoryKindForTabIndex(_selectedIndex);
    setState(() {
      _categoryFilterCompact = false;
      if (kind != null) {
        final visibleRows = TvCategoryFilterOptions.rowsFor(
          kind,
          _categoryFilters[kind] ?? const <String, TvCategoryFilterOption>{},
        );
        if (visibleRows.isNotEmpty) {
          _categoryFilterPreferredFocusRowTitle = visibleRows.last.title;
        }
      }
    });
  }

  /// 处理顶部菜单项获焦后的上方向键。
  void _handleTopNavArrowUp(int index) {
    // 顶部菜单上键现在统一交给 TvTopNav 过渡到右上角快捷按钮。
  }

  /// 处理顶部菜单项确认键。
  bool _handleTopNavPressed(int index) {
    if (!_isCategoryTabIndex(index) || index != _selectedIndex) {
      return false;
    }
    _showCategoryFilter();
    return true;
  }

  /// 处理顶部菜单项获焦后的下方向键。
  bool _handleTopNavArrowDown(int index) {
    if (index == 0) {
      return _requestFirstAvailableHomeSectionFocus();
    }

    if (!_isCategoryTabIndex(index)) {
      return false;
    }

    final kind = _categoryKindForTabIndex(index);
    final focusNode = kind == null ? null : _categoryFirstFocusNodes[kind];
    if (focusNode != null && _isAttachedFocusableNode(focusNode)) {
      final focusGroupKey = 'tv-category-grid-${kind!.name}';
      if (TvFocusable.requestRememberedFocusForGroup(focusGroupKey)) {
        return true;
      }
      focusNode.requestFocus();
      return true;
    }
    return false;
  }

  /// 请求首页首个可用分区的第一张卡片焦点。
  ///
  /// 首页首次进入时，如果“继续观看”为空，需要显式回退到下一个有内容的分区，
  /// 避免焦点系统按几何距离默认跳到中间列卡片。
  bool _requestFirstAvailableHomeSectionFocus() {
    final focusTargets = <({Object groupKey, FocusNode firstNode})>[
      (
        groupKey: _continueWatchingSectionFocusGroup,
        firstNode: _continueWatchingFirstFocusNode,
      ),
      (
        groupKey: _hotMoviesSectionFocusGroup,
        firstNode: _hotMoviesFirstFocusNode,
      ),
      (
        groupKey: _hotSeriesSectionFocusGroup,
        firstNode: _hotSeriesFirstFocusNode,
      ),
      (
        groupKey: _hotAnimeSectionFocusGroup,
        firstNode: _hotAnimeFirstFocusNode,
      ),
      (
        groupKey: _hotVarietySectionFocusGroup,
        firstNode: _hotVarietyFirstFocusNode,
      ),
    ];

    for (final target in focusTargets) {
      if (!_isAttachedFocusableNode(target.firstNode)) {
        continue;
      }
      if (TvFocusable.requestRememberedFocusForGroup(target.groupKey)) {
        return true;
      }
      target.firstNode.requestFocus();
      return true;
    }
    return false;
  }

  /// 请求首页横向分区最近一次焦点。
  ///
  /// 多个横向分区上下切换时，统一优先回到分区里上次停留的卡片，
  /// 没有焦点记忆时才回到该分区第一张卡片。
  void _requestHomeSectionFocus({
    required Object focusGroupKey,
    required FocusNode fallbackFocusNode,
  }) {
    if (!_isAttachedFocusableNode(fallbackFocusNode)) {
      return;
    }
    if (TvFocusable.requestRememberedFocusForGroup(focusGroupKey)) {
      return;
    }
    fallbackFocusNode.requestFocus();
  }

  /// 判断首页分区首卡焦点节点是否已挂到真实控件上。
  ///
  /// 空分区虽然会保留页面级 FocusNode，但没有对应卡片可接收焦点，
  /// 这里需要额外过滤未挂载节点，避免顶部按下后落回默认空间寻焦。
  bool _isAttachedFocusableNode(FocusNode focusNode) {
    return focusNode.canRequestFocus && focusNode.context != null;
  }

  /// 安排首页首次进入时重置横向分区的视觉入口状态。
  ///
  /// 这里仅用于首次挂载和开发期热重载后的首帧：
  /// 1. 清掉首页分区焦点记忆，避免默认内容焦点落回中间卡片。
  /// 2. 把每个横向分区滚动位置拉回最左，避免视觉上从中间卡片开始。
  void _scheduleInitialHomeEntryState() {
    if (!_shouldResetHomeEntryState) {
      return;
    }
    _shouldResetHomeEntryState = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final controller in <ScrollController>[
        _continueWatchingScrollController,
        _hotMoviesScrollController,
        _hotSeriesScrollController,
        _hotAnimeScrollController,
        _hotVarietyScrollController,
      ]) {
        if (!controller.hasClients) {
          continue;
        }
        controller.jumpTo(controller.position.minScrollExtent);
      }
    });
  }

  /// 清理首页横向分区的焦点记忆。
  void _resetHomeSectionFocusMemory() {
    for (final groupKey in <Object>[
      _continueWatchingSectionFocusGroup,
      _hotMoviesSectionFocusGroup,
      _hotSeriesSectionFocusGroup,
      _hotAnimeSectionFocusGroup,
      _hotVarietySectionFocusGroup,
    ]) {
      TvFocusable.clearLastFocusedForGroup(groupKey);
    }
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
  ///
  /// 根页返回优先关闭筛选面板，其次把焦点送回顶部导航，只有已经处于根级
  /// 浏览态时才弹出退出确认，避免误触返回直接离开 TV 首页。
  Future<void> _handlePopInvokedWithResult(bool didPop) async {
    if (didPop) {
      return;
    }

    if (_categoryFilterVisible) {
      _hideCategoryFilter();
      return;
    }

    if (!_topNavController.hasFocus && _topNavController.requestSelectedFocus()) {
      return;
    }

    await _showExitConfirmDialog();
  }

  /// 处理当前标签内容区的返回键。
  ///
  /// 首页和分类页列表中按返回键时，只把焦点送回当前选中的顶部导航入口，
  /// 不自动落到列表首项，也不直接退出页面。
  KeyEventResult _handleSelectedTabBackKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_isBackKey(event.logicalKey) || _topNavController.hasFocus) {
      return KeyEventResult.ignored;
    }
    if (_topNavController.requestSelectedFocus()) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 判断是否为返回类按键。
  bool _isBackKey(LogicalKeyboardKey key) {
    return TvBackIntent.isBackKey(key);
  }

  /// 展示 TV 根页退出确认弹框。
  ///
  /// 根页返回时通过确认弹框降低误退出概率，并保持 TV 遥控器焦点手感一致。
  Future<void> _showExitConfirmDialog() async {
    if (_exitDialogVisible || !mounted) {
      return;
    }

    _exitDialogVisible = true;
    final confirmed = await showTvConfirmDialog(
      context: context,
      title: '确定退出 IvyTV？',
      message: '退出后将返回系统桌面',
      confirmLabel: '确认',
    );
    _exitDialogVisible = false;

    if (!confirmed || !mounted) {
      return;
    }

    await _exitTvApp();
  }

  /// 执行 TV 根页退出。
  ///
  /// 统一复用系统返回，让 Android TV 和模拟器都回到宿主桌面。
  Future<void> _exitTvApp() async {
    await SystemNavigator.pop();
  }

  /// 按播放记录语义打开视频。
  void _openVideoFromRecord(VideoInfo videoInfo) {
    _openVideo(
      videoInfo,
    );
  }

  /// 删除首页“继续观看”里的单条播放记录。
  Future<void> _deleteContinueWatchingItem(VideoInfo videoInfo) async {
    final currentData = await _homeDataFuture;
    final continueWatching = currentData?.continueWatching ?? const <VideoInfo>[];
    final deletedIndex = continueWatching.indexWhere(
      (item) => item.source == videoInfo.source && item.id == videoInfo.id,
    );
    if (deletedIndex >= 0) {
      final nextIndex = deletedIndex < continueWatching.length - 1
          ? deletedIndex + 1
          : deletedIndex - 1;
      _pendingContinueWatchingFocusVideoId =
          nextIndex >= 0 && nextIndex < continueWatching.length
              ? continueWatching[nextIndex].id
              : null;
    } else {
      _pendingContinueWatchingFocusVideoId = null;
    }

    if (!mounted) {
      return;
    }
    final confirmed = await showTvConfirmDialog(
      context: context,
      title: '删除继续观看',
      message: '确定要删除这条继续观看记录吗？',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final deleted =
        await (widget.deleteContinueWatchingItem ??
            TvVideoLibraryService.deleteHistoryItem)(context, videoInfo);
    if (!deleted || !mounted) {
      _pendingContinueWatchingFocusVideoId = null;
      return;
    }

    setState(() {
      _homeDataFuture = _createHomeDataFuture();
    });
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
  Future<void> _openVideo(
    VideoInfo videoInfo, {
    String? stype,
  }) async {
    final detailPage = widget.buildDetailPage?.call(videoInfo, stype) ??
        TvVideoDetailScreen(
          videoInfo: videoInfo,
          stype: stype,
        );
    final refreshHome = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => TvTheme.wrapScope(
          context: context,
          child: detailPage,
        ),
      ),
    );
    if (!mounted || refreshHome != true) {
      return;
    }
    setState(() {
      _homeDataFuture = _createHomeDataFuture();
    });
  }

  /// 打开搜索页面。
  void _openSearch() {
    final searchPage = widget.buildSearchPage?.call() ?? const TvSearchScreen();
    _pushQuickPage(searchPage);
  }

  /// 打开播放历史页面。
  Future<void> _openHistory() async {
    final historyPage = widget.buildHistoryPage?.call() ??
        TvHistoryScreen(
          buildDetailPage: (videoInfo) =>
              widget.buildDetailPage?.call(videoInfo, null) ??
              TvVideoDetailScreen(videoInfo: videoInfo),
        );
    final refreshHome = await _pushQuickPage<bool>(historyPage);
    if (!mounted || refreshHome != true) {
      return;
    }
    setState(() {
      _homeDataFuture = _createHomeDataFuture();
    });
  }

  /// 打开收藏夹页面。
  Future<void> _openFavorites() async {
    final favoritesPage = widget.buildFavoritesPage?.call() ??
        TvFavoritesScreen(
          buildDetailPage: (videoInfo) =>
              widget.buildDetailPage?.call(videoInfo, null) ??
              TvVideoDetailScreen(videoInfo: videoInfo),
        );
    final refreshHome = await _pushQuickPage<bool>(favoritesPage);
    if (!mounted || refreshHome != true) {
      return;
    }
    setState(() {
      _homeDataFuture = _createHomeDataFuture();
    });
  }

  /// 打开设置页面。
  void _openSettings() {
    final settingsPage =
        widget.buildSettingsPage?.call() ?? const TvSettingsScreen();
    _pushQuickPage(settingsPage);
  }

  /// 统一打开顶部快捷入口对应的独立页面。
  Future<T?> _pushQuickPage<T extends Object?>(Widget page) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            TvTheme.wrapScope(
          context: context,
          child: page,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  /// 创建首页数据加载任务。
  Future<TvHomeData> _createHomeDataFuture() {
    return (widget.loadHomeData ?? TvHomeScreen.defaultLoadHomeData)(context);
  }
}
