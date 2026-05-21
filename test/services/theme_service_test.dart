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

    expect(service.appThemeScheme.label, '清澈蓝');
    expect(
      service.appThemeScheme.lightSeedColor,
      const Color(0xFF0393E7),
    );
  });

  test('setAppThemeScheme updates current scheme and theme seed color',
      () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    final netflixRed = AppThemeScheme.values.firstWhere(
      (scheme) => scheme.label == '奈飞红',
    );

    await service.setAppThemeScheme(netflixRed);

    expect(service.appThemeScheme, netflixRed);
    expect(
      service.lightTheme.colorScheme.primary,
      equals(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          brightness: Brightness.light,
        ).primary,
      ),
    );
  });

  test('light scaffold gradient starts from the active theme family', () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    final clearBlue = AppThemeScheme.values.firstWhere(
      (scheme) => scheme.label == '清澈蓝',
    );

    await service.setAppThemeScheme(clearBlue);

    expect(
      service.lightScaffoldGradientColors.first,
      equals(
        service.accentTint(
          0.045,
          brightness: Brightness.light,
          baseColor: Colors.white,
        ),
      ),
    );
    expect(
      service.lightScaffoldGradientColors.last,
      equals(
        service.accentTint(
          0.035,
          brightness: Brightness.light,
          baseColor: const Color(0xFFF8FCFF),
        ),
      ),
    );
  });

  test('selected card palette stays on a clean light tint in dark mode',
      () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    final netflixRed = AppThemeScheme.values.firstWhere(
      (scheme) => scheme.label == '奈飞红',
    );

    await service.setAppThemeScheme(netflixRed);

    expect(
      service.selectedCardSurface(brightness: Brightness.dark),
      equals(
        service.accentTint(
          0.09,
          brightness: Brightness.dark,
          baseColor: Colors.white,
        ),
      ),
    );
    expect(
      service.selectedCardBorder(brightness: Brightness.dark),
      equals(
        service.accentTint(
          0.46,
          brightness: Brightness.dark,
          baseColor: Colors.white,
        ),
      ),
    );
  });

  test('selected card palette keeps the same clean light base in light mode',
      () async {
    final service = ThemeService();
    await Future<void>.delayed(Duration.zero);

    final clearBlue = AppThemeScheme.values.firstWhere(
      (scheme) => scheme.label == '清澈蓝',
    );

    await service.setAppThemeScheme(clearBlue);

    expect(
      service.selectedCardSurface(brightness: Brightness.light),
      equals(
        service.accentTint(
          0.045,
          brightness: Brightness.light,
          baseColor: Colors.white,
        ),
      ),
    );
    expect(
      service.selectedCardBorder(brightness: Brightness.light),
      equals(
        service.accentTint(
          0.42,
          brightness: Brightness.light,
          baseColor: Colors.white,
        ),
      ),
    );
  });

  test('available app theme schemes stay limited to the clean cinema palette',
      () {
    expect(
      AppThemeScheme.values.map((scheme) => scheme.label),
      ['经典影院绿', '奈飞红', '清澈蓝'],
    );
  });
}
