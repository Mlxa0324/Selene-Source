# re-android Kotlin 原生 TV 重建实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `re-android/` 下重建一套 Kotlin 原生 Android TV 工程，对齐现有 Flutter TV 端页面和交互，并以 `ExoPlayer 主内核 + WebView 兜底` 跑通全屏播放与内核切换主链路。

**架构：** 先搭建 `app-tv + core-* + feature-tv-*` 的独立多模块工程，再用 `core-player-api` 抽象播放器协议，让 `core-player-exo` 和 `core-player-webview` 复用同一套全屏播放器壳。页面层用 Compose for TV 和统一线程调度器组织 UI、数据加载、播放控制和切内核状态机，避免主线程承接解析、预热和状态恢复等重活。

**技术栈：** Kotlin、Jetpack Compose、Navigation Compose、androidx.tv.material3、ViewModel、Coroutines、StateFlow、Retrofit、OkHttp、DataStore、Room、Media3 ExoPlayer、Android WebView、JUnit4、kotlinx-coroutines-test、Compose UI Test

---

## 范围说明

本计划只覆盖首期原生 TV 已确认范围：

1. `首页 / 搜索 / 详情 / 播放历史 / 收藏夹 / 设置 / 全屏播放器`
2. `直播` 只保留占位页
3. 不包含 `DLNA / 本地离线`
4. 默认播放内核是 `ExoPlayer`
5. 全屏底部菜单 `其它 -> 内核切换 -> ExoPlayer / WebView`
6. 切换语义为软重载，切换后恢复到当前全屏、当前集、当前线路、当前进度附近

## 文件地图

**Spec：**
- `/Volumes/My2TDrive/StudioProjects/Selene-Source/docs/superpowers/specs/2026-05-30-re-android-tv-native-player-design.md`

**Workspace root：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/settings.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/gradle.properties`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/gradle/libs.versions.toml`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/.gitignore`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/README.md`

**App shell：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/AndroidManifest.xml`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/SeleneTvApplication.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/MainActivity.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/navigation/TvDestination.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/navigation/TvNavGraph.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvApp.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/navigation/TvDestinationTest.kt`

**Core design and threading：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTheme.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTokens.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/focus/TvFocusableCard.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignPreset.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignMetrics.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/threading/AppDispatchers.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/threading/DispatcherProvider.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/test/java/org/moontechlab/selene/tv/core/design/threading/DispatcherProviderTest.kt`

**Core data and network：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneTvApi.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/AuthInterceptor.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SessionCookieStore.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/model/TvHomeResponse.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvHomeSection.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvVideoCard.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvVideoDetail.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvSearchPayload.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvHomeRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvSearchRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvPlaybackRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvSettingsRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/storage/TvDatabase.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/storage/TvPreferencesStore.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/test/java/org/moontechlab/selene/tv/core/network/SessionCookieStoreTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/TvHomeRepositoryTest.kt`

**Player modules：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlaybackRequest.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlaybackSnapshot.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlayerState.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerFactory.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerBridge.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/assets/player/hls_player.html`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/assets/player/hls.min.js`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/test/java/org/moontechlab/selene/tv/core/player/api/PlaybackSnapshotTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/test/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerEngineTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/test/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerBridgeTest.kt`

**Feature modules：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/src/main/java/org/moontechlab/selene/tv/feature/history/TvHistoryViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/src/main/java/org/moontechlab/selene/tv/feature/history/TvHistoryRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-live/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-live/src/main/java/org/moontechlab/selene/tv/feature/live/TvLiveRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcher.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-benchmark/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-benchmark/src/main/java/org/moontechlab/selene/tv/core/benchmark/PlayerBenchmarkRecorder.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/test/java/org/moontechlab/selene/tv/feature/home/TvHomeViewModelTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/test/java/org/moontechlab/selene/tv/feature/search/TvSearchViewModelTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModelTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcherTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/androidTest/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteTest.kt`

**命令约定：**
- 所有 Gradle 命令都在 `/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android` 目录执行。

### 任务 1：重建 `re-android` Gradle 多模块工程与 TV 导航壳

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/settings.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/gradle.properties`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/gradle/libs.versions.toml`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/.gitignore`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/README.md`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/AndroidManifest.xml`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/SeleneTvApplication.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/MainActivity.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/navigation/TvDestination.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/navigation/TvNavGraph.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvApp.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/navigation/TvDestinationTest.kt`

- [ ] **步骤 1：编写失败的路由测试**

```kotlin
class TvDestinationTest {
    @Test
    fun topLevelDestinations_expose_expected_routes() {
        val routes = TvDestination.topLevelDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "home",
            "search",
            "history",
            "favorites",
            "settings",
            "live"
        )
    }

    @Test
    fun fullscreen_player_route_is_hidden_from_top_level_tabs() {
        assertThat(TvDestination.Player.route).isEqualTo("player/{videoId}")
        assertThat(TvDestination.topLevelDestinations).doesNotContain(TvDestination.Player)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :app-tv:testDebugUnitTest --tests "org.moontechlab.selene.tv.app.navigation.TvDestinationTest"`
预期：FAIL，提示 `TvDestination` 或 `topLevelDestinations` 尚未实现。

- [ ] **步骤 3：编写最小工程壳与导航实现**

```kotlin
sealed class TvDestination(val route: String) {
    data object Home : TvDestination("home")
    data object Search : TvDestination("search")
    data object History : TvDestination("history")
    data object Favorites : TvDestination("favorites")
    data object Settings : TvDestination("settings")
    data object Live : TvDestination("live")
    data object Player : TvDestination("player/{videoId}")

    companion object {
        val topLevelDestinations = listOf(Home, Search, History, Favorites, Settings, Live)
    }
}
```

```kotlin
@Composable
fun TvApp() {
    val navController = rememberNavController()
    TvNavGraph(navController = navController)
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :app-tv:testDebugUnitTest --tests "org.moontechlab.selene.tv.app.navigation.TvDestinationTest"`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/settings.gradle.kts re-android/build.gradle.kts re-android/gradle.properties re-android/gradle/libs.versions.toml re-android/.gitignore re-android/README.md re-android/app-tv
git commit -m "feat(re-android): 初始化tv原生工程壳"
```

### 任务 2：建立 TV 设计标尺、焦点组件与线程调度器

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTheme.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTokens.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/focus/TvFocusableCard.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignPreset.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignMetrics.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/threading/AppDispatchers.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/threading/DispatcherProvider.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-design/src/test/java/org/moontechlab/selene/tv/core/design/threading/DispatcherProviderTest.kt`

- [ ] **步骤 1：编写失败的线程调度测试**

```kotlin
class DispatcherProviderTest {
    @Test
    fun provider_exposes_distinct_dispatchers_for_ui_playback_io_and_default() {
        val provider = TestDispatcherProvider()

        assertThat(provider.main).isNotSameInstanceAs(provider.playback)
        assertThat(provider.playback).isNotSameInstanceAs(provider.io)
        assertThat(provider.io).isNotSameInstanceAs(provider.default)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :core-design:testDebugUnitTest --tests "org.moontechlab.selene.tv.core.design.threading.DispatcherProviderTest"`
预期：FAIL，提示 `DispatcherProvider` 尚未实现。

- [ ] **步骤 3：编写最小设计与调度实现**

```kotlin
interface DispatcherProvider {
    val main: CoroutineDispatcher
    val playback: CoroutineDispatcher
    val io: CoroutineDispatcher
    val default: CoroutineDispatcher
}

data class AppDispatchers(
    override val main: CoroutineDispatcher,
    override val playback: CoroutineDispatcher,
    override val io: CoroutineDispatcher,
    override val default: CoroutineDispatcher
) : DispatcherProvider
```

```kotlin
enum class TvDesignPreset {
    HD720,
    FULL_HD_1080
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :core-design:testDebugUnitTest --tests "org.moontechlab.selene.tv.core.design.threading.DispatcherProviderTest"`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/core-design
git commit -m "feat(re-android): 建立tv设计与线程基座"
```

### 任务 3：建立网络层、数据模型与本地仓库

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SeleneTvApi.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/AuthInterceptor.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/main/java/org/moontechlab/selene/tv/core/network/SessionCookieStore.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvHomeSection.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvVideoCard.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/model/TvVideoDetail.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvHomeRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvSearchRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvPlaybackRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvSettingsRepository.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/storage/TvDatabase.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/storage/TvPreferencesStore.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-network/src/test/java/org/moontechlab/selene/tv/core/network/SessionCookieStoreTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/TvHomeRepositoryTest.kt`

- [ ] **步骤 1：编写失败的会话与首页仓库测试**

```kotlin
class SessionCookieStoreTest {
    @Test
    fun saveSession_persists_base_url_account_and_cookie() = runTest {
        val store = SessionCookieStore(fakePreferences)

        store.saveSession(
            baseUrl = "https://example.com",
            account = "demo",
            cookie = "sid=1"
        )

        assertThat(store.readSession()?.baseUrl).isEqualTo("https://example.com")
        assertThat(store.readSession()?.account).isEqualTo("demo")
        assertThat(store.readSession()?.cookie).isEqualTo("sid=1")
    }
}
```

```kotlin
class TvHomeRepositoryTest {
    @Test
    fun loadHome_aggregates_continue_watching_and_hot_sections() = runTest {
        val payload = repository.loadHome()

        assertThat(payload.sections.map { it.key }).containsAtLeast(
            "continue_watching",
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows"
        )
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :core-network:testDebugUnitTest :core-data:testDebugUnitTest --tests "org.moontechlab.selene.tv.core.network.SessionCookieStoreTest" --tests "org.moontechlab.selene.tv.core.data.repository.TvHomeRepositoryTest"`
预期：FAIL，提示会话存储或首页仓库尚未实现。

- [ ] **步骤 3：编写最小网络与仓库实现**

```kotlin
data class SessionPayload(
    val baseUrl: String,
    val account: String,
    val cookie: String
)

interface SeleneTvApi {
    @GET("admin/dashboard")
    suspend fun getDashboard(): TvHomeResponse
}
```

```kotlin
class TvHomeRepository(
    private val api: SeleneTvApi,
    private val playbackRepository: TvPlaybackRepository
) {
    suspend fun loadHome(): TvHomePayload {
        val remote = api.getDashboard()
        return remote.toHomePayload(playbackRepository.readContinueWatching())
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :core-network:testDebugUnitTest :core-data:testDebugUnitTest`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/core-network re-android/core-data
git commit -m "feat(re-android): 打通tv数据与网络层"
```

### 任务 4：建立播放器协议、ExoPlayer 主内核与 seek 调度器

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlaybackRequest.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlaybackSnapshot.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/main/java/org/moontechlab/selene/tv/core/player/api/PlayerState.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerFactory.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-api/src/test/java/org/moontechlab/selene/tv/core/player/api/PlaybackSnapshotTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-exo/src/test/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerEngineTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt`

- [ ] **步骤 1：编写失败的播放器协议与 seek 规则测试**

```kotlin
class PlaybackSnapshotTest {
    @Test
    fun snapshot_keeps_source_episode_position_speed_and_resize_mode() {
        val snapshot = PlaybackSnapshot(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-3",
            url = "https://cdn.test/3.m3u8",
            positionMs = 92_000L,
            durationMs = 1_800_000L,
            playbackSpeed = 1.25f,
            resizeMode = TvResizeMode.FIT
        )

        assertThat(snapshot.episodeId).isEqualTo("ep-3")
        assertThat(snapshot.positionMs).isEqualTo(92_000L)
        assertThat(snapshot.playbackSpeed).isEqualTo(1.25f)
    }
}
```

```kotlin
class TvSeekControllerTest {
    @Test
    fun longPress_seek_delta_accelerates_after_threshold() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 100)).isEqualTo(5)
        assertThat(controller.computeDeltaSeconds(holdMs = 2400)).isGreaterThan(5)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :core-player-api:testDebugUnitTest :core-player-exo:testDebugUnitTest :feature-tv-player:testDebugUnitTest --tests "org.moontechlab.selene.tv.core.player.api.PlaybackSnapshotTest" --tests "org.moontechlab.selene.tv.core.player.exo.ExoPlayerEngineTest" --tests "org.moontechlab.selene.tv.feature.player.TvSeekControllerTest"`
预期：FAIL，提示播放器协议、ExoPlayerEngine 或 seek 控制器尚未实现。

- [ ] **步骤 3：编写最小播放器协议与 Exo 主内核**

```kotlin
interface PlayerEngine {
    suspend fun load(request: PlaybackRequest)
    suspend fun play()
    suspend fun pause()
    suspend fun seekTo(positionMs: Long)
    suspend fun captureSnapshot(): PlaybackSnapshot
    suspend fun restoreSnapshot(snapshot: PlaybackSnapshot)
    suspend fun release()
    val state: StateFlow<PlayerState>
}
```

```kotlin
class ExoPlayerEngine(
    private val exoPlayer: ExoPlayer,
    private val dispatchers: DispatcherProvider
) : PlayerEngine {
    override suspend fun seekTo(positionMs: Long) = withContext(dispatchers.playback) {
        exoPlayer.seekTo(positionMs)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :core-player-api:testDebugUnitTest :core-player-exo:testDebugUnitTest :feature-tv-player:testDebugUnitTest`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/core-player-api re-android/core-player-exo re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvSeekController.kt re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvSeekControllerTest.kt
git commit -m "feat(re-android): 建立exo主播放器链路"
```

### 任务 5：跑通首页、搜索、历史、收藏、设置与直播占位页

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/src/main/java/org/moontechlab/selene/tv/feature/history/TvHistoryViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-history/src/main/java/org/moontechlab/selene/tv/feature/history/TvHistoryRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-favorites/src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-settings/src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-live/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-live/src/main/java/org/moontechlab/selene/tv/feature/live/TvLiveRoute.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-home/src/test/java/org/moontechlab/selene/tv/feature/home/TvHomeViewModelTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-search/src/test/java/org/moontechlab/selene/tv/feature/search/TvSearchViewModelTest.kt`

- [ ] **步骤 1：编写失败的首页与搜索状态测试**

```kotlin
class TvHomeViewModelTest {
    @Test
    fun loadHome_emits_sections_and_preserves_selected_tab() = runTest {
        val viewModel = buildViewModel()

        viewModel.load()

        assertThat(viewModel.state.value.sections).isNotEmpty()
        assertThat(viewModel.state.value.selectedMainTab).isEqualTo("home")
    }
}
```

```kotlin
class TvSearchViewModelTest {
    @Test
    fun submitQuery_updates_history_and_search_results() = runTest {
        val viewModel = buildViewModel()

        viewModel.submitQuery("剑来")

        assertThat(viewModel.state.value.searchHistory).contains("剑来")
        assertThat(viewModel.state.value.resultGroups).isNotEmpty()
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :feature-tv-home:testDebugUnitTest :feature-tv-search:testDebugUnitTest --tests "org.moontechlab.selene.tv.feature.home.TvHomeViewModelTest" --tests "org.moontechlab.selene.tv.feature.search.TvSearchViewModelTest"`
预期：FAIL，提示首页或搜索 ViewModel 尚未实现。

- [ ] **步骤 3：编写最小页面与 ViewModel 实现**

```kotlin
data class TvHomeUiState(
    val selectedMainTab: String = "home",
    val sections: List<TvHomeSection> = emptyList()
)
```

```kotlin
@Composable
fun TvLiveRoute() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(text = "正在开发")
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :feature-tv-home:testDebugUnitTest :feature-tv-search:testDebugUnitTest :feature-tv-history:testDebugUnitTest :feature-tv-favorites:testDebugUnitTest :feature-tv-settings:testDebugUnitTest`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/feature-tv-home re-android/feature-tv-search re-android/feature-tv-history re-android/feature-tv-favorites re-android/feature-tv-settings re-android/feature-tv-live
git commit -m "feat(re-android): 完成tv基础页面主链"
```

### 任务 6：跑通详情页、预览播放、播放记录与全屏播放器壳

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerViewModel.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerRoute.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/TvDetailViewModelTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/androidTest/java/org/moontechlab/selene/tv/feature/player/TvPlayerRouteTest.kt`

- [ ] **步骤 1：编写失败的详情与全屏壳测试**

```kotlin
class TvDetailViewModelTest {
    @Test
    fun loadDetail_sets_current_source_and_current_episode() = runTest {
        val viewModel = buildViewModel()

        viewModel.load(videoId = "video-1")

        assertThat(viewModel.state.value.currentSourceId).isNotEmpty()
        assertThat(viewModel.state.value.currentEpisodeId).isNotEmpty()
    }
}
```

```kotlin
@Test
fun player_route_opens_other_menu_and_shows_engine_switch_entry() {
    composeRule.setContent { TvPlayerRoute(fakeViewModel) }

    composeRule.onNodeWithTag("tv-player-menu-other").performClick()
    composeRule.onNodeWithText("内核切换").assertExists()
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :feature-tv-detail:testDebugUnitTest :feature-tv-player:connectedDebugAndroidTest`
预期：FAIL，提示详情状态或全屏菜单入口尚未实现。

- [ ] **步骤 3：编写最小详情与全屏播放器壳实现**

```kotlin
data class TvDetailUiState(
    val currentSourceId: String = "",
    val currentEpisodeId: String = "",
    val recommendCards: List<TvVideoCard> = emptyList()
)
```

```kotlin
data class TvPlayerUiState(
    val isMenuVisible: Boolean = false,
    val selectedTopMenu: String = "播放列表",
    val selectedOtherMenuItem: String = "内核切换"
)
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :feature-tv-detail:testDebugUnitTest :feature-tv-player:connectedDebugAndroidTest`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/feature-tv-detail re-android/feature-tv-player
git commit -m "feat(re-android): 打通详情与全屏播放器壳"
```

### 任务 7：接入 WebView 兜底、全屏内核切换与 benchmark

**文件：**
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerEngine.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerBridge.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/assets/player/hls_player.html`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/main/assets/player/hls.min.js`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcher.kt`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-benchmark/build.gradle.kts`
- 创建：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-benchmark/src/main/java/org/moontechlab/selene/tv/core/benchmark/PlayerBenchmarkRecorder.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/core-player-webview/src/test/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerBridgeTest.kt`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcherTest.kt`

- [ ] **步骤 1：编写失败的桥接与切换状态机测试**

```kotlin
class TvPlayerEngineSwitcherTest {
    @Test
    fun switchEngine_restores_snapshot_on_target_engine() = runTest {
        val switcher = buildSwitcher()

        switcher.switchTo(PlayerKernel.WEB_VIEW)

        assertThat(fakeWebViewEngine.restoredSnapshot?.sourceId).isEqualTo("source-a")
        assertThat(fakeWebViewEngine.restoredSnapshot?.positionMs).isEqualTo(92_000L)
    }
}
```

```kotlin
class WebViewPlayerBridgeTest {
    @Test
    fun onPlaybackEvent_maps_js_payload_to_player_state() {
        val bridge = WebViewPlayerBridge()

        val state = bridge.mapEvent("""{"positionMs":1200,"durationMs":2400,"isPlaying":true}""")

        assertThat(state.positionMs).isEqualTo(1200L)
        assertThat(state.isPlaying).isTrue()
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew :core-player-webview:testDebugUnitTest :feature-tv-player:testDebugUnitTest --tests "org.moontechlab.selene.tv.core.player.webview.WebViewPlayerBridgeTest" --tests "org.moontechlab.selene.tv.feature.player.TvPlayerEngineSwitcherTest"`
预期：FAIL，提示 WebView bridge 或切换状态机尚未实现。

- [ ] **步骤 3：编写最小 WebView 兜底与切换实现**

```kotlin
class TvPlayerEngineSwitcher(
    private val exoEngine: PlayerEngine,
    private val webViewEngine: PlayerEngine,
    private val dispatchers: DispatcherProvider
) {
    suspend fun switchTo(target: PlayerKernel) = withContext(dispatchers.playback) {
        val current = activeEngine.captureSnapshot()
        val next = when (target) {
            PlayerKernel.EXO_PLAYER -> exoEngine
            PlayerKernel.WEB_VIEW -> webViewEngine
        }
        next.load(current.toPlaybackRequest())
        next.restoreSnapshot(current)
        activeEngine.release()
        activeEngine = next
    }
}
```

```kotlin
class PlayerBenchmarkRecorder {
    fun record(event: PlayerBenchmarkEvent) {
        // 记录 seek、切源、切内核耗时，为后续缩减 WebView 使用范围提供依据。
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew :core-player-webview:testDebugUnitTest :feature-tv-player:testDebugUnitTest :core-benchmark:testDebugUnitTest`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add re-android/core-player-webview re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcher.kt re-android/feature-tv-player/src/test/java/org/moontechlab/selene/tv/feature/player/TvPlayerEngineSwitcherTest.kt re-android/core-benchmark
git commit -m "feat(re-android): 接入webview兜底与内核切换"
```

### 任务 8：执行整体验证与文档收口

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/re-android/README.md`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/docs/superpowers/plans/2026-05-30-re-android-tv-native-player.md`

- [ ] **步骤 1：运行 JVM 单测**

运行：`./gradlew testDebugUnitTest`
预期：PASS。

- [ ] **步骤 2：运行播放器与菜单 Android 测试**

运行：`./gradlew :feature-tv-player:connectedDebugAndroidTest`
预期：PASS。

- [ ] **步骤 3：执行静态检查**

运行：`./gradlew lintDebug`
预期：PASS。

- [ ] **步骤 4：执行 diff 检查**

运行：`git diff --check -- re-android docs/superpowers/plans/2026-05-30-re-android-tv-native-player.md`
预期：无输出。

- [ ] **步骤 5：Commit**

```bash
git add re-android docs/superpowers/plans/2026-05-30-re-android-tv-native-player.md
git commit -m "feat(re-android): 完成tv原生重建首期"
```

