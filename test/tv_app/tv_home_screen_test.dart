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

  testWidgets('home top nav down restores remembered continue watching card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: List.generate(
              6,
              (index) => _videoInfo('continue_$index', '继续 $index'),
            ),
            hotMovies: List.generate(
              6,
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
    _focusNodeForVideoCard(tester, 'continue_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'continue_3').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);
  });

  testWidgets('home top nav down restores remembered home section focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              6,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: List.generate(
              6,
              (index) => _videoInfo('series_$index', '剧集 $index'),
            ),
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForVideoCard(tester, 'series_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'series_3').hasFocus, isTrue);
  });

  testWidgets('escape from home list focuses selected home top nav tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: [_videoInfo('continue_0', '继续 0')],
            hotMovies: List.generate(
              6,
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
    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_focusNodeForTopNavLabel(tester, '首页').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'continue_0').hasFocus, isFalse);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);
  });

  testWidgets('quick action down returns to selected tab before home cards',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: [_videoInfo('continue_0', '继续 0')],
            hotMovies: List.generate(
              6,
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
    _focusNodeForAction(tester, 'history').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForTopNavLabel(tester, '首页').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'continue_0').hasFocus, isFalse);
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

  testWidgets('opens history page from top nav quick action', (tester) async {
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
          buildHistoryPage: () => const Scaffold(
            body: Text('TV 播放历史页已打开'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-history')));
    await tester.pumpAndSettle();

    expect(find.text('TV 播放历史页已打开'), findsOneWidget);
  });

  testWidgets('opens favorites page from top nav quick action', (tester) async {
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
          buildFavoritesPage: () => const Scaffold(
            body: Text('TV 收藏夹页已打开'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-favorites')));
    await tester.pumpAndSettle();

    expect(find.text('TV 收藏夹页已打开'), findsOneWidget);
  });

  testWidgets('opens settings page from top nav quick action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
          buildSettingsPage: () => const Scaffold(
            body: Text('TV 设置页已打开'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-settings')));
    await tester.pumpAndSettle();

    expect(find.text('TV 设置页已打开'), findsOneWidget);
  });

  testWidgets('settings quick action blocks right key and keeps focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);

    _focusNodeForAction(tester, 'settings').requestFocus();
    await tester.pumpAndSettle();
    expect(_focusNodeForAction(tester, 'settings').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));

    expect(_focusNodeForAction(tester, 'settings').hasFocus, isTrue);
  });

  testWidgets('renders live tab as developing placeholder page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _tapTopNavLabel(tester, '直播');
    await tester.pumpAndSettle();

    expect(find.text('正在开发'), findsOneWidget);
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
          loadCategoryData: (_, __, filters, ___) async {
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

  testWidgets('animates top tab content with page-like horizontal slide',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: [_videoInfo('movie_0', '电影 0')],
            hotTvShows: [_videoInfo('series_0', '剧集 0')],
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

    await _tapTopNavLabel(tester, '剧集');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('电影 0'), findsOneWidget);
    expect(find.text('剧集 0'), findsOneWidget);
    expect(_slideOffsetForText(tester, '电影 0').dx, lessThan(-0.1));
    expect(_slideOffsetForText(tester, '剧集 0').dx, greaterThan(0.1));
  });

  testWidgets(
      'shows category filter panel only from selected category top nav confirm action',
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

    _focusNodeForVideoCard(tester, 'movie_0').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-top-nav-visible')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-category-filter-panel')), findsNothing);
    expect(_focusNodeForAction(tester, 'search').hasFocus, isTrue);

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
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

  testWidgets('live top nav item still moves to quick actions on up key',
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

  testWidgets('category top nav item up moves to quick actions',
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

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
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

  testWidgets('vertical grid loads more when focus reaches second last row',
      (tester) async {
    var loadMoreCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvVideoGrid(
            title: '电影',
            videos: List.generate(
              21,
              (index) => _videoInfo('grid_$index', '电影 $index'),
            ),
            hasMore: true,
            onLoadMore: () => loadMoreCount++,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForVideoCard(tester, 'grid_0').requestFocus();
    await tester.pumpAndSettle();
    expect(loadMoreCount, 0);

    _focusNodeForVideoCard(tester, 'grid_7').requestFocus();
    await tester.pumpAndSettle();
    expect(loadMoreCount, 1);

    _focusNodeForVideoCard(tester, 'grid_8').requestFocus();
    await tester.pumpAndSettle();
    expect(loadMoreCount, 1);
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
          loadCategoryData: (_, kind, filters, page) async {
            queryCount++;
            capturedFilters = Map<String, TvCategoryFilterOption>.from(filters);
            expect(page, 0);
            return [_videoInfo('movie_filtered', '筛选后电影')];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();
    expect(find.text('初始电影'), findsOneWidget);

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-犯罪'))
        .requestFocus();
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

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-category-filter-panel')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('tv-category-filter-summary')), findsNothing);

    _focusNodeForGridVideoCard(tester, 'movie_0').requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

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

  testWidgets(
      'category top nav down restores remembered card after filter closes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              21,
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

    _focusNodeForVideoCard(tester, 'movie_10').requestFocus();
    await tester.pump();
    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 380));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 380));

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(_focusNodeForVideoCard(tester, 'movie_10').hasFocus, isTrue);
  });

  testWidgets('escape from category grid focuses selected top nav tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              14,
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

    _focusNodeForVideoCard(tester, 'movie_10').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(_focusNodeForTopNavLabel(tester, '电影').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_10').hasFocus, isFalse);
  });

  testWidgets('escape from category filter focuses selected top nav tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              14,
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

    _focusNodeForVideoCard(tester, 'movie_0').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-category-filter-panel')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-category-filter-panel')),
      findsNothing,
    );
    expect(_focusNodeForTopNavLabel(tester, '电影').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isFalse);
  });

  testWidgets('category filter down moves to next filter row before cards',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              14,
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

    _focusNodeForVideoCard(tester, 'movie_0').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(
      _rowHasFocusedChip(tester, '排序'),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '类型'), isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '地区'), isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '年份'), isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isFalse);
  });

  testWidgets('selected category filter chip keeps focus after refresh',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              14,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
          loadCategoryData: (_, __, filters, ___) async {
            final region = filters['地区']?.label ?? '全部';
            return [_videoInfo('filtered_$region', '筛选后 $region')];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-香港'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('筛选后 香港'), findsOneWidget);
    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-香港')).hasFocus,
      isTrue,
    );
    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部')).hasFocus,
      isFalse,
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
          loadCategoryData: (_, __, filters, ___) async {
            final year = filters['年份']?.label ?? '全部';
            return [_videoInfo('filtered_$year', '筛选后 $year')];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    _focusNodeForTopNavLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tv-filter-chip-2025')).first,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    _focusNodeForVideoCard(tester, 'filtered_2025').requestFocus();
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

    final chipWidget = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('tv-filter-chip-全部')).first,
    );
    expect(
      chipWidget.constraints,
      const BoxConstraints(minWidth: 38, maxWidth: 72, minHeight: 30),
    );
    expect(
      chipWidget.padding,
      const EdgeInsets.symmetric(horizontal: 2),
    );
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

  testWidgets('category grid shows confirm hint beside title', (tester) async {
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

    expect(find.text('按确认键打开分类筛选'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-video-grid-title-hint')), findsOneWidget);
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

  testWidgets('category grid appends next page near bottom second last row',
      (tester) async {
    final requestedPages = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              21,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: const [],
            favorites: const [],
          ),
          loadCategoryData: (_, __, ___, page) async {
            requestedPages.add(page);
            return List.generate(
              7,
              (index) => _videoInfo(
                'movie_page_${page}_$index',
                '第$page页电影 $index',
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _tapTopNavLabel(tester, '电影');
    await tester.pumpAndSettle();

    _focusNodeForVideoCard(tester, 'movie_7').requestFocus();
    await tester.pump();
    await tester.pump();

    expect(requestedPages, [1]);
    final categoryGrid = tester.widget<TvVideoGrid>(
      find.byType(TvVideoGrid).first,
    );
    expect(
      categoryGrid.videos.map((video) => video.title),
      contains('第1页电影 0'),
    );
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

Offset _slideOffsetForText(WidgetTester tester, String label) {
  final slideFinder = find.ancestor(
    of: find.text(label),
    matching: find.byType(SlideTransition),
  );
  return tester.widget<SlideTransition>(slideFinder.first).position.value;
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

FocusNode _focusNodeForTopNavLabel(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForVideoCard(WidgetTester tester, String id) {
  return _focusNodeForFocusableKey(
    tester,
    ValueKey('tv-video-card-focus-$id'),
  );
}

FocusNode _focusNodeForGridVideoCard(WidgetTester tester, String id) {
  return _focusNodeForFocusableKey(
    tester,
    ValueKey('tv-video-card-focus-$id'),
  );
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

bool _rowHasFocusedChip(WidgetTester tester, String rowTitle) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-filter-row-$rowTitle')),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode?.hasFocus == true,
    ),
  );
  return focusFinder.evaluate().isNotEmpty;
}

FocusNode _focusNodeForFocusableKey(WidgetTester tester, Key key) {
  final focusFinder = find.descendant(
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
