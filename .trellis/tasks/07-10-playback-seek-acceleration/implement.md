# TV Long-Press Seek Acceleration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a ten-second long press seek approximately thirty minutes with a physical four-second gear change while preserving short-press and overlay-digit behavior.

**Architecture:** Keep `TvPlayerRoute` as the 100ms scheduler and keep `TvPlayerViewModel` as the absolute-target dispatcher. Change only the pure `TvSeekController` policy and focused route/test contracts.

**Tech Stack:** Kotlin, Jetpack Compose key events, Kotlin Coroutines, JUnit 4, Truth.

---

## File Map

- Modify: `re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt`
- Modify: `re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt`
- Modify: `re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteControlContractTest.kt`
- Inspect only unless a contract mismatch is found: `re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerRoute.kt`

### Task 1: Add Failing Timing and Cumulative Tests

**Files:**
- Modify: `re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt`

- [ ] **Step 1: Replace old five-second/18-second expectations**

Add tests equivalent to:

```kotlin
@Test
fun longPress_seek_delta_changes_gear_at_four_physical_seconds() {
    val controller = TvSeekController()

    assertThat(controller.computeDeltaSeconds(holdMs = 250L)).isEqualTo(12)
    assertThat(controller.computeDeltaSeconds(holdMs = 3_999L)).isEqualTo(12)
    assertThat(controller.computeDeltaSeconds(holdMs = 4_000L)).isEqualTo(22)
    assertThat(controller.computeDeltaSeconds(holdMs = 10_000L)).isEqualTo(22)
}
```

- [ ] **Step 2: Add the ten-second cumulative travel test**

```kotlin
@Test
fun continuousSeek_ten_second_hold_travels_about_thirty_minutes() {
    val controller = TvSeekController()
    val tickHoldTimes = generateSequence(250L) { previous -> previous + 100L }
        .takeWhile { holdMs -> holdMs < 10_000L }
        .toList()

    val totalSeconds = 10 + tickHoldTimes.sumOf(controller::computeDeltaSeconds)

    assertThat(totalSeconds).isEqualTo(1_786)
    assertThat(totalSeconds).isAtLeast(29 * 60 + 30)
    assertThat(totalSeconds).isAtMost(30 * 60 + 30)
}
```

- [ ] **Step 3: Add display cadence and boundary tests**

Cover:

```kotlin
val withinSameSecond = controller.computeDisplayPositionMs(
    actualPositionMs = 1_234_000L,
    basePositionMs = 300_000L,
    holdMs = 1_250L,
    direction = 1,
    durationMs = 7_200_000L,
)
val beforeNextSecond = controller.computeDisplayPositionMs(
    actualPositionMs = 1_244_000L,
    basePositionMs = 300_000L,
    holdMs = 1_999L,
    direction = 1,
    durationMs = 7_200_000L,
)
val afterNextSecond = controller.computeDisplayPositionMs(
    actualPositionMs = 1_254_000L,
    basePositionMs = 300_000L,
    holdMs = 2_250L,
    direction = 1,
    durationMs = 7_200_000L,
)
```

Assert that the two first values share the same seconds ones digit, the third advances by one, rewind never creates a negative digit, and display positions clip to `0..durationMs`.

- [ ] **Step 4: Run the focused test and verify failure**

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.feature.player.TvSeekControllerTest"
```

Expected: FAIL because the production threshold is still five seconds and the accelerated step is still 18 seconds.

### Task 2: Implement the Four-Second 12/22 Policy

**Files:**
- Modify: `re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt`

- [ ] **Step 1: Make the threshold use total physical hold time**

Implement the minimal policy:

```kotlin
fun computeDeltaSeconds(holdMs: Long): Int {
    if (holdMs < LONG_PRESS_START_MS) {
        // 短按保持 10 秒精确跳转。
        return INITIAL_PRESS_SECONDS
    }
    return if (holdMs < ACCELERATION_TRIGGER_HOLD_MS) {
        // 物理按住未满 4 秒时使用第一档。
        NORMAL_REPEAT_STEP_SECONDS
    } else {
        // 物理按住达到 4 秒后切入第二档。
        ACCELERATED_REPEAT_STEP_SECONDS
    }
}
```

Set constants to:

```kotlin
const val NORMAL_REPEAT_STEP_SECONDS = 12
const val ACCELERATED_REPEAT_STEP_SECONDS = 22
const val LONG_PRESS_START_MS = 250L
const val ACCELERATION_TRIGGER_HOLD_MS = 4_000L
```

Remove the obsolete subtraction-based threshold variable and update every constant/comment KDoc to describe physical hold time.

- [ ] **Step 2: Run the focused tests**

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.feature.player.TvSeekControllerTest"
```

Expected: PASS.

### Task 3: Lock the KeyUp Stop Contract

**Files:**
- Modify: `re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteControlContractTest.kt`

- [ ] **Step 1: Add a focused source contract test**

Add a test that reads `TvPlayerRoute.kt` and asserts the direction-key `KeyUp` branch contains both:

```kotlin
event.type == KeyEventType.KeyUp && event.key.isSeekDirectionKey()
continuousSeekState.stop()
```

Also retain the existing assertion that native repeat events are consumed while the internal scheduler owns ticks.

- [ ] **Step 2: Run route contract tests**

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  --tests "org.moontechlab.selene.tv.feature.player.TvPlayerRouteControlContractTest"
```

Expected: PASS without production route changes unless the source contract reveals drift.

### Task 4: Validate and Prepare the Child Commit

- [ ] **Step 1: Run the full player module unit tests**

```bash
./re-android/gradlew -p re-android :feature-tv-player:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 2: Check formatting and task-only diff**

```bash
git diff --check
git diff -- re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt \
  re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt \
  re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteControlContractTest.kt
```

Expected: no whitespace errors; every hunk maps to the child PRD.

- [ ] **Step 3: Commit only the verified child files**

```bash
git add -p \
  re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt \
  re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt \
  re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteControlContractTest.kt
git diff --cached
git commit -m "optimize(tv): 调整长按快进快退变速"
```

Stage only task hunks. Do not commit if the staged diff includes unrelated pre-existing hunks.
