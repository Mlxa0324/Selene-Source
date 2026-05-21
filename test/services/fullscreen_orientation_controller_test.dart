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
    expect(service.interfaceReadCount, 2);
    expect(service.autoRotateReadCount, 1);
  });

  test('skips duplicate orientation sets', () async {
    final service = _FakeMobileOrientationService(autoRotateEnabled: true);
    final controller = FullscreenOrientationController(
      orientationService: service,
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
    expect(service.autoRotateReadCount, 1);
    expect(service.interfaceReadCount, 0);
  });

  test('skips interface reads when Android auto-rotate state is unknown',
      () async {
    final service = _FakeMobileOrientationService(autoRotateEnabled: null);
    final controller = FullscreenOrientationController(
      orientationService: service,
      retryDelay: Duration.zero,
      retryTimeout: const Duration(milliseconds: 1),
    );

    final target = await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: false,
      lastAppliedOrientations: null,
    );

    expect(target, isNull);
    expect(service.autoRotateReadCount, 1);
    expect(service.interfaceReadCount, 0);
  });

  test('returns null when Android auto-rotate state is unavailable', () async {
    final controller = FullscreenOrientationController(
      orientationService: _FakeMobileOrientationService(
        autoRotateEnabled: null,
        orientationReads: [MobileInterfaceOrientation.landscapeLeft],
      ),
      retryDelay: Duration.zero,
      retryTimeout: Duration.zero,
    );

    expect(
      await controller.resolveAfterFullscreenEntry(
        platform: TargetPlatform.android,
        isShortDramaPortraitFlow: false,
        lastAppliedOrientations: null,
      ),
      isNull,
    );
  });

  test('short drama flow bypasses Android bridge reads', () async {
    final service = _FakeMobileOrientationService(
      autoRotateEnabled: false,
      orientationReads: const [MobileInterfaceOrientation.landscapeLeft],
    );
    final controller = FullscreenOrientationController(
      orientationService: service,
      retryDelay: Duration.zero,
      retryTimeout: const Duration(milliseconds: 50),
    );

    final target = await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: true,
      lastAppliedOrientations: null,
    );

    expect(target, isNull);
    expect(service.autoRotateReadCount, 0);
    expect(service.interfaceReadCount, 0);
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

  int autoRotateReadCount = 0;
  int interfaceReadCount = 0;
  int _index = 0;

  @override
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation() async {
    interfaceReadCount += 1;
    if (_index >= orientationReads.length) {
      return orientationReads.last;
    }
    final current = orientationReads[_index];
    _index += 1;
    return current;
  }

  @override
  Future<bool?> getSystemAutoRotateEnabled() async {
    autoRotateReadCount += 1;
    return autoRotateEnabled;
  }

  @override
  Stream<MobileInterfaceOrientation> watchPhysicalDeviceOrientation() {
    return const Stream<MobileInterfaceOrientation>.empty();
  }
}
