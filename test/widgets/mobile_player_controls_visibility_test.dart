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
}
