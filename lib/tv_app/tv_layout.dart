/// TV 端页面布局常量。
///
/// 统一管理大屏页面的左右安全边距和纵向 Grid 列数，避免各页面手写魔法数。
class TvLayout {
  /// TV 布局工具类不允许实例化。
  const TvLayout._();

  /// TV 页面左右统一边距。
  ///
  /// 由原来的 72 缩小一半到 36，方便在 1080p 下容纳更多内容。
  static const double pageHorizontalPadding = 36.0;

  /// TV 纵向 Grid 固定列数。
  static const int gridCrossAxisCount = 7;
}
