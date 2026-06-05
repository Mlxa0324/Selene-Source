/// TV 端页面布局常量。
///
/// 统一管理大屏页面的左右安全边距和纵向 Grid 列数，避免各页面手写魔法数。
class TvLayout {
  /// TV 布局工具类不允许实例化。
  const TvLayout._();

  /// TV 页面左右统一边距。
  ///
  /// 横向列表可在此基础上追加焦点安全留白，避免获焦放大时被裁切。
  static const double pageHorizontalPadding = 46.0;

  /// TV 纵向 Grid 固定列数。
  static const int gridCrossAxisCount = 7;
}
