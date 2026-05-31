# Technical Design

## Scope

Shared TV UI primitives and app shell/navigation only.

## Target Files

- `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/**`
- `re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/**`
- Matching unit/UI tests under affected modules.

## Notes

- Keep components generic and page-agnostic.
- Keep comments concise Chinese where code needs comments.
- Preserve existing APIs where later child tasks already depend on them.
