// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_home_screen.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/widgets/tv_category_filter_panel.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(1920, 1080);
    binding.window.devicePixelRatioTestValue = 1;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  test('TV video grid keeps focus overflow visible', () {
    expect(TvVideoGrid.focusSafePadding, 12);
  });

  test('TV layout uses compact page padding and fixed grid columns', () {
    expect(TvLayout.pageHorizontalPadding, 36);
    expect(TvLayout.gridCrossAxisCount, 7);
  });

  testWidgets('renders TV home tabs and homepage sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-top-nav-action-search')),
      findsOneWidget,
    );
    final homeNavDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('tv-top-nav-visible')),
    );
    expect(
      (homeNavDecoration.decoration as BoxDecoration).color,
      Colors.transparent,
    );
    expect(find.byKey(const ValueKey('tv-home-content-clip')), findsOneWidget);
    expect(find.text('电影'), findsOneWidget);
    expect(find.text('剧集'), findsOneWidget);
    expect(find.text('动漫'), findsOneWidget);
    expect(find.text('综艺'), findsOneWidget);
    expect(find.text('直播'), findsOneWidget);
    expect(find.text('播放历史'), findsOneWidget);
    expect(find.text('收藏夹'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('热门电影'), findsOneWidget);
    expect(find.text('热门剧集'), findsOneWidget);
    expect(find.text('新番放送'), findsOneWidget);
    expect(find.text('热门综艺'), findsOneWidget);
  });

  testWidgets('opens search screen from top nav search icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
          buildSearchPage: () => const Scaffold(
            body: Text('TV 搜索页已打开'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-search')));
    await tester.pumpAndSettle();

    expect(find.text('TV 搜索页已打开'), findsOneWidget);
  });

  testWidgets('renders history and favorites as vertical grids',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: const [],
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: List.generate(
              8,
              (index) => _videoInfo('history_$index', '历史 $index'),
            ),
            favorites: List.generate(
              8,
              (index) => _videoInfo('favorite_$index', '收藏 $index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _tapTopNavLabel(tester, '播放历史');
    await tester.pumpAndSettle();

    final historyGrid = find.byKey(const ValueKey('tv-video-grid'));
    final historyScroll = find.byKey(const ValueKey('tv-video-grid-scroll'));
    expect(historyGrid, findsOneWidget);
    expect(historyScroll, findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(historyScroll).scrollDirection,
      Axis.vertical,
    );
    expect(
      tester.widget<CustomScrollView>(historyScroll).clipBehavior,
      Clip.none,
    );
    expect(
      find.descendant(
        of: historyScroll,
        matching: find.text('播放历史'),
      ),
      findsOneWidget,
    );
    expect(find.text('历史 0'), findsOneWidget);

    await _tapTopNavLabel(tester, '收藏夹');
    await tester.pumpAndSettle();

    final favoritesGrid = find.byKey(const ValueKey('tv-video-grid'));
    final favoritesScroll = find.byKey(const ValueKey('tv-video-grid-scroll'));
    expect(favoritesGrid, findsOneWidget);
    expect(favoritesScroll, findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(favoritesScroll).scrollDirection,
      Axis.vertical,
    );
    expect(
      find.descendant(
        of: favoritesScroll,
        matching: find.text('收藏夹'),
      ),
      findsOneWidget,
    );
    expect(find.text('收藏 0'), findsOneWidget);
  });

  testWidgets('renders category tabs as vertical grids', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              4,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: List.generate(
              4,
              (index) => _videoInfo('series_$index', '剧集 $index'),
            ),
            bangumiCalendar: List.generate(
              4,
              (index) => _videoInfo('anime_$index', '动漫 $index'),
            ),
            hotShows: List.generate(
              4,
              (index) => _videoInfo('variety_$index', '综艺 $index'),
            ),
            history: const [],
            favorites: const [],
          ),
          loadCategoryData: (_, __, filters) async {
            final year = filters['年份']?.label ?? '全部';
            return [_videoInfo('movie_filtered', '筛选后 $year')];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-video-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-category-grid-clip')), findsOneWidget);
    final categoryNavDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('tv-top-nav-visible')),
    );
    expect(
      (categoryNavDecoration.decoration as BoxDecoration).color,
      const Color(0xD00B0D0E),
    );
    expect(find.text('电影 0'), findsOneWidget);

    await _tapTopNavLabel(tester, '剧集');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-video-grid')), findsOneWidget);
    expect(find.text('剧集 0'), findsOneWidget);

    await _tapTopNavLabel(tester, '动漫');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-video-grid')), findsOneWidget);
    expect(find.text('动漫 0'), findsOneWidget);

    await _tapTopNavLabel(tester, '综艺');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-video-grid')), findsOneWidget);
    expect(find.text('综艺 0'), findsOneWidget);
  });

  testWidgets(
      'shows category filter panel only from focused category top nav item',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              4,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);

    _focusNodeForText(tester, '筛选后 2025').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);

    _focusNodeForText(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsNothing);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('tv-category-filter-panel')),
          )
          .color,
      const Color(0xD00B0D0E),
    );
    expect(find.text('排序:'), findsOneWidget);
    expect(find.text('类型:'), findsOneWidget);
    expect(find.text('地区:'), findsOneWidget);
    expect(find.text('年份:'), findsOneWidget);
    expect(find.text('全部'), findsWidgets);
    expect(
      tester
          .widget<ListView>(find.byKey(const ValueKey('tv-filter-row-类型')))
          .scrollDirection,
      Axis.horizontal,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);
  });

  testWidgets('live top nav item is only a quick action bridge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForText(tester, '直播').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);
    expect(_focusNodeForAction(tester, 'search').hasFocus, isTrue);
  });

  testWidgets('grid edge cards keep feedback wrapper without blocking top',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvVideoGrid(
            title: '电影',
            videos: [_videoInfo('movie_0', '电影 0')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsOneWidget);
  });

  testWidgets('category filter rows clip options and keep edge focus',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvCategoryFilterPanel(kind: TvCategoryFilterKind.movie),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final typeListView = tester.widget<ListView>(
      find.byKey(const ValueKey('tv-filter-row-类型')),
    );
    expect(typeListView.clipBehavior, Clip.hardEdge);
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);

    final scoreFocusNode = _focusNodeForText(tester, '评分');
    scoreFocusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(scoreFocusNode.hasFocus, isTrue);
  });

  testWidgets('selecting category filter refreshes current grid data',
      (tester) async {
    var queryCount = 0;
    Map<String, TvCategoryFilterOption> capturedFilters = {};

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: [_videoInfo('movie_initial', '初始电影')],
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
          loadCategoryData: (_, kind, filters) async {
            queryCount++;
            capturedFilters = Map<String, TvCategoryFilterOption>.from(filters);
            return [_videoInfo('movie_filtered', '筛选后电影')];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();
    expect(find.text('初始电影'), findsOneWidget);

    _focusNodeForText(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _focusNodeForText(tester, '犯罪').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(queryCount, 1);
    expect(capturedFilters['类型']?.label, '犯罪');
    expect(find.text('筛选后电影'), findsOneWidget);
    expect(find.text('初始电影'), findsNothing);
  });

  testWidgets('category filter compacts after focus enters grid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              4,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    _focusNodeForText(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-category-filter-panel')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('tv-category-filter-summary')), findsNothing);

    _focusNodeForText(tester, '电影 0').requestFocus();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-category-filter-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-panel')),
      findsNothing,
    );
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('排序:'), findsNothing);
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-排序')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-类型')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-地区')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-年份')),
      findsOneWidget,
    );
  });

  testWidgets('focus returns to selected year chip when moving up from grid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              8,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    _focusNodeForText(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tv-filter-chip-2025')).first,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    _focusNodeForText(tester, '电影 0').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-2025')).hasFocus,
      isTrue,
    );
  });

  testWidgets('category filter expanded chips use compact sizing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvCategoryFilterPanel(kind: TvCategoryFilterKind.movie),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final chipSize = tester.getSize(
      find
          .ancestor(
            of: find.text('全部').first,
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(chipSize.height, 44);
    expect(chipSize.width, greaterThanOrEqualTo(44));
    expect(chipSize.width, lessThanOrEqualTo(76));
    expect(
      find.byKey(const ValueKey('tv-filter-row-more-indicator-排序')),
      findsNothing,
    );
  });

  testWidgets('category filter chips use faster directional repeat throttle',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvCategoryFilterPanel(kind: TvCategoryFilterKind.movie),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final focusable = tester.widget<TvFocusable>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tv-filter-chip-全部')).first,
            matching: find.byType(TvFocusable),
          )
          .first,
    );

    expect(
      focusable.directionalRepeatThrottleDuration,
      const Duration(milliseconds: 80),
    );
  });

  testWidgets('uses cover size for grid loading skeletons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvVideoGrid(
            title: '电影',
            videos: [],
            isLoading: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getSize(
          find.byKey(const ValueKey('tv-video-grid-loading-card')).first),
      const Size(158, 237),
    );
  });

  testWidgets('opens TV detail screen when video card is selected',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: [_videoInfo('continue_1', '继续观看影片')],
            hotMovies: const [],
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
          buildDetailPage: (_, __) => const Scaffold(
            body: Text('TV 详情页已打开'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('继续观看影片'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('TV 详情页已打开'), findsOneWidget);
  });

  testWidgets('home section more card jumps to matching top category',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              16,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('热门电影'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('tv-home-section-list-热门电影')),
      const Offset(-2800, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看更多'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-video-grid')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-video-grid-scroll')),
        matching: find.text('电影'),
      ),
      findsOneWidget,
    );
    expect(find.text('电影 0'), findsOneWidget);
  });
}

Future<void> _tapTopNavLabel(WidgetTester tester, String label) async {
  final finder = find.text(label).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
}

FocusNode _focusNodeForText(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForAction(WidgetTester tester, String key) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-top-nav-action-$key')),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForKey(WidgetTester tester, Key key) {
  final focusFinder = find.ancestor(
    of: find.byKey(key),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

VideoInfo _videoInfo(String id, String title) {
  return VideoInfo(
    id: id,
    source: 'test',
    title: title,
    sourceName: '测试源',
    year: '2026',
    cover: '',
    index: 1,
    totalEpisodes: 1,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: title,
  );
}
