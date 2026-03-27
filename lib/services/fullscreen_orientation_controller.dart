import 'package:flutter/services.dart';
import 'package:selene/services/mobile_orientation_service.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

class FullscreenOrientationController {
  FullscreenOrientationController({
    required this.orientationService,
    this.retryDelay = const Duration(milliseconds: 50),
    this.retryTimeout = const Duration(milliseconds: 500),
  });

  final MobileOrientationServiceProtocol orientationService;
  final Duration retryDelay;
  final Duration retryTimeout;

  Future<List<DeviceOrientation>?> resolveAfterFullscreenEntry({
    required TargetPlatform platform,
    required bool isShortDramaPortraitFlow,
    required List<DeviceOrientation>? lastAppliedOrientations,
  }) async {
    final autoRotateEnabled = platform == TargetPlatform.android
        ? await orientationService.getSystemAutoRotateEnabled()
        : null;

    final observed =
        platform == TargetPlatform.android && autoRotateEnabled == false
            ? await _readBoundedLandscapeOrientation()
            : MobileInterfaceOrientation.unknown;

    final decision = FullscreenOrientationPolicy.resolve(
      isFullscreen: true,
      isEnteringFullscreen: false,
      isShortDramaPortraitFlow: isShortDramaPortraitFlow,
      platform: platform,
      observedInterfaceOrientation: observed,
      lastConfirmedLandscapeOrientation: observed.isLandscape ? observed : null,
      androidAutoRotateEnabled: autoRotateEnabled,
    );

    return _sameSet(
      decision.preferredOrientations,
      lastAppliedOrientations,
    )
        ? null
        : decision.preferredOrientations;
  }

  Future<MobileInterfaceOrientation> _readBoundedLandscapeOrientation() async {
    final deadline = DateTime.now().add(retryTimeout);
    var hasRetriedOnce = false;

    while (true) {
      final observed =
          await orientationService.getCurrentInterfaceOrientation();
      if (observed.isLandscape) {
        return observed;
      }

      if (hasRetriedOnce && DateTime.now().isAfter(deadline)) {
        return MobileInterfaceOrientation.unknown;
      }

      hasRetriedOnce = true;
      await Future<void>.delayed(retryDelay);
    }
  }

  bool _sameSet(
    List<DeviceOrientation>? a,
    List<DeviceOrientation>? b,
  ) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    if (a.length != b.length) {
      return false;
    }
    final sortedA = [...a]..sort((left, right) => left.index - right.index);
    final sortedB = [...b]..sort((left, right) => left.index - right.index);
    for (var index = 0; index < sortedA.length; index += 1) {
      if (sortedA[index] != sortedB[index]) {
        return false;
      }
    }
    return true;
  }
}
