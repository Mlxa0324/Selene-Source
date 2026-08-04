# Flutter Android PIP Controls

## 1. Scope / Trigger

This contract applies when changing Android PIP actions in `lib/widgets/video_player_widget.dart`, `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`, or `PipActionReceiver.kt`. It does not apply to `re-android`, `kotlin-tv`, iOS PIP, or the `pip` pub-cache source.

## 2. Signatures

The Flutter-to-host method channel is `org.moontechlab.selene/pip_controls`:

```text
updatePipActions({
  isPlaying: bool,
  hasPrevious: bool,
  hasNext: bool,
})
```

The host-to-Flutter action method is `onPipAction({action: String})`. The stable action values are `previous`, `toggle_play_pause`, and `next`.

## 3. Contracts

- Flutter is the source of truth for playback state and episode boundaries.
- Every Flutter `pip.setup()` completion must be followed by an action-state write through the same serialized queue.
- After `pip.start()` returns successfully, the host must restore the current `RemoteAction` list because `pip:0.0.3` enters PIP with a builder that does not include custom actions.
- `MainActivity` only maps system actions and forwards them; episode switching and play/pause remain Flutter business callbacks.
- `PipActionReceiver` logs and drops empty actions. Missing Activity handler or Flutter channel is a safe, logged drop.
- The Flutter PIP action channel must be bound when an Android `VideoPlayerWidget` with `enablePip` is initialized, even when `url` is null. The main player can inject media later through `VideoPlayerWidgetController.updateDataSource()`.

## 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| Android API below 26 | Skip custom PIP actions without throwing. |
| No previous/next episode | Omit only the unavailable action. |
| PIP plugin setup completes | Write the current action snapshot after setup. |
| PIP start succeeds | Restore the current actions after entering PIP. |
| Receiver has an empty action | Drop and log; do not dispatch to Flutter. |
| Activity/channel/handler is unavailable | Drop and log; do not crash. |
| Player is disposed before queued sync | Drop the stale sync. |
| Player URL is injected after widget initialization | Keep the PIP channel bound; do not wait for a widget URL change. |

## 5. Good / Base / Bad Cases

- Good: configure PIP, write actions, enter PIP, then write actions again; Flutter confirms play/pause state after the adapter changes.
- Base: a previous/next action is rendered only when the current widget episode state allows it.
- Bad: bind the PIP channel only inside the first non-null URL branch; the main player can then render actions whose callbacks have no Dart handler.
- Bad: call `pip.setup()` and `updatePipActions` through independent `unawaited` operations, or flip playback state in Kotlin before Flutter confirms it.

## 6. Tests Required

- Unit tests must cover first, middle, and last episode action visibility.
- Unit tests must cover PIP bridge eligibility before the first media URL is attached and preserve `enablePip: false` for TV playback.
- Unit tests must prove queued PIP writes remain ordered when an older operation is still awaiting.
- Flutter analysis must cover the changed widget and PIP tests.
- The Android app Debug APK must compile the host bridge.
- A real Android PIP device test must verify action visibility, callback execution, episode switching, play/pause state refresh, and exit/re-entry. Dart tests do not replace this system test.

## 7. Wrong vs Correct

Wrong:

```dart
unawaited(pip.setup(options));
unawaited(channel.invokeMethod('updatePipActions', state));
```

Correct:

```dart
await pipSyncQueue.enqueue(() async {
  await pip.setup(options);
  await channel.invokeMethod('updatePipActions', currentState);
});
```

For the player lifecycle, bind the action receiver independently from media URL setup:

```dart
if (Platform.isAndroid && widget.enablePip) {
  _registerPipObserver();
  _bindPipControlChannel();
}
```
