# Kotlin TV 骨架搭建：app 壳 + core-common + core-design + core-player

## Goal

搭建 `kotlin-tv/` Gradle 工程骨架，落地 `app-tv` 壳、`core-common`（网络+数据）、`core-design`（TV 主题+复用组件）、`core-player`（ExoPlayer+WebView 双引擎），验证 minSdk 24 兼容性，冻结对外契约供后续 5 个 feature 子任务消费。本任务是父任务 `07-01-refactor-kotlin-tv-from-flutter-min-api24` 的前置依赖，其余子任务不得早于本任务验收完成开始实现。

## Reference Priority (重要)

**样式、交互、动效、业务逻辑以 Flutter TV 端 (`lib/tv_app/`) 为准，这是用户中意的实现，必须精确对齐。`re-android/` 只用作 Kotlin/Gradle 工程结构、模块划分、文件命名的参照，不作为视觉/交互标准，不照抄其简化或占位实现。**

- 例：`re-android` 的 `TvQrCodeSection` 只是占位渲染 `[QR]` 文字，Flutter 端用 `qr_flutter` 生成真实二维码——必须照 Flutter 的真实交互实现，不能照抄 `re-android` 的占位版本。
- 例：`re-android` 的 `TvPreferencesStore` 只是内存存储——必须照 Flutter 端 `SharedPreferences` 的持久化语义真正落地（Kotlin 端用 DataStore），不能照抄内存占位。
- 例：`re-android` 的 `TvFocusableCard` 焦点/长按判定逻辑基本对齐 Flutter 的 `TvFocusable`，但 Flutter 版本功能更完整（焦点记忆分组、方向键长按节流分组），要以 Flutter 版本的完整能力为目标。

## Confirmed Facts — Flutter TV 端设计与交互基线（权威参照）

- **`TvFocusable`**（`lib/tv_app/widgets/tv_focusable.dart`）是 Kotlin 版 `TvFocusableCard` 的完整对齐目标，能力包括：
  - 确认键短按/长按判定：`KeyDownEvent` 记录按压键，`KeyRepeatEvent` 长按只触发一次，`KeyUpEvent` 未触发长按才回落短按，防止一次物理按压重复触发业务。
  - 焦点记忆分组（`focusMemoryGroupKey`）：同组内记录最近一次真实获焦项，跨组上下方向移动时优先回到目标分组的记忆项，其次回退到分组内第一个可聚焦项（按“先上后下、同行从左到右”排序）。
  - 方向键长按节流分组（`directionalRepeatThrottleGroupKey`）：纯文字列表长按方向键时按分组节流重复事件（默认 120ms），避免跳过中间选中态；非文字列表（卡片/主导航/播放器菜单）不启用。
  - 获焦自动滚动（`autoScrollOnFocus`/`focusScrollAlignment`/`horizontalFocusScrollTriggerFraction`），复用 `TvFocusScroll.ensureVisible`。
  - `onFocusedNodeChanged` 只在真正获焦时触发，用于记录“最近停留焦点”。
- **`TvVideoCard`**（`lib/tv_app/widgets/tv_video_card.dart`）视觉与动效规格（以实测代码为准，权威于 `tv-mode.md` 文档里的旧数值）：
  - 卡片整体尺寸：`width=158`，`height=300`，封面 `coverHeight=237`。
  - 获焦缩放：`focusedScale=1.08`，`AnimatedScale` 140ms `easeOutCubic`。
  - 封面焦点框：获焦时边框变为浅色 `#E2E6EA` 宽 3px + 外阴影（blur 22, offset (0,10), alpha 0.08）；未获焦时边框为 `TvThemeColors.cardSurfaceBorder` 宽 1px。
  - 焦点雨刷扫光：获焦停留 300ms（`focusSweepDelay`）后触发一次 1800ms 横向扫光动画（七段渐变，纯横向不带纵向偏移）。
  - 封面加载骨架：同款雨刷扫光，最多播放 2 轮（`maxSweepCount`），背景为深色渐变 `#20282B -> #14191B`。
  - 多集进度徽章（右上角，`totalEpisodes>1 && index>0` 时显示 `index/totalEpisodes`）、播放进度条（封面底部，`progressPercentage>0` 时显示，用当前主题 `accent` 色填充）。
  - 图片加载有“滚动期延迟加载”优化：快速滚动时不发起网络请求，停止后只对视口内可见卡片解禁加载。
  - 副标题规则：继续观看态（`playTime>0 || index>1`）优先显示线路名；否则按“年份 · 评分或线路名”组装，全部为空时回退品牌名 `IvyTV`。
- **`TvDesignCanvas`**（`lib/tv_app/widgets/tv_design_canvas.dart`）设计画布自适应缩放系统：
  - 4 个预设：`auto`/`hd720(1280x720)`/`fullHd1080(1920x1080)`/`qhd1440(2560x1440)`。
  - `auto` 按当前视口从高到低匹配预设（>=1440p 用 1440p 设计稿，>=1080p 用 1080p，否则回退 720p）。
  - 只在视口小于设计稿时等比缩小（`scale = min(1, min(widthScale, heightScale))`），不会因为视口更大而放大。
  - 用 `Transform.scale` + `OverflowBox` + 固定 `MediaQuery.size` 实现整体缩放，子树内部按设计稿坐标系开发，不需要感知实际设备分辨率。
  - Compose 对应实现思路：用一个 `CompositionLocal` 传递当前 scale/designSize，顶层用 `Modifier.graphicsLayer(scaleX=scale, scaleY=scale)` + 固定尺寸约束容器包裹整个页面子树。
- **`TvThemeService`**（`lib/tv_app/services/tv_theme_service.dart`）完整主题体系（比之前记录的更丰富，包含 3 组独立可切换维度）：
  1. 主题色（`TvThemePalette`，3 选，**默认是奈飞红不是 Ivy 绿**）：奈飞红(`netflix_red`, accent=#E50914, focus=#FF3B45)/Ivy 绿(`ivy_green`, accent=#26C96F, focus=#42D37B)/柔和蓝(`soft_blue`, accent=#5B7CFA, focus=#7F99FF)，每个含 accent/focus/focusFill/disabledFill/selectedText 5 色值。
  2. 页面背景色（`TvThemeBackground`，2 选，默认深蓝灰）：深蓝灰(`deep_blue`, #1A1D29)/深黑夜幕(`deep_black`, #0A0D0E)。
  3. 卡片焦点效果模式（`TvFocusEffectMode`，2 选，**默认放大镜模式**）：放大镜(`magnifier`，卡片自身缩放+焦点框)/平滑外框(`smooth_frame`，跨卡片共享外边框平滑移动)。
  - 三组维度各自独立持久化（3 个不同 SharedPreferences key），互不影响。
  - `TvTheme.wrapScope` 用于 `Navigator.push`/`showDialog` 创建的新路由子树透传主题服务和设计画布，避免独立弹窗/路由脱离父级主题作用域。
- **`TvLayout`**（`lib/tv_app/tv_layout.dart`）全局布局常量：页面左右统一边距 `pageHorizontalPadding=46`，纵向 Grid 固定列数 `gridCrossAxisCount=7`。

## Confirmed Facts — Gradle 工程结构参照（次要，仅供工程搭建）

- `re-android` 现有对应模块（`core-data`/`core-network`/`core-design`/`core-player-api`/`core-player-exo`/`core-player-webview`/`app-tv`）已有完整文件清单和职责划分，可作为 `kotlin-tv` 合并后模块的**目录/文件组织**参照（不复制代码逻辑，只借鉴 Gradle 结构和文件命名习惯）：
  - `core-data`（18 文件）：`TvHomeRepository`/`TvSearchRepository`/`TvDetailRepository`/`TvFavoritesRepository`/`TvSettingsRepository`/`TvDanmakuRepository`/`TvDanmakuManualMatchRepository`/`TvPlaybackRepository`/`TvVideoLibraryRepository`/`DoubanRepository` + 对应模型/payload + `TvPreferencesStore`/`TvDatabase`。
  - `core-network`（11 文件）：`SeleneTvApi`/`SeleneDanmakuApi`/`SeleneDoubanApi`/`SeleneTvAuthApi` + 对应 Response DTO + `SessionCookieStore`/`AuthInterceptor`/`SeleneTvNetworkClient`。
  - `core-design`（30 文件）：`TvTokens`/`TvTheme`/`TvDesignPreset`/`TvDesignMetrics` 视觉基础；`TvFocusableCard`/`TvPosterCard`/`TvPosterGrid`/`TvPosterRail`/`TvPosterFocusGroup` 卡片列表；`TvPageScaffold`/`TvPageSection`/`TvPageModels` 页面骨架；`TvForm*`（TextField/ActionButton/SwitchRow/SliderRow/ChipOptionRow/ValueRow/Panel）表单组件；`TvStatePanel`/`TvEmptyStatePanel`/`TvSkeleton`/`TvActionNotice`/`TvConfirmDialog`/`TvQrCodeSection` 状态与反馈组件；`TvRemotePressPolicy`/`TvListLayoutMetrics` 焦点/布局辅助；`AppDispatchers`/`DispatcherProvider` 协程调度。
  - `core-player-api`（4 文件）：`PlayerEngine`/`PlaybackRequest`/`PlaybackSnapshot`/`PlayerState` 接口与数据类。
  - `core-player-exo`（3 文件）：`ExoPlayerEngine`/`ExoPlayerFactory`/`ExoPlayerAdapter`。
  - `core-player-webview`（5 文件）：`WebViewPlayerEngine`/`WebViewPlayerBridge`/`WebViewPlayerSession`/`WebViewPlayerCommand`/`WebViewPlayerSurface`。
  - `app-tv`：`TvDestination`（路由：Home/Movie/Tv/Anime/Show/Search/History/Favorites/Settings/...）、`TvNavGraph`、`TvAppContainer`（手写 DI 容器）、`TvApp`。
- `re-android` 的 `TvPreferencesStore` **当前只是内存存储**（代码注释：`// 首期使用内存存储，替换为 DataStore 时保持同名契约`），没有真正的本地持久化——这是一个已知缺口，`kotlin-tv` 从一开始就要用真正的持久化方案落地，不能照抄这个内存版本。
- `TvFocusableCard` 的焦点/按压处理模式（`TvRemotePressPolicy` 区分短按/长按、`onPreviewKeyEvent` 消费 `DirectionCenter`/`Enter`、多 `FocusRequester` 共享同一节点）是经过验证的可用设计,可直接作为 `kotlin-tv` 焦点卡片组件蓝本。
- `TvTokens` 色彩体系（Accent/FocusFill/FocusBorder/Background/Surface/SurfaceElevated/Outline/Danger/TextPrimary 等）可作为默认主题令牌参照，需要额外支持用户已确认的 3 套外观主题（Ivy 绿/奈飞红/柔和蓝）切换。
- 技术选型已确认：
  - UI 框架：Jetpack Compose for TV（`androidx.tv:tv-material` + `tv-foundation`）+ Navigation Compose。
  - 网络：Retrofit + Gson（保持 `re-android` 现有选型，不换 kotlinx.serialization）。
  - 本地持久化：Jetpack DataStore（Preferences DataStore），替代 `re-android` 的内存占位实现。
  - DI：手写构造函数注入容器（不引入 Hilt/Dagger/Koin）。
  - 播放：ExoPlayer/Media3（原生）+ WebView（兜底），双引擎可切换。
  - minSdk 24，`applicationId` 前缀 `uk.oxiang.ivy.tv.app`，`android:label` = `IvyTV`。
- 版本基线（起点，需在 minSdk 24 下逐一验证）：Kotlin 2.1.0、AGP 8.9.1、Compose BOM 2025.05.01、Media3 1.6.1、tv-material 1.1.0、tv-foundation 1.0.0、Retrofit 2.11.0、OkHttp 4.12.0、Coil 2.7.0。

## Requirements

### 工程骨架

- 创建 `kotlin-tv/` 根目录，`settings.gradle.kts` 按分组路径 include 全部模块（`:app:app-tv`、`:core:core-common`、`:core:core-design`、`:core:core-player`、`:feature:*` 先占位声明，模块目录逐步补齐）。
- 根 `build.gradle.kts` + `gradle/libs.versions.toml` 集中管理版本。
- `app-tv/build.gradle.kts`：`applicationId` 前缀 `uk.oxiang.ivy.tv.app`，`minSdk=24`、`compileSdk=35`、`targetSdk` 遵循当期 Google Play TV 要求；`android:label` = `IvyTV`；本地网关配置模式（`local.gateway.properties` + `.example`）复用 `re-android` 现有实现方式。

### core-common（合并 core-data + core-network）

- Retrofit + OkHttp + Gson 网络层：`SeleneTvApi`/`SeleneDanmakuApi`/`SeleneDoubanApi`/`SeleneTvAuthApi` 接口 + 对应 Response DTO。
- `SessionCookieStore`/`AuthInterceptor`/`SeleneTvNetworkClient` 会话与鉴权。
- Repository 层：`TvHomeRepository`/`TvSearchRepository`/`TvDetailRepository`/`TvFavoritesRepository`/`TvSettingsRepository`/`TvDanmakuRepository`/`TvDanmakuManualMatchRepository`/`TvPlaybackRepository`/`TvVideoLibraryRepository`/`DoubanRepository`，DTO 与业务模型分离（保持 `re-android` 已验证的分层约束：network 层 DTO 独立，data 层负责映射）。
- 本地持久化改用 Jetpack DataStore，替代 `re-android` 的内存占位；`TvPreferencesStore` 契约签名保持兼容，内部实现换成真正持久化。

### core-design

- 视觉令牌：`TvTokens` 基础色板 + `TvThemeService` 三维独立可切换主题体系（主题色 3 选默认奈飞红/背景色 2 选默认深蓝灰/卡片焦点效果模式 2 选默认放大镜），对齐 Flutter `tv_theme_service.dart`，供 settings 子任务消费。
- `TvDesignCanvas` 自适应缩放系统：4 预设（auto/hd720/fullHd1080/qhd1440），只缩小不放大，对齐 Flutter `tv_design_canvas.dart`；`TvLayout` 全局布局常量（`pageHorizontalPadding=46`、`gridCrossAxisCount=7`）。
- 复用组件集：焦点卡片（`TvFocusableCard`，需完整对齐 Flutter `TvFocusable` 的焦点记忆分组、方向键长按节流分组、获焦自动滚动能力，不是 `re-android` 的简化子集）、海报列表/网格/焦点组（`TvPosterCard`/`Grid`/`Rail`/`FocusGroup`）、页面骨架（`TvPageScaffold`/`Section`）、表单组件集（TextField/ActionButton/SwitchRow/SliderRow/ChipOptionRow/ValueRow/Panel）、状态与反馈组件（`TvStatePanel`/`TvEmptyStatePanel`/`TvSkeleton`/`TvActionNotice`/`TvConfirmDialog`/`TvQrCodeSection`）。
- 焦点/布局辅助：`TvRemotePressPolicy`（短按/长按判定）、`TvListLayoutMetrics`（列表滚动定位）。
- `TvQrCodeSection` 需要支持真实二维码渲染（ZXing 生成的 Bitmap），不停留在 `re-android` 的占位状态。
- `TvTheme.wrapScope` 等价机制：新路由/弹窗子树透传三维主题状态和设计画布 scale/designSize，避免脱离父级作用域。

### core-player

- 统一接口 `PlayerEngine` + 数据类 `PlaybackRequest`/`PlaybackSnapshot`/`PlayerState`。
- `ExoPlayerEngine`/`ExoPlayerFactory`/`ExoPlayerAdapter`（原生播放）。
- `WebViewPlayerEngine`/`WebViewPlayerBridge`/`WebViewPlayerSession`/`WebViewPlayerCommand`/`WebViewPlayerSurface`（WebView 兜底播放）。
- 双引擎可通过 `TvAppContainer` 的 `playerEngineFactory` 运行时切换。

### app-tv

- `TvDestination` 路由清单：Home/Movie/Tv/Anime/Show/Search/History/Favorites/Settings/Detail/Player（对齐 `re-android` 现有路由设计）。
- `TvNavGraph` 负责跳转到 `TvDestination.Detail.createRoute(videoId)` 等统一路由。
- `TvAppContainer` 手写 DI 容器，组装 core 层各 factory。
- `TvApp` 顶层 Composable，包含顶部导航、`contentFocusRequester` 管理。

## Acceptance Criteria

- [ ] `./gradlew -p kotlin-tv :app:app-tv:assembleDebug` 在 minSdk 24 下编译通过，无 `NewApi` 阻断性告警。
- [ ] `core-common` 网络层与数据层分离，Repository 完成 DTO -> 业务模型映射，覆盖首页/搜索/详情/收藏/设置/弹幕/豆瓣/播放记录场景的接口签名（先搭骨架签名，具体业务逻辑由各 feature 子任务实现）。
- [ ] `TvPreferencesStore` 使用 DataStore 落地真实持久化，读写契约签名与 `re-android` 版本保持兼容（供未来对照）。
- [ ] `core-design` 提供完整复用组件集，三维主题体系（主题色/背景色/焦点效果模式）各自独立可切换生效，`TvDesignCanvas` 缩放系统按 4 预设正确工作。
- [ ] `TvFocusableCard` 完整覆盖 Flutter `TvFocusable` 的 5 项能力（短按/长按判定、焦点记忆分组、方向键长按节流分组、获焦自动滚动、`onFocusedNodeChanged`），非 `re-android` 子集。
- [ ] `core-player` 提供统一 `PlayerEngine` 接口，ExoPlayer 与 WebView 两个实现都能通过 `TvAppContainer` 工厂函数创建并切换。
- [ ] `app-tv` 具备可运行的空壳（顶部导航 + 路由跳转 + 首页占位），可安装到 API 24 模拟器/真机验证基础导航与焦点。
- [ ] 所有 core 层对外契约（接口签名）在本任务验收时视为冻结，后续 feature 子任务作为消费方，不应频繁要求变更。
- [ ] 单元测试覆盖 core-common Repository 映射逻辑、core-player 双引擎切换、DataStore 读写往返。
- [ ] `./gradlew -p kotlin-tv test` 全量通过。

## Out of Scope

- 任何 feature 页面的具体业务 UI/交互实现（留给 5 个 feature 子任务）。
- `re-android` 目录的删除或修改。
- 真机版本适配以外的深度性能调优（低端机性能验证只做基础可用性检查，不做像素级优化）。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Complex task: `design.md` 和 `implement.md` 已同步补充。
