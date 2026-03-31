# 正式播放器 WebView Seek 异步收尾优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 缩短正式播放页 `PlayerScreen` 中 WebView seek 的关键路径，让 seek 更接近 benchmark 页速度。

**Architecture:** 先用测试锁定 seek 通知与弹幕索引重置的行为，然后把正式页的 seek 通知从“seek 前同步”调整为“seek 后异步”，并把弹幕索引重置改成二分查找，减少 seek 临界路径内的同步工作。

**Tech Stack:** Flutter, Dart, flutter_test

---

## 文件地图

- 参考：`docs/superpowers/specs/2026-03-31-player-screen-seek-async-design.md`
- 修改：`lib/widgets/video_player_widget.dart`
- 修改：`lib/screens/player_screen.dart`
- 新增：`test/widgets/video_player_widget_seek_notify_test.dart`
- 新增：`test/screens/player_screen_danmaku_seek_test.dart`

## 任务 1：锁定 seek 通知与弹幕索引行为

**Files:**
- Create: `test/widgets/video_player_widget_seek_notify_test.dart`
- Create: `test/screens/player_screen_danmaku_seek_test.dart`

- [ ] **Step 1: 写失败测试，锁定 seek 先发起后通知**

在 `test/widgets/video_player_widget_seek_notify_test.dart` 覆盖：
- `VideoPlayerWidgetController.seekTo()` 调用底层 player seek 后，再异步通知 `onSeek`
- 不再要求 `onSeek` 先于底层 seek 完成

- [ ] **Step 2: 写失败测试，锁定弹幕索引重置结果**

在 `test/screens/player_screen_danmaku_seek_test.dart` 覆盖：
- `_resetDanmakuIndex()` 对有序弹幕列表给出正确索引
- 边界位置（开头、中间、末尾）都正确

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart`
Expected: FAIL，提示 seek 通知时序或弹幕索引辅助接口尚未实现

## 任务 2：实现正式页 seek 异步收尾

**Files:**
- Modify: `lib/widgets/video_player_widget.dart`
- Modify: `lib/screens/player_screen.dart`

- [ ] **Step 1: 调整 VideoPlayerWidget seek 通知时序**

在 `lib/widgets/video_player_widget.dart`：
- 保持底层 `adapter.seek(position)` 为主动作
- 改成 seek 发起后，再异步通知 `widget.onSeek`

- [ ] **Step 2: 让 PlayerScreen 的 seek 跟随收尾保持异步**

在 `lib/screens/player_screen.dart`：
- 保留 `_handlePlayerSeek()` 入口
- 不让其重新进入 seek 主链路阻塞点
- 将弹幕恢复、补发等继续放在异步阶段

- [ ] **Step 3: 把弹幕索引重置改成二分查找**

在 `lib/screens/player_screen.dart`：
- 提取一个可测试的索引查找辅助方法
- `_resetDanmakuIndex()` 使用二分查找代替线性扫描

- [ ] **Step 4: 运行新增测试确认通过**

Run: `flutter test test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart`
Expected: PASS

## 任务 3：回归验证

**Files:**
- Modify: `docs/superpowers/plans/2026-03-31-player-screen-seek-async.md`

- [ ] **Step 1: 运行相关回归测试**

Run: `flutter test test/widgets/mobile_player_controls_seek_test.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart test/screens/player_benchmark_screen_test.dart`
Expected: PASS

- [ ] **Step 2: 运行格式化**

Run: `dart format lib/widgets/video_player_widget.dart lib/screens/player_screen.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart`
Expected: 成功

- [ ] **Step 3: 运行静态分析**

Run: `dart analyze lib/widgets/video_player_widget.dart lib/screens/player_screen.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart`
Expected: 没有新增 error

- [ ] **Step 4: 记录剩余风险**

至少记录：
- 正式页是否仍被 buffering 遮罩影响体感
- 真机上是否已明显逼近 benchmark 页 seek 时间

## 执行记录（2026-03-31）

- `flutter test test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart`
  - 结果：PASS
- `flutter test test/widgets/mobile_player_controls_seek_test.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart test/screens/player_benchmark_screen_test.dart`
  - 结果：PASS
- `dart format lib/widgets/player_adapter.dart lib/widgets/video_player_widget.dart lib/widgets/mobile_player_controls.dart lib/widgets/short_drama_controls.dart lib/screens/player_screen.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart test/widgets/mobile_player_controls_seek_test.dart`
  - 结果：已完成
- `dart analyze lib/widgets/player_adapter.dart lib/widgets/video_player_widget.dart lib/widgets/mobile_player_controls.dart lib/widgets/short_drama_controls.dart lib/screens/player_screen.dart test/widgets/video_player_widget_seek_notify_test.dart test/screens/player_screen_danmaku_seek_test.dart test/widgets/mobile_player_controls_seek_test.dart`
  - 结果：无新增 error；输出主要为项目中既有 warning/info

## 剩余风险

- 正式页的体感时间仍可能被 `VideoPlayerWidget` 的 buffering 遮罩影响，即使 seek 命令本身已经更早发出。
- 这次优化把正式页 seek 相关的父层通知改成异步，若有极少数逻辑隐式依赖“seek 前立即收到 onSeek”，需要靠真机回放再确认没有边角回归。
- benchmark 页与正式页仍然不是完全同一运行环境；即便关键路径收窄，最终体感是否逼近 benchmark 还需要同机同源真机对比确认。
