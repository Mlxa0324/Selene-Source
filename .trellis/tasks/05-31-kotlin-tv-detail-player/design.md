# Technical Design

## Scope

Detail page, playback entry, fullscreen player shell and player navigation.

## Target Files

- `re-android/feature-tv-detail/**`
- `re-android/feature-tv-player/**`
- `re-android/core-player-*`
- `re-android/core-data/**` for detail/playback repository gaps.

## Data Flow

Detail ViewModel performs staged source loading and emits UI state. Player ViewModel consumes a typed playback request and maintains snapshot state.
