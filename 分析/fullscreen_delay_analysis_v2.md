# 全屏点击后播放器延迟放大的原因分析（移动端）

本文只分析 `lib/widgets/mobile_player_controls.dart` 触发全屏后，界面旋转先发生、播放器尺寸稍后才变化的原因。不修改代码。

## 1. 直接调用链（无显式延时）
- 全屏按钮点击 -> `_enterFullscreen()`
  - 位置：`lib/widgets/mobile_player_controls.dart`（约 1427-1450）
- `_enterFullscreen()` 仅做两件事：
  - `widget.onFullscreenChange(true)` 通知上层
  - `setState(() => _isFullscreen = true)` 更新控制层 UI
  - 位置：`lib/widgets/mobile_player_controls.dart`（约 499-507）
- 上层 `PlayerScreen` 接收回调 `_onFullscreenChanged`：
  - `setState(() => _isFullscreen = isFullscreen)`
  - `SystemChrome.setPreferredOrientations(...)`
  - `SystemChrome.setEnabledSystemUIMode(...)`
  - 位置：`lib/screens/player_screen.dart`（约 1145-1166）
- 播放器真正填满屏幕的逻辑在 `_buildPlayerLayer`：
  - 手机模式下 `_isFullscreen == true` 时走 `Positioned.fill`
  - 位置：`lib/screens/player_screen.dart`（约 3863-3943）

结论：控制层与上层都没有写任何 0.5s 的延时逻辑。

## 2. 控制层先“进入全屏”的原因
`MobilePlayerControls` 的全屏判断依赖：
```
_isEffectiveFullscreen = (MediaQuery.size.width > height) || _isFullscreen
```
位置：`lib/widgets/mobile_player_controls.dart`（约 110-118）

这意味着：
- 点击按钮后 `_isFullscreen` 立即为 true
- 控制层 UI 立即切换为“全屏样式”
- 但播放器 Surface 的尺寸仍要等平台方向切换与布局刷新完成

## 3. 为什么会出现 0.3-0.5s 的“播放器尺寸滞后”
这是常见的跨平台链路延迟，主要由以下几个低层阶段叠加造成：

1) 平台方向切换是异步
- `SystemChrome.setPreferredOrientations` 通过平台通道交给系统处理
- Android 会触发 Activity 方向变化和窗口重算

2) Flutter 等待窗口指标（window metrics）更新
- 只有当系统完成方向切换并上报新尺寸
- Flutter 才会触发新的 layout / build

3) 视频 Surface/Texture 的尺寸更新更慢
- 媒体播放组件通常依赖平台视图或 SurfaceTexture
- 这些对象的大小更新通常发生在下一帧或几帧之后
- 因此播放器视觉尺寸比 UI 切换慢 1-2 个阶段是正常现象

综合结果：
- 先看到系统旋转
- 播放器仍沿用旧的尺寸约束
- 等平台和 Flutter 同步完毕后才真正铺满

## 4. 代码侧能解释的现象
- `MobilePlayerControls` 只切控制层状态，不控制播放器尺寸。
- `PlayerScreen` 通过 `_isFullscreen` 决定是否 `Positioned.fill`。
- 真实视觉变化依赖方向切换完成后的窗口尺寸和平台 Surface 重新绑定。

## 5. 结论
你看到的“0.5 秒后才真正全屏”，更像是系统方向切换 + Flutter 布局 + 视频 Surface 重新绑定的综合延迟，而不是 `mobile_player_controls.dart` 里存在的显式延时或定时器逻辑。
