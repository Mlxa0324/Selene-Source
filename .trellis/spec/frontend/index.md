# Frontend Development Guidelines

> Guidelines for Selene Flutter UI across phone, desktop, and TV modes.

## Overview

Read these files before editing `lib/screens/`, `lib/widgets/`, `lib/tv_app/`, UI-facing helpers, or widget tests. The app uses Flutter with Provider, Material widgets, media playback widgets, and a separate TV UI surface.

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Flutter screen/widget/TV organization | Filled |
| [Component Guidelines](./component-guidelines.md) | Widget patterns, constructor props, composition, interaction | Filled |
| [Hook Guidelines](./hook-guidelines.md) | Flutter equivalents for reusable stateful logic | Filled |
| [State Management](./state-management.md) | Local state, Provider state, persisted state, TV focus state | Filled |
| [Quality Guidelines](./quality-guidelines.md) | Linting, widget tests, review checklist | Filled |
| [Android PIP Controls](./pip-controls.md) | Flutter Android PIP action bridge contract | Filled |
| [Type Safety](./type-safety.md) | Dart model, enum, callback, and JSON type rules | Filled |
| [TV Mode](./tv-mode.md) | TV-specific screens, focus, launch, and validation rules | Filled |

## Pre-Development Checklist

Before changing frontend code:

1. Read the guide matching the layer you will touch.
2. Read [TV Mode](./tv-mode.md) for any Android TV, BlueStacks, focus, remote-control, or TV route change.
3. Search for existing widgets/helpers/tests before adding new abstractions.
4. Keep service/storage/API concerns out of widgets.
5. Add or update focused widget/unit tests for changed behavior.
6. Run `flutter analyze` and relevant `flutter test` targets when feasible.
7. For first-frame, first-playback, scroll jank, focus lag, skeleton loading, or image-loading performance issues, read `.agents/skills/flutter-performance-optimization/` before changing UI behavior.

## Language

Project code comments are commonly Chinese and concise. Trellis spec files are maintained in English so platform agents can consume them consistently.
