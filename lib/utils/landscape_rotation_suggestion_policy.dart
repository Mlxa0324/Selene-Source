import 'package:flutter/services.dart';

import 'fullscreen_orientation_policy.dart';

/// 播放器横屏旋转提示按钮的显示策略。
class LandscapeRotationSuggestionPolicy {
  const LandscapeRotationSuggestionPolicy._();

  /// 判断当前场景是否需要显示横屏旋转提示按钮。
  ///
  /// [platform] 当前运行平台。
  /// [isTablet] 当前设备是否按平板布局处理。
  /// [isShortDramaPortraitFlow] 当前是否为短剧竖屏播放流。
  /// [isFullscreen] 播放器是否已经进入真全屏。
  /// [isEnteringLandscapeFullscreen] 播放器是否正在进入横屏全屏。
  /// [isPlayerRotationLocked] 播放器方向锁是否已开启。
  /// [androidAutoRotateEnabled] Android 系统自动旋转是否开启。
  /// [isCurrentInterfacePortrait] 当前播放器界面是否仍为竖屏。
  /// [physicalOrientation] 传感器检测到的物理设备方向。
  /// [currentFullscreenOrientations] 当前全屏锁定方向。
  static bool shouldShow({
    required TargetPlatform platform,
    required bool isTablet,
    required bool isShortDramaPortraitFlow,
    required bool isFullscreen,
    required bool isEnteringLandscapeFullscreen,
    required bool isPlayerRotationLocked,
    required bool? androidAutoRotateEnabled,
    required bool isCurrentInterfacePortrait,
    required MobileInterfaceOrientation physicalOrientation,
    required List<DeviceOrientation>? currentFullscreenOrientations,
  }) {
    // 当前只处理 Android 手机的系统旋转关闭场景，避免影响其他平台现有体验。
    if (platform != TargetPlatform.android) {
      return false;
    }

    // 平板、短剧、非全屏、全屏切换中或播放器锁定时不弹出额外入口。
    if (isTablet ||
        isShortDramaPortraitFlow ||
        !isFullscreen ||
        isEnteringLandscapeFullscreen ||
        isPlayerRotationLocked) {
      return false;
    }

    // 系统自动旋转开启时沿用系统行为，读取失败时也不额外干预。
    if (androidAutoRotateEnabled != false) {
      return false;
    }

    // 只处理全屏横屏内的横向侧切换，竖屏界面不显示按钮。
    if (isCurrentInterfacePortrait) {
      return false;
    }

    final targetOrientation = resolveTargetOrientation(physicalOrientation);
    final currentOrientation =
        _resolveSingleLandscapeOrientation(currentFullscreenOrientations);
    if (targetOrientation == null || currentOrientation == null) {
      return false;
    }

    return targetOrientation != currentOrientation;
  }

  /// 根据物理方向解析目标横屏方向。
  ///
  /// [physicalOrientation] 传感器检测到的物理设备方向。
  static DeviceOrientation? resolveTargetOrientation(
    MobileInterfaceOrientation physicalOrientation,
  ) {
    return switch (physicalOrientation) {
      MobileInterfaceOrientation.landscapeLeft =>
        DeviceOrientation.landscapeLeft,
      MobileInterfaceOrientation.landscapeRight =>
        DeviceOrientation.landscapeRight,
      _ => null,
    };
  }

  /// 解析当前已锁定的单一横屏方向。
  ///
  /// [orientations] 当前全屏方向约束。
  static DeviceOrientation? _resolveSingleLandscapeOrientation(
    List<DeviceOrientation>? orientations,
  ) {
    if (orientations == null || orientations.length != 1) {
      return null;
    }

    final orientation = orientations.single;
    if (orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight) {
      return orientation;
    }
    return null;
  }
}
