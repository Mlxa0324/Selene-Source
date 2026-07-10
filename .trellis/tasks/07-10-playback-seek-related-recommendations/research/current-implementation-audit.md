# Current Implementation Audit

## Scope

This audit covers the Kotlin native Android TV implementation under `re-android/` and compares it with the established Flutter TV/mobile behavior requested by the user.

## Seek Findings

- `re-android/feature-tv-player/.../TvPlayerRoute.kt` starts with a 10-second seek, waits 250ms, and then emits one seek tick every 100ms.
- `re-android/feature-tv-player/.../TvSeekController.kt` currently returns:
  - 10 seconds before the long-press threshold;
  - 12 seconds per tick in the first continuous stage;
  - 18 seconds per tick after a 5-second acceleration threshold.
- The center overlay deliberately derives the seconds ones digit from physical hold time while the second tens/minute digits follow the real seek target. This already matches the user's requested display rhythm and should be preserved.
- Existing tests verify only individual 10/12/18-second step values. They do not verify the physical 4-second gear boundary or the cumulative 10-second travel distance.

## Recommendation Findings

- `re-android/feature-tv-detail/.../TvDetailRoute.kt` already renders a horizontal recommendation rail when `recommendCards` is non-empty.
- `re-android/feature-tv-detail/.../TvDetailViewModel.kt` currently invokes `loadRecommends` only after:
  1. resume state is ready;
  2. exact source loading completes;
  3. title/SSE fallback loading completes;
  4. favorite state completes.
- The title fallback can remain active for a long time. Therefore the recommendation request may never start while the page is otherwise playable.
- Recommendation exceptions are collapsed to an empty list with `getOrDefault(emptyList())`. The UI then hides the entire rail, making request failures and parser failures indistinguishable from a legitimate empty result.
- The dirty worktree already contains partial recommendation wiring in:
  - `TvAppContainer.kt`;
  - `TvDetailViewModel.kt`;
  - `DoubanRepository.kt`;
  - the untracked `DoubanDetailsParser.kt` and `SeleneDoubanHtmlApi.kt`.
- These changes compile and the current focused unit-test baseline passes, but no test covers recommendation scheduling, HTML parsing, or stale result isolation.

## Flutter Reference Behavior

- `lib/tv_app/screens/tv_video_detail_screen.dart` schedules recommendation loading two seconds after preview playback has actually started.
- The Flutter recommendation task is independent from background source completion.
- If the detail has no playable source, Flutter retains a force-load path for recommendations.
- `lib/screens/player_screen.dart` and `lib/services/douban_service.dart` obtain recommendation cards from the Douban subject details response and keep failures non-fatal to playback.

## Baseline Verification

Executed on 2026-07-10:

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  :feature-tv-detail:testDebugUnitTest \
  :core-data:testDebugUnitTest \
  :app-tv:testDebugUnitTest
```

Result: `BUILD SUCCESSFUL`.

## Design Consequences

- Keep the existing seek scheduler and overlay digit model; change only the stage boundary, accelerated step, and focused tests.
- Move recommendation loading into a serial-aware independent job triggered by preview playback, with a no-playback fallback after source loading settles.
- Make the HTML fetch boundary injectable so parsing and repository behavior can be tested without live Douban access.
- Preserve all unrelated dirty worktree changes and build on the current partial recommendation implementation instead of replacing it wholesale.
