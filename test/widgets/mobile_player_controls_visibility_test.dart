import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/mobile_player_controls.dart';

void main() {
  group('shouldShowEpisodeSourceButtons', () {
    test('keeps quick actions on phone landscape even before true fullscreen',
        () {
      expect(
        shouldShowEpisodeSourceButtons(
          isTabletOrDesktop: false,
          isEffectiveFullscreen: true,
          isFullscreen: false,
        ),
        isTrue,
      );
    });

    test('hides quick actions on tablet or desktop when not truly fullscreen',
        () {
      expect(
        shouldShowEpisodeSourceButtons(
          isTabletOrDesktop: true,
          isEffectiveFullscreen: true,
          isFullscreen: false,
        ),
        isFalse,
      );
    });

    test('shows quick actions on tablet or desktop after entering fullscreen',
        () {
      expect(
        shouldShowEpisodeSourceButtons(
          isTabletOrDesktop: true,
          isEffectiveFullscreen: true,
          isFullscreen: true,
        ),
        isTrue,
      );
    });
  });

  group('shouldShowCenterControls', () {
    test('hides center controls with top and bottom controls by default', () {
      expect(
        shouldShowCenterControls(
          isPipMode: false,
          isLocked: false,
          isPlaying: false,
          controlsVisible: false,
          hideWithControls: true,
        ),
        isFalse,
      );
    });

    test('keeps center controls visible while paused when linked hiding is off',
        () {
      expect(
        shouldShowCenterControls(
          isPipMode: false,
          isLocked: false,
          isPlaying: false,
          controlsVisible: false,
          hideWithControls: false,
        ),
        isTrue,
      );
    });

    test('still hides center controls during playback when controls are hidden',
        () {
      expect(
        shouldShowCenterControls(
          isPipMode: false,
          isLocked: false,
          isPlaying: true,
          controlsVisible: false,
          hideWithControls: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldIgnoreTransientPauseUi', () {
    test('ignores pause UI while seek state is still settling', () {
      expect(
        shouldIgnoreTransientPauseUi(
          isSeekingViaSwipe: false,
          isDraggingProgressBar: false,
          hasPendingDragPosition: true,
        ),
        isTrue,
      );
    });

    test('allows normal pause UI after seek state clears', () {
      expect(
        shouldIgnoreTransientPauseUi(
          isSeekingViaSwipe: false,
          isDraggingProgressBar: false,
          hasPendingDragPosition: false,
        ),
        isFalse,
      );
    });
  });
}
