# Technical Design

## Scope

Home page and video library/category pages.

## Target Files

- `re-android/feature-tv-home/**`
- `re-android/core-data/**` for missing home/library contracts.
- Shared components only when child 1 exposes them; avoid duplicate UI primitives.

## Data Flow

ViewModel -> repository -> UI state -> Compose route. Routes emit events only.
