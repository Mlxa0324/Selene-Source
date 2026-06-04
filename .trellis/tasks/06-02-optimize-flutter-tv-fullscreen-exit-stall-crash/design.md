# 优化 Flutter TV 全屏退出卡顿与闪退 - 技术设计

## Scope

本任务处理 Flutter TV 详情页预览播放器与全屏播放器的 loading / 退出状态链路：

- 退出阻塞
- 重复保存
- 生命周期竞态
- 共享 overlay 复用播放器时的时序安全
- 详情页黑底首帧等待时的 loading 转圈和网速提示
- 全屏长按 seek 松手后的 loading 清理

不扩展到：

- Kotlin TV
- 全屏进入性能
- 详情页整体卡顿

## Current Behavior

### 退出主路径

`TvFullscreenPlayerScreen._handleBackKey()` 当前逻辑：

1. 如果菜单打开，先关菜单
2. 否则 `unawaited(_handleExitWithSave())`

而 `_handleExitWithSave()` 当前会：

1. `await _saveProgress(force: true, scene: '全屏返回')`
2. 再触发：
   - `widget.onExitRequested()`
   - 或 `Navigator.maybePop()`

这意味着“可见退出动作”被一次强制保存同步阻塞。

### 额外保存路径

当前退出相关还存在两条额外保存：

- `dispose()` → `unawaited(_saveProgress(force: true, scene: '全屏页销毁'))`
- `_handlePopInvoked(didPop: true)` → `unawaited(_saveProgress(force: true, scene: '全屏系统返回'))`

所以同一轮退出可能出现：

- 返回键路径保存
- pop 完成后再保存
- dispose 再保存

### 共享 overlay 特有风险

从详情页进入全屏 overlay 时：

- `onExitRequested: _closeFullscreenOverlay`
- `reuseExistingPlayer: true`

这意味着退出不只是 pop 一个普通页面，而是：

1. 关闭全屏壳
2. 保留并复用详情页原播放器
3. 恢复详情页焦点
4. 防止晚到回调继续写入已经关闭的全屏页状态

如果退出链路里再叠加同步保存、异步补保存、dispose、focus 恢复，就容易出现：

- 视觉卡住
- 晚到回调
- 小概率已销毁对象访问

## Design Goals

### Goal A: 退出动作优先，保存异步收尾

用户体感里最重要的是“按下 `ESC` 后立刻退出全屏”。

因此退出设计要改为：

- 先执行可见退出动作
- 再在后台做尽量安全的一次进度收尾

而不是先等保存完成。

### Goal B: 单轮退出只允许一个收尾流程

需要把“全屏返回 / 系统返回 / dispose”这三类路径统一到一个退出收尾守卫上：

- 同一轮退出最多只有一个“主动收尾入口”真正触发
- 其它路径只能补兜底，且必须避开重复重活

### Goal C: 共享 overlay 优先避免竞态回写

退出开始后要尽早标记“正在退出”，让以下逻辑停止继续回写：

- 晚到的 progress / save 结果
- focus 切换回调
- seek / timer / player state 回调

### Goal D: loading 可见性由真实播放状态驱动

详情页和全屏页都要把 loading 分成两件事：

- “是否正在等待画面恢复”：本地 UI 状态或控制器 `isLoading`
- “是否已经有可见播放信号”：真实进度、播放恢复或 ready 后的控制器状态

loading overlay 的显示只看前者，清理看后者。不能把“未收到真实进度”同时当成“不要显示 loading”，否则黑底阶段会无反馈。

## Proposed Changes

### 1. 引入“退出中”守卫

在 `TvFullscreenPlayerScreen` 增加类似状态：

```dart
bool _isExitingFullscreen = false;
bool _hasScheduledExitSave = false;
```

用途：

- 避免重复触发退出
- 避免多条退出路径重复触发重保存
- 让异步回调在退出开始后尽量早停

### 2. 改造 `_handleExitWithSave()` 为“先退后存”

从：

```dart
await _saveProgress(...)
exitRequested() / maybePop()
```

改为：

```dart
if (_beginExit()) {
  _performVisibleExit();
  unawaited(_saveProgress(...));
}
```

关键点：

- 可见退出动作不能再等保存
- 保存改为后台异步收尾
- 如果退出已开始，后续重复按键直接忽略

### 3. 统一退出收尾职责

建议职责拆分：

- `_handleExitWithSave()`
  - 负责用户主动退出
  - 负责触发一次“主保存”
- `_handlePopInvoked(didPop: true)`
  - 只做系统 pop 兜底，不再重复触发同级别重保存
- `dispose()`
  - 只在“还没做过退出收尾”的情况下补一层最后兜底

也就是说：

- 主动返回路径优先负责保存
- `dispose` 不再默认无脑再来一遍

### 4. 退出后收紧异步回写

在这些入口加守卫：

- `_onVideoProgressUpdate`
- 可能的 timer callback
- 焦点恢复前后的异步 post-frame callback

原则：

- 如果 `_isExitingFullscreen == true`，就不再继续发起新的保存、刷新或 UI 状态回写

### 5. 保持共享 overlay 焦点恢复语义不变

详情页的 `_closeFullscreenOverlay` 和已有焦点恢复逻辑不改语义，只减少它等待全屏页收尾的时间。

也就是说：

- 行为仍然是“返回详情页并恢复顶部播放器焦点”
- 只是全屏页不要再阻塞这个动作

### 6. 恢复详情页 preview loading overlay

详情页小播放器继续关闭 `VideoPlayerWidget.showLoadingIndicator`，避免内部播放器控件抢焦点或和 TV 壳层重复。

在详情页播放器外层 `Stack` 增加 TV 专属 overlay：

- `_shouldShowPreviewLoadingOverlay`
  - `_previewPlayerLoading == true`
  - 或 `_playerController?.isLoading == true`
  - 且未展示全屏 overlay
- overlay 内显示 `CircularProgressIndicator` 与播放器控制器上报的真实网速；未知或暂无样本时才回退 `0KB/s`
- overlay 不设置背景色，使用 `IgnorePointer`，不影响遥控器焦点和按键

清理只允许通过真实播放进度完成：记录本轮 loading 开始时的播放锚点，只有 `currentPosition` 从该锚点向前推进时才调用 `_finishPreviewPlayerLoading()`；`ready`、`play`、`isPlaying` 或 `isLoading=false` 都只能刷新 UI，不能单独撤掉转圈。

### 7. 给全屏 seek loading 增加兜底收敛

全屏长按 seek 松手后：

- 保留 `_markFullscreenPlayerLoading()`，让用户看到 seek 后正在恢复
- `_markFullscreenPlayerLoading()` 记录 seek 目标或本轮加载起点作为锚点
- 只有真实播放器进度从该锚点继续向前推进，才允许结束 `_fullscreenPlayerLoading`
- 复用详情页播放器时，全屏壳必须监听 provider 暴露的 `VideoPlayerWidgetController` 进度事件，避免没有本地 controller 时缺少清理信号
- `ready`、`play`、`isPlaying` 或 `isLoading=false` 只刷新 UI，不作为清理信号

这样既不会在 seek 后立刻闪掉转圈，也不会因为复用播放器缺少全屏页进度监听而永久残留。

## File Plan

重点文件：

- `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- `lib/tv_app/screens/tv_video_detail_screen.dart`

测试：

- `test/tv_app/tv_video_detail_screen_test.dart`
- `test/tv_app/tv_fullscreen_player_screen_test.dart`

## Compatibility / Risk

### 风险 1: 异步保存改后退回详情页太快，进度没记上

这是本任务最大 trade-off。

控制策略：

- 仍保留后台强制保存
- `dispose` 保留“未收尾时才补兜底”的最后保护

### 风险 2: 退出守卫过多，导致系统返回路径丢保存

控制策略：

- 明确区分“主保存已调度”与“兜底保存是否还需要”
- 用测试覆盖单轮退出只触发一次主收尾

### 风险 3: 共享播放器复用路径被误伤

控制策略：

- 不改变 `reuseExistingPlayer` 的语义
- 不在退出时 dispose 复用播放器
- 保留现有 overlay 退出与焦点恢复测试

## Rollback Shape

如果“先退后存”导致进度丢失明显：

1. 保留退出守卫与重复收尾压缩
2. 只回退“完全异步保存”的部分，改成更轻量的同步快照 + 后台完整保存

也就是说，本任务第一优先级是“不卡住、不闪退”；第二优先级才是把保存时机打磨到最优。
