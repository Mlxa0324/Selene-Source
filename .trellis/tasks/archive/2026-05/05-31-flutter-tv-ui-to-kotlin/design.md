# Technical Design: Flutter TV UI to Kotlin

## Source of Truth

Flutter TV is the source behavior and visual reference:

- `lib/tv_app/tv_app_shell.dart`
- `lib/tv_app/screens/*.dart`
- `lib/tv_app/widgets/*.dart`
- `lib/tv_app/services/*.dart`
- `test/tv_app/*_test.dart`
- `.trellis/spec/frontend/tv-mode.md`

Kotlin implementation target:

- `re-android/app-tv`
- `re-android/core-design`
- `re-android/core-data`
- `re-android/core-network`
- `re-android/core-player-*`
- `re-android/feature-tv-*`

## Architecture

Keep Kotlin work inside the existing modular Android TV architecture:

- `app-tv`: root application, theme, navigation graph, destination arguments.
- `core-design`: reusable Compose TV primitives, tokens, focus components, design metrics, page scaffolds, cards, rails, grids, dialogs.
- `core-data`: repositories and UI-ready domain models matching Flutter TV data needs.
- `core-network`: remote DTO/API contracts.
- `core-player-*`: player engines and player snapshot behavior.
- `feature-tv-*`: page-specific Compose routes and ViewModels.

This is a parent task. Implementation lives in child tasks; this parent keeps the global mapping and final integration contract.

## Mapping

| Flutter TV | Kotlin Target |
|------------|---------------|
| `TvAppShell` | `app-tv/TvApp.kt`, `TvNavGraph.kt` |
| `TvDesignCanvas` | `core-design/layout/TvDesignMetrics.kt`, `TvDesignPreset.kt` |
| `TvThemeService`, `TvTheme` | `core-design/TvTheme.kt`, `TvTokens.kt`, settings-backed theme state if needed |
| `TvTopNav` | app/root top navigation or shared `core-design` component |
| `TvFocusable`, `TvFocusScroll` | `core-design/focus` and shared focus modifiers |
| `TvHomeScreen`, `TvHomeSection` | `feature-tv-home`, shared rail/grid components |
| `TvVideoLibraryScreen` | feature modules for category/history/favorites lists |
| `TvVideoDetailScreen` | `feature-tv-detail` with repository-backed staged loading |
| `TvFullscreenPlayerScreen` | `feature-tv-player` route and menu |
| `TvSettingsScreen` | `feature-tv-settings` |
| `TvSearchScreen` | `feature-tv-search` |
| `TvLiveScreen` | `feature-tv-live` |
| `TvDanmakuMatchScreen`, overlay | player/detail feature or dedicated feature if module grows |

## Data Flow

- ViewModels expose immutable UI state per page.
- Repositories in `core-data` own network/local preference/cache decisions.
- Compose routes render state and emit events; they should not call Retrofit/Datastore directly.
- Detail loading should preserve Flutter's staged model:
  1. Load exact/initial playable source.
  2. End first-screen loading and allow preview/playback as soon as a source is available.
  3. Continue background source search and merge unique sources.
  4. Load recommendations after current detail is known.

## Focus and Remote Input

- A shared focus abstraction must prevent repeat key events from triggering duplicate click navigation.
- Long press and short press semantics must mirror Flutter `TvFocusable`.
- Lists/rails should remember focus group entries where Flutter does.
- Top navigation must support focus redirection to selected item and right-side shortcut area.

## Compatibility Notes

- Preserve existing Kotlin module boundaries and current user changes.
- Do not delete current repositories/player engines unless replacing them with equivalent behavior.
- Kotlin comments should remain concise Chinese comments per project instruction.
- Compose UI text should match Flutter TV user-facing copy unless product intent says otherwise.

## Validation Strategy

- Unit tests for ViewModels/repositories/focus policy.
- Compose UI tests where module setup already supports Android/instrumented tests.
- Gradle unit test target: `../gradlew testDebugUnitTest` from `re-android/`.
- Lint target: `../gradlew lintDebug` from `re-android/` when environment allows.
- Manual/visual checklist comparing Flutter TV and Kotlin TV page-by-page.

## Rollback

- Keep shared `core-design` additions backward-compatible.
- Each child task should be reversible independently where possible.
- If a route breaks, navigation can be temporarily pointed back to the prior feature route while keeping shared components.
