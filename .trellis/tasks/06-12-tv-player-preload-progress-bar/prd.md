# TV播放器预加载进度条优化

## Goal

在 TV 端详情页和全屏播放器的进度条上显示缓冲进度（浅灰色条），并放大进度条尺寸以提升 TV 屏幕上的可读性。

## 已确认事实（来自代码库分析）

### 当前进度条实现
- TV 进度条在 `tv_fullscreen_player_screen.dart:3772` 的 `_buildBottomProgressBar()` 中自定义构建
- 不使用 Flutter Slider，完全由 Stack/Container/Positioned 手写
- 当前尺寸：轨道高 3px，当前时间圆点 10x10
- 只在暂停/seek 时显示（`_shouldShowPlaybackChrome`），播放中隐藏

### 缓冲数据链路（已通，仅 UI 层未用）
- Exo 内核（默认）→ `VideoPlayerAdapter._resolveCachedRanges()` → `controller.value.buffered` → `List<PlayerCachedRange>` ✓
- WebView 内核 → JS bridge → `List<PlayerCachedRange>` ✓
- `PlayerAdapterState.cachedRanges` 和 `PlayerAdapter.stream.cachedRanges` 已有
- 手机端和 PC 端 UI 已有缓冲进度条，TV 端完全缺失

### 已有可复用资源
- `resolvePlayerCachedProgressSegments()`：`List<PlayerCachedRange>` → 归一化分段
- `findPrimaryPlayerCachedRange()`：找当前播放位的缓冲区间
- `mergePlayerCachedRanges()`：合并重叠区间
- 手机端 `mobile_player_controls.dart:2343` 分段渲染参考实现

## Requirements

### R1: 进度条常驻显示
- 修改 `_shouldShowPlaybackChrome` 逻辑，使底部进度条在播放中保持可见
- 进度条区域包含：播放/暂停按钮、当前时间、进度条（含缓冲）、总时长、全屏按钮

### R2: 缓冲进度条
- 在进度条轨道上叠加浅灰色缓冲段，位置对应 `cachedRanges` 数据
- 缓冲显示范围截断至当前播放位置 + 3 分钟（`position + 3min`），超出的不显示
- 复用 `resolvePlayerCachedProgressSegments()` 计算分段位置
- 参考手机端 `mobile_player_controls.dart` 的渲染方式

### R3: 进度条尺寸放大
- 轨道高度：3px → 6px（×2）
- 当前时间圆点：10x10 → 15x15（×1.5）

### R4: 数据层暴露
- `VideoPlayerWidgetController` 新增 `cachedRanges` getter
- `TvFullscreenPlaybackController` 新增 `cachedRanges` getter

### R5: 详情页同步改造
- 详情页的嵌入播放器进度条与全屏保持一致：常驻显示 + 缓冲条 + 放大尺寸
- 详情页和全屏共享同一播放器实例，缓冲数据自然同步

## Acceptance Criteria

- [ ] 播放中能看到底部进度条（不再自动隐藏）
- [ ] 进度条上显示浅灰色缓冲段，范围不超过当前播放位 + 3 分钟
- [ ] 进度条轨道高 6px，时间圆点 15x15
- [ ] 详情页和全屏播放器进度条表现一致
- [ ] Exo 和 WebView 两种内核都能显示缓冲进度
- [ ] 低端设备（2GB 运存）上不影响播放流畅度

## Out of Scope

- 不主动触发预加载缓冲，仅显示播放器已有的缓冲数据
- 不改变播放器的缓冲策略
- 不修改手机端/PC端的进度条
