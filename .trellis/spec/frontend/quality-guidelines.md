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

## Forbidden Patterns

- API calls, cache keys, or raw SharedPreferences access in widgets/screens.
- Unbounded text or controls that can overflow compact player panels.
- Layout changes that only work on one platform without checking mobile/desktop/TV implications.
- Changing public widget constructor requirements without updating all callers and tests.
- Replacing existing tested helper functions with inline layout math.

## Testing Requirements

- Component behavior: use `testWidgets`, pump the component, interact with controls, and assert callbacks or rendered state.
- Layout helper logic: prefer plain `test` for pure functions.
- Player controls: cover seek/preload/surface-key regressions in `test/widgets/`.
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
