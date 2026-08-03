# Flutter Android PIP Controls Implementation Plan

> 用户已授权实现。本计划只覆盖 Flutter Android APK，`re-android`、`kotlin-tv`、iOS 和 pub 缓存保持不变。

## File Map

- Inspect/modify: `lib/widgets/video_player_widget.dart`
- Inspect/modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`
- Inspect/modify: `android/app/src/main/kotlin/com/example/selene/PipActionReceiver.kt`
- Inspect: `/Users/lx/.pub-cache/hosted/pub.dev/pip-0.0.3`（只读）
- Add/modify focused tests under `test/` and Android host test sources only if the existing test setup supports them.

## Step 1: Capture the Flutter Android Baseline

- [x] Confirm the tested APK is built from `android/`, record build variant, device model, Android API and whether the failure happens only in PIP system controls. No Android device is connected in this environment; source, test and Debug APK evidence is recorded instead.
- [x] Record `git status --short` before implementation and preserve unrelated worktree changes.
- [ ] Reproduce with a multi-episode title in a middle episode and at both first/last episode boundaries.
- [ ] Capture the following logcat window while entering PIP and tapping each action:

```bash
adb logcat -c
adb logcat -v time -s PipControls flutter
```

- [ ] Mark the first missing stage: action list absent, Receiver absent, native dispatch absent, Flutter callback absent, or player operation not executed.

## Step 2: Add Focused Regression Coverage First

- [x] Add a pure/testable action-state contract and queue regression coverage.
- [x] Cover previous/next visibility at index `0`, middle index and last index.
- [x] Cover the toggle action contract and state synchronization queue.
- [x] Cover repeated setup/state updates: queued writes preserve order so the latest snapshot is written after an older in-flight operation.
- [x] Review Receiver/Handler mapping for all three native action strings and a missing Handler path; native host compilation covers the changed Kotlin.
- [x] Run the new focused tests before production changes and record the expected compile failure before implementation.

## Step 3: Implement a Single Flutter Android Synchronization Path

- [x] Replace independent PIP setup/action writes with a serialized coordinator for the current widget instance.
- [x] Ensure every `_setupPip()` completion is followed by the current action snapshot, including init, first URL, playing changes and explicit PIP entry/retry; episode changes use the same queue for action-only updates.
- [x] Prevent a stale async operation from writing after a newer episode or playback state snapshot.
- [x] Preserve aspect ratio, auto-enter, source rect, retry and existing PIP state observer behavior.

## Step 4: Harden Native Dispatch Without Moving Business Logic

- [x] Keep `MainActivity` as the Flutter Android host action writer and `PipActionReceiver` as the broadcast adapter.
- [x] Keep native action mapping explicit and idempotent; episode switching and play/pause remain in Flutter.
- [x] Handle channel/Handler absence without throwing and emit stage-specific diagnostic logs.
- [x] Remove the native optimistic playback-state update so Flutter's confirmed adapter state remains authoritative.
- [x] Re-check existing `PendingIntent` flags and request codes on the minimum supported Android versions.

## Step 5: Validate the Flutter Android Scope

- [x] Run focused Dart tests, then:

```bash
flutter analyze lib/widgets/video_player_widget.dart
flutter test test/widgets/video_player_widget_preload_config_test.dart \
  test/widgets/video_player_widget_seek_notify_test.dart
./android/gradlew -p android :app:assembleDebug
git diff --check
```

- [ ] Install the generated Flutter Android APK, repeat the real PIP matrix and retain the stage logs. Blocked by the lack of an Android device/working ADB daemon.
- [x] Verify `git diff --name-only` contains only Flutter/Dart tests, `android/app` host code and task-authorized files. No `re-android`, `kotlin-tv`, iOS or pub-cache changes are allowed.
- [x] Do not modify `re-android`, `kotlin-tv`, iOS code or pub-cache/plugin source.
