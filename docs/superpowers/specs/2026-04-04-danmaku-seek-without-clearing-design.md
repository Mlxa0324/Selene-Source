# 弹幕 Seek 保持连续滚动设计

## 背景

当前播放器在拖动进度条 seek 时，会有明显的“弹幕清屏”感。根因在 `player_screen.dart` 的 seek 弹幕同步链路：

- `_handlePlayerSeek(position)` 会调用 `_resetDanmakuIndex(position)`
- `_resetDanmakuIndex(position)` 在重算 `_danmakuIndex` 后，会直接执行 `DanmakuController.clear()`
- seek 完成后，再通过 `_sendDanmakuByPosition(position)` 补发目标时间点弹幕

这会让用户在拖动进度条时明显感受到弹幕先被清掉，再重新出现。

## 目标

- 所有端统一支持：拖动进度条 seek 时，弹幕不清屏
- 到达目标时间点后，新弹幕直接平滑接上
- 保留当前屏幕上已经存在的弹幕，让它们自然滚出屏幕
- 不影响暂停恢复不清屏的现有修复

## 非目标

- 不修改切集、换源、切换弹幕集时的清屏逻辑
- 不修改弹幕首次加载或弹幕重新启用时的清屏逻辑
- 不改第三方弹幕库行为
- 不引入“前拖/后拖不同策略”

## 方案对比

### 方案 A：seek 时只重算索引，不清屏

把当前 `_resetDanmakuIndex(position)` 拆成两个动作：

- 重算 `_danmakuIndex`
- 是否清空当前屏幕弹幕

拖动进度条 seek 时只重算索引，不调用 `clear()`。

优点：

- 最符合用户诉求，seek 过程不会出现明显清屏感
- 改动范围集中在 `player_screen.dart`
- 可继续保留其它需要清屏的路径

缺点：

- 往前/往后拖动时，旧时间点弹幕会短暂保留，直到自然飞出屏幕

### 方案 B：只对“拖动进度条”单独保留弹幕

沿着控件链把“这是手动拖动 seek”的信号一路传到 `player_screen.dart`，只对这一类 seek 关闭 clear。

优点：

- 控制更细

缺点：

- 需要修改控件链路，文件分布更散
- 当前用户目标只是“拖动进度条不清屏”，但现有 seek 基本就是这条路径，没必要先扩复杂度

### 方案 C：所有 seek 都不 clear

优点：

- 代码最省

缺点：

- 容易误伤非进度条 seek 场景
- 切源后的内部跳转、恢复位置等动作也可能被带入，不够安全

## 推荐方案

采用方案 A。

把“重算索引”和“清屏”拆开，让 seek 链路只做索引重算，不做清屏。这样旧弹幕会自然滚出，新时间点弹幕平滑接入，最贴近目标体验。

## 详细设计

### 1. 拆分 `_resetDanmakuIndex(...)` 的职责

当前 `_resetDanmakuIndex(Duration position)` 做了两件事：

- 通过 `findDanmakuSeekIndex(...)` 重算 `_danmakuIndex`
- 调用 `controller.clear()`

需要把它拆成更明确的行为：

- 一个只负责按目标时间重算 `_danmakuIndex`
- 一个包装方法根据场景决定是否清屏

这样“seek 时不清屏”和“切集时需要清屏”才能被清楚地区分。

### 2. seek 链改为“重算索引但不 clear”

修改 `_handlePlayerSeek(Duration position)` 的异步收尾逻辑：

- 保留 seek 开始时的 `_isSeeking = true`
- 保留 `_lastDanmakuCheckTime = -1`
- 保留根据目标位置重算 `_danmakuIndex`
- 删除 seek 路径上的 `controller.clear()`

seek 完成后继续保留现有：

- `_syncDanmakuPlaybackState(reason: 'player_on_seek_async')`
- `_sendDanmakuByPosition(position)`

这样拖动后能直接从目标位置补发新弹幕，同时不把当前屏幕上旧弹幕清掉。

### 3. 保持需要 clear 的路径不变

以下场景继续保留 clear：

- 切集
- 换源
- 弹幕首次加载
- 弹幕从关闭切到开启
- 手动匹配切换到新的弹幕集

这些路径本质上都属于“内容集变化”，继续清屏是合理的。

### 4. 暂停恢复修复保持不变

本次 seek 改动不能回归上一轮刚完成的行为：

- 暂停后恢复播放时，不清屏
- seek 时，也不清屏

也就是说：

- 暂停恢复：保留现有屏幕弹幕并继续滚
- seek：保留现有屏幕弹幕并让新目标时间点弹幕继续接入

## 风险

- 往前或往后拖很多时，旧时间点弹幕会短暂留在屏幕上，直到自然飞出
- 这是本次设计有意接受的视觉取舍，因为目标就是“不断、不清屏、平滑接上”

## 测试策略

### 回归测试

至少增加/更新以下测试：

- seek 时重算索引但不清屏
- 切集 / 换源 / 弹幕重新启用时仍然清屏
- 暂停恢复不清屏的现有测试继续通过

### 手动验证

至少验证以下场景：

1. 播放中等待屏幕上有多条弹幕
2. 拖动进度条到新位置
3. 确认旧弹幕没有瞬间清空，而是继续自然滚出
4. 确认目标时间点的新弹幕直接接上
5. 切集后确认仍不会残留上一集弹幕

## 实施范围

- 修改：`lib/screens/player_screen.dart`
- 更新/新增测试：`test/screens/` 下与弹幕 seek 行为对应的回归测试

不修改：

- `lib/widgets/video_player_widget.dart`
- `lib/widgets/player_adapter.dart`
- `lib/services/danmaku_service.dart`
- 第三方弹幕库
