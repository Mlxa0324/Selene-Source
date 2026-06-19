# 修复 iOS 暂停数分钟后恢复播放卡转圈 - Implement

## Checklist

- [x] 增加 WebView 恢复播放 HTML/桥接红测。
- [x] 将 `WebViewPlayerAdapter.play()` 改为调用 `window.resumePlaybackFromPause()`，保留函数不存在时的 `player.play()` 回退。
- [x] 在生成 HTML 中添加 `resumePlaybackFromPause()` 和短延迟恢复检查。
- [x] 确认 Android 复用逻辑不依赖 iOS 专属 API。
- [x] 运行验证：
  - `flutter test test/widgets/player_adapter_webview_preload_test.dart`
  - `flutter test test/widgets/video_player_widget_preload_config_test.dart`
  - `flutter test test/widgets/mobile_player_controls_seek_test.dart`
  - `flutter analyze lib/widgets/player_adapter.dart test/widgets/player_adapter_webview_preload_test.dart`
- [x] 检查 diff，避免混入无关 TV/Kotlin 改动。

## Risk Notes

- 不要改 HLS 主 buffer 参数，避免回退前一次预加载修复。
- 恢复检查应短延迟、有限次数，不能新增常驻 timer。
- `player.play()` 在 WebView 内可能返回 Promise，必须吞掉 promise rejection，避免 JS 控制台错误中断后续恢复逻辑。
