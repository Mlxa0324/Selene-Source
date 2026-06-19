# 修复 iOS 暂停数分钟后恢复播放卡转圈

## Goal

分析并修复 iOS 手机端暂停放置数分钟后再次播放一直转圈无法恢复的问题，同时确认 Android 是否存在同类风险。

## Confirmed Facts

- 手机端网络播放默认走 `WebViewPlayerAdapter`，iOS 和 Android 都会经过同一套 WebView JS 播放桥接。
- 手机控件点击恢复播放只调用 `widget.player.play()`，不会触发 seek 或切源。
- `WebViewPlayerAdapter.play()` 当前只执行 `player.play();`，没有唤醒 hls.js 加载器，也没有安排恢复播放卡住检查。
- WebView 快进路径 `fastSeekTo(sec)` 会主动 `hlsInstance.startLoad(sec)`，说明当前代码已经知道跳点后需要唤醒 HLS 加载。
- 现有 iOS 倍速恢复逻辑已经有 `scheduleFrozenPlaybackWakeup(...)` / `tryWakeFrozenPlayback(...)`，但只在 `setRate(...)` 中使用，普通暂停后播放不会用到。
- App 生命周期层只保存进度、恢复屏幕常亮，不会重建播放器或主动恢复 WebView HLS 加载。
- Android 也走 `WebViewPlayerAdapter.play()`，存在同类恢复唤醒缺口；只是 Android WebView/hls.js 更可能自行恢复，所以用户感知上不明显。

## Requirements

- iOS 暂停数分钟后点击播放时，WebView 播放器必须主动唤醒当前位置附近的媒体加载。
- Android 同链路也应受益，但修复不能破坏 Android 正常点击播放。
- 恢复播放不应改变当前集、当前播放源、播放速度和已有 seek warmup/preload 行为。
- 修复应优先复用现有 WebView JS 恢复工具，避免新增独立 UI 状态。
- 补充生成 HTML 的回归测试，锁住暂停后恢复播放的 HLS 唤醒和卡住恢复调度。

## Acceptance Criteria

- [x] `WebViewPlayerAdapter.play()` 不再只是裸 `player.play()`，而是调用生成 HTML 内的恢复播放辅助函数。
- [x] 恢复播放辅助函数会在当前位置调用 `hlsInstance.startLoad(currentTime)`。
- [x] 恢复播放辅助函数会安排短延迟卡住恢复检查，防止 iOS 一直处于 waiting/buffering。
- [x] Android 走同一辅助函数但不依赖 iOS 专属 API，不引入平台分支崩溃。
- [x] 相关 Flutter tests 和 analyze 通过。

## Out of Scope

- 不调整播放 UI 样式。
- 不改变继续观看、切集、换源流程。
- 不改 TV/Kotlin 播放器。
- 不引入真实网络源集成测试。

## Notes

- 用户明确要求创建任务、分析并修复，按连续执行模式推进。
