# 弹幕暂停恢复保持连续滚动设计

## 背景

当前播放器在“暂停后再播放”时，弹幕会出现明显的“清屏再重新出现”的感觉。根因不在播放器内核，而在播放恢复链路：

- `onPlay` 会调用 `player_screen.dart` 中的 `_rebaseDanmakuCursorToCurrentPosition(...)`
- 该函数会继续调用 `_resetDanmakuIndex(...)`
- `_resetDanmakuIndex(...)` 内部会执行 `DanmakuController.clear()`

这条链在 seek、切集、换源时是合理的，但在“只是暂停后继续播放”的场景里会破坏连续性。

## 目标

- 所有端统一支持：暂停后再播放时，屏幕上已有弹幕继续从原位置滚动
- 恢复播放时不做弹幕清屏
- 保持 seek、切集、换源等时间轴变化场景的现有清屏和重定位逻辑
- 不新增暂停保活逻辑；暂停时允许系统按正常策略熄屏

## 非目标

- 不改 `canvas_danmaku` 三方库行为
- 不修改 seek 后的弹幕同步策略
- 不调整全屏切换或 Web 全屏切换时的弹幕重定位行为
- 不引入“长暂停/短暂停”双路径策略

## 方案对比

### 方案 A：暂停恢复只做 `pause()/resume()`，不做 `rebase/clear`

在 `player_screen.dart` 中移除 `onPlay` 里针对弹幕的 `_rebaseDanmakuCursorToCurrentPosition(...)` 调用，只保留 `_syncDanmakuPlaybackState(... forcePlaying: true)`。

优点：

- 最符合用户预期，暂停前屏幕上的弹幕会继续滚动
- 改动范围最小，只影响“暂停恢复播放”场景
- 不会动到 seek、切集、换源这些需要重置索引的路径

缺点：

- 如果后续又有其它“恢复播放”入口复用 `onPlay` 但语义不是普通暂停恢复，需要额外确认是否仍适用

### 方案 B：按暂停时长决定是否清屏

短暂停时只恢复，长暂停时仍执行 rebase。

优点：

- 对极端暂停时长更保守

缺点：

- 增加状态和时长判断逻辑
- 规则不直观，用户难以预测
- 不是当前需求重点

### 方案 C：恢复时 rebase，但不 clear

保留索引重算，但移除 `controller.clear()`。

优点：

- 代码变更局部

缺点：

- 容易造成重复弹幕或叠加
- 语义不清晰，时间轴未变时其实不需要重算索引

## 推荐方案

采用方案 A。

暂停时只暂停弹幕控制器，恢复时只恢复弹幕控制器，不做索引重置，不做清屏。时间轴未改变时，保留现有弹幕位置是最合理的行为。

## 详细设计

### 1. 保持暂停恢复链最小化

修改 `lib/screens/player_screen.dart` 中传给 `VideoPlayerWidget` 的 `onPlay` 回调：

- 删除 `_rebaseDanmakuCursorToCurrentPosition(reason: 'player_on_play', triggerNow: true)`
- 保留 `_syncDanmakuPlaybackState(reason: 'player_on_play', forcePlaying: true)`

`onPause` 保持现有行为：

- 保存进度
- 调用 `_syncDanmakuPlaybackState(reason: 'player_on_pause', forcePlaying: false)`

这样暂停时弹幕暂停，恢复时从原状态继续。

### 2. 明确保留需要清屏的路径

以下路径维持现状，不做修改：

- `seekTo` 相关：`_handlePlayerSeek(...)`
- 切集 / 换源相关：重新加载弹幕和重置索引的链路
- 弹幕从关闭切到开启：按当前位置重建索引
- 全屏切换 / Web 全屏切换：继续保留当前 rebase 行为

这些场景都涉及播放位置或渲染上下文变化，继续清屏重定位是合理的。

### 3. 熄屏行为

本次不新增任何暂停保活逻辑，也不新增“暂停即关闭 wakelock”逻辑。

原因：

- 需求是“暂停时允许熄屏”，不是“暂停时强制立即熄屏”
- 只要不额外维持保活，系统就会按设备策略正常熄屏

如果后续验证发现暂停态仍被其它逻辑强行保活，再单独处理该问题。

## 测试策略

### 单元/Widget 回归

新增针对 `player_screen.dart` 的回归测试，至少覆盖：

- 普通 `onPlay` 恢复播放时，不再触发弹幕 rebase
- `seek` 相关路径仍会触发索引重置 / 清屏逻辑

重点是锁定“暂停恢复”和“seek”这两条路径被区别对待。

### 手动验证

至少验证以下场景：

1. 暂停视频，等待屏幕上存在多条弹幕
2. 点击继续播放，确认现有弹幕继续滚动，没有瞬间清空
3. 执行 seek，确认仍会按目标时间点重建弹幕
4. 切集后确认不会残留上一集弹幕

## 风险

- 某些播放恢复事件如果也走 `onPlay`，但语义并非普通暂停恢复，可能失去之前的 rebase 行为
- 当前先不动全屏切换链路，所以全屏切换后的弹幕表现会保持现状，不在本次修复范围内

## 实施范围

- 修改：`lib/screens/player_screen.dart`
- 新增测试：与 `player_screen.dart` 对应的回归测试文件

不修改：

- `lib/widgets/video_player_widget.dart`
- `lib/widgets/player_adapter.dart`
- `lib/services/danmaku_service.dart`
- 第三方弹幕库
