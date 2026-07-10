# Kotlin TV 重构设计（kotlin-tv）

## Architecture Overview

```
kotlin-tv/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
├── app/
│   └── app-tv/                      # 壳、Navigation Compose 路由、TvAppContainer(手写DI)、启动分流
├── core/
│   ├── core-common/                 # Retrofit/OkHttp + DTO + Repository（合并原 core-network + core-data）
│   ├── core-design/                  # TV 主题、TvFocusableCard、TvPosterRail/Grid、表单组件、状态面板
│   └── core-player/                    # PlayerEngine 接口 + ExoPlayerEngine + WebViewPlayerEngine（合并三个 player 模块）
└── feature/
    ├── feature-home/                # 首页 + 分类筛选 + 视频库 Grid
    ├── feature-detail/               # 详情页（补源/续播/推荐/焦点图）
    ├── feature-player/               # 全屏播放器（菜单/弹幕/切集/seek）
    ├── feature-search/               # 搜索页
    ├── feature-settings/             # 设置 + 弹幕手动匹配
    └── feature-content/              # 历史 + 收藏 + 直播占位（三个轻量页面合并）
```

Gradle `include` 使用带路径的模块名（如 `:app:app-tv`、`:core:core-common`、`:feature:feature-home`），目录分组不影响模块引用方式，仅约束物理路径。

## Module Dependency Graph

```
core-common  <- feature-* (数据/仓库依赖)
core-design  <- feature-* (UI 组件依赖)
core-player  <- feature-detail, feature-player
app-tv       -> 依赖全部 feature-* 与 core-*（组装层，不被任何模块反向依赖）
```

约束延续 `tv-mode.md` 现有契约：`core-common` 内部网络层 DTO 与业务模型分离（Repository 负责映射），不允许 feature 直接读取网络层 DTO 或 BuildConfig。

## Version Baseline (待 minSdk 24 验证)

以 `re-android/gradle/libs.versions.toml` 现有版本为起点（仅借用其依赖版本号作为起始基线，不代表业务实现标准），逐一在 minSdk 24 环境验证：

| 依赖 | 起始版本 | 已知最低 API 支持 |
|------|---------|------|
| Kotlin | 2.1.0 | 无 minSdk 限制 |
| AGP | 8.9.1 | 无 minSdk 限制 |
| Compose BOM | 2025.05.01 | Jetpack Compose 官方 minSdk 21+ |
| androidx.tv:tv-material | 1.1.0 | Compose for TV 官方 minSdk 21+ |
| androidx.tv:tv-foundation | 1.0.0 | 同上 |
| androidx.media3 (ExoPlayer) | 1.6.1 | Media3 官方 minSdk 21+ |
| Retrofit | 2.11.0 | 无特殊限制 |
| OkHttp | 4.12.0 | 无特殊限制（注意 4.x 系列部分子版本要求 API 21+，24 满足） |
| Coil | 2.7.0 | minSdk 21+ |

验证方式：`kotlin-tv-scaffold-core` 子任务落地时执行 `./gradlew :app:app-tv:assembleDebug` 并检查 lint 的 `NewApi` 告警，逐一清零或加 `@RequiresApi` / 版本判断兜底。

## Build Config

- `namespace` / `applicationId` 前缀：`uk.oxiang.ivy.tv.app`（子模块沿用相同 group 前缀，各模块自定后缀）。
- `android:label` = `IvyTV`。
- `minSdk = 24`，`compileSdk = 35`，`targetSdk` 遵循 Google Play TV 应用当期要求（当前 API 34，随生态更新可调）。
- 本地网关配置：`kotlin-tv/local.gateway.properties`（gitignore）+ `local.gateway.properties.example`（提交），复用 `re-android` 现有的 `loadLocalGatewayProperties()` / `toBuildConfigString()` 模式。
- Debug 允许明文流量（`usesCleartextTraffic=true`），Release 关闭。

## DI / Composition Root

延续 `re-android` 的手写容器模式（`TvAppContainer`），不引入 Hilt/Dagger/Koin：

```kotlin
class TvAppContainer(
    private val gatewayConfig: TvLocalGatewayConfig,
    private val sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    private val preferencesStore: TvPreferencesStore = TvPreferencesStore(),
    private val gatewayClientFactory: (String, SessionCookieStore) -> SeleneTvGatewayClient = { ... },
    private val danmakuApiFactory: (String) -> SeleneDanmakuApi = { ... },
    private val playerEngineFactory: () -> PlayerEngine = { ExoPlayerEngine(...) }, // 默认原生, 可切 WebViewPlayerEngine
    private val doubanApiFactory: () -> SeleneDoubanApi = { ... },
)
```

## Player Engine Contract

`core-player` 暴露统一接口，`feature-detail` 与 `feature-player` 消费同一接口，运行时可切换：

```kotlin
interface PlayerEngine {
    fun updateDataSource(request: PlaybackRequest, startAtMs: Long)
    fun play(); fun pause(); fun seekTo(positionMs: Long)
    val stateFlow: StateFlow<PlaybackSnapshot>
}
```

对齐 `.trellis/spec/frontend/tv-mode.md` 3.5/3.5.1/3.5.2 节的续播、退出收尾、seek 加速度契约（照搬规则，不重新设计）。

## Focus Contract Reuse

复用 `.trellis/spec/frontend/tv-mode.md` 中已确立的焦点原则（真实可见节点、页面级 `contentFocusRequester`、列表记录最近真实获焦项、纯 Kotlin 焦点图 + Compose 只做 `requestFocus()`），不重新设计，`06-24-govern-kotlin-tv-focus-navigation` 任务中已经沉淀的 `design.md` 焦点治理原则原样套用到 `kotlin-tv`。

## Danmaku Rendering

渲染方式：Compose `Canvas` 手绘评论叠加层，不引入第三方弹幕库（`re-android` 的 Canvas 手绘做法与 Flutter 端 `canvas_danmaku` 的渲染思路一致，可作为工程实现参照）。具体动效参数（速度、防重叠、字号缩放等）以 Flutter 端 `lib/tv_app/` 弹幕相关组件的实测代码为准，由 `kotlin-tv-feature-player` 子任务规划时核对。

## Spec Update Plan

`.trellis/spec/frontend/tv-mode.md` 中 3.3.1 / 3.6 / 3.7 / 3.8 节当前路径引用指向 `re-android/*`；随着各子任务落地，需要新增/改写对应章节，路径指向 `kotlin-tv/*`，明确标注 `re-android/*` 版本为历史参照（弃用）。此更新在各子任务的 Phase 3.3（spec update）中逐步完成，不在父任务一次性改完。

## Legacy Handling

- `re-android/` 保留在磁盘，不删除。
- 仓库根 README 或 `re-android/README.md` 增补一行弃用说明（谁在维护 `kotlin-tv`、`re-android` 不再接新功能）。
- `re-android` 下现存 14 个进行中任务不处理，维持原状，等 `kotlin-tv` 全部子任务完成后再决定批量归档或摘录。

## Risks & Mitigations

- **风险**：minSdk 24 下部分 Compose for TV 组件在低端设备动画/焦点性能不如高版本。
  **缓解**：`scaffold-core` 阶段先在低配模拟器（API 24）跑通基础导航+列表滚动，性能异常及早发现，不要拖到 feature 子任务后期。
- **风险**：6 个子任务并行推进时，`core-common`/`core-design`/`core-player` 契约变更会影响已完成的 feature 子任务。
  **缓解**：`scaffold-core` 必须先完成并冻结对外契约（接口签名），后续 feature 子任务视为消费方，如需变更 core 契约要单独走一次评审，不能随意改。
- **风险**：详情页/播放器体量大（各自对应 Flutter 5835/4983 行），一次性实现容易失控。
  **缓解**：子任务 `implement.md` 按 Flutter 源码的功能分区拆解检查点（例如详情页拆：数据加载 → 焦点图 → 播放器接线 → 选集/分组 → 推荐），每个检查点独立验证。

## Rollback

- 每个子任务是独立可验收单元，若某个子任务实现方向有问题，只回滚该子任务分支，不影响其余已完成子任务。
- `core-common`/`core-design`/`core-player` 契约一旦冻结并被多个 feature 消费，后续变更需要新开子任务而不是就地修改（避免影响已验收的 feature）。
