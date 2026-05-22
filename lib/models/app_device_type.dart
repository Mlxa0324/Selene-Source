/// 应用运行设备类型。
///
/// 用于启动阶段选择普通端入口或 TV 端入口。
enum AppDeviceType {
  /// 手机设备，默认走现有移动端逻辑。
  phone,

  /// 平板设备，保留给后续更精细的布局分流。
  tablet,

  /// Android TV 或电视盒子设备，进入 TV 独立入口。
  tv,

  /// 桌面设备，包含 Windows、macOS、Linux。
  desktop,

  /// 无法判断的设备类型，启动时降级走普通端逻辑。
  unknown,
}
