import 'package:selene/models/app_theme_scheme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/playback_preload.dart';
import 'package:selene/services/user_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getPlaybackPreloadLevel defaults to medium when nothing is stored',
      () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.medium,
    );
  });

  test('getAdFilterEnabled defaults to true when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getAdFilterEnabled(),
      isTrue,
    );
  });

  test('getPlaybackPreloadLevel falls back to legacy unified bool key',
      () async {
    SharedPreferences.setMockInitialValues({
      'playback_preload_enabled_v1': false,
    });

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.off,
    );
  });

  test('getPlaybackPreloadLevel falls back to legacy media kit key', () async {
    SharedPreferences.setMockInitialValues({
      'media_kit_preload_enabled': false,
    });

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.off,
    );
  });

  test('savePlaybackPreloadLevel writes the unified level key', () async {
    SharedPreferences.setMockInitialValues({});

    await UserDataService.savePlaybackPreloadLevel(PlaybackPreloadLevel.medium);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('playback_preload_level_v1'), 'medium');
  });

  test('getAppThemeScheme defaults to classic green when nothing is stored',
      () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getAppThemeScheme(),
      AppThemeScheme.classicGreen,
    );
  });

  test('saveAppThemeScheme writes the selected theme scheme key', () async {
    SharedPreferences.setMockInitialValues({});

    await UserDataService.saveAppThemeScheme(AppThemeScheme.oceanBlue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme_scheme_v1'), 'ocean_blue');
  });
}
