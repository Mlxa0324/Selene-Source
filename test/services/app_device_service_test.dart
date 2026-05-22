import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/config/device_mode_config.dart';
import 'package:selene/models/app_device_type.dart';
import 'package:selene/services/app_device_service.dart';

void main() {
  group('AppDeviceService', () {
    test('force TV mode config follows debug default', () {
      expect(DeviceModeConfig.forceTvMode, kDebugMode);
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

    test('resolves Android phone when native checker returns false', () async {
      final service = AppDeviceService(
        targetPlatform: TargetPlatform.android,
        forceTvMode: false,
        androidTvChecker: () async => false,
      );

      expect(await service.resolveDeviceType(), AppDeviceType.phone);
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
