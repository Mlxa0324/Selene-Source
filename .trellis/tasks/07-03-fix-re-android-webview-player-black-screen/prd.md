# 修复 re-android 播放器有声音无画面

## Goal

修复 `re-android` 详情页预览播放器和全屏播放器出现“有声音无画面”的问题，优先保证默认 `webview` 播放内核稳定显示视频画面，并把排障证据和回归测试沉淀下来。

## Confirmed Facts

- 当前默认播放器内核已经切到 `webview`，详情页和全屏播放器优先走 `WebViewPlayerSurface`。
- `adb logcat -d -s SeleneWebViewPlayer:D ExoPlayerImpl:D AndroidRuntime:E '*:S'` 持续出现：
  - `WARNING: [SeleneWebViewPlayer] hls error otherError/internalException`
  - `ERROR: Uncaught Error: Java exception was raised during method invocation @76`
- `@76` 对应 `re-android/core-player-webview/src/main/assets/player/hls_player.html` 中 `window.SeleneAndroidPlayer.onPlaybackEvent(...)`。
- `WebView` 注入的 `@JavascriptInterface` 运行在线程不是 Compose 主线程，当前实现又通过 `rememberUpdatedState` 间接读取 Compose State，有较高概率触发线程/快照级异常。

## Requirements

- JS -> Android 播放事件桥接不能再直接触发 `Java exception was raised during method invocation`。
- 桥接层要把异常日志打全，至少包含 payload 预览，方便后续继续排查。
- JS 侧调用 Android 桥时要自己兜底，不能把 hls.js 事件循环炸掉。
- 修复范围只限 `re-android`，不扩散到 `kotlin-tv` 新工程。

## Acceptance Criteria

- [x] `WebViewPlayerSurface` 使用主线程分发播放事件回调，不再直接从 WebView 私有线程碰 Compose 回调引用。
- [x] `hls_player.html` 给 `SeleneAndroidPlayer.onPlaybackEvent(...)` 增加 `try/catch` 兜底。
- [x] `core-player-webview` 回归测试通过。
- [x] `app-tv` 相关路由测试和 `assembleDebug` 通过。
- [ ] 真机/模拟器手测确认详情页和全屏播放器画面恢复正常。

## Risks

- 即使 WebView 桥接异常修掉，仍可能存在 `TvDesignCanvas` 缩放与 `AndroidView` 组合带来的平台视图显示问题，需要继续看运行态。
- `feature-tv-detail` 当前存在与本次修复无关的既有契约测试失败，不能误判成播放器回归。
