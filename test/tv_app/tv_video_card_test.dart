import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';

void main() {
  test('TV video card keeps compact poster proportions', () {
    expect(TvVideoCard.width, 158);
    expect(TvVideoCard.height, 297);
    expect(TvVideoCard.coverHeight, 237);
    expect(TvVideoCard.focusedScale, 1.08);
    expect(TvVideoCard.shimmerBegin, const Alignment(-1.2, -0.34));
    expect(TvVideoCard.shimmerEnd, const Alignment(1.2, 0.34));
    expect(TvVideoCard.shimmerVerticalTravelFactor, 0.34);
    expect(TvVideoCard.shimmerDuration, const Duration(milliseconds: 1800));
    expect(TvVideoCard.focusSweepDelay, const Duration(milliseconds: 300));
    expect(TvVideoCard.coverHeight / TvVideoCard.width, closeTo(1.5, 0.01));
  });

  test('TV cover loading skeleton uses softer horizontal shimmer', () {
    expect(TvCoverLoadingSkeleton.shimmerBegin, const Alignment(-1.2, 0));
    expect(TvCoverLoadingSkeleton.shimmerEnd, const Alignment(1.2, 0));
    expect(TvCoverLoadingSkeleton.shimmerVerticalTravelFactor, 0);
    expect(
      TvCoverLoadingSkeleton.shimmerSoftEdgeColor,
      const Color(0x0FE4EAED),
    );
    expect(
      TvCoverLoadingSkeleton.shimmerCenterColor,
      const Color(0x1CE4EAED),
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
    expect(subtitle.style?.fontSize, 13);
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
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 1}) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
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
