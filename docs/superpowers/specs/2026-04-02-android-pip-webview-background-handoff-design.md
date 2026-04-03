# Android PiP WebView Background Handoff Design

## 背景

当前 Android 在线播放默认仍优先使用 `WebViewPlayerAdapter`。在开启“息屏播放”后，`VideoPlayerWidget` 为了保证 PiP 和后台媒体通知可用，会在进入 PiP 前先调用原生播放器切换链路，把前台 WebView 播放切到原生 `MediaKit`。

这条链路虽然能保证 Android PiP 和后台播放可用，但会带来两个明显问题：

1. 用户点击右下角 PiP 时，画面可能先黑一下再进入小窗。
2. 即使用户只是短暂切到后台或马上回前台，也会过早触发内核切换，体感生硬。

本次改动只针对 Android，目标是把“进入 PiP”与“后台接管”拆成两个阶段：

- 进入 PiP 时尽量保持 WebView 前台播放，不立即切核。
- 真正离开 PiP 可见阶段并稳定停留一段时间后，再切到息屏播放允许的原生后台播放链路。

## 目标

- Android 在线播放使用 WebView 时，进入 PiP 不再立即切到原生播放器。
- Android 进入 PiP 后，只要 PiP 仍在桌面可见，就不触发后台原生接管。
- Android PiP 离开可见阶段后，只有持续超过 `1s` 时才切到后台原生播放。
- 这 `1s` 内如果用户回前台、退出 PiP，或没有真正离开 PiP 可见阶段，则取消切换。
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

另外，Android 原生层的 `MainActivity.onPictureInPictureModeChanged()` 当前已经在进入 PiP 时主动调用 `flutterEngine?.lifecycleChannel?.appIsResumed()`，目的是让“PiP 仍然可见”阶段不要被 Flutter 生命周期误判成普通后台。

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
3. PiP 会话离开“可见阶段”后，启动一个 `1s` 的延迟切换定时器。
4. 如果 `1s` 内恢复前台或 PiP 结束，则取消切换。
5. 如果 `1s` 后仍然离开 `resumed`，则启动现有 Android 后台原生播放链路。
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
  代表已经离开“PiP 可见阶段”，正在等待是否超过 `1s`。

### PiP 可见阶段与真正后台阶段的判定

这是本次状态机的核心约束。

本方案不把 `inactive / hidden / paused` 直接等价成“PiP 后应立即开始后台接管计时”，而是依赖现有 Android 原生层的约定：

- 当 PiP 仍然显示在桌面上时，`MainActivity` 会主动把 Flutter 生命周期保持在 `resumed`
- 因此，PiP 期间如果仍然处于 `resumed`，就视为“PiP 仍可见，继续保留 WebView”
- 只有当当前仍处于 PiP 会话中，但生命周期已经离开 `resumed` 时，才视为“用户已锁屏、系统已让应用真正离开可见阶段，允许开始后台接管窗口”

换句话说：

- `isPipMode == true && lifecycle == resumed`
  表示 PiP 仍可见，不启动后台接管计时
- `isPipMode == true && lifecycle != resumed`
  表示 PiP 会话仍在，但已经离开可见阶段，此时才启动 `1s` 接管计时

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

当 `didChangeAppLifecycleState()` 收到 Android 生命周期变化时：

- 如果当前处于 `armed PiP WebView` 场景，则先判断当前是否已经离开 `resumed`
- 若仍处于 `resumed`，不启动任何后台接管逻辑
- 若已离开 `resumed`，则不立即走普通后台播放策略，而是启动或刷新 `1s` 定时器
- 定时器触发时再次检查：
  - 组件仍 mounted
  - 仍处于 PiP
  - 生命周期仍未恢复到 `resumed`
  - 当前仍是允许后台接管的 Android 在线播放场景
- 条件满足后，调用现有 `_startAndroidBackgroundPlayback()` 完成后台原生接管

这样可以避免“用户正在桌面上看 PiP，小窗 1 秒后仍被接管”的问题。

### 回前台或退出 PiP 的行为

以下任一情况出现时，取消 `armed` 和相关定时器：

- 生命周期回到 `resumed`
- PiP 结束
- 当前 URL/播放器适配器发生变化
- 组件销毁

如果后台原生接管已经发生，则仍沿用现有 `_restoreFromAndroidBackgroundPlayback()` 恢复前台播放器。

如果尚未发生后台接管，则只需要取消定时器，不做播放器切换。

### PiP 窗口收尾约定

本方案明确约定：只有当 PiP 会话已经离开“可见阶段”时，才允许后台原生接管。

这意味着后台接管发生时，系统层的 PiP 不再被视为“仍在桌面上给用户看”的主画面，因此不会把“可见 PiP 画面”和“后台音频接管”同时保持。

因此本次实现不额外新增“后台接管前主动 stop PiP”的强制动作；优先依赖现有 Android 原生层对 PiP 可见阶段维持 `resumed` 的约定来避免黑窗。如果真机验证发现仍有机型会在“PiP 不可见但系统未自动结束 PiP”时留下残余黑窗，再单独补一条“后台接管前主动结束 PiP”的兜底策略。

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
- `[PiP] Android PiP 仍可见，跳过后台接管计时`
- `[PiP] Android 后台接管计时开始: state=paused`
- `[PiP] Android 后台接管已取消: reason=resumed`
- `[PiP] Android WebView 离开可见阶段超过 1s，开始切到后台原生播放`
- `[PiP] Android PiP 结束，取消延迟后台接管`

这些日志只用于调试，不新增用户可见提示。

## 风险

### 风险 1：部分机型对 PiP 生命周期的实际派发与当前约定不完全一致

如果某些 ROM 下“PiP 仍可见”阶段没有稳定保持 `resumed`，则可能仍会过早进入后台接管窗口。真机验证需要重点覆盖这类设备。

### 风险 2：PiP、后台、回前台切换很快时发生重复接管

通过单独的 `armed` 状态和专用定时器去重，避免重复调用后台接管。

### 风险 3：部分机型在后台接管时仍残留系统 PiP 容器

本方案第一版不主动 stop PiP，而是依赖“只在 PiP 不可见阶段接管”的约定。若特定机型仍残留黑窗，需要第二步补充主动结束 PiP 的兜底。

### 风险 4：后台接管后回前台恢复抖动

继续复用现有恢复链路，不再新造第二套恢复机制，减少额外不确定性。

## 测试策略

### 自动化

本次优先补充策略层或 widget 局部测试，覆盖：

- PiP WebView 场景不会立即预切原生
- PiP 可见且生命周期保持 `resumed` 时，不触发后台接管
- PiP 离开可见阶段但在 `1s` 内恢复前台时，不触发后台接管
- PiP 离开可见阶段并停留超过 `1s` 时，会触发后台接管

如果 widget 级别自动化成本过高，可接受以更小范围的状态逻辑测试替代。

### 手动验证

Android 真机验证以下路径：

1. 开启“息屏播放”
2. 在线播放使用 WebView
3. 点击右下角 PiP
   - 不应立即黑屏切核
4. PiP 保持在桌面可见状态停留
   - 不应在 `1s` 后被后台原生接管
5. PiP 后锁屏或离开可见阶段，再在 `1s` 内回前台
   - 不应触发后台原生接管
6. PiP 后锁屏或离开可见阶段，并停留超过 `1s`
   - 应触发后台原生播放/媒体通知
7. 从后台回到前台
   - 应恢复前台播放器，不持续黑屏

## 验收标准

- Android WebView 在线播放进入 PiP 时，不再立即执行原生预切换。
- Android PiP 在桌面可见阶段停留时，不触发后台原生接管。
- Android PiP 离开可见阶段不足 `1s` 时，不触发后台原生接管。
- Android PiP 离开可见阶段超过 `1s` 时，能稳定切到后台原生播放。
- 回前台后能恢复前台播放器。
- iOS 与非 PiP 场景行为保持不变。
