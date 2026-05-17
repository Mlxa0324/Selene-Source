import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/app_theme_scheme.dart';
import 'package:selene/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  test('loads saved app theme scheme from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_scheme_v1': 'ocean_blue',
    });

    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    expect(service.appThemeScheme, AppThemeScheme.oceanBlue);
  });

  test('setAppThemeScheme updates current scheme and theme seed color', () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    await service.setAppThemeScheme(AppThemeScheme.sunsetOrange);

    expect(service.appThemeScheme, AppThemeScheme.sunsetOrange);
    expect(
      service.lightTheme.colorScheme.primary,
      equals(
        ColorScheme.fromSeed(
          seedColor: AppThemeScheme.sunsetOrange.lightSeedColor,
          brightness: Brightness.light,
        ).primary,
      ),
    );
  });

  test('light scaffold gradient starts from the active theme family', () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    await service.setAppThemeScheme(AppThemeScheme.oceanBlue);

    expect(
      service.lightScaffoldGradientColors.first,
      equals(service.accentTint(0.12, brightness: Brightness.light)),
    );
    expect(
      service.lightScaffoldGradientColors.last,
      equals(
        service.accentTint(
          0.14,
          brightness: Brightness.light,
          baseColor: const Color(0xFFD3DDE6),
        ),
      ),
    );
  });
}
