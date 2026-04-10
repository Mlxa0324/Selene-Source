import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/services/user_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getPlaybackPreloadEnabled defaults to true when nothing is stored',
      () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getPlaybackPreloadEnabled(),
      isTrue,
    );
  });

  test('getPlaybackPreloadEnabled falls back to legacy media kit key',
      () async {
    SharedPreferences.setMockInitialValues({
      'media_kit_preload_enabled': false,
    });

    expect(
      await UserDataService.getPlaybackPreloadEnabled(),
      isFalse,
    );
  });

  test('savePlaybackPreloadEnabled writes the unified key', () async {
    SharedPreferences.setMockInitialValues({});

    await UserDataService.savePlaybackPreloadEnabled(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('playback_preload_enabled_v1'), isFalse);
  });
}
