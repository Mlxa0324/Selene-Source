# Android Media Session Island Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Android-only screen-off audio playback backed by a native media session so lock-screen controls, media notifications, and vendor island/capsule surfaces can work on supported Android systems.

**Architecture:** Keep Flutter responsible for page UI and episode/source logic, but move eligible Android screen-off playback sessions onto a native-player-backed route that feeds an Android media playback service. The service owns the media session, notification, and background playback lifecycle, while Flutter and Android exchange commands over a method channel.

**Tech Stack:** Flutter, Dart, `media_kit`, Android Kotlin, AndroidX Media3, MethodChannel, widget/unit tests

---

### Task 1: Lock down routing rules with tests

**Files:**
- Modify: `test/config/player_backend_config_test.dart`
- Modify: `lib/config/player_backend_config.dart`

- [ ] **Step 1: Write the failing test**

Add coverage for:
- Android with screen-off playback enabled prefers native playback for online streams
- Android with screen-off playback disabled preserves existing behavior
- Non-Android platforms ignore the Android-only preference

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/player_backend_config_test.dart`
Expected: FAIL because the new routing rule is not fully encoded yet

- [ ] **Step 3: Write minimal implementation**

Update `lib/config/player_backend_config.dart` so the routing rule is explicit and reusable by both Flutter UI and bridge code.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/player_backend_config_test.dart`
Expected: PASS

### Task 2: Define Android bridge contract in Dart

**Files:**
- Create: `lib/services/android_media_session_bridge.dart`
- Create: `test/services/android_media_session_bridge_test.dart`
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/widgets/video_player_widget.dart`

- [ ] **Step 1: Write the failing test**

Add tests for:
- metadata payload generation from current playback item
- action names for play, pause, next, previous, seek
- no-op behavior on non-Android

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: FAIL because the bridge service does not exist yet

- [ ] **Step 3: Write minimal implementation**

Create a small Dart bridge service that wraps method-channel calls and normalizes payloads. Wire it into the player screen so metadata/state updates are emitted only for Android sessions that are using the native playback path.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: PASS

### Task 3: Add Android media playback service shell

**Files:**
- Create: `android/app/src/main/kotlin/org/moontechlab/selene/MediaPlaybackService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts` or `android/app/build.gradle`

- [ ] **Step 1: Write the failing test**

Add a lightweight Android-facing contract test where possible in Dart for expected method names and service capability flags. If no Android unit harness exists, document this task as manual-verified and start with manifest/service compile integration.

- [ ] **Step 2: Run verification to confirm the feature is missing**

Run: `flutter analyze android/app/src/main/kotlin/org/moontechlab/selene/MediaPlaybackService.kt`
Expected: file missing / feature absent

- [ ] **Step 3: Write minimal implementation**

Create a Media3-based service that:
- creates a media session
- publishes a media-style notification
- marks itself as `mediaPlayback`
- exposes session callbacks for play/pause/seek/next/previous

- [ ] **Step 4: Run verification**

Run: `flutter analyze`
Expected: service code and manifest compile without new Android syntax errors

### Task 4: Bridge Flutter commands to Android media session

**Files:**
- Modify: `android/app/src/main/kotlin/org/moontechlab/selene/MainActivity.kt`
- Modify: `lib/services/android_media_session_bridge.dart`
- Modify: `lib/widgets/video_player_widget.dart`
- Modify: `lib/screens/player_screen.dart`

- [ ] **Step 1: Write the failing test**

Add tests that prove Flutter sends:
- session start/update with title/artwork/duration/position
- playback state changes
- teardown when playback stops or widget disposes

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: FAIL because the command flow is incomplete

- [ ] **Step 3: Write minimal implementation**

Wire the player lifecycle so Android receives:
- current media metadata when playback starts or episode changes
- state updates when play/pause/progress changes
- cleanup when playback ends or route falls back away from native playback

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: PASS

### Task 5: Route Android media session actions back into Flutter playback

**Files:**
- Modify: `android/app/src/main/kotlin/org/moontechlab/selene/MainActivity.kt`
- Modify: `lib/widgets/video_player_widget.dart`
- Modify: `test/services/android_media_session_bridge_test.dart`

- [ ] **Step 1: Write the failing test**

Add tests for inbound actions:
- play
- pause
- toggle play/pause
- previous
- next
- seek

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: FAIL because inbound action dispatch is not wired

- [ ] **Step 3: Write minimal implementation**

Reuse the existing PiP-style command channel pattern where appropriate, but keep media-session action names isolated so PiP and notification actions do not conflict.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/android_media_session_bridge_test.dart`
Expected: PASS

### Task 6: Expose and persist the Android-only setting in application settings

**Files:**
- Modify: `lib/widgets/user_menu.dart`
- Modify: `lib/services/user_data_service.dart`
- Modify: `test/services/user_data_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add tests covering:
- default disabled state
- persistence round-trip
- Android-only visibility wording

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/user_data_service_test.dart`
Expected: FAIL if new wording or state handling changes are not reflected yet

- [ ] **Step 3: Write minimal implementation**

Keep the existing setting but update wording and control flow so it clearly promises Android media notification / lock-screen behavior only for supported sources.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/user_data_service_test.dart`
Expected: PASS

### Task 7: Manual device validation and regression sweep

**Files:**
- Modify: `docs/superpowers/specs/2026-03-24-android-media-session-island-playback-design.md`

- [ ] **Step 1: Run focused automated checks**

Run:
- `flutter test test/config/player_backend_config_test.dart test/services/android_media_session_bridge_test.dart test/services/user_data_service_test.dart`
- `flutter analyze lib/config/player_backend_config.dart lib/services/android_media_session_bridge.dart lib/screens/player_screen.dart lib/widgets/video_player_widget.dart lib/widgets/user_menu.dart`

Expected: PASS, or only pre-existing warnings outside the new scope

- [ ] **Step 2: Run Android manual checks**

Verify on device:
- screen-off audio continues
- lock-screen controls work
- PiP still works when manually entered
- exiting PiP does not kill the media session unexpectedly
- Xiaomi HyperOS device surfaces media playback in island/capsule UI if supported by the system

- [ ] **Step 3: Record source compatibility notes**

Document which stream/source shapes still fall back to WebView and therefore cannot promise media-session island behavior.
