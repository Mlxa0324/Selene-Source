# Android PiP WebView Background Handoff Design

## 背景

当前 Android 在线播放默认仍优先使用 `WebViewPlayerAdapter`。在开启“息屏播放”后，`VideoPlayerWidget` 为了保证 PiP 和后台媒体通知可用，会在进入 PiP 前先调用原生播放器切换链路，把前台 WebView 播放切到原生 `MediaKit`。

这条链路虽然能保证 Android PiP 和后台播放可用，但会带来两个明显问题：

1. 用户点击右下角 PiP 时，画面可能先黑一下再进入小窗。
2. 即使用户只是短暂切到后台或马上回前台，也会过早触发内核切换，体感生硬。

本次改动只针对 Android，目标是把“进入 PiP”与“后台接管”拆成两个阶段：

- 进入 PiP 时尽量保持 WebView 前台播放，不立即切核。
- 真正进入后台并稳定停留一段时间后，再切到息屏播放允许的原生后台播放链路。

## 目标

- Android 在线播放使用 WebView 时，进入 PiP 不再立即切到原生播放器。
- Android 进入 PiP 后，只有在后台持续超过 `1s` 时才切到后台原生播放。
- 这 `1s` 内如果用户回前台、退出 PiP，或没有真正进入后台，则取消切换。
- 回到前台后，继续沿用现有恢复逻辑，把播放恢复到前台播放器。
- 不改 iOS 行为。
- 不改“息屏播放”产品语义，只改触发时机。

## 非目标

- 不新增新的播放器后端。
- 不调整 iOS PiP 或 iOS WebView 前后台恢复策略。
- 不重写 Android 后台音频桥接实现。
- 不改变当前非 PiP 场景下的普通前后台播放策略。

## 当前实现概况

### PiP 进入链路

`VideoPlayerWidget._enterPipMode()` 在 Android 下会先执行 `_prepareAndroidNativePlaybackForPip()`，将当前在线播放从 WebView 切到原生 `MediaKit`，然后再启动 PiP。

### Android 后台播放链路

`VideoPlayerWidget.didChangeAppLifecycleState()` 会根据 `MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction()` 的结果，在进入后台时触发：

- 延迟启动后台播放
- 立即启动后台播放
- 回前台恢复前台播放器

当前策略对 `isPipMode` 有短路保护，因此 PiP 场景本质上依赖“进入 PiP 前已经切到原生播放器”来保证后续后台播放可持续。

## 方案

### 方案摘要

Android 开启“息屏播放”且当前在线播放使用 WebView 时：

1. 进入 PiP 时不立即切到原生播放器。
2. PiP 小窗阶段继续保持 WebView 前台渲染。
3. 应用进入后台后，启动一个 `1s` 的延迟切换定时器。
4. 如果 `1s` 内恢复前台或 PiP 结束，则取消切换。
5. 如果 `1s` 后仍处于后台，则启动现有 Android 后台原生播放链路。
6. 回前台后，继续复用现有恢复逻辑恢复前台播放。

### 生命周期设计

引入 Android PiP 专用的后台接管窗口：

- 常量：`_androidPipBackgroundHandoffDelay = Duration(seconds: 1)`
- 状态：
  - `_pendingAndroidPipBackgroundHandoffTimer`
  - `_androidPipBackgroundHandoffArmed`

语义如下：

- `armed = true`
  代表当前会话是“WebView 进入 PiP，允许在后台稳定后再接管”的状态。
- `timer != null`
  代表已经进入后台，正在等待是否超过 `1s`。

### 进入 PiP 的行为

#### 旧行为

- Android
  - 进入 PiP 前先 `_prepareAndroidNativePlaybackForPip()`
  - 再 `_pip.start()`

#### 新行为

当满足以下条件时，Android 进入 PiP 不再预切原生：

- 当前适配器是 `WebViewPlayerAdapter`
- `screenOffPlaybackEnabled == true`
- URL 支持 Android 后台原生播放兜底
- 当前不是本地播放

此时：

- 设置 `armed = true`
- 不调用 `_prepareAndroidNativePlaybackForPip()`
- 直接进入 PiP

其他场景维持原状。

### 进入后台的行为

当 `didChangeAppLifecycleState()` 收到 Android 的 `inactive / hidden / paused` 时：

- 如果当前处于 `armed PiP WebView` 场景，则不立即走普通后台播放策略。
- 对 `inactive / hidden / paused` 启动或刷新 `1s` 定时器。
- 定时器触发时再次检查：
  - 组件仍 mounted
  - 仍处于 PiP
  - 仍未回前台
  - 当前仍是允许后台接管的 Android 在线播放场景
- 条件满足后，调用现有 `_startAndroidBackgroundPlayback()` 完成后台原生接管。

### 回前台或退出 PiP 的行为

以下任一情况出现时，取消 `armed` 和相关定时器：

- 生命周期回到 `resumed`
- PiP 结束
- 当前 URL/播放器适配器发生变化
- 组件销毁

如果后台原生接管已经发生，则仍沿用现有 `_restoreFromAndroidBackgroundPlayback()` 恢复前台播放器。

如果尚未发生后台接管，则只需要取消定时器，不做播放器切换。

### 对现有策略层的改动

`MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction()` 保持“普通非 PiP 场景”的语义不变。

PiP WebView 延迟接管由 `VideoPlayerWidget` 自己处理，不把这类短暂切换窗口塞进通用 policy。这样可以避免：

- 把 PiP 特例扩散到所有 Android 生命周期判断里
- 影响已有非 PiP 后台播放逻辑

换句话说：

- 普通后台播放：继续走 policy
- PiP WebView 后台延迟接管：由 widget 内新增逻辑拦截并调度

## 实现边界

### 主要修改文件

- `lib/widgets/video_player_widget.dart`
- `lib/utils/mobile_playback_lifecycle_policy.dart`

### 可接受的辅助修改

- 如有必要，可对 Android 背景播放相关日志和状态字段做小范围整理。

### 明确不改的文件

- `lib/screens/player_screen.dart`
- Android 后台播放 bridge 的平台侧实现
- iOS PiP 与前后台恢复逻辑

## 日志与可观测性

新增或调整 Android 调试日志，确保真机验证时能看清状态转换：

- `[PiP] Android WebView 进入 PiP，延迟后台接管已启用`
- `[PiP] Android 后台接管计时开始: state=paused`
- `[PiP] Android 后台接管已取消: reason=resumed`
- `[PiP] Android WebView 后台停留超过 1s，开始切到后台原生播放`
- `[PiP] Android PiP 结束，取消延迟后台接管`

这些日志只用于调试，不新增用户可见提示。

## 风险

### 风险 1：部分机型在 PiP 后很快冻结 WebView 画面

这是允许接受的风险。产品目标是给 WebView 一个短暂窗口尽量无黑屏进入 PiP，而不是保证 WebView 永远能在后台保持视频渲染。

### 风险 2：PiP、后台、回前台切换很快时发生重复接管

通过单独的 `armed` 状态和专用定时器去重，避免重复调用后台接管。

### 风险 3：后台接管后回前台恢复抖动

继续复用现有恢复链路，不再新造第二套恢复机制，减少额外不确定性。

## 测试策略

### 自动化

本次优先补充策略层或 widget 局部测试，覆盖：

- PiP WebView 场景不会立即预切原生
- PiP 进入后台但在 `1s` 内恢复前台时，不触发后台接管
- PiP 进入后台并停留超过 `1s` 时，会触发后台接管

如果 widget 级别自动化成本过高，可接受以更小范围的状态逻辑测试替代。

### 手动验证

Android 真机验证以下路径：

1. 开启“息屏播放”
2. 在线播放使用 WebView
3. 点击右下角 PiP
   - 不应立即黑屏切核
4. PiP 后立刻回前台
   - 不应触发后台原生接管
5. PiP 后停留后台超过 `1s`
   - 应触发后台原生播放/媒体通知
6. 从后台回前台
   - 应恢复前台播放器，不持续黑屏

## 验收标准

- Android WebView 在线播放进入 PiP 时，不再立即执行原生预切换。
- Android PiP 后台停留不足 `1s` 时，不触发后台原生接管。
- Android PiP 后台停留超过 `1s` 时，能稳定切到后台原生播放。
- 回前台后能恢复前台播放器。
- iOS 与非 PiP 场景行为保持不变。
