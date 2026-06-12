# 技术设计：TV播放器预加载进度条优化

## 1. 变更边界

### 涉及文件

| 文件 | 变更性质 |
|------|----------|
| `lib/widgets/video_player_widget.dart` | 暴露 `cachedRanges` getter |
| `lib/tv_app/screens/tv_fullscreen_player_screen.dart` | 修改进度条 UI + 显示逻辑 |
| `lib/tv_app/screens/tv_video_detail_screen.dart` | 新增进度条覆盖层 + 控制器暴露 |
| `lib/utils/player_cached_range_utils.dart` | 只读引用（已有，不改） |

### 不涉及
- `player_adapter.dart`（数据链路已通，不改）
- 手机端/PC端控件（不在范围内）
- 播放器缓冲策略（不干预 media_kit/Exo 内部缓冲逻辑）

## 2. 数据层设计

### 2.1 缓存区间查询链

```
PlayerAdapter.state.cachedRanges          ← 底层播放器缓冲数据
  ↓ (已有 stream 订阅)
_VideoPlayerWidgetState._currentPreloadProgressRanges  ← 持久化合并后的缓存区间
  ↓ (新增 getter)
VideoPlayerWidgetController.cachedRanges   ← [新增] 公开 getter
  ↓ (已有适配器模式)
TvFullscreenPlaybackController.cachedRanges ← [新增] 接口方法
  ↓ (UI 层消费)
_buildBottomProgressBar()                  ← 渲染缓冲条
```

### 2.2 `VideoPlayerWidgetController` 新增 getter

```dart
// 位置: video_player_widget.dart:226 VideoPlayerWidgetController
List<PlayerCachedRange> get cachedRanges =>
    _state._currentPreloadProgressRanges;
```

直接委托到已有的 `_currentPreloadProgressRanges`（已聚合合并、去重）。

### 2.3 `TvFullscreenPlaybackController` 新增接口

```dart
// 位置: tv_fullscreen_player_screen.dart:61
abstract class TvFullscreenPlaybackController {
  // ... 已有方法 ...

  /// 当前播放器已缓冲的区间列表。
  List<PlayerCachedRange> get cachedRanges;
}
```

`_TvDetailFullscreenPlaybackController`（详情页适配器）直接委托：
```dart
List<PlayerCachedRange> get cachedRanges =>
    _controller?.cachedRanges ?? const [];
```

全屏播放器内部 `_TvInternalPlaybackController` 同理。

### 2.4 缓冲监听（实时更新）

进度条已在 `_scheduleChromeRefresh` 中定期刷新（通过 `addProgressListener` / `addNetworkSpeedListener` 触发 setState）。缓冲区间更新时需同步触发 chrome refresh。方法：在 `_listenCachedRanges` 中订阅 `_adapter.stream.cachedRanges`。

或者更轻量的方式：在已有的进度监听回调中顺带读取 `cachedRanges`（缓冲通常和播放位置同步更新），不额外增加订阅。

## 3. UI 层设计

### 3.1 全屏播放器进度条改造

**位置**: `tv_fullscreen_player_screen.dart:3772` `_buildBottomProgressBar()`

当前 Stack 层级（3 层）:
```
Container (背景轨道, 白色 54% alpha, 3px)
Container (已播放轨道, accent 色, 3px, proportional width)
Positioned > Container (时间圆点, 10x10, accent 色)
```

改造后 Stack 层级（4 层）:
```
Container (背景轨道, 白色 54% alpha, 6px)              ← 高度 x2
Container (缓冲段, 浅灰 白色 24% alpha, 6px, 截断至 position+3min)  ← 新增
Container (已播放轨道, accent 色, 6px, proportional width)  ← 高度 x2
Positioned > Container (时间圆点, 15x15, accent 色)   ← 尺寸 x1.5
```

**缓冲段位置计算**:
```dart
// 截断上限: 当前播放位置 + 3 分钟
final preloadCap = clampedPosition + const Duration(minutes: 3);
final cappedCap = preloadCap > duration ? duration : preloadCap;

// 调用已有工具函数
final segments = resolvePlayerCachedProgressSegments(
  cachedRanges,
  duration: duration,
);
// 过滤: 只保留 end <= cappedCap 的分段，截断跨界的
```

**knobLeft 调整**: 圆点放大后偏移量从 `-5` 改为 `-7.5`

### 3.2 进度条常驻显示

**位置**: `tv_fullscreen_player_screen.dart:1845` `_shouldShowPlaybackChrome`

```dart
// 改造前
bool get _shouldShowPlaybackChrome {
  return !_menuVisible &&
      !_isPlaybackLoading &&
      (_seekOverlayVisible || !_isPlaybackPlaying);
}

// 改造后: 移除 "播放中隐藏" 条件
bool get _shouldShowPlaybackChrome {
  return !_menuVisible && !_isPlaybackLoading;
}
```

播放中时底栏常驻显示（进度条 + 时间 + 播放/暂停按钮），只有当菜单打开或加载中时才隐藏。

### 3.3 详情页新增进度条覆盖层

**位置**: `tv_video_detail_screen.dart:4399` `_buildPlayerBox()`

详情页当前在 `AspectRatio(16/9)` 的播放器上**没有任何进度条**。需要新增一个底部覆盖层，仅当播放中有数据时显示。

在 `_buildPlayerBox` 的 Stack 中新增一层：
```dart
Positioned(
  left: 0, right: 0, bottom: 0,
  child: _buildDetailProgressBar(),  // 新增
)
```

`_buildDetailProgressBar()` 结构（简化版，无全屏按钮）:
```
Row
  Icon (play/pause, size 16)
  SizedBox(width: 6)
  Text (current time, smaller font)
  SizedBox(width: 10)
  Expanded > Stack [背景轨道 / 缓冲段 / 已播放轨道 / 圆点]
  SizedBox(width: 10)
  Text (total duration)
```

详情页进度条不需要额外的全屏/设置按钮（那些入口在详情页其他位置已有）。

尺寸可比全屏略小（详情页播放器面积有限）：
- 轨道高度: 4px (全屏 6px × 2/3 比例)
- 圆点: 10x10 (全屏 15x15 × 2/3 比例)
- 字号: 14 (全屏 17 × ~0.8)

### 3.4 缓冲数据获取路径

**全屏播放器**:
```dart
final cachedRanges = widget.playbackController?.cachedRanges ?? const [];
```

**详情页**:
```dart
final cachedRanges = _playerController?.cachedRanges ?? const [];
```

当 `_playerController` 尚未挂载时，不显示缓冲条（显示为空缓冲）。

### 3.5 缓冲条颜色

参考手机端 `Colors.white.withValues(alpha: 0.34)`，TV 端使用更淡的灰色以区分背景轨道：
- 背景轨道: `Colors.white.withValues(alpha: 0.54)` (不变)
- 缓冲段: `Colors.white.withValues(alpha: 0.24)`
- 已播放: `palette.accent` (不变)

## 4. 兼容性

### 4.1 内核兼容
- Exo (`VideoPlayerAdapter`): `cachedRanges` 来自 `controller.value.buffered` ✓
- WebView (`WebViewPlayerAdapter`): `cachedRanges` 来自 JS bridge ✓
- 两种内核都实现了 `PlayerAdapter` 接口，`cachedRanges` 为必须实现的方法

### 4.2 状态兼容
- 缓冲为空时（如直播流）: `resolvePlayerCachedProgressSegments` 返回空列表，不渲染任何缓冲段
- 播放器未就绪时: `cachedRanges` 返回空列表

### 4.3 性能考量 (2GB 低端设备)
- 缓冲区间更新频率低（通常秒级），setState 开销可接受
- 不新增 AnimationController
- 不新增 FocusNode
- 进度条已通过 `IgnorePointer` 包裹，不影响焦点系统

## 5. 风险与回滚

- **风险**: `_shouldShowPlaybackChrome` 改为常驻后，某些之前依赖"播放中隐藏"的场景可能受影响
- **缓解**: 菜单打开时仍隐藏 (`!_menuVisible` 条件保留)，加载中仍隐藏 (`!_isPlaybackLoading` 条件保留)
- **回滚**: 恢复 `_shouldShowPlaybackChrome` 的旧逻辑 + 移除缓冲条渲染层即可，改动集中在 2 个文件
