# 执行计划：TV端加载阴影、续播源等待、ESC返回卡顿

## 概览

- 改动文件: 3 个
- 风险: 低（改动集中，逻辑清晰）
- 回滚: 恢复 3 个文件即可

## Step 1: R1 — 加载转圈投影改造

**文件**: `lib/tv_app/screens/tv_video_detail_screen.dart`

- [ ] 找到 `_buildPreviewLoadingOverlay()` 方法
- [ ] 移除双 `CircularProgressIndicator` 重叠的 Stack 结构
- [ ] 替换为单 `CircularProgressIndicator`，用 `Container` 包裹 + `BoxDecoration(boxShadow)`:
  ```dart
  Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 4,
          offset: const Offset(2, 2),
        ),
      ],
    ),
    child: CircularProgressIndicator(
      color: palette.accent,
      strokeWidth: 3,
    ),
  )
  ```
- [ ] 文字"加载中..."保持现有 Shadow 不变
- [ ] 标记 `_shadow` 结尾的旧变量名（如有）

**文件**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

- [ ] 找到 `_buildFullscreenLoadingOverlay()` 方法
- [ ] 同样移除双 spinner，替换为单圈 + BoxShadow
- [ ] 圈颜色保持白色（全屏是黑底）
- [ ] 文字保持现有 Shadow 不变

**验证**: 编译通过，视觉确认单圈+投影效果

## Step 2: R2 — 续播源等待逻辑

**文件**: `lib/tv_app/screens/tv_video_detail_screen.dart`

- [ ] 新增状态变量:
  ```dart
  ({String source, String id})? _resumeSourceTarget;
  ```
- [ ] 在 `_loadResumeRecord` 完成回调中设置 `_resumeSourceTarget`（从 `PlayRecord` 提取 `source` + `id`）
- [ ] 新增辅助方法:
  ```dart
  bool _sourceMatchesResumeTarget(SearchResult detail) {
    final target = _resumeSourceTarget;
    if (target == null) return true; // 无续播目标
    return detail.source == target.source && detail.id == target.id;
  }
  ```
- [ ] 修改 `_onNewIncrementalSource` / 源选择逻辑：在确定可播源后检查 `_sourceMatchesResumeTarget`，不命中则暂不起播
- [ ] 新增回退逻辑 `_checkResumeFallback()`: 当精确源和补源都完成但未命中续播目标时，用最佳可用源起播
- [ ] 在 `_handleDetailBackPressed` 中不再等待续播匹配，直接退出

**验证**: 从继续观看进入，确认播放的是续播源；ESC 中途退出无等待

## Step 3: R3 — ESC 高优先级打断

**文件**: `lib/tv_app/screens/tv_video_detail_screen.dart`

- [ ] 修改 `_handleDetailBackPressed()`:
  ```dart
  // 改造前: await _saveProgress → _isExitingDetail = true → pop
  // 改造后:
  Future<void> _handleDetailBackPressed() async {
    if (_isExitingDetail) return;
    _isExitingDetail = true;
    unawaited(_saveProgress(force: true)); // 后台保存
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }
  ```
- [ ] 在以下异步回包点增加 `_isExitingDetail` 早停:
  - `_loadInitialSources` 完成处理开头
  - `_loadMoreSources` 增量回包开头
  - `_loadResumeRecord` 回包开头
  - `_handleAdFilterPreference` 回包开头
  - `_loadPlayerKernelPreference` 回包开头
  - `_onPlayerControllerCreated` 开头
  - `_tryInitialPlaybackDispatch` 内部
- [ ] 在所有 `addPostFrameCallback` 回调开头增加 `if (!mounted || _isExitingDetail) return;`
- [ ] 修改 `dispose()`: 增加 `_hasManuallySavedOnExit` 检查避免重复保存

**验证**: 进入详情页后立刻 ESC，确认无卡顿返回；进入全屏后 ESC，确认不受影响

## Step 4: 品质验证

- [ ] `flutter analyze` 无新增问题
- [ ] 从继续观看进入详情页，确认源正确
- [ ] 详情页加载中 ESC，确认流畅返回
- [ ] 全屏播放器 ESC 返回正常
- [ ] 加载转圈视觉效果清爽（单圈+投影）

## 关键引用

| 内容 | 位置 |
|------|------|
| `_buildPreviewLoadingOverlay()` | `tv_video_detail_screen.dart` ~4634 |
| `_buildFullscreenLoadingOverlay()` | `tv_fullscreen_player_screen.dart` ~3499 |
| `_handleDetailBackPressed()` | `tv_video_detail_screen.dart` ~4085 |
| `_loadInitialSources()` | `tv_video_detail_screen.dart` ~970 |
| `_loadMoreSources()` | `tv_video_detail_screen.dart` ~1040 |
| `_loadResumeRecord()` | `tv_video_detail_screen.dart` ~1060 |
| `_tryInitialPlaybackDispatch()` | `tv_video_detail_screen.dart` ~2100 |
| `_handleExitWithSave()` | `tv_fullscreen_player_screen.dart` ~1508 |
| `TvBackHandler` | `tv_back_handler.dart` |
| research 目录 | `06-13-fix-tv-loading-shadow-back-stall/research/` |
