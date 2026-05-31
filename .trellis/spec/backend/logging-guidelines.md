# Logging Guidelines

> This project uses lightweight Flutter logging, mostly `debugPrint`, not a structured logging framework.

## Overview

Logs are used for local diagnosis of playback, settings, cache, network, and parsing behavior. Keep logs concise and feature-scoped. Avoid introducing a new logging dependency unless the task explicitly adds a broader diagnostics system.

Existing examples:

- `UserDataService.saveVideoSkipSettings` logs the cached skip-setting key and timing values.
- `UserDataService.getVideoSkipSettings` logs malformed stored skip-setting failures.
- Service and player code use `debugPrint` for recoverable failures and state transitions that help diagnose user reports.

## Log Levels

There is no project-wide level abstraction. Use these practical rules:

- `debugPrint`: normal diagnostic output during development and recoverable runtime failures.
- `assert` or test expectations: invariant checks that should not become user-visible logs.
- User-facing feedback: use UI messages/toasts/dialogs from the screen/widget layer; do not rely on logs for user communication.

## What to Log

- Feature area and operation, for example cache read/write, API request category, playback setting migration, download state transition.
- Enough identifiers to reproduce without exposing secrets: video title/key, source id, status code, cache key version, and exception message.
- Fallback paths that could explain changed behavior, such as legacy preference key fallback or failed JSON parsing.

## What NOT to Log

- Passwords, cookies, complete authorization headers, or saved account secrets.
- Full URLs when they may contain tokens or private proxy parameters.
- Large response bodies, M3U8 playlists, or downloaded media content.
- High-frequency playback position updates unless a task is explicitly debugging playback timing.

## Common Mistakes

- Using `print` instead of `debugPrint` in Flutter code.
- Logging inside tight build, animation, or playback loops.
- Adding logs that expose `SavedUserAccount.password` or `cookies`.
- Leaving temporary noisy logs after a bugfix.
