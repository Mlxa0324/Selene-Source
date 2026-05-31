# Directory Structure

> Frontend code is Flutter UI: screens, widgets, TV UI, layout helpers, and presentation state.

## Overview

Selene uses a layered Flutter structure. Phone/desktop page-level UI is in `lib/screens/`, reusable components are in `lib/widgets/`, and large-screen remote-control UI is isolated in `lib/tv_app/`. Shared data and business behavior should stay in `lib/models/`, `lib/services/`, and `lib/utils/`.

Existing examples:

- `lib/screens/home_screen.dart`, `lib/screens/player_screen.dart`, and `lib/screens/search_screen.dart` are page-level workflows.
- `lib/widgets/video_player_widget.dart`, `lib/widgets/pc_player_controls.dart`, and `lib/widgets/mobile_player_controls.dart` compose the normal playback UI.
- `lib/widgets/player_settings_panel.dart` is a reusable settings panel with typed callbacks.
- `lib/tv_app/screens/tv_home_screen.dart` and `lib/tv_app/widgets/tv_focusable.dart` are TV-only UI boundaries.

## Directory Layout

```text
lib/
├── screens/                 # Phone/desktop pages and route destinations
├── widgets/                 # Shared reusable Flutter widgets
├── tv_app/
│   ├── screens/             # TV-specific pages
│   ├── widgets/             # TV focus, navigation, cards, overlays
│   └── services/            # TV adapters over shared services
├── services/                # Business/data layer consumed by UI
├── models/                  # Typed UI/service data
├── utils/                   # Layout/policy helpers used by widgets
└── config/                  # Device mode and playback backend config

test/
├── widgets/                 # Shared widget tests
├── screens/                 # Page-level widget tests
└── tv_app/                  # TV UI/service/focus tests
```

## Module Organization

- Add a new full page to `lib/screens/` unless it is TV-only.
- Add reusable phone/desktop components to `lib/widgets/`.
- Add TV-only screens, cards, navigation, and focus wrappers under `lib/tv_app/`.
- Keep layout calculations that can be pure functions in `lib/utils/`; this makes them easier to test.
- Route through `Navigator`/`MaterialPageRoute` in the current app style unless working in the TV shell's route helpers.

## Naming Conventions

- Files use `snake_case.dart`.
- Page widgets end in `Screen`, for example `DownloadScreen`.
- Reusable widgets describe the component, for example `VideoCard`, `PlayerSettingsPanel`, or `TvFocusable`.
- TV-specific UI uses the `Tv` prefix.
- Tests end with `_test.dart` and usually include the subject name, for example `player_settings_panel_test.dart`.

## Examples

- `lib/widgets/player_settings_panel.dart` shows typed constructor props and callback-based composition.
- `lib/widgets/video_card.dart` shows reusable content cards consumed by multiple screens.
- `lib/tv_app/widgets/tv_focusable.dart` shows TV-specific focus behavior isolated from normal widgets.
- `test/widgets/player_settings_panel_test.dart` shows a focused widget regression test.
- `test/tv_app/tv_video_card_test.dart` shows TV component testing.

## Forbidden Patterns

- Do not place TV-only focus behavior in normal phone/desktop widgets.
- Do not call APIs directly from widgets when a service layer already exists.
- Do not create giant page files for reusable UI pieces; extract repeated controls into `lib/widgets/` or `lib/tv_app/widgets/`.
- Do not add untested layout helper behavior when it can be covered as a pure function.
