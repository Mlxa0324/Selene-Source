import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/fullscreen_orientation_controller.dart';
import 'package:selene/services/mobile_orientation_service.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

void main() {
  test('retries Android side detection until a landscape side is confirmed',
      () async {
    final service = _FakeMobileOrientationService(
      autoRotateEnabled: false,
      orientationReads: [
        MobileInterfaceOrientation.unknown,
        MobileInterfaceOrientation.landscapeRight,
      ],
    );

    final controller = FullscreenOrientationController(
      orientationService: service,
      retryDelay: Duration.zero,
      retryTimeout: const Duration(milliseconds: 50),
    );

    final target = await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: false,
      lastAppliedOrientations: null,
    );

    expect(target, const [DeviceOrientation.landscapeRight]);
    expect(service.readCount, 2);
  });

  test('skips duplicate orientation sets', () async {
    final controller = FullscreenOrientationController(
      orientationService:
          _FakeMobileOrientationService(autoRotateEnabled: true),
      retryDelay: Duration.zero,
      retryTimeout: const Duration(milliseconds: 1),
    );

    final target = await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: false,
      lastAppliedOrientations: const [
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ],
    );

    expect(target, isNull);
  });

  test('does not accept landscape reads after timeout deadline', () async {
    final service = _FakeMobileOrientationService(
      autoRotateEnabled: false,
      orientationReads: [
        MobileInterfaceOrientation.unknown,
        MobileInterfaceOrientation.landscapeRight,
      ],
    );

    final controller = FullscreenOrientationController(
      orientationService: service,
      retryDelay: Duration.zero,
      retryTimeout: Duration.zero,
    );

    final target = await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: false,
      lastAppliedOrientations: null,
    );

    expect(target, isNull);
  });
}

class _FakeMobileOrientationService
    implements MobileOrientationServiceProtocol {
  _FakeMobileOrientationService({
    required this.autoRotateEnabled,
    this.orientationReads = const [MobileInterfaceOrientation.unknown],
  });

  final bool? autoRotateEnabled;
  final List<MobileInterfaceOrientation> orientationReads;

  int readCount = 0;
  int _index = 0;

  @override
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation() async {
    readCount += 1;
    if (_index >= orientationReads.length) {
      return orientationReads.last;
    }
    final current = orientationReads[_index];
    _index += 1;
    return current;
  }

  @override
  Future<bool?> getSystemAutoRotateEnabled() async {
    return autoRotateEnabled;
  }
}
