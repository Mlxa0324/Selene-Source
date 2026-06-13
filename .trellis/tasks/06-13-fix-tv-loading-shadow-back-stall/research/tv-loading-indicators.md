# Research: TV Loading Spinner/Indicator Code

- **Query**: Find loading spinner, CircularProgressIndicator, shadow, dark background Container near loading indicators in TV screens and widgets
- **Scope**: internal
- **Date**: 2026-06-13

## Findings

### 1. Detail Screen: `_buildPreviewLoadingOverlay()` (primary loading overlay)

**File**: `lib/tv_app/screens/tv_video_detail_screen.dart`, lines 4634-4694

**Widget structure** (outer to inner):

```
Positioned.fill
  IgnorePointer
    Container (key: 'tv-detail-preview-loading')
      -- NO decoration, NO background color (fully transparent)
      Center
        Column (mainAxisSize: min)
          SizedBox.square(dimension: 36)
            Stack (clipBehavior: Clip.none, alignment: center)
              Positioned.fill
                Transform.translate(offset: Offset(0, 2))
                  CircularProgressIndicator(color: Colors.black.withValues(alpha: 0.42), strokeWidth: 3)
                    -- This is the "shadow" spinner, offset by 2px downward
              Positioned.fill
                CircularProgressIndicator(color: TvTheme.accent, strokeWidth: 3)
                  -- This is the visible foreground spinner
          SizedBox(height: 12)
          Text (networkSpeedText)
            style: FontUtils.poppins(fontSize: 14, fontWeight: w600, color: Colors.white.withValues(alpha: 0.92))
            .copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 2, offset: Offset(0, 2))])
```

**Key observation**: The `Container` wrapping everything has NO background decoration. It is completely transparent. The dark backdrop effect depends on whatever is beneath it in the Stack (either the video player rendering black frames, or the `ColoredBox(color: Colors.black)` when the fullscreen overlay is active).

#### Where it sits in the layout

**File**: lines 4448-4464, inside `_buildPlayerBox()`:

```
ClipRRect(borderRadius: 8)
  Stack
    Positioned.fill:
      if fullscreen overlay visible: ColoredBox(color: Colors.black)
      else: _buildSharedPlayer(detail)
    if (_shouldShowPreviewLoadingOverlay): _buildPreviewLoadingOverlay()
    if (playback started): _buildDetailProgressBar()
```

#### Visibility condition: `_shouldShowPreviewLoadingOverlay` (lines 4614-4631)

Returns `true` when:
- Fullscreen overlay is NOT visible AND detail is NOT null AND
  - Controller is null AND `_previewPlayerLoading` is true (initial black-screen phase before controller arrives), OR
  - `_previewPlayerLoading` is true AND (has pending playback dispatch OR loading), OR
  - Playback has NOT started AND controller says it's loading

### 2. Detail Screen: Initial Page Loading Spinner

**File**: `lib/tv_app/screens/tv_video_detail_screen.dart`, lines 4227-4233

```dart
child: _isInitialDetailLoading && _currentDetail == null
    ? Center(
        child: CircularProgressIndicator(
          color: TvTheme.of(context).accent,
        ),
      )
    : SingleChildScrollView(...)
```

Simple spinner with NO wrapper Container, no shadow, no dark background. Just a plain `Center` + `CircularProgressIndicator` inside the Expanded area of the page body.

### 3. Fullscreen Player Screen: `_buildFullscreenLoadingOverlay()` (primary loading overlay)

**File**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`, lines 3499-3574

**Widget structure** (outer to inner):

```
Center
  IgnorePointer
    Container (key: 'tv-fullscreen-loading')
      -- NO decoration, NO background color (fully transparent)
      Column (mainAxisSize: min)
        SizedBox.square(dimension: 36)
          Stack (clipBehavior: Clip.none, alignment: center)
            Positioned.fill
              Transform.translate(offset: Offset(0, 2))
                CircularProgressIndicator(color: Colors.black.withValues(alpha: 0.42), strokeWidth: 3)
                  -- "shadow" spinner, offset 2px down
            Positioned.fill
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                -- foreground spinner (white, NOT accent like detail screen)
        SizedBox(height: 12)
        Text ("加载中")
          style: FontUtils.poppins(fontSize: 15, fontWeight: w600, color: Colors.white.withValues(alpha: 0.94))
          .copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 2, offset: Offset(0, 2))])
        SizedBox(height: 4)
        Text (networkSpeedText)
          style: FontUtils.poppins(fontSize: 13, fontWeight: w500, color: Colors.white.withValues(alpha: 0.72))
          .copyWith(shadows: [Shadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 2, offset: Offset(0, 2))])
```

**Key observation**: Same as detail screen -- the `Container` has NO background. It relies on the `Scaffold(backgroundColor: Colors.black)` at line 3422 providing the dark backdrop. Note the spinner color is `Colors.white` here (not accent).

#### Where it sits in the layout

**File**: lines 3420-3449:

```
Scaffold(backgroundColor: Colors.black)
  Stack
    Positioned.fill: _buildPlayer()
    if danmaku: TvDanmakuOverlay
    if chrome visible: Positioned.fill + _buildPlaybackChromeScrim()
    if chrome visible: _buildTopDecorations()
    if chrome visible: _buildCenterPlayButton()
    if chrome visible: _buildBottomProgressBar()
    if (_isPlaybackLoading): _buildFullscreenLoadingOverlay()  <-- HERE
    if seek overlay: _buildSeekOverlay()
    if menu: _buildBottomMenu()
```

#### Visibility condition: `_isPlaybackLoading` (lines 1808-1828)

Returns `true` when:
- `_fullscreenPlayerLoading` flag is true, OR
- `_fullscreenPlaybackStarted` is false AND `controller.isLoading` is true

The `_fullscreenPlayerLoading` flag has special recovery logic:
- Set to true at: initial load (line 809), seek operations (line 1279), resume playback (line 1175)
- Cleared by: `_finishFullscreenPlayerLoading()` (line 1288) which also cancels the recovery timer
- Recovery timer `_scheduleSeekRecoveryNativeStateCheck()` (line 1299): fires after 800ms to check if native player recovered from loading state. If controller says not loading and is playing, it auto-clears the loading flag.

### 4. Playback Chrome Scrim (NOT a loading element, but adjacent)

**File**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`, lines 3605-3621

```dart
Widget _buildPlaybackChromeScrim() {
  return IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.34),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.18, 0.72, 1.0],
        ),
      ),
    ),
  );
}
```

This is the dimming overlay for the playback UI chrome (top bar, bottom bar). It uses a gradient from semi-transparent black at top/bottom to transparent in the middle. This is NOT a loading element; it appears when playback chrome is visible.

### 5. Shared TV Loading Skeleton Widgets (no spinner indicators)

**File**: `lib/tv_app/widgets/tv_video_card.dart`, class `TvCoverLoadingSkeleton` (lines 919+)

A shimmer animation skeleton for cover image placeholder. Uses:
- `DecoratedBox` with `LinearGradient` (colors: `0xFF20282B` to `0xFF14191B`) as background
- `AnimatedBuilder` with `Transform.translate` for shimmer sweep effect
- Another `DecoratedBox` with a different `LinearGradient` for the shimmer highlight
- No CircularProgressIndicator, no shadow Container near spinner

**File**: `lib/tv_app/widgets/tv_video_grid.dart`:
- `_buildLoadingGrid()` (line 560): Grey `cardSurface` placeholder `Container` with border (no spinner)
- `_buildLoadingMore()` (line 710): Simple 18x18 `CircularProgressIndicator(strokeWidth: 2, color: Colors.white)` + "Load more" text -- no shadow Container

**File**: `lib/tv_app/widgets/tv_home_section.dart`:
- `_buildLoadingPlaceholder()` (line 510): Grey `cardSurface` placeholder `Container` with border (no spinner)

### 6. BoxShadow Usage in Detail Screen (non-loading context)

**File**: `lib/tv_app/screens/tv_video_detail_screen.dart`, lines 4584-4591

Used on the progress bar time-dot knob:
```dart
Container(
  decoration: BoxDecoration(
    color: palette.accent,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  ),
);
```

**File**: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`, lines 3891-3897

Same pattern on the fullscreen progress bar knob:
```dart
boxShadow: [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.28),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
],
```

## Summary

| Location | Widget | Has Dark Container? | Container Background |
|---|---|---|---|
| Detail screen preview | `_buildPreviewLoadingOverlay()` | No | Transparent (relies on player black underneath) |
| Detail screen initial load | `Center + CircularProgressIndicator` | No | Transparent (inside column body) |
| Fullscreen player | `_buildFullscreenLoadingOverlay()` | No | Transparent (relies on Scaffold black background) |
| Chrome scrim | `_buildPlaybackChromeScrim()` | Yes | LinearGradient (top/bottom dimming, not loading) |
| Cover skeleton | `TvCoverLoadingSkeleton` | Yes | LinearGradient dark grey (shimmer animation, not loading spinner) |
| Video grid "load more" | `CircularProgressIndicator` in Row | No | No container at all |

## Caveats / Not Found

- There is **no shared TV loading spinner widget** in `lib/tv_app/widgets/`. Both screens independently implement their own loading overlay method (`_buildPreviewLoadingOverlay` and `_buildFullscreenLoadingOverlay`), though with nearly identical structure.
- Neither loading overlay has a dark/solid background `Container` or `DecoratedBox`. They rely entirely on the video player rendering black frames or the `Scaffold` background providing the dark backdrop to ensure the white/colored spinner text is visible.
- The "shadow" on the spinner is achieved by a second offset `CircularProgressIndicator` (not a `BoxShadow` decoration), while text shadows use the `TextStyle.copyWith(shadows: ...)` approach.
