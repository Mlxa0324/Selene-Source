# Danmaku Resume Without Clearing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让播放器在“暂停后再播放”时保留屏幕上已有弹幕继续滚动，而不是先清屏再重新喷发。

**Architecture:** 改动只放在 `player_screen.dart` 的弹幕播放恢复链路。通过测试先锁定“普通恢复播放不再触发弹幕 rebase，但 seek 仍保留 clear/rebase”，然后做最小实现，最后补回归验证和 changelog。

**Tech Stack:** Flutter, Dart, `player_screen.dart`, Flutter test

---

## File Map

- Modify: `lib/screens/player_screen.dart`
  - 移除“普通恢复播放”时的弹幕 rebase 调用，只保留 pause/resume 同步。
- Create: `test/screens/player_screen_danmaku_resume_test.dart`
  - 锁定暂停恢复不清屏、seek 继续重置弹幕索引的行为。
- Optional modify: `AGENTS.md`
  - 如果实现落地，补一条变更记录，方便后续追踪。

## Task 1: 先锁定暂停恢复与 seek 的行为差异

**Files:**
- Create: `test/screens/player_screen_danmaku_resume_test.dart`
- Reference: `lib/screens/player_screen.dart`

- [ ] **Step 1: 写失败测试，锁定普通恢复播放不再触发弹幕 rebase**

在 `test/screens/player_screen_danmaku_resume_test.dart` 新增一个最小测试入口，目标不是挂整套真实播放器，而是验证 `player_screen.dart` 暴露/新增的最小判定 helper。

至少覆盖：

```dart
test('普通暂停后恢复播放时不需要重置弹幕游标', () {
  expect(
    PlayerScreenDanmakuPolicy.shouldRebaseOnPlay(
      reason: 'player_on_play',
    ),
    isFalse,
  );
});
```

- [ ] **Step 2: 写失败测试，锁定 seek 仍然需要重置弹幕游标**

继续在同一测试文件中增加：

```dart
test('seek 后仍然需要重置弹幕游标', () {
  expect(
    PlayerScreenDanmakuPolicy.shouldClearOnTimelineJump(
      reason: 'player_on_seek_async',
    ),
    isTrue,
  );
});
```

如果最终实现不需要单独的 `shouldClearOnTimelineJump(...)` helper，也可以把测试落到更贴近实际的方法名上；关键是要把“暂停恢复”和“seek”这两类事件区分开。

- [ ] **Step 3: 运行新测试，确认先失败**

Run: `flutter test test/screens/player_screen_danmaku_resume_test.dart`

Expected: FAIL，提示新增 helper/测试目标尚未定义。

- [ ] **Step 4: 提交失败测试对应的最小测试骨架与目标接口设计**

```bash
git add test/screens/player_screen_danmaku_resume_test.dart
git commit -m "test: cover danmaku resume without clearing"
```

如果因为测试和实现需要同一提交更合理，也允许把这一步合并到 Task 2 的提交中，但仍要先看到失败测试。

## Task 2: 最小实现暂停恢复不清屏

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Test: `test/screens/player_screen_danmaku_resume_test.dart`

- [ ] **Step 1: 在 `player_screen.dart` 增加最小可测 helper**

为测试增加一个小而纯的判断入口，例如：

```dart
@visibleForTesting
abstract final class PlayerScreenDanmakuPolicy {
  static bool shouldRebaseOnPlay({required String reason}) {
    return reason != 'player_on_play';
  }
}
```

如果更适合写成 `PlayerScreen.debugShouldRebaseDanmakuOnPlay(...)` 的静态测试入口，也可以；关键是保持判定简单、纯净、可测。

- [ ] **Step 2: 运行测试，确认 helper 测试先转绿**

Run: `flutter test test/screens/player_screen_danmaku_resume_test.dart`

Expected: PASS 或至少第一条“暂停恢复不 rebase”转绿。

- [ ] **Step 3: 修改 `onPlay` 链路，移除恢复播放时的弹幕 rebase**

在 `lib/screens/player_screen.dart` 中这段：

```dart
onPlay: () {
  _rebaseDanmakuCursorToCurrentPosition(
      reason: 'player_on_play', triggerNow: true);
  _syncDanmakuPlaybackState(
      reason: 'player_on_play', forcePlaying: true);
},
```

改成只保留：

```dart
onPlay: () {
  _syncDanmakuPlaybackState(
      reason: 'player_on_play', forcePlaying: true);
},
```

不要改 `onPause`，不要动 seek、切集、换源相关链路。

- [ ] **Step 4: 确认 seek 相关逻辑保持不变**

检查以下路径不做行为修改：

- `_handlePlayerSeek(...)`
- `_resetDanmakuIndex(...)`
- `_rebaseDanmakuCursorToCurrentPosition(...)`

这一步主要是防止误删 `clear()` 或把 seek 和暂停恢复混到一起。

- [ ] **Step 5: 重跑新测试，确认“暂停恢复不清屏”与“seek 仍重置”都通过**

Run: `flutter test test/screens/player_screen_danmaku_resume_test.dart`

Expected: PASS。

- [ ] **Step 6: 运行现有弹幕 seek 回归测试，确认没有回归**

Run: `flutter test test/screens/player_screen_danmaku_seek_test.dart`

Expected: PASS。

- [ ] **Step 7: 提交最小实现**

```bash
git add lib/screens/player_screen.dart test/screens/player_screen_danmaku_resume_test.dart
git commit -m "fix: keep danmaku on pause resume"
```

## Task 3: 验证、记录与收尾

**Files:**
- Modify: `AGENTS.md`
- Verify: `lib/screens/player_screen.dart`
- Verify: `test/screens/player_screen_danmaku_resume_test.dart`
- Verify: `test/screens/player_screen_danmaku_seek_test.dart`

- [ ] **Step 1: 补 changelog**

在 `AGENTS.md` 的变更记录顶部添加一条，说明：

- 暂停后恢复播放时，弹幕改为保留当前屏幕内容继续滚动
- seek、切集、换源等场景继续保留原有清屏重定位

- [ ] **Step 2: 运行目标测试集**

Run:

```bash
flutter test test/screens/player_screen_danmaku_resume_test.dart test/screens/player_screen_danmaku_seek_test.dart
```

Expected: PASS。

- [ ] **Step 3: 运行静态检查**

Run:

```bash
dart analyze lib/screens/player_screen.dart test/screens/player_screen_danmaku_resume_test.dart test/screens/player_screen_danmaku_seek_test.dart
```

Expected: 没有新增 error；如果有项目现存 info/warning，要在结果说明里单独标注。

- [ ] **Step 4: 提交 changelog 与验证收尾**

```bash
git add AGENTS.md
git commit -m "docs: record danmaku resume behavior change"
```

- [ ] **Step 5: 准备手动验证说明**

最终结果中提醒人工验证这 4 步：

1. 暂停视频，观察屏幕上有多条弹幕停住
2. 点击继续播放，确认现有弹幕继续滚动，不瞬间清空
3. 执行 seek，确认弹幕仍按目标时间点重建
4. 切集后确认不会残留上一集弹幕
