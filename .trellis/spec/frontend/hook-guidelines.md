# Hook Guidelines

> This is not a React codebase. The equivalent reusable stateful logic is Flutter controllers, services, `ChangeNotifier`, and focused helper classes.

## Overview

Selene does not use React hooks. Do not create hook-like abstractions. Share stateful logic through the patterns already present in the app:

- `StatefulWidget` state for page-local interaction state.
- `ChangeNotifier` with Provider for app-wide reactive state, such as `ThemeService`.
- Static service methods for storage, API, cache, and business operations.
- Controllers for imperative widget behavior, such as player control.
- Pure helpers in `lib/utils/` for deterministic policies.

## Stateful Logic Patterns

- Page state belongs in `State<T>` when it is only needed by one screen.
- Cross-widget app state belongs in a service/`ChangeNotifier` only when multiple branches of the widget tree consume it.
- Playback and panel controls use typed callbacks from child widgets to parent screens.
- Long-lived listeners, timers, focus nodes, controllers, and streams must be initialized in `initState` and cleaned up in `dispose`.

## Data Fetching

- Fetch data through `lib/services/` methods.
- Screens orchestrate loading state and pass typed results into widgets.
- Widgets should not know HTTP endpoint details, cookie handling, or cache key names.
- TV screens may use `lib/tv_app/services/` adapters when they need TV-specific defaults over shared services.

## Naming Conventions

- Do not use `use*` names; this project is Flutter/Dart.
- Controllers end in `Controller` when they expose imperative behavior.
- Services end in `Service`.
- ChangeNotifier services should expose clear methods and call `notifyListeners()` only when observers need a rebuild.
- Private state fields use a leading underscore.

## Common Mistakes

- Inventing React-style hook APIs in Dart.
- Forgetting to dispose `FocusNode`, `AnimationController`, `Timer`, or stream subscriptions.
- Putting data-fetch retries or cache fallbacks in widgets instead of services.
- Calling `notifyListeners()` for internal changes that no UI observes.
