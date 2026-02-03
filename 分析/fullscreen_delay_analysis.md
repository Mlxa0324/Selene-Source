# 全屏切换延迟与调用链路分析报告

## 1. 现象描述
在 `MobilePlayerControls` 中点击全屏按钮后，用户会观察到：
1. 屏幕立即发生了物理旋转（由竖屏变为横屏）。
2. 播放器容器（Player Container）在旋转后的约 0.5 秒内仍保持原有的比例或尺寸（通常表现为黑边或布局错位）。
3. 约 0.5 秒后，播放器突然“跳变”填满全屏。

## 2. 完整执行链路 (Call Chain)

### 第一阶段：UI 触发 (MobilePlayerControls)
1. **用户点击**：`_buildBottomControls` 中的全屏切换图标触发 `onTap`。
2. **控制器响应**：调用 `_enterFullscreen()`。
   - 逻辑 A：执行 `widget.state!.enterFullscreen()`。这里的 `state` 是 `media_kit` 的 `VideoState`。
   - 逻辑 B：调用回调 `widget.onFullscreenChange(true)`。

### 第二阶段：回调传递 (VideoPlayerWidget)
3. **中转响应**：`VideoPlayerWidget` 接收到 `onFullscreenChange`，继续向上抛出：
   - 调用 `widget.onFullscreenChanged?.call(true)`。

### 第三阶段：页面响应 (PlayerScreen)
4. **状态变更**：`PlayerScreen._onFullscreenChanged(true)` 被激活。
   - 调用 `setState(() => _isFullscreen = true)`。这会标记 Flutter 的 **Element Tree** 需要重建（Rebuild）。
5. **系统指令**：
   - 通过 `SystemChrome.setPreferredOrientations` 向原生系统（Android/iOS）发送强制横屏指令。
   - 通过 `SystemChrome.setEnabledSystemUIMode` 开启沉浸式模式（隐藏状态栏/导航栏）。

## 3. 延迟产生的底层逻辑分析

### 3.1 系统旋转与 Flutter 重绘的异步性 (Race Condition)
这是导致“先旋转、后缩放”的核心原因。
- **Native 优先**：`SystemChrome` 的指令几乎是瞬时到达原生系统的。原生系统接收到横屏请求后，会立即启动 Activity/ViewController 的旋转动画。
- **Flutter 滞后**：Flutter 的 UI 重建遵循 **Frame Pipeline**。当 `setState` 被调用时，它只是将当前 Frame 标记为 "dirty"。
- **矛盾点**：原生系统旋转后，屏幕的分辨率（宽高比）已经发生了物理改变，但 Flutter 此时可能还未完成下一帧的布局计算，或者正在处理 `SystemChrome` 带来的系统级配置变更（Configuration Changes），导致播放器组件未能第一时间获取到新的 `MediaQuery` 尺寸。

### 3.2 media_kit 的“双重竞争”
代码中同时执行了：
1. `media_kit` 内部的 `enterFullscreen`。
2. `PlayerScreen` 手动触发的 `SystemChrome` 旋转。
`media_kit` 在全屏时通常会创建一个新的全屏路由（FullScreen Route）或使用其内部的 `Video` 组件重新接管渲染。这种内部接管逻辑往往包含获取原生窗口句柄、调整 OpenGL/Vulkan 渲染上下文等，大约需要 **300ms - 500ms** 的初始化耗时。

### 3.3 MediaQuery 的更新时机 (The Layout Lag)
在 `PlayerScreen._buildPlayerLayer` 中，播放器高度之前是这样计算的：
```dart
final playerHeight = _isFullscreen ? screenHeight : screenWidth / (16 / 9);
```
当旋转发生时，Flutter 需要等待 `Window.onMetricsChanged` 回调触发。在 Android 系统上，从发起旋转请求到系统完成 Activity 销毁/重建并反馈给 Flutter 新的宽高数值，标准耗时就在 400ms - 600ms 之间。

### 3.4 沉浸式模式的动画开销
`SystemUiMode.immersiveSticky` 隐藏系统 UI 时，原生系统会执行收缩动画。在此期间，Flutter 的布局引擎有时会等到系统 UI 完全稳定后才触发最后一次精确布局。

## 4. 优化方案建议
1. **消除冗余调用**：屏蔽 `media_kit` 内部的全屏方法，完全由 Flutter 侧控制旋转。
2. **布局强制铺满**：全屏状态下改用 `Positioned.fill`，不再依赖需要计算的 `MediaQuery` 高度值。

---
*分析完成 - Selene 项目组*
