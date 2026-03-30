import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:selene/widgets/user_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('long pressing the version opens the benchmark screen',
      (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Selene',
      packageName: 'com.example.selene',
      version: '1.6.7',
      buildNumber: '1',
      buildSignature: 'sig',
    );

    var versionTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserMenu(
            isDarkMode: false,
            onVersionTap: () {
              versionTapCount++;
            },
            benchmarkScreenBuilder: (_) => const Scaffold(
              body: Text('Benchmark Screen'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final versionText = find.text('v1.6.7');
    expect(versionText, findsOneWidget);

    await tester.tap(versionText);
    await tester.pumpAndSettle();
    expect(versionTapCount, 1);

    await tester.longPress(versionText);
    await tester.pumpAndSettle();

    expect(find.text('Benchmark Screen'), findsOneWidget);
  });
}
