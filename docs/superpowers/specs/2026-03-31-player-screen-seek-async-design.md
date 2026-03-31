# 正式播放器 WebView Seek 异步收尾优化设计

**日期：** 2026-03-31

## 目标

把正式播放页 `PlayerScreen` 的 WebView seek 体感尽量拉近 benchmark 页。

当前 benchmark 页的 WebView seek 在同一条 `m3u8` 上可稳定做到约 2 秒内完成，而正式页通常需要 3 秒多。目标是尽量把正式页 seek 的关键路径缩短，让真正的 `fastSeekTo/currentTime` 尽早发出，把弹幕和其他联动改成异步收尾。

## 根因判断

当前正式页 seek 链路与 benchmark 的关键差异：

1. benchmark 页手动 seek 直接调用 benchmark driver 的 `seek()`。
2. 正式页在真正发起播放器 seek 之前，会先触发 `onSeek -> PlayerScreen._handlePlayerSeek()`。
3. `_handlePlayerSeek()` 里会同步重置弹幕索引并清空弹幕控制器。

这意味着正式页把一部分业务收尾工作塞进了 seek 的临界路径，而 benchmark 没有这层额外同步成本。

## 设计原则

- 优先让播放器 seek 命令尽早发出。
- 弹幕跟随仍然保留，但改成异步收尾。
- 非 seek 本身必须立即完成的工作，一律不阻塞 seek。
- 尽量不改正式播放器其他业务逻辑。

## 方案

### 1. 把正式页 seek 通知从“seek 前同步”改成“seek 后异步”

正式页当前通过 `seekPlayerAndNotify(... notifyBeforeSeek: true)` 让 `PlayerScreen` 在 seek 前收到 `onSeek`。

优化后：

- `VideoPlayerWidget` 发起底层 seek 后，再用 `unawaited` 异步通知父层 `onSeek`
- 父层 `PlayerScreen` 不再处于底层 seek 的前置步骤

这样可以保证 WebView 的 `fastSeekTo/currentTime` 更早执行。

### 2. 让弹幕 seek 跟随进一步异步化

`_handlePlayerSeek()` 保留，但只做轻量标记：

- 更新 seek serial
- 标记 `_isSeeking`
- 记录目标位置

真正较重的工作改到异步阶段执行：

- 重置弹幕索引
- 清空弹幕控制器
- 根据当前位置补发弹幕
- 恢复弹幕播放状态

### 3. 把弹幕索引重置改成二分查找

当前 `_resetDanmakuIndex()` 是线性扫描整份弹幕列表。

优化后改成二分查找，直接定位第一个 `time > targetTime` 的索引，避免 seek 时随着弹幕量变大而增加同步成本。

## 非目标

- 不改 benchmark 页测量逻辑
- 不把 `fvp` 接进正式播放器链路
- 不重构正式页弹幕整体架构
- 不在这次工作里改 seek 遮罩视觉策略，除非验证后确认它仍是主要瓶颈

## 验证

- 现有 seek 相关测试保持通过
- 新增测试覆盖：
  - seek 命令先发出，父层 `onSeek` 后异步触发
  - 弹幕索引重置逻辑使用新的二分查找结果
- 在真机上对同一条 `m3u8` 对比 benchmark 页与正式页的左向 seek 体感

## 风险

- 正式页有弹幕、控制层和更多状态联动，即使把同步收尾移开，也未必能完全追平 benchmark
- 如果某些依赖 `_isSeeking` 的逻辑默认假设它在 seek 前就置位，需要通过测试确认不会回归
- 真机上的 buffering 遮罩仍可能影响“体感时间”，即便实际 seek 更早完成
