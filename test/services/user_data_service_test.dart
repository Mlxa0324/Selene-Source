import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserDataService screen-off playback setting', () {
    test('persists and reads enabled state', () async {
      await UserDataService.saveScreenOffPlaybackEnabled(true);

      expect(await UserDataService.getScreenOffPlaybackEnabled(), isTrue);
      expect(UserDataService.getScreenOffPlaybackEnabledSync(), isTrue);
    });

    test('defaults to disabled when unset', () async {
      expect(await UserDataService.getScreenOffPlaybackEnabled(), isFalse);
      expect(UserDataService.getScreenOffPlaybackEnabledSync(), isFalse);
    });
  });
}
