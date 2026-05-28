/// 设备模式调试配置。
///
/// 用于 BlueStacks、平板或其他无法被 Android 原生层识别为 TV 的环境。
class DeviceModeConfig {
  /// 是否强制进入 TV 模式。
  ///
  /// 默认关闭，保持自动识别。调试 BlueStacks TV 模式时可使用：
  /// `flutter run --dart-define=SELENE_FORCE_TV_MODE=true`
  ///
  /// 如果需要长期固定，也可以把 [defaultValue] 改成 true。
  static const bool forceTvMode = bool.fromEnvironment(
    'SELENE_FORCE_TV_MODE',
    defaultValue: false,
  );
}
