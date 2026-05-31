import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('vertical grid moves a shared focus frame between cards',
      (tester) async {
    final themeService = TvThemeService();
    await themeService.setFocusEffectModeKey(TvFocusEffectMode.smoothFrame.key);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0D0E),
            body: TvVideoGrid(
              title: '电影',
              crossAxisCount: 3,
              videos: List.generate(
                6,
                (index) => _videoInfo('grid_$index', '电影 $index'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    _focusNodeForVideoCard(tester, 'grid_0').requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final focusFrame = find.byKey(const ValueKey('tv-video-grid-focus-frame'));
    expect(focusFrame, findsOneWidget);
    expect(tester.getSize(focusFrame), _focusedCoverSize(tester, 'grid_0'));
    final firstFrameTopLeft = tester.getTopLeft(focusFrame);

    _focusNodeForVideoCard(tester, 'grid_4').requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final secondFrameTopLeft = tester.getTopLeft(focusFrame);
    expect(tester.getSize(focusFrame), _focusedCoverSize(tester, 'grid_4'));
    expect(secondFrameTopLeft.dx, greaterThan(firstFrameTopLeft.dx));
    expect(secondFrameTopLeft.dy, greaterThan(firstFrameTopLeft.dy));
  });

  testWidgets('vertical grid keeps shared focus frame aligned while scrolling',
      (tester) async {
    final themeService = TvThemeService();
    await themeService.setFocusEffectModeKey(TvFocusEffectMode.smoothFrame.key);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0D0E),
            body: SizedBox(
              height: 320,
              child: TvVideoGrid(
                title: '电影',
                showTitle: false,
                crossAxisCount: 3,
                videos: List.generate(
                  18,
                  (index) => _videoInfo('grid_$index', '电影 $index'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    _focusNodeForVideoCard(tester, 'grid_1').requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final focusFrame = find.byKey(const ValueKey('tv-video-grid-focus-frame'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(_focusNodeForVideoCard(tester, 'grid_4').hasFocus, isTrue);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();

    final settledCoverTopLeft =
        tester.getTopLeft(_coverFinder(tester, 'grid_4'));
    final settledFrameTopLeft = tester.getTopLeft(focusFrame);
    expect(
      tester
          .state<ScrollableState>(
            find.byType(Scrollable).first,
          )
          .position
          .pixels,
      greaterThan(0),
    );
    expect(
      settledFrameTopLeft.dx,
      closeTo(settledCoverTopLeft.dx - 5, 0.1),
    );
    expect(
      settledFrameTopLeft.dy,
      closeTo(settledCoverTopLeft.dy - 5, 0.1),
    );
  });
}

Size _focusedCoverSize(WidgetTester tester, String id) {
  final coverSize = tester.getSize(_coverFinder(tester, id));
  return Size(coverSize.width + 10, coverSize.height + 10);
}

Finder _coverFinder(WidgetTester tester, String id) {
  final cardFinder = find.byKey(ValueKey('tv-video-card-focus-$id'));
  return find
      .descendant(
        of: cardFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is AnimatedContainer,
        ),
      )
      .evaluate()
      .map((element) => find.byWidget(element.widget))
      .firstWhere((finder) => tester.getSize(finder).height > 200);
}

FocusNode _focusNodeForVideoCard(WidgetTester tester, String id) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-video-card-focus-$id')),
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
    rate: '8.8',
  );
}
