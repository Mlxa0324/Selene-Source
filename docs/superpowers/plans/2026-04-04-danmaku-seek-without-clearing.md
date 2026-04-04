# Danmaku Seek Without Clearing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让拖动进度条 seek 时保留当前屏幕上的弹幕，不清屏，并让目标位置的新弹幕平滑接上。

**Architecture:** 改动集中在 `player_screen.dart` 的弹幕 seek 收尾链路。把“重算弹幕索引”和“清屏”拆成两个可区分的动作，让 seek 只重算索引不清屏，同时保留切集、换源、重新启用弹幕这些内容切换场景的 clear 行为。

**Tech Stack:** Flutter, Dart, `player_screen.dart`, Flutter test

---

## File Map

- Modify: `lib/screens/player_screen.dart`
  - 拆分弹幕索引重置与清屏职责，修改 seek 收尾链路只重算索引不 clear。
- Modify or Create: `test/screens/player_screen_danmaku_seek_test.dart`
  - 在现有 seek 回归测试上补充“seek 不 clear”的行为覆盖。
- Verify: `test/screens/player_screen_danmaku_resume_test.dart`
  - 证明暂停恢复不清屏的现有修复没有回归。
- Optional modify: `AGENTS.md`
  - 记录 seek 弹幕保持连续滚动的变更。

## Task 1: 先锁定 seek 不 clear 的失败测试

**Files:**
- Modify: `test/screens/player_screen_danmaku_seek_test.dart`
- Reference: `lib/screens/player_screen.dart`

- [ ] **Step 1: 写失败测试，锁定 seek 只重算索引不清屏**

在 `test/screens/player_screen_danmaku_seek_test.dart` 中新增一个最小可测入口对应的行为测试。目标不是挂完整播放器，而是验证 `player_screen.dart` 新增的 seek 编排 helper。

至少覆盖：

```dart
test('seek keeps visible danmaku while resetting index cursor', () {
  var resetCalls = 0;
  var clearCalls = 0;

  runDanmakuSeekCallbacks(
    resetIndex: () => resetCalls++,
    clearVisible: () => clearCalls++,
  );

  expect(resetCalls, 1);
  expect(clearCalls, 0);
});
```

helper 名字可以调整，但测试必须证明：

- seek 仍会重算索引
- seek 不再清屏

- [ ] **Step 2: 运行测试确认先失败**

Run: `flutter test test/screens/player_screen_danmaku_seek_test.dart`

Expected: FAIL，提示新 helper 或行为尚未定义。

- [ ] **Step 3: 记录失败测试结果**

在执行说明中明确记录失败原因，确保是“目标行为尚未实现”，不是拼写或导入错误。

## Task 2: 实现 seek 不 clear 的最小改动

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Test: `test/screens/player_screen_danmaku_seek_test.dart`

- [ ] **Step 1: 拆分弹幕索引重置与清屏职责**

在 `lib/screens/player_screen.dart` 中把当前 `_resetDanmakuIndex(Duration position)` 拆成两层：

示例方向：

```dart
void _updateDanmakuIndex(Duration position) {
  if (_danmakuList.isEmpty) return;
  _danmakuIndex = findDanmakuSeekIndex(_danmakuList, position);
}

void _resetDanmakuIndex(
  Duration position, {
  bool clearVisible = true,
}) {
  _updateDanmakuIndex(position);
  if (!clearVisible) return;
  _runWithDanmakuController(
    'clear_reset_index',
    (controller) => controller.clear(),
  );
}
```

名字可以不同，但职责必须拆开。

- [ ] **Step 2: 为 seek 新增最小行为编排 helper**

新增一个 `@visibleForTesting` 的小 helper，让测试能直接验证“reset index 但不 clear”的行为。例如：

```dart
@visibleForTesting
void runDanmakuSeekCallbacks({
  required void Function() resetIndex,
  required void Function() clearVisible,
}) {
  resetIndex();
}
```

注意：

- helper 要和真实运行路径连接
- 不要引入字符串 reason policy
- 不要为了测试把生产逻辑复杂化

- [ ] **Step 3: 修改 `_handlePlayerSeek(...)`，让 seek 只重算索引**

把当前 seek 开始后的这段：

```dart
runDanmakuSeekReset(
  reset: () => _resetDanmakuIndex(position),
);
```

改成走新的 seek 编排 helper，并在内部调用：

```dart
_resetDanmakuIndex(position, clearVisible: false)
```

保留以下行为不变：

- `_isSeeking = true`
- `_lastDanmakuCheckTime = -1`
- `_syncDanmakuPlaybackState(reason: 'player_on_seek_async')`
- `shouldRenderImmediately` 判定
- `_sendDanmakuByPosition(position)`

- [ ] **Step 4: 保持其它 clear 路径不变**

确认以下路径继续用默认 `clearVisible: true`：

- 弹幕首次加载后的索引初始化
- 切集 / 换源相关路径
- 弹幕关闭后重新开启
- 其它明确属于内容切换的路径

不要把这些路径一起改成“不清屏”。

- [ ] **Step 5: 重跑 seek 测试，确认转绿**

Run: `flutter test test/screens/player_screen_danmaku_seek_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交最小实现**

```bash
git add lib/screens/player_screen.dart test/screens/player_screen_danmaku_seek_test.dart
git commit -m "fix: keep danmaku visible during seek"
```

## Task 3: 回归验证与记录

**Files:**
- Modify: `AGENTS.md`
- Verify: `test/screens/player_screen_danmaku_seek_test.dart`
- Verify: `test/screens/player_screen_danmaku_resume_test.dart`
- Verify: `lib/screens/player_screen.dart`

- [ ] **Step 1: 回归暂停恢复测试**

Run: `flutter test test/screens/player_screen_danmaku_resume_test.dart`

Expected: PASS，证明暂停恢复不清屏没有回归。

- [ ] **Step 2: 运行组合测试集**

Run:

```bash
flutter test test/screens/player_screen_danmaku_seek_test.dart test/screens/player_screen_danmaku_resume_test.dart
```

Expected: PASS。

- [ ] **Step 3: 运行静态检查**

Run:

```bash
dart analyze lib/screens/player_screen.dart test/screens/player_screen_danmaku_seek_test.dart test/screens/player_screen_danmaku_resume_test.dart
```

Expected: 没有新增 error；如有 `player_screen.dart` 现存 warning/info，需要在结果说明中单独注明。

- [ ] **Step 4: 补 changelog**

在 `AGENTS.md` 追加一条记录：

- 拖动进度条 seek 时，弹幕改为保留当前屏幕内容并平滑接上
- 切集、换源、弹幕重新启用等内容切换场景仍保留清屏

- [ ] **Step 5: 提交文档收尾**

```bash
git add AGENTS.md
git commit -m "docs: record danmaku seek continuity change"
```

- [ ] **Step 6: 准备手动验证说明**

最终结果中提醒人工验证：

1. 播放中等待几条弹幕挂在屏幕上
2. 拖动进度条到新位置
3. 确认旧弹幕没有瞬间清空，而是自然滚出
4. 确认目标时间点的新弹幕直接接上
5. 切集后确认仍然不会残留上一集弹幕
