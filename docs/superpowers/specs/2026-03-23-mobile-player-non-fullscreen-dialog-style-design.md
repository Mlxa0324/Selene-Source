# Mobile Player Non-Fullscreen Dialog Style Design

**Date:** 2026-03-23

## Goal

Unify the non-fullscreen mobile and tablet presentation for the player `选集`, `换源`, `定时关闭`, and `设置` dialogs on iOS and Android so they all use a solid barrier and an opaque panel background.

## Scope

- Standard player flow in `lib/screens/player_screen.dart`
- Short drama flow in `lib/widgets/short_drama_controls.dart`
- Panel widgets used by the four entry points:
  - `lib/widgets/player_episodes_panel.dart`
  - `lib/widgets/player_sources_panel.dart`
  - `lib/widgets/player_sleep_timer_panel.dart`
  - `lib/widgets/player_settings_panel.dart`

## Design

### Entry-layer behavior

For iOS and Android when the player is **not** in fullscreen:

- Bottom sheets use `theme.scaffoldBackgroundColor` as `barrierColor`
- Side sheets shown from non-fullscreen tablet contexts also use `theme.scaffoldBackgroundColor`
- Existing fullscreen and PC overlays keep their current translucent behavior

### Panel-layer behavior

For the same non-fullscreen mobile/tablet contexts:

- Pass `backgroundOpacity: 1.0` into the four panels
- Keep existing radius and layout behavior
- Avoid introducing a new shared helper so the rollback surface stays small

### Short drama parity

The short drama controls must follow the same rule set as the standard player so users do not see two different dialog styles for the same actions.

## Risks

- `player_settings_panel.dart` currently assumes side-sheet radius; mobile bottom-sheet callers need an explicit bottom-sheet shape without breaking fullscreen side sheets
- Short drama settings use a local sheet widget, so its barrier and background need separate alignment

## Verification

- Add a focused widget test covering opaque background behavior for the reusable panel widgets
- Run targeted Flutter tests
- Run `dart format` and `flutter analyze` on touched files or project scope as practical
