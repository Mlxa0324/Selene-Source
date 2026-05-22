import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:selene/config/device_mode_config.dart';
import 'package:selene/models/app_device_type.dart';

/// Android TV 原生判断函数。
///
/// 返回 true 表示当前 Android 设备应进入 TV 端入口。
typedef AndroidTvChecker = Future<bool> Function();

/// 应用设备类型识别服务。
///
/// 负责在启动阶段判断当前设备形态，并为入口分流提供稳定结果。
class AppDeviceService {
  /// 创建设备类型识别服务。
  ///
  /// [targetPlatform] 用于测试时注入目标平台。
  /// [androidTvChecker] 用于测试时替换原生 TV 判断。
  const AppDeviceService({
    TargetPlatform? targetPlatform,
    AndroidTvChecker? androidTvChecker,
    bool? forceTvMode,
  })  : _targetPlatform = targetPlatform,
        _androidTvChecker = androidTvChecker,
        _forceTvMode = forceTvMode;

  /// Android 设备能力通道名称。
  static const MethodChannel _deviceChannel = MethodChannel('selene/device');

  /// 测试注入的平台值。
  final TargetPlatform? _targetPlatform;

  /// 测试注入的 Android TV 判断函数。
  final AndroidTvChecker? _androidTvChecker;

  /// 测试注入或配置读取的强制 TV 模式开关。
  final bool? _forceTvMode;

  /// 识别当前设备类型。
  ///
  /// Android TV 由原生层判断；非 Android 平台不会调用 TV 判断。
  Future<AppDeviceType> resolveDeviceType() async {
    // 调试开关优先级最高，用于 BlueStacks 或平板强制进入 TV 壳。
    if (_forceTvMode ?? DeviceModeConfig.forceTvMode) {
      return AppDeviceType.tv;
    }

    final platform = _targetPlatform ?? defaultTargetPlatform;

    // 桌面平台直接归类为 desktop，避免误走 TV 分支。
    if (_isDesktopPlatform(platform)) {
      return AppDeviceType.desktop;
    }

    // 当前第一版只在 Android 上识别 TV，其他移动平台走普通端。
    if (platform != TargetPlatform.android) {
      return AppDeviceType.phone;
    }

    try {
      final isTv = await (_androidTvChecker ?? _readAndroidTvFromNative)();
      return isTv ? AppDeviceType.tv : AppDeviceType.phone;
    } catch (_) {
      // 原生能力异常时不阻塞启动，由上层降级到普通端。
      return AppDeviceType.unknown;
    }
  }

  /// 调用 Android 原生层读取 TV 能力。
  static Future<bool> _readAndroidTvFromNative() async {
    return await _deviceChannel.invokeMethod<bool>('isAndroidTv') ?? false;
  }

  /// 判断目标平台是否属于桌面端。
  static bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }
}
