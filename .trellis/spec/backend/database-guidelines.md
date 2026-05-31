# Database Guidelines

> Selene currently has no relational database, ORM, or migration system. Persistence is local preference storage, local files, cache files, and remote HTTP APIs.

## Overview

The app stores lightweight configuration and user data with `shared_preferences`, stores larger/cache data through file-oriented services, and talks to a remote MoonTV-compatible API through HTTP services. Document and preserve these boundaries instead of introducing a database abstraction.

Existing examples:

- `lib/services/user_data_service.dart` stores login data, playback preferences, source browser settings, and feature toggles in SharedPreferences.
- `lib/services/douban_cache_service.dart` manages cached Douban metadata with a 7-day validity window and periodic cleanup.
- `lib/services/page_cache_service.dart` caches page/category data.
- `lib/services/local_mode_storage_service.dart` supports local-mode user data.
- `lib/services/download_service.dart` and `lib/services/m3u8_service.dart` handle download metadata and M3U8 workflows.

## Storage Patterns

Use the smallest storage layer that fits the data:

- SharedPreferences: scalar settings, login/session values, feature flags, playback preferences, and small JSON blobs.
- File cache: API responses or media-related data that can expire, be cleared, or be regenerated.
- In-memory cache: hot settings used during playback or TV navigation, only when repeated async reads are on a critical path.
- Remote API: server-mode favorites, play records, source data, and search behavior.

When adding SharedPreferences keys, place the key in the owning service as a `static const String`, keep the key private unless external callers genuinely need it, and add save/get/clear methods next to related methods.

## Cache Conventions

- Cache ownership belongs to one service. For example, `UserDataService` owns playback preference caches and `DoubanCacheService` owns Douban metadata cache.
- Provide explicit debug/test reset hooks for process-memory caches, as `UserDataService.debugResetMemoryCaches()` does.
- Update both persisted value and memory cache in the same save method when a setting has both.
- Keep cache key versions in the key name when changing semantics, for example `_playbackPreloadLevelKey = 'playback_preload_level_v1'`.
- Preserve legacy fallback reads when migrating settings; `getPlaybackPreloadLevel()` falls back to older boolean keys before returning the default level.

## Migrations

There are no schema migrations. Existing migration style is defensive read fallback:

- New keys should have defaults when no stored value exists.
- When replacing a key, read the new key first, then fall back to legacy keys.
- Do not silently delete legacy values during reads unless the service already has a clear migration path.
- Add tests that pin default and fallback behavior, as in `test/services/user_data_service_preload_test.dart`.

## Naming Conventions

- SharedPreferences keys use lowercase snake case plus a version suffix when the format may evolve, such as `show_live_v1`.
- Service methods use explicit verbs: `saveServerUrl`, `getCookies`, `clearSessionCookies`, `setIsLocalMode`.
- JSON model fields mirror API payloads when necessary, even if they use snake case such as `source_name` or `episodes_titles`.
- Dart model fields use idiomatic lowerCamelCase and map to API keys inside `fromJson`/`toJson`.

## Common Mistakes

- Reading SharedPreferences repeatedly in hot playback paths instead of using an existing memory cache.
- Adding a new setting without a default and causing first-run behavior to change.
- Changing a key string without searching all references and tests.
- Putting remote response parsing directly in UI code instead of service/model layers.
