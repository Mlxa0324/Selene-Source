# 修复手机端预加载进度条偶发不执行

## Goal

分析并修复手机端播放过程中预加载进度条有时整集都不显示、不执行的问题，验证真实缓存上报与进度条展示链路。

## Confirmed Facts

- 手机端普通播放器使用 `MobilePlayerControls` 绘制预加载进度段，入口为 `showPreloadProgress` 和 `preloadProgressRanges`。
- `VideoPlayerWidget` 只在 `playbackPreloadLevel.isEnabled && !isLocal` 时持久化预加载进度，默认等级为 `medium`。
- 手机端网络流当前默认走 `WebViewPlayerAdapter`，HLS 缓冲区间通过 WebView JS 的 `cached_ranges` 事件回传到 Flutter。
- 已有修复保证 `seekBoostEnabled` 不再缩小主预加载 buffer，但这不等于进度条一定能持续收到缓存区间。
- 现有 JS 主要在 `timeupdate`、`progress`、`durationchange`、`canplay`、`playing`、`seeked` 等媒体事件里调用 `emitBufferedRanges()`。
- 从继续观看首次进入时，初始化阶段会正常建立 `cachedRanges` 监听。
- 切换选集/源会进入 `VideoPlayerWidget._updateDataSource()`，该方法先取消旧的 `_cachedRangesSubscription`。
- WebView 复用同一个控制器执行 `WebViewPlayerAdapter.updateSource()` 后，旧代码没有重新 `_setupCachedRangesListener()`，导致新源后续 `cached_ranges` 事件进不了 Flutter 外层。
- HLS 分片加载完成时此前只刷新网速，没有同步刷新 `cached_ranges`；若某些源或 WebView 内核不稳定触发 `progress`，会进一步放大进度条空白问题。

## Requirements

- 手机端网络流开启预加载时，底层 HLS 分片加载完成必须主动尝试上报已缓冲区间。
- 切换选集/源复用 WebView 播放器后，必须恢复缓存区间监听。
- 预加载进度条展示逻辑继续使用现有 `PlayerCachedRange` / `cachedRanges` 链路，不新增独立 UI 状态。
- 不改变本地播放、直播、TV/Kotlin 播放器链路。
- 不回退上一轮 WebView seek warmup 与主 preload buffer 解耦的修复。
- 补充覆盖 HLS 分片加载触发缓存区间上报的回归测试。

## Acceptance Criteria

- [x] `buildWebViewPlayerHtmlForTest(...)` 生成的 HLS HTML 在 `Hls.Events.FRAG_LOADED` 回调中调用 `emitBufferedRanges()`。
- [x] 复用现有 WebView 切换选集/源后会恢复 `cachedRanges` 监听。
- [x] `seekBoostEnabled` 开启时仍保留正常 preload buffer 配置，不出现 8/16 秒级 buffer 覆盖。
- [x] `MobilePlayerControls` 继续能按传入的 `preloadProgressRanges` 绘制多个缓存段。
- [x] 相关 Flutter widget/unit 测试通过。
- [x] `flutter analyze` 对改动文件无新增问题。

## Out of Scope

- 不做新的预加载策略开关或设置页改版。
- 不调整短剧播放器控件。
- 不改 TV 端 Compose/WebView/Exo 播放器。
- 不引入实际网络源集成测试。

## Notes

- 用户明确要求创建任务并分析修复，按连续执行模式推进。
