# Backend Development Guidelines

> Guidelines for Selene service, data, cache, network, storage, and platform-integration code.

## Overview

Selene is a Flutter client app, so "backend" in this spec means the app's business/data layer rather than a server-side package. Read these files before editing `lib/services/`, `lib/models/`, `lib/utils/`, platform integration code, or the native `re-android/` modules.

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Service/data module organization and file layout | Filled |
| [Database Guidelines](./database-guidelines.md) | Local persistence, cache, key migration, and storage rules | Filled |
| [Error Handling](./error-handling.md) | API result wrappers, parsing failures, and recovery behavior | Filled |
| [Quality Guidelines](./quality-guidelines.md) | Lint, tests, compatibility, and review checklist | Filled |
| [Logging Guidelines](./logging-guidelines.md) | `debugPrint` conventions and sensitive-data rules | Filled |

## Pre-Development Checklist

Before changing backend-like code:

1. Read the guide matching the layer you will touch.
2. Search for existing services, models, keys, and tests before adding new ones.
3. Check `CLAUDE.md` and relevant module docs when touching established modules.
4. Add or update focused tests for changed service/model/cache behavior.
5. Run `flutter analyze` and relevant `flutter test` targets when feasible.

## Language

Project code comments are commonly Chinese and concise. Trellis spec files are maintained in English so platform agents can consume them consistently.
