# Technical Design: Kotlin TV Detail Recommendations

## Problem Definition

The Compose route and recommendation rail already exist. The failure is primarily in orchestration: recommendation loading is currently placed after complete exact-source, title-source, and favorite completion. A long-running title/SSE search therefore prevents the recommendation request from starting, and any failure is silently converted to an empty list that hides the entire section.

## Selected Architecture

Keep the existing route and card model. Introduce a dedicated recommendation lifecycle inside `TvDetailViewModel` and make the HTML fetch boundary testable.

### ViewModel Ownership

`TvDetailViewModel` owns:

- one recommendation job for the active detail load;
- one active load serial used to reject stale results;
- a recommendation lifecycle state suitable for tests and diagnostics (`Idle`, `Scheduled`, `Loading`, `Loaded`, `Empty`, `Failed`);
- the existing `recommendCards` list consumed by the route.

Starting a new detail load must cancel the previous recommendation job, clear the previous cards, reset lifecycle state, and increment the existing detail serial.

### Primary Trigger: Preview Playback

When `applyPreviewPlayerState` observes `PlayerState.Playing` for the active media:

1. verify the snapshot matches the active `playbackRequest`;
2. call a single-entry scheduling function;
3. move the recommendation state to `Scheduled`;
4. wait two seconds, matching Flutter TV;
5. re-check the active serial and current entry;
6. execute the loader on the ViewModel's lazily initialized background scope.

Repeated `Playing` snapshots, pause/resume, recomposition, and fullscreen return must not schedule duplicate requests for the same detail serial.

The background scope initializer is shared by `ensureLoaded` and recommendation scheduling so production route calls and direct unit-test calls to `load(entry)` use the same lifecycle owner.

Recommendation diagnostics use an injected structured sink shared by the ViewModel and app-container loader. Direct JVM tests collect events without relying on Android Logcat; production wiring formats the same low-frequency events through a platform-safe logger.

### Fallback Trigger: Terminal No-Playback State

The fallback must run only when the ViewModel can observe that normal preview playback will not reach the primary `Playing` trigger. It must not fire merely because both source lanes have settled while a valid preview is still in `Loading`.

The allowed fallback conditions are:

- both source lanes settled and `emptyPlaybackCompleted=true`, meaning no playable source exists;
- `playerEngine == null`, meaning the current configuration cannot produce player state events;
- `engine.load(request)` failed synchronously;
- `applyPreviewPlayerState` received `PlayerState.Error` for the active request.

When one of these terminal conditions occurs and no recommendation request has started, schedule it immediately. A normal `Loading` state with a playable source remains on the primary path and waits for `PlayerState.Playing`, then the two-second delay.

The fallback must not wait for favorite state and must not modify source or playback completion flags.

### Loader and Data Boundary

The injected loader keeps the existing conceptual inputs: active `TvDetailEntry` and the latest `TvVideoDetail`.

Douban identity resolution order remains:

1. `detail.doubanId` when present and non-zero;
2. the app container's entry-keyed full exact detail when the ViewModel's source-only detail has lost that metadata;
3. a Douban entry's `entry.videoId`;
4. title/year matching through `TvDetailRepository.resolveDoubanId`.

Every candidate must reject blank values and the sentinel value `"0"` before it can win the priority chain. The app container should merge captured exact-detail metadata into the recommendation lookup input rather than expanding the source-loader contract.

Captured exact details must be stored by a stable `source + videoId` entry key. A late exact-detail result from another entry must never become the recommendation identity for the active entry.

The HTML fetch dependency should be exposed as a narrow suspend function or interface rather than requiring tests to instantiate a live `SeleneDoubanHtmlApi`. Production wiring still delegates to `SeleneDoubanHtmlApi.fetchDoubanSubjectHtml`.

Network exceptions propagate to the ViewModel recommendation boundary. An empty parsed list is an `Empty` result; an exception is `Failed`. Neither changes playback, sources, favorite state, or the page-level fatal error.

## HTML Parsing Contract

`DoubanDetailsParser` remains dependency-free and parses only the recommendations section.

It must:

- locate the full `div#recommendations` container without stopping at the first nested `</div>`;
- iterate recommendation `<dl>` blocks;
- accept absolute, protocol-relative, or subject-relative Douban links;
- extract `src` and `alt` independently so HTML attribute order is not significant;
- treat rating as optional;
- normalize protocol-relative poster URLs to HTTPS;
- skip incomplete items without failing the whole list;
- return an empty list for missing or malformed recommendation content.

The parser does not parse the full Douban detail model and does not add a third-party HTML library.

## UI Contract

`TvDetailRoute` keeps its existing rendering rule:

- non-empty `recommendCards` renders the rail;
- empty/failed results do not render a fake recommendation section;
- bottom actions remain visible under the existing layout contract.

No recommendation card style or navigation redesign is included.

## Diagnostics

Diagnostics must be concise and stage-based:

- scheduling trigger and detail serial;
- resolved/missing Douban identity without private session data;
- request failure class/message;
- parse result count;
- stale result rejection.

Do not log response HTML, cookies, authorization headers, or high-frequency player snapshots.

## Test Design

### `feature-tv-detail`

- A blocked `loadMoreSources` deferred does not prevent a playing preview from triggering recommendations after the configured delay.
- Both source lanes settling with no playable source triggers the fallback.
- Both source lanes settling while a valid preview remains in `Loading` does not bypass the primary trigger.
- Missing player engine, synchronous engine-load failure, and `PlayerState.Error` each trigger the terminal fallback once.
- Repeated playing snapshots start only one request.
- A `Playing` snapshot for previous/shared-session media does not start recommendations for the active detail.
- Loader failure moves only recommendation state to `Failed` and preserves source/playback state.
- A new detail load invalidates the previous delayed or in-flight result.
- A successful non-empty result updates `recommendCards` and `Loaded` state.

### `core-data`

- Parser fixture with multiple items and nested recommendation markup.
- Optional/missing rating.
- Reordered image attributes and protocol-relative poster URL.
- Missing recommendation container and malformed items.
- Repository/fetch-lambda success, empty, and exception behavior.

### `app-tv`

- Douban ID priority: detail ID, Douban entry ID, then title/year resolution.
- Detail ViewModel receives the production recommendation loader.

### Route Contract

- Existing presentation test continues to hide an empty rail.
- Add/retain a non-empty layout assertion showing recommendations and bottom actions.

## Compatibility and Rollback

- The existing `recommendCards` field and route rendering remain compatible.
- No persistence or API schema changes are introduced.
- The scheduling helper can be disabled independently if device testing reveals unexpected bandwidth contention.
- The HTML fetch/parse wiring can be rolled back without touching the source-loading state machine.
- Existing dirty implementation is amended in place; unrelated detail/player refactors are not reverted.
