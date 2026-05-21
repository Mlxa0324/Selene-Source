import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:selene/utils/fullscreen_orientation_policy.dart';

abstract class MobileOrientationServiceProtocol {
  /// 读取 Android 系统级自动旋转开关状态。
  Future<bool?> getSystemAutoRotateEnabled();

  /// 读取当前界面方向，用于全屏后锁定播放器方向。
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation();

  /// 监听物理设备方向，用于移动端系统未自动转屏时提示手动横屏。
  Stream<MobileInterfaceOrientation> watchPhysicalDeviceOrientation();
}

/// 移动端方向能力桥接服务。
class MobileOrientationService implements MobileOrientationServiceProtocol {
  const MobileOrientationService();

  static const MethodChannel _channel = MethodChannel('selene/orientation');
  static const EventChannel _physicalOrientationChannel =
      EventChannel('selene/physical_orientation');

  @override
  Future<bool?> getSystemAutoRotateEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _channel.invokeMethod<bool>('getSystemAutoRotateEnabled');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return MobileInterfaceOrientation.unknown;
    }
    try {
      final raw = await _channel.invokeMethod<String>(
        'getCurrentInterfaceOrientation',
      );
      return parseMobileInterfaceOrientation(raw);
    } catch (_) {
      return MobileInterfaceOrientation.unknown;
    }
  }

  @override
  Stream<MobileInterfaceOrientation> watchPhysicalDeviceOrientation() {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const Stream<MobileInterfaceOrientation>.empty();
    }

    return _physicalOrientationChannel
        .receiveBroadcastStream()
        .map((raw) => parseMobileInterfaceOrientation(raw as String?))
        .where(
            (orientation) => orientation != MobileInterfaceOrientation.unknown)
        .distinct();
  }
}

/// 将原生方向字符串转换为播放器内部方向枚举。
///
/// [raw] 原生平台返回的方向名称。
@visibleForTesting
MobileInterfaceOrientation parseMobileInterfaceOrientation(String? raw) {
  return MobileInterfaceOrientation.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => MobileInterfaceOrientation.unknown,
  );
}
