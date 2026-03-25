import 'package:flutter_test/flutter_test.dart';
import 'package:selene/config/player_backend_config.dart';

void main() {
  group('PlayerBackendConfig', () {
    test('keeps Android online playback on WebView by default', () {
      expect(
        PlayerBackendConfig
            .shouldUseMediaKitForMobileNetworkPlaybackForPlatform(
          isAndroid: true,
          isIOS: false,
        ),
        isFalse,
      );
    });

    test(
        'keeps Android online playback on WebView when screen-off playback is enabled',
        () {
      expect(
        PlayerBackendConfig
            .shouldUseMediaKitForMobileNetworkPlaybackForPlatform(
          isAndroid: true,
          isIOS: false,
          preferAndroidScreenOffPlayback: true,
        ),
        isFalse,
      );
    });

    test('does not let Android screen-off setting affect iOS backend', () {
      expect(
        PlayerBackendConfig
            .shouldUseMediaKitForMobileNetworkPlaybackForPlatform(
          isAndroid: false,
          isIOS: true,
          preferAndroidScreenOffPlayback: true,
        ),
        isFalse,
      );
    });
  });
}
