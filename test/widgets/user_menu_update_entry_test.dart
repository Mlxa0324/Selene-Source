import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:selene/widgets/user_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('user menu hides update entry after update feature shutdown',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'IvyTV',
      packageName: 'com.example.ivytv',
      version: '2.1.8',
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

    expect(find.text('检查更新'), findsNothing);
  });
}
