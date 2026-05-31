# Directory Structure

> Backend-like code in this Flutter project means service, data, cache, network, platform, and persistence code. There is no server package in this repository.

## Overview

Selene is a Flutter video player app. Runtime business logic lives in `lib/services/`, data transfer and persistence shapes live in `lib/models/`, reusable policy helpers live in `lib/utils/`, and platform-specific code lives under Flutter platform folders plus the experimental native TV rewrite in `re-android/`.

Existing examples:

- `lib/services/api_service.dart` builds authenticated HTTP requests and wraps remote responses in `ApiResponse<T>`.
- `lib/services/user_data_service.dart` owns SharedPreferences keys, playback settings, login data, and memory caches.
- `lib/services/download_service.dart`, `lib/services/m3u8_service.dart`, and `lib/services/app_cache_service.dart` handle file/cache-heavy workflows.
- `lib/models/search_result.dart`, `lib/models/play_record.dart`, and `lib/models/download_task.dart` define serialized data shapes.
- `lib/utils/player_cached_range_utils.dart` and `lib/utils/fullscreen_orientation_policy.dart` hold deterministic policy logic with matching unit tests.

## Directory Layout

```text
lib/
├── main.dart                         # Flutter entry point
├── app_bootstrap.dart                # App/TV shell selection
├── config/                           # Compile-time and runtime feature config
├── models/                           # JSON/data models and small enums
├── services/                         # API, cache, storage, search, playback services
├── utils/                            # Pure helpers and policy functions
├── screens/                          # Phone/desktop page-level widgets
├── widgets/                          # Shared UI widgets
└── tv_app/                           # TV-specific screens, widgets, and services

test/
├── services/                         # Service and cache behavior tests
├── utils/                            # Pure policy/helper tests
├── widgets/                          # Widget behavior/layout tests
├── screens/                          # Page-level regression tests
└── tv_app/                           # TV shell, focus, route, and service tests

re-android/
├── app-tv/                           # Native Android TV app shell
├── core-*                            # Native core modules
└── feature-tv-*                      # Native TV feature modules
```

## Module Organization

Add new business capabilities by layer:

- Data shape: create or extend a model in `lib/models/` with `fromJson` and `toJson` when persisted or returned from API data.
- Remote/local behavior: add service methods in `lib/services/`; keep widgets out of HTTP, cache, and SharedPreferences details.
- Deterministic decisions: place pure policy logic in `lib/utils/` and test it under `test/utils/`.
- TV-specific behavior: prefer `lib/tv_app/services/` or `lib/tv_app/widgets/` when the behavior is remote-control or large-screen specific.
- Native Android TV rewrite: keep Kotlin work inside the matching `re-android/core-*` or `re-android/feature-tv-*` module.

Do not add API calls directly in `lib/screens/` or `lib/widgets/` when a service already owns that domain.

## Naming Conventions

- Dart files use `snake_case.dart`.
- Dart classes, enums, and typedefs use `UpperCamelCase`.
- Methods, variables, fields, and parameters use `lowerCamelCase`.
- Private implementation details use a leading underscore, as in `ApiService._buildHeaders`.
- SharedPreferences keys are private static constants near the top of the owning service, as in `UserDataService._playbackPreloadLevelKey`.
- Test files mirror the subject and end in `_test.dart`, for example `test/services/user_data_service_preload_test.dart`.

## Examples

- `lib/services/user_data_service.dart` is the canonical owner for local user/app settings.
- `lib/services/api_service.dart` shows the current remote API wrapper style.
- `lib/tv_app/services/tv_account_config_service.dart` shows TV-specific service adaptation.
- `test/services/user_data_service_preload_test.dart` shows SharedPreferences tests with mocked values and memory-cache reset.
- `test/tv_app/tv_focusable_test.dart` and `lib/tv_app/widgets/tv_focusable.dart` show the TV interaction boundary.

## Forbidden Patterns

- Do not put new persistence keys in widgets or screens.
- Do not duplicate model parsing inside services if a model already owns the JSON shape.
- Do not mix generic phone/desktop UI code into `lib/tv_app/`; TV code should depend on shared services/models, not the other way around.
