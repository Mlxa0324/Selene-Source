# Quality Guidelines

> Frontend changes should preserve responsive Flutter behavior across phone, desktop, and TV modes.

## Overview

The project uses `flutter_lints` through `analysis_options.yaml` and has active tests under `test/widgets/`, `test/screens/`, and `test/tv_app/`. UI work should follow existing Flutter patterns, keep service boundaries clean, and add focused regression tests for behavior or layout changes.

## Required Patterns

- Run `flutter analyze` for Dart UI changes when feasible.
- Add widget tests for changed visible behavior, callbacks, layout contracts, focus behavior, and regression-prone panels.
- Use `MaterialApp`/`Scaffold` wrappers in widget tests when the widget depends on theme, Navigator, or Material inherited widgets.
- Keep page-level workflows in screens and reusable controls in widgets.
- For TV UI, test focus and route behavior under `test/tv_app/`.
- Use `const` and `final` where supported by the current code style.
- For image-heavy lists, reuse the shared default `AppCacheService.instance` for disk-cache policy checks and merge concurrent policy reads; keep injected `AppCacheService` instances available for isolated tests and special callers.
- High-frequency image URL resolution must reuse the in-memory Douban image-source setting. Saving that setting must refresh the memory value before later cards resolve URLs.
- For WebView HLS preload telemetry, fragment-load handlers must refresh both network speed and buffered ranges; `Hls.Events.FRAG_LOADED` should call `emitBufferedRanges()` so Flutter receives `cached_ranges` even when mobile WebView `progress` events are sparse.
- When `VideoPlayerWidget` reuses an existing WebView adapter for episode or source switching, restore the cached-range subscription after `updateSource()`; switching cancels the old subscription before the new source starts reporting preload ranges.
- Treat empty WebView `cached_ranges` as a clear signal for the active media key during source switches. Do not ignore it as "no update", or the previous episode's persisted preload progress can remain visible.
- Use persisted cached ranges only for the preload progress bar. Loading overlays must read the adapter's real-time `state.cachedRanges`; persisted ranges can contain accumulated history that no longer proves the current playback position is buffered.
- WebView pause/resume playback must use a resume helper rather than bare `player.play()`; the helper should wake hls.js with `startLoad(currentTime)` and schedule finite recovery checks so iOS does not stay stuck in `waiting` after a long pause.

## Forbidden Patterns

- API calls, cache keys, or raw SharedPreferences access in widgets/screens.
- Unbounded text or controls that can overflow compact player panels.
- Layout changes that only work on one platform without checking mobile/desktop/TV implications.
- Changing public widget constructor requirements without updating all callers and tests.
- Replacing existing tested helper functions with inline layout math.
- Tying seek warmup or fast-seek helpers to the main preload buffer in a way that silently reduces the configured forward buffer. Seek recovery should strengthen jump points without overriding the normal preload level.

## Testing Requirements

- Component behavior: use `testWidgets`, pump the component, interact with controls, and assert callbacks or rendered state.
- Layout helper logic: prefer plain `test` for pure functions.
- Player controls: cover seek/preload/surface-key regressions in `test/widgets/`.
- Video player cache regressions: cover controller-supplied media identity, empty `cached_ranges` clearing, and loading overlay suppression based on real-time cached ranges.
- Generated WebView player HTML: assert important JS event hooks directly, especially `cached_ranges` bridge behavior and preload buffer tuning.
- WebView play bridge tests should assert pause-resume recovery commands directly, including `resumePlaybackFromPause`, HLS `startLoad`, and finite recovery scheduling.
- TV focus: cover directional focus, back handling, and route behavior in `test/tv_app/`.
- Screen regressions: add focused tests under `test/screens/` for page-level behavior.

Useful existing tests:

- `test/widgets/player_settings_panel_test.dart`
- `test/widgets/mobile_player_controls_seek_test.dart`
- `test/widgets/video_player_widget_preload_config_test.dart`
- `test/widgets/global_back_handler_test.dart`
- `test/screens/player_screen_danmaku_seek_test.dart`
- `test/tv_app/tv_focusable_test.dart`
- `test/tv_app/tv_route_test.dart`

## Code Review Checklist

- Does the UI still delegate data operations to services?
- Are constructor fields typed and required/nullable intentionally?
- Is the behavior covered by a focused widget/unit test?
- Does TV-specific behavior stay inside `lib/tv_app/`?
- Are async UI updates guarded by `mounted` where needed?
- Can long text fit inside compact panels, cards, and controls?
