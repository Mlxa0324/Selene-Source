/// 设备模式调试配置。
///
/// 用于 BlueStacks、平板或其他无法被 Android 原生层识别为 TV 的环境。
class DeviceModeConfig {
  /// 本地调试是否强制进入 TV 模式。
  ///
  /// 默认关闭，保持自动识别。需要在本机直接把平板切到 TV 模式时，
  /// 把这里临时改成 true 即可。
  static const bool localDebugForceTvMode = false;

  /// `dart-define` 强制 TV 模式开关。
  ///
  /// 适合命令行或 CI 场景按需覆盖。
  static const bool dartDefineForceTvMode = bool.fromEnvironment(
    'SELENE_FORCE_TV_MODE',
    defaultValue: false,
  );

  /// 是否强制进入 TV 模式。
  ///
  /// 只要本地调试开关或 `dart-define` 任一开启，就会强制进入 TV 壳。
  static const bool forceTvMode =
      localDebugForceTvMode || dartDefineForceTvMode;
}
