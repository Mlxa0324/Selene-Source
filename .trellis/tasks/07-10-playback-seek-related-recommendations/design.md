# Technical Design: Playback Seek and Detail Recommendations

## Decision Summary

This parent task coordinates two independently verifiable Kotlin Android TV changes:

1. tune long-press seek so a 10-second hold travels about 30 minutes with a physical 4-second gear change;
2. make detail recommendations load independently from source discovery and reliably reach the existing recommendation rail.

Implementation belongs to the two child tasks. The parent owns shared constraints, worktree protection, and final integration verification.

## Source of Truth

- Product intent: the user request captured in this task tree.
- Flutter TV behavior:
  - `lib/tv_app/screens/tv_video_detail_screen.dart`;
  - `lib/tv_app/screens/tv_fullscreen_player_screen.dart` and related player controls;
  - `.trellis/spec/frontend/tv-mode.md`.
- Flutter mobile recommendation behavior:
  - `lib/screens/player_screen.dart`;
  - `lib/services/douban_service.dart`.
- Kotlin implementation target:
  - `re-android/feature-tv-player`;
  - `re-android/feature-tv-detail`;
  - `re-android/core-data`;
  - `re-android/core-network`;
  - `re-android/app-tv`.

## Architecture Boundaries

### Seek Child

The player route continues to own key events and the 100ms continuous scheduling loop. `TvSeekController` remains the single owner of step selection and overlay display calculation. Player engines continue receiving absolute `seekTo` targets through `TvPlayerViewModel`.

No player engine, menu, key routing, or playback-speed protocol changes are required.

### Recommendation Child

The detail feature owns recommendation scheduling and stale-result protection. The app container resolves the Douban identity and injects the loader. The data/network layers fetch and parse the Douban subject page. The existing Compose route remains a pure state renderer.

The data flow is:

```text
detail entry/current detail
  -> resolve Douban id
  -> fetch Douban subject HTML
  -> parse recommendation cards
  -> serial-aware ViewModel state update
  -> existing recommendation rail
```

The scheduling flow is independent:

```text
preview PlayerState.Playing
  -> wait 2 seconds
  -> start recommendation job once

terminal no-playback state without a prior start
  -> start recommendation job immediately as fallback
```

## Shared Contracts

- Neither child may block the first playable source or initial playback request.
- Recommendation failure is non-fatal and may only affect recommendation state.
- A new detail load cancels or invalidates the previous recommendation job.
- Seek-forward and seek-backward use symmetric magnitude rules and preserve duration clipping.
- Existing user changes in the dirty worktree are authoritative unless directly contradicted by this task's accepted behavior.
- Kotlin production code and tests follow the project's complete Chinese comment requirements.

## Child Task Order

The children do not depend on one another and may be implemented in either order. To reduce risk in the current dirty worktree, execute them sequentially:

1. `07-10-playback-seek-acceleration` — isolated player constants and tests.
2. `07-10-detail-related-recommendations` — cross-layer detail/data/network changes.

The parent is not an implementation target. It is completed only after both children pass their own checks and the combined Kotlin TV verification passes.

## Compatibility and Rollback

- Seek rollback should first reduce or restore the accelerated step while keeping the accepted four-second boundary; restore the old threshold only if device evidence shows the boundary itself is unsafe.
- Recommendation rollback can disable the new scheduling entry while leaving the existing route and partial data-layer wiring intact.
- No stored data, API payload, database schema, or user preference migration is introduced.
- No new third-party parser dependency is required; the recommendation parser remains a focused Kotlin utility with fixture-backed tests.

## Parent Verification

- Confirm both child task acceptance criteria are satisfied.
- Run focused player, detail, data, and app-container unit tests.
- Run the full `re-android` unit-test suite and lint when feasible.
- Run `git diff --check` and verify only task-related edits are staged later.
- Manually verify on TV/emulator when available:
  - 4-second gear transition and approximately 30-minute travel after 10 seconds;
  - seconds ones digit changes once per second;
  - recommendations appear while background source discovery is still active;
  - returning from fullscreen does not duplicate recommendation requests.
