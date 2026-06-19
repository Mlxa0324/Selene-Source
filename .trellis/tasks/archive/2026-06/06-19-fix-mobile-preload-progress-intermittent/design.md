# 修复手机端预加载进度条偶发不执行 - Design

## Scope

本任务只修 Flutter 手机端普通播放器的 WebView/HLS 缓冲区间上报链路。目标是让“实际已经加载分片”更可靠地进入现有 `cachedRanges` 数据流，从而驱动手机端预加载进度条显示。

## Current Data Flow

```text
HLS 分片加载 / video buffered
  -> WebView JS emitBufferedRanges()
  -> sendEvent('cached_ranges', ranges)
  -> WebViewPlayerAdapter._handlePlayerEvent()
  -> PlayerAdapter.stream.cachedRanges
  -> VideoPlayerWidget._recordCachedRanges()
  -> MobilePlayerControls.preloadProgressRanges
```

## Root Cause Hypothesis

主要断点在切换选集/源时的 WebView 复用分支：`VideoPlayerWidget._updateDataSource()` 开始会取消旧的 `_cachedRangesSubscription`，随后复用已有 `WebViewPlayerAdapter.updateSource()` 切到新 URL，但旧代码没有重新调用 `_setupCachedRangesListener()`。继续观看首次初始化会建立监听，所以更容易看到进度条；切集/切源后监听断开，新源即使继续发送 `cached_ranges`，Flutter 外层也收不到。

次要补强点在 HTML：现有 `Hls.Events.FRAG_LOADED` 中只调用 `emitNetworkSpeedFromStats(...)`，没有同步调用 `emitBufferedRanges()`。部分移动端 WebView 或 HLS 源不会稳定触发 `<video>` 的 `progress` 事件，会让进度条上报更不稳定。

## Change

- 在 HLS `FRAG_LOADED` 回调中，保留网速统计，并追加 `emitBufferedRanges()`。
- 在 WebView 复用切源分支中，`updateSource()` 成功返回后恢复 `_setupCachedRangesListener()`。
- 增加 `shouldRestoreCachedRangesListenerAfterDataSourceSwitch(...)`，用单元测试锁定复用 WebView 且预加载开启时必须恢复监听。
- 不修改 `MobilePlayerControls` 绘制方式，避免 UI 行为漂移。
- 不修改 `PlaybackPreloadLevel` 的 buffer 目标值。
- 不修改 `seekBoostEnabled` 的 HLS buffer 配置解耦规则。

## Compatibility

- 对非 HLS 视频无影响。
- 对 HLS 源只增加一次本地 `player.buffered` 读取和事件回传，不新增网络请求。
- 对切集/切源只恢复被当前方法主动取消的同一条缓存区间订阅，不新增重复订阅。
- 如果此时 `player.buffered` 仍为空，会回传空列表；Flutter 现有逻辑会保持已持久化缓存段，不会清掉已显示进度。

## Tests

- 扩展 `test/widgets/player_adapter_webview_preload_test.dart`，断言 `FRAG_LOADED` 回调包含 `emitBufferedRanges()`。
- 扩展 `test/widgets/video_player_widget_preload_config_test.dart`，断言复用 WebView 切源且预加载开启时必须恢复缓存监听。
- 保留已有 seek warmup 不缩小 preload 的断言，避免修复互相覆盖。
- 运行手机控件现有预加载段绘制测试，确认 UI 仍能渲染缓存段。
