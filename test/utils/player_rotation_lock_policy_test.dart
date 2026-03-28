import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';
import 'package:selene/utils/player_rotation_lock_policy.dart';

void main() {
  group('PlayerRotationLockPolicy', () {
    test('未锁定时不返回方向约束', () {
      expect(
        PlayerRotationLockPolicy.resolve(
          isLocked: false,
          observedInterfaceOrientation:
              MobileInterfaceOrientation.landscapeLeft,
          lastKnownInterfaceOrientation: null,
        ),
        isNull,
      );
    });

    test('锁定时冻结当前横屏方向', () {
      expect(
        PlayerRotationLockPolicy.resolve(
          isLocked: true,
          observedInterfaceOrientation:
              MobileInterfaceOrientation.landscapeRight,
          lastKnownInterfaceOrientation: null,
        ),
        const [DeviceOrientation.landscapeRight],
      );
    });

    test('锁定时冻结当前竖屏方向', () {
      expect(
        PlayerRotationLockPolicy.resolve(
          isLocked: true,
          observedInterfaceOrientation: MobileInterfaceOrientation.portraitUp,
          lastKnownInterfaceOrientation: null,
        ),
        const [DeviceOrientation.portraitUp],
      );
    });

    test('当前方向未知时回退到上次已知方向', () {
      expect(
        PlayerRotationLockPolicy.resolve(
          isLocked: true,
          observedInterfaceOrientation: MobileInterfaceOrientation.unknown,
          lastKnownInterfaceOrientation:
              MobileInterfaceOrientation.landscapeLeft,
        ),
        const [DeviceOrientation.landscapeLeft],
      );
    });
  });
}
