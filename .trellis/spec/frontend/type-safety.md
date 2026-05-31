# Type Safety

> Use Dart's type system directly: typed models, nullable fields where data can be absent, and explicit JSON conversion.

## Overview

Selene is a Dart 3 / Flutter project with `flutter_lints`. Types are organized as concrete model classes in `lib/models/`, enums near the domain they describe, and typed service responses. The project does not use generated serializers or runtime validation libraries.

Existing examples:

- `lib/models/search_result.dart` defines `SearchResult`, search event enums, event classes, and JSON parsing.
- `lib/models/playback_preload.dart` defines playback preload levels used by `UserDataService`.
- `lib/widgets/player_settings_panel.dart` defines `VideoFitType` and `ProgressDisplayMode` for UI selections.
- `lib/services/api_service.dart` wraps remote results in `ApiResponse<T>`.

## Type Organization

- Shared data shapes belong in `lib/models/`.
- UI-only enums can live beside the widget if they are not reused elsewhere.
- Service result wrappers belong next to the service when they are service-specific.
- Prefer domain models over `Map<String, dynamic>` in widget props.
- Use nullable fields for inconsistent external API data, and normalize missing strings/lists in `fromJson` when the UI expects defaults.

## Validation

Runtime validation is manual:

- `fromJson` should default missing strings to `''` only when that is the existing UI expectation.
- List fields should default to empty lists when the UI can render no items.
- Throw for unknown event/command kinds when there is no safe fallback, as `SearchEvent.fromJson` does.
- Parse numbers defensively when API data may arrive as `num`.

## Common Patterns

- `factory Model.fromJson(Map<String, dynamic> json)` for parsing.
- `Map<String, dynamic> toJson()` for persisted or outbound models.
- `copyWith` for immutable settings/account-like objects.
- `enum` for closed option sets.
- `ApiResponse<T>` for typed API success/error results.

## Forbidden Patterns

- Passing raw JSON maps through UI layers.
- Using `dynamic` beyond the parsing boundary when a model can represent the data.
- Adding unchecked casts from external API payloads in widgets.
- Replacing typed callbacks with loosely typed `Function` when `ValueChanged<T>` or `VoidCallback` is enough.
