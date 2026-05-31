# Technical Design

## Scope

This task wires local-only development credentials into the Kotlin TV app and connects the existing TV home repository to a real backend session.

## Local Configuration

- Real local file: `re-android/local.gateway.properties`
- Tracked template: `re-android/local.gateway.properties.example`
- Fields:
  - `SELENE_TV_BASE_URL`
  - `SELENE_TV_USERNAME`
  - `SELENE_TV_PASSWORD`

The real file is git-ignored. Gradle reads it at configuration time and injects values into `app-tv` `BuildConfig`.

## Network Contracts

- Login endpoint: `POST /api/login`
- Request body: JSON `{ "username": "...", "password": "..." }`
- Login success: HTTP 2xx with optional `Set-Cookie`
- Authenticated requests: include `Cookie` header when the session store has a cookie.
- Dashboard endpoint: `GET admin/dashboard`

## Kotlin Boundaries

- `app-tv` owns build-time local config because only the application module can safely expose `BuildConfig` for a local installed build.
- `core-network` owns Retrofit, OkHttp, login DTOs, baseUrl normalization, Cookie parsing, and API creation.
- `core-data` keeps repository contracts and does not read Gradle/local files.
- `feature-tv-home` remains UI-state driven; it receives a `TvHomeViewModel` or state and does not know about credentials.

## Runtime Flow

1. `app-tv` reads `BuildConfig.SELENE_TV_*`.
2. `TvAppContainer` validates and normalizes local config.
3. If config is complete, it logs in through `SeleneTvAuthApi.login`.
4. `Set-Cookie` is saved into `SessionCookieStore`.
5. `SeleneTvApi.getDashboard()` requests carry Cookie through `AuthInterceptor`.
6. `TvHomeViewModel.load()` renders real backend data or an error state.

## Compatibility

- If `local.gateway.properties` is missing, generated BuildConfig values are empty strings.
- Existing tests can inject fake APIs/repositories without reading local secrets.
- The checked-in example file documents fields but never contains real values.

## Rollback

- Remove `local.gateway.properties` to return to empty-config behavior.
- Revert app container wiring to return static UI state if backend connectivity breaks development.
