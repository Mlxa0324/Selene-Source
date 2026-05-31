# Quality Guidelines

> Backend-like changes must preserve service boundaries, storage compatibility, and tested behavior.

## Overview

The repository uses `flutter_lints` from `analysis_options.yaml`. Service and model code is mostly hand-written Dart with explicit serialization, static service methods, and focused unit tests. Current test coverage exists under `test/services/`, `test/utils/`, and `test/tv_app/`; do not rely on older module docs that say there is no coverage.

## Required Patterns

- Run `flutter analyze` for Dart changes when feasible.
- Add or update `flutter test` coverage for service, cache, parsing, settings, or utility behavior.
- Use `SharedPreferences.setMockInitialValues` and service debug reset hooks for preference tests.
- Keep deterministic logic in utils or services so it can be tested without pumping a widget.
- Preserve backward-compatible defaults for settings and cached data.
- Use `final` for values that do not change and `const` constructors/widgets where the local style supports it.

## Forbidden Patterns

- Direct HTTP, SharedPreferences, or file-cache logic inside widgets/screens when a service layer exists.
- Untested changes to key strings, cache invalidation, default playback settings, or login/session behavior.
- Introducing global mutable state without a reset strategy for tests.
- Changing model JSON keys without checking API callers and persisted data.
- Adding broad dependencies for small service changes.

## Testing Requirements

- Model serialization: test `fromJson` and `toJson`, especially nullable fields and defaults.
- SharedPreferences settings: test first-run defaults, save/read behavior, legacy fallbacks, and memory-cache reset.
- API wrappers: test URL/header/error mapping where the method has branching behavior.
- Cache/file services: test expiration, clear behavior, and malformed data fallback.
- TV services: test both mobile settings bridge behavior and TV-specific defaults under `test/tv_app/`.

Useful existing tests:

- `test/services/user_data_service_preload_test.dart`
- `test/services/app_cache_service_test.dart`
- `test/services/download_service_test.dart`
- `test/services/danmaku_service_test.dart`
- `test/utils/player_cached_range_utils_test.dart`
- `test/tv_app/tv_account_config_service_test.dart`

## Code Review Checklist

- Does the change keep the service/model/UI boundary intact?
- Are storage keys searched and updated consistently?
- Is first-run behavior still defined?
- Are legacy stored values handled when a preference shape changes?
- Can tests reset any new memory cache or static singleton state?
- Are user-facing error messages localized consistently with nearby code?
