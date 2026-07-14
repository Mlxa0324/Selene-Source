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

## Scenario: Native Android TV Playback Record Save And Continue-Watching Refresh

### 1. Scope / Trigger

- Trigger: 修改 Kotlin TV 详情页/全屏播放器的续播恢复、播放进度保存、`/api/playrecords` 接线或首页继续观看刷新链路。
- Applies to `re-android/core-network`, `re-android/core-data`, `re-android/app-tv`, `re-android/feature-tv-detail`, `re-android/feature-tv-player`, `re-android/feature-tv-home`.

### 2. Signatures

- API contract: `SeleneTvApi.savePlayRecord(request: TvPlayRecordUpsertRequest)`
- DTOs: `TvPlayRecordUpsertRequest`, `TvPlayRecordUpsertBody`
- Repository boundary: `TvPlaybackRepository.savePlayRecord(video: TvVideoCard)`
- Container save boundary: `TvAppContainer.persistPlaybackProgress(request, positionMs, durationMs)`
- Async exit boundary: `TvAppContainer.persistPlaybackProgressAsync(request, positionMs, durationMs, onFinished)`
- Detail resume resolver: `resolveResumeRecord(entry: TvDetailEntry, cards: List<TvVideoCard>): TvVideoCard?`
- Home partial refresh: `TvHomeViewModel.refreshContinueWatching()`
- Navigation refresh flag: `HOME_CONTINUE_WATCHING_REFRESH_KEY`

### 3. Contracts

- Native TV 保存播放记录时，必须对齐 Flutter `/api/playrecords`：请求体使用 `key + record` 结构，`record` 至少包含 `title / source_name / year / cover / index / total_episodes / play_time / total_time / save_time / search_title`。
- `PlaybackRequest` 必须携带 `sourceName / videoYear / posterUrl / totalEpisodes / searchTitle`，这样详情页预览和全屏播放器都能在不知道额外上下文的情况下直接落续播记录。
- Kotlin TV 续播记录解析顺序固定为：
  1. 精确 `source + id`
  2. 同 `id` 且 `title/searchTitle + year` 命中
  3. 资料源入口（`douban` / `bangumi` / blank）按 `title/searchTitle (+ year)` 命中最新记录
  4. 同 `id` 兜底
- 详情页预览和全屏播放器都按 10 秒分段保存播放进度；同一媒体首次接管只记录当前分段基线，不立即重复保存；如果用户 seek 回更早分段，必须立刻覆盖保存。
- 详情页和全屏播放器退出时必须先退栈，再后台保存播放进度；保存失败不得阻塞退出。
- 从详情页退回首页后，首页只能局部刷新 `continue_watching` 分区，不得先清空整页 `sections`，避免慢接口下列表闪屏。
- 首页局部刷新必须在后台保存流程完成后再触发 `HOME_CONTINUE_WATCHING_REFRESH_KEY`，避免首页重新请求到旧进度。

### 4. Validation & Error Matrix

- `PlaybackRequest` 为空 -> 不保存进度，不报致命错误。
- `positionMs < 10s bucket` -> 不触发周期性保存；退出时仍允许强制保存当前点位。
- 新请求和旧播放器快照媒体身份不一致 -> 不得把旧快照进度写到新请求的续播记录里。
- `/api/playrecords` 保存失败 -> 不阻塞详情/全屏退出；首页保留当前内容，不先清空。
- 首页继续观看刷新失败 -> 保留当前 `sections`，不打断用户浏览其它分区。
- 资料源入口没有精确 `source + id` 命中 -> 允许按标题/搜索标题/年份回源命中最近记录，而不是直接从 0 秒起播。

### 5. Good/Base/Bad Cases

- Good: 从首页继续观看进入资料源详情页，仍能按最近一次保存的集数和时间点续播。
- Good: 从详情页返回首页时页面立即退回，继续观看稍后局部更新，不出现整页空白闪烁。
- Good: 全屏切集时旧播放器快照仍在流里，新的续播保存逻辑不会把上一集进度写到当前集。
- Base: 没有任何续播记录时，详情页和全屏播放器正常从 0 秒起播。
- Bad: 详情页退出前同步等待网络保存，导致返回键发涩或卡住。
- Bad: 首页刷新先执行 `sections = emptyList()`，导致继续观看和热门分区一起闪没再回来。
- Bad: 资料源入口只认精确 `source + id`，导致已有播放记录却始终从第 1 集 0 秒起播。

### 6. Tests Required

- `TvPlaybackRepositoryTest` 覆盖 `/api/playrecords` 保存请求映射。
- `TvDetailViewModelTest` 覆盖预览播放器每 10 秒保存一次进度。
- `TvPlayerViewModelTest` 覆盖全屏播放器每 10 秒保存一次进度，并避免切集交界误存旧快照。
- `TvHomeViewModelTest.refreshContinueWatching_updates_only_continue_section` 覆盖首页局部刷新不清空整页。
- `TvHomeViewModelTest.loadHome_refresh_keeps_existing_sections_until_new_payload_arrives` 覆盖首页刷新不闪屏。
- `TvAppContainerTest.createDetailViewModel_matches_resume_record_by_title_when_route_source_is_metadata_only` 覆盖资料源入口按标题回源命中续播记录。

### 7. Wrong vs Correct

#### Wrong

```kotlin
onExitClick = {
    scope.launch {
        appContainer.persistPlaybackProgress(request, positionMs, durationMs)
        navController.popBackStack()
    }
}
```

#### Correct

```kotlin
onExitClick = {
    val refreshHandle = navController.previousBackStackEntry?.savedStateHandle
    appContainer.persistPlaybackProgressAsync(
        request = request,
        positionMs = positionMs,
        durationMs = durationMs,
        onFinished = {
            refreshHandle?.set(HOME_CONTINUE_WATCHING_REFRESH_KEY, true)
        },
    )
    navController.popBackStack()
}
```

#### Wrong

```kotlin
mutableState.value = mutableState.value.copy(
    isLoading = true,
    sections = emptyList(),
)
```

#### Correct

```kotlin
mutableState.value = mutableState.value.copy(
    isLoading = true,
    errorMessage = null,
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
