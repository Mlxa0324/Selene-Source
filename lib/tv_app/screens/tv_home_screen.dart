import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/bangumi_service.dart';
import 'package:selene/services/douban_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/user_data_service.dart';
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
import 'package:selene/tv_app/widgets/tv_route.dart';
import 'package:selene/tv_app/widgets/tv_top_nav.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

/// TV 首页数据加载函数。
///
/// [context] 用于复用现有 service 中的请求上下文。
typedef TvHomeDataLoader = Future<TvHomeData> Function(BuildContext context);

/// TV 首页单个分区视频列表加载函数。
///
/// 返回当前分区已经转换好的卡片数据，页面会自行维护该分区的加载态。
typedef TvHomeVideoListLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
);

/// TV 首页继续观看刷新函数。
///
/// 返回当前播放记录快照，页面会自行拆分出“继续观看”和历史列表。
typedef TvContinueWatchingLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
);

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

/// TV 首页数据链路日志前缀。
const String _tvHomeLogTag = 'TvHomeScreen[home]';

/// TV 首页继续观看删除函数。
///
/// 用于测试替换真实播放记录删除逻辑。
typedef TvContinueWatchingDeleter = Future<bool> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

/// TV 首页登录态读取函数。
///
/// 用于判断“继续观看”分区是否应该展示。
typedef TvHomeLoginStateLoader = Future<bool> Function();

/// TV 首页各分区的本地状态键。
///
/// 用于把首页聚合数据拆成多个独立请求后的局部状态。
enum _TvHomeSectionKey {
  /// 继续观看分区。
  continueWatching,

  /// 热门电影分区。
  hotMovies,

  /// 热门剧集分区。
  hotTvShows,

  /// 新番放送分区。
  bangumiCalendar,

  /// 热门综艺分区。
  hotShows,

  /// 播放历史快照。
  history,

  /// 收藏夹快照。
  favorites,
}

/// TV 首页单个分区的本地快照。
///
/// 每个分区独立维护自己的数据和骨架屏状态，避免整页共享一个总 loading。
class _TvHomeSectionSnapshot {
  /// 创建 TV 首页单个分区快照。
  const _TvHomeSectionSnapshot({
    this.videos = const <VideoInfo>[],
    this.isLoading = true,
  });

  /// 当前分区已拿到的视频卡片数据。
  final List<VideoInfo> videos;

  /// 当前分区是否仍在加载。
  final bool isLoading;
}

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
  /// [loadContinueWatching] 用于详情页或独立页返回后，只局部刷新继续观看。
  /// [buildDetailPage] 可在测试中替换详情页，生产环境默认打开 TV 详情页。
  /// [buildSearchPage] 可在测试中替换搜索页，生产环境默认打开普通搜索页。
  const TvHomeScreen({
    super.key,
    this.loadHomeData,
    this.loadHomePlayRecords,
    this.loadHomeHotMovies,
    this.loadHomeHotTvShows,
    this.loadHomeBangumiCalendar,
    this.loadHomeHotShows,
    this.loadHomeFavorites,
    this.loadContinueWatching,
    this.loadHasLoginSession,
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

  /// 首页播放记录加载函数。
  ///
  /// 返回播放记录原始快照，页面会拆成“继续观看”和历史列表两个分区。
  final TvContinueWatchingLoader? loadHomePlayRecords;

  /// 首页热门电影分区加载函数。
  final TvHomeVideoListLoader? loadHomeHotMovies;

  /// 首页热门剧集分区加载函数。
  final TvHomeVideoListLoader? loadHomeHotTvShows;

  /// 首页新番放送分区加载函数。
  final TvHomeVideoListLoader? loadHomeBangumiCalendar;

  /// 首页热门综艺分区加载函数。
  final TvHomeVideoListLoader? loadHomeHotShows;

  /// 首页收藏夹快照加载函数。
  final TvHomeVideoListLoader? loadHomeFavorites;

  /// 首页继续观看局部刷新函数。
  final TvContinueWatchingLoader? loadContinueWatching;

  /// 首页登录态读取函数。
  ///
  /// 未登录时隐藏首页“继续观看”分区，避免展示无意义的空占位。
  final TvHomeLoginStateLoader? loadHasLoginSession;

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
  ///
  /// 保留聚合加载入口，兼容旧测试注入和需要一次性回填首页的场景。
  static Future<TvHomeData> defaultLoadHomeData(BuildContext context) async {
    final playRecordVideosFuture = defaultLoadHomePlayRecords(context);
    final favoritesFuture = defaultLoadHomeFavorites(context);
    final hotMoviesFuture = defaultLoadHomeHotMovies(context);
    final hotTvShowsFuture = defaultLoadHomeHotTvShows(context);
    final bangumiCalendarFuture = defaultLoadHomeBangumiCalendar(context);
    final hotShowsFuture = defaultLoadHomeHotShows(context);

    final playRecordVideos = await playRecordVideosFuture;
    final favorites = await favoritesFuture;
    final hotMovies = await hotMoviesFuture;
    final hotTvShows = await hotTvShowsFuture;
    final bangumiCalendar = await bangumiCalendarFuture;
    final hotShows = await hotShowsFuture;

    return TvHomeData(
      continueWatching: _buildContinueWatchingVideos(playRecordVideos),
      hotMovies: hotMovies.take(20).toList(),
      hotTvShows: hotTvShows.take(20).toList(),
      bangumiCalendar: bangumiCalendar.take(20).toList(),
      hotShows: hotShows.take(20).toList(),
      history: _buildHistoryVideos(playRecordVideos),
      favorites: favorites.take(60).toList(),
    );
  }

  /// 默认首页播放记录加载逻辑。
  ///
  /// 首次进入首页时直接读取播放记录快照，给“继续观看”和历史列表共用。
  static Future<List<VideoInfo>> defaultLoadHomePlayRecords(
    BuildContext context,
  ) {
    return TvVideoLibraryService.loadHistoryDirect(context);
  }

  /// 默认首页热门电影分区加载逻辑。
  static Future<List<VideoInfo>> defaultLoadHomeHotMovies(
    BuildContext context,
  ) async {
    final cacheService = PageCacheService();
    final videos = await _loadHotMovies(context, cacheService);
    return videos.take(20).toList();
  }

  /// 默认首页热门剧集分区加载逻辑。
  static Future<List<VideoInfo>> defaultLoadHomeHotTvShows(
    BuildContext context,
  ) async {
    final cacheService = PageCacheService();
    final videos = await _loadHotTvShows(context, cacheService);
    return videos.take(20).toList();
  }

  /// 默认首页新番放送分区加载逻辑。
  static Future<List<VideoInfo>> defaultLoadHomeBangumiCalendar(
    BuildContext context,
  ) async {
    final videos = await _loadBangumiCalendar(context);
    return videos.take(20).toList();
  }

  /// 默认首页热门综艺分区加载逻辑。
  static Future<List<VideoInfo>> defaultLoadHomeHotShows(
    BuildContext context,
  ) async {
    final cacheService = PageCacheService();
    final videos = await _loadHotShows(context, cacheService);
    return videos.take(20).toList();
  }

  /// 默认首页收藏夹快照加载逻辑。
  static Future<List<VideoInfo>> defaultLoadHomeFavorites(
    BuildContext context,
  ) async {
    final favorites = await TvVideoLibraryService.loadFavorites(context);
    return favorites.take(60).toList();
  }

  /// 默认继续观看局部刷新逻辑。
  ///
  /// 详情页返回首页时优先复用缓存中的播放记录，避免再次等待首页整页聚合请求。
  static Future<List<VideoInfo>> defaultLoadContinueWatching(
    BuildContext context,
  ) {
    return TvVideoLibraryService.loadHistory(context);
  }

  /// 默认首页登录态读取逻辑。
  static Future<bool> defaultLoadHasLoginSession() {
    return UserDataService.isLoggedIn();
  }

  /// 从播放记录里提取首页“继续观看”分区数据。
  static List<VideoInfo> _buildContinueWatchingVideos(
    Iterable<VideoInfo> playRecordVideos,
  ) {
    return playRecordVideos
        .where((video) => video.source != 'local')
        .take(20)
        .toList();
  }

  /// 从播放记录里提取首页历史快照。
  static List<VideoInfo> _buildHistoryVideos(
    Iterable<VideoInfo> playRecordVideos,
  ) {
    return playRecordVideos.take(60).toList();
  }

  /// 在保留热门分区的前提下，只替换首页播放记录相关数据。
  static TvHomeData copyWithContinueWatchingRecords({
    required TvHomeData baseData,
    required List<VideoInfo> playRecordVideos,
  }) {
    return TvHomeData(
      continueWatching: _buildContinueWatchingVideos(playRecordVideos),
      hotMovies: baseData.hotMovies,
      hotTvShows: baseData.hotTvShows,
      bangumiCalendar: baseData.bangumiCalendar,
      hotShows: baseData.hotShows,
      history: _buildHistoryVideos(playRecordVideos),
      favorites: baseData.favorites,
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
    final stopwatch = Stopwatch()..start();
    debugPrint('$_tvHomeLogTag section=新番放送 service request start.');
    try {
      final response = await BangumiService.getTodayCalendar(context);
      final videos =
          (response.data ?? []).map((item) => item.toVideoInfo()).toList();
      final previewTitles = videos
          .take(5)
          .map((video) => video.title.trim())
          .where((title) => title.isNotEmpty)
          .join(' | ');
      debugPrint(
        '$_tvHomeLogTag section=新番放送 service request done, success=${response.success}, items=${videos.length}, statusCode=${response.statusCode}, message=${response.message}, preview=[$previewTitles], elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      return videos;
    } catch (error) {
      debugPrint(
        '$_tvHomeLogTag section=新番放送 service request exception, type=${error.runtimeType}, message=$error, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
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
  /// 输出首页分区加载调试日志。
  ///
  /// 用于把“新番放送 5 秒兜底”在首页这一层的开始、结束和空结果串起来看。
  void _logHomeDebug(String message) {
    debugPrint('$_tvHomeLogTag $message');
  }

  /// 读取首页分区中文名称。
  ///
  /// 控制台统一输出可读分区名，避免只看枚举值时难以对照页面。
  String _homeSectionLabel(_TvHomeSectionKey section) {
    switch (section) {
      case _TvHomeSectionKey.continueWatching:
        return '继续观看';
      case _TvHomeSectionKey.hotMovies:
        return '热门电影';
      case _TvHomeSectionKey.hotTvShows:
        return '热门剧集';
      case _TvHomeSectionKey.bangumiCalendar:
        return '新番放送';
      case _TvHomeSectionKey.hotShows:
        return '热门综艺';
      case _TvHomeSectionKey.history:
        return '播放历史';
      case _TvHomeSectionKey.favorites:
        return '收藏夹';
    }
  }

  /// 根页退出确认弹框显示态。
  ///
  /// 避免长按返回键或 `Esc` 时重复弹出多层退出确认。
  bool _exitDialogVisible = false;

  /// 首页根级退出确认武装态。
  ///
  /// 第一次返回只回到稳定的根级浏览态，第二次返回才弹退出确认，
  /// 避免首页首屏已经停在顶部导航时一次误触就直接看到退出弹框。
  bool _homeExitConfirmArmed = false;

  /// 首页横向分区焦点记忆分组。
  static const String _continueWatchingSectionFocusGroup =
      'tv-home-section-继续观看';
  static const String _hotMoviesSectionFocusGroup = 'tv-home-section-热门电影';
  static const String _hotSeriesSectionFocusGroup = 'tv-home-section-热门剧集';
  static const String _hotAnimeSectionFocusGroup = 'tv-home-section-新番放送';
  static const String _hotVarietySectionFocusGroup = 'tv-home-section-热门综艺';

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

  /// 首页数据加载是否已经启动。
  ///
  /// `didChangeDependencies` 可能会多次触发，这里只允许首页首轮数据请求启动一次。
  bool _homeDataLoadStarted = false;

  /// 首页整轮分区加载序号。
  ///
  /// 热重载或未来需要主动重刷整页时，可用它丢弃过期分区回包。
  int _homeDataLoadVersion = 0;

  /// 首页各分区本地快照。
  ///
  /// 每个分区独立维护自己的数据和 loading，避免共享整页骨架屏。
  final Map<_TvHomeSectionKey, _TvHomeSectionSnapshot> _homeSectionSnapshots = {
    for (final section in _TvHomeSectionKey.values)
      section: const _TvHomeSectionSnapshot(),
  };

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

  /// 是否已经派发过首页冷启动首焦点。
  ///
  /// 外层 `TvBackHandler` 会先拿到根焦点，导致首页顶部导航的 `autofocus`
  /// 在真实 App 壳里失效。这里在首页首帧完成后补发一次，把焦点稳定收回
  /// 当前选中的顶部 tab。
  bool _didDispatchInitialTopNavFocus = false;

  /// 首页内容区是否已经完成过首次人工浏览。
  ///
  /// 首次冷启动进入首页时，顶部导航按下应该固定进入首个非空分区，
  /// 不读取历史焦点记忆；只有用户真正浏览过首页内容后，才恢复记忆逻辑。
  bool _hasEnteredHomeContentOnce = false;

  /// “继续观看”删除后优先恢复的焦点卡片 ID。
  String? _pendingContinueWatchingFocusVideoId;

  /// 首页最近一次成功加载的数据快照。
  ///
  /// 删除继续观看等本地操作优先在这份快照上做局部更新，避免整页重新挂骨架。
  TvHomeData? _lastResolvedHomeData;

  /// 当前是否展示“继续观看”分区。
  ///
  /// 仅当存在有效登录态时才展示，未登录时整块入口直接隐藏。
  bool _showContinueWatchingSection = true;

  /// 继续观看局部刷新序号。
  ///
  /// 详情页或独立列表页返回时只刷新继续观看，旧请求回包不应覆盖更新后的首页快照。
  int _continueWatchingRefreshVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureHomeDataLoadStarted();
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
    final pageBackgroundColor = TvTheme.backgroundOf(context).color;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          _handlePopInvokedWithResult(didPop),
      child: Scaffold(
        backgroundColor: pageBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnimatedTopNav(),
              Expanded(
                child: ClipRect(
                  key: const ValueKey('tv-home-content-clip'),
                  child: _buildAnimatedSelectedTab(_buildCurrentHomeData()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 确保首页首轮数据加载已经启动。
  void _ensureHomeDataLoadStarted() {
    if (_homeDataLoadStarted) {
      return;
    }
    _homeDataLoadStarted = true;
    _loadHomeData();
  }

  /// 触发首页数据加载。
  ///
  /// 生产环境默认拆成多个独立分区请求；只有注入旧版聚合 loader 时，
  /// 才保留一次性回填全部首页数据的兼容路径。
  void _loadHomeData() {
    final loadVersion = ++_homeDataLoadVersion;
    _logHomeDebug('start load version=$loadVersion.');
    if (_shouldResolveContinueWatchingVisibility()) {
      _loadHomeLoginState(loadVersion);
    }
    if (widget.loadHomeData != null) {
      _logHomeDebug('version=$loadVersion using legacy aggregate loader.');
      _loadLegacyHomeData(loadVersion);
      return;
    }

    _logHomeDebug('version=$loadVersion using split section loaders.');
    _loadHomeRecordSections(loadVersion);
    _loadHomeVideoSection(
      loadVersion,
      section: _TvHomeSectionKey.hotMovies,
      loader: widget.loadHomeHotMovies ?? TvHomeScreen.defaultLoadHomeHotMovies,
    );
    _loadHomeVideoSection(
      loadVersion,
      section: _TvHomeSectionKey.hotTvShows,
      loader:
          widget.loadHomeHotTvShows ?? TvHomeScreen.defaultLoadHomeHotTvShows,
    );
    _loadHomeVideoSection(
      loadVersion,
      section: _TvHomeSectionKey.bangumiCalendar,
      loader: widget.loadHomeBangumiCalendar ??
          TvHomeScreen.defaultLoadHomeBangumiCalendar,
    );
    _loadHomeVideoSection(
      loadVersion,
      section: _TvHomeSectionKey.hotShows,
      loader: widget.loadHomeHotShows ?? TvHomeScreen.defaultLoadHomeHotShows,
    );
    _loadHomeVideoSection(
      loadVersion,
      section: _TvHomeSectionKey.favorites,
      loader: widget.loadHomeFavorites ?? TvHomeScreen.defaultLoadHomeFavorites,
    );
  }

  /// 判断当前首页是否需要主动读取登录态。
  ///
  /// 生产环境使用默认加载链路时需要真实判断登录态；测试若注入了首页数据，
  /// 则只有显式传入 `loadHasLoginSession` 才启用该逻辑，避免误读空偏好导致用例串成“未登录”。
  bool _shouldResolveContinueWatchingVisibility() {
    if (widget.loadHasLoginSession != null) {
      return true;
    }
    return widget.loadHomeData == null &&
        widget.loadHomePlayRecords == null &&
        widget.loadHomeHotMovies == null &&
        widget.loadHomeHotTvShows == null &&
        widget.loadHomeBangumiCalendar == null &&
        widget.loadHomeHotShows == null &&
        widget.loadHomeFavorites == null &&
        widget.loadContinueWatching == null;
  }

  /// 读取首页当前登录态。
  ///
  /// 登录态只影响“继续观看”分区是否可见，不阻塞其它热门分区继续加载。
  Future<void> _loadHomeLoginState(int loadVersion) async {
    final loader =
        widget.loadHasLoginSession ?? TvHomeScreen.defaultLoadHasLoginSession;
    try {
      final hasLoginSession = await loader();
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      setState(() {
        _showContinueWatchingSection = hasLoginSession;
        _syncLastResolvedHomeData();
      });
    } catch (_) {
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      setState(() {
        _showContinueWatchingSection = true;
        _syncLastResolvedHomeData();
      });
    }
  }

  /// 加载旧版聚合首页数据。
  ///
  /// 该分支主要用于兼容测试注入的 `loadHomeData`，避免一次改动打散现有用例。
  Future<void> _loadLegacyHomeData(int loadVersion) async {
    final stopwatch = Stopwatch()..start();
    try {
      final data =
          await (widget.loadHomeData ?? TvHomeScreen.defaultLoadHomeData)(
        context,
      );
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      _logHomeDebug(
        'version=$loadVersion legacy aggregate loader success, continueWatching=${data.continueWatching.length}, hotMovies=${data.hotMovies.length}, hotTvShows=${data.hotTvShows.length}, bangumiCalendar=${data.bangumiCalendar.length}, hotShows=${data.hotShows.length}, favorites=${data.favorites.length}, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() => _applyResolvedHomeData(data));
    } catch (error) {
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      // 聚合 loader 失败时整页回退为空态，但必须结束骨架，避免首页永久停留在 loading。
      _logHomeDebug(
        'version=$loadVersion legacy aggregate loader failed, type=${error.runtimeType}, message=$error, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() => _applyResolvedHomeData(TvHomeData.empty()));
    }
  }

  /// 加载首页播放记录相关分区。
  ///
  /// 播放记录会同时驱动“继续观看”和历史快照两个分区，因此要一次回写两份状态。
  Future<void> _loadHomeRecordSections(int loadVersion) async {
    final requestVersion = _continueWatchingRefreshVersion;
    final loader = widget.loadHomePlayRecords ??
        widget.loadContinueWatching ??
        TvHomeScreen.defaultLoadHomePlayRecords;
    final stopwatch = Stopwatch()..start();
    _logHomeDebug(
      'version=$loadVersion sectionGroup=播放记录 start, refreshVersion=$requestVersion.',
    );

    try {
      final playRecordVideos = await loader(context);
      if (!mounted ||
          !_isCurrentHomeLoadVersion(loadVersion) ||
          requestVersion != _continueWatchingRefreshVersion) {
        return;
      }
      _logHomeDebug(
        'version=$loadVersion sectionGroup=播放记录 success, continueWatching=${TvHomeScreen._buildContinueWatchingVideos(playRecordVideos).length}, history=${TvHomeScreen._buildHistoryVideos(playRecordVideos).length}, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() {
        _setHomeSectionSnapshot(
          _TvHomeSectionKey.continueWatching,
          TvHomeScreen._buildContinueWatchingVideos(playRecordVideos),
          isLoading: false,
        );
        _setHomeSectionSnapshot(
          _TvHomeSectionKey.history,
          TvHomeScreen._buildHistoryVideos(playRecordVideos),
          isLoading: false,
        );
        _syncLastResolvedHomeData();
      });
    } catch (error) {
      if (!mounted ||
          !_isCurrentHomeLoadVersion(loadVersion) ||
          requestVersion != _continueWatchingRefreshVersion) {
        return;
      }
      // 记录请求失败时只让对应分区回退为空列表，不能拖累其它热门分区继续显示。
      _logHomeDebug(
        'version=$loadVersion sectionGroup=播放记录 failed, type=${error.runtimeType}, message=$error, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() {
        _setHomeSectionSnapshot(
          _TvHomeSectionKey.continueWatching,
          const <VideoInfo>[],
          isLoading: false,
        );
        _setHomeSectionSnapshot(
          _TvHomeSectionKey.history,
          const <VideoInfo>[],
          isLoading: false,
        );
        _syncLastResolvedHomeData();
      });
    }
  }

  /// 加载首页单个热门分区。
  Future<void> _loadHomeVideoSection(
    int loadVersion, {
    required _TvHomeSectionKey section,
    required TvHomeVideoListLoader loader,
  }) async {
    final sectionLabel = _homeSectionLabel(section);
    final stopwatch = Stopwatch()..start();
    _logHomeDebug('version=$loadVersion section=$sectionLabel start.');
    try {
      final videos = await loader(context);
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      _logHomeDebug(
        'version=$loadVersion section=$sectionLabel success, items=${videos.length}, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() {
        _setHomeSectionSnapshot(section, videos, isLoading: false);
        _syncLastResolvedHomeData();
      });
    } catch (error) {
      if (!mounted || !_isCurrentHomeLoadVersion(loadVersion)) {
        return;
      }
      // 单分区失败时只结束自己的骨架，避免首页被单个慢源或坏源拖死。
      _logHomeDebug(
        'version=$loadVersion section=$sectionLabel failed, type=${error.runtimeType}, message=$error, elapsed=${stopwatch.elapsedMilliseconds}ms.',
      );
      setState(() {
        _setHomeSectionSnapshot(section, const <VideoInfo>[], isLoading: false);
        _syncLastResolvedHomeData();
      });
    }
  }

  /// 判断当前回包是否仍属于最新一轮首页加载。
  bool _isCurrentHomeLoadVersion(int loadVersion) {
    return loadVersion == _homeDataLoadVersion;
  }

  /// 更新首页单个分区快照。
  void _setHomeSectionSnapshot(
    _TvHomeSectionKey section,
    List<VideoInfo> videos, {
    required bool isLoading,
  }) {
    _homeSectionSnapshots[section] = _TvHomeSectionSnapshot(
      videos: videos,
      isLoading: isLoading,
    );
  }

  /// 读取首页单个分区 loading 状态。
  bool _isHomeSectionLoading(_TvHomeSectionKey section) {
    return _homeSectionSnapshots[section]?.isLoading ?? false;
  }

  /// 根据分区快照重新拼出当前首页数据。
  TvHomeData _buildCurrentHomeData() {
    return TvHomeData(
      continueWatching:
          _homeSectionSnapshots[_TvHomeSectionKey.continueWatching]?.videos ??
              const <VideoInfo>[],
      hotMovies: _homeSectionSnapshots[_TvHomeSectionKey.hotMovies]?.videos ??
          const <VideoInfo>[],
      hotTvShows: _homeSectionSnapshots[_TvHomeSectionKey.hotTvShows]?.videos ??
          const <VideoInfo>[],
      bangumiCalendar:
          _homeSectionSnapshots[_TvHomeSectionKey.bangumiCalendar]?.videos ??
              const <VideoInfo>[],
      hotShows: _homeSectionSnapshots[_TvHomeSectionKey.hotShows]?.videos ??
          const <VideoInfo>[],
      history: _homeSectionSnapshots[_TvHomeSectionKey.history]?.videos ??
          const <VideoInfo>[],
      favorites: _homeSectionSnapshots[_TvHomeSectionKey.favorites]?.videos ??
          const <VideoInfo>[],
    );
  }

  /// 把当前分区快照同步成首页聚合缓存。
  ///
  /// 继续观看删除、详情返回刷新等局部更新逻辑仍然依赖这份快照复用已有分区数据。
  void _syncLastResolvedHomeData() {
    _lastResolvedHomeData = _buildCurrentHomeData();
  }

  /// 用聚合数据一次性回填首页全部分区。
  void _applyResolvedHomeData(TvHomeData data) {
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.continueWatching,
      data.continueWatching,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.hotMovies,
      data.hotMovies,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.hotTvShows,
      data.hotTvShows,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.bangumiCalendar,
      data.bangumiCalendar,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.hotShows,
      data.hotShows,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.history,
      data.history,
      isLoading: false,
    );
    _setHomeSectionSnapshot(
      _TvHomeSectionKey.favorites,
      data.favorites,
      isLoading: false,
    );
    _lastResolvedHomeData = data;
  }

  /// 构建带收起动画的顶部导航。
  Widget _buildAnimatedTopNav() {
    // 非首页标签页需要和全局 TV 页面背景保持一致，避免顶部区域残留写死底色。
    final topNavBackgroundColor = _selectedIndex == 0
        ? Colors.transparent
        : TvTheme.backgroundOf(context).color;
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
                color: topNavBackgroundColor,
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
  Widget _buildAnimatedSelectedTab(TvHomeData data) {
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
                ),
              ),
            _buildTabTransitionLayer(
              key: ValueKey('tv-home-tab-incoming-$_selectedIndex'),
              offset: incomingOffset,
              child: _buildSelectedTab(data),
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
  Widget _buildSelectedTab(TvHomeData data) {
    return _buildSelectedTabByIndex(_selectedIndex, data);
  }

  /// 按指定下标构建 TV 标签内容。
  Widget _buildSelectedTabByIndex(
    int index,
    TvHomeData data,
  ) {
    switch (index) {
      case 1:
        return _buildMovieTab(data);
      case 2:
        return _buildSeriesTab(data);
      case 3:
        return _buildAnimeTab(data);
      case 4:
        return _buildVarietyTab(data);
      case 5:
        return const TvLiveScreen();
      case 0:
      default:
        return _buildHomeTab(data);
    }
  }

  /// 构建 TV 首页标签内容。
  Widget _buildHomeTab(TvHomeData data) {
    _scheduleInitialHomeEntryState();
    _dispatchInitialTopNavFocusIfNeeded();
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleSelectedTabBackKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showContinueWatchingSection)
              TvHomeSection(
                title: '继续观看',
                titleHint: '长按删除',
                pendingFocusVideoId: _pendingContinueWatchingFocusVideoId,
                videos: data.continueWatching,
                isLoading: _isHomeSectionLoading(
                  _TvHomeSectionKey.continueWatching,
                ),
                scrollController: _continueWatchingScrollController,
                onVideoPressed: _openVideoFromRecord,
                onVideoLongPressed: _deleteContinueWatchingItem,
                firstItemFocusNode: _continueWatchingFirstFocusNode,
                onArrowUpFromAnyItem: _topNavController.requestSelectedFocus,
                onArrowUpFromFirstItem: _topNavController.requestSelectedFocus,
                onArrowDownToNextSection: () =>
                    _requestAdjacentHomeSectionFocus(
                  currentSection: _TvHomeSectionKey.continueWatching,
                  moveForward: true,
                ),
                // “继续观看”的“查看更多”进入独立播放历史页。
                onMorePressed: _openHistory,
              ),
            TvHomeSection(
              title: '热门电影',
              videos: data.hotMovies,
              isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotMovies),
              scrollController: _hotMoviesScrollController,
              onVideoPressed: (video) => _openVideo(video, stype: 'movie'),
              firstItemFocusNode: _hotMoviesFirstFocusNode,
              onArrowUpFromAnyItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotMovies,
                moveForward: false,
              ),
              onArrowUpFromFirstItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotMovies,
                moveForward: false,
              ),
              onArrowDownToNextSection: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotMovies,
                moveForward: true,
              ),
              onMorePressed: () => _selectTab(1),
            ),
            TvHomeSection(
              title: '热门剧集',
              videos: data.hotTvShows,
              isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotTvShows),
              scrollController: _hotSeriesScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotSeriesFirstFocusNode,
              onArrowUpFromAnyItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotTvShows,
                moveForward: false,
              ),
              onArrowUpFromFirstItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotTvShows,
                moveForward: false,
              ),
              onArrowDownToNextSection: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotTvShows,
                moveForward: true,
              ),
              onMorePressed: () => _selectTab(2),
            ),
            TvHomeSection(
              title: '新番放送',
              videos: data.bangumiCalendar,
              isLoading: _isHomeSectionLoading(
                _TvHomeSectionKey.bangumiCalendar,
              ),
              scrollController: _hotAnimeScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotAnimeFirstFocusNode,
              onArrowUpFromAnyItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.bangumiCalendar,
                moveForward: false,
              ),
              onArrowUpFromFirstItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.bangumiCalendar,
                moveForward: false,
              ),
              onArrowDownToNextSection: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.bangumiCalendar,
                moveForward: true,
              ),
              onMorePressed: () => _selectTab(3),
            ),
            TvHomeSection(
              title: '热门综艺',
              videos: data.hotShows,
              isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotShows),
              scrollController: _hotVarietyScrollController,
              onVideoPressed: _openVideo,
              firstItemFocusNode: _hotVarietyFirstFocusNode,
              onArrowUpFromAnyItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotShows,
                moveForward: false,
              ),
              onArrowUpFromFirstItem: () => _requestAdjacentHomeSectionFocus(
                currentSection: _TvHomeSectionKey.hotShows,
                moveForward: false,
              ),
              onMorePressed: () => _selectTab(4),
            ),
          ],
        ),
      ),
    );
  }

  /// 在首页冷启动首帧完成后，把焦点显式送回当前选中的顶部导航项。
  ///
  /// 这样即便外层 App 壳的返回键处理节点先拿到焦点，用户首次进入 TV 首页时
  /// 仍然会从“首页”tab 开始浏览，而不是停在页面根节点或内容卡片上。
  void _dispatchInitialTopNavFocusIfNeeded() {
    if (_didDispatchInitialTopNavFocus) {
      return;
    }
    _didDispatchInitialTopNavFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _topNavController.requestSelectedFocus();
    });
  }

  /// 构建电影分类标签内容。
  Widget _buildMovieTab(TvHomeData data) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.movie,
      title: '电影',
      videos: data.hotMovies,
      isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotMovies),
      onVideoPressed: (video) => _openVideo(video, stype: 'movie'),
    );
  }

  /// 构建剧集分类标签内容。
  Widget _buildSeriesTab(TvHomeData data) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.series,
      title: '剧集',
      videos: data.hotTvShows,
      isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotTvShows),
      onVideoPressed: _openVideo,
    );
  }

  /// 构建动漫分类标签内容。
  Widget _buildAnimeTab(TvHomeData data) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.anime,
      title: '动漫',
      videos: data.bangumiCalendar,
      isLoading: _isHomeSectionLoading(_TvHomeSectionKey.bangumiCalendar),
      onVideoPressed: _openVideo,
    );
  }

  /// 构建综艺分类标签内容。
  Widget _buildVarietyTab(TvHomeData data) {
    return _buildCategoryTab(
      kind: TvCategoryFilterKind.variety,
      title: '综艺',
      videos: data.hotShows,
      isLoading: _isHomeSectionLoading(_TvHomeSectionKey.hotShows),
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
    _disarmHomeExitConfirm();
    for (final target in _homeSectionFocusTargets()) {
      if (_hasEnteredHomeContentOnce) {
        if (_requestHomeSectionFocus(
          focusGroupKey: target.groupKey,
          fallbackFocusNode: target.firstNode,
        )) {
          return true;
        }
        continue;
      }
      // 首页首次从顶部导航进入内容区时，产品期望从首个可用卡片开始，
      // 不读取测试预置焦点或重建残留的分区记忆。
      TvFocusable.resetGroupEntryToFirstFocusable(target.groupKey);
      if (_requestHomeSectionFocus(
        focusGroupKey: target.groupKey,
        fallbackFocusNode: target.firstNode,
      )) {
        _hasEnteredHomeContentOnce = true;
        return true;
      }
    }
    return false;
  }

  /// 构建首页横向分区的焦点跳转顺序。
  ///
  /// 首页上下分区切换、顶部导航下探和焦点记忆恢复都统一复用这份顺序，
  /// 避免某个中间分区为空时还写死跳到它，导致焦点停在原地。
  List<({Object groupKey, FocusNode firstNode, _TvHomeSectionKey section})>
      _homeSectionFocusTargets() {
    return <({
      Object groupKey,
      FocusNode firstNode,
      _TvHomeSectionKey section
    })>[
      if (_showContinueWatchingSection)
        (
          groupKey: _continueWatchingSectionFocusGroup,
          firstNode: _continueWatchingFirstFocusNode,
          section: _TvHomeSectionKey.continueWatching,
        ),
      (
        groupKey: _hotMoviesSectionFocusGroup,
        firstNode: _hotMoviesFirstFocusNode,
        section: _TvHomeSectionKey.hotMovies,
      ),
      (
        groupKey: _hotSeriesSectionFocusGroup,
        firstNode: _hotSeriesFirstFocusNode,
        section: _TvHomeSectionKey.hotTvShows,
      ),
      (
        groupKey: _hotAnimeSectionFocusGroup,
        firstNode: _hotAnimeFirstFocusNode,
        section: _TvHomeSectionKey.bangumiCalendar,
      ),
      (
        groupKey: _hotVarietySectionFocusGroup,
        firstNode: _hotVarietyFirstFocusNode,
        section: _TvHomeSectionKey.hotShows,
      ),
    ];
  }

  /// 沿首页分区顺序跳到相邻的下一个可聚焦分区。
  ///
  /// 当前分区上下方如果存在空列表，需要直接越过空分区，回到最近一次停留卡片，
  /// 没有焦点记忆时再落到目标分区第一张卡片。
  void _requestAdjacentHomeSectionFocus({
    required _TvHomeSectionKey currentSection,
    required bool moveForward,
  }) {
    _disarmHomeExitConfirm();
    final focusTargets = _homeSectionFocusTargets();
    final currentIndex = focusTargets.indexWhere(
      (target) => target.section == currentSection,
    );
    if (currentIndex < 0) {
      return;
    }

    final step = moveForward ? 1 : -1;
    for (var index = currentIndex + step;
        index >= 0 && index < focusTargets.length;
        index += step) {
      final target = focusTargets[index];
      if (_requestHomeSectionFocus(
        focusGroupKey: target.groupKey,
        fallbackFocusNode: target.firstNode,
      )) {
        return;
      }
    }

    // 已经来到首页内容区最顶部的非空分区时，上键应当回到当前顶部导航入口。
    // 例如“继续观看”为空、焦点停在“热门电影”首卡时，不能再因为没有上一个分区而停在原地。
    if (!moveForward) {
      _topNavController.requestSelectedFocus();
    }
  }

  /// 请求首页横向分区最近一次焦点。
  ///
  /// 多个横向分区上下切换时，统一优先回到分区里上次停留的卡片，
  /// 没有焦点记忆时才回到该分区第一张卡片。
  bool _requestHomeSectionFocus({
    required Object focusGroupKey,
    required FocusNode fallbackFocusNode,
  }) {
    // 横向分区滚到右侧后，首卡可能已经被 Sliver 回收；这时要先尝试该分区最近
    // 一次停留的可用卡片，再退回到首卡兜底，避免整排被误判为“不可回焦”。
    if (TvFocusable.requestRememberedFocusForGroup(focusGroupKey)) {
      return true;
    }
    if (!_isAttachedFocusableNode(fallbackFocusNode)) {
      return false;
    }
    fallbackFocusNode.requestFocus();
    return true;
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
      _disarmHomeExitConfirm();
      _hideCategoryFilter();
      return;
    }

    if (!_topNavController.hasFocus &&
        _topNavController.requestSelectedFocus()) {
      _homeExitConfirmArmed = true;
      return;
    }

    // 首页根级返回采用“两段式退出”：
    // 第一次返回只稳定回到根级浏览态，第二次返回才真正弹退出确认。
    if (!_homeExitConfirmArmed) {
      _homeExitConfirmArmed = true;
      _topNavController.requestSelectedFocus();
      return;
    }

    _disarmHomeExitConfirm();
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
      // 用户已经明确看过退出确认但选择取消，仍视为停留在根级退出态，
      // 下次返回可以直接再次弹框，不必重新经历第一次返回的武装步骤。
      _homeExitConfirmArmed = true;
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
    final currentData = _lastResolvedHomeData ?? _buildCurrentHomeData();
    final continueWatching = currentData.continueWatching;
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

    final deleted = await (widget.deleteContinueWatchingItem ??
        TvVideoLibraryService.deleteHistoryItem)(context, videoInfo);
    if (!deleted || !mounted) {
      _pendingContinueWatchingFocusVideoId = null;
      return;
    }

    final baseData = _lastResolvedHomeData ?? currentData;
    final refreshedContinueWatching = baseData.continueWatching
        .where(
          (item) => item.source != videoInfo.source || item.id != videoInfo.id,
        )
        .toList();
    final refreshedHistory = baseData.history
        .where(
          (item) => item.source != videoInfo.source || item.id != videoInfo.id,
        )
        .take(60)
        .toList();

    setState(() {
      _continueWatchingRefreshVersion++;
      _setHomeSectionSnapshot(
        _TvHomeSectionKey.continueWatching,
        refreshedContinueWatching,
        isLoading: false,
      );
      _setHomeSectionSnapshot(
        _TvHomeSectionKey.history,
        refreshedHistory,
        isLoading: false,
      );
      _syncLastResolvedHomeData();
    });
  }

  /// 切换到指定顶部菜单。
  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() {
      _homeExitConfirmArmed = false;
      _outgoingTabIndex = _selectedIndex;
      _tabSwitchDirection = index > _selectedIndex ? 1 : -1;
      _selectedIndex = index;
      _categoryFilterVisible = false;
      _categoryFilterCompact = false;
      _categoryFilterPreferredFocusRowTitle = null;
    });
    _tabSwitchController.forward(from: 0);
  }

  /// 清理首页根级退出确认武装态。
  ///
  /// 用户重新进入内容区、切换标签或关闭弹层后，都应该重新从第一次返回开始计算。
  void _disarmHomeExitConfirm() {
    _homeExitConfirmArmed = false;
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
    final refreshHome = await TvRoute.push<bool>(context, detailPage);
    if (!mounted || refreshHome != true) {
      return;
    }
    await _refreshContinueWatchingOnly();
  }

  /// 打开搜索页面。
  Future<void> _openSearch() async {
    final searchPage = widget.buildSearchPage?.call() ?? const TvSearchScreen();
    await _openQuickPageAndRefreshContinueWatching(searchPage);
  }

  /// 打开播放历史页面。
  Future<void> _openHistory() async {
    final historyPage = widget.buildHistoryPage?.call() ??
        TvHistoryScreen(
          buildDetailPage: (videoInfo) =>
              widget.buildDetailPage?.call(videoInfo, null) ??
              TvVideoDetailScreen(videoInfo: videoInfo),
        );
    await _openQuickPageAndRefreshContinueWatching(historyPage);
  }

  /// 打开收藏夹页面。
  Future<void> _openFavorites() async {
    final favoritesPage = widget.buildFavoritesPage?.call() ??
        TvFavoritesScreen(
          buildDetailPage: (videoInfo) =>
              widget.buildDetailPage?.call(videoInfo, null) ??
              TvVideoDetailScreen(videoInfo: videoInfo),
        );
    await _openQuickPageAndRefreshContinueWatching(favoritesPage);
  }

  /// 打开设置页面。
  Future<void> _openSettings() async {
    final settingsPage =
        widget.buildSettingsPage?.call() ?? const TvSettingsScreen();
    await _openQuickPageAndRefreshContinueWatching(settingsPage);
  }

  /// 统一打开顶部快捷入口对应的独立页面。
  Future<T?> _pushQuickPage<T extends Object?>(Widget page) {
    return TvRoute.push<T>(context, page);
  }

  /// 打开右上角快捷页，并在返回首页后刷新继续观看。
  ///
  /// 搜索、播放历史、收藏夹和设置都可能改动播放记录或登录态，
  /// 因此返回首页后统一只刷新“继续观看”和历史快照，不重刷热门分区。
  Future<void> _openQuickPageAndRefreshContinueWatching(Widget page) async {
    await _pushQuickPage<Object?>(page);
    if (!mounted) {
      return;
    }
    await _refreshContinueWatchingOnly();
  }

  /// 只刷新首页“继续观看”和历史快照。
  ///
  /// 详情页返回时保留首页现有热门分区，避免整页重新进入骨架屏。
  Future<void> _refreshContinueWatchingOnly() async {
    final requestVersion = ++_continueWatchingRefreshVersion;
    final loader = widget.loadContinueWatching ??
        widget.loadHomePlayRecords ??
        TvHomeScreen.defaultLoadContinueWatching;

    List<VideoInfo> refreshedPlayRecordVideos;
    try {
      refreshedPlayRecordVideos = await loader(context);
    } catch (_) {
      return;
    }

    if (!mounted || requestVersion != _continueWatchingRefreshVersion) {
      return;
    }

    final refreshedContinueWatching =
        TvHomeScreen._buildContinueWatchingVideos(refreshedPlayRecordVideos);
    final refreshedHistory =
        TvHomeScreen._buildHistoryVideos(refreshedPlayRecordVideos);

    setState(() {
      _setHomeSectionSnapshot(
        _TvHomeSectionKey.continueWatching,
        refreshedContinueWatching,
        isLoading: false,
      );
      _setHomeSectionSnapshot(
        _TvHomeSectionKey.history,
        refreshedHistory,
        isLoading: false,
      );
      // 刷新后只要真的拿到了继续观看数据，就立即恢复分区显示，
      // 避免首页还停留在旧的隐藏态，导致用户误以为记录被清空。
      if (refreshedContinueWatching.isNotEmpty) {
        _showContinueWatchingSection = true;
      }
      _syncLastResolvedHomeData();
    });
  }
}
