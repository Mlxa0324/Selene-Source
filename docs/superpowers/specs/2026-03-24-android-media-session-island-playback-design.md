# Android Media Session Island Playback Design

## Background

Selene currently uses a WebView-based playback path for most mobile online streams. That path can keep video rendering inside the Flutter page, but it does not expose Android system media primitives such as media sessions, lock-screen transport controls, media-style notifications, or vendor media capsules.

The product goal is Android-only screen-off playback that can:

- keep audio playing after screen-off and on the lock screen
- show standard system media controls
- surface automatically in Xiaomi HyperOS media island / capsule when supported
- reuse the same standard Android media session path for other Android vendors such as Huawei, OPPO, vivo, and iQOO
- keep PiP as an optional parallel mode rather than a requirement

## Findings

### Current project state

- Mobile online playback still prefers the WebView player path for many streams.
- Android native code currently contains PiP actions and a download foreground service, but no media playback foreground service.
- The app already includes `media_kit` and Android video libraries, so we have a viable non-WebView player core to build on.

### Platform capability

- Android officially supports background playback through a `MediaSessionService` / media session + foreground media playback service model.
- Xiaomi HyperOS documentation states that after integrating media notification capability, media playback can surface automatically in the island-style system UI.
- I did not find a vendor-specific public SDK requirement for Huawei / OPPO / vivo / iQOO during this pass. The safest portable assumption is that those systems will consume standard Android media sessions and media notifications when they choose to expose an island / capsule / live card surface.

## Product Scope

### In scope

- Android phones and tablets only
- App setting switch in application settings
- Screen-off playback via native player path
- Lock-screen continuation and media notification controls
- Optional coexistence with PiP when the user explicitly enters PiP
- Metadata sync for title, poster, progress, play/pause, previous, next

### Out of scope

- iOS lock-screen or Dynamic Island
- Vendor-private visual enhancements beyond standard Android media sessions
- Full migration of every playback scenario away from WebView
- Download/offline playback redesign

## Recommended Approach

### Option A: Stay on WebView and attempt background audio workarounds

Pros:

- smallest short-term diff in Flutter UI

Cons:

- unreliable for lock-screen audio
- no real Android media session ownership
- poor compatibility with media notification / vendor island surfaces

This is not recommended.

### Option B: Android-only switch to native playback + media session bridge

Pros:

- aligns with Android system architecture
- unlocks lock-screen controls and vendor media surfaces
- contains platform-specific risk to Android

Cons:

- requires native Android service work
- requires a second playback path for eligible Android streams

This is the recommended approach.

### Option C: Full mobile playback migration to native player on both Android and iOS

Pros:

- long-term consistency

Cons:

- much larger blast radius
- not required for the current Android-only goal

This is intentionally deferred.

## Architecture

### Playback routing

When Android screen-off playback is disabled, keep the current routing behavior.

When Android screen-off playback is enabled and the stream URL is compatible with native playback:

1. route playback through the native player-backed path instead of WebView
2. start or attach to an Android media playback service
3. publish playback state and metadata to the service-backed media session

If a URL is not compatible with native playback, stay on the existing fallback path and do not promise island behavior for that source.

### Android native media layer

Introduce an Android media playback service with these responsibilities:

- own the foreground service lifecycle for active audio playback
- expose a media session for system controls
- publish media notification state
- reflect play/pause/seek/next/previous to Flutter
- continue playback when the app UI backgrounds or the screen turns off

Initial implementation direction:

- Android foreground service type `mediaPlayback`
- `MediaSessionCompat` + `MediaStyle` notification for system media exposure
- keep the real player in Flutter / `media_kit`, with metadata and actions bridged to Android

Future enhancement path:

- if we later migrate more playback ownership into native Android, we can move this service toward AndroidX Media3

### Flutter bridge

Flutter remains the source of episode lists, source switching, danmaku state, and page UI.

Bridge responsibilities:

- send current media metadata to Android service
- send playback commands when the user acts in Flutter
- receive service-originated commands from notification / lock screen / Bluetooth / island surface
- keep PiP action handling and media session action handling from conflicting

## Interaction Rules

### Screen-off playback enabled, no PiP

- screen turns off
- audio keeps playing
- lock screen and system media notification remain active
- vendor island surface may appear automatically if the system supports it

### Screen-off playback enabled, user enters PiP

- PiP remains visible
- audio continues
- media session remains active in parallel

### Screen-off playback disabled

- preserve current behavior
- no forced media service startup

## Compatibility Strategy

### Xiaomi

Primary target for island behavior. Standard media notification + media session is required.

### Huawei / OPPO / vivo / iQOO

Treat these as standard Android media-session consumers first.

Implementation stance:

- support them through the same media session and media notification stack
- do not add vendor-private code unless we later verify a public requirement
- validate behavior on real devices where possible

This is an inference from available platform documentation and Android system behavior, not a confirmed guarantee from each vendor.

## Error Handling and Fallbacks

- If Android media service initialization fails, keep playback inside the page and log the failure.
- If a source URL cannot be handled by the native player, fall back to current playback path and suppress the “screen-off playback supported” promise for that session.
- If notification permission is denied on Android 13+, continue best-effort playback but warn that lock-screen / island exposure may be degraded.

## Testing Strategy

### Dart / Flutter tests

- backend routing rules when screen-off playback is enabled
- metadata mapping sent to Android bridge
- app setting persistence and UI visibility

### Android tests

- service command mapping
- media session action dispatch
- notification state updates

### Manual verification

- Android device screen-off audio continuation
- lock-screen play/pause/next/previous
- PiP + audio coexistence
- Xiaomi HyperOS island appearance
- non-Xiaomi vendor smoke checks

## Risks

- Some online sources may still require WebView fallback and therefore not support island behavior.
- Vendor island surfaces are system-controlled; we can feed the standard media stack, but we cannot force a vendor UI to appear.
- Keeping PiP and media session in sync introduces action-routing complexity.

## Success Criteria

- Android app setting toggles screen-off playback behavior
- eligible Android streams switch to native playback when enabled
- screen-off and lock-screen audio continue without manual PiP entry
- media notification controls work
- Xiaomi devices can surface media playback in the vendor island UI when the system supports it
- no regression to existing Android PiP behavior for users who choose PiP
