# 设计说明

## Scope

本任务只处理 Flutter TV 端三段相关链路：

1. `TvFullscreenPlayerScreen` 的左右键长按 seek 节奏与 key up 收尾。
2. `TvFullscreenPlayerScreen` / `VideoPlayerWidget` 在 TV 全屏场景下的控件显隐与暂停控制。
3. `TvVideoDetailScreen` / `TvFullscreenPlayerScreen` 的继续观看续播时序，重点关注弱 CPU / 低内存电视端。

不涉及 Kotlin 原生 TV 模块，不处理真机网络、投影仪固件或 adb 连接本身。

## Known Flow

### 全屏长按 seek

- `_handleSeekKeyDown` 在左右方向键按下时启动内部长按调度。
- `TvFullscreenSeekStep` 负责定义：
  - 短按 `10s`
  - 长按阈值 `250ms`
  - 第一档 `60 视频秒 / 真实秒`
  - 第二档 `120 视频秒 / 真实秒`
- `_scheduleNextSeekHoldTick` 会根据累计长按时间计算下一次 tick 触发时机。
- `_handleSeekKeyUp` 当前只负责停止计时器、隐藏 seek overlay，并没有额外等待底层播放器“追平”到最终位置。

### 全屏控件

- TV 全屏页 `_buildPlayer()` 会给 `VideoPlayerWidget` 传 `showControls: false`。
- Flutter TV 壳层自己的暂停按钮、顶部说明和底部进度条由 `_shouldShowPlaybackChrome` / `_shouldShowTopDecorations` 控制。
- 如果用户仍能看到暂停按钮或底部按钮，需要先区分：
  - 是 TV 全屏壳自己的层误显示；
  - 还是 `VideoPlayerWidget` / WebView / 页面内 video 元素自己暴露出的控件。

### 继续观看续播

- 详情页与全屏页都使用 `updateDataSource(startAt)` 下发初始时间点。
- 当前已有两层兜底：
  - `updateDataSource` 后立即补一次 `seekTo(startAt)`
  - 真实进度信号回来后若仍小于续播点，限次重试 seek
- 已知模拟器可以走通；2GB 电视端仍可能失败，说明当前兜底仍存在设备时序窗口或底层播放器差异。

## Design Strategy

### 1. 长按首段手感与收尾分开处理

- 首段过快与“松手后残留倍速感”虽然都发生在长按链路里，但根因未必相同：
  - 首段过快更像 `TvFullscreenSeekStep` 参数问题。
  - 松手残留更像 key up 后仍有晚到 tick、生效过晚的底层 seek、或播放器在连续 seek 后短暂追帧。
- 实现上需要分别验证：
  - 调低第一档速率/延后加速阈值是否能改善手感；
  - key up 后是否还有 timer callback 或 seek 请求在继续落地。

### 2. 控件问题按“壳层 vs 底层”分叉

- 如果是 `_shouldShowPlaybackChrome` 条件误判，就在 TV 全屏壳修。
- 如果 Flutter 壳层没有显示，但用户仍看到控件，更大概率是：
  - `VideoPlayerWidget` 的 WebView/网页播放器自身露出控件；
  - 某些源的网页全屏或 H5 video 原生控件没有被禁用。
- 这类问题要优先从 `VideoPlayerWidget` 和对应 adapter/WebView 行为确认，而不是只改 TV 壳层。

### 3. 续播问题继续按“记录链路 / 参数链路 / 播放器时序”三段拆

- 既然模拟器正常、2GB 电视异常，优先怀疑“底层播放器时序差异”，但不能跳过记录与匹配链路核对。
- 需要重点排查：
  - 真实进度信号是否在电视端来得更晚；
  - 当前重试上限是否过低；
  - `currentPosition` 在弱设备上是否会先报一个乐观值，再回退到 0；
  - 详情页进全屏时是否复用了过早的播放位置快照。

## Risk Notes

- 长按节奏调慢过头会让大跨度拖动变得费力，尤其是长视频。
- 如果只在 TV 壳层隐藏控件，但底层网页视频本身带原生 controls，问题会被误判为已修复。
- 续播继续加重试不能无限增大次数，否则可能在播放已经推进后又被旧记录回拉。

## Validation Shape

- 先用 widget test 和现有 fake controller 把长按节奏、key up 收尾、暂停壳层判定跑通。
- 再用代码审查和必要日志点验证续播时序是否还有可见漏洞。
- 若后续能连上 2GB 真机，再补真机日志验证，不把模拟器现象当成最终结论。
