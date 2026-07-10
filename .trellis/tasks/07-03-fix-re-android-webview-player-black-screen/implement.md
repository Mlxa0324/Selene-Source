# 实施记录

## Root Cause Track

1. 先用 `adb logcat` 锁定默认运行路径已经进入 `SeleneWebViewPlayer`，不是单纯 Exo 黑屏。
2. 再用日志行号对齐 `hls_player.html`，确认异常点在 JS 上报 Android 播放事件时触发。
3. 回看 `WebViewPlayerSurface.kt` 后确认当前桥接把 Compose 的 `rememberUpdatedState` 暴露给了 WebView 私有线程，这条链路不安全。

## Fix

- `WebViewPlayerSurface.kt`
  - 去掉 `rememberUpdatedState(onPlaybackEvent)` 的后台线程读取方式。
  - 新增 `AtomicReference` 保存最新播放事件回调。
  - 新增 `Handler(Looper.getMainLooper())`，把 JS 桥接事件切回主线程再分发。
  - 对 payload 解析失败、回调分发失败分别补 `Log.e(...)`，日志里带 payload 预览。
- `hls_player.html`
  - 把 `JSON.stringify(...)` 单独保存为 `payload`。
  - 调用 `window.SeleneAndroidPlayer.onPlaybackEvent(payload)` 时加 `try/catch`。
  - 桥接失败时通过 `logPlayerIssue('bridge callback failed', ...)` 打回 WebView 控制台。
- `WebViewPlayerSurfaceContractTest.kt`
  - 先补红灯测试，锁定“主线程派发 + AtomicReference + JS try/catch”契约。

## Validation

- [x] `./re-android/gradlew -p re-android :core-player-webview:testDebugUnitTest --tests org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSurfaceContractTest --tests org.moontechlab.selene.tv.core.player.webview.WebViewPlayerBridgeTest`
- [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.navigation.TvNavGraphPlayerContractTest :app-tv:assembleDebug :feature-tv-player:testDebugUnitTest`
- [x] `./re-android/gradlew -p re-android :app-tv:installDebug`
- [ ] 手动进入详情页和全屏播放器，确认画面恢复且 `SeleneWebViewPlayer` 不再刷 `Java exception was raised during method invocation`

## Notes

- `:feature-tv-detail:testDebugUnitTest` 当前仍有既有失败：`TvDetailRouteFocusContractTest.detail_top_bar_uses_fixed_width_actions`。这不是本次播放器桥接修复引入的失败，需要另开一刀处理。
