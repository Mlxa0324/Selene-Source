/// TV 端在线播放内核类型。
///
/// Flutter TV 当前支持 `Exo` 与 `WebView` 两种实现：
/// - `Exo` 走 Android 原生 `video_player` / ExoPlayer 后端
/// - `WebView` 走现有 `InAppWebView + hls.js` 链路
enum TvPlayerKernel {
  /// Android 原生 ExoPlayer 内核。
  exo(
    key: 'exo',
    label: 'Exo',
  ),

  /// WebView + hls.js 内核。
  webView(
    key: 'webview',
    label: 'WebView',
  );

  /// 创建 TV 播放内核枚举值。
  const TvPlayerKernel({
    required this.key,
    required this.label,
  });

  /// 持久化使用的稳定 Key。
  final String key;

  /// 设置页展示名称。
  final String label;

  /// 根据持久化 Key 解析 TV 播放内核。
  static TvPlayerKernel fromKey(String? key) {
    for (final value in TvPlayerKernel.values) {
      if (value.key == key) {
        return value;
      }
    }
    return TvPlayerKernel.exo;
  }
}
