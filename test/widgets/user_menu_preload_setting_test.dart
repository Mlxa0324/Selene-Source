import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/widgets/user_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserMenu(
            isDarkMode: false,
          ),
        ),
      ),
    );

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
}
