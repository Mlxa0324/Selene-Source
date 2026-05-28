// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_home_screen.dart';
import 'package:selene/tv_app/screens/tv_history_screen.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_category_filter_panel.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_home_section.dart';
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

  test('TV category filters mirror mobile filter option sets', () {
    expect(
      _rowLabels(TvCategoryFilterKind.movie),
      ['分类', '地区'],
    );
    expect(
      _optionLabels(TvCategoryFilterKind.movie, '分类'),
      ['全部', '热门电影', '最新电影', '豆瓣高分', '冷门佳片'],
    );
    expect(
      _optionLabels(TvCategoryFilterKind.movie, '地区'),
      ['全部', '华语', '欧美', '韩国', '日本'],
    );
    expect(
      _rowLabels(
        TvCategoryFilterKind.movie,
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      ['分类', '类型', '地区', '年代', '平台', '排序'],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.movie,
        '类型',
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      containsAll([
        '恐怖',
        '战争',
        '传记',
        '歌舞',
        '武侠',
        '情色',
        '灾难',
        '西部',
        '纪录片',
        '短片',
      ]),
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.movie,
        '平台',
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      [
        '全部',
        '腾讯视频',
        '爱奇艺',
        '优酷',
        '湖南卫视',
        'Netflix',
        'HBO',
        'BBC',
        'NHK',
        'CBS',
        'NBC',
        'tvN'
      ],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.movie,
        '排序',
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      ['综合排序', '近期热度', '首映时间', '高分优先'],
    );

    expect(
      _optionLabels(TvCategoryFilterKind.series, '类型'),
      ['全部', '国产', '欧美', '日本', '韩国', '动漫', '纪录片'],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.series,
        '类型',
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      containsAll([
        '恐怖',
        '历史',
        '战争',
        '动作',
        '冒险',
        '传记',
        '剧情',
        '奇幻',
        '惊悚',
        '灾难',
        '歌舞',
        '音乐'
      ]),
    );

    expect(
      _optionLabels(TvCategoryFilterKind.variety, '类型'),
      ['全部', '国内', '国外'],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.variety,
        '类型',
        category: const TvCategoryFilterOption(label: '全部', value: '全部'),
      ),
      ['全部', '真人秀', '脱口秀', '音乐', '歌舞'],
    );

    expect(
      _rowLabels(TvCategoryFilterKind.anime),
      ['分类', '星期'],
    );
    expect(
      _optionLabels(TvCategoryFilterKind.anime, '分类'),
      ['每日放送', '番剧', '剧场版'],
    );
    expect(
      _optionLabels(TvCategoryFilterKind.anime, '星期'),
      ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
    );
    expect(
      _rowLabels(
        TvCategoryFilterKind.anime,
        category: const TvCategoryFilterOption(label: '番剧', value: '番剧'),
      ),
      ['分类', '类型', '地区', '年代', '平台', '排序'],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.anime,
        '类型',
        category: const TvCategoryFilterOption(label: '番剧', value: '番剧'),
      ),
      [
        '全部',
        '黑色幽默',
        '历史',
        '歌舞',
        '励志',
        '恶搞',
        '治愈',
        '运动',
        '后宫',
        '情色',
        '国漫',
        '人性',
        '悬疑',
        '恋爱',
        '魔幻',
        '科幻'
      ],
    );
    expect(
      _rowLabels(
        TvCategoryFilterKind.anime,
        category: const TvCategoryFilterOption(label: '剧场版', value: '剧场版'),
      ),
      ['分类', '类型', '地区', '年代', '排序'],
    );
    expect(
      _optionLabels(
        TvCategoryFilterKind.anime,
        '类型',
        category: const TvCategoryFilterOption(label: '剧场版', value: '剧场版'),
      ),
      [
        '全部',
        '定格动画',
        '传记',
        '美国动画',
        '爱情',
        '黑色幽默',
        '歌舞',
        '儿童',
        '二次元',
        '动物',
        '青春',
        '历史',
        '励志',
        '恶搞',
        '治愈',
        '运动',
        '后宫',
        '情色',
        '人性',
        '悬疑',
        '恋爱',
        '魔幻',
        '科幻'
      ],
    );
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

    expect(_focusNodeForVideoCard(tester, 'continue_0').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'continue_3').hasFocus, isFalse);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);

    _focusNodeForVideoCard(tester, 'continue_3').requestFocus();
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

    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);

    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
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

  testWidgets('home top nav down initially focuses first item in first non empty section',
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

    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);
  });

  testWidgets('home top nav down restores remembered focus after first manual browse',
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
    _focusNodeForTopNavLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isTrue);

    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isTrue);
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

  testWidgets('escape from quick action returns to source top nav tab',
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
    await _tapTopNavLabel(tester, '剧集');
    await tester.pumpAndSettle();
    _focusNodeForTopNavLabel(tester, '剧集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForAction(tester, 'search').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_focusNodeForTopNavLabel(tester, '剧集').hasFocus, isTrue);
    expect(_focusNodeForAction(tester, 'search').hasFocus, isFalse);
    expect(_focusNodeForVideoCard(tester, 'series_0').hasFocus, isFalse);
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

  testWidgets('history page return refreshes home continue watching data',
      (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async {
            loadCount++;
            return TvHomeData(
              continueWatching: [
                _videoInfo('continue_$loadCount', '继续 $loadCount'),
              ],
              hotMovies: const [],
              hotTvShows: const [],
              bangumiCalendar: const [],
              hotShows: const [],
              history: const [],
              favorites: const [],
            );
          },
          buildHistoryPage: () => TvHistoryScreen(
            loadVideos: (_) async => [
              _videoInfo('history_1', '历史 1'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('继续 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tv-top-nav-action-history')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('继续 2'), findsOneWidget);
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

  testWidgets('quick action keeps stable frame when focus changes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData.empty(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final actionFinder = find.byKey(
      const ValueKey('tv-top-nav-action-history'),
    );
    final unfocusedRect = tester.getRect(actionFinder);

    _focusNodeForAction(tester, 'history').requestFocus();
    await tester.pumpAndSettle();

    final focusedRect = tester.getRect(actionFinder);
    expect(focusedRect.left, unfocusedRect.left);
    expect(focusedRect.width, unfocusedRect.width);
    expect(focusedRect.height, unfocusedRect.height);
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
            final year = filters['年代']?.label ?? '全部';
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
    expect(find.text('分类:'), findsOneWidget);
    expect(find.text('排序:'), findsNothing);
    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('排序:'), findsOneWidget);
    expect(find.text('类型:'), findsOneWidget);
    expect(find.text('地区:'), findsOneWidget);
    expect(find.text('年代:'), findsOneWidget);
    expect(find.text('平台:'), findsOneWidget);
    expect(find.text('全部'), findsWidgets);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('tv-filter-row-scroll-类型')),
          )
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
          body: TvCategoryFilterPanel(
            kind: TvCategoryFilterKind.movie,
            selectedOptions: {
              '分类': TvCategoryFilterOption(label: '全部', value: '全部'),
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final typeScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('tv-filter-row-scroll-类型')),
    );
    expect(typeScrollView.clipBehavior, Clip.hardEdge);
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);

    final scoreFocusNode = _focusNodeForText(tester, '高分优先');
    scoreFocusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(scoreFocusNode.hasFocus, isTrue);
  });

  testWidgets(
      'category filter vertical move remembers last chip and falls back to nearest chip',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvCategoryFilterPanel(
            kind: TvCategoryFilterKind.movie,
            selectedOptions: {
              '分类': TvCategoryFilterOption(label: '全部', value: '全部'),
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    _focusNodeForChipInRow(tester, '地区', '意大利').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '类型'), isTrue);
    expect(_focusedChipLabelInRow(tester, '类型'), isNot('全部'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForChipInRow(tester, '地区', '意大利').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      _focusedChipLabelInRow(tester, '类型'),
      isNot('全部'),
    );
  });

  testWidgets('category filter reveals rightmost chip inside row viewport',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvCategoryFilterPanel(
            kind: TvCategoryFilterKind.movie,
            selectedOptions: {
              '分类': TvCategoryFilterOption(label: '全部', value: '全部'),
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    _focusNodeForChipInRow(tester, '地区', '丹麦').requestFocus();
    await tester.pumpAndSettle();

    final rowRect = tester.getRect(
      find.byKey(const ValueKey('tv-filter-row-scroll-地区')),
    );
    final chipRect = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-filter-row-地区')),
        matching: find.byKey(const ValueKey('tv-filter-chip-丹麦')),
      ),
    );

    expect(chipRect.right, lessThanOrEqualTo(rowRect.right - 1));
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
    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    queryCount = 0;
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
      find.byKey(const ValueKey('tv-category-filter-summary-分类')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-地区')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-category-filter-summary-类型')),
      findsNothing,
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
          loadCategoryData: (_, __, ___, ____) async => [
            _videoInfo('movie_0', '电影 0'),
          ],
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

    expect(_rowHasFocusedChip(tester, '分类'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '地区'), isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isFalse);

    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '类型'), isTrue);
    expect(_rowHasFocusedChip(tester, '分类'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '地区'), isTrue);
    expect(_rowHasFocusedChip(tester, '类型'), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_rowHasFocusedChip(tester, '年代'), isTrue);
    expect(_rowHasFocusedChip(tester, '地区'), isFalse);
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
            final platform = filters['平台']?.label ?? '全部';
            return [_videoInfo('filtered_$platform', '筛选后 $platform')];
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

    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-Netflix'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('筛选后 Netflix'), findsOneWidget);
    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-Netflix'))
          .hasFocus,
      isTrue,
    );
    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部')).hasFocus,
      isFalse,
    );
  });

  testWidgets('focus returns to bottom filter row when moving up from grid',
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
            final sort = filters['排序']?.label ?? '综合排序';
            return [_videoInfo('filtered_$sort', '筛选后 $sort')];
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

    _focusNodeForKey(tester, const ValueKey('tv-filter-chip-全部'))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tv-filter-chip-近期热度')).first,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    _focusNodeForVideoCard(tester, 'filtered_近期热度').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      _focusNodeForKey(tester, const ValueKey('tv-filter-chip-近期热度')).hasFocus,
      isTrue,
    );
    expect(_rowHasFocusedChip(tester, '排序'), isTrue);
    expect(_rowHasFocusedChip(tester, '年代'), isFalse);
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

  testWidgets('category grid keeps page right padding for video list',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: const [],
            hotMovies: List.generate(
              7,
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

    final categoryGrid = tester.widget<TvVideoGrid>(find.byType(TvVideoGrid));
    expect(categoryGrid.rightPadding, TvLayout.pageHorizontalPadding);
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

  testWidgets('continue watching shows long press delete hint',
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
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('长按删除'), findsOneWidget);
  });

  testWidgets('continue hint matches category hint font size and vertical slot',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvHomeSection(
                title: '继续观看',
                titleHint: '长按删除',
                videos: [_videoInfo('continue_1', '继续观看影片')],
              ),
              const Expanded(
                child: TvVideoGrid(
                  title: '电影',
                  titleHint: '按确认键打开分类筛选',
                  videos: [],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final continueHintText = tester.widget<Text>(find.text('长按删除'));
    final categoryHintText = tester.widget<Text>(
      find.byKey(const ValueKey('tv-video-grid-title-hint')),
    );
    final continueTitleBottom =
        tester.getBottomLeft(find.text('继续观看')).dy;
    final continueHintBottom = tester.getBottomLeft(find.text('长按删除')).dy;
    final categoryTitleBottom = tester.getBottomLeft(find.text('电影')).dy;
    final categoryHintBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('tv-video-grid-title-hint')))
        .dy;

    // 首页“继续观看”和分类页提示需要共用同一字号，避免右侧提示观感不一致。
    expect(
      continueHintText.style?.fontSize,
      categoryHintText.style?.fontSize,
    );
    // 两类标题右侧提示都要落在同一时间槽位，保持标题行上下对齐手感一致。
    expect(
      categoryTitleBottom - categoryHintBottom,
      closeTo(continueTitleBottom - continueHintBottom, 0.1),
    );
  });

  testWidgets('continue watching card long press deletes current item',
      (tester) async {
    var records = <VideoInfo>[
      _videoInfo('continue_1', '继续观看影片 1'),
      _videoInfo('continue_2', '继续观看影片 2'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async => TvHomeData(
            continueWatching: records,
            hotMovies: const [],
            hotTvShows: const [],
            bangumiCalendar: const [],
            hotShows: const [],
            history: records,
            favorites: const [],
          ),
          deleteContinueWatchingItem: (_, videoInfo) async {
            records = records
                .where(
                  (item) =>
                      item.source != videoInfo.source || item.id != videoInfo.id,
                )
                .toList();
            return true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final focusNode = _focusNodeForVideoCard(tester, 'continue_1');
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    expect(find.text('删除继续观看'), findsOneWidget);
    expect(find.text('确定要删除这条继续观看记录吗？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('继续观看影片 1'), findsNothing);
    expect(find.text('继续观看影片 2'), findsOneWidget);
    expect(_focusNodeForVideoCard(tester, 'continue_2').hasFocus, isTrue);
  });

  testWidgets(
      'deleting continue watching keeps existing hot sections visible while local record refreshes',
      (tester) async {
    var records = <VideoInfo>[
      _videoInfo('continue_1', '继续观看影片 1'),
      _videoInfo('continue_2', '继续观看影片 2'),
    ];
    var loadCount = 0;
    final delayedHotMoviesCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: TvHomeScreen(
          loadHomeData: (_) async {
            loadCount++;
            if (loadCount == 1) {
              return TvHomeData(
                continueWatching: records,
                hotMovies: [_videoInfo('movie_1', '热门电影 1')],
                hotTvShows: const [],
                bangumiCalendar: const [],
                hotShows: const [],
                history: records,
                favorites: const [],
              );
            }

            await delayedHotMoviesCompleter.future;
            return TvHomeData(
              continueWatching: records,
              hotMovies: [_videoInfo('movie_1', '热门电影 1')],
              hotTvShows: const [],
              bangumiCalendar: const [],
              hotShows: const [],
              history: records,
              favorites: const [],
            );
          },
          deleteContinueWatchingItem: (_, videoInfo) async {
            records = records
                .where(
                  (item) =>
                      item.source != videoInfo.source || item.id != videoInfo.id,
                )
                .toList();
            return true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('热门电影 1'), findsOneWidget);

    final focusNode = _focusNodeForVideoCard(tester, 'continue_1');
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('热门电影 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-home-loading-card')), findsNothing);

    delayedHotMoviesCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('继续观看影片 1'), findsNothing);
    expect(find.text('继续观看影片 2'), findsOneWidget);
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

  testWidgets('root back shows exit confirm dialog and confirms before exit',
      (tester) async {
    final platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TvBackHandler(
          autofocus: true,
          child: TvHomeScreen(
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
      ),
    );

    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('确定退出 IvyTV？'), findsNothing);
    expect(_focusNodeForTopNavLabel(tester, '首页').hasFocus, isTrue);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('确定退出 IvyTV？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );
    expect(_focusNodeForText(tester, '取消').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('确定退出 IvyTV？'), findsNothing);
    expect(
      platformCalls.where((call) => call.method == 'SystemNavigator.pop'),
      isEmpty,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    final exitCalls =
        platformCalls.where((call) => call.method == 'SystemNavigator.pop');
    expect(exitCalls, hasLength(1));
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

List<String> _rowLabels(
  TvCategoryFilterKind kind, {
  TvCategoryFilterOption? category,
}) {
  final filters = <String, TvCategoryFilterOption>{
    if (category != null) '分类': category,
  };
  return TvCategoryFilterOptions.rowsFor(kind, filters)
      .map((row) => row.title)
      .toList();
}

List<String> _optionLabels(
  TvCategoryFilterKind kind,
  String rowTitle, {
  TvCategoryFilterOption? category,
}) {
  final filters = <String, TvCategoryFilterOption>{
    if (category != null) '分类': category,
  };
  return TvCategoryFilterOptions.rowsFor(kind, filters)
      .firstWhere((row) => row.title == rowTitle)
      .options
      .map((option) => option.label)
      .toList();
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

FocusNode _focusNodeForChipInRow(
  WidgetTester tester,
  String rowTitle,
  String label,
) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-filter-row-$rowTitle')),
    matching: find.ancestor(
      of: find.byKey(ValueKey('tv-filter-chip-$label')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Focus && widget.focusNode != null,
      ),
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

String? _focusedChipLabelInRow(WidgetTester tester, String rowTitle) {
  const allSelectedCategory = TvCategoryFilterOption(label: '全部', value: '全部');
  const animeSeriesCategory = TvCategoryFilterOption(label: '番剧', value: '番剧');
  const animeMovieCategory = TvCategoryFilterOption(label: '剧场版', value: '剧场版');
  final labels = <String>{};
  for (final kind in TvCategoryFilterKind.values) {
    for (final category in <TvCategoryFilterOption?>[
      null,
      allSelectedCategory,
      animeSeriesCategory,
      animeMovieCategory,
    ]) {
      try {
        labels.addAll(_optionLabels(kind, rowTitle, category: category));
      } on StateError {
        // 当前分类下没有这行时跳过，继续尝试其它配置。
      }
    }
  }
  for (final label in labels) {
    final chipFinder = find.descendant(
      of: find.byKey(ValueKey('tv-filter-row-$rowTitle')),
      matching: find.byKey(ValueKey('tv-filter-chip-$label')),
    );
    if (chipFinder.evaluate().isEmpty) {
      continue;
    }
    final focusFinder = find.ancestor(
      of: chipFinder.first,
      matching: find.byWidgetPredicate(
        (widget) => widget is Focus && widget.focusNode?.hasPrimaryFocus == true,
      ),
    );
    if (focusFinder.evaluate().isNotEmpty) {
      return label;
    }
  }
  return null;
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
