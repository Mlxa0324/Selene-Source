import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/config/device_mode_config.dart';
import 'package:selene/models/app_device_type.dart';
import 'package:selene/services/app_device_service.dart';

void main() {
  group('AppDeviceService', () {
    test('force TV mode config defaults to auto detect', () {
      expect(DeviceModeConfig.forceTvMode, isFalse);
    });

    test('resolves TV when force TV mode is enabled', () async {
      var called = false;
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: true,
        androidTvChecker: () async {
          called = true;
          return false;
        },
      );

      expect(await service.resolveDeviceType(), AppDeviceType.tv);
      expect(called, isFalse);
    });

    test('resolves Android TV when native checker returns true', () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        androidTvChecker: () async => true,
      );

      expect(await service.resolveDeviceType(), AppDeviceType.tv);
    });

    test('resolves Android phone when native checker returns false',
        () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        shortestSideDp: 411,
        androidTvChecker: () async => false,
      );

      expect(await service.resolveDeviceType(), AppDeviceType.phone);
    });

    test('resolves physical Android tablet when shortest side is wide',
        () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        shortestSideDp: 720,
        androidTvChecker: () async => false,
      );

      expect(
        await service.resolvePhysicalDeviceType(),
        AppDeviceType.tablet,
      );
    });

    test('resolves physical Android phone when shortest side is narrow',
        () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        shortestSideDp: 411,
        androidTvChecker: () async => false,
      );

      expect(
        await service.resolvePhysicalDeviceType(),
        AppDeviceType.phone,
      );
    });

    test('resolves physical iOS tablet from shortest side', () async {
      const service = AppDeviceService(
        targetPlatform: TargetPlatform.iOS,
        forceTvMode: false,
        shortestSideDp: 768,
      );

      expect(
        await service.resolvePhysicalDeviceType(),
        AppDeviceType.tablet,
      );
    });

    test('ignores force TV mode when resolving physical device type',
        () async {
      var called = false;
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: true,
        shortestSideDp: 720,
        androidTvChecker: () async {
          called = true;
          return false;
        },
      );

      expect(
        await service.resolvePhysicalDeviceType(),
        AppDeviceType.tablet,
      );
      expect(called, isTrue);
    });

    test('resolves desktop platforms without calling Android checker',
        () async {
      var called = false;
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.macOS,
        forceTvMode: false,
        androidTvChecker: () async {
          called = true;
          return true;
        },
      );

      expect(await service.resolveDeviceType(), AppDeviceType.desktop);
      expect(called, isFalse);
    });

    test('resolves unknown when Android native checker fails', () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        androidTvChecker: () async {
          throw Exception('native unavailable');
        },
      );

      expect(await service.resolveDeviceType(), AppDeviceType.unknown);
    });
  });
}
