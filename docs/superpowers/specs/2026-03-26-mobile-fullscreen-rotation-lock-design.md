# Mobile Fullscreen Rotation Lock Design

**Date:** 2026-03-26

## Goal

Adjust fullscreen rotation behavior on iOS and Android phones/tablets so that:

- fullscreen playback can switch between left and right landscape when system auto-rotation is available
- fullscreen playback never rotates back to portrait while staying fullscreen
- exiting fullscreen keeps the current behavior unchanged

The design must apply to both the standard player and the live player.

## Scope

- Standard player flow in `lib/screens/player_screen.dart`
- Live player flow in `lib/screens/live_player_screen.dart`
- Shared fullscreen orientation policy in a new helper under `lib/services/` or `lib/utils/`
- Small Android platform bridge to read the system auto-rotation setting

## Non-Goals

- No changes to desktop or web behavior
- No changes to non-fullscreen layout rotation behavior
- No changes to the existing fullscreen exit rules on phone or tablet
- No changes to short-drama portrait fullscreen behavior
- No attempt to expose a user-visible "rotation lock" toggle inside the app

## Design

### Behavior rules

This change only applies on mobile/tablet when the player is already in fullscreen.

- Entering fullscreen for regular video still goes to landscape fullscreen
- Entering fullscreen for short-drama style portrait flows keeps the current portrait-only logic
- While fullscreen is stable:
  - if the device moves from left landscape to right landscape, the player may switch to the new landscape side
  - if the device moves from right landscape to left landscape, the player may switch to the new landscape side
  - if the device is held vertically, the player stays in the current landscape fullscreen
- Exiting fullscreen must keep today's behavior:
  - phone flow keeps the current portrait restore logic
  - tablet flow keeps the current orientation restore logic

### State boundaries

The fullscreen rotation policy only runs when all of the following are true:

- the platform is not PC/web
- the player is fullscreen
- the player is not in the "entering fullscreen" transition window
- the current flow is not the short-drama portrait fullscreen path

The policy must ignore:

- non-fullscreen orientation changes
- portrait device posture while still fullscreen
- unknown orientation readings
- duplicate requests that would re-apply the same orientation set

### Platform strategy

#### Shared orientation signal source

Current landscape side detection for Android must not be inferred from Flutter width/height alone.

Add a small Android platform bridge:

- `MethodChannel('selene/orientation')`
  - `getCurrentInterfaceOrientation() -> String`
  - `getSystemAutoRotateEnabled() -> bool?`

Rules:

- Only Android implements this bridge in the first version
- Orientation values are one of: `portraitUp`, `portraitDown`, `landscapeLeft`, `landscapeRight`, `unknown`
- On Android, `getCurrentInterfaceOrientation()` must return values in Flutter `DeviceOrientation` semantics, not raw `Surface.ROTATION_*` values
- The Android implementation must account for devices whose natural orientation is landscape
- Natural orientation should be derived before mapping rotation:
  - portrait-natural devices map as `ROTATION_0 -> portraitUp`, `ROTATION_90 -> landscapeLeft`, `ROTATION_180 -> portraitDown`, `ROTATION_270 -> landscapeRight`
  - landscape-natural devices map as `ROTATION_0 -> landscapeLeft`, `ROTATION_90 -> portraitDown`, `ROTATION_180 -> landscapeRight`, `ROTATION_270 -> portraitUp`
- The purpose of the bridge is: given the current Android interface posture, return the same logical orientation labels that Flutter `SystemChrome.setPreferredOrientations` expects
- Sanity check for mapping: starting from portraitUp, a clockwise rotation should land on `landscapeRight`, and a counter-clockwise rotation should land on `landscapeLeft`

#### Android

Android will explicitly read the system auto-rotation setting through a small platform bridge backed by `Settings.System.ACCELEROMETER_ROTATION`.

- If auto-rotation is enabled, fullscreen may switch between `landscapeLeft` and `landscapeRight`
- If auto-rotation is disabled, fullscreen freezes on the current landscape side
- The value should be read when entering fullscreen. Mid-session system setting changes are out of scope for this first implementation and take effect the next time fullscreen is entered.

When entering fullscreen on Android:

- use the current fullscreen-entry behavior to request landscape fullscreen first
- after fullscreen stabilizes, read `getSystemAutoRotateEnabled()`
  - if `true`, apply `SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])`
  - if `false`, read `getCurrentInterfaceOrientation()` and lock to the returned landscape side
  - if `null` (unknown), do not change the current orientation request
- if `getCurrentInterfaceOrientation()` is not a landscape value yet, keep the existing fullscreen landscape request and retry `getCurrentInterfaceOrientation()` on Android for up to 500ms in short intervals until `landscapeLeft` or `landscapeRight` is confirmed, then lock to that side
- if no landscape side is confirmed within that bounded retry window, keep the existing fullscreen landscape request for the rest of that fullscreen session
- if reading `Settings.System.ACCELEROMETER_ROTATION` fails or is unavailable on an OEM build, treat `getSystemAutoRotateEnabled()` as `null` and keep the current fullscreen landscape request unchanged for that session

In this spec, "current landscape side" means the first confirmed fullscreen interface orientation after the entry transition has stabilized.

#### iOS

iOS will not try to read the system rotation-lock switch directly.

Instead, iOS follows actual system-delivered orientation changes:

- fullscreen allows landscape orientations
- the system will rotate between left/right landscapes when allowed
- portrait posture while fullscreen is ignored by keeping portrait out of the allowed set

This keeps behavior aligned with what iOS actually allows, without adding fragile native lock-state detection.

### Shared policy layer

Introduce a small shared fullscreen orientation helper used by both player screens.

Responsibilities:

- decide whether a fullscreen orientation update should run
- map the current platform state into one of three outcomes:
  - allow both landscapes
  - lock to left landscape
  - lock to right landscape
- respect Android auto-rotation availability
- stay out of fullscreen exit behavior

The helper should remain UI-agnostic and avoid direct widget dependencies so it can be covered by focused Dart tests.

#### Helper contract

Inputs:

- `isFullscreen`
- `isEnteringFullscreen`
- `isShortDramaPortraitFlow`
- `platform`
- `observedInterfaceOrientation`
- `lastConfirmedLandscapeOrientation`
- `androidAutoRotateEnabled`

Outputs:

- `no-op`
- `setPreferredOrientations([landscapeLeft])`
- `setPreferredOrientations([landscapeRight])`
- `setPreferredOrientations([landscapeLeft, landscapeRight])`

Policy:

- non-fullscreen -> `no-op`
- entering-fullscreen transition -> `no-op`
- short-drama portrait flow -> `no-op`
- iOS fullscreen -> allow both landscapes
- Android fullscreen + auto-rotate enabled -> allow both landscapes
- Android fullscreen + auto-rotate disabled:
  - if `observedInterfaceOrientation` is `landscapeLeft`/`landscapeRight`, lock to that side
  - else if `lastConfirmedLandscapeOrientation` exists, lock to that side
  - else `no-op`
- Android fullscreen + auto-rotate unknown -> `no-op`

The helper must never return portrait orientations for fullscreen handling.

### Screen integration

`player_screen.dart` and `live_player_screen.dart` should both:

- keep their existing enter-fullscreen and exit-fullscreen UI mode behavior
- call the shared policy helper after fullscreen entry is stabilized
- skip the policy while fullscreen entry is still stabilizing
- de-duplicate orientation updates before calling `SystemChrome.setPreferredOrientations`

`player_screen.dart` already has a fullscreen transition guard and a `didChangeMetrics` hook. That screen should keep using `_isEnteringLandscapeFullscreen` plus the existing landscape wait helper as the stabilization gate.

`live_player_screen.dart` should add the same guard semantics:

- introduce a fullscreen-entry transition flag equivalent to `_isEnteringLandscapeFullscreen`
- wait for the same landscape timeout window used by `player_screen.dart` (currently 850ms) before marking fullscreen as stable
- only activate the shared policy after that point

Only Android should query the platform orientation bridge in this first version. The query starts after fullscreen stabilization completes. If Android auto-rotation is disabled and the first orientation read is not yet a landscape side, the screen should perform the bounded 500ms retry described above, then stop. iOS does not use a native bridge in this first version. Metrics changes remain useful for existing fullscreen UI updates, but the new auto-rotation decision does not depend on a continuous platform listener in this first version.

In `live_player_screen.dart`, `isShortDramaPortraitFlow` is always `false`.

De-duplication rule: compare the normalized target orientation set with the last applied orientation set, and skip `SystemChrome.setPreferredOrientations` if they are identical.

Fullscreen exit reset paths are unchanged and must continue to restore orientations via:

- `player_screen.dart`: `_onFullscreenChanged(false)` path
- `live_player_screen.dart`: `_onFullscreenChanged(false)` path

## Risks

- Interface orientation can be `unknown` during fullscreen transitions, so the policy must not force a side until stabilization completes
- Repeated `SystemChrome.setPreferredOrientations` calls can create flicker or extra transitions if updates are not de-duplicated
- The Android bridge must fail safely so a read error behaves like "do not change current landscape" rather than breaking fullscreen
- Existing PiP and fullscreen-entry fixes must not regress while reusing the same metrics callbacks

## Verification

- Add focused Dart tests for the shared fullscreen orientation helper covering:
  - non-fullscreen ignores
  - Android fullscreen + auto-rotation enabled returns both landscapes
  - Android fullscreen + auto-rotation disabled locks the confirmed current landscape
  - Android fullscreen + auto-rotation unknown returns `no-op`
  - iOS fullscreen returns both landscapes
  - short-drama path bypasses the new policy
- Manually verify standard player on:
  - iPhone / Android phone
  - iPad / Android tablet
- Manually verify live player on the same four device classes
- On Android, verify both system states by entering fullscreen once with auto-rotation enabled and once with auto-rotation disabled
- Confirm fullscreen exit behavior is unchanged for phone and tablet
- Confirm PiP entry/exit still behaves as before, especially on Android
- Run `dart format`, targeted tests, and `flutter analyze` on the touched scope as practical
