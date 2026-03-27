# Mobile Fullscreen Rotation Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iOS and Android mobile/tablet fullscreen playback stay landscape-only, allow left/right landscape switching when supported, and preserve all existing fullscreen-exit behavior.

**Architecture:** Extract the fullscreen orientation rules into a pure Dart policy, add a small Android-only MethodChannel wrapper for system auto-rotation and current interface orientation, then put the async retry/de-dup logic into a shared coordinator that both player screens call after fullscreen entry stabilizes. Keep the existing screen-specific exit paths intact so the new logic only affects the in-fullscreen decision window.

**Tech Stack:** Flutter, Dart, Kotlin, `MethodChannel`, `flutter_test`

---

## File Map

- Create: `lib/utils/fullscreen_orientation_policy.dart`
  Pure decision logic for fullscreen orientation outcomes.
- Create: `lib/services/mobile_orientation_service.dart`
  Android-only MethodChannel wrapper for `getSystemAutoRotateEnabled()` and `getCurrentInterfaceOrientation()`.
- Create: `lib/services/fullscreen_orientation_controller.dart`
  Shared async coordinator that retries bounded Android side detection, normalizes orientation sets, and returns the next target set or `null`.
- Create: `test/utils/fullscreen_orientation_policy_test.dart`
  Unit tests for the pure fullscreen rule matrix.
- Create: `test/services/mobile_orientation_service_test.dart`
  Unit tests for MethodChannel mapping and safe failure behavior.
- Create: `test/services/fullscreen_orientation_controller_test.dart`
  Unit tests for bounded retry, Android lock-side behavior, and orientation-set de-duplication.
- Modify: `lib/screens/player_screen.dart`
  Use the shared controller after fullscreen entry stabilizes; keep current exit logic unchanged.
- Modify: `lib/screens/live_player_screen.dart`
  Add the same stabilization guard and shared controller wiring for live playback.
- Modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`
  Expose the Android orientation channel and map device rotation into Flutter-facing orientation labels.

## Implementation Notes

- Keep channel naming consistent with the existing codebase and use one constant in Dart/Kotlin for the orientation channel.
- Preserve `player_screen.dart` short-drama portrait fullscreen behavior by bypassing the new controller when `_isShortDrama` is true.
- In `live_player_screen.dart`, hardcode the controller input `isShortDramaPortraitFlow: false`.
- De-duplicate `SystemChrome.setPreferredOrientations` calls by comparing normalized sets, not list identity.
- Android bridge fallback rules:
  - `getSystemAutoRotateEnabled()` returns `true`, `false`, or `null`
  - `null` means “leave the current fullscreen landscape request unchanged”
- Android “current interface orientation” must map to Flutter `DeviceOrientation` semantics and account for devices whose natural orientation is landscape.

### Task 1: Lock the fullscreen rule matrix in pure Dart tests

**Files:**
- Create: `lib/utils/fullscreen_orientation_policy.dart`
- Create: `test/utils/fullscreen_orientation_policy_test.dart`
- Test: `test/utils/fullscreen_orientation_policy_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('returns both landscape orientations for iOS fullscreen', () {
  final decision = FullscreenOrientationPolicy.resolve(
    isFullscreen: true,
    isEnteringFullscreen: false,
    isShortDramaPortraitFlow: false,
    platform: TargetPlatform.iOS,
    observedInterfaceOrientation: MobileInterfaceOrientation.landscapeLeft,
    lastConfirmedLandscapeOrientation: null,
    androidAutoRotateEnabled: null,
  );

  expect(
    decision.preferredOrientations,
    const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
  );
});

test('locks Android fullscreen to the confirmed side when auto-rotate is off',
    () {
  final decision = FullscreenOrientationPolicy.resolve(
    isFullscreen: true,
    isEnteringFullscreen: false,
    isShortDramaPortraitFlow: false,
    platform: TargetPlatform.android,
    observedInterfaceOrientation: MobileInterfaceOrientation.landscapeRight,
    lastConfirmedLandscapeOrientation: null,
    androidAutoRotateEnabled: false,
  );

  expect(
    decision.preferredOrientations,
    const [DeviceOrientation.landscapeRight],
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/fullscreen_orientation_policy_test.dart`
Expected: FAIL because `FullscreenOrientationPolicy` and `MobileInterfaceOrientation` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
enum MobileInterfaceOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
  unknown,
}

class FullscreenOrientationDecision {
  const FullscreenOrientationDecision(this.preferredOrientations);

  final List<DeviceOrientation>? preferredOrientations;
}

class FullscreenOrientationPolicy {
  static FullscreenOrientationDecision resolve({
    required bool isFullscreen,
    required bool isEnteringFullscreen,
    required bool isShortDramaPortraitFlow,
    required TargetPlatform platform,
    required MobileInterfaceOrientation observedInterfaceOrientation,
    required MobileInterfaceOrientation? lastConfirmedLandscapeOrientation,
    required bool? androidAutoRotateEnabled,
  }) {
    if (!isFullscreen || isEnteringFullscreen || isShortDramaPortraitFlow) {
      return const FullscreenOrientationDecision(null);
    }

    if (platform == TargetPlatform.iOS) {
      return const FullscreenOrientationDecision([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (platform == TargetPlatform.android && androidAutoRotateEnabled == true) {
      return const FullscreenOrientationDecision([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    final lockedSide = switch (observedInterfaceOrientation) {
      MobileInterfaceOrientation.landscapeLeft => DeviceOrientation.landscapeLeft,
      MobileInterfaceOrientation.landscapeRight =>
        DeviceOrientation.landscapeRight,
      _ => switch (lastConfirmedLandscapeOrientation) {
          MobileInterfaceOrientation.landscapeLeft =>
            DeviceOrientation.landscapeLeft,
          MobileInterfaceOrientation.landscapeRight =>
            DeviceOrientation.landscapeRight,
          _ => null,
        },
    };

    return FullscreenOrientationDecision(
      lockedSide == null ? null : [lockedSide],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/fullscreen_orientation_policy_test.dart`
Expected: PASS with coverage for iOS dual-landscape, Android auto-rotate on/off, short-drama bypass, and `no-op` cases.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/fullscreen_orientation_policy.dart test/utils/fullscreen_orientation_policy_test.dart
git commit -m "test: add fullscreen orientation policy"
```

### Task 2: Add the Android orientation bridge and safe Dart wrapper

**Files:**
- Create: `lib/services/mobile_orientation_service.dart`
- Create: `test/services/mobile_orientation_service_test.dart`
- Modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`
- Test: `test/services/mobile_orientation_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('returns null when Android auto-rotate cannot be read', () async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('selene/orientation');

  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    throw PlatformException(code: 'unavailable');
  });

  expect(
    await const MobileOrientationService().getSystemAutoRotateEnabled(),
    isNull,
  );
});

test('maps channel orientation strings into enum values', () async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('selene/orientation');

  debugDefaultTargetPlatformOverride = TargetPlatform.android;

  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getCurrentInterfaceOrientation') {
      return 'landscapeLeft';
    }
    return null;
  });

  expect(
    await const MobileOrientationService().getCurrentInterfaceOrientation(),
    MobileInterfaceOrientation.landscapeLeft,
  );
});
```

Import `package:flutter/foundation.dart` in this test file so `debugDefaultTargetPlatformOverride` and `defaultTargetPlatform` are available.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/mobile_orientation_service_test.dart`
Expected: FAIL because `MobileOrientationService` and the orientation channel do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
abstract class MobileOrientationServiceProtocol {
  Future<bool?> getSystemAutoRotateEnabled();
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation();
}

class MobileOrientationService implements MobileOrientationServiceProtocol {
  const MobileOrientationService();

  static const MethodChannel _channel =
      MethodChannel('selene/orientation');

  @override
  Future<bool?> getSystemAutoRotateEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<bool>('getSystemAutoRotateEnabled');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MobileInterfaceOrientation> getCurrentInterfaceOrientation() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return MobileInterfaceOrientation.unknown;
    }
    try {
      final raw = await _channel.invokeMethod<String>(
        'getCurrentInterfaceOrientation',
      );
      return MobileInterfaceOrientation.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => MobileInterfaceOrientation.unknown,
      );
    } catch (_) {
      return MobileInterfaceOrientation.unknown;
    }
  }
}
```

```kotlin
private val orientationChannelName = "selene/orientation"

MethodChannel(flutterEngine.dartExecutor.binaryMessenger, orientationChannelName)
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "getSystemAutoRotateEnabled" -> {
                val value = runCatching {
                    Settings.System.getInt(
                        contentResolver,
                        Settings.System.ACCELEROMETER_ROTATION,
                    ) == 1
                }.getOrNull()
                result.success(value)
            }
            "getCurrentInterfaceOrientation" -> {
                result.success(resolveCurrentInterfaceOrientation())
            }
            else -> result.notImplemented()
        }
    }
```

Implement `resolveCurrentInterfaceOrientation()` so it:

- derives whether the device is portrait-natural or landscape-natural
- maps the current `display.rotation` into Flutter-facing labels
- returns `unknown` if it cannot determine a valid orientation
- registers the new `selene/orientation` channel inside `MainActivity.configureFlutterEngine(...)` next to the existing background/PiP/sleep-timer channels

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/mobile_orientation_service_test.dart`
Expected: PASS with the Dart wrapper swallowing platform failures and mapping raw strings correctly.

- [ ] **Step 5: Commit**

```bash
git add lib/services/mobile_orientation_service.dart test/services/mobile_orientation_service_test.dart android/app/src/main/kotlin/com/example/selene/MainActivity.kt
git commit -m "feat: add mobile orientation bridge"
```

### Task 3: Add the shared fullscreen orientation controller

**Files:**
- Create: `lib/services/fullscreen_orientation_controller.dart`
- Create: `test/services/fullscreen_orientation_controller_test.dart`
- Modify: `lib/utils/fullscreen_orientation_policy.dart`
- Test: `test/services/fullscreen_orientation_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('retries Android side detection until a landscape side is confirmed',
    () async {
  final service = _FakeMobileOrientationService(
    autoRotateEnabled: false,
    orientationReads: [
      MobileInterfaceOrientation.unknown,
      MobileInterfaceOrientation.landscapeRight,
    ],
  );

  final controller = FullscreenOrientationController(
    orientationService: service,
    retryDelay: Duration.zero,
    retryTimeout: const Duration(milliseconds: 1),
  );

  final target = await controller.resolveAfterFullscreenEntry(
    platform: TargetPlatform.android,
    isShortDramaPortraitFlow: false,
    lastAppliedOrientations: null,
  );

  expect(target, const [DeviceOrientation.landscapeRight]);
  expect(service.readCount, 2);
});

test('skips duplicate orientation sets', () async {
  final controller = FullscreenOrientationController(
    orientationService: _FakeMobileOrientationService(autoRotateEnabled: true),
    retryDelay: Duration.zero,
    retryTimeout: const Duration(milliseconds: 1),
  );

  final target = await controller.resolveAfterFullscreenEntry(
    platform: TargetPlatform.android,
    isShortDramaPortraitFlow: false,
    lastAppliedOrientations: const [
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ],
  );

  expect(target, isNull);
});
```

Define `_FakeMobileOrientationService` in this test file and make it implement `MobileOrientationServiceProtocol` so the failing state is caused by the missing controller behavior, not missing test scaffolding.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/fullscreen_orientation_controller_test.dart`
Expected: FAIL because `FullscreenOrientationController` and its retry/de-dup behavior do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class FullscreenOrientationController {
  FullscreenOrientationController({
    required this.orientationService,
    this.retryDelay = const Duration(milliseconds: 50),
    this.retryTimeout = const Duration(milliseconds: 500),
  });

  final MobileOrientationServiceProtocol orientationService;
  final Duration retryDelay;
  final Duration retryTimeout;

  Future<List<DeviceOrientation>?> resolveAfterFullscreenEntry({
    required TargetPlatform platform,
    required bool isShortDramaPortraitFlow,
    required List<DeviceOrientation>? lastAppliedOrientations,
  }) async {
    final autoRotateEnabled = platform == TargetPlatform.android
        ? await orientationService.getSystemAutoRotateEnabled()
        : null;

    final observed = platform == TargetPlatform.android &&
            autoRotateEnabled == false
        ? await _readBoundedLandscapeOrientation()
        : MobileInterfaceOrientation.unknown;

    final decision = FullscreenOrientationPolicy.resolve(
      isFullscreen: true,
      isEnteringFullscreen: false,
      isShortDramaPortraitFlow: isShortDramaPortraitFlow,
      platform: platform,
      observedInterfaceOrientation: observed,
      lastConfirmedLandscapeOrientation:
          observed.isLandscape ? observed : null,
      androidAutoRotateEnabled: autoRotateEnabled,
    );

    return _sameSet(
      decision.preferredOrientations,
      lastAppliedOrientations,
    )
        ? null
        : decision.preferredOrientations;
  }
}
```

Define the following support pieces in the same step so the tests compile cleanly:

- `MobileOrientationServiceProtocol` in `lib/services/mobile_orientation_service.dart`
- service platform gating based on `defaultTargetPlatform`, with tests overriding `debugDefaultTargetPlatformOverride`
- `bool get isLandscape` on `MobileInterfaceOrientation`
- `_readBoundedLandscapeOrientation()` with this contract:
  - only runs when `platform == TargetPlatform.android && autoRotateEnabled == false`
  - polls `getCurrentInterfaceOrientation()` every `retryDelay`
  - returns the first `landscapeLeft`/`landscapeRight`
  - returns `MobileInterfaceOrientation.unknown` after `retryTimeout`
- `_sameSet()` sorts by enum index before comparing orientation lists

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/fullscreen_orientation_controller_test.dart`
Expected: PASS with coverage for bounded retry, Android auto-rotate on/off, and normalized de-duplication.

- [ ] **Step 5: Commit**

```bash
git add lib/services/fullscreen_orientation_controller.dart lib/utils/fullscreen_orientation_policy.dart test/services/fullscreen_orientation_controller_test.dart
git commit -m "feat: add fullscreen orientation controller"
```

### Task 4: Wire the standard and live players to the shared controller

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/screens/live_player_screen.dart`

- [ ] **Step 1: Write the failing test**

Add one controller regression test that proves Android keeps the current fullscreen landscape request unchanged when auto-rotate state is unavailable, so the player and live-player wiring can treat channel failures as a safe no-op.

```dart
test('returns null when Android auto-rotate state is unavailable', () async {
  final controller = FullscreenOrientationController(
    orientationService: _FakeMobileOrientationService(
      autoRotateEnabled: null,
      orientationReads: [MobileInterfaceOrientation.landscapeLeft],
    ),
    retryDelay: Duration.zero,
    retryTimeout: Duration.zero,
  );

  expect(
    await controller.resolveAfterFullscreenEntry(
      platform: TargetPlatform.android,
      isShortDramaPortraitFlow: false,
      lastAppliedOrientations: null,
    ),
    isNull,
  );
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/fullscreen_orientation_controller_test.dart`
Expected: FAIL until the controller explicitly treats `androidAutoRotateEnabled == null` as a safe no-op.

- [ ] **Step 3: Write minimal implementation**

In `player_screen.dart`:

```dart
final targetOrientations =
    await _fullscreenOrientationController.resolveAfterFullscreenEntry(
  platform: defaultTargetPlatform,
  isShortDramaPortraitFlow: _isShortDrama,
  lastAppliedOrientations: _lastAppliedFullscreenOrientations,
);

if (targetOrientations != null) {
  await SystemChrome.setPreferredOrientations(targetOrientations);
  _lastAppliedFullscreenOrientations = targetOrientations;
}
```

Use this only after `_waitForLandscapeMetrics()` completes and before `_isEnteringLandscapeFullscreen` is cleared.

Initialize the controller once in each screen state:

```dart
late final FullscreenOrientationController _fullscreenOrientationController =
    FullscreenOrientationController(
  orientationService: const MobileOrientationService(),
);
```

In `live_player_screen.dart`:

```dart
setState(() => _isEnteringLandscapeFullscreen = true);
await _waitForLandscapeMetrics();

final targetOrientations =
    await _fullscreenOrientationController.resolveAfterFullscreenEntry(
  platform: defaultTargetPlatform,
  isShortDramaPortraitFlow: false,
  lastAppliedOrientations: _lastAppliedFullscreenOrientations,
);
```

Also:

- add `_isEnteringLandscapeFullscreen`
- add the same 850ms `_waitForLandscapeMetrics()` helper used by the standard player
- reset `_lastAppliedFullscreenOrientations` when exiting fullscreen
- do not touch either screen’s existing fullscreen-exit orientation restore branch

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/fullscreen_orientation_controller_test.dart`
Expected: PASS, with the screens compiling against the shared controller and keeping their exit codepaths unchanged.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/player_screen.dart lib/screens/live_player_screen.dart test/services/fullscreen_orientation_controller_test.dart
git commit -m "feat: share fullscreen orientation handling"
```

### Task 5: Format and verify

**Files:**
- Modify: `lib/utils/fullscreen_orientation_policy.dart`
- Modify: `lib/services/mobile_orientation_service.dart`
- Modify: `lib/services/fullscreen_orientation_controller.dart`
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/screens/live_player_screen.dart`
- Modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`
- Modify: `test/utils/fullscreen_orientation_policy_test.dart`
- Modify: `test/services/mobile_orientation_service_test.dart`
- Modify: `test/services/fullscreen_orientation_controller_test.dart`

- [ ] **Step 1: Format touched Dart files**

Run: `dart format lib/utils/fullscreen_orientation_policy.dart lib/services/mobile_orientation_service.dart lib/services/fullscreen_orientation_controller.dart lib/screens/player_screen.dart lib/screens/live_player_screen.dart test/utils/fullscreen_orientation_policy_test.dart test/services/mobile_orientation_service_test.dart test/services/fullscreen_orientation_controller_test.dart`
Expected: files formatted with no errors

- [ ] **Step 2: Run targeted tests**

Run: `flutter test test/utils/fullscreen_orientation_policy_test.dart test/services/mobile_orientation_service_test.dart test/services/fullscreen_orientation_controller_test.dart`
Expected: PASS

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: exit 0, or only pre-existing unrelated issues that are documented before completion

- [ ] **Step 4: Manual device verification**

Verify on real devices or emulators:

- Android phone:
  - auto-rotate on -> fullscreen allows left/right landscape switching
  - auto-rotate off -> fullscreen stays locked to the confirmed landscape side
  - vertical device posture while fullscreen never returns to portrait
- Android tablet:
  - repeat the same two auto-rotate states
  - confirm natural-landscape devices do not invert left/right locking
  - confirm clockwise/counter-clockwise rotation still maps to the expected Flutter landscape side
- iPhone / iPad:
  - fullscreen allows only landscape orientations
  - exiting fullscreen still follows today’s phone/tablet behavior
- iPhone with rotation unlocked:
  - rotate between left and right landscape while staying fullscreen
  - hold the phone vertically and confirm fullscreen does not rotate back to portrait
- Standard player and live player:
  - PiP behavior still works
  - exiting fullscreen still resets orientation preferences correctly

- [ ] **Step 5: Commit**

```bash
git add lib/utils/fullscreen_orientation_policy.dart lib/services/mobile_orientation_service.dart lib/services/fullscreen_orientation_controller.dart lib/screens/player_screen.dart lib/screens/live_player_screen.dart android/app/src/main/kotlin/com/example/selene/MainActivity.kt test/utils/fullscreen_orientation_policy_test.dart test/services/mobile_orientation_service_test.dart test/services/fullscreen_orientation_controller_test.dart
git commit -m "feat: update mobile fullscreen rotation handling"
```
