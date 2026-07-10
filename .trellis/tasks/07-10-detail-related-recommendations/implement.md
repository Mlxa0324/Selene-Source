# Kotlin TV Detail Recommendations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Kotlin TV detail recommendations start independently from source discovery, survive stale loads safely, and parse Douban recommendation HTML reliably.

**Architecture:** Introduce a narrow `DoubanSubjectHtmlSource` boundary for testable HTML fetching, harden the dependency-free parser, and add a serial-aware recommendation lifecycle in `TvDetailViewModel`. Keep `TvDetailRoute` rendering the existing `recommendCards` list.

**Tech Stack:** Kotlin, Coroutines/StateFlow, Jetpack Compose, OkHttp, JUnit 4, Truth, kotlinx-coroutines-test.

---

## File Map

- Modify: `re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneDoubanHtmlApi.kt`
- Modify: `re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParser.kt`
- Modify: `re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepository.kt`
- Create: `re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParserTest.kt`
- Create: `re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepositoryTest.kt`
- Modify: `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModel.kt`
- Modify: `re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModelTest.kt`
- Modify: `re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailPresentationTest.kt`
- Modify: `re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvAppContainer.kt`
- Modify: `re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/TvAppContainerTest.kt`

### Task 1: Add Failing Douban Parser and Repository Tests

**Files:**
- Create: `re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParserTest.kt`
- Create: `re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepositoryTest.kt`

- [ ] **Step 1: Write a nested-container parser fixture**

Use a fixture containing nested `<div>` elements, two `<dl>` items, reordered image attributes, a protocol-relative poster, and one missing rating:

```kotlin
private val recommendationHtml = """
    <div id="recommendations">
      <div class="hd"><h2>喜欢这部电影的人也喜欢</h2></div>
      <div class="recommendations-bd">
        <dl>
          <dt><a href="https://movie.douban.com/subject/1111111/"><img alt="推荐甲" src="//img.test/a.jpg"></a></dt>
          <dd><span class="subject-rate">9.1</span></dd>
        </dl>
        <dl>
          <dt><a href="//movie.douban.com/subject/2222222/"><img src="https://img.test/b.jpg" alt="推荐乙"></a></dt>
        </dl>
      </div>
    </div>
""".trimIndent()
```

Assert exact IDs, titles, normalized poster URLs, optional rating, and stable order. Add separate cases for no recommendation container and incomplete items.

- [ ] **Step 2: Write repository boundary tests**

Define an injectable suspend fetch source and verify:

```kotlin
val source = DoubanSubjectHtmlSource { doubanId ->
    assertThat(doubanId).isEqualTo("1292052")
    recommendationHtml
}
val repository = DoubanRepository(api = fakeDoubanApi, htmlSource = source)
```

Cover successful parsing, `htmlSource=null` returning empty, and fetch exceptions propagating to the caller. The fixture must explicitly prove protocol-relative subject links and poster links are accepted.

- [ ] **Step 3: Run the tests and verify failure**

```bash
./re-android/gradlew -p re-android \
  :core-data:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.core.data.repository.DoubanDetailsParserTest" \
  --tests "org.moontechlab.selene.tv.core.data.repository.DoubanRepositoryTest"
```

Expected: FAIL because the current parser truncates at the first nested closing div, assumes image attribute order, and no injectable `DoubanSubjectHtmlSource` exists.

### Task 2: Implement the Testable HTML Boundary and Parser

**Files:**
- Modify: `re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneDoubanHtmlApi.kt`
- Modify: `re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParser.kt`
- Modify: `re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepository.kt`

- [ ] **Step 1: Introduce the fetch contract**

Add above the implementation:

```kotlin
/** 豆瓣详情 HTML 数据源。 */
fun interface DoubanSubjectHtmlSource {
    /**
     * 抓取指定豆瓣条目的 HTML。
     *
     * @param doubanId 豆瓣条目 ID。
     * @return 豆瓣详情 HTML。
     */
    suspend fun fetchSubjectHtml(doubanId: String): String
}
```

Make `SeleneDoubanHtmlApi` implement the interface and rename/bridge its method to `fetchSubjectHtml` without changing direct/verified network behavior.

- [ ] **Step 2: Extract a balanced recommendations container**

Implement a helper that finds the opening `div#recommendations`, scans subsequent opening/closing `div` tags with a depth counter, and returns only the matched container body. Do not stop at the first nested `</div>`.

- [ ] **Step 3: Parse attributes independently**

Use a reusable helper:

```kotlin
private fun readAttribute(tag: String, name: String): String? {
    return Regex(
        pattern = """\\b${Regex.escape(name)}\\s*=\\s*[\"']([^\"']*)[\"']""",
        option = RegexOption.IGNORE_CASE,
    ).find(tag)?.groupValues?.getOrNull(1)
}
```

Read `href`, `src`, and `alt` independently; accept absolute, protocol-relative, and relative subject links; normalize `//poster` to `https://poster`; keep rating optional; skip incomplete items.

- [ ] **Step 4: Let repository fetch failures propagate**

Change the repository dependency to `DoubanSubjectHtmlSource?` and implement:

```kotlin
suspend fun loadDetailRecommends(doubanId: String): List<TvVideoCard> {
    val source = htmlSource ?: return emptyList()
    val html = source.fetchSubjectHtml(doubanId)
    return DoubanDetailsParser.parseRecommends(html)
}
```

Do not convert network failures into an indistinguishable empty list here; the ViewModel boundary owns non-fatal failure state.

- [ ] **Step 5: Run parser/repository tests**

Run the Task 1 command again.

Expected: PASS.

- [ ] **Step 6: Prepare the data-boundary commit**

```bash
git add -N \
  re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneDoubanHtmlApi.kt \
  re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParser.kt \
  re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParserTest.kt \
  re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepositoryTest.kt
git add -p \
  re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneDoubanHtmlApi.kt \
  re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParser.kt \
  re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepository.kt \
  re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanDetailsParserTest.kt \
  re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/DoubanRepositoryTest.kt
git diff --cached
git commit -m "fix(tv): 修复豆瓣相关推荐解析"
```

Stage only task hunks. Do not commit unrelated pre-existing hunks.

### Task 3: Add Failing Recommendation Lifecycle Tests

**Files:**
- Modify: `re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModelTest.kt`

- [ ] **Step 1: Test the primary Playing-plus-two-seconds trigger**

Use `StandardTestDispatcher(testScheduler)`, a playable exact source, a blocked `loadMoreSources`, `FailingPreviewPlayerEngine`, and a counting `loadRecommends` lambda.

After emitting `PlayerState.Playing(request.toSnapshot())`:

```kotlin
advanceTimeBy(1_999L)
assertThat(recommendCalls).isEqualTo(0)
advanceTimeBy(1L)
runCurrent()
assertThat(recommendCalls).isEqualTo(1)
assertThat(viewModel.state.value.recommendCards).containsExactly(recommendCard())
assertThat(moreGate.isCompleted).isFalse()
```

Complete the source gate at the end so the test coroutine exits cleanly.

- [ ] **Step 2: Test single-start and stale-result isolation**

Cover repeated `Playing` snapshots producing one request, then start a second detail load before the first recommendation deferred completes. Complete the old deferred and assert it cannot overwrite the new detail's cards or state.

Also emit a `PlayerState.Playing` snapshot whose request belongs to previous/shared-session media and assert it does not schedule recommendations for the current detail.

- [ ] **Step 3: Test terminal fallbacks**

Add independent cases for:

- both source lanes complete with no playable source;
- `playerEngine == null` after a playable request is selected;
- synchronous `engine.load` failure;
- `PlayerState.Error`;
- both lanes settled while a valid engine remains `Loading` does not start recommendations.

- [ ] **Step 4: Test failure isolation**

Make `loadRecommends` throw and assert:

```kotlin
assertThat(state.recommendLoadState).isEqualTo(TvDetailRecommendLoadState.Failed)
assertThat(state.recommendErrorMessage).contains("推荐请求失败")
assertThat(state.currentSourceId).isNotEmpty()
assertThat(state.playbackRequest).isNotNull()
assertThat(state.errorMessage).isNull()
```

- [ ] **Step 5: Run the focused tests and verify failure**

```bash
./re-android/gradlew -p re-android \
  :feature-tv-detail:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.feature.detail.TvDetailViewModelTest"
```

Expected: FAIL because recommendation lifecycle state and independent scheduling do not exist.

### Task 4: Implement the Recommendation Lifecycle

**Files:**
- Modify: `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModel.kt`

- [ ] **Step 1: Add explicit lifecycle state**

Add a fully documented enum:

```kotlin
enum class TvDetailRecommendLoadState {
    Idle,
    Scheduled,
    Loading,
    Loaded,
    Empty,
    Failed,
}
```

Add `recommendLoadState` and `recommendErrorMessage` to `TvDetailUiState`, with field/KDoc comments.

Add a structured diagnostic contract in the detail feature so local JVM tests can collect events:

```kotlin
enum class TvDetailRecommendDiagnosticStage {
    Scheduled,
    Loading,
    MissingDoubanId,
    Success,
    Empty,
    Failure,
    StaleIgnored,
}

data class TvDetailRecommendDiagnostic(
    val stage: TvDetailRecommendDiagnosticStage,
    val entryKey: String,
    val trigger: String = "",
    val count: Int? = null,
    val message: String? = null,
)

fun interface TvDetailRecommendDiagnosticSink {
    fun record(event: TvDetailRecommendDiagnostic)
}
```

Inject `TvDetailRecommendDiagnosticSink` into `TvDetailViewModel` with a no-op default. ViewModel tests own assertions for scheduled/loading/success/empty/failure/stale events.

- [ ] **Step 2: Add one job per detail serial**

Add fields for `recommendJob` and `recommendStartedSerial`. At the start of `load(entry)`, cancel the old job and reset recommendation state/cards before starting source work.

Extract the existing scope creation into one shared lazy initializer used by production and direct-test paths:

```kotlin
private fun getOrCreateBackgroundScope(): CoroutineScope {
    return backgroundScope ?: CoroutineScope(SupervisorJob() + previewDispatcher).also { createdScope ->
        backgroundScope = createdScope
    }
}
```

Change `ensureLoaded` to call this helper, and use the same helper for recommendation jobs. This keeps `load(entry)` tests buildable without requiring `ensureLoaded` first.

- [ ] **Step 3: Add the scheduling helper**

Implement a single-entry helper shaped as:

```kotlin
private fun scheduleRecommends(
    serial: Long,
    delayMs: Long,
    trigger: String,
) {
    if (!isActiveSerial(serial) || recommendStartedSerial == serial) return
    recommendStartedSerial = serial
    mutableState.value = mutableState.value.copy(
        recommendLoadState = TvDetailRecommendLoadState.Scheduled,
        recommendErrorMessage = null,
    )
    recommendJob = getOrCreateBackgroundScope().launch {
        delay(delayMs)
        if (!isActiveSerial(serial)) return@launch
        mutableState.value = mutableState.value.copy(
            recommendLoadState = TvDetailRecommendLoadState.Loading,
        )
        runCatching { loadRecommends(currentEntry ?: return@launch, mutableState.value.detail) }
            .onSuccess { cards -> applyRecommendSuccess(serial, cards, trigger) }
            .onFailure { throwable -> applyRecommendFailure(serial, throwable, trigger) }
    }
}
```

Use the existing background dispatcher/scope lifecycle, cancel the job in `release()`, and keep diagnostic logging low frequency and free of response bodies/cookies.

- [ ] **Step 4: Wire the primary and terminal triggers**

- `PlayerState.Playing` -> first verify `playerState.snapshot` matches the active `mutableState.value.playbackRequest`, then call `scheduleRecommends(loadSerial, 2_000L, "preview-playing")`.
- `playerEngine == null` after a valid request -> immediate terminal fallback.
- synchronous `engine.load` failure -> immediate terminal fallback.
- `PlayerState.Error` -> immediate terminal fallback.
- `emptyPlaybackCompleted=true` after both lanes finish -> immediate terminal fallback.
- `PlayerState.Loading` and normal lane completion with a playable source -> no fallback.

Remove the old serial recommendation call located after `moreDeferred.await()` and favorite completion.

Use the existing request-matching helper already used by `startPreviewPlayback`; do not duplicate media identity comparison logic.

- [ ] **Step 5: Apply results without touching playback state**

Success with cards sets `Loaded`; success with empty list sets `Empty`; failure sets `Failed` plus a concise error message. Each helper must re-check the serial before writing and modify only recommendation fields.

Tests must assert diagnostic coverage for request failure, empty parse result, success count, and stale-result rejection. Missing/invalid Douban ID belongs to the app-container loader test because identity resolution happens there. Keep diagnostics low frequency and exclude response bodies, cookies, and authorization data.

- [ ] **Step 6: Run ViewModel tests**

Run the Task 3 focused command.

Expected: PASS.

### Task 5: Wire and Test the App Container

**Files:**
- Modify: `re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvAppContainer.kt`
- Modify: `re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/TvAppContainerTest.kt`

- [ ] **Step 1: Change the injectable factory to the narrow interface**

Replace the concrete factory type with `() -> DoubanSubjectHtmlSource`, keeping the production default returned by `SeleneTvNetworkFactory.createDoubanHtmlApi()`.

Construct `DoubanRepository(api = doubanApi, htmlSource = doubanHtmlSource)`.

Add a `TvDetailRecommendDiagnosticSink` constructor dependency to `TvAppContainer`. Production defaults to a low-frequency `java.util.logging.Logger` formatter; tests inject a collecting sink. Pass the sink into every created `TvDetailViewModel`, and emit `MissingDoubanId` from the app-container loader when all normalized identity candidates are absent.

- [ ] **Step 2: Add Douban ID priority tests**

Inject a recording `DoubanSubjectHtmlSource` returning the parser fixture and verify separately:

1. `detail.doubanId` is used when present;
2. when the ViewModel's source-only detail has a blank ID, the matching entry-keyed exact detail ID is used;
3. a `source="douban"` entry uses `entry.videoId`;
4. a normal entry without a detail ID calls the existing title/year resolver and fetches the resolved ID.

Reject blank and `"0"` IDs at every priority step. Implement a small private normalization helper in `TvAppContainer.kt`, for example:

```kotlin
private fun String.validDoubanIdOrNull(): String? {
    return trim().takeIf { value -> value.isNotEmpty() && value != "0" }
}
```

Inside `loadRecommends`, build the lookup detail from the latest ViewModel detail plus the matching entry-keyed exact-detail metadata before applying entry/title fallback. Do not change the `loadExactSources` return type just to carry the ID.

Do not keep one unversioned `exactFallbackDetail` variable. Store exact details by stable entry identity:

```kotlin
val exactDetailsByEntry = ConcurrentHashMap<String, TvVideoDetail>()

fun TvDetailEntry.detailEntryKey(): String {
    return "${source.trim()}::${videoId.trim()}"
}
```

`loadExactSources` must handle the nullable repository result explicitly:

```kotlin
val entryKey = entry.detailEntryKey()
val exactDetail = repo.loadDetail(source = entry.source, id = entry.videoId)
if (exactDetail == null) {
    exactDetailsByEntry.remove(entryKey)
} else {
    exactDetailsByEntry[entryKey] = exactDetail
}
```

`loadRecommends` reads only the detail under the active entry key. Add a race regression where a previous entry's exact detail completes late and prove the active entry never fetches that previous Douban ID. Add a same-entry refresh case where a later null exact result removes the older cached detail so an obsolete Douban ID cannot be reused.

Assert resulting `recommendCards` become non-empty through the created ViewModel.

Inject a collecting diagnostic sink and assert the app-container layer emits `MissingDoubanId` for blank/`"0"` candidates without attempting HTML fetch. ViewModel tests remain responsible for request/parse/result/stale diagnostic events.

- [ ] **Step 3: Run app-container tests and fix only wiring regressions**

```bash
./re-android/gradlew -p re-android \
  :app-tv:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.app.TvAppContainerTest"
```

Expected: PASS.

### Task 6: Lock the Existing UI Contract

**Files:**
- Modify: `re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailPresentationTest.kt`

- [ ] **Step 1: Add the non-empty recommendation layout case**

Build `TvDetailLayoutSections` with at least one `TvVideoCard` and assert:

```kotlin
assertThat(sections.showRecommends).isTrue()
assertThat(sections.showBottomActions).isTrue()
```

Retain the existing empty-list case. No route styling change is expected.

- [ ] **Step 2: Run feature detail tests**

```bash
./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

### Task 7: Validate and Prepare Scoped Commits

- [ ] **Step 1: Run all affected modules**

```bash
./re-android/gradlew -p re-android \
  :core-network:testDebugUnitTest \
  :core-data:testDebugUnitTest \
  :feature-tv-detail:testDebugUnitTest \
  :app-tv:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 2: Run whitespace and diff review**

```bash
git diff --check
git status --short
git diff -- re-android/core-network re-android/core-data re-android/feature-tv-detail re-android/app-tv
```

Expected: no whitespace errors and no unrelated hunk introduced by this child.

- [ ] **Step 3: Prepare separate Chinese commits when hunks are safely isolatable**

Use concise messages such as:

```text
fix(tv): 修复豆瓣相关推荐解析
fix(tv): 拆分详情页推荐加载
fix(tv): 接通详情页相关推荐数据
```

Inspect `git diff --cached` before every commit. Because these files already contain user changes, do not stage or commit unrelated hunks silently; defer the commit and report the overlap when safe isolation is not possible.
