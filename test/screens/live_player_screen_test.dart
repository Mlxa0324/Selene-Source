import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/screens/live_player_screen.dart';

void main() {
  test('live fullscreen prefers clockwise landscape rotation on phone', () {
    expect(
      resolveLiveInitialFullscreenOrientations(isTablet: false),
      const [
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ],
    );
  });

  test('live fullscreen also keeps clockwise preference on tablet', () {
    expect(
      resolveLiveInitialFullscreenOrientations(isTablet: true),
      const [
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ],
    );
  });
}
