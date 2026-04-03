# Android PiP WebView Background Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Android 在线播放使用 WebView 时进入 PiP 不再立即切到原生内核，只在 PiP 离开可见阶段超过 1 秒后才切到后台原生播放。

**Architecture:** 保持现有 Android 后台播放 bridge 和前台恢复链路不变，只调整 `VideoPlayerWidget` 的切换时机。为避免把关键状态机埋进超大 widget 文件，这次先新增一个纯 Dart 的 Android PiP WebView handoff helper，把“是否 arm / 是否预切原生 / 是否开始计时 / 是否取消 / 是否执行接管”下沉成可测判定，再由 `VideoPlayerWidget` 负责接线和定时器。

**Tech Stack:** Flutter widget lifecycle, Dart timers, `video_player_widget.dart`, pure Dart policy helpers, Flutter test

---

## File Map

- Create: `lib/utils/android_pip_webview_handoff_policy.dart`
  - 放置 Android PiP WebView 延迟接管的纯判定 helper。
- Create: `test/utils/android_pip_webview_handoff_policy_test.dart`
  - 覆盖 arm、预切原生、开始计时、取消计时、执行接管等关键状态机判定。
- Create: `test/widgets/video_player_widget_android_pip_handoff_test.dart`
  - 锁定 `VideoPlayerWidget` 的接线行为，不依赖真实 PiP 插件。
- Modify: `lib/widgets/video_player_widget.dart`
  - 新增 Android PiP WebView 延迟后台接管状态、定时器和日志。
  - 调整 `_enterPipMode()`、PiP observer、生命周期处理和 dispose 清理，并接入新 helper。
- Verify only: `test/utils/mobile_playback_lifecycle_policy_test.dart`
  - 证明原有普通 Android/iOS 生命周期策略保持不变。
- Optional modify after behavior is verified: `AGENTS.md`
  - 如果项目继续要求同步 changelog，再作为收尾顺手补。

## Task 1: 抽出 Android PiP WebView Handoff 纯判定层

**Files:**
- Create: `lib/utils/android_pip_webview_handoff_policy.dart`
- Test: `test/utils/android_pip_webview_handoff_policy_test.dart`

- [ ] **Step 1: 给新 helper 写失败测试，覆盖关键状态机判定**

新建 `test/utils/android_pip_webview_handoff_policy_test.dart`，至少覆盖：

```dart
test('WebView 在线播放开启息屏播放时进入 PiP 会 arm 延迟接管', () {
  expect(
    AndroidPipWebViewHandoffPolicy.shouldArmForPip(
      isAndroid: true,
      screenOffPlaybackEnabled: true,
      usesWebViewAdapter: true,
      isLocal: false,
      canUseNativeBackgroundPlayback: true,
      backgroundPlaybackActive: false,
      pipNativeTransitioning: false,
    ),
    isTrue,
  );
});

test('PiP 仍可见且生命周期为 resumed 时不启动后台接管计时', () {
  expect(
    AndroidPipWebViewHandoffPolicy.shouldStartBackgroundHandoffTimer(
      state: AppLifecycleState.resumed,
      isAndroid: true,
      isPipMode: true,
      handoffArmed: true,
    ),
    isFalse,
  );
});

test('PiP 离开可见阶段时启动后台接管计时', () {
  expect(
    AndroidPipWebViewHandoffPolicy.shouldStartBackgroundHandoffTimer(
      state: AppLifecycleState.paused,
      isAndroid: true,
      isPipMode: true,
      handoffArmed: true,
    ),
    isTrue,
  );
});

test('PiP 回到 resumed 时取消后台接管', () {
  expect(
    AndroidPipWebViewHandoffPolicy.shouldCancelBackgroundHandoff(
      state: AppLifecycleState.resumed,
      isAndroid: true,
      isPipMode: true,
      handoffArmed: true,
    ),
    isTrue,
  );
});
```

- [ ] **Step 2: 运行新测试，确认先失败**

Run: `flutter test test/utils/android_pip_webview_handoff_policy_test.dart`

Expected: FAIL，提示新文件/新 helper 未定义。

- [ ] **Step 3: 实现最小纯判定 helper**

在 `lib/utils/android_pip_webview_handoff_policy.dart` 增加纯判定方法：

```dart
abstract final class AndroidPipWebViewHandoffPolicy {
  static bool shouldArmForPip({
    required bool isAndroid,
    required bool screenOffPlaybackEnabled,
    required bool usesWebViewAdapter,
    required bool isLocal,
    required bool canUseNativeBackgroundPlayback,
    required bool backgroundPlaybackActive,
    required bool pipNativeTransitioning,
  }) { ... }

  static bool shouldPrepareNativePlaybackForPip({
    required bool isAndroid,
    required bool shouldArmForPip,
  }) { ... }

  static bool shouldStartBackgroundHandoffTimer({
    required AppLifecycleState state,
    required bool isAndroid,
    required bool isPipMode,
    required bool handoffArmed,
  }) { ... }

  static bool shouldCancelBackgroundHandoff({
    required AppLifecycleState state,
    required bool isAndroid,
    required bool isPipMode,
    required bool handoffArmed,
  }) { ... }

  static bool shouldExecuteBackgroundHandoff({
    required bool mounted,
    required bool isPipMode,
    required bool handoffArmed,
    required bool canUseHandoff,
    required AppLifecycleState lastLifecycleState,
  }) { ... }
}
```

保持这些方法纯函数，不读 widget 字段，不做 I/O。

- [ ] **Step 4: 重跑新 helper 测试，确认通过**

Run: `flutter test test/utils/android_pip_webview_handoff_policy_test.dart`

Expected: PASS。

- [ ] **Step 5: 回归现有普通生命周期测试，确认没被影响**

Run: `flutter test test/utils/mobile_playback_lifecycle_policy_test.dart`

Expected: PASS，证明原有 Android/iOS 生命周期策略保持不变。

- [ ] **Step 6: 提交 helper 与测试**

```bash
git add lib/utils/android_pip_webview_handoff_policy.dart test/utils/android_pip_webview_handoff_policy_test.dart
git commit -m "test: cover android pip webview handoff helper"
```

## Task 2: 锁定 VideoPlayerWidget 的接线行为

**Files:**
- Create: `test/widgets/video_player_widget_android_pip_handoff_test.dart`
- Modify: `lib/widgets/video_player_widget.dart`
- Reference: `lib/utils/android_pip_webview_handoff_policy.dart`

- [ ] **Step 1: 写 widget 接线失败测试**

新建 `test/widgets/video_player_widget_android_pip_handoff_test.dart`。不要启动真实 PiP 插件；为 `VideoPlayerWidget` 增加最小可测试入口，只验证接线行为。至少覆盖：

```dart
test('Android WebView PiP 进入时会 arm 延迟接管而不是预切原生', () { ... });
test('PiP visible/resumed 时不会触发后台接管调度', () { ... });
test('PiP stopped 时会取消延迟接管', () { ... });
```

- [ ] **Step 2: 运行这组测试，确认先失败**

Run: `flutter test test/widgets/video_player_widget_android_pip_handoff_test.dart`

Expected: FAIL，提示测试目标尚未接入。

- [ ] **Step 3: 在 widget 中新增状态字段和定时器**

在 `lib/widgets/video_player_widget.dart` 的 Android 播放状态字段附近新增：

```dart
static const Duration _androidPipBackgroundHandoffDelay =
    Duration(seconds: 1);

Timer? _pendingAndroidPipBackgroundHandoffTimer;
bool _androidPipBackgroundHandoffArmed = false;
AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
```

- [ ] **Step 4: 加入最小可测试入口并接入 helper**

在 `video_player_widget.dart` 中新增最小的 `@visibleForTesting` 或等价小 helper，让 widget 测试能直接验证：

- 是否会 arm handoff
- 是否会在 `resumed` 时跳过调度
- 是否会在 PiP stopped 时取消 handoff

同时把 `_enterPipMode()` 中这段：

```dart
if (Platform.isAndroid) {
  await _prepareAndroidNativePlaybackForPip();
}
```

改成基于 `AndroidPipWebViewHandoffPolicy.shouldArmForPip(...)` 的条件化逻辑。

- [ ] **Step 5: 实现 widget 内部调度 helper**

在 `video_player_widget.dart` 新增：

```dart
void _cancelAndroidPipBackgroundHandoff({required String reason}) { ... }
void _scheduleAndroidPipBackgroundHandoff({required String reason}) { ... }
Future<void> _executeAndroidPipBackgroundHandoff({required String reason}) async { ... }
```

要求：

- schedule 时只使用 `_androidPipBackgroundHandoffDelay`
- timer 触发时通过 `AndroidPipWebViewHandoffPolicy.shouldExecuteBackgroundHandoff(...)` 再次检查
- 真正执行时调用现有 `_startAndroidBackgroundPlayback(reason: ...)`
- 执行前取消 timer，避免重复接管

- [ ] **Step 6: 改 `didChangeAppLifecycleState()`，优先处理 PiP WebView 延迟接管**

在现有 Android 生命周期 switch 之前插入：

```dart
_lastLifecycleState = state;

final shouldCancel = AndroidPipWebViewHandoffPolicy.shouldCancelBackgroundHandoff(...);
if (shouldCancel) {
  _cancelAndroidPipBackgroundHandoff(reason: state.name);
}

final shouldSchedule = AndroidPipWebViewHandoffPolicy.shouldStartBackgroundHandoffTimer(...);
if (shouldSchedule) {
  _scheduleAndroidPipBackgroundHandoff(reason: state.name);
  return;
}
```

要求：

- PiP 可见且 `resumed` 时只保持 armed，不触发接管
- 非 PiP 或未 armed 场景继续走现有普通策略

- [ ] **Step 7: 在 PiP observer 和销毁链路里清理状态**

在 `_registerPipObserver()` 的 `pipStateStopped` / `pipStateFailed` 中调用：

```dart
_cancelAndroidPipBackgroundHandoff(reason: 'pip_state_stopped');
```

在 `_disposePlayer()` 或 `dispose()` 中也补：

```dart
_cancelAndroidPipBackgroundHandoff(reason: 'dispose');
```

确保 timer 不泄漏，也不会在控件销毁后继续切后台音频。

- [ ] **Step 8: 跑 widget 接线测试和 analyze**

Run:

```bash
flutter test test/widgets/video_player_widget_android_pip_handoff_test.dart
flutter analyze lib/widgets/video_player_widget.dart lib/utils/android_pip_webview_handoff_policy.dart test/widgets/video_player_widget_android_pip_handoff_test.dart
```

Expected:

- PASS
- `flutter analyze` 无新增 error；若有既有 info，需要在执行总结里单独说明

- [ ] **Step 9: 提交 widget 状态机实现**

```bash
git add lib/widgets/video_player_widget.dart lib/utils/android_pip_webview_handoff_policy.dart test/widgets/video_player_widget_android_pip_handoff_test.dart
git commit -m "feat: delay android pip webview background handoff"
```

## Task 3: 聚焦回归验证与收尾

**Files:**
- Verify: `test/utils/android_pip_webview_handoff_policy_test.dart`
- Verify: `test/utils/mobile_playback_lifecycle_policy_test.dart`
- Verify: `test/widgets/video_player_widget_android_pip_handoff_test.dart`
- Verify: `lib/widgets/video_player_widget.dart`
- Optional modify: `AGENTS.md`

- [ ] **Step 1: 运行最终聚焦验证**

Run:

```bash
flutter test test/utils/android_pip_webview_handoff_policy_test.dart
flutter test test/utils/mobile_playback_lifecycle_policy_test.dart
flutter test test/widgets/video_player_widget_android_pip_handoff_test.dart
flutter analyze lib/widgets/video_player_widget.dart lib/utils/android_pip_webview_handoff_policy.dart test/utils/android_pip_webview_handoff_policy_test.dart test/utils/mobile_playback_lifecycle_policy_test.dart test/widgets/video_player_widget_android_pip_handoff_test.dart
```

Expected:

- PASS
- analyze 没有新增 error

- [ ] **Step 2: 记录真机验证清单**

在最终汇报里明确列出需要用户手动验证的 Android 路径：

```text
1. 开启息屏播放
2. WebView 在线播放进入 PiP
3. PiP 在桌面可见停留 > 1s，不应切后台音频
4. PiP 后锁屏/离开可见阶段 < 1s 返回，不应切后台音频
5. PiP 后锁屏/离开可见阶段 > 1s，应切后台原生播放
6. 回前台后应恢复前台播放器
```

- [ ] **Step 3: 如果项目仍要求同步 changelog，则最后顺手更新 `AGENTS.md`**

如果这轮代码最终确认保留，在 `AGENTS.md` 顶部变更记录中补一条：

- Android WebView 进入 PiP 不再立即切原生
- PiP 离开可见阶段超过 1 秒后才切后台原生播放
- 保留现有前台恢复链路

- [ ] **Step 4: 如果更新了 `AGENTS.md`，再单独提交**

```bash
git add AGENTS.md
git commit -m "docs: note android pip webview handoff"
```
