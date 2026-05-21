import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';
import 'package:selene/utils/landscape_rotation_suggestion_policy.dart';

void main() {
  group('LandscapeRotationSuggestionPolicy.shouldShow', () {
    test('hides on portrait player even when phone is held landscape', () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.android,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: false,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: false,
          isCurrentInterfacePortrait: true,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.unknown,
          currentFullscreenOrientations: null,
        ),
        isFalse,
      );
    });

    test('shows in fullscreen when held landscape side differs from lock', () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.android,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: true,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: false,
          isCurrentInterfacePortrait: false,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.unknown,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeRight,
          ],
        ),
        isTrue,
      );
    });

    test('hides in fullscreen when held landscape side matches lock', () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.android,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: true,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: false,
          isCurrentInterfacePortrait: false,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.unknown,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeLeft,
          ],
        ),
        isFalse,
      );
    });

    test('hides when system auto-rotate is enabled', () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.android,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: false,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: true,
          isCurrentInterfacePortrait: true,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.unknown,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeRight,
          ],
        ),
        isFalse,
      );
    });

    test('hides when player rotation is locked', () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.android,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: false,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: true,
          androidAutoRotateEnabled: false,
          isCurrentInterfacePortrait: true,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.unknown,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeRight,
          ],
        ),
        isFalse,
      );
    });

    test('shows on iOS fullscreen when physical side differs from interface',
        () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.iOS,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: true,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: null,
          isCurrentInterfacePortrait: false,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation:
              MobileInterfaceOrientation.landscapeRight,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
        isTrue,
      );
    });

    test('hides on iOS fullscreen when system already matched physical side',
        () {
      expect(
        LandscapeRotationSuggestionPolicy.shouldShow(
          platform: TargetPlatform.iOS,
          isTablet: false,
          isShortDramaPortraitFlow: false,
          isFullscreen: true,
          isEnteringLandscapeFullscreen: false,
          isPlayerRotationLocked: false,
          androidAutoRotateEnabled: null,
          isCurrentInterfacePortrait: false,
          physicalOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentInterfaceOrientation: MobileInterfaceOrientation.landscapeLeft,
          currentFullscreenOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
        isFalse,
      );
    });
  });

  group('LandscapeRotationSuggestionPolicy.resolveTargetOrientation', () {
    test('maps physical landscape direction to device orientation', () {
      expect(
        LandscapeRotationSuggestionPolicy.resolveTargetOrientation(
          MobileInterfaceOrientation.landscapeLeft,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        LandscapeRotationSuggestionPolicy.resolveTargetOrientation(
          MobileInterfaceOrientation.landscapeRight,
        ),
        DeviceOrientation.landscapeRight,
      );
    });

    test('returns null for portrait physical direction', () {
      expect(
        LandscapeRotationSuggestionPolicy.resolveTargetOrientation(
          MobileInterfaceOrientation.portraitUp,
        ),
        isNull,
      );
    });
  });
}
