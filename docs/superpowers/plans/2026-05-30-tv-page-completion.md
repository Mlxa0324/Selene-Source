# TV 页面补全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 TV 端首页、搜索、历史、收藏、详情和直播页补成统一、完整、可继续扩展的产品页面，而不是只保留标题和占位字。

**Architecture:** 先在 `core-design` 抽出共享的 TV 页面壳、区块标题、统计信息和空状态组件，让各个 feature 页共用同一套视觉语言。再逐页把首页、搜索页、历史页、收藏夹页和详情页接到这些共享组件上，保留现有的数据流和播放器入口，只增强页面结构与可见内容。直播页保持轻量占位，但改成更像正式页面的结构，避免用户看到纯文本空白页。

**Tech Stack:** Kotlin、Jetpack Compose、Material3、AndroidX Compose UI Test、现有 TV feature module、`core-design` 共享设计模块。

---

### Task 1: 抽出 TV 页面共享组件

**Files:**
- Create: `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPageScaffold.kt`
- Create: `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPageSection.kt`
- Create: `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPageStatChip.kt`
- Create: `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvEmptyStatePanel.kt`
- Create: `re-android/core-design/src/androidTest/java/org/moontechlab/selene/tv/core/design/layout/TvPageScaffoldTest.kt`

- [ ] **Step 1: 写失败测试**

```kotlin
@Test
fun page_scaffold_renders_title_and_sections() {
    // 断言标题、状态文案和区块标题都能显示出来。
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core-design:connectedDebugAndroidTest`
Expected: 失败，提示找不到新组件或断言目标。

- [ ] **Step 3: 写最小实现**

```kotlin
@Composable
fun TvPageScaffold(...)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `./gradlew :core-design:connectedDebugAndroidTest`
Expected: 通过。

### Task 2: 补首页与搜索页

**Files:**
- Modify: `re-android/feature-tv-home/build.gradle.kts`
- Modify: `re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeRoute.kt`
- Create: `re-android/feature-tv-home/src/androidTest/java/org/moontechlab/selene/tv/feature/home/TvHomeRouteTest.kt`
- Modify: `re-android/feature-tv-search/build.gradle.kts`
- Modify: `re-android/feature-tv-search/src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchRoute.kt`
- Create: `re-android/feature-tv-search/src/androidTest/java/org/moontechlab/selene/tv/feature/search/TvSearchRouteTest.kt`

- [ ] **Step 1: 写首页/搜索页失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 用共享页面壳补充首页和搜索页布局**
- [ ] **Step 4: 运行测试确认通过**

### Task 3: 补历史、收藏和详情页

**Files:**
- Modify: `re-android/feature-tv-history/build.gradle.kts`
- Modify: `re-android/feature-tv-history/src/main/java/org/moontechlab/selene/tv/feature/history/TvHistoryRoute.kt`
- Create: `re-android/feature-tv-history/src/androidTest/java/org/moontechlab/selene/tv/feature/history/TvHistoryRouteTest.kt`
- Modify: `re-android/feature-tv-favorites/build.gradle.kts`
- Modify: `re-android/feature-tv-favorites/src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesRoute.kt`
- Create: `re-android/feature-tv-favorites/src/androidTest/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesRouteTest.kt`
- Modify: `re-android/feature-tv-detail/build.gradle.kts`
- Modify: `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- Create: `re-android/feature-tv-detail/src/androidTest/java/org/moontechlab/selene/tv/feature/detail/TvDetailRouteTest.kt`

- [ ] **Step 1: 写历史/收藏/详情页失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 用页面壳补齐信息块、列表区和入口区**
- [ ] **Step 4: 运行测试确认通过**

### Task 4: 补直播页和依赖收口

**Files:**
- Modify: `re-android/feature-tv-live/build.gradle.kts`
- Modify: `re-android/feature-tv-live/src/main/java/org/moontechlab/selene/tv/feature/live/TvLiveRoute.kt`
- Create: `re-android/feature-tv-live/src/androidTest/java/org/moontechlab/selene/tv/feature/live/TvLiveRouteTest.kt`

- [ ] **Step 1: 写直播页失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 把直播页改成正式一点的占位壳**
- [ ] **Step 4: 运行测试确认通过**

### Task 5: 全量验证与收尾

**Files:**
- Modify: 以上变更涉及的 Compose 页面和测试文件

- [ ] **Step 1: 运行相关模块测试**

Run:
```bash
./gradlew :core-design:testDebugUnitTest
./gradlew :feature-tv-home:connectedDebugAndroidTest
./gradlew :feature-tv-search:connectedDebugAndroidTest
./gradlew :feature-tv-history:connectedDebugAndroidTest
./gradlew :feature-tv-favorites:connectedDebugAndroidTest
./gradlew :feature-tv-detail:connectedDebugAndroidTest
./gradlew :feature-tv-live:connectedDebugAndroidTest
./gradlew :app-tv:connectedDebugAndroidTest
```

- [ ] **Step 2: 运行增量静态检查**

Run:
```bash
git diff --check
./gradlew :app-tv:compileDebugKotlin
```

- [ ] **Step 3: 记录变更并准备后续页面数据填充**

Keep the page shells reusable for the next round of data work.
