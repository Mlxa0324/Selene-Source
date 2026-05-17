import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/app_theme_scheme.dart';
import 'package:selene/services/theme_service.dart';
import 'package:selene/widgets/user_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('settings page shows a unified preload option enabled by default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    final preloadRow =
        find.byKey(const ValueKey('app-settings-preload-option'));

    expect(find.text('预加载级别'), findsOneWidget);
    expect(preloadRow, findsOneWidget);
    expect(find.descendant(of: preloadRow, matching: find.text('关')),
        findsOneWidget);
    expect(find.descendant(of: preloadRow, matching: find.text('低')),
        findsOneWidget);
    expect(find.descendant(of: preloadRow, matching: find.text('中')),
        findsOneWidget);
    expect(find.descendant(of: preloadRow, matching: find.text('高')),
        findsOneWidget);
    expect(find.text('预加载（media_kit）'), findsNothing);
  });

  testWidgets('settings page shows theme color selector with five fixed schemes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('经典影院绿'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-settings-theme-color-option')));
    await tester.pumpAndSettle();

    expect(find.text('深海蓝'), findsOneWidget);
    expect(find.text('霓虹紫'), findsOneWidget);
    expect(find.text('落日橙'), findsOneWidget);
    expect(find.text('玫瑰红'), findsOneWidget);
  });

  testWidgets('phone preload level options stay on a single row',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    final preloadWrap =
        find.byKey(const ValueKey('app-settings-preload-level-wrap'));
    final singleRow =
        find.byKey(const ValueKey('app-settings-preload-level-row'));

    expect(preloadWrap, findsOneWidget);
    expect(singleRow, findsOneWidget);
  });

  testWidgets('preload level selector uses coordinated inner and outer radii',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    final selector = tester.widget<Container>(
      find.byKey(const ValueKey('app-settings-preload-level-wrap')),
    );
    final selectedButton = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('app-settings-preload-level-button-medium')),
    );
    final selectedLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(
          const ValueKey('app-settings-preload-level-button-medium'),
        ),
        matching: find.text('中'),
      ),
    );

    final selectorDecoration = selector.decoration! as BoxDecoration;
    final selectedDecoration = selectedButton.decoration! as BoxDecoration;

    expect(selectorDecoration.borderRadius, BorderRadius.circular(12));
    expect(selectedDecoration.borderRadius, BorderRadius.circular(8));
    expect(
      selectedDecoration.color,
      AppThemeScheme.classicGreen.lightSeedColor,
    );
    expect(selectedLabel.style?.fontSize, 11);
    expect(selectedLabel.style?.color, Colors.white);
  });

  testWidgets('preload level selector active color follows selected app theme',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'app_theme_scheme_v1': 'ocean_blue',
    });
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    final selectedButton = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('app-settings-preload-level-button-medium')),
    );
    final selectedDecoration = selectedButton.decoration! as BoxDecoration;

    expect(
      selectedDecoration.color,
      AppThemeScheme.oceanBlue.lightSeedColor,
    );
  });

  testWidgets(
      'tablet settings dialog is wider and keeps preload level at bottom',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    await _pumpUserMenu(tester);

    await tester.pumpAndSettle();

    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey('user-menu-dialog'));
    final preloadRow =
        find.byKey(const ValueKey('app-settings-preload-option'));
    final preloadHeader =
        find.byKey(const ValueKey('app-settings-preload-level-header'));
    final preloadWrap =
        find.byKey(const ValueKey('app-settings-preload-level-wrap'));
    final preloadMediumButton =
        find.byKey(const ValueKey('app-settings-preload-level-button-medium'));
    final localSearchRow = find.text('本地搜索');

    expect(dialog, findsOneWidget);
    expect(tester.getSize(dialog).width, greaterThan(360));
    expect(preloadHeader, findsOneWidget);
    expect(preloadWrap, findsOneWidget);
    expect(preloadMediumButton, findsOneWidget);
    expect(localSearchRow, findsOneWidget);
    expect(
      tester.getTopLeft(preloadRow).dy,
      greaterThan(tester.getTopLeft(localSearchRow).dy),
    );
    expect(
      tester.getCenter(preloadHeader).dy,
      closeTo(tester.getCenter(preloadWrap).dy, 2),
    );
    expect(tester.getSize(preloadMediumButton).width, lessThan(56));
  });
}

Future<void> _pumpUserMenu(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MaterialApp(
        home: Scaffold(
          body: UserMenu(
            isDarkMode: false,
          ),
        ),
      ),
    ),
  );
}
