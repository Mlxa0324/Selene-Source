# 设计：Kotlin TV 骨架搭建

## Directory Layout

```
kotlin-tv/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
├── local.gateway.properties.example
├── app/
│   └── app-tv/
│       └── src/main/java/uk/oxiang/ivy/tv/app/
│           ├── TvApp.kt
│           ├── TvAppContainer.kt
│           └── navigation/
│               ├── TvDestination.kt
│               └── TvNavGraph.kt
├── core/
│   ├── core-common/
│   │   └── src/main/java/uk/oxiang/ivy/tv/core/common/
│   │       ├── network/       # SeleneTvApi, SeleneDanmakuApi, SeleneDoubanApi, SeleneTvAuthApi, DTO, SessionCookieStore, AuthInterceptor, SeleneTvNetworkClient
│   │       ├── repository/    # TvHomeRepository, TvSearchRepository, TvDetailRepository, ...
│   │       ├── model/         # 业务模型（TvVideoCard, TvVideoDetail, TvHomeSection...）
│   │       └── storage/       # TvPreferencesStore (DataStore), TvDatabase
│   ├── core-design/
│   │   └── src/main/java/uk/oxiang/ivy/tv/core/design/
│   │       ├── TvTokens.kt, TvTheme.kt, TvLayout.kt
│   │       ├── canvas/         # TvDesignPreset, TvDesignMetrics, TvDesignCanvas（等比缩放系统，对齐 Flutter tv_design_canvas.dart）
│   │       ├── focus/          # TvFocusableCard, TvFocusMemoryRegistry, TvRemotePressPolicy
│   │       ├── layout/         # TvPageScaffold, TvPageSection, TvPosterCard/Grid/Rail/FocusGroup, TvForm*, TvStatePanel, TvEmptyStatePanel, TvSkeleton, TvActionNotice, TvConfirmDialog, TvQrCodeSection
│   │       └── util/           # TvListLayoutMetrics, AppDispatchers, DispatcherProvider
│   └── core-player/
│       └── src/main/java/uk/oxiang/ivy/tv/core/player/
│           ├── api/     # PlayerEngine, PlaybackRequest, PlaybackSnapshot, PlayerState
│           ├── exo/      # ExoPlayerEngine, ExoPlayerFactory, ExoPlayerAdapter
│           └── webview/  # WebViewPlayerEngine, WebViewPlayerBridge, WebViewPlayerSession, WebViewPlayerCommand, WebViewPlayerSurface
└── feature/   # 占位 include，实际内容由各 feature 子任务落地
```

## Gradle Settings

```kotlin
// kotlin-tv/settings.gradle.kts
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "kotlin-tv"

include(":app:app-tv")
include(":core:core-common")
include(":core:core-design")
include(":core:core-player")
include(":feature:feature-home")
include(":feature:feature-detail")
include(":feature:feature-player")
include(":feature:feature-search")
include(":feature:feature-settings")
include(":feature:feature-content")

project(":app:app-tv").projectDir = file("app/app-tv")
project(":core:core-common").projectDir = file("core/core-common")
project(":core:core-design").projectDir = file("core/core-design")
project(":core:core-player").projectDir = file("core/core-player")
project(":feature:feature-home").projectDir = file("feature/feature-home")
project(":feature:feature-detail").projectDir = file("feature/feature-detail")
project(":feature:feature-player").projectDir = file("feature/feature-player")
project(":feature:feature-search").projectDir = file("feature/feature-search")
project(":feature:feature-settings").projectDir = file("feature/feature-settings")
project(":feature:feature-content").projectDir = file("feature/feature-content")
```

本任务只创建 `app-tv`、`core-common`、`core-design`、`core-player` 四个模块的真实内容；`feature/*` 模块先建最小骨架（空 `build.gradle.kts` + 一个占位 Composable），避免 `include` 声明后找不到模块导致构建失败，具体实现留给各 feature 子任务。

## Module Dependency Rules

```
core-common  (无内部依赖，仅第三方库)
core-design  (无内部依赖，仅第三方库)
core-player  -> core-design（WebView 播放层用到 Compose 组件时可复用设计令牌，非强制）
app-tv       -> core-common, core-design, core-player, feature-*
feature-*    -> core-common, core-design, core-player（不相互依赖）
```

约束延续 `re-android` 已验证规则：network 层 DTO 与 data 层业务模型分离，Repository 负责映射；`feature-*` 不得直接读取 `BuildConfig` 或本地配置文件，统一通过 `app-tv` 组装的 `TvAppContainer` 消费。

## core-common: DataStore-backed Preferences

```kotlin
class TvPreferencesStore(private val dataStore: DataStore<Preferences>) {
    suspend fun saveSession(baseUrl: String, account: String, cookie: String)
    suspend fun loadSession(): TvServerConfig?
    suspend fun saveDanmakuManualMatch(record: TvDanmakuManualMatchRecord)
    suspend fun loadDanmakuManualMatches(): Map<String, TvDanmakuManualMatchRecord>
    suspend fun saveThemePaletteKey(key: String)
    fun themePaletteKeyFlow(): Flow<String>
    suspend fun saveThemeBackgroundKey(key: String)
    fun themeBackgroundKeyFlow(): Flow<String>
    suspend fun saveFocusEffectModeKey(key: String)
    fun focusEffectModeKeyFlow(): Flow<String>
    // 其余字段（图片代理/去广告/弹幕地址等）按 feature-settings 消费需要逐步补充 key
}
```

依赖 `androidx.datastore:datastore-preferences`，`app-tv` 的 `Context.dataStore` 扩展属性做单例绑定，通过 `TvAppContainer` 构造函数注入到 Repository。

## core-design: Theme Tokens（对齐 Flutter `TvThemeService` 三维独立主题体系）

`re-android` 只做了单一主题色维度，Flutter 端 `TvThemeService`（`lib/tv_app/services/tv_theme_service.dart`）实际有 3 组互相独立、各自持久化的可切换维度，Kotlin 版必须完整落地：

```kotlin
// 维度 1：主题色（accent palette），默认奈飞红（不是 Ivy 绿）
enum class TvThemePaletteKey(val storageKey: String) {
    NETFLIX_RED("netflix_red"), IVY_GREEN("ivy_green"), SOFT_BLUE("soft_blue")
}

data class TvThemePalette(
    val key: TvThemePaletteKey,
    val label: String,
    val accent: Color,
    val focus: Color,
    val focusFill: Color,
    val disabledFill: Color,
    val selectedText: Color,
)

object TvThemePaletteCatalog {
    val netflixRed = TvThemePalette(TvThemePaletteKey.NETFLIX_RED, "奈飞红", accent = Color(0xFFE50914), focus = Color(0xFFFF3B45), ...)
    val ivyGreen = TvThemePalette(TvThemePaletteKey.IVY_GREEN, "Ivy 绿", accent = Color(0xFF26C96F), focus = Color(0xFF42D37B), ...)
    val softBlue = TvThemePalette(TvThemePaletteKey.SOFT_BLUE, "柔和蓝", accent = Color(0xFF5B7CFA), focus = Color(0xFF7F99FF), ...)
    val all = listOf(netflixRed, ivyGreen, softBlue)
    val default = netflixRed
}

// 维度 2：页面背景色，默认深蓝灰（不是深黑夜幕）
enum class TvThemeBackgroundKey(val storageKey: String) { DEEP_BLUE("deep_blue"), DEEP_BLACK("deep_black") }
data class TvThemeBackground(val key: TvThemeBackgroundKey, val label: String, val color: Color)
object TvThemeBackgroundCatalog {
    val deepBlue = TvThemeBackground(TvThemeBackgroundKey.DEEP_BLUE, "深蓝灰", Color(0xFF1A1D29))
    val deepBlack = TvThemeBackground(TvThemeBackgroundKey.DEEP_BLACK, "深黑夜幕", Color(0xFF0A0D0E))
    val all = listOf(deepBlue, deepBlack)
    val default = deepBlue
}

// 维度 3：卡片焦点效果模式，默认放大镜模式
enum class TvFocusEffectMode(val storageKey: String) { MAGNIFIER("magnifier"), SMOOTH_FRAME("smooth_frame") }
// magnifier：卡片自身缩放+焦点框；smooth_frame：跨卡片共享外边框平滑移动
val defaultFocusEffectMode = TvFocusEffectMode.MAGNIFIER

val LocalTvThemePalette = compositionLocalOf { TvThemePaletteCatalog.default }
val LocalTvThemeBackground = compositionLocalOf { TvThemeBackgroundCatalog.default }
val LocalTvFocusEffectMode = compositionLocalOf { defaultFocusEffectMode }
```

三组维度各自独立持久化（`TvPreferencesStore` 中 3 个不同 key：`themePaletteKey`/`themeBackgroundKey`/`focusEffectModeKey`），互不影响。`app-tv` 顶层根据 DataStore 读取的三个 key 分别提供对应值给三个 `CompositionLocal`。

需要额外提供 `TvTheme.wrapScope`（Compose 版）：用于 `Navigation Compose` 的新路由或 `Dialog` 组合创建的子树，透传当前三组 `CompositionLocal` 值和设计画布 scale/designSize，避免独立弹窗/路由脱离父级主题作用域（对应 Flutter `TvTheme.wrapScope` 语义）。

## core-design: TvDesignCanvas（对齐 Flutter 自适应缩放系统，`re-android` 无对应实现）

对齐 `lib/tv_app/widgets/tv_design_canvas.dart`，4 个预设：`auto`/`hd720(1280x720)`/`fullHd1080(1920x1080)`/`qhd1440(2560x1440)`。`auto` 按当前视口从高到低匹配预设（>=1440p 用 1440p 设计稿，>=1080p 用 1080p，否则回退 720p）；只在视口小于设计稿时等比缩小（`scale = min(1, min(widthScale, heightScale))`），不会因视口更大而放大。

```kotlin
enum class TvDesignPreset(val designWidth: Int, val designHeight: Int) {
    AUTO(0, 0), HD720(1280, 720), FULL_HD1080(1920, 1080), QHD1440(2560, 1440)
}

data class TvDesignMetrics(val scale: Float, val designSize: IntSize)

val LocalTvDesignMetrics = compositionLocalOf { TvDesignMetrics(1f, IntSize(1920, 1080)) }

@Composable
fun TvDesignCanvas(preset: TvDesignPreset = TvDesignPreset.AUTO, content: @Composable () -> Unit) {
    // 用 BoxWithConstraints 取实际视口宽高，计算 scale/designSize，
    // 通过 Modifier.graphicsLayer(scaleX = scale, scaleY = scale) 包裹固定尺寸约束容器，
    // 内部 content() 按设计稿坐标系开发，不需要感知实际设备分辨率。
    // CompositionLocalProvider(LocalTvDesignMetrics provides metrics) { ... }
}
```

`TvLayout` 全局布局常量（对齐 `lib/tv_app/tv_layout.dart`）：

```kotlin
object TvLayout {
    const val pageHorizontalPadding = 46
    const val gridCrossAxisCount = 7
}
```

## core-design: TvFocusableCard（以 Flutter `TvFocusable` 完整能力为目标）

`re-android` 的 `TvFocusableCard` 只对齐了 Flutter `TvFocusable`（`lib/tv_app/widgets/tv_focusable.dart`）的短按/长按判定和多焦点节点共享这两点，Kotlin 版必须补齐 Flutter 版本的全部能力，不能停留在 `re-android` 的子集：

1. **短按/长按判定**（`re-android` 已覆盖，沿用该模式）：`onPreviewKeyEvent` 拦截 `DirectionCenter`/`Enter` 的 `KeyDown`/`KeyUp`，长按用 Compose 的按键重复事件或手动计时判定，短按在未触发长按的 `KeyUp` 时回落，防止一次物理按压重复触发业务；多个 `FocusRequester` 通过 `fold` 共享同一真实焦点节点。
2. **焦点记忆分组**（对齐 `focusMemoryGroupKey`，`re-android` 缺失，需新增）：每个分组维护"最近一次真实获焦项"的记忆（用 `mutableStateMapOf<groupKey, itemKey>` 或类似的分组级单例状态承载）。跨组上下方向移动时优先回到目标分组的记忆项，其次回退到分组内第一个可聚焦项（排序规则"先上后下、同行从左到右"）。对应 Flutter 端静态方法 `clearLastFocusedForGroup`/`resetGroupEntryToFirstFocusable`/`groupHasFocusedChild`/`requestRememberedFocusForGroup` 需要在 Kotlin 侧找到等价的分组注册表设计（可用一个 `TvFocusMemoryRegistry` object 持有 `Map<groupKey, FocusMemoryEntry>`）。
3. **方向键长按节流分组**（对齐 `directionalRepeatThrottleGroupKey`，`re-android` 缺失，需新增）：纯文字列表长按方向键时按分组节流重复事件（默认 120ms），避免跳过中间选中态；卡片网格/主导航/播放器菜单等非文字列表不启用节流（保持原生重复速率）。用一个可选参数 `directionalRepeatThrottleGroupKey: String?` 控制是否启用，节流状态按分组 key 独立维护最后触发时间戳。
4. **获焦自动滚动**（对齐 `autoScrollOnFocus`/`focusScrollAlignment`/`horizontalFocusScrollTriggerFraction`，`re-android` 缺失，需新增）：获焦时如果列表可滚动，调用 Compose `LazyListState.animateScrollToItem`/`BringIntoViewRequester` 等价实现"确保可见"（对应 Flutter `TvFocusScroll.ensureVisible`）。
5. **`onFocusedNodeChanged` 回调**：只在真正获焦（不是失焦）时触发，用于记录"最近停留焦点"，供 3 的分组记忆机制消费。

实现建议：`TvFocusableCard` 组合以上 5 项能力，通过可选构造参数控制启用范围（例如 `focusMemoryGroupKey: String? = null` 不传则不启用分组记忆），避免所有卡片/列表都强制承担全部逻辑开销。

## core-design: TvQrCodeSection（升级为真实二维码）

```kotlin
@Composable
fun TvQrCodeSection(
    qrBitmap: Bitmap?,   // 由调用方(feature-settings)用 ZXing 生成后传入，core-design 不感知 ZXing 依赖
    statusText: String,
    onRegenerateClick: () -> Unit,
    modifier: Modifier = Modifier,
)
```

`core-design` 只负责渲染 `Bitmap`，不引入 ZXing 依赖（避免 UI 组件层引入业务能力），生成逻辑放在消费方（`feature-settings` 子任务负责）。

## core-player: Unified Engine Contract

```kotlin
// core-player/api
interface PlayerEngine {
    val stateFlow: StateFlow<PlaybackSnapshot>
    fun updateDataSource(request: PlaybackRequest, startAtMs: Long)
    fun play()
    fun pause()
    fun seekTo(positionMs: Long)
    fun setPlaybackSpeed(speed: Float)
    fun setResizeMode(mode: PlayerResizeMode)
    fun release()
}

data class PlaybackRequest(val url: String, val headers: Map<String, String> = emptyMap(), ...)
data class PlaybackSnapshot(val positionMs: Long, val durationMs: Long, val isPlaying: Boolean, val bufferedRanges: List<LongRange>, ...)
enum class PlayerState { IDLE, BUFFERING, READY, ENDED, ERROR }
```

`ExoPlayerEngine` 和 `WebViewPlayerEngine` 都实现该接口；`TvAppContainer.playerEngineFactory` 决定默认引擎，`feature-detail`/`feature-player` 消费同一接口，不感知具体实现类型。

## app-tv: Container & Navigation

```kotlin
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val dataStore: DataStore<Preferences>,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { ... },
    private val danmakuApiFactory: (String) -> SeleneDanmakuApi = { ... },
    private val doubanApiFactory: () -> SeleneDoubanApi = { ... },
    private val playerEngineFactory: () -> PlayerEngine = { ExoPlayerEngine(AppDispatchers.createDefault()) },
)

sealed class TvDestination(val route: String, val label: String, val iconGlyph: String? = null) {
    data object Home : TvDestination("home", "首页")
    data object Movie : TvDestination("library/movie", "电影")
    data object Tv : TvDestination("library/tv", "剧集")
    data object Anime : TvDestination("library/anime", "动漫")
    data object Show : TvDestination("library/show", "综艺")
    data object Search : TvDestination("search", "搜索", "⌕")
    data object History : TvDestination("history", "播放历史", "↺")
    data object Favorites : TvDestination("favorites", "收藏夹", "♥")
    data object Settings : TvDestination("settings", "设置")
    data object Live : TvDestination("live", "直播")
    data class Detail(val videoId: String) : TvDestination("detail/$videoId", "详情") {
        companion object { fun createRoute(videoId: String) = "detail/${URLEncoder.encode(videoId, "UTF-8")}" }
    }
}
```

`TvNavGraph` 在骨架阶段只接线 Home/Settings/占位路由，其余 feature 路由由各子任务在自己的 `implement.md` 中接入（app-tv 侧只需预留路由声明，具体页面 Composable 由 feature 模块提供）。

## Dependencies (gradle/libs.versions.toml additions)

```toml
[versions]
datastore = "1.1.1"
# 保持 re-android 现有版本基线：kotlin=2.1.0, agp=8.9.1, composeBom=2025.05.01,
# media3=1.6.1, tvMaterial=1.1.0, tvFoundation=1.0.0, retrofit=2.11.0, okhttp=4.12.0, coil=2.7.0

[libraries]
androidx-datastore-preferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
```

## minSdk 24 Compatibility Validation Plan

1. 先只搭 `app-tv` 空壳（顶部导航 + 首页占位）+ `core-design` 基础组件，跑 `assembleDebug` 和 `lintDebug`，扫描 `NewApi` 告警。
2. 引入 `core-player`（ExoPlayer + WebView）后重新跑一遍，Media3/WebView 组件在 API 24 上的已知问题重点检查（例如某些 `MediaCodec` 特性在低版本设备上不可用，需要 fallback）。
3. 在 API 24 模拟器（Android 7.0，非 TV profile 也可用于基础验证，若需要 TV 专属校验可用 Android TV API 24 模拟器镜像）上安装验证基础导航、焦点、播放。
4. 记录验证结果到本任务的 check 环节，任何降级或兼容 hack 都要写清楚原因和影响范围。

## Testing Strategy

- `core-common`：Repository 映射逻辑单测（DTO -> 业务模型）、`TvPreferencesStore` DataStore 读写往返测试（用 `InMemoryDataStore` 或临时文件 DataStore 测试替身）。
- `core-design`：`TvFocusableCard` 契约测试（短按/长按判定、多焦点请求器绑定、焦点记忆分组跨组跳转、方向键长按节流分组）、三维主题切换单测（palette/background/focusEffectMode 各自独立持久化与读取）、`TvDesignCanvas` 缩放计算单测（4 预设 + auto 匹配规则 + 只缩小不放大边界条件）。
- `core-player`：`ExoPlayerEngine`/`WebViewPlayerEngine` 各自的 `PlayerEngine` 契约测试（updateDataSource/play/pause/seekTo 行为一致性）。
- `app-tv`：`TvAppContainer` 工厂注入测试、`TvDestination` 路由生成测试。

## Rollback

- 四个 core 模块任一模块验证失败（尤其 minSdk 兼容性），先隔离修复该模块，不影响其余已通过模块。
- 如果 DataStore 迁移遇到阻碍，可临时回退到内存实现作为过渡（需在 PR 描述中明确标注技术债务和后续计划），但不能作为最终验收状态。
