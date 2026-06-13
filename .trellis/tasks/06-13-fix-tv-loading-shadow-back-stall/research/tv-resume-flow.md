# Research: TV Detail Page "Continue Watching" Playback Flow

- **Query**: How does the TV detail page handle "Continue Watching" (继续播放/续播) and load the initial playback source?
- **Scope**: internal
- **Date**: 2026-06-13

## Findings

### Key Files

| File Path | Description |
|---|---|
| `lib/tv_app/screens/tv_video_detail_screen.dart` | Main detail screen with all resume logic (4700+ lines) |
| `lib/tv_app/screens/tv_fullscreen_player_screen.dart` | Fullscreen player overlay with its own resume seek logic |
| `lib/tv_app/services/tv_play_record_service.dart` | Builds play records, resolves resume positions/episode indices |
| `lib/models/play_record.dart` | PlayRecord data model |
| `lib/models/video_info.dart` | VideoInfo data model (entry point + fromPlayRecord factory) |
| `lib/models/search_result.dart` | SearchResult model with `List<String> episodes` (URLs) |
| `lib/services/page_cache_service.dart` | Persistence layer: savePlayRecord, getPlayRecords, deletePlayRecord |

### Critical Finding: PlayRecord Does NOT Store the Episode URL

The `PlayRecord` model stores:
- `source` (e.g., "yinghua") and `id` (e.g., "12345") -- identifies the **source/resource**, not the episode URL
- `sourceName` (e.g., "樱花") -- display name of the source line
- `title`, `year`, `cover` -- video metadata
- `index` -- episode number (1-based), e.g., episode 5
- `playTime` -- elapsed seconds, used for resume position
- `totalTime` -- full duration in seconds
- `saveTime` -- timestamp of record
- `searchTitle` -- search keyword for matching

The **actual episode URL is NOT persisted** in the play record. It lives only in the in-memory `SearchResult.episodes` list (which is a `List<String>` of URL strings). When continuing watching, the URL is resolved at playback time by:

```dart
// tv_video_detail_screen.dart, _playCurrentEpisode(), line ~2225
final url = _resolvePlaybackUrl(detail.episodes[index]);
```

### Flow: "Continue Watching Click" to "First Frame Playing"

#### Step 1: Entry Point

The detail screen (`TvVideoDetailScreen`) receives a `VideoInfo` from the home screen. The `VideoInfo` carries resume hints when `playTime > 0` or `index > 1`.

#### Step 2: initState -- Parallel Loading

The screen starts multiple async loads simultaneously (line ~914-915 in `_loadContent`):

```
unawaited(_loadInitialSources(serial));     // Load exact source results
unawaited(_loadMoreSources(serial));         // Load additional sources
```

Separately, in `initState`:
- `_loadResumeRecord()` -- reads latest PlayRecords from cache
- `_loadTvPlayerKernel()` -- reads player kernel preference (exo vs default)
- `_loadM3u8ProxyUrl()` -- warms up M3U8 proxy config

#### Step 3: Resume Record Matching (`_loadResumeRecord`, line ~922)

1. Reads all `PlayRecord`s from `PageCacheService().getPlayRecords(context)`
2. Matches via `_matchingResumeRecord(records)`:
   - **First**: exact match by `record.source == widget.videoInfo.source && record.id == widget.videoInfo.id`
   - **Fallback** (only if `widget.videoInfo` has resume hint): matches by `sourceName` + video identity (title+year or searchTitle+year)
   - Takes the most recent matching record (sorted by `saveTime`)
3. If matched, creates a new `VideoInfo` from the record: `VideoInfo.fromPlayRecord(matchedRecord)` and stores it in `_resumeVideoInfo`

#### Step 4: Source Loading and Selection (`_loadInitialSources`, line ~1387)

Sources come from three channels (in priority order):
1. `_prefetchedSearchSessionSources()` -- shared search session from search page
2. `widget.prefetchedSources` -- pre-cached sources
3. Network API via `TvVideoDetailScreen.defaultLoadInitialSources(context, videoInfo)`

Each source (`SearchResult`) contains `List<String> episodes` (URL strings indexed by episode).

#### Step 5: Source Selection in `_mergeSources` (line ~1512)

When no `_currentDetail` exists yet (first time), calls `_resolveInitialPlayableSource()`:

If resume record exists (`_shouldPrioritizeResumeSource`):
1. Try exact match: `source.source == _resumeVideoInfo.source && source.id == _resumeVideoInfo.id`
2. Fall back to same source key: `source.source == _resumeVideoInfo.source`
3. Fall back to same source name
4. Fall back to same episode count
5. Random source as last resort

If no resume record: pick first available source

#### Step 6: Apply Resume State (`_applyInitialResumeState`, line ~1717)

Called on the selected `SearchResult`. If the record matches the detail (`_matchesVideoInfoRecord`):
- Sets `_episodeIndex` from `TvPlayRecordService.episodeIndexFromVideoInfo(_resumeVideoInfo, detail.episodes.length)` -- converts 1-based index to 0-based, clamped to valid range
- Sets `_pendingInitialPlaybackPosition` from `TvPlayRecordService.resumePositionFromVideoInfo(_resumeVideoInfo)` -- `Duration(seconds: playRecord.playTime)` if playTime >= 1
- Saves snapshot: `_initialResumePlaybackPositionSnapshot`

If no match: resets to episode 0, no resume position.

#### Step 7: Deferred Playback Gate (`_playCurrentEpisode`, line ~2200)

Playback waits for three conditions:
1. `_hasLoadedResumeRecord == true` (otherwise sets `_hasPendingInitialPlaybackAfterResumeLoad = true` and returns)
2. `_hasResolvedTvPlayerKernel == true` (otherwise returns)
3. `_playerController` is not null

If resume record arrives LATER than the initial source, `_restoreSavedSourceAfterResumeRecordLoaded()` may replace the current source with the saved one, then calls `_playCurrentEpisode()` again.

#### Step 8: URL Resolution and Playback (`_playCurrentEpisode`, line ~2225-2251)

```dart
final index = _episodeIndex.clamp(0, detail.episodes.length - 1);
final url = _resolvePlaybackUrl(detail.episodes[index]);
final startAt = _takeInitialPlaybackPosition();
await controller.updateDataSource(url, startAt: startAt);
await _seekToInitialPlaybackPositionIfNeeded(controller, startAt);
```

- `_resolvePlaybackUrl()` prepends M3U8 proxy if available: `'$_m3u8ProxyUrl${Uri.encodeComponent(url)}'`
- `_takeInitialPlaybackPosition()` is one-shot: returns `_pendingInitialPlaybackPosition` then nullifies it and sets `_hasAppliedInitialPlaybackPosition = true`
- `_seekToInitialPlaybackPositionIfNeeded()` compensates if the underlying player ignores `startAt`

#### Step 9: Resume Seek Confirmation Loop

After `updateDataSource`, the system monitors `onProgressUpdate` and may retry seek up to 5 times if the player hasn't reached the resume position (`_retryPendingResumeSeekAfterProgress`, line ~1855).

#### Step 10: Fullscreen Transition

When opening fullscreen overlay:
- `_resolveFullscreenInitialPosition()` returns `_playerController?.currentPosition ?? _initialResumePlaybackPositionSnapshot`
- Fullscreen player receives `initialEpisodeIndex` and `initialPlaybackPosition` from detail page
- Fullscreen has its own `_takeInitialPlaybackPosition()` for one-shot resume

### Resume Data Flow Diagram

```
Home Screen "继续观看" click
    |
    v
VideoInfo (source, id, sourceName, playTime, index, ...)
    |
    v
TvVideoDetailScreen.initState()
    |-- _loadResumeRecord() ------> PageCacheService.getPlayRecords()
    |                                  |
    |                            PlayRecord[] (source, id, index, playTime, ...)
    |                                  |
    |                            match by source+id or sourceName+title+year
    |                                  |
    |                            _resumeVideoInfo = VideoInfo.fromPlayRecord(matched)
    |
    |-- _loadInitialSources() ---> API / cache
    |                                  |
    |                            SearchResult[] (each has List<String> episodes URLs)
    |                                  |
    |                            _resolveInitialPlayableSource()
    |                            (prioritizes source matching _resumeVideoInfo)
    |                                  |
    |                            _currentDetail = selected Source
    |                            _applyInitialResumeState(selected)
    |                            (sets _episodeIndex, _pendingInitialPlaybackPosition)
    |
    +-- (both complete) --> _playCurrentEpisode()
                                  |
                            detail.episodes[_episodeIndex] --> URL string
                            _resolvePlaybackUrl(url) --> final URL (with proxy)
                            _takeInitialPlaybackPosition() --> startAt Duration
                                  |
                            controller.updateDataSource(url, startAt: startAt)
                                  |
                            _seekToInitialPlaybackPositionIfNeeded (fallback seek)
                                  |
                            FIRST FRAME PLAYING
```

### Key Variables in Detail Screen

| Variable | Type | Purpose |
|---|---|---|
| `_resumeVideoInfo` | `VideoInfo` | Latest resume record data, updated from cache |
| `_currentDetail` | `SearchResult?` | Currently selected source with episode URLs |
| `_episodeIndex` | `int` | Current episode index (0-based) |
| `_initialResumeEpisodeIndex` | `int` | Snapshot of the initial resume episode |
| `_pendingInitialPlaybackPosition` | `Duration?` | Resume position, consumed one-shot by `_takeInitialPlaybackPosition()` |
| `_initialResumePlaybackPositionSnapshot` | `Duration?` | Snapshot for fullscreen fallback |
| `_hasAppliedInitialPlaybackPosition` | `bool` | Guard against consuming resume position twice |
| `_hasLoadedResumeRecord` | `bool` | Block playback until resume record is loaded |
| `_hasPendingInitialPlaybackAfterResumeLoad` | `bool` | Playback request arrived before resume record; replay needed |
| `_hasDispatchedInitialPreviewPlayback` | `bool` | Has the first playback URL been dispatched |
| `_hasResolvedTvPlayerKernel` | `bool` | Player kernel config loaded |
| `_shouldPrioritizeResumeSource` | `bool` (getter) | True when `_resumeVideoInfo` has resume hint AND a non-empty source |

### Caveats / Not Found

1. **Episode URL is not stored in PlayRecord.** The play record only stores `source` + `id` to re-identify the source, plus `index` (episode number). The actual URL comes from re-fetching `SearchResult.episodes[_episodeIndex]`. This means if a source changes its episode URLs between sessions, the "Continue Watching" could load a different URL than originally played, or no URL at all if the source becomes unavailable.

2. **Deferred playback race condition.** `_playCurrentEpisode()` may be called BEFORE `_loadResumeRecord()` completes. In that case, it sets `_hasPendingInitialPlaybackAfterResumeLoad = true` and returns. The actually-played source might be a "first-available" source rather than the saved source, requiring `_restoreSavedSourceAfterResumeRecordLoaded()` to correct it after the record loads. This could cause a brief flash of the wrong source loading/playing.

3. **`_restoreSavedSourceAfterResumeRecordLoaded`** is the correction mechanism but only fires if `_shouldPrioritizeResumeSource` is true AND the saved source is found in `_sources`.
