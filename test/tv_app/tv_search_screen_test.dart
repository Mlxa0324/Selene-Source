// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_search_screen.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';

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

  testWidgets('renders TV search history hot words and recommendations',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const ['剑来', '主角', '黑袍纠察队第五季'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('搜索热词'), findsOneWidget);
    expect(find.text('影片推荐'), findsOneWidget);
    expect(find.text('庆余年'), findsOneWidget);
    expect(find.text('剑来'), findsOneWidget);
    expect(find.text('世界的主人'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-search-recommend-list')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('影片推荐')).dx,
      tester.getTopLeft(find.text('搜索热词')).dx,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('tv-search-recommend-list')))
          .dx,
      tester.getTopLeft(find.text('影片推荐')).dx,
    );
    expect(
      tester
          .widget<GridView>(
            find.byKey(const ValueKey('tv-search-word-grid-搜索历史')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(
      tester
          .widget<GridView>(
            find.byKey(const ValueKey('tv-search-word-grid-搜索热词')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
  });

  testWidgets('fills search input from hot word tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: ['剑来'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('剑来'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('剑来'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('throttles repeat focus traversal on text word tiles',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: ['热词1', '热词2', '热词3'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstFocusNode = _focusNodeForText(tester, '热词1');
    final secondFocusNode = _focusNodeForText(tester, '热词2');
    final thirdFocusNode = _focusNodeForText(tester, '热词3');

    firstFocusNode.requestFocus();
    await tester.pump();
    expect(firstFocusNode.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocusNode.hasFocus, isTrue);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocusNode.hasFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 180));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(thirdFocusNode.hasFocus, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
  });

  testWidgets('places search panels closer to top on first screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: ['剑来'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final leftTop = tester.getTopLeft(find.text('搜索')).dy;
    final historyTop = tester.getTopLeft(find.text('搜索历史')).dy;
    expect(leftTop, lessThanOrEqualTo(64));
    expect(historyTop, lessThanOrEqualTo(64));
    expect((leftTop - historyTop).abs(), lessThanOrEqualTo(6));
  });

  testWidgets('recommendation cards use TV card focus scale and edge feedback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: List.generate(
              3,
              (index) => _videoInfo('recommend_$index', '推荐 $index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);
    final focusNode = _focusNodeForText(tester, '推荐 2');
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final focusedScale = tester.widget<AnimatedScale>(
      find.ancestor(
        of: find.text('推荐 2'),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(focusedScale.scale, TvVideoCard.focusedScale);
  });

  testWidgets('escape pops TV search page like remote back key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TvSearchScreen(
                        loadSearchData: (_) async => const TvSearchData(
                          searchHistory: ['庆余年'],
                          hotWords: ['剑来'],
                          recommends: [],
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开搜索页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开搜索页'));
    await tester.pumpAndSettle();

    final hotWordFocusNode = _focusNodeForText(tester, '剑来');
    hotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(hotWordFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('打开搜索页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-search-screen')), findsNothing);
  });
}

FocusNode _focusNodeForText(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Focus &&
          widget.focusNode != null &&
          widget.focusNode!.debugLabel != 'tv-back-handler',
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
