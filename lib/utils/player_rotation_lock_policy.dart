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

  static List<DeviceOrientation>? resolveCachedLockTarget({
    required List<DeviceOrientation>? currentLockedOrientations,
    required MobileInterfaceOrientation? lastKnownInterfaceOrientation,
    required List<DeviceOrientation>? lastAppliedOrientations,
  }) {
    if (currentLockedOrientations != null &&
        currentLockedOrientations.isNotEmpty) {
      return List<DeviceOrientation>.unmodifiable(currentLockedOrientations);
    }

    final cachedFromInterface = resolve(
      isLocked: true,
      observedInterfaceOrientation: MobileInterfaceOrientation.unknown,
      lastKnownInterfaceOrientation: lastKnownInterfaceOrientation,
    );
    if (cachedFromInterface != null) {
      return cachedFromInterface;
    }

    if (lastAppliedOrientations != null &&
        lastAppliedOrientations.length == 1) {
      return List<DeviceOrientation>.unmodifiable(lastAppliedOrientations);
    }

    return null;
  }

  static List<DeviceOrientation>? resolveInitialLockTarget({
    required MobileInterfaceOrientation observedInterfaceOrientation,
    required MobileInterfaceOrientation? lastKnownInterfaceOrientation,
    required List<DeviceOrientation>? lastAppliedOrientations,
  }) {
    if (observedInterfaceOrientation != MobileInterfaceOrientation.unknown) {
      return resolve(
        isLocked: true,
        observedInterfaceOrientation: observedInterfaceOrientation,
        lastKnownInterfaceOrientation: lastKnownInterfaceOrientation,
      );
    }

    return resolveCachedLockTarget(
      currentLockedOrientations: null,
      lastKnownInterfaceOrientation: lastKnownInterfaceOrientation,
      lastAppliedOrientations: lastAppliedOrientations,
    );
  }
}
