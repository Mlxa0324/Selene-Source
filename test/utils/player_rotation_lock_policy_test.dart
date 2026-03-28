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

    test('已有已锁定方向时保持原方向，不被后续变化覆盖', () {
      expect(
        PlayerRotationLockPolicy.resolveCachedLockTarget(
          currentLockedOrientations: const [DeviceOrientation.landscapeRight],
          lastKnownInterfaceOrientation:
              MobileInterfaceOrientation.landscapeLeft,
          lastAppliedOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
        const [DeviceOrientation.landscapeRight],
      );
    });

    test('点击锁定时优先使用上次缓存的界面方向立即冻结', () {
      expect(
        PlayerRotationLockPolicy.resolveCachedLockTarget(
          currentLockedOrientations: null,
          lastKnownInterfaceOrientation:
              MobileInterfaceOrientation.landscapeLeft,
          lastAppliedOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
        const [DeviceOrientation.landscapeLeft],
      );
    });

    test('没有缓存方向时回退到最近一次单方向约束', () {
      expect(
        PlayerRotationLockPolicy.resolveCachedLockTarget(
          currentLockedOrientations: null,
          lastKnownInterfaceOrientation: null,
          lastAppliedOrientations: const [DeviceOrientation.landscapeRight],
        ),
        const [DeviceOrientation.landscapeRight],
      );
    });

    test('没有缓存方向且最近是多方向约束时，不猜测锁定方向', () {
      expect(
        PlayerRotationLockPolicy.resolveCachedLockTarget(
          currentLockedOrientations: null,
          lastKnownInterfaceOrientation: null,
          lastAppliedOrientations: const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
        ),
        isNull,
      );
    });
  });
}
