// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
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

  testWidgets('clears search history through TV confirm dialog',
      (tester) async {
    var history = <String>['庆余年', '长安的荔枝'];
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: TvSearchScreen(
            loadSearchData: (_) async => TvSearchData(
              searchHistory: history,
              hotWords: const ['剑来'],
              recommends: [],
            ),
            onClearSearchHistory: (_) async {
              history = <String>[];
              return true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-history-clear-button')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('tv-search-history-clear-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    expect(find.text('清空搜索历史'), findsOneWidget);
    expect(find.text('确定要清空全部搜索记录吗？'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tv-confirm-dialog'))),
      const Size(372, 182),
    );
    expect(
      (tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('tv-confirm-cancel-button')),
      ).decoration as BoxDecoration)
          .color,
      TvThemePalette.netflixRed.accent,
    );

    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('庆余年'), findsNothing);
    expect(find.text('长安的荔枝'), findsNothing);
    expect(find.text('暂无搜索历史'), findsOneWidget);
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

  testWidgets('rightmost word tiles keep focus on right key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['历史1', '历史2', '历史3', '历史4'],
            hotWords: ['热词1', '热词2', '热词3'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rightmostHistoryNode = _focusNodeForText(tester, '历史3');
    rightmostHistoryNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(rightmostHistoryNode.hasFocus, isTrue);

    final raggedRightNode = _focusNodeForText(tester, '历史4');
    raggedRightNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(raggedRightNode.hasFocus, isTrue);
  });

  testWidgets(
      'last hot word moves focus down to first recommendation card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final lastHotWordFocusNode = _focusNodeForText(tester, '热词4');
    lastHotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '推荐 1').hasFocus, isTrue);
    expect(lastHotWordFocusNode.hasFocus, isFalse);
  });

  testWidgets('last history item moves focus down to hot words',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['历史1', '历史2', '历史3', '历史4'],
            hotWords: ['热词1', '热词2'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyFocusNode = _focusNodeForText(tester, '历史4');
    historyFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '热词1').hasFocus, isTrue);
    expect(_focusNodeForText(tester, 'A').hasFocus, isFalse);
  });

  testWidgets('last hot word keeps focus on arrow down when recommendations are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['历史1'],
            hotWords: ['热词1', '热词2', '热词3', '热词4'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final hotWordFocusNode = _focusNodeForText(tester, '热词4');
    hotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(hotWordFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(hotWordFocusNode.hasFocus, isTrue);
    expect(_focusNodeForText(tester, 'A').hasFocus, isFalse);
  });

  testWidgets('leftmost recommendation card moves focus left to search panel',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['热词1'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final keyboardFocusNode = _focusNodeForText(tester, 'A');
    keyboardFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(keyboardFocusNode.hasFocus, isTrue);

    final firstRecommendFocusNode = _focusNodeForText(tester, '推荐 1');
    firstRecommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(firstRecommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(keyboardFocusNode.hasFocus, isTrue);
    expect(firstRecommendFocusNode.hasFocus, isFalse);
  });

  testWidgets('last recommendation card moves focus up to remembered hot word',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2'],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHotWordNode = _focusNodeForText(tester, '热词4');
    rememberedHotWordNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHotWordNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, '推荐 1').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, '推荐 3').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHotWordNode.hasFocus, isTrue);
    expect(_focusNodeForText(tester, '推荐 3').hasFocus, isFalse);
  });

  testWidgets('recommendation focus up prefers hot words over history memory',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHotWordNode = _focusNodeForText(tester, '热词4');
    rememberedHotWordNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHotWordNode.hasFocus, isTrue);

    final historyNode = _focusNodeForText(tester, '历史4');
    historyNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyNode.hasFocus, isTrue);

    final recommendFocusNode = _focusNodeForText(tester, '推荐 3');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHotWordNode.hasFocus, isTrue);
    expect(historyNode.hasFocus, isFalse);
    expect(recommendFocusNode.hasFocus, isFalse);
  });

  testWidgets('recommendation card moves focus up to history when hot words are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHistoryNode = _focusNodeForText(tester, '历史4');
    rememberedHistoryNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHistoryNode.hasFocus, isTrue);

    final recommendFocusNode = _focusNodeForText(tester, '推荐 2');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHistoryNode.hasFocus, isTrue);
    expect(recommendFocusNode.hasFocus, isFalse);
  });

  testWidgets('recommendation cards keep focus on arrow down', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2'],
            hotWords: const ['热词1', '热词2', '热词3'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final middleRecommendNode = _focusNodeForText(tester, '推荐 2');
    middleRecommendNode.requestFocus();
    await tester.pumpAndSettle();
    expect(middleRecommendNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(middleRecommendNode.hasFocus, isTrue);
  });

  testWidgets('right panel scroll keeps focused word near middle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: List<String>.generate(15, (index) => '历史$index'),
            hotWords: List<String>.generate(12, (index) => '热词$index'),
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final lowerWordNode = _focusNodeForText(tester, '热词8');
    lowerWordNode.requestFocus();
    await tester.pumpAndSettle();

    final focusedRect = tester.getRect(find.text('热词8'));
    final viewportHeight = tester.view.physicalSize.height;
    expect(focusedRect.center.dy, greaterThan(viewportHeight * 0.36));
    expect(focusedRect.center.dy, lessThan(viewportHeight * 0.64));
  });

  testWidgets('right panel scrolls down when recommendation card gains focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: List<String>.generate(18, (index) => '历史$index'),
            hotWords: List<String>.generate(15, (index) => '热词$index'),
            recommends: List<VideoInfo>.generate(
              6,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.controller != null &&
          widget.controller!.hasClients,
    );
    final scrollViewBefore =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final beforeOffset = scrollViewBefore.controller!.offset;

    final recommendFocusNode = _focusNodeForText(tester, '推荐0');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();

    final scrollViewAfter =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final afterOffset = scrollViewAfter.controller!.offset;

    expect(afterOffset, greaterThan(beforeOffset));
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

  testWidgets('left search controls use tighter sizing', (tester) async {
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

    final titleText = tester.widget<Text>(find.text('搜索'));
    final hintText = tester.widget<Text>(find.text('按返回键可退出本页面'));
    final keyboardGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('tv-search-keyboard')),
    );
    final searchField = tester.widget<Container>(
      find.byKey(const ValueKey('tv-search-input')),
    );
    final clearButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('清空'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );

    final keyboardDelegate =
        keyboardGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(titleText.style?.fontSize, 28);
    expect(hintText.style?.fontSize, 15);
    expect(
        searchField.constraints?.maxHeight ??
            searchField.constraints?.minHeight,
        46);
    expect(keyboardDelegate.mainAxisExtent, 42);
    expect(
        clearButton.constraints?.maxHeight ??
            clearButton.constraints?.minHeight,
        46);
  });

  testWidgets('right search panels use more compact sizing', (tester) async {
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

    final historyTitle = tester.widget<Text>(find.text('搜索历史'));
    final hotWordTitle = tester.widget<Text>(find.text('搜索热词'));
    final recommendTitle = tester.widget<Text>(find.text('影片推荐'));
    final historyGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('tv-search-word-grid-搜索历史')),
    );
    final historyTileText = tester.widget<Text>(find.text('庆余年'));
    final recommendList = tester.widget<ListView>(
      find.byKey(const ValueKey('tv-search-recommend-list')),
    );

    final historyDelegate =
        historyGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(historyTitle.style?.fontSize, 24);
    expect(hotWordTitle.style?.fontSize, 24);
    expect(recommendTitle.style?.fontSize, 26);
    expect(historyDelegate.mainAxisExtent, 46);
    expect(historyDelegate.crossAxisSpacing, 16);
    expect(historyDelegate.mainAxisSpacing, 14);
    expect(historyTileText.style?.fontSize, 17);
    expect(recommendList.padding, const EdgeInsets.fromLTRB(0, 8, 70, 16));
  });

  testWidgets('autofocuses first search history item when history exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const ['剑来', '主角'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '庆余年').hasFocus, isTrue);
  });

  testWidgets('autofocuses first hot word when history is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['剑来', '主角'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '剑来').hasFocus, isTrue);
  });

  testWidgets('autofocuses first recommendation card when words are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '世界的主人'),
              _videoInfo('recommend_2', '飞驰人生'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '世界的主人').hasFocus, isTrue);
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
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvSearchScreen(
                        loadSearchData: (_) async => const TvSearchData(
                          searchHistory: ['庆余年'],
                          hotWords: ['剑来'],
                          recommends: [],
                        ),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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

  testWidgets('escape pops TV search page without waiting for extra frame',
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
                          TvSearchScreen(
                        loadSearchData: (_) async => const TvSearchData(
                          searchHistory: ['庆余年'],
                          hotWords: ['剑来'],
                          recommends: [],
                        ),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

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
