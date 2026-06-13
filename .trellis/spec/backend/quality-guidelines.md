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

## Scenario: Native Android TV Local Gateway Config

### 1. Scope / Trigger

- Trigger: native Android TV code reads local secret/env-style config and passes it into app, data, or feature UI layers.
- Applies to `re-android/local.gateway.properties`, Gradle `BuildConfig` fields, `TvAppContainer`, and settings/home feature ViewModels.

### 2. Signatures

- Gradle loader: `loadLocalGatewayProperties(): Properties`
- Config factory: `TvLocalGatewayConfig.fromBuildConfig(): TvLocalGatewayConfig`
- Container factory: `TvAppContainer.createSettingsViewModel(): TvSettingsViewModel`
- Feature state injection: `TvSettingsViewModel(initialState: TvSettingsUiState = TvSettingsUiState())`
- URL normalization: `SeleneTvNetworkFactory.normalizeBaseUrl(rawBaseUrl: String): String`
- Login boundary: `SeleneTvNetworkClient.login(username: String, password: String): SessionPayload`
- Home aggregation: `TvHomeRepository.loadHome(): TvHomePayload`

### 3. Contracts

- `SELENE_TV_BASE_URL`: optional string; empty means no local gateway is configured.
- `SELENE_TV_USERNAME`: optional string; empty means login cannot be auto-attempted.
- `SELENE_TV_PASSWORD`: optional string; empty means login cannot be auto-attempted.
- `TvLocalGatewayConfig.isComplete` is true only when all three fields are non-blank.
- Settings UI must receive the same local gateway values that home/login uses; do not let route defaults hide populated BuildConfig values.
- `normalizeBaseUrl` must trim input, add `http://` when the scheme is missing, and append one trailing `/` for Retrofit.
- Login failures that surface to the home screen must preserve actionable diagnostics, including HTTP status, HTML/PassNAT error pages, and the OkHttp failed connection target when it differs from the configured host.
- `TvHomeRepository.loadHome` should treat continue-watching, dashboard, and fallback category failures independently where possible so one empty/failing section does not blank the whole home page.

### 4. Validation & Error Matrix

- Missing file -> BuildConfig fields are empty -> home shows the existing local config missing error.
- Partial file -> `isComplete == false` -> gateway client is not created.
- Complete file -> settings state shows address, account, and password; home login uses the same values.
- Missing scheme in URL -> normalize to `http://<host>/` before creating Retrofit.
- 401 from `/api/login` -> show account/password error and keep server configuration recoverable.
- Non-2xx HTML response from `/api/login` -> show that the configured address returned a web page instead of Selene API JSON.
- PassNAT node page from `/api/login` -> tell the user the tunnel/domain did not hit the Selene backend service.
- `IOException("Failed to connect to /<ip>:<port>")` while configured host is a domain -> show both the configured domain and the actual failed target so DNS, tunnel, or redirect issues are distinguishable from stale APK config.
- Dashboard unavailable -> keep continue-watching and fall back to category search sections.
- One fallback category unavailable -> render the other fallback sections instead of failing the whole home payload.

### 5. Good/Base/Bad Cases

- Good: `TvNavGraph` obtains settings state from `TvAppContainer.createSettingsViewModel()`.
- Good: `http://ivy3004.s.odn.cc` failing with `Failed to connect to /192.168.31.28:9000` renders a message that names both addresses and points to DNS/tunnel/redirect checks.
- Good: a failed continue-watching request returns an empty continue-watching section while dashboard sections still render.
- Base: feature tests can instantiate `TvSettingsViewModel()` with default empty state.
- Bad: `TvSettingsRoute()` is called with `TvSettingsUiState()` in app navigation while BuildConfig contains populated values.
- Bad: wrapping every login failure as "cannot connect backend" without distinguishing 401, HTML/PassNAT pages, or actual failed connection target.
- Bad: a single fallback category exception prevents all other home fallback sections from rendering.

### 6. Tests Required

- App container test asserts complete local gateway config pre-fills settings state.
- Feature ViewModel test asserts constructor-injected initial state is exposed unchanged.
- Existing missing-config home test must continue to assert the local config error path.
- Core network tests assert URL normalization, 401 handling, HTML/PassNAT login failures, and resolved-target connection diagnostics.
- Core data tests assert dashboard fallback, continue-watching failure isolation, and per-category fallback failure isolation.

### 7. Wrong vs Correct

#### Wrong

```kotlin
composable(TvDestination.Settings.route) {
    TvSettingsRoute()
}
```

#### Correct

```kotlin
composable(TvDestination.Settings.route) {
    val settingsViewModel = remember(appContainer) {
        appContainer.createSettingsViewModel()
    }
    val settingsState by settingsViewModel.state.collectAsState()
    TvSettingsRoute(state = settingsState)
}
```

#### Wrong

```kotlin
throw IllegalStateException("无法连接后台服务")
```

#### Correct

```kotlin
throw IllegalStateException(
    "无法连接后台服务：$baseUrl。原因：$reason。" +
        "当前请求实际连接到 $failedTarget，请检查域名解析、穿透或重定向。"
)
```

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
