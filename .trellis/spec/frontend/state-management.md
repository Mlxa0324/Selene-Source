# State Management

> Selene uses Provider/ChangeNotifier for app-level reactive state, StatefulWidget for local UI state, and services for persisted or server state.

## Overview

Current state patterns:

- Local UI state: `StatefulWidget` fields inside screens and complex widgets.
- App-wide reactive state: Provider-backed services, especially `ThemeService`.
- Persisted settings/session state: `UserDataService` and related services using SharedPreferences.
- Server state: service methods in `ApiService`, `SearchService`, `DoubanService`, `LiveService`, and similar classes.
- TV focus state: `TvFocusable` and TV widgets manage focus memory and remote navigation.

## State Categories

- Ephemeral UI state: panel open/closed, selected tab, slider drag value, loading indicator. Keep local.
- Route/page state: query text, selected episode, current source, search results. Keep in the screen unless shared.
- Global visual/app state: theme and app-wide mode. Use Provider/ChangeNotifier.
- Persisted user preferences: save through `UserDataService` or the owning service.
- Playback state: keep in player widgets/controllers and synchronize through callbacks.

## When to Use Global State

Promote state out of a widget only when:

- Multiple unrelated widget branches read the same value.
- The value must survive route changes.
- The value is persisted and should be loaded through a service.
- The value is a TV-wide focus/navigation concern.

Do not use Provider for one-off dialog state or a single component's internal selection.

## Server and Cache State

- Server-mode data should flow through API/search/live services.
- Local-mode data should flow through `LocalModeStorageService`.
- Cache services own expiration and cleanup policy.
- Screens should handle loading/error/empty states based on typed service results.
- Avoid duplicating fetched lists in multiple services unless one is an intentional derived cache.

## Common Mistakes

- Calling `setState` after async work without checking `mounted`.
- Storing persisted preferences only in widget fields and not saving them through `UserDataService`.
- Triggering broad Provider rebuilds for state that belongs in a single screen.
- Losing TV focus memory when rebuilding lists; use established `TvFocusable` group behavior.
