import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_library_screen.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

void main() {
  testWidgets('video library page keeps title away from top edge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => [
            _videoInfo('history_1', '历史影片 1'),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    final titleTopLeft = tester.getTopLeft(find.text('播放历史'));
    expect(titleTopLeft.dy, greaterThanOrEqualTo(18));
  });

  testWidgets('video library page keeps header pinned while grid scrolls',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      28,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => videos,
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final titleFinder = find.text('播放历史');
    final clearButtonFinder =
        find.byKey(const ValueKey('tv-video-library-clear-button'));
    final initialTitleTopLeft = tester.getTopLeft(titleFinder);
    final initialClearButtonTopLeft = tester.getTopLeft(clearButtonFinder);

    await tester.drag(
      find.byKey(const ValueKey('tv-video-grid-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(titleFinder).dy, initialTitleTopLeft.dy);
    expect(
      tester.getTopLeft(clearButtonFinder).dy,
      initialClearButtonTopLeft.dy,
    );
  });

  testWidgets('video grid appends next batch after focus reaches batch tail',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      12,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF10131D),
          body: SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF10131D),
          body: TvVideoGrid(
            title: '播放历史',
            videos: videos,
            crossAxisCount: 4,
            initialRenderCount: 8,
            renderBatchSize: 4,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_videoGridRenderedChildCount(tester), 8);

    final batchTailFocusNode = _focusNodeForCard(tester, 'history_7');
    batchTailFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(_videoGridRenderedChildCount(tester), 12);
  });

  testWidgets('video library page keeps first row below pinned header',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      12,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '收藏夹',
          loadVideos: (_) async => videos,
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final titleBottom = tester.getBottomLeft(find.text('收藏夹')).dy;
    final clearButtonBottom = tester
        .getBottomLeft(
            find.byKey(const ValueKey('tv-video-library-clear-button')))
        .dy;
    final firstPosterTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-video-card-focus-history_0')))
        .dy;

    expect(firstPosterTop, greaterThan(titleBottom));
    expect(firstPosterTop, greaterThan(clearButtonBottom));
  });

  testWidgets('video library page keeps first focused card outline visible',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      8,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => videos,
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstCardFocusNode = _focusNodeForCard(tester, 'history_0');
    firstCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    final titleBottom = tester.getBottomLeft(find.text('播放历史')).dy;
    final focusedCardTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-video-card-focus-history_0')))
        .dy;

    expect(focusedCardTop, greaterThan(titleBottom));
  });

  testWidgets('video library page shows header search action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => [
            _videoInfo('history_1', '历史影片 1'),
          ],
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-video-library-search-button')),
        findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
  });

  testWidgets('video library header actions use scoped theme accent',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: TvVideoLibraryScreen(
            title: '播放历史',
            loadVideos: (_) async => [
              _videoInfo('history_1', '历史影片 1'),
            ],
            onClearVideos: (_) async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 搜索按钮获焦时使用当前主题色，避免继续沿用默认 Ivy 绿。
    Focus.of(tester.element(find.text('搜索'))).requestFocus();
    await tester.pumpAndSettle();
    expect(
      _actionButtonFillColor(tester, '搜索'),
      TvThemePalette.netflixRed.accent,
    );

    // 删除全部按钮同样走当前主题色，历史页和收藏页共用这一套头部按钮。
    Focus.of(tester.element(find.text('删除全部'))).requestFocus();
    await tester.pumpAndSettle();
    expect(
      _actionButtonFillColor(tester, '删除全部'),
      TvThemePalette.netflixRed.accent,
    );
  });

  testWidgets('video library search action opens TV search screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '收藏夹',
                        loadVideos: (_) async => [
                          _videoInfo('favorite_1', '收藏影片 1'),
                        ],
                        onClearVideos: (_) async => true,
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开收藏夹页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开收藏夹页'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('tv-video-library-search-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
    expect(find.byType(TvVideoLibraryScreen), findsNothing);
  });

  testWidgets('clear button arrow down restores remembered grid focus',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      14,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => videos,
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final targetCardFocusNode = _focusNodeForCard(tester, 'history_8');
    targetCardFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(targetCardFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(targetCardFocusNode.hasFocus, isTrue);
  });

  testWidgets('header action buttons move down to remembered grid focus',
      (tester) async {
    final videos = List<VideoInfo>.generate(
      14,
      (index) => _videoInfo('history_$index', '历史影片 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoLibraryScreen(
          title: '播放历史',
          loadVideos: (_) async => videos,
          onClearVideos: (_) async => true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final targetCardFocusNode = _focusNodeForCard(tester, 'history_8');
    targetCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    for (final buttonKey in [
      const ValueKey('tv-video-library-search-button'),
      const ValueKey('tv-video-library-clear-button'),
    ]) {
      final buttonFocusNode = _focusNodeForActionButton(tester, buttonKey);
      buttonFocusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(buttonFocusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(targetCardFocusNode.hasFocus, isTrue);
    }
  });

  testWidgets('video library page moves initial focus to first card after load',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => [
                          _videoInfo('history_1', '历史影片 1'),
                          _videoInfo('history_2', '历史影片 2'),
                          _videoInfo('history_3', '历史影片 3'),
                        ],
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    expect(_focusNodeForCard(tester, 'history_1').hasFocus, isTrue);
    expect(_focusNodeForCard(tester, 'history_2').hasFocus, isFalse);
    expect(_focusNodeForCard(tester, 'history_3').hasFocus, isFalse);
  });

  testWidgets('escape pops TV video library page without waiting extra frame',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => [
                          _videoInfo('history_1', '历史影片'),
                        ],
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('打开视频库页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-video-library-screen-播放历史')),
      findsNothing,
    );

    // 这条用例只验证“当前帧即可返回”，断言完成后手动清掉返回键静态兜底计时器，
    // 避免测试框架把这段保护定时器误判成泄漏。
    TvBackIntent.debugResetBackKeyTracking();
  });

  testWidgets('history page clears all items from header action',
      (tester) async {
    var history = <VideoInfo>[
      _videoInfo('history_1', '历史影片 1'),
      _videoInfo('history_2', '历史影片 2'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => history,
                        onDeleteVideo: (_, videoInfo) async {
                          history.removeWhere(
                            (item) =>
                                item.source == videoInfo.source &&
                                item.id == videoInfo.id,
                          );
                          return true;
                        },
                        onClearVideos: (_) async {
                          history = <VideoInfo>[];
                          return true;
                        },
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    expect(find.text('历史影片 1'), findsOneWidget);
    expect(find.text('历史影片 2'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('tv-video-library-clear-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('清空播放历史'), findsOneWidget);
    expect(find.text('确定要清空全部内容吗？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('历史影片 1'), findsNothing);
    expect(find.text('历史影片 2'), findsNothing);
    expect(find.text('暂无内容'), findsOneWidget);
  });

  testWidgets('favorite card long press deletes current item', (tester) async {
    var favorites = <VideoInfo>[
      _videoInfo('favorite_1', '收藏影片 1'),
      _videoInfo('favorite_2', '收藏影片 2'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '收藏夹',
                        loadVideos: (_) async => favorites,
                        onDeleteVideo: (_, videoInfo) async {
                          favorites.removeWhere(
                            (item) =>
                                item.source == videoInfo.source &&
                                item.id == videoInfo.id,
                          );
                          return true;
                        },
                        onClearVideos: (_) async {
                          favorites = <VideoInfo>[];
                          return true;
                        },
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开收藏夹页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开收藏夹页'));
    await tester.pumpAndSettle();

    final focusNode = _focusNodeForCard(tester, 'favorite_1');
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('删除当前收藏'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('收藏影片 1'), findsNothing);
    expect(find.text('收藏影片 2'), findsOneWidget);
  });
}

FocusNode _focusNodeForCard(WidgetTester tester, String id) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-video-card-focus-$id')),
    matching: find.byWidgetPredicate((widget) {
      return widget is Focus && widget.focusNode != null;
    }),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForActionButton(WidgetTester tester, Key key) {
  final focusFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((widget) {
      return widget is Focus && widget.focusNode != null;
    }),
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

int _videoGridRenderedChildCount(WidgetTester tester) {
  final sliverGrid =
      tester.widget<SliverGrid>(find.byKey(const ValueKey('tv-video-grid')));
  final delegate = sliverGrid.delegate as SliverChildBuilderDelegate;
  return delegate.childCount ?? 0;
}

Color? _actionButtonFillColor(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(AnimatedContainer),
    ),
  );
  final decoration = container.decoration as BoxDecoration?;
  return decoration?.color;
}
