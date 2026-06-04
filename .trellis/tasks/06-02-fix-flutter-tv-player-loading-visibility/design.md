# 修复 Flutter TV 详情与全屏加载态误判 - 技术设计

## Scope

本任务只处理 Flutter TV 端详情页小播放器与全屏播放器的中心 loading 态显示/隐藏逻辑，不扩展到：

- Kotlin TV 端
- 首页 / 搜索页 / 设置页
- 首播链路瘦身、续播记录读取、补源并发等已有独立任务

本任务核心解决两件事：

1. loading 态期间需要展示“转圈 + 网速”
2. loading 态退出条件要更接近“真实画面已经恢复可见”

## Current Behavior

### 详情页

`TvVideoDetailScreen` 当前已有：

- `_previewPlayerLoading`
- `_previewPlaybackStarted`
- `_previewProgressSignalReceived`
- `_isPreviewPlaybackReadyForDisplay`
- `_buildPreviewLoadingIndicator()`

当前退出条件本质上依赖：

- `controller.isPlaying`
- `controller.isLoading`
- 是否收到 progress
- `currentPosition / duration > 0`

这能挡住一部分“ready 了但没播起来”的误判，但仍不能证明真实视频帧已经出现在屏幕上。

### 全屏页

`TvFullscreenPlayerScreen` 当前已有：

- `_isPlaybackLoading`
- `_fullscreenPlaybackStarted`
- `_fullscreenProgressSignalReceived`
- `_isFullscreenPlaybackReadyForDisplay`

当前退出条件同样主要依赖：

- `isPlaying`
- `isLoading`
- progress 信号
- 当前 position / duration

这套规则与详情页语义接近，但并未抽成共享能力。

### 当前缺口

1. 没有网速展示能力
2. loading 退出条件仍偏“事件到达”，不是“画面真正可见”
3. 详情页与全屏页的 loading 语义接近但未统一，后续容易继续漂移

## Design Goals

### Goal A: 明确定义两类 loading 场景

只允许在以下两个场景展示中心 loading：

1. 首次进入详情页小播放器或全屏播放器，等待真实画面出来
2. 长按 seek 松手后，等待真实画面恢复

不在以下场景展示：

- 普通暂停态
- 菜单态
- 普通已稳定播放态

### Goal B: 把“真实出画面”判断收敛为共享语义

虽然 Flutter / WebView / MediaKit 很难直接拿到“首帧渲染完成”的统一底层事件，但可以把当前散落判断升级成更严格的共享近似语义：

- 播放器不再处于 loading / buffering 主态
- 已收到至少一次有效播放进度信号
- position 或 duration 已进入有效区间
- 若处于 seek 恢复态，还需确认当前位置已经追平到目标位置附近

这仍不是 GPU 级别的“像素已绘制”信号，但比当前“只要 isPlaying 或只要 progress”更接近用户真实感知。

### Goal C: loading UI 结构统一

详情页和全屏页都改为共享的中心 loading 组件语义：

- 中心转圈
- 一行实时网速文本
- 纯展示，不拦截焦点和遥控器按键

视觉允许在详情页 / 全屏页按尺寸略调，但信息结构一致。

## Proposed Changes

### 1. 新增 TV 播放 loading 指示器组件

新增一个 TV 专用展示组件，建议放在：

- `lib/tv_app/widgets/tv_player_loading_indicator.dart`

职责：

- 展示中心转圈
- 展示网速文本
- 支持详情页 / 全屏页复用
- 使用 `IgnorePointer`，不截断焦点行为

建议接口：

```dart
class TvPlayerLoadingIndicator extends StatelessWidget {
  final Key? spinnerKey;
  final String speedText;
  final double spinnerSize;
}
```

说明：

- `spinnerKey` 便于详情页 / 全屏页继续保留现有测试 key
- `speedText` 由页面层计算后传入，避免组件反向持有播放器状态

### 2. 新增共享的 loading 可见性判断语义

不强行先抽一个巨型 service；先把共用语义收敛成小型 helper / getter 模式，避免本轮抽象过度。

建议新增一组共享概念：

- `hasPlaybackProgressSignal`
- `isPlayerActivelyLoading`
- `hasPlayableTimeline`
- `isSeekRecoveryPending`
- `isVisualPlaybackReady`

其中 `isVisualPlaybackReady` 作为“可以隐藏中心 loading”的统一语义：

```dart
isVisualPlaybackReady =
  !isPlayerActivelyLoading &&
  hasPlaybackProgressSignal &&
  hasPlayableTimeline &&
  !isSeekRecoveryPending
```

页面层再用：

```dart
shouldShowCenterLoading = inInitialLoadOrSeekRecovery && !isVisualPlaybackReady
```

### 3. 详情页补“首次进入 loading”和“seek 恢复 loading”的来源拆分

详情页当前 `_previewPlayerLoading` 已经涵盖部分首播链路，但要额外明确“为什么现在在 loading”：

- `initialPlaybackLoading`
- `seekRecoveryLoading`

这样能避免后续逻辑继续把所有 loading 混成一个布尔值。

本轮不一定要暴露成 enum，但内部至少要能区分来源，便于：

- 首次进入显示网速
- 长按 seek 松手恢复时显示网速
- 普通暂停 / 普通菜单不误亮 loading

### 4. 全屏页补“长按松手后的恢复 loading”

全屏当前已有 `_isPlaybackLoading` 与 seek overlay，但要把“长按松手后，播放器仍在追平目标画面”的窗口明确纳入 loading。

建议在 seek 交互链路中：

- key down 连续 seek 期间仍以 seek overlay 为主
- key up 后若仍未 `isVisualPlaybackReady`，切入中心 loading
- 一旦恢复播放，立即隐藏 loading 与网速

也就是说：

- “正在拖动预览”与“松手后等待恢复”是两种不同中间态
- 前者显示 seek overlay
- 后者显示 center loading

继续观看路径沿用同一语义：

- 即使 `onPlay` / `onReady` 先到了，只要续播补 seek 还没追平到目标位置，就仍视为恢复中
- 只有在真实进度已追平/恢复后，才允许隐藏 center loading

### 5. 网速展示优先支持，拿不到就优雅降级

当前仓库没有播放器通用网速 API，因此本轮不建议深挖底层网络层。

当前已确认的实现策略：

- 先保留可更新的 `speedText` 接口
- 若当前播放器链路拿不到稳定可信的实时吞吐量，则直接降级为仅显示 `加载中`
- 不为了保住数字速率而引入不可信估算，避免让用户感觉“数字在跳，但并不说明真实恢复状态”

也就是说：

- 数字速率是增强项
- `加载中` 文案和正确的显示/隐藏时机才是本任务主目标

### 6. loading 占位层分场景配色

为了同时满足“圈不能被原生视图盖住”和“详情页视觉不要像突然切成一整块黑屏”：

- 非全屏详情页：
  - 继续采用“替换播放器区域”的结构，而不是简单叠加背景
  - 占位层底色使用页面原背景色
- 全屏页：
  - 保持黑底占位

这样结构统一，视觉口径按场景区分。

## File Plan

重点文件：

- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- `lib/tv_app/widgets/tv_player_loading_indicator.dart`（新增）
- 如确有必要，少量触及 `lib/widgets/video_player_widget.dart` 或 `lib/widgets/player_adapter.dart`

测试：

- `test/tv_app/tv_video_detail_screen_test.dart`
- `test/tv_app/tv_fullscreen_player_screen_test.dart`

## Compatibility / Risk

### 风险 1: 退出条件过严，导致转圈不消失

如果 `isVisualPlaybackReady` 过严，可能再次出现“已经在播，转圈仍残留”。

控制策略：

- 保留现有 `onPlay` / progress 信号作为重要输入，但不单独作为唯一退出条件
- 用测试覆盖“收到恢复进度后立即隐藏”

### 风险 2: 退出条件过松，导致黑屏时提前消失

如果仍只靠 `isPlaying / progress`，就会回到当前问题。

控制策略：

- seek 恢复态单独建模
- loading / buffering 主态不能直接忽略

### 风险 3: 网速取值不稳定

播放器端如果拿不到稳定吞吐量，网速文本会抖动或失真。

控制策略：

- speed 文本做降频更新
- 无值时显示保守占位，不阻塞整个 loading 改造

## Rollback Shape

如果实现后发现网速链路不稳定：

1. 保留“更精准的 loading 显示/隐藏判断”
2. 临时回退为只显示转圈，不显示数值网速

也就是说，本任务最关键的价值是“转圈与真实出画面同步”，网速数值是第二优先级。
