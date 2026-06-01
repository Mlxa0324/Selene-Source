import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';

void main() {
  test('TV video card keeps compact poster proportions', () {
    expect(TvVideoCard.width, 158);
    expect(TvVideoCard.height, 300);
    expect(TvVideoCard.coverHeight, 237);
    expect(TvVideoCard.focusedScale, 1.08);
    expect(TvVideoCard.shimmerBegin, const Alignment(-1.2, 0));
    expect(TvVideoCard.shimmerEnd, const Alignment(1.2, 0));
    expect(TvVideoCard.shimmerVerticalTravelFactor, 0);
    expect(TvVideoCard.shimmerSoftEdgeColor, const Color(0x12FFFFFF));
    expect(TvVideoCard.shimmerMidColor, const Color(0x20FFFFFF));
    expect(TvVideoCard.shimmerCenterColor, const Color(0x2CFFFFFF));
    expect(
      TvVideoCard.shimmerStops,
      const <double>[0.08, 0.24, 0.38, 0.50, 0.62, 0.76, 0.92],
    );
    expect(TvVideoCard.shimmerDuration, const Duration(milliseconds: 1800));
    expect(TvVideoCard.focusSweepDelay, const Duration(milliseconds: 300));
    expect(TvVideoCard.coverHeight / TvVideoCard.width, closeTo(1.5, 0.01));
  });

  test('TV cover loading skeleton uses softer horizontal shimmer', () {
    expect(TvCoverLoadingSkeleton.shimmerBegin, const Alignment(-1.2, 0));
    expect(TvCoverLoadingSkeleton.shimmerEnd, const Alignment(1.2, 0));
    expect(TvCoverLoadingSkeleton.shimmerVerticalTravelFactor, 0);
    expect(TvCoverLoadingSkeleton.maxSweepCount, 2);
    expect(
      TvCoverLoadingSkeleton.shimmerSoftEdgeColor,
      const Color(0x12E4EAED),
    );
    expect(
      TvCoverLoadingSkeleton.shimmerMidColor,
      const Color(0x1EE4EAED),
    );
    expect(
      TvCoverLoadingSkeleton.shimmerCenterColor,
      const Color(0x2AE4EAED),
    );
    expect(
      TvCoverLoadingSkeleton.shimmerStops,
      const <double>[0.10, 0.26, 0.40, 0.50, 0.60, 0.74, 0.90],
    );
  });

  testWidgets('TV video card scales whole card but keeps focus frame on cover',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(),
          ),
        ),
      ),
    );

    final coverFocusFrame = find.byType(AnimatedContainer);

    expect(coverFocusFrame, findsOneWidget);
    expect(tester.getSize(coverFocusFrame), const Size(158, 237));
    expect(find.byType(AnimatedScale), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('测试影片'),
        matching: find.byType(AnimatedScale),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: coverFocusFrame,
        matching: find.text('测试影片'),
      ),
      findsNothing,
    );

    final title = tester.widget<Text>(find.text('测试影片'));
    expect(title.maxLines, 1);
  });

  testWidgets('TV video card uses larger title and subtitle font sizes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('测试影片'));
    final subtitle = tester.widget<Text>(find.text('2026 · 8.8 分'));

    expect(title.style?.fontSize, 16);
    expect(subtitle.style?.fontSize, 14);
  });

  testWidgets('TV video card shows cover skeleton while image is loading',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(cover: 'https://example.com/poster.jpg'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tv-cover-loading-skeleton')),
        findsOneWidget);
  });

  testWidgets('TV cover loading skeleton stops after two shimmer sweeps',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: TvVideoCard.width,
            height: TvVideoCard.coverHeight,
            child: TvCoverLoadingSkeleton(),
          ),
        ),
      ),
    );

    final initialOffset = _skeletonSweepOffset(tester);

    await tester.pump(TvVideoCard.shimmerDuration);
    final firstCompletedOffset = _skeletonSweepOffset(tester);

    await tester.pump(const Duration(milliseconds: 1));
    final secondSweepStartedOffset = _skeletonSweepOffset(tester);

    await tester
        .pump(TvVideoCard.shimmerDuration - const Duration(milliseconds: 1));
    final secondCompletedOffset = _skeletonSweepOffset(tester);

    await tester.pump(TvVideoCard.shimmerDuration);
    final thirdCompletedOffset = _skeletonSweepOffset(tester);

    expect(initialOffset.dx, lessThan(firstCompletedOffset.dx));
    expect(secondSweepStartedOffset.dx, lessThan(firstCompletedOffset.dx));
    expect(thirdCompletedOffset.dx, closeTo(secondCompletedOffset.dx, 0.5));
  });

  testWidgets('TV video card defers image requests while scrolling',
      (tester) async {
    var shouldDeferLoading = true;
    final startedRequests = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(cover: 'https://example.com/poster.jpg'),
            deferredLoadingDecider: (_) => shouldDeferLoading,
            deferredLoadingRetryDelay: const Duration(milliseconds: 10),
            onCoverImageRequestStarted: startedRequests.add,
          ),
        ),
      ),
    );

    expect(startedRequests, isEmpty);
    await _pumpFrames(tester, count: 6);

    expect(find.byKey(const ValueKey('tv-cover-deferred-loading-skeleton')),
        findsOneWidget);
    expect(startedRequests, isEmpty);

    // 模拟滚动停止后，组件通过内部重试自行发起图片加载。
    shouldDeferLoading = false;
    await tester.pump(const Duration(milliseconds: 12));
    await _pumpFrames(tester, count: 6);

    expect(startedRequests, const ['https://example.com/poster.jpg']);
  });

  testWidgets(
      'TV video card only starts image requests after entering viewport',
      (tester) async {
    final startedRequests = <String>[];
    final scrollController = ScrollController();

    VideoInfo buildVideoInfo(int index) {
      return VideoInfo(
        id: 'tv_card_$index',
        source: 'test',
        title: '测试影片 $index',
        sourceName: '测试源',
        year: '2026',
        cover: 'https://example.com/poster_$index.jpg',
        index: 1,
        totalEpisodes: 1,
        playTime: 0,
        totalTime: 0,
        saveTime: 0,
        searchTitle: '测试影片 $index',
        rate: '8.8',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 650,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: List<Widget>.generate(
                  6,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TvVideoCard(
                      videoInfo: buildVideoInfo(index),
                      deferredLoadingDecider: (_) => false,
                      deferredLoadingRetryDelay:
                          const Duration(milliseconds: 10),
                      onCoverImageRequestStarted: startedRequests.add,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await _pumpFrames(tester, count: 6);

    expect(startedRequests, contains('https://example.com/poster_0.jpg'));
    expect(startedRequests, contains('https://example.com/poster_1.jpg'));
    expect(
        startedRequests, isNot(contains('https://example.com/poster_5.jpg')));

    scrollController.jumpTo((TvVideoCard.height + 12) * 4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 12));
    await _pumpFrames(tester, count: 6);

    expect(startedRequests, contains('https://example.com/poster_5.jpg'));

    scrollController.dispose();
  });

  testWidgets(
      'TV video card keeps existing image widget after loading has started',
      (tester) async {
    var shouldDeferLoading = false;
    final startedRequests = <String>[];
    late StateSetter hostSetState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              hostSetState = setState;
              return TvVideoCard(
                videoInfo: _videoInfo(cover: 'https://example.com/poster.jpg'),
                deferredLoadingDecider: (_) => shouldDeferLoading,
                deferredLoadingRetryDelay: const Duration(milliseconds: 10),
                onCoverImageRequestStarted: startedRequests.add,
              );
            },
          ),
        ),
      ),
    );

    await _pumpFrames(tester, count: 6);
    expect(startedRequests, const ['https://example.com/poster.jpg']);

    // 模拟已开始加载后继续滚动，卡片不应闪回到纯延迟骨架态。
    shouldDeferLoading = true;
    hostSetState(() {});
    await tester.pump();

    expect(startedRequests, const ['https://example.com/poster.jpg']);
    expect(find.byKey(const ValueKey('tv-cover-deferred-loading-skeleton')),
        findsNothing);
  });

  testWidgets('TV video card shows episode badge for multi episode progress',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(
              index: 3,
              totalEpisodes: 12,
              playTime: 600,
              totalTime: 1200,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tv-card-episode-badge')), findsOneWidget);
    expect(find.text('3/12'), findsOneWidget);
  });

  testWidgets('TV video card shows playback progress at cover bottom',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(
              playTime: 300,
              totalTime: 1200,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tv-card-progress-bar')), findsOneWidget);
    final progressFill = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('tv-card-progress-fill')),
    );
    expect(progressFill.widthFactor, 0.25);
  });

  testWidgets('TV video card progress fill uses scoped theme accent',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: Scaffold(
            body: TvVideoCard(
              videoInfo: _videoInfo(
                playTime: 300,
                totalTime: 1200,
              ),
            ),
          ),
        ),
      ),
    );

    final progressDecoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('tv-card-progress-fill')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;

    // 继续观看封面底部进度条跟随当前 TV 主题色。
    expect(progressDecoration.color, TvThemePalette.netflixRed.accent);
  });

  testWidgets('TV video card focus border stays neutral under scoped theme',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final focusNode = FocusNode();
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: Scaffold(
            body: TvVideoCard(
              focusNode: focusNode,
              videoInfo: _videoInfo(),
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    final coverContainerFinder = find
        .byWidgetPredicate(
          (widget) => widget is AnimatedContainer,
        )
        .evaluate()
        .map((element) => find.byWidget(element.widget))
        .firstWhere(
          (finder) =>
              tester.getSize(finder) ==
              const Size(TvVideoCard.width, TvVideoCard.coverHeight),
        );
    final coverDecoration = tester
        .widget<AnimatedContainer>(coverContainerFinder)
        .foregroundDecoration! as BoxDecoration;

    expect(coverDecoration.border, isA<Border>());
    expect(
      (coverDecoration.border! as Border).top.color,
      const Color(0xFFE2E6EA),
    );

    focusNode.dispose();
  });

  testWidgets(
      'TV video card shows only source name in continue watching subtitle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            videoInfo: _videoInfo(
              index: 497,
              totalEpisodes: 500,
              playTime: 497,
              totalTime: 3600,
              rate: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('497/500'), findsOneWidget);
    expect(find.text('测试源'), findsOneWidget);
    expect(find.textContaining('08:17'), findsNothing);
    expect(find.textContaining('第497集'), findsNothing);
  });

  testWidgets('TV video card delays focus sweep until focus stays briefly',
      (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            focusNode: focusNode,
            videoInfo: _videoInfo(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));

    expect(find.byKey(const ValueKey('tv-cover-focus-sweep')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(const ValueKey('tv-cover-focus-sweep')), findsOneWidget);

    focusNode.dispose();
  });

  testWidgets('TV video card focus sweep uses horizontal shimmer only',
      (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvVideoCard(
            focusNode: focusNode,
            videoInfo: _videoInfo(),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    await tester.pump(TvVideoCard.focusSweepDelay);

    final sweepDecoration = tester
        .widget<DecoratedBox>(
          find.byKey(const ValueKey('tv-cover-focus-sweep')),
        )
        .decoration as BoxDecoration;
    final sweepGradient = sweepDecoration.gradient! as LinearGradient;

    expect(sweepGradient.begin, TvVideoCard.shimmerBegin);
    expect(sweepGradient.end, TvVideoCard.shimmerEnd);
    expect(TvVideoCard.shimmerVerticalTravelFactor, 0);

    focusNode.dispose();
  });
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 1}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Offset _skeletonSweepOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byKey(const ValueKey('tv-cover-loading-skeleton')),
      matching: find.byType(Transform),
    ),
  );
  final translation = transform.transform.getTranslation();
  return Offset(translation.x, translation.y);
}

VideoInfo _videoInfo({
  String cover = '',
  int index = 1,
  int totalEpisodes = 1,
  int playTime = 0,
  int totalTime = 0,
  String? rate = '8.8',
}) {
  return VideoInfo(
    id: 'tv_card_1',
    source: 'test',
    title: '测试影片',
    sourceName: '测试源',
    year: '2026',
    cover: cover,
    index: index,
    totalEpisodes: totalEpisodes,
    playTime: playTime,
    totalTime: totalTime,
    saveTime: 0,
    searchTitle: '测试影片',
    rate: rate,
  );
}
