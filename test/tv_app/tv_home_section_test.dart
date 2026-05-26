import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/widgets/tv_home_section.dart';

void main() {
  testWidgets('resets horizontal scroll when section focus moves away',
      (tester) async {
    final firstController = ScrollController();
    final secondController = ScrollController();
    final verticalController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: SizedBox(
            height: 360,
            child: SingleChildScrollView(
              controller: verticalController,
              child: Column(
                children: [
                  TvHomeSection(
                    title: '继续观看',
                    videos: List.generate(
                      12,
                      (index) => _videoInfo('continue_$index', '继续 $index'),
                    ),
                    scrollController: firstController,
                  ),
                  TvHomeSection(
                    title: '热门电影',
                    videos: List.generate(
                      12,
                      (index) => _videoInfo('movie_$index', '电影 $index'),
                    ),
                    scrollController: secondController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    firstController.jumpTo(320);
    await tester.pump();
    expect(firstController.offset, 320);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 140));

    expect(verticalController.offset, greaterThan(0));

    await tester.pumpAndSettle();

    expect(firstController.offset, 0);
  });

  testWidgets('wraps horizontal edge cards with shake feedback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvHomeSection(
            title: '热门电影',
            videos: [_videoInfo('movie_0', '电影 0')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsOneWidget);
  });

  testWidgets('uses cover size for horizontal loading skeletons',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0B0D0E),
          body: TvHomeSection(
            title: '继续观看',
            videos: [],
            isLoading: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('tv-home-loading-card')).first),
      const Size(158, 237),
    );
  });

  testWidgets('shows first fifteen videos and then more card', (tester) async {
    var morePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvHomeSection(
            title: '热门电影',
            videos: List.generate(
              16,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            onMorePressed: () {
              morePressed = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('tv-home-section-list-热门电影')),
      const Offset(-2800, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-home-more-card')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tv-home-more-card'))),
      const Size(158, 237),
    );
    expect(find.text('电影 15'), findsNothing);

    await tester.tap(find.text('查看更多'));
    await tester.pumpAndSettle();

    expect(morePressed, isTrue);
  });

  testWidgets('right edge key reveals trailing padding before shaking',
      (tester) async {
    final controller = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvHomeSection(
            title: '热门电影',
            videos: List.generate(
              16,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            onMorePressed: () {},
            scrollController: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent - 120);
    await tester.pumpAndSettle();
    _focusNodeForFocusableContainer(tester, const ValueKey('tv-home-more-card'))
        .requestFocus();
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent - 120);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('horizontal row starts moving only when fifth card gets focus',
      (tester) async {
    final controller = ScrollController();
    await _setTvSurfaceSize(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvHomeSection(
            title: '热门电影',
            videos: List.generate(
              12,
              (index) => _videoInfo('movie_$index', '电影 $index'),
            ),
            scrollController: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }

    expect(controller.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  testWidgets('re-entering home section starts from first card after blur',
      (tester) async {
    final continueFirstFocusNode = FocusNode(debugLabel: 'continue-first');
    final movieFirstFocusNode = FocusNode(debugLabel: 'movie-first');
    addTearDown(continueFirstFocusNode.dispose);
    addTearDown(movieFirstFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: SizedBox(
            height: 360,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TvHomeSection(
                    title: '继续观看',
                    videos: List.generate(
                      8,
                      (index) => _videoInfo('continue_$index', '继续 $index'),
                    ),
                    firstItemFocusNode: continueFirstFocusNode,
                    onArrowDownToNextSection: () {
                      movieFirstFocusNode.requestFocus();
                    },
                  ),
                  TvHomeSection(
                    title: '热门电影',
                    videos: List.generate(
                      8,
                      (index) => _videoInfo('movie_$index', '电影 $index'),
                    ),
                    firstItemFocusNode: movieFirstFocusNode,
                    onArrowUpFromFirstItem: () {
                      continueFirstFocusNode.requestFocus();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    _focusNodeForVideoCard(tester, 'movie_3').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForVideoCard(tester, 'continue_0').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForVideoCard(tester, 'movie_0').hasFocus, isTrue);
    expect(_focusNodeForVideoCard(tester, 'movie_3').hasFocus, isFalse);
  });

  test('home section starts scrolling when focus reaches fifth card', () {
    const currentPixels = 0.0;
    const viewportDimension = 1480.0;
    const minScrollExtent = 0.0;
    const maxScrollExtent = 1200.0;

    expect(
      TvHomeSection.resolveScrollOffset(
        index: 3,
        currentPixels: currentPixels,
        viewportDimension: viewportDimension,
        minScrollExtent: minScrollExtent,
        maxScrollExtent: maxScrollExtent,
      ),
      currentPixels,
    );

    expect(
      TvHomeSection.resolveScrollOffset(
        index: 4,
        currentPixels: currentPixels,
        viewportDimension: viewportDimension,
        minScrollExtent: minScrollExtent,
        maxScrollExtent: maxScrollExtent,
      ),
      greaterThan(0),
    );

    expect(
      TvHomeSection.resolveScrollOffset(
        index: 5,
        currentPixels: currentPixels,
        viewportDimension: viewportDimension,
        minScrollExtent: minScrollExtent,
        maxScrollExtent: maxScrollExtent,
      ),
      greaterThan(
        TvHomeSection.resolveScrollOffset(
          index: 4,
          currentPixels: currentPixels,
          viewportDimension: viewportDimension,
          minScrollExtent: minScrollExtent,
          maxScrollExtent: maxScrollExtent,
        ),
      ),
    );
  });
}

FocusNode _focusNodeForFocusableContainer(WidgetTester tester, Key key) {
  final focusFinder = find.ancestor(
    of: find.byKey(key),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForKey(WidgetTester tester, Key key) {
  final focusFinder = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForVideoCard(WidgetTester tester, String id) {
  return _focusNodeForKey(
    tester,
    ValueKey('tv-video-card-focus-$id'),
  );
}

Future<void> _setTvSurfaceSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
