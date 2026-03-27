import 'package:flutter/services.dart';

enum MobileInterfaceOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
  unknown,
}

extension MobileInterfaceOrientationX on MobileInterfaceOrientation {
  bool get isLandscape =>
      this == MobileInterfaceOrientation.landscapeLeft ||
      this == MobileInterfaceOrientation.landscapeRight;
}

class FullscreenOrientationDecision {
  const FullscreenOrientationDecision(this.preferredOrientations);

  final List<DeviceOrientation>? preferredOrientations;
}

class FullscreenOrientationPolicy {
  static FullscreenOrientationDecision resolve({
    required bool isFullscreen,
    required bool isEnteringFullscreen,
    required bool isShortDramaPortraitFlow,
    required TargetPlatform platform,
    required MobileInterfaceOrientation observedInterfaceOrientation,
    required MobileInterfaceOrientation? lastConfirmedLandscapeOrientation,
    required bool? androidAutoRotateEnabled,
  }) {
    if (!isFullscreen || isEnteringFullscreen || isShortDramaPortraitFlow) {
      return const FullscreenOrientationDecision(null);
    }

    if (platform == TargetPlatform.iOS) {
      return const FullscreenOrientationDecision([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (platform == TargetPlatform.android &&
        androidAutoRotateEnabled == true) {
      return const FullscreenOrientationDecision([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (platform == TargetPlatform.android &&
        androidAutoRotateEnabled == null) {
      return const FullscreenOrientationDecision(null);
    }

    final lockedSide = switch (observedInterfaceOrientation) {
      MobileInterfaceOrientation.landscapeLeft =>
        DeviceOrientation.landscapeLeft,
      MobileInterfaceOrientation.landscapeRight =>
        DeviceOrientation.landscapeRight,
      _ => switch (lastConfirmedLandscapeOrientation) {
          MobileInterfaceOrientation.landscapeLeft =>
            DeviceOrientation.landscapeLeft,
          MobileInterfaceOrientation.landscapeRight =>
            DeviceOrientation.landscapeRight,
          _ => null,
        },
    };

    return FullscreenOrientationDecision(
      lockedSide == null ? null : [lockedSide],
    );
  }
}
