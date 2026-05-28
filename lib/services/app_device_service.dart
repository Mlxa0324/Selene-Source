import 'dart:ui' as ui;

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
    double? shortestSideDp,
  })  : _targetPlatform = targetPlatform,
        _androidTvChecker = androidTvChecker,
        _forceTvMode = forceTvMode,
        _shortestSideDp = shortestSideDp;

  /// Android 设备能力通道名称。
  static const MethodChannel _deviceChannel = MethodChannel('selene/device');

  /// 平板与手机的最短边阈值。
  ///
  /// Flutter 生态通常使用 600dp 作为手机和平板的粗粒度分界线。
  static const double _tabletShortestSideBreakpointDp = 600;

  /// 测试注入的平台值。
  final TargetPlatform? _targetPlatform;

  /// 测试注入的 Android TV 判断函数。
  final AndroidTvChecker? _androidTvChecker;

  /// 测试注入或配置读取的强制 TV 模式开关。
  final bool? _forceTvMode;

  /// 测试注入的逻辑最短边尺寸。
  final double? _shortestSideDp;

  /// 识别当前设备类型。
  ///
  /// 该结果用于应用入口分流，会优先尊重强制 TV 调试开关。
  Future<AppDeviceType> resolveDeviceType() async {
    // 调试开关优先级最高，用于 BlueStacks 或平板强制进入 TV 壳。
    if (_forceTvMode ?? DeviceModeConfig.forceTvMode) {
      return AppDeviceType.tv;
    }

    return _resolvePhysicalDeviceType();
  }

  /// 识别当前设备的真实物理类型。
  ///
  /// 该结果不会受强制 TV 调试开关影响，可用于区分真 TV、平板和手机。
  Future<AppDeviceType> resolvePhysicalDeviceType() async {
    return _resolvePhysicalDeviceType();
  }

  /// 执行忽略强制 TV 开关的设备识别。
  Future<AppDeviceType> _resolvePhysicalDeviceType() async {
    final platform = _targetPlatform ?? defaultTargetPlatform;

    // 桌面平台直接归类为 desktop，避免误走 TV 分支。
    if (_isDesktopPlatform(platform)) {
      return AppDeviceType.desktop;
    }

    // iOS 等移动平台不需要原生 TV 判断，直接按屏幕尺寸区分手机和平板。
    if (platform != TargetPlatform.android) {
      return _resolveHandheldDeviceType();
    }

    try {
      final isTv = await (_androidTvChecker ?? _readAndroidTvFromNative)();
      if (isTv) {
        return AppDeviceType.tv;
      }

      // Android 非 TV 设备继续按屏幕尺寸区分手机和平板。
      return _resolveHandheldDeviceType();
    } catch (_) {
      // 原生能力异常时不阻塞启动，由上层降级到普通端。
      return AppDeviceType.unknown;
    }
  }

  /// 调用 Android 原生层读取 TV 能力。
  static Future<bool> _readAndroidTvFromNative() async {
    return await _deviceChannel.invokeMethod<bool>('isAndroidTv') ?? false;
  }

  /// 根据逻辑最短边区分手机和平板。
  AppDeviceType _resolveHandheldDeviceType() {
    final shortestSideDp = _shortestSideDp ?? _readLogicalShortestSideDp();
    if (shortestSideDp != null &&
        shortestSideDp >= _tabletShortestSideBreakpointDp) {
      return AppDeviceType.tablet;
    }

    return AppDeviceType.phone;
  }

  /// 读取当前窗口的逻辑最短边尺寸。
  static double? _readLogicalShortestSideDp() {
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isEmpty) {
      return null;
    }

    final firstView = views.first;
    if (firstView.devicePixelRatio <= 0) {
      return null;
    }

    return firstView.physicalSize.shortestSide / firstView.devicePixelRatio;
  }

  /// 判断目标平台是否属于桌面端。
  static bool _isDesktopPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }
}
