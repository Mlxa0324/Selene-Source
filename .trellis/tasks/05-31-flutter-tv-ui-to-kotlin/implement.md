# Implementation Plan

Scope decision: this is a parent/integration task with four child implementation tasks. Do not implement broad code directly in the parent unless resolving final integration drift.

## Child Task Map

- [ ] `05-31-kotlin-tv-design-shell`: shared design system, root shell, navigation and focus base.
- [ ] `05-31-kotlin-tv-home-library`: home page and video library/category pages.
- [ ] `05-31-kotlin-tv-detail-player`: detail page and fullscreen player.
- [ ] `05-31-kotlin-tv-pages-acceptance`: remaining pages, danmaku landing point and final acceptance.

## Parent Phase 0: Baseline and Protection

- [ ] Record current dirty files before editing and identify unrelated user changes.
- [ ] Build an inventory comparing Flutter TV screens/widgets/services/tests to Kotlin modules/routes/components/tests.
- [ ] Search for user-facing placeholder/bone text in `re-android/` and convert it into a gap list.
- [ ] Run current Kotlin unit tests if feasible to capture baseline failures before changes.

## Child 1: Shared Design System

- [ ] Complete through `05-31-kotlin-tv-design-shell`.

## Child 2: Home and Library

- [ ] Complete through `05-31-kotlin-tv-home-library`.

## Child 3: Detail and Player

- [ ] Complete through `05-31-kotlin-tv-detail-player`.

## Child 4: Remaining Pages and Acceptance

- [ ] Complete through `05-31-kotlin-tv-pages-acceptance`.

## Parent Final Verification

- [ ] Remove final-user placeholder texts.
- [ ] Verify every Flutter TV screen/widget/service counterpart listed in `prd.md` has a Kotlin landing point or an explicitly documented Kotlin equivalent.
- [ ] Run targeted Kotlin tests for changed modules.
- [ ] Run `../gradlew testDebugUnitTest` from `re-android/` if feasible.
- [ ] Run `../gradlew lintDebug` from `re-android/` if feasible.
- [ ] Update Trellis spec if new Kotlin TV conventions emerge.
- [ ] Prepare commit with only task-related files.

## Validation Commands

```bash
cd re-android && ../gradlew testDebugUnitTest
cd re-android && ../gradlew lintDebug
cd re-android && ../gradlew :feature-tv-player:connectedDebugAndroidTest
```

Use connected Android tests only when a TV/emulator target is available.

## Risky Areas

- Existing dirty `re-android/` files may contain user work; do not overwrite without reading.
- Player route and engine switching can break playback state restoration.
- Focus behavior can regress navigation by triggering duplicate pushes or trapping focus.
- Compose TV APIs and AndroidX TV Material versions may constrain component choices.
