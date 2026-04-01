# Selene Android 原生重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在根目录 `re-android/` 下建立一个可编译、可运行的 Android-only Kotlin 原生工程，覆盖 Selene 的首轮全量功能域和基础可运行链路。

**Architecture:** 先搭建 `re-android/` 的独立 Gradle 多模块工程，再按 `core / feature / app` 划分基础设施和功能域。每个任务都先用单元测试或状态测试锁定行为，再补最小实现，最终把启动、登录、本地模式、首页、搜索、详情、播放器、下载、直播、资源站浏览、设置、收藏/历史都接进统一导航和存储层。

**Tech Stack:** Kotlin, Jetpack Compose, Navigation Compose, Hilt, Retrofit, OkHttp, Room, DataStore, Media3 ExoPlayer, WorkManager, Coil, JUnit4, kotlinx-coroutines-test

---

## 范围说明

本次 spec 覆盖多个独立子系统。为避免计划失焦，这份实施计划把目标限定为“首轮可运行原生版”：

1. 工程、模块、导航、依赖和状态管理全部原生化。
2. 全部一级功能域都有模块和基础路由。
3. 主链路可运行，复杂能力通过稳定接口先接线，再逐步做深。

更深层的 DLNA 控制细节、弹幕渲染调优和 benchmark 完整体验不在本轮强求追平 Flutter，但必须留下稳定实现边界。

## 文件地图

**Spec:**
- `docs/superpowers/specs/2026-04-01-re-android-native-rebuild-design.md`

**Workspace root:**
- Create: `re-android/settings.gradle.kts`
- Create: `re-android/build.gradle.kts`
- Create: `re-android/gradle.properties`
- Create: `re-android/gradle/libs.versions.toml`
- Create: `re-android/.gitignore`
- Create: `re-android/README.md`

**App shell:**
- Create: `re-android/app/build.gradle.kts`
- Create: `re-android/app/src/main/AndroidManifest.xml`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/SeleneApplication.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/MainActivity.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/navigation/SeleneDestination.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/navigation/SeleneNavGraph.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/SeleneApp.kt`

**Core modules:**
- Create: `re-android/core/common/build.gradle.kts`
- Create: `re-android/core/model/build.gradle.kts`
- Create: `re-android/core/ui/build.gradle.kts`
- Create: `re-android/core/network/build.gradle.kts`
- Create: `re-android/core/database/build.gradle.kts`
- Create: `re-android/core/datastore/build.gradle.kts`
- Create: `re-android/core/parser/build.gradle.kts`
- Create: `re-android/core/player/build.gradle.kts`
- Create: `re-android/core/download/build.gradle.kts`

**Feature modules:**
- Create: `re-android/feature/startup/build.gradle.kts`
- Create: `re-android/feature/auth/build.gradle.kts`
- Create: `re-android/feature/home/build.gradle.kts`
- Create: `re-android/feature/search/build.gradle.kts`
- Create: `re-android/feature/detail/build.gradle.kts`
- Create: `re-android/feature/player/build.gradle.kts`
- Create: `re-android/feature/live/build.gradle.kts`
- Create: `re-android/feature/sourcebrowser/build.gradle.kts`
- Create: `re-android/feature/favorites/build.gradle.kts`
- Create: `re-android/feature/history/build.gradle.kts`
- Create: `re-android/feature/downloads/build.gradle.kts`
- Create: `re-android/feature/settings/build.gradle.kts`
- Create: `re-android/feature/benchmark/build.gradle.kts`

**Representative source files for first working slice:**
- Create: `re-android/core/common/src/main/java/org/moontechlab/selene/core/common/AppError.kt`
- Create: `re-android/core/common/src/main/java/org/moontechlab/selene/core/common/Resource.kt`
- Create: `re-android/core/model/src/main/java/org/moontechlab/selene/core/model/SearchSource.kt`
- Create: `re-android/core/model/src/main/java/org/moontechlab/selene/core/model/VideoDetail.kt`
- Create: `re-android/core/ui/src/main/java/org/moontechlab/selene/core/ui/theme/SeleneTheme.kt`
- Create: `re-android/core/ui/src/main/java/org/moontechlab/selene/core/ui/adaptive/WindowLayoutInfo.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/CookieSessionStore.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/SeleneApi.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/DownstreamApi.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/SseSearchClient.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/SeleneDatabase.kt`
- Create: `re-android/core/datastore/src/main/java/org/moontechlab/selene/core/datastore/AppPreferencesRepository.kt`
- Create: `re-android/core/parser/src/main/java/org/moontechlab/selene/core/parser/M3uPlaylistParser.kt`
- Create: `re-android/core/parser/src/main/java/org/moontechlab/selene/core/parser/M3u8PlaylistParser.kt`
- Create: `re-android/core/player/src/main/java/org/moontechlab/selene/core/player/AndroidVideoPlayerEngine.kt`
- Create: `re-android/core/download/src/main/java/org/moontechlab/selene/core/download/M3u8DownloadPlanner.kt`

**Representative feature entry files:**
- Create: `re-android/feature/startup/src/main/java/org/moontechlab/selene/feature/startup/StartupViewModel.kt`
- Create: `re-android/feature/auth/src/main/java/org/moontechlab/selene/feature/auth/AuthViewModel.kt`
- Create: `re-android/feature/home/src/main/java/org/moontechlab/selene/feature/home/HomeRoute.kt`
- Create: `re-android/feature/search/src/main/java/org/moontechlab/selene/feature/search/SearchViewModel.kt`
- Create: `re-android/feature/detail/src/main/java/org/moontechlab/selene/feature/detail/DetailViewModel.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/PlayerViewModel.kt`
- Create: `re-android/feature/live/src/main/java/org/moontechlab/selene/feature/live/LiveViewModel.kt`
- Create: `re-android/feature/sourcebrowser/src/main/java/org/moontechlab/selene/feature/sourcebrowser/SourceBrowserViewModel.kt`
- Create: `re-android/feature/favorites/src/main/java/org/moontechlab/selene/feature/favorites/FavoritesViewModel.kt`
- Create: `re-android/feature/history/src/main/java/org/moontechlab/selene/feature/history/HistoryViewModel.kt`
- Create: `re-android/feature/downloads/src/main/java/org/moontechlab/selene/feature/downloads/DownloadsViewModel.kt`
- Create: `re-android/feature/settings/src/main/java/org/moontechlab/selene/feature/settings/SettingsViewModel.kt`
- Create: `re-android/feature/benchmark/src/main/java/org/moontechlab/selene/feature/benchmark/BenchmarkRoute.kt`

**Representative tests:**
- Create: `re-android/app/src/test/java/org/moontechlab/selene/app/navigation/SeleneDestinationTest.kt`
- Create: `re-android/core/common/src/test/java/org/moontechlab/selene/core/common/ResourceTest.kt`
- Create: `re-android/core/network/src/test/java/org/moontechlab/selene/core/network/CookieSessionStoreTest.kt`
- Create: `re-android/core/database/src/test/java/org/moontechlab/selene/core/database/SeleneDatabaseMigrationTest.kt`
- Create: `re-android/core/parser/src/test/java/org/moontechlab/selene/core/parser/M3u8PlaylistParserTest.kt`
- Create: `re-android/core/player/src/test/java/org/moontechlab/selene/core/player/AndroidVideoPlayerEngineTest.kt`
- Create: `re-android/core/download/src/test/java/org/moontechlab/selene/core/download/M3u8DownloadPlannerTest.kt`
- Create: `re-android/feature/startup/src/test/java/org/moontechlab/selene/feature/startup/StartupViewModelTest.kt`
- Create: `re-android/feature/search/src/test/java/org/moontechlab/selene/feature/search/SearchViewModelTest.kt`
- Create: `re-android/feature/detail/src/test/java/org/moontechlab/selene/feature/detail/DetailViewModelTest.kt`
- Create: `re-android/feature/player/src/test/java/org/moontechlab/selene/feature/player/PlayerViewModelTest.kt`
- Create: `re-android/feature/live/src/test/java/org/moontechlab/selene/feature/live/LiveViewModelTest.kt`
- Create: `re-android/feature/downloads/src/test/java/org/moontechlab/selene/feature/downloads/DownloadsViewModelTest.kt`

**Command convention:**
- 所有 Gradle 命令都在 `re-android/` 目录执行。

### Task 1: 建立 `re-android/` 独立 Gradle 工程与导航壳

**Files:**
- Create: `re-android/settings.gradle.kts`
- Create: `re-android/build.gradle.kts`
- Create: `re-android/gradle.properties`
- Create: `re-android/gradle/libs.versions.toml`
- Create: `re-android/.gitignore`
- Create: `re-android/app/build.gradle.kts`
- Create: `re-android/app/src/main/AndroidManifest.xml`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/SeleneApplication.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/MainActivity.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/navigation/SeleneDestination.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/navigation/SeleneNavGraph.kt`
- Create: `re-android/app/src/main/java/org/moontechlab/selene/app/SeleneApp.kt`
- Test: `re-android/app/src/test/java/org/moontechlab/selene/app/navigation/SeleneDestinationTest.kt`

- [ ] **Step 1: 写失败测试，锁定一级路由和隐藏 benchmark 路由**

在 `SeleneDestinationTest.kt` 断言：
- 首页、搜索、直播、资源站、下载、我的/设置都存在稳定 route
- `benchmark` route 存在，但不出现在默认底部导航列表中

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :app:testDebugUnitTest --tests "org.moontechlab.selene.app.navigation.SeleneDestinationTest"`
Expected: FAIL，提示 `SeleneDestination` 或导航列表尚未实现

- [ ] **Step 3: 写最小实现**

实现：
- `settings.gradle.kts` 注册 `app`、`core/*`、`feature/*`
- `libs.versions.toml` 声明 Compose、Hilt、Room、Retrofit、Media3、WorkManager 版本
- `SeleneDestination`、`SeleneNavGraph`、`SeleneApp` 完成基础导航壳
- `MainActivity` 仅承载 Compose 根节点，不写业务逻辑

- [ ] **Step 4: 运行测试确认通过**

Run: `./gradlew :app:testDebugUnitTest --tests "org.moontechlab.selene.app.navigation.SeleneDestinationTest"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/settings.gradle.kts re-android/build.gradle.kts re-android/gradle.properties re-android/gradle/libs.versions.toml re-android/.gitignore re-android/app
git commit -m "feat: bootstrap re-android app shell"
```

### Task 2: 建立 `core/common`、`core/model`、`core/ui` 基础能力

**Files:**
- Create: `re-android/core/common/build.gradle.kts`
- Create: `re-android/core/common/src/main/java/org/moontechlab/selene/core/common/AppError.kt`
- Create: `re-android/core/common/src/main/java/org/moontechlab/selene/core/common/Resource.kt`
- Create: `re-android/core/common/src/main/java/org/moontechlab/selene/core/common/CoroutineDispatchers.kt`
- Create: `re-android/core/model/build.gradle.kts`
- Create: `re-android/core/model/src/main/java/org/moontechlab/selene/core/model/SearchSource.kt`
- Create: `re-android/core/model/src/main/java/org/moontechlab/selene/core/model/VideoCardModel.kt`
- Create: `re-android/core/model/src/main/java/org/moontechlab/selene/core/model/VideoDetail.kt`
- Create: `re-android/core/ui/build.gradle.kts`
- Create: `re-android/core/ui/src/main/java/org/moontechlab/selene/core/ui/theme/SeleneTheme.kt`
- Create: `re-android/core/ui/src/main/java/org/moontechlab/selene/core/ui/adaptive/WindowLayoutInfo.kt`
- Create: `re-android/core/ui/src/main/java/org/moontechlab/selene/core/ui/adaptive/rememberWindowLayoutInfo.kt`
- Test: `re-android/core/common/src/test/java/org/moontechlab/selene/core/common/ResourceTest.kt`

- [ ] **Step 1: 写失败测试，锁定 `Resource` 状态转换**

在 `ResourceTest.kt` 覆盖：
- `Loading`、`Success`、`Error` 的状态和值行为
- `AppError.AuthExpired`、`AppError.Network` 的区分

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core:common:testDebugUnitTest --tests "org.moontechlab.selene.core.common.ResourceTest"`
Expected: FAIL，提示 `Resource` 或 `AppError` 尚未定义

- [ ] **Step 3: 写最小实现**

实现：
- `Resource`、`AppError`、协程调度器接口
- 与 Flutter `SearchResult` / `VideoInfo` 对齐语义的核心模型
- `SeleneTheme` 和手机/平板窗口信息封装

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :core:common:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/core/common re-android/core/model re-android/core/ui
git commit -m "feat: add core common model and ui modules"
```

### Task 3: 建立网络层、Cookie 会话和启动/认证主链路

**Files:**
- Create: `re-android/core/network/build.gradle.kts`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/CookieSessionStore.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/AuthInterceptor.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/SeleneApi.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/DownstreamApi.kt`
- Create: `re-android/core/network/src/main/java/org/moontechlab/selene/core/network/SseSearchClient.kt`
- Create: `re-android/feature/startup/build.gradle.kts`
- Create: `re-android/feature/startup/src/main/java/org/moontechlab/selene/feature/startup/StartupViewModel.kt`
- Create: `re-android/feature/auth/build.gradle.kts`
- Create: `re-android/feature/auth/src/main/java/org/moontechlab/selene/feature/auth/AuthViewModel.kt`
- Create: `re-android/feature/auth/src/main/java/org/moontechlab/selene/feature/auth/AuthRoute.kt`
- Test: `re-android/core/network/src/test/java/org/moontechlab/selene/core/network/CookieSessionStoreTest.kt`
- Test: `re-android/feature/startup/src/test/java/org/moontechlab/selene/feature/startup/StartupViewModelTest.kt`

- [ ] **Step 1: 写失败测试，锁定 Cookie 会话和启动分流**

在 `CookieSessionStoreTest.kt` 覆盖：
- 保存服务器地址、Cookie、本地模式标记
- 读取时保留 `baseUrl + cookie + isLocalMode`

在 `StartupViewModelTest.kt` 覆盖：
- 本地模式时进入首页
- 服务器模式且有有效会话时进入首页
- 无会话或认证失败时进入登录页

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core:network:testDebugUnitTest :feature:startup:testDebugUnitTest --tests "org.moontechlab.selene.core.network.CookieSessionStoreTest" --tests "org.moontechlab.selene.feature.startup.StartupViewModelTest"`
Expected: FAIL，提示会话仓库或启动状态机未实现

- [ ] **Step 3: 写最小实现**

实现：
- Cookie 会话存储与 `AuthInterceptor`
- `SeleneApi` 登录、自动登录、源配置基础接口
- `StartupViewModel` 和 `AuthViewModel` 的状态流
- 认证失效通过状态事件抛给 UI，不在拦截器里直接导航

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :core:network:testDebugUnitTest :feature:startup:testDebugUnitTest :feature:auth:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/core/network re-android/feature/startup re-android/feature/auth
git commit -m "feat: add startup and auth flow"
```

### Task 4: 建立 DataStore、Room 和基础本地数据仓库

**Files:**
- Create: `re-android/core/database/build.gradle.kts`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/SeleneDatabase.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/entity/AuthSessionEntity.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/entity/SearchSourceEntity.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/entity/PlayHistoryEntity.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/entity/FavoriteEntity.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/entity/SearchHistoryEntity.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/dao/PlayHistoryDao.kt`
- Create: `re-android/core/database/src/main/java/org/moontechlab/selene/core/database/dao/FavoriteDao.kt`
- Create: `re-android/core/datastore/build.gradle.kts`
- Create: `re-android/core/datastore/src/main/java/org/moontechlab/selene/core/datastore/AppPreferencesRepository.kt`
- Create: `re-android/core/datastore/src/main/java/org/moontechlab/selene/core/datastore/PlayerPreferencesSerializer.kt`
- Test: `re-android/core/database/src/test/java/org/moontechlab/selene/core/database/SeleneDatabaseMigrationTest.kt`

- [ ] **Step 1: 写失败测试，锁定首版数据库 schema**

在 `SeleneDatabaseMigrationTest.kt` 覆盖：
- 数据库包含 `auth_session`、`search_source`、`play_history`、`favorite_item`、`search_history`
- 从 schema v1 打开数据库成功

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core:database:testDebugUnitTest --tests "org.moontechlab.selene.core.database.SeleneDatabaseMigrationTest"`
Expected: FAIL，提示数据库或 migration 尚未实现

- [ ] **Step 3: 写最小实现**

实现：
- `SeleneDatabase`、核心实体、DAO
- `AppPreferencesRepository` 保存主题、播放器设置、本地模式、显示开关
- 用 Repository 封装数据库访问，不让 feature 直接依赖 DAO

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :core:database:testDebugUnitTest :core:datastore:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/core/database re-android/core/datastore
git commit -m "feat: add persistence layer for re-android"
```

### Task 5: 打通首页、搜索、详情基础链路

**Files:**
- Create: `re-android/feature/home/build.gradle.kts`
- Create: `re-android/feature/home/src/main/java/org/moontechlab/selene/feature/home/HomeViewModel.kt`
- Create: `re-android/feature/home/src/main/java/org/moontechlab/selene/feature/home/HomeRoute.kt`
- Create: `re-android/feature/search/build.gradle.kts`
- Create: `re-android/feature/search/src/main/java/org/moontechlab/selene/feature/search/SearchViewModel.kt`
- Create: `re-android/feature/search/src/main/java/org/moontechlab/selene/feature/search/SearchRepository.kt`
- Create: `re-android/feature/detail/build.gradle.kts`
- Create: `re-android/feature/detail/src/main/java/org/moontechlab/selene/feature/detail/DetailViewModel.kt`
- Create: `re-android/feature/detail/src/main/java/org/moontechlab/selene/feature/detail/DetailRepository.kt`
- Test: `re-android/feature/search/src/test/java/org/moontechlab/selene/feature/search/SearchViewModelTest.kt`
- Test: `re-android/feature/detail/src/test/java/org/moontechlab/selene/feature/detail/DetailViewModelTest.kt`

- [ ] **Step 1: 写失败测试，锁定搜索和详情状态流**

在 `SearchViewModelTest.kt` 覆盖：
- 搜索开始时进入 loading
- 聚合结果按源分组写入 UI 状态
- 搜索历史成功写入本地仓库

在 `DetailViewModelTest.kt` 覆盖：
- 加载详情后得到剧集列表
- 支持选中默认剧集和默认播放源

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :feature:search:testDebugUnitTest :feature:detail:testDebugUnitTest --tests "org.moontechlab.selene.feature.search.SearchViewModelTest" --tests "org.moontechlab.selene.feature.detail.DetailViewModelTest"`
Expected: FAIL，提示 ViewModel、Repository 或状态模型未实现

- [ ] **Step 3: 写最小实现**

实现：
- 首页继续观看、收藏、推荐的基础区块和手机/平板布局壳
- 搜索页输入、历史、结果分组和进入详情
- 详情页封面、简介、剧集、源选择和进入播放器参数

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :feature:home:testDebugUnitTest :feature:search:testDebugUnitTest :feature:detail:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/feature/home re-android/feature/search re-android/feature/detail
git commit -m "feat: add home search and detail features"
```

### Task 6: 建立播放器内核与点播播放器页

**Files:**
- Create: `re-android/core/player/build.gradle.kts`
- Create: `re-android/core/player/src/main/java/org/moontechlab/selene/core/player/VideoPlayerEngine.kt`
- Create: `re-android/core/player/src/main/java/org/moontechlab/selene/core/player/AndroidVideoPlayerEngine.kt`
- Create: `re-android/core/player/src/main/java/org/moontechlab/selene/core/player/PictureInPictureController.kt`
- Create: `re-android/core/player/src/main/java/org/moontechlab/selene/core/player/PlayerSessionCoordinator.kt`
- Create: `re-android/feature/player/build.gradle.kts`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/PlayerViewModel.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/PlayerRoute.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/PlayerUiState.kt`
- Test: `re-android/core/player/src/test/java/org/moontechlab/selene/core/player/AndroidVideoPlayerEngineTest.kt`
- Test: `re-android/feature/player/src/test/java/org/moontechlab/selene/feature/player/PlayerViewModelTest.kt`

- [ ] **Step 1: 写失败测试，锁定播放会话和选集切换**

在 `AndroidVideoPlayerEngineTest.kt` 覆盖：
- `play`、`pause`、`seekTo`、`setPlaybackSpeed` 会正确代理到播放器接口

在 `PlayerViewModelTest.kt` 覆盖：
- 进入播放器页后装载当前剧集
- 切换剧集时更新播放种子和播放记录
- 睡眠定时设置会进入 UI 状态

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core:player:testDebugUnitTest :feature:player:testDebugUnitTest --tests "org.moontechlab.selene.core.player.AndroidVideoPlayerEngineTest" --tests "org.moontechlab.selene.feature.player.PlayerViewModelTest"`
Expected: FAIL，提示播放器引擎和状态协调器未实现

- [ ] **Step 3: 写最小实现**

实现：
- `Media3 ExoPlayer` 封装
- 点播播放器页与非全屏/全屏控制层
- 剧集切换、换源、倍速、画面比例、睡眠定时、PiP 接线
- 播放历史回写

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :core:player:testDebugUnitTest :feature:player:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/core/player re-android/feature/player
git commit -m "feat: add native player stack"
```

### Task 7: 建立解析层、下载规划器和下载页面

**Files:**
- Create: `re-android/core/parser/build.gradle.kts`
- Create: `re-android/core/parser/src/main/java/org/moontechlab/selene/core/parser/M3uPlaylistParser.kt`
- Create: `re-android/core/parser/src/main/java/org/moontechlab/selene/core/parser/M3u8PlaylistParser.kt`
- Create: `re-android/core/parser/src/main/java/org/moontechlab/selene/core/parser/SpecialSourceDetailParser.kt`
- Create: `re-android/core/download/build.gradle.kts`
- Create: `re-android/core/download/src/main/java/org/moontechlab/selene/core/download/M3u8DownloadPlanner.kt`
- Create: `re-android/core/download/src/main/java/org/moontechlab/selene/core/download/SegmentDownloadWorker.kt`
- Create: `re-android/core/download/src/main/java/org/moontechlab/selene/core/download/DownloadForegroundService.kt`
- Create: `re-android/core/download/src/main/java/org/moontechlab/selene/core/download/OfflineCatalog.kt`
- Create: `re-android/feature/downloads/build.gradle.kts`
- Create: `re-android/feature/downloads/src/main/java/org/moontechlab/selene/feature/downloads/DownloadsViewModel.kt`
- Create: `re-android/feature/downloads/src/main/java/org/moontechlab/selene/feature/downloads/DownloadsRoute.kt`
- Test: `re-android/core/parser/src/test/java/org/moontechlab/selene/core/parser/M3u8PlaylistParserTest.kt`
- Test: `re-android/core/download/src/test/java/org/moontechlab/selene/core/download/M3u8DownloadPlannerTest.kt`
- Test: `re-android/feature/downloads/src/test/java/org/moontechlab/selene/feature/downloads/DownloadsViewModelTest.kt`

- [ ] **Step 1: 写失败测试，锁定 M3U8 解析和下载任务规划**

在 `M3u8PlaylistParserTest.kt` 覆盖：
- 解析主 playlist 和 media playlist
- 输出分片 URL、时长和加密信息

在 `M3u8DownloadPlannerTest.kt` 覆盖：
- 根据 playlist 生成分片下载计划
- 支持断点续传时过滤已完成分片

在 `DownloadsViewModelTest.kt` 覆盖：
- 下载中、已完成两个分栏状态
- 删除任务后同步清理离线索引

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :core:parser:testDebugUnitTest :core:download:testDebugUnitTest :feature:downloads:testDebugUnitTest --tests "org.moontechlab.selene.core.parser.M3u8PlaylistParserTest" --tests "org.moontechlab.selene.core.download.M3u8DownloadPlannerTest" --tests "org.moontechlab.selene.feature.downloads.DownloadsViewModelTest"`
Expected: FAIL，提示 parser、planner 或下载状态模型未实现

- [ ] **Step 3: 写最小实现**

实现：
- `M3u` / `M3u8` 解析器
- 下载计划器、Worker、前台通知服务
- 下载列表页和离线播放入口
- 播放器页“加入下载”动作接线

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :core:parser:testDebugUnitTest :core:download:testDebugUnitTest :feature:downloads:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/core/parser re-android/core/download re-android/feature/downloads
git commit -m "feat: add download pipeline and parsers"
```

### Task 8: 建立直播与资源站浏览功能

**Files:**
- Create: `re-android/feature/live/build.gradle.kts`
- Create: `re-android/feature/live/src/main/java/org/moontechlab/selene/feature/live/LiveRepository.kt`
- Create: `re-android/feature/live/src/main/java/org/moontechlab/selene/feature/live/LiveViewModel.kt`
- Create: `re-android/feature/live/src/main/java/org/moontechlab/selene/feature/live/LiveRoute.kt`
- Create: `re-android/feature/sourcebrowser/build.gradle.kts`
- Create: `re-android/feature/sourcebrowser/src/main/java/org/moontechlab/selene/feature/sourcebrowser/SourceBrowserRepository.kt`
- Create: `re-android/feature/sourcebrowser/src/main/java/org/moontechlab/selene/feature/sourcebrowser/SourceBrowserViewModel.kt`
- Create: `re-android/feature/sourcebrowser/src/main/java/org/moontechlab/selene/feature/sourcebrowser/SourceBrowserRoute.kt`
- Test: `re-android/feature/live/src/test/java/org/moontechlab/selene/feature/live/LiveViewModelTest.kt`
- Test: `re-android/feature/sourcebrowser/src/test/java/org/moontechlab/selene/feature/sourcebrowser/SourceBrowserViewModelTest.kt`

- [ ] **Step 1: 写失败测试，锁定频道分组和分类分页**

在 `LiveViewModelTest.kt` 覆盖：
- 直播源加载成功
- 频道按分组聚合
- 频道切换时当前播放频道更新

在 `SourceBrowserViewModelTest.kt` 覆盖：
- 源切换后重置分类和分页
- 选择分类后追加下一页内容

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :feature:live:testDebugUnitTest :feature:sourcebrowser:testDebugUnitTest --tests "org.moontechlab.selene.feature.live.LiveViewModelTest" --tests "org.moontechlab.selene.feature.sourcebrowser.SourceBrowserViewModelTest"`
Expected: FAIL，提示直播和资源站状态机未实现

- [ ] **Step 3: 写最小实现**

实现：
- 直播源、频道分组、频道搜索、EPG 基础展示
- 资源站源切换、分类树、分页列表、进入详情/播放器
- 共用 `core:player` 的播放内核

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :feature:live:testDebugUnitTest :feature:sourcebrowser:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/feature/live re-android/feature/sourcebrowser
git commit -m "feat: add live and source browser features"
```

### Task 9: 建立收藏、历史、设置、弹幕边界和隐藏 benchmark 入口

**Files:**
- Create: `re-android/feature/favorites/build.gradle.kts`
- Create: `re-android/feature/favorites/src/main/java/org/moontechlab/selene/feature/favorites/FavoritesViewModel.kt`
- Create: `re-android/feature/history/build.gradle.kts`
- Create: `re-android/feature/history/src/main/java/org/moontechlab/selene/feature/history/HistoryViewModel.kt`
- Create: `re-android/feature/settings/build.gradle.kts`
- Create: `re-android/feature/settings/src/main/java/org/moontechlab/selene/feature/settings/SettingsViewModel.kt`
- Create: `re-android/feature/settings/src/main/java/org/moontechlab/selene/feature/settings/SettingsRoute.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/danmaku/DanmakuRepository.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/danmaku/DanmakuMatcher.kt`
- Create: `re-android/feature/player/src/main/java/org/moontechlab/selene/feature/player/danmaku/DanmakuSyncController.kt`
- Create: `re-android/feature/benchmark/build.gradle.kts`
- Create: `re-android/feature/benchmark/src/main/java/org/moontechlab/selene/feature/benchmark/BenchmarkRoute.kt`
- Test: `re-android/feature/settings/src/test/java/org/moontechlab/selene/feature/settings/SettingsViewModelTest.kt`
- Test: `re-android/feature/player/src/test/java/org/moontechlab/selene/feature/player/danmaku/DanmakuSyncControllerTest.kt`

- [ ] **Step 1: 写失败测试，锁定设置项和弹幕同步行为**

在 `SettingsViewModelTest.kt` 覆盖：
- 主题、播放器偏好、底部导航显示开关会写入偏好仓库

在 `DanmakuSyncControllerTest.kt` 覆盖：
- seek 后会根据目标时间重建索引
- 暂停/恢复和倍速变化会同步到弹幕状态

- [ ] **Step 2: 运行测试确认失败**

Run: `./gradlew :feature:settings:testDebugUnitTest :feature:player:testDebugUnitTest --tests "org.moontechlab.selene.feature.settings.SettingsViewModelTest" --tests "org.moontechlab.selene.feature.player.danmaku.DanmakuSyncControllerTest"`
Expected: FAIL，提示设置仓库或弹幕同步控制器未实现

- [ ] **Step 3: 写最小实现**

实现：
- 收藏、历史、设置页面和入口
- 播放器设置持久化
- 弹幕匹配、同步和渲染接口边界
- benchmark 隐藏入口路由和开关

- [ ] **Step 4: 运行模块测试**

Run: `./gradlew :feature:favorites:testDebugUnitTest :feature:history:testDebugUnitTest :feature:settings:testDebugUnitTest :feature:player:testDebugUnitTest :feature:benchmark:testDebugUnitTest`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add re-android/feature/favorites re-android/feature/history re-android/feature/settings re-android/feature/benchmark re-android/feature/player
git commit -m "feat: add settings history favorites and danmaku boundaries"
```

### Task 10: 组装整机回归、格式化和文档补全

**Files:**
- Modify: `re-android/README.md`
- Modify: `docs/superpowers/plans/2026-04-01-re-android-native-rebuild.md`

- [ ] **Step 1: 运行首轮关键单测集合**

Run: `./gradlew testDebugUnitTest`
Expected: PASS

- [ ] **Step 2: 运行 Compose 与导航相关检查**

Run: `./gradlew :app:assembleDebug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: 运行代码格式和静态检查**

Run: `./gradlew lintDebug`
Expected: 没有阻塞性 error

- [ ] **Step 4: 更新 README 和剩余风险**

在 `re-android/README.md` 记录：
- 模块结构
- 运行方式
- 当前未完全追平的能力，如 DLNA 深度控制、benchmark 完整体验、弹幕渲染性能优化

- [ ] **Step 5: 提交**

```bash
git add re-android/README.md docs/superpowers/plans/2026-04-01-re-android-native-rebuild.md
git commit -m "docs: finalize re-android implementation notes"
```

## 本地审查清单

执行本计划时，每完成一个任务都要检查：

1. 是否仍然遵守 `docs/superpowers/specs/2026-04-01-re-android-native-rebuild-design.md`
2. 是否把状态逻辑写进了 `ViewModel` 而不是 Compose 页面
3. 是否让 feature 直接依赖了 DAO 或 Retrofit 接口；若有，立即回收进 Repository
4. 是否新增了无法测试的全局单例；若有，立即改为接口注入
5. 是否在手机和平板布局上都至少保留基础可用性

## 风险记录

1. `Media3`、前台下载服务、WorkManager 和 Room 同时落地时，初版编译配置最容易出错，必须优先保持工程可装配。
2. 若下载模块过早追求并发调优，可能拖慢首轮主链路；应先保证计划生成、分片入库和状态可视化。
3. 弹幕和 DLNA 很容易演变成第二个复杂中心，本轮只允许先建稳定边界和基础同步能力。
