# 排查 Flutter TV 全屏长按与低内存续播异常

## Goal

修复 Flutter TV 全屏播放器与低内存设备续播链路中的一组回归问题，重点覆盖：

1. 全屏左右键长按刚开始推进过快，首段手感需要放缓。
2. 长按松手后，画面会短暂保持几秒“倍速感”再恢复正常。
3. 部分视频进入全屏后仍能看到暂停态或底部控制按钮，并且暂停/恢复响应异常。
4. 2GB 运存电视端在继续观看进入详情页后，仍可能无法从记录时间点起播；平板模拟器运行 TV 模式时则正常。

目标是在不回退现有 TV 全屏交互和详情页首播链路的前提下，定位根因并完成最小修复。

## Confirmed Facts

- TV 全屏播放器壳位于 `lib/tv_app/screens/tv_fullscreen_player_screen.dart`，当前短按左右键固定 seek `10s`。
- 当前长按规则由 `TvFullscreenSeekStep` 控制：
  - 长按阈值 `250ms`
  - 第一档前 `5s` 为 `60 视频秒 / 真实秒`
  - 第二档为 `120 视频秒 / 真实秒`
  - 当前实现通过 `3s / 6s` 的 staged tick 驱动。
- 全屏页 `_buildPlayer()` 传给 `VideoPlayerWidget` 的参数是 `showControls: false`；Flutter 壳层自己的顶部装饰、中心暂停按钮和底部进度条由 `_shouldShowPlaybackChrome` / `_shouldShowTopDecorations` 控制。
- 详情页预览播放器与全屏播放器都已经有两层续播兜底：
  - `updateDataSource(startAt)`
  - 首次下发后立刻补一次 `seekTo(startAt)`
  - 若真实进度信号仍停在续播点之前，再做限次重试 seek
- 之前的投影仪专项调查任务已经归档：`.trellis/tasks/archive/2026-06/06-01-investigate-flutter-tv-projector-resume-playback/`。
- 已知当时无法连接投影仪真机，因此“模拟器正常、2GB 真机异常”的最终结论仍停留在代码侧推断，缺少真机日志闭环。
- 本轮 2GB 电视端续播项先按“代码侧 best effort 修复 + 回归测试补强”推进，不把真机闭环作为本轮阻塞条件。
- 本次仍然只处理 Flutter TV 端，不处理 Kotlin 原生 TV 端。

## Requirements

### R1: 微调全屏长按首段 seek 手感

- 在保留短按 `10s` 跳转语义的前提下，降低长按刚开始阶段的推进速度或触发节奏。
- 调整后不能让长按完全失去“快速跨段”的能力；长距离拖动仍需保留后段加速。

### R2: 长按松手后不能残留“倍速感”

- 长按方向键抬起后，播放器必须立即回到正常播放节奏。
- 不允许出现数秒钟的持续快进画面、迟到的残留 seek tick，或 seek 提示已经消失但底层仍继续向后跳的现象。

### R3: 全屏模式下不应暴露普通播放器控制层

- 对于 Flutter TV 全屏壳托管的视频，进入全屏后不应再看到普通 `VideoPlayerWidget` 的暂停按钮、底部控制栏或其它非 TV 壳层控件。
- 确认键/Enter/Space 的暂停与恢复行为必须稳定可用。
- 需要区分“Flutter 自己叠加的控件”与“底层播放器/WebView/native video 元素自己露出的控件”。

### R4: 2GB 电视端继续观看续播要继续排查并修复

- 继续观看进入详情页后，若播放记录存在有效 `source / id / playTime / index / searchTitle`，详情页与全屏页都应尽量从记录时间点起播。
- 需要重新审视当前 `startAt + seek 兜底 + 进度确认重试` 是否仍有设备时序缺口，尤其是弱 CPU / 低内存电视端。
- 若没有真机可直连，至少要把代码可验证的时序漏洞、竞态窗口和测试缺口收敛清楚，不做拍脑袋结论。

## Acceptance Criteria

- [ ] 已明确当前全屏长按“刚开始过快”的根因，且形成可验证的微调方案。
- [ ] 长按松手后，不再出现残留快进/倍速画面；相关 widget test 能覆盖 key up 后的停止行为。
- [ ] 已定位“全屏仍显示暂停/底部按钮且无法暂停”属于 TV 壳层、`VideoPlayerWidget` 控制层，还是底层播放内核。
- [ ] 若属于 Flutter TV 可控范围，提交最小修复并补对应测试；若属于底层播放器或网页控件限制，任务内要明确记录触发条件和后续处理建议。
- [ ] 已重新审视 2GB 电视端续播链路，并输出“当前代码路径仍可能失败的点”或完成修复。
- [ ] 不回退现有测试中已覆盖的以下行为：
  - `test/tv_app/tv_fullscreen_player_screen_test.dart` 中的长按 seek、暂停、全局按键行为
  - `test/tv_app/tv_video_detail_screen_test.dart` 中的继续观看起播、`startAt` 下发与 seek 重试逻辑

## Out of Scope

- Kotlin 原生 TV 模块修复
- 搜索页、首页、设置页的无关 UI 调整
- 真机 adb 连接和外部网络/投影仪固件问题本身

## Open Questions

- 长按首段“微调到什么程度”仍需要产品口径：是只略微放慢，还是要明显降低第一段推进速度。

## Notes

- 当前仓库已经存在与本任务直接相关的历史上下文：
  - `.trellis/tasks/06-01-analyze-flutter-tv-low-memory-performance/`
  - `.trellis/tasks/archive/2026-06/06-01-investigate-flutter-tv-projector-resume-playback/`
- 该任务同时跨越全屏交互、播放器壳层和低内存续播链路，按 Trellis 规则应视为复杂任务，开始实现前补 `design.md` 与 `implement.md`。
