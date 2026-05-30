// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_top_nav.dart';

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

  testWidgets('keeps selected tab when focus enters top nav from outside',
      (tester) async {
    var selectedIndex = 2;
    final outsideFocusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              backgroundColor: const Color(0xFF0B0D0E),
              body: Column(
                children: [
                  TvTopNav(
                    tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
                    selectedIndex: selectedIndex,
                    onChanged: (index) {
                      setState(() => selectedIndex = index);
                    },
                  ),
                  TextButton(
                    focusNode: outsideFocusNode,
                    onPressed: () {},
                    child: const Text('下方内容'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    outsideFocusNode.requestFocus();
    await tester.pumpAndSettle();

    _focusNodeForLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
    outsideFocusNode.dispose();
  });

  testWidgets('changes selected tab during top nav internal focus movement',
      (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              backgroundColor: const Color(0xFF0B0D0E),
              body: TvTopNav(
                tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
                selectedIndex: selectedIndex,
                onChanged: (index) {
                  setState(() => selectedIndex = index);
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();

    _focusNodeForLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
  });

  testWidgets('top nav focus border stays white under scoped theme',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: Scaffold(
            backgroundColor: const Color(0xFF0B0D0E),
            body: TvTopNav(
              tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
              selectedIndex: 0,
              onChanged: (_) {},
              onSearchPressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForAction(tester, 'search').requestFocus();
    await tester.pumpAndSettle();

    final actionDecoration = tester
        .widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byKey(const ValueKey('tv-top-nav-action-search')),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        )
        .decoration! as BoxDecoration;

    expect(actionDecoration.border, isA<Border>());
    expect((actionDecoration.border! as Border).top.color, Colors.white);
  });

  testWidgets('renders utility actions outside main tab menu', (tester) async {
    var selectedIndex = 0;
    var searchPressed = false;
    var historyPressed = false;
    var favoritesPressed = false;
    var settingsPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              backgroundColor: const Color(0xFF0B0D0E),
              body: TvTopNav(
                tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
                selectedIndex: selectedIndex,
                onChanged: (index) {
                  setState(() => selectedIndex = index);
                },
                onSearchPressed: () {
                  searchPressed = true;
                },
                onHistoryPressed: () {
                  historyPressed = true;
                },
                onFavoritesPressed: () {
                  favoritesPressed = true;
                },
                onSettingsPressed: () {
                  settingsPressed = true;
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final mainTabs = find.byKey(const ValueKey('tv-top-nav-main-tabs'));
    final actions = find.byKey(const ValueKey('tv-top-nav-actions'));
    expect(
      find.descendant(of: mainTabs, matching: find.text('播放历史')),
      findsNothing,
    );
    expect(
      find.descendant(of: mainTabs, matching: find.text('收藏夹')),
      findsNothing,
    );
    expect(
      find.descendant(of: mainTabs, matching: find.text('设置')),
      findsNothing,
    );
    expect(
      find.descendant(of: actions, matching: find.text('搜索')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: actions, matching: find.text('播放历史')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: actions, matching: find.text('收藏夹')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: actions, matching: find.text('设置')),
      findsOneWidget,
    );

    await _tapAction(tester, 'search');
    await _tapAction(tester, 'history');
    await _tapAction(tester, 'favorites');
    await _tapAction(tester, 'settings');

    expect(searchPressed, isTrue);
    expect(historyPressed, isTrue);
    expect(favoritesPressed, isTrue);
    expect(settingsPressed, isTrue);
  });

  testWidgets('places utility actions above the main tab row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 0,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final logoTop =
        tester.getTopLeft(find.byKey(const ValueKey('tv-top-nav-logo'))).dy;
    final actionTop =
        tester.getTopLeft(find.byKey(const ValueKey('tv-top-nav-actions'))).dy;
    final tabTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-top-nav-main-tabs')))
        .dy;

    expect(actionTop, closeTo(logoTop, 2));
    expect(actionTop, lessThan(tabTop));
    expect(find.byKey(const ValueKey('tv-top-nav-clock')), findsOneWidget);
  });

  testWidgets('uses compact radius for utility action buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 0,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final searchButton = find.descendant(
      of: find.byKey(const ValueKey('tv-top-nav-action-search')),
      matching: find.byType(AnimatedContainer),
    );
    final container = tester.widget<AnimatedContainer>(searchButton);
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('moves from live tab to quick actions with up key',
      (tester) async {
    int? arrowUpIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 5,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
            onTabArrowUp: (index) {
              arrowUpIndex = index;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForLabel(tester, '直播').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForAction(tester, 'search').hasFocus, isTrue);
    expect(arrowUpIndex, isNull);
  });

  testWidgets('moves from home tab to quick actions with up key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 0,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForAction(tester, 'search').hasFocus, isTrue);
  });

  testWidgets('search action down returns to home tab after entering from home',
      (tester) async {
    var searchPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 0,
            onChanged: (_) {},
            onSearchPressed: () {
              searchPressed = true;
            },
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForLabel(tester, '首页').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(searchPressed, isTrue);
    expect(_focusNodeForLabel(tester, '首页').hasFocus, isTrue);
    expect(_focusNodeForLabel(tester, '直播').hasFocus, isFalse);
  });

  testWidgets('moves from search action back to live tab with down key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 5,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForAction(tester, 'search').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForLabel(tester, '直播').hasFocus, isTrue);
  });

  testWidgets('history selection highlights only quick action, not live tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 6,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byKey(const ValueKey('tv-top-nav-action-history')),
              matching: find.text('播放历史'),
            ),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final liveTab = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('直播'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );

    final historyDecoration = historyButton.decoration! as BoxDecoration;
    final liveDecoration = liveTab.decoration! as BoxDecoration;

    expect(historyDecoration.color, isNot(Colors.transparent));
    expect(liveDecoration.color, Colors.transparent);
  });

  testWidgets('live selection highlights only live tab, not history action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 5,
            onChanged: (_) {},
            onSearchPressed: () {},
            onHistoryPressed: () {},
            onFavoritesPressed: () {},
            onSettingsPressed: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.descendant(
              of: find.byKey(const ValueKey('tv-top-nav-action-history')),
              matching: find.text('播放历史'),
            ),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final liveTab = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('直播'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );

    final historyDecoration = historyButton.decoration! as BoxDecoration;
    final liveDecoration = liveTab.decoration! as BoxDecoration;

    expect(liveDecoration.color, isNot(Colors.transparent));
    expect(historyDecoration.color, const Color(0xFF272C30));
  });

  testWidgets(
      'redirects focus back to history action instead of live bridge when history page is selected',
      (tester) async {
    final outsideFocusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: Column(
            children: [
              TvTopNav(
                tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
                selectedIndex: 6,
                onChanged: (_) {},
                onSearchPressed: () {},
                onHistoryPressed: () {},
                onFavoritesPressed: () {},
                onSettingsPressed: () {},
              ),
              TextButton(
                focusNode: outsideFocusNode,
                onPressed: () {},
                child: const Text('下方内容'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    outsideFocusNode.requestFocus();
    await tester.pumpAndSettle();

    _focusNodeForLabel(tester, '直播').requestFocus();
    await tester.pumpAndSettle();

    expect(_focusNodeForAction(tester, 'history').hasFocus, isTrue);
    expect(_focusNodeForLabel(tester, '直播').hasFocus, isFalse);

    outsideFocusNode.dispose();
  });

  testWidgets('notifies focused tab index when pressing up on top nav item',
      (tester) async {
    int? arrowUpIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0B0D0E),
          body: TvTopNav(
            tabs: const ['首页', '电影', '剧集', '动漫', '综艺', '直播'],
            selectedIndex: 1,
            onChanged: (_) {},
            onTabArrowUp: (index) {
              arrowUpIndex = index;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    _focusNodeForLabel(tester, '电影').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(arrowUpIndex, 1);
  });
}

/// 点击指定快捷入口。
Future<void> _tapAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey('tv-top-nav-action-$key'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
}

/// 获取指定顶部菜单文案对应的焦点节点。
FocusNode _focusNodeForLabel(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

/// 获取指定快捷入口对应的焦点节点。
FocusNode _focusNodeForAction(WidgetTester tester, String key) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-top-nav-action-$key')),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}
