import 'package:flutter/services.dart';

import 'fullscreen_orientation_policy.dart';

class PlayerRotationLockPolicy {
  static List<DeviceOrientation>? resolve({
    required bool isLocked,
    required MobileInterfaceOrientation observedInterfaceOrientation,
    required MobileInterfaceOrientation? lastKnownInterfaceOrientation,
  }) {
    if (!isLocked) {
      return null;
    }

    final targetOrientation = observedInterfaceOrientation ==
            MobileInterfaceOrientation.unknown
        ? (lastKnownInterfaceOrientation ?? MobileInterfaceOrientation.unknown)
        : observedInterfaceOrientation;

    return switch (targetOrientation) {
      MobileInterfaceOrientation.portraitUp => const [
          DeviceOrientation.portraitUp,
        ],
      MobileInterfaceOrientation.portraitDown => const [
          DeviceOrientation.portraitDown,
        ],
      MobileInterfaceOrientation.landscapeLeft => const [
          DeviceOrientation.landscapeLeft,
        ],
      MobileInterfaceOrientation.landscapeRight => const [
          DeviceOrientation.landscapeRight,
        ],
      MobileInterfaceOrientation.unknown => null,
    };
  }
}
