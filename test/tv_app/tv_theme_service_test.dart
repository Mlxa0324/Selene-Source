import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('TV theme palette resolves Netflix red', () {
    final palette = TvThemePalette.fromKey(TvThemePalette.netflixRedKey);

    expect(palette.label, '奈飞红');
    expect(palette.accent.toARGB32(), 0xFFE50914);
  });

  test('TV theme service persists selected theme key', () async {
    SharedPreferences.setMockInitialValues({});

    await TvThemeService.saveThemeKey(TvThemePalette.netflixRedKey);

    expect(
        await TvThemeService.loadSavedThemeKey(), TvThemePalette.netflixRedKey);
  });
}
