# 技术设计：TV端加载阴影、续播源等待、ESC返回卡顿

## 1. 变更边界

| 文件 | 变更 |
|------|------|
| `lib/tv_app/screens/tv_video_detail_screen.dart` | R1 加载阴影 + R2 续播等待 + R3 ESC打断 |
| `lib/tv_app/screens/tv_fullscreen_player_screen.dart` | R1 加载阴影 |
| `lib/tv_app/widgets/tv_back_handler.dart` | R3 暴露打断能力（无状态变更） |

## 2. R1: 加载转圈投影

### 2.1 当前结构

```dart
// _buildPreviewLoadingOverlay() / _buildFullscreenLoadingOverlay()
Stack(children: [
  Positioned(1, 1, CircularProgressIndicator(shadowColor)),
  CircularProgressIndicator(accent/white),
])
```

### 2.2 改造后

```dart
// 单圈 + BoxShadow 投影
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
    color: accent/white,  // 保持原色
    strokeWidth: 3,       // 略加粗，投影下更清晰
  ),
)
```

**文字阴影**：已有 `Shadow` 在 `TextSpan` 上，保持不变。

**改点位置**:
- 详情页: `_buildPreviewLoadingOverlay()` (line ~4634)
- 全屏: `_buildFullscreenLoadingOverlay()` (line ~3499)

## 3. R2: 继续播放等待命中续播源

### 3.1 当前流程

```
进入详情页
  → _loadInitialSources() 发精确源搜索
  → _loadMoreSources() 发标题补源（SSE）
  → 首个可播源到达 → _tryInitialPlaybackDispatch() 起播
  → 续播记录返回 → _restoreSavedSourceAfterResumeRecordLoaded() 纠正源
```

问题：`_tryInitialPlaybackDispatch()` 在续播记录返回前可能用非续播源起播。

### 3.2 改造后流程

```
进入详情页
  → _loadResumeRecord()           ← 第一优先级
  → _loadInitialSources()         ← 并行
  → _loadMoreSources()            ← 并行
  → 续播记录返回 → 记录 resumeTarget (source+id)
  → 源到达 → _tryMatchResumeSource()
    → 命中 resumeTarget → 起播
    → 未命中 → 继续等待下一个源
  → 超时/无续播记录 → 回退用首个可播源起播
```

### 3.3 核心逻辑

```dart
// 新增状态
({String source, String id})? _resumeSourceTarget;

// 在 _loadResumeRecord 回调中设置
void _setResumeSourceTarget(PlayRecord? record) {
  if (record == null) return;
  _resumeSourceTarget = (source: record.source, id: record.id);
}

// 在源到达时检查
bool _sourceMatchesResumeTarget(SearchResult detail) {
  final target = _resumeSourceTarget;
  if (target == null) return true; // 无续播目标，任何源都可以
  return detail.source == target.source && detail.id == target.id;
}

// 修改 _tryInitialPlaybackDispatch
void _tryInitialPlaybackDispatch() {
  if (_hasResolvedInitialPlayableSource) return;
  // ... 找可播源 ...
  if (!_sourceMatchesResumeTarget(detail)) return; // ← 新增检查
  // ... 起播 ...
}

// ESC 打断: _isExitingDetail 新增检查
bool get _canContinueWaiting => mounted && !_isExitingDetail;
```

### 3.4 超时处理

如果续播记录有目标源但流式搜索一直没命中（例如该源已下线），设置搜索完成超时回退：

```dart
// 当精确源搜索和标题补源都完成后，若仍无命中，用最佳可用源起播
void _checkResumeTimeout() {
  if (_resumeSourceTarget != null &&
      _hasCompletedInitialSource &&
      _hasCompletedMoreSources &&
      !_hasResolvedInitialPlayableSource) {
    // 回退：用当前最佳匹配源起播
    _dispatchFirstAvailableSource();
  }
}
```

## 4. R3: ESC 高优先级打断

### 4.1 当前流程（问题）

```dart
Future<void> _handleDetailBackPressed() async {
  if (_isExitingDetail) return;
  await _saveProgress(force: true);  // ← 阻塞等数据库
  _isExitingDetail = true;            // ← 太晚了
  Navigator.of(context).pop();
}
```

### 4.2 改造后

```dart
Future<void> _handleDetailBackPressed() async {
  if (_isExitingDetail) return;
  _isExitingDetail = true;            // ← 前置！立即停止所有异步任务
  _stopAllPendingAsyncTasks();        // ← 取消加载、搜索、播放器创建
  unawaited(_saveProgress(force: true)); // ← 后台保存
  if (mounted) {
    Navigator.of(context).maybePop();
  }
}

void _stopAllPendingAsyncTasks() {
  _cancelSourceSearch();
  _cancelMoreSources();
  _cancelResumeRecordRequest();
  _cancelPlayerInitialization();
}
```

### 4.3 异步中断检查点

在以下异步操作中插入 `_isExitingDetail` 早停检查：

| 位置 | 当前 | 改造后 |
|------|------|--------|
| `_loadInitialSources` 回包 | 直接处理 | `if (_isExitingDetail) return;` |
| `_loadMoreSources` 增量回包 | 直接处理 | `if (_isExitingDetail) return;` |
| `_loadResumeRecord` 回包 | 设置状态 | `if (_isExitingDetail) return;` |
| `_handleAdFilterPreference` | 设置状态 | `if (_isExitingDetail) return;` |
| `_loadPlayerKernelPreference` | 更新播放器 | `if (_isExitingDetail) return;` |
| `_tryInitialPlaybackDispatch` | 起播 | 已有检查 `_currentDetail != null`，增加退出检查 |
| `_onPlayerControllerCreated` | 挂控制器 | `if (_isExitingDetail) return;` |
| `addPostFrameCallback` 各处 | 执行回调 | `if (!mounted \|\| _isExitingDetail) return;` |

### 4.4 详情页加载/搜索取消

`_loadInitialSources` 和 `_loadMoreSources` 当前是通过 `_searchService` 发起的网络请求。需要支持取消：

```dart
// 方案：用 CancellationToken 或标志位
// TvVideoDetailScreen 内部已有 _isExitingDetail，直接在回包处理中检查
```

不需要引入额外取消机制，只需在回包/setState 前检查 `_isExitingDetail` 即可。网络请求本身可以继续完成，但结果被丢弃。

### 4.5 dispose 去重

当前 `dispose()` 也会调用 `_saveProgress(force: true)`。增加检查避免重复保存：

```dart
void dispose() {
  _isExitingDetail = true;
  if (!_hasManuallySavedOnExit) {
    _saveProgress(force: true); // dispose 兜底，但正常退出已保存过
  }
  // ...
}
```

## 5. 兼容性

- R2 不影响非续播路径（直接点击卡片进入详情页时 `_resumeSourceTarget` 为 null，立即起播）
- R3 不影响全屏播放器（退出逻辑已正确）
- R1 不影响非 TV 端（独立函数）

## 6. 风险

- R2: 如果续播源已下线，等待所有搜索完成后才回退，可能延长首播等待时间 → 设置搜索完成后立即回退
- R3: `unawaited` 保存可能在 crash 时丢失进度 → 权衡可接受（全屏播放器已有相同策略）
