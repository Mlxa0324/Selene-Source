# 修复手机端预加载进度条偶发不执行 - Implement

## Checklist

- [x] 在 WebView HLS HTML 生成测试中添加红测，锁定 `FRAG_LOADED` 后必须调用 `emitBufferedRanges()`。
- [x] 修改 `lib/widgets/player_adapter.dart`，在 HLS 分片加载完成回调中同步上报缓存区间。
- [x] 添加切源监听恢复红测，锁定复用 WebView 且预加载开启时必须恢复 `cachedRanges` 订阅。
- [x] 修改 `lib/widgets/video_player_widget.dart`，在 WebView `updateSource()` 后重新 `_setupCachedRangesListener()`。
- [x] 确认上一轮 seek warmup / preload buffer 断言仍通过。
- [x] 运行相关测试：
  - `flutter test test/widgets/player_adapter_webview_preload_test.dart`
  - `flutter test test/widgets/video_player_widget_preload_config_test.dart`
  - `flutter test test/widgets/mobile_player_controls_seek_test.dart`
- [x] 运行分析：
  - `flutter analyze lib/widgets/player_adapter.dart lib/widgets/video_player_widget.dart test/widgets/player_adapter_webview_preload_test.dart test/widgets/video_player_widget_preload_config_test.dart test/widgets/mobile_player_controls_seek_test.dart`
- [x] 检查 diff，避免触碰无关 TV/Kotlin 改动。

## Risk Notes

- `player_adapter.dart` 里 HTML 字符串较长，修改时只动 HLS `FRAG_LOADED` 回调。
- 不要把 `emitBufferedRanges()` 放到高频 timer，避免桥接事件过多。
- 不要改 `VideoPlayerWidget._recordCachedRanges()` 的空列表处理；它当前用于保护已持久化缓存段。
