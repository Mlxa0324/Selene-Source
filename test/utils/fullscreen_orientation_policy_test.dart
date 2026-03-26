import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

void main() {
  group('FullscreenOrientationPolicy', () {
    test('returns both landscape orientations for iOS fullscreen', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.iOS,
        observedInterfaceOrientation:
            MobileInterfaceOrientation.landscapeLeft,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: null,
      );

      expect(
        decision.preferredOrientations,
        const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    });

    test('locks Android fullscreen to the confirmed side when auto-rotate is off',
        () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.android,
        observedInterfaceOrientation:
            MobileInterfaceOrientation.landscapeRight,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: false,
      );

      expect(
        decision.preferredOrientations,
        const [DeviceOrientation.landscapeRight],
      );
    });

    test('returns both landscape orientations for Android when auto-rotate is on', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.android,
        observedInterfaceOrientation:
            MobileInterfaceOrientation.landscapeLeft,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: true,
      );

      expect(
        decision.preferredOrientations,
        const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    });

    test('abandons locking when not in fullscreen', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: false,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.iOS,
        observedInterfaceOrientation:
            MobileInterfaceOrientation.landscapeLeft,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: null,
      );

      expect(decision.preferredOrientations, isNull);
    });

    test('returns null when short drama portrait flow is active', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: true,
        platform: TargetPlatform.android,
        observedInterfaceOrientation:
            MobileInterfaceOrientation.landscapeRight,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: false,
      );

      expect(decision.preferredOrientations, isNull);
    });

    test('uses last confirmed orientation when observation is unknown', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.android,
        observedInterfaceOrientation: MobileInterfaceOrientation.unknown,
        lastConfirmedLandscapeOrientation:
            MobileInterfaceOrientation.landscapeLeft,
        androidAutoRotateEnabled: false,
      );

      expect(
        decision.preferredOrientations,
        const [DeviceOrientation.landscapeLeft],
      );
    });

    test('returns null when no orientation can be determined', () {
      final decision = FullscreenOrientationPolicy.resolve(
        isFullscreen: true,
        isEnteringFullscreen: false,
        isShortDramaPortraitFlow: false,
        platform: TargetPlatform.android,
        observedInterfaceOrientation: MobileInterfaceOrientation.unknown,
        lastConfirmedLandscapeOrientation: null,
        androidAutoRotateEnabled: false,
      );

      expect(decision.preferredOrientations, isNull);
    });
  });
}
