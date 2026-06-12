# 执行计划：TV播放器预加载进度条优化

## 概览

- 改动文件: 3 个（+ 可能抽公共方法到工具层）
- 风险等级: 低（集中在 UI 层，数据层只需加 getter）
- 回滚方式: 恢复改动文件即可

## 执行步骤

### Step 1: 数据层 — 暴露 `cachedRanges`

**文件**: `lib/widgets/video_player_widget.dart`

- [ ] 在 `VideoPlayerWidgetController` 类中新增 getter:
  ```dart
  List<PlayerCachedRange> get cachedRanges =>
      _state._currentPreloadProgressRanges;
  ```
- [ ] 确认 `_currentPreloadProgressRanges` 在无数据时返回 `const []`

**验证**: IDE 无编译错误，getter 可被外部访问

### Step 2: 接口层 — `TvFullscreenPlaybackController` 新增接口

**文件**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

- [ ] 在 `TvFullscreenPlaybackController` 抽象类中新增:
  ```dart
  List<PlayerCachedRange> get cachedRanges;
  ```
- [ ] 在全屏内部实现中添加 getter（委托到 `_playerController?.cachedRanges`）

**文件**: `lib/tv_app/screens/tv_video_detail_screen.dart`

- [ ] 在 `_TvDetailFullscreenPlaybackController` 中实现:
  ```dart
  @override
  List<PlayerCachedRange> get cachedRanges =>
      _controller?.cachedRanges ?? const [];
  ```

**验证**: 编译通过，两种控制器都能返回缓存区间

### Step 3: 全屏进度条 — 尺寸放大

**文件**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

- [ ] 修改 `_buildBottomProgressBar()`:
  - 背景轨道 `height: 3` → `height: 6`
  - 已播放轨道 `height: 3` → `height: 6`
  - 时间圆点 `width: 10, height: 10` → `width: 15, height: 15`
  - 圆点偏移 `(playedWidth - 5)` → `(playedWidth - 7.5)`
  - `knobLeft` clamp: `.clamp(0.0, trackWidth - 10.0)` → `.clamp(0.0, trackWidth - 15.0)`

**验证**: 编译通过，肉眼确认尺寸变化

### Step 4: 全屏进度条 — 缓冲段渲染

**文件**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

- [ ] 在 `_buildBottomProgressBar()` 的 LayoutBuilder 内部新增缓冲段计算:
  ```dart
  // 获取缓冲区间
  final cachedRanges = widget.playbackController?.cachedRanges ?? const [];

  // 截断至 position + 3min
  final preloadCap = clampedPosition + const Duration(minutes: 3);
  final cappedCap = duration > Duration.zero && preloadCap > duration
      ? duration : preloadCap;

  // 调用已有工具计算分段
  final segments = resolvePlayerCachedProgressSegments(
    cachedRanges,
    duration: duration,
  );
  ```
- [ ] 在 Stack 中背景轨道和已播放轨道之间插入缓冲段:
  ```dart
  // 缓冲段（浅灰色条）
  for (final segment in segments)
    Positioned(
      left: segment.start * trackWidth,
      child: Container(
        width: ((segment.end > cappedRatio ? cappedRatio : segment.end) - segment.start) * trackWidth,
        height: 6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    ),
  ```
- [ ] 添加 import `player_cached_range_utils.dart`（如尚未导入）

**验证**: 播放有缓冲进度的视频，确认进度条上出现灰色缓冲段

### Step 5: 全屏进度条 — 常驻显示

**文件**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

- [ ] 修改 `_shouldShowPlaybackChrome`:
  ```dart
  // 改造前
  (_seekOverlayVisible || !_isPlaybackPlaying)

  // 改造后: 播放中仍然显示
  true  // 即只保留 !_menuVisible && !_isPlaybackLoading
  ```
  即最终为:
  ```dart
  bool get _shouldShowPlaybackChrome {
    return !_menuVisible && !_isPlaybackLoading;
  }
  ```

**验证**: 播放中底栏保持可见，菜单打开时隐藏，加载中时隐藏

### Step 6: 详情页 — 新增进度条覆盖层

**文件**: `lib/tv_app/screens/tv_video_detail_screen.dart`

- [ ] 新增 `_buildDetailProgressBar()` 方法，结构参考全屏版但尺寸缩小:
  - 轨道高 4px，圆点 10x10
  - 字号 14
  - 无全屏按钮（详情页已有其他入口）
  - 包含缓冲段渲染（与全屏相同逻辑）
- [ ] 从 `_playerController?.cachedRanges` 读取缓冲数据
- [ ] 在 `_buildPlayerBox()` 的 Stack children 中追加:
  ```dart
  if (_previewPlaybackStarted && _currentDetail != null)
    Positioned(
      left: 0, right: 0, bottom: 0,
      child: _buildDetailProgressBar(),
    ),
  ```
- [ ] 进度条用 `IgnorePointer` 包裹，不拦截焦点事件

**验证**: 详情页播放器中可见进度条，格式与全屏版一致但稍小

### Step 7: 品质验证

- [ ] `flutter analyze` 无新增警告
- [ ] Exo 内核下缓冲条正常显示
- [ ] WebView 内核下缓冲条正常显示（如有条件测试）
- [ ] 播放中底栏常驻，不遮挡关键内容
- [ ] 菜单打开/加载中时底栏正确隐藏
- [ ] 缓冲为空时无异常（不显示缓冲段）
- [ ] 详情页和全屏进度条表现一致

## 关键引用

| 内容 | 位置 |
|------|------|
| `_buildBottomProgressBar()` | `tv_fullscreen_player_screen.dart:3772` |
| `_shouldShowPlaybackChrome` | `tv_fullscreen_player_screen.dart:1845` |
| `VideoPlayerWidgetController` | `video_player_widget.dart:226` |
| `_currentPreloadProgressRanges` | `video_player_widget.dart:434` |
| `TvFullscreenPlaybackController` | `tv_fullscreen_player_screen.dart:61` |
| `_TvDetailFullscreenPlaybackController` | `tv_video_detail_screen.dart:5093` |
| `_buildPlayerBox()` | `tv_video_detail_screen.dart:4399` |
| `resolvePlayerCachedProgressSegments()` | `utils/player_cached_range_utils.dart` |
| 手机端缓冲渲染参考 | `mobile_player_controls.dart:2343` |
