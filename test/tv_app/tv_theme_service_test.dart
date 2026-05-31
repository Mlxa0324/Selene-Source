import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('TV theme palette resolves Netflix red', () {
    final palette = TvThemePalette.fromKey(TvThemePalette.netflixRedKey);

    expect(palette.label, '奈飞红');
    expect(palette.accent.toARGB32(), 0xFFE50914);
  });

  test('TV theme palette resolves soft blue', () {
    final palette = TvThemePalette.fromKey(TvThemePalette.softBlueKey);

    expect(palette.label, '柔和蓝');
    expect(palette.accent.toARGB32(), 0xFF5B7CFA);
    expect(TvThemePalette.values, contains(TvThemePalette.ivyGreen));
    expect(TvThemePalette.values, contains(TvThemePalette.netflixRed));
    expect(TvThemePalette.values, contains(TvThemePalette.softBlue));
  });

  test('TV theme shared colors match TV visual contract', () {
    expect(TvThemeBackground.deepBlue.color.toARGB32(), 0xFF1A1D29);
    expect(TvThemeColors.cardSurface.toARGB32(), 0xFF4B4E5A);
  });

  test('TV theme service persists selected theme key', () async {
    SharedPreferences.setMockInitialValues({});

    await TvThemeService.saveThemeKey(TvThemePalette.netflixRedKey);

    expect(
        await TvThemeService.loadSavedThemeKey(), TvThemePalette.netflixRedKey);
  });

  test('TV theme service uses Netflix red as default theme key', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await TvThemeService.loadSavedThemeKey(),
      TvThemePalette.netflixRedKey,
    );
  });

  test('TV theme service persists selected background key', () async {
    SharedPreferences.setMockInitialValues({});

    await TvThemeService.saveBackgroundKey(TvThemeBackground.deepBlack.key);

    expect(
      await TvThemeService.loadSavedBackgroundKey(),
      TvThemeBackground.deepBlack.key,
    );
  });

  test('TV theme service persists selected focus effect mode', () async {
    SharedPreferences.setMockInitialValues({});

    await TvThemeService.saveFocusEffectModeKey(
      TvFocusEffectMode.magnifier.key,
    );

    expect(
      await TvThemeService.loadSavedFocusEffectModeKey(),
      TvFocusEffectMode.magnifier.key,
    );
  });

  test('TV focus effect defaults to magnifier and lists it first', () async {
    SharedPreferences.setMockInitialValues({});

    expect(TvFocusEffectMode.values.first, TvFocusEffectMode.magnifier);
    expect(
      await TvThemeService.loadSavedFocusEffectModeKey(),
      TvFocusEffectMode.magnifier.key,
    );
  });

  testWidgets('TV theme background falls back to deep blue without scope',
      (tester) async {
    Color? resolvedColor;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolvedColor = TvTheme.backgroundOf(context).color;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedColor, TvThemeBackground.deepBlue.color);
  });

  testWidgets('TV theme background reads current scope background',
      (tester) async {
    Color? resolvedColor;
    final service = TvThemeService();

    SharedPreferences.setMockInitialValues({});
    await service.setBackgroundKey(TvThemeBackground.deepBlack.key);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: service,
          child: Builder(
            builder: (context) {
              resolvedColor = TvTheme.backgroundOf(context).color;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(resolvedColor, TvThemeBackground.deepBlack.color);
  });

  testWidgets('TV focus effect reads current scope mode', (tester) async {
    TvFocusEffectMode? resolvedMode;
    final service = TvThemeService();

    SharedPreferences.setMockInitialValues({});
    await service.setFocusEffectModeKey(TvFocusEffectMode.magnifier.key);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: service,
          child: Builder(
            builder: (context) {
              resolvedMode = TvTheme.focusEffectModeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(resolvedMode, TvFocusEffectMode.magnifier);
  });
}
