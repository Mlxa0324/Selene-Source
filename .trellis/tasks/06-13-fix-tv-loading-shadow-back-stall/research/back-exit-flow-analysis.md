# Research: Back/Exit Flow During Player Initialization

- **Query**: How ESC/back key is handled during player initialization in the TV detail page and fullscreen player, and what could cause lag/stall when pressing ESC.
- **Scope**: internal
- **Date**: 2026-06-13

## Findings

### 1. Detail Page Back Handler Chain

#### Entry Point: `TvBackHandler` (widget)

File: `lib/tv_app/widgets/tv_back_handler.dart`

The detail page wraps itself with `TvBackHandler` at line 4205-4206:
```dart
return TvBackHandler(
  onBackPressed: _handleDetailBackPressed,
```

The back key flow through `TvBackHandler` is:
1. `_handleKeyEvent` (line 143) detects ESC/goBack/browserBack via `TvBackIntent.isBackKey`
2. `KeyUpEvent` releases the back key tracking (line 148-150)
3. `KeyRepeatEvent` extends the press state (line 153-155)
4. `KeyDownEvent` (first down only) calls `_dispatchBack()` (line 170)
5. `_dispatchBack()` (line 177) checks `_backDispatchScheduled` lock, then schedules a microtask:
   ```dart
   Future<void>.microtask(() async {
     try {
       if (!mounted) return;
       final handled = await widget.onBackPressed?.call() ?? false;
       if (handled || !mounted) return;
       await Navigator.of(context).maybePop();
     } finally {
       _backDispatchScheduled = false;  // LOCK RELEASE ONLY IN FINALLY
     }
   });
   ```

**Key point**: The `_backDispatchScheduled` flag prevents double-back. It is only released in the `finally` block -- meaning if `onBackPressed` is slow, the user cannot trigger another back attempt.

#### Cross-page back key dedup: `TvBackIntent`

File: `lib/tv_app/widgets/tv_back_handler.dart`, lines 1-89

- Uses a static `Set<LogicalKeyboardKey> _pressedBackKeys` shared across all pages
- `registerBackKeyDown()` (line 43) returns `true` only on the first KeyDown for a given physical press
- A 700ms fallback timer releases the lock even if KeyUp is lost (line 29-30)

#### Detail Page Back Handler: `_handleDetailBackPressed`

File: `lib/tv_app/screens/tv_video_detail_screen.dart`, lines 4085-4110

```dart
Future<bool> _handleDetailBackPressed() async {
    if (_isExitingDetail) {
      return true;                     // Already exiting, consume event
    }
    if (_fullscreenOverlayVisible) {
      _closeFullscreenOverlay();       // Close overlay, don't pop route
      return true;
    }
    if (_consumeFullscreenOverlayBack) {
      _consumeFullscreenOverlayBack = false;
      return true;
    }
    _isExitingDetail = true;           // Set exit flag
    _loadSerial++;                      // Cancel pending async ops
    final controller = _playerController;
    if (controller != null) {
      unawaited(controller.pause());   // Unawaited -- non-blocking
    }
    await _saveProgress(force: true, scene: '详情页返回');  // BLOCKING await
    if (!mounted) {
      return true;
    }
    Navigator.of(context).pop(true);   // Only after save completes
    return true;
}
```

#### Detail Page Global Back Handler: `_handleGlobalBackKeyEvent`

File: `lib/tv_app/screens/tv_video_detail_screen.dart`, lines 4113-4130

This is registered via `HardwareKeyboard.instance.addHandler` (line 815). It serves as a fallback when platform views steal focus away from the Flutter Focus tree. It checks if the current focus is inside the detail page's Focus tree before dispatching -- avoiding duplicate handling alongside `TvBackHandler`.

### 2. Fullscreen Player Back Handler Chain

File: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`

#### Key Event Handling

Two paths for back key:

1. **`_handleKeyEvent`** (line 1340) -- Focus-based, when `_rootFocusNode` has focus:
   - Lines 1362-1365: calls `_handleBackKey()` for ESC/goBack/browserBack

2. **`_handleGlobalKeyEvent`** (line 1401) -- HardwareKeyboard handler, when `_rootFocusNode` does NOT have focus (e.g., platform view stole focus):
   - Lines 1428-1431: calls `_handleBackKey()` for back keys

#### Back Key Logic: `_handleBackKey` (line 1473)

```dart
void _handleBackKey() {
    if (_menuVisible) {
      _hideMenu();           // First press hides menu
      return;
    }
    unawaited(_handleExitWithSave());  // Second press exits
}
```

#### Exit Flow: `_handleExitWithSave` (line 1508)

```dart
Future<void> _handleExitWithSave() async {
    if (!_beginFullscreenExit()) {  // Sets _isExitingFullscreen = true
      return;                       // Prevents re-entry
    }
    final exitRequested = widget.onExitRequested;
    if (exitRequested != null) {
      exitRequested();                         // SYNCHRONOUS close overlay
      _scheduleExitSaveOnce(scene: '全屏返回'); // ASYNC save (unawaited inside)
      return;
    }
    final navigator = Navigator.of(context);
    unawaited(navigator.maybePop());            // ASYNC pop
    _scheduleExitSaveOnce(scene: '全屏返回');    // ASYNC save
}
```

**Key point**: The fullscreen player does NOT await save. It calls `exitRequested()` synchronously (which immediately closes the overlay via `_closeFullscreenOverlay` on the detail page), then schedules save as a fire-and-forget background task.

#### System Back: `_handlePopInvoked` (line 1982)

```dart
void _handlePopInvoked(bool didPop) {
    if (didPop) {
      _isExitingFullscreen = true;
      _scheduleExitSaveOnce(scene: '全屏系统返回');
      return;
    }
    if (!_menuVisible) return;
    _hideMenu();
}
```

### 3. Root Cause of Stall: SYNCHRONOUS `_saveProgress` in Detail Page

The critical difference between the two screens:

| | Detail Page | Fullscreen Player |
|---|---|---|
| Save on exit | **AWAITED** (blocking) | `unawaited` (non-blocking) |
| Pop on exit | After save completes | Before save completes |
| Exit feels fast? | NO -- waits for DB I/O | YES -- immediately exits |

#### The Stall Sequence (Detail Page)

1. User opens detail page, `_playCurrentEpisode()` begins executing
2. If player not yet ready (no resume record, no player kernel config), the call defers (lines 2212-2220)
3. Once prerequisites arrive, `_playCurrentEpisode` runs:
   - Sets `_previewPlayerLoading = true` (line 2237) -- loading shadow visible
   - Awaits `controller.updateDataSource(url, startAt: startAt)` (line 2242)
   - `updateDataSource` may trigger full player initialization (`_initializePlayer`) or adapter replacement, all of which involve async network I/O and `await`
4. **User presses ESC during this loading period**
5. `TvBackHandler._dispatchBack()` calls `_handleDetailBackPressed()`
6. `_handleDetailBackPressed` sets `_isExitingDetail = true` and increments `_loadSerial`
7. `_handleDetailBackPressed` **awaits** `_saveProgress(force: true)`, which calls:
   - `TvPlayRecordService.buildRecord()`
   - `TvPlayRecordService.saveRecordAndCleanupOtherSources()` -- database I/O
8. The loading shadow (`_buildPreviewLoadingOverlay`) keeps spinning because `_previewPlayerLoading` is still `true`
9. UI appears frozen/stalled until the database write completes
10. On low-end TV devices (2G RAM), database I/O can take hundreds of milliseconds or more
11. During this stall:
    - `_backDispatchScheduled` remains `true` -- user cannot press back again
    - The player's `updateDataSource` continues running in the background (its `_playerDisposed` flag is NOT set by the detail page)
    - When `updateDataSource` completes, it checks `_canUseDetailRoute` which returns `false`, so it aborts -- but the player adapter may have already been created/swapped
12. When `dispose()` is eventually called, it calls `_saveProgress` AGAIN (line 854), duplicating work

#### Why the loading shadow persists during stall

File: `lib/tv_app/screens/tv_video_detail_screen.dart`

- `_previewPlayerLoading` is set to `true` in `_markPreviewPlayerLoading()` (line 2013)
- It is only set to `false` in `_finishPreviewPlayerLoading()` (line 2030) or when `_markPreviewPlaybackStarted()` (line 2047) detects actual playback progress
- **Neither** `_handleDetailBackPressed` nor any exit path resets `_previewPlayerLoading`
- The `_buildPreviewLoadingOverlay()` at line 4634 renders a `CircularProgressIndicator` + "加载中" text when `_previewPlayerLoading` is true and controller is loading or playback hasn't started

#### Why `updateDataSource` doesn't abort early

File: `lib/widgets/video_player_widget.dart`

The `_updateDataSource` method (line 1257) has multiple `await` points with `_shouldAbortAsyncAfterAwait()` checks. However, `_shouldAbortAsyncAfterAwait()` (line 1650) only checks:
- `mounted` -- whether the VideoPlayerWidget's State is still mounted
- `_playerDisposed` -- whether the widget has been disposed

The detail page's `_handleDetailBackPressed` does NOT set `_playerDisposed`, and the widget is still mounted (the detail page hasn't popped yet). So the player's internal operations continue running.

#### Disposal duplication

When the detail page finally pops:
- `dispose()` (line 845) sets `_isExitingDetail = true` and calls `unawaited(_saveProgress(force: true, scene: '详情页销毁'))`
- This is in addition to the `_saveProgress` already called and awaited in `_handleDetailBackPressed`
- The player controller's `pause()` is also called again at line 855

### 4. Exit Guard Flags

| Flag | Screen | File:Line | Set By | Purpose |
|---|---|---|---|---|
| `_isExitingDetail` | Detail | tv_video_detail_screen.dart:685 | `_handleDetailBackPressed`, `dispose`, `_openSearch` | Blocks UI updates, source loading, playback |
| `_loadSerial` | Detail | tv_video_detail_screen.dart:721 | `_startDetailLoading`, `_handleDetailBackPressed`, `dispose` | Cancels stale async results |
| `_canUseDetailRoute` (getter) | Detail | tv_video_detail_screen.dart:709 | Computed: `mounted && !_isExitingDetail` | Gate for all UI ops |
| `_isExitingFullscreen` | Fullscreen | tv_fullscreen_player_screen.dart:528 | `_beginFullscreenExit`, `dispose`, `_handlePopInvoked` | Blocks UI callbacks, prevents double-exit |
| `_shouldIgnoreAsyncUiCallback` (getter) | Fullscreen | tv_fullscreen_player_screen.dart:782 | Computed: `!mounted \|\| _isExitingFullscreen` | Gate for all async UI callbacks |
| `_backDispatchScheduled` | TvBackHandler | tv_back_handler.dart:131 | `_dispatchBack` entry | Prevents double-back during same press |
| `_hasScheduledExitSave` | Fullscreen | tv_fullscreen_player_screen.dart:534 | `_scheduleExitSaveOnce` | Prevents duplicate save on exit |

### 5. Code Patterns

**Pattern: Blocking save on exit (detail page -- the problem)**

Lines 4085-4110 in `tv_video_detail_screen.dart`:
```dart
_isExitingDetail = true;
_loadSerial++;
unawaited(controller.pause());
await _saveProgress(force: true, scene: '详情页返回');  // BLOCKS pop
Navigator.of(context).pop(true);
```

**Pattern: Non-blocking save on exit (fullscreen player -- the fix pattern)**

Lines 1508-1521 in `tv_fullscreen_player_screen.dart`:
```dart
_beginFullscreenExit();
exitRequested();                            // Immediate visual feedback
_scheduleExitSaveOnce(scene: '全屏返回');    // Fire-and-forget save
```

### 6. Related Specs

None directly relevant found in `.trellis/spec/`.

## Caveats / Not Found

- The severity of the stall depends on the device's database I/O speed. On high-end devices, `saveRecordAndCleanupOtherSources` may complete fast enough to not be noticeable.
- The `_handleDetailBackPressed` comment at lines 4103-4104 states intent: "真正离开详情页前强制保存当前进度，保持与普通端返回语义一致" -- the blocking save is intentional to ensure progress is saved before leaving, but this trade-off sacrifices exit speed for data safety.
- No explicit "abort in-progress player init" signal is sent from the detail page to the `VideoPlayerWidget`. The player widget has no knowledge of the detail page's `_isExitingDetail` flag.
