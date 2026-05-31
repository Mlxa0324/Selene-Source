# Implementation Plan

- [x] Add ignored local gateway config pattern and tracked example file.
- [x] Make `app-tv` Gradle read `re-android/local.gateway.properties` into `BuildConfig`.
- [x] Add network auth request/response contracts and Retrofit factory in `core-network`.
- [x] Add tests for baseUrl normalization, missing config, Cookie parsing, and login session save.
- [x] Add `app-tv` container wiring from BuildConfig to `TvHomeRepository` and `TvHomeViewModel`.
- [x] Update `TvHomeRoute` integration so app home loads real backend data.
- [x] Run focused tests for `core-network`, `core-data`, `feature-tv-home`, and `app-tv`.
- [x] Run lint/build verification for touched modules.
- [x] Confirm real local config remains untracked before commit.
