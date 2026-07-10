# Playback Seek and Detail Recommendations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the accepted long-press seek tuning and reliable detail recommendations as two independently verified Kotlin Android TV child tasks.

**Architecture:** The player child changes only pure seek policy and route contracts. The recommendation child changes the detail recommendation lifecycle plus its Douban HTML boundary while preserving the existing Compose rail. The parent performs integration verification and protects the existing dirty worktree.

**Tech Stack:** Kotlin 2.x, Android Gradle Plugin, Jetpack Compose, Kotlin Coroutines/Flow, JUnit 4, Truth, kotlinx-coroutines-test.

---

## File Map

- Child 1 plan: `.trellis/tasks/07-10-playback-seek-acceleration/implement.md`
- Child 2 plan: `.trellis/tasks/07-10-detail-related-recommendations/implement.md`
- Shared evidence: `.trellis/tasks/07-10-playback-seek-related-recommendations/research/current-implementation-audit.md`
- Shared spec: `.trellis/spec/frontend/tv-mode.md`

### Task 1: Protect the Existing Worktree

**Files:**
- Inspect only: all paths listed by `git status --short`

- [ ] **Step 1: Record the pre-implementation dirty state**

Run:

```bash
git status --short
git diff -- re-android/feature-tv-player re-android/feature-tv-detail re-android/core-data re-android/core-network re-android/app-tv
```

Expected: existing user changes are visible and no unrelated file is reverted.

- [ ] **Step 2: Confirm baseline tests**

Run:

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  :feature-tv-detail:testDebugUnitTest \
  :core-data:testDebugUnitTest \
  :app-tv:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL` before new implementation changes.

### Task 2: Execute the Seek Child

**Files:**
- Plan: `.trellis/tasks/07-10-playback-seek-acceleration/implement.md`

- [ ] **Step 1: Activate the child task**

Run:

```bash
python3 ./.trellis/scripts/task.py start .trellis/tasks/07-10-playback-seek-acceleration
```

Expected: task status becomes `in_progress`.

- [ ] **Step 2: Implement the child plan with TDD**

Follow every checkbox in the child `implement.md`. Do not edit recommendation files in this child.

- [ ] **Step 3: Run child quality checks**

Run the focused player tests, module unit tests, and `git diff --check` listed in the child plan.

- [ ] **Step 4: Complete the child only after checks pass**

Record the verified result in the child task and preserve unrelated dirty files.

### Task 3: Execute the Recommendation Child

**Files:**
- Plan: `.trellis/tasks/07-10-detail-related-recommendations/implement.md`

- [ ] **Step 1: Activate the child task**

Run:

```bash
python3 ./.trellis/scripts/task.py start .trellis/tasks/07-10-detail-related-recommendations
```

Expected: task status becomes `in_progress`.

- [ ] **Step 2: Implement the child plan with TDD**

Follow every checkbox in the child `implement.md`. Build on the existing partial recommendation changes; do not replace unrelated detail/player work.

- [ ] **Step 3: Run child quality checks**

Run the focused detail/data/app tests, module tests, and `git diff --check` listed in the child plan.

- [ ] **Step 4: Complete the child only after checks pass**

Record the verified result and any device-only follow-up in the child task.

### Task 4: Parent Integration Verification

**Files:**
- Modify if required: `.trellis/spec/frontend/tv-mode.md`
- Modify: parent and child Trellis task artifacts for final status/checklists

- [ ] **Step 1: Run the combined focused suite**

```bash
./re-android/gradlew -p re-android \
  :feature-tv-player:testDebugUnitTest \
  :feature-tv-detail:testDebugUnitTest \
  :core-data:testDebugUnitTest \
  :core-network:testDebugUnitTest \
  :app-tv:testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 2: Run the full Kotlin TV unit suite**

```bash
./re-android/gradlew -p re-android testDebugUnitTest
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Run lint and whitespace checks**

```bash
./re-android/gradlew -p re-android lintDebug
git diff --check
```

Expected: lint completes without task-introduced errors and `git diff --check` prints no errors.

- [ ] **Step 4: Review the final diff against the initial dirty snapshot**

```bash
git status --short
git diff --stat
git diff -- re-android/feature-tv-player re-android/feature-tv-detail re-android/core-data re-android/core-network re-android/app-tv
```

Expected: every new hunk maps to a child PRD/design/plan; unrelated user changes remain intact.

- [ ] **Step 5: Update executable TV specifications when the new contracts are stable**

Capture the four-second/approximately-30-minute seek contract and the independent recommendation scheduling contract in `.trellis/spec/frontend/tv-mode.md` if they are not already represented.

- [ ] **Step 6: Prepare scoped Chinese commits**

Use separate concise messages rather than one broad commit:

```text
optimize(tv): 调整长按快进快退变速
fix(tv): 修复详情页相关推荐加载链路
```

Use `git add -p` for overlapping dirty files and verify `git diff --cached` contains only task-authorized hunks. If pre-existing changes cannot be safely isolated, do not commit them silently; report the exact overlap.

## Manual TV/Emulator Checklist

- [ ] Short press still seeks 10 seconds.
- [ ] Hold left/right for about four seconds and feel the second-stage gear change.
- [ ] Hold for about ten seconds and confirm approximately 30 minutes of travel away from media boundaries.
- [ ] Confirm the seconds ones digit changes about once per second while higher digits move quickly.
- [ ] Confirm releasing the key stops further movement immediately.
- [ ] Open a detail page with a valid Douban identity and confirm recommendations appear even while title-source discovery remains active.
- [ ] Enter and return from fullscreen and confirm no duplicate recommendation request or list reset.
- [ ] Confirm no-source and preview-error pages can still load recommendations without changing the playback error/empty state.
