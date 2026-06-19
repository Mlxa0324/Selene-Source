# 修复 iOS 暂停数分钟后恢复播放卡转圈 - Design

## Scope

本任务只修 Flutter 手机端 WebView 播放器暂停后恢复播放链路。修复集中在 `WebViewPlayerAdapter` 生成的 HTML/JS 和 Dart `play()` 桥接，不改变播放器控件 UI。

## Current Flow

```text
MobilePlayerControls._togglePlayPause()
  -> widget.player.play()
  -> WebViewPlayerAdapter.play()
  -> evaluateJavascript('player.play();')
  -> video element play event
```

暂停数分钟后，iOS WebKit 可能已经停止或挂起 HLS/媒体加载。当前恢复播放只调用 `player.play()`，如果 HLS loader 没有重新拉当前位置附近分片，播放器就会进入 `waiting` / `buffering`，外层表现为一直转圈。

## Target Flow

```text
WebViewPlayerAdapter.play()
  -> window.resumePlaybackFromPause()
      -> begin short buffering suppression
      -> hlsInstance.startLoad(currentTime) when hls.js exists
      -> player.play()
      -> schedule resume stuck checks
      -> wake playback / nudge currentTime if still stalled
```

## Compatibility

- hls.js 路径：恢复时调用 `startLoad(currentTime)`，补齐暂停后 loader 没有自行恢复的缺口。
- iOS/native HLS 路径：`hlsInstance` 为空时跳过 `startLoad`，仍执行 `player.play()` 和短延迟卡住恢复检查。
- Android 路径：同样调用辅助函数；如果 Android 已可自行恢复，则辅助逻辑只做幂等唤醒。
- 与 seek warmup 解耦：不改变 `fastSeekTo(...)`、`PlaybackPreloadLevel`、HLS buffer 配置。

## Tests

- 在 `test/widgets/player_adapter_webview_preload_test.dart` 中断言：
  - Dart `play()` 桥接调用 `resumePlaybackFromPause()` 而不是裸 `player.play()`。
  - 生成 HTML 定义 `resumePlaybackFromPause`。
  - 恢复函数包含 `hlsInstance.startLoad(resumeTime)`。
  - 恢复函数安排 `scheduleResumePlaybackRecovery(...)`。
