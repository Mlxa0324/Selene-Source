# 重构 Kotlin TV 端：在 kotlin-tv 全新实现，对齐 Flutter TV 全部功能，兼容 Android 7

## Goal

在仓库根目录新建 `kotlin-tv/` 工程，用 Kotlin + Jetpack Compose for TV 全新实现 Flutter TV 端 (`lib/tv_app/`) 的全部功能，minSdk 降到 24（Android 7.0），模块划分适度（不过度拆分也不单模块堆砌）。旧的 `re-android/` 工程保留在磁盘上作为行为/UI 参照，标记为弃用，不再接新功能、不再修复非阻断性 bug。

## Reference Priority (重要)

**样式、交互、动效、业务逻辑以 Flutter TV 端 (`lib/tv_app/`) 为准，这是用户中意的实现，必须精确对齐。`re-android/` 只用作 Kotlin/Gradle 工程结构、模块划分、文件命名的参照，不作为视觉/交互标准，不照抄其简化或占位实现。** 各子任务在规划和实现阶段都需要重新核对 Flutter 源码实测细节（尺寸、动效参数、状态维度等），不能只依赖 `re-android` 的既有实现或 `tv-mode.md` 里记录的旧数值——`tv-mode.md` 记录可能滞后于 Flutter 实测代码，发现不一致时以 Flutter 源码为准并更新 spec。

## Background / Confirmed Facts

- `re-android/` 是此前用非 Claude 工具做的一次 Kotlin 重构尝试，已提交（`cf3d8db 非claude重构成kotlin，未完`），用户明确不信任这份实现，要求重新开发。
- `re-android/` 现有 16 个 Gradle 模块，用户反馈"架构分散一点不要太分散"，判定为拆分过细。
- Flutter TV 端 (`lib/tv_app/`) 总计约 22287 行 Dart，核心页面体量：详情页 5835 行、全屏播放器 4983 行、搜索页 3109 行、设置页 2735 行、首页 2620 行、视频库/分类 372 行、弹幕手动匹配 392 行，history/favorites/live 各 30-40 行（轻量占位/列表页）。
- Flutter TV 端直播页当前是"正在开发"占位页，不是真实直播功能。
- Flutter TV 端强制服务器模式（进入 TV 壳会强制关闭本地模式），Kotlin 新实现同样只对接服务器 API，不需要处理本地模式分支。
- Flutter 播放内核是双引擎架构：`media_kit`（原生播放，对应 ExoPlayer/Media3）+ `flutter_inappwebview`（WebView 兜底播放），Kotlin 新实现要保留双引擎切换能力。
- `.trellis/spec/frontend/tv-mode.md`（1152 行）是现有的 TV 端行为契约文档，覆盖启动分流、首页内容、卡片尺寸、详情页数据流、播放记录、全屏 seek 手感、焦点路径等精确规则，是 UI/交互/数据流的权威依据；其中 3.3.1/3.6/3.7/3.8 节是专门写给 `re-android` 的 Kotlin 契约，将随实现推进改写为指向 `kotlin-tv/*`。
- Compose for TV（`androidx.tv:tv-material`）官方支持最低 API 21；Media3/ExoPlayer 同样支持 API 21+；minSdk 24 在框架层面没有阻碍（来源：[Android Developers - Use Jetpack Compose on Android TV](https://developer.android.com/training/tv/playback/compose)）。
- `re-android` 现有依赖基线：Kotlin 2.1.0、AGP 8.9.1、Compose BOM 2025.05.01、Media3 1.6.1、tv-material 1.1.0、Retrofit 2.11.0、OkHttp 4.12.0、Coil 2.7.0——作为 `kotlin-tv` 的起始版本参考，需要在 minSdk 24 下逐一验证兼容性。
- `re-android` 没有引入 Hilt/Dagger/Koin，使用手写构造函数注入容器（`TvAppContainer`），符合"低代码、不过度设计"的方向，`kotlin-tv`延续这一模式。
- 弹幕渲染是 Compose `Canvas` 手绘评论叠加层，不依赖 `canvas_danmaku` 的直接 Kotlin 移植。

## Requirements

- 新工程根目录为 `kotlin-tv/`，与 `re-android/` 并存，互不影响构建。
- UI 框架：Jetpack Compose for TV（`androidx.tv:tv-material` + `tv-foundation`）+ Navigation Compose。
- `minSdk = 24`，`compileSdk`/`targetSdk` 沿用当前 Android TV 生态推荐版本（在 design.md 中明确）。
- `applicationId` 前缀为 `uk.oxiang.ivy.tv.app`，应用显示名（`android:label`）为 `IvyTV`。
- 播放内核保留双引擎（ExoPlayer/Media3 原生 + WebView 兜底），可运行时切换。
- Gradle 模块采用分组子目录 + 合并粒度：
  ```
  kotlin-tv/
  ├── app/app-tv
  ├── core/core-common core-design core-player
  └── feature/feature-home feature-detail feature-player feature-search feature-settings feature-content
  ```
  （`feature-content` 合并原 history + favorites + live 三个轻量页面；`core-common` 合并原 core-data + core-network；`core-player` 合并原 player-api + player-exo + player-webview。）
- 覆盖 Flutter TV 端全部功能面：首页分区/顶部导航、分类筛选与分页、搜索（输入/联想/热词/历史/结果会话）、历史、收藏、设置（服务器配置/弹幕匹配/播放媒体/外观焦点）、详情页（补源/续播/推荐/焦点流）、全屏播放器（控制/菜单/弹幕/切集切源/seek 手感）、直播（占位页，与 Flutter 端一致）。
- 遥控器焦点行为需要满足 `.trellis/spec/frontend/tv-mode.md` 中已有的焦点契约（上下左右、边界抖动、跨区回流等），不需要重新发明规则，是照抄验证。
- 不使用 Hilt/Dagger/Koin 等 DI 框架，沿用手写容器注入模式。
- 本地网关配置沿用 `local.gateway.properties` 模式（真实文件 gitignore，仓库只提交 `.example`）。

## Acceptance Criteria

- [ ] `kotlin-tv/` 工程可独立构建（`./gradlew assembleDebug`），不依赖 `re-android/` 任何模块。
- [ ] `minSdk = 24` 且关键依赖（Compose for TV、Media3、Retrofit、Coil）在该 minSdk 下编译通过、无 API 兼容告警。
- [ ] 首页、分类、搜索、历史、收藏、设置、直播占位、详情页、全屏播放器功能均以 `kotlin-tv` 全新实现落地，行为对齐 `.trellis/spec/frontend/tv-mode.md` 契约。
- [ ] 应用可安装且 `android:label` 显示为 `IvyTV`，`applicationId` 前缀为 `uk.oxiang.ivy.tv.app`。
- [ ] 播放双引擎切换（ExoPlayer ↔ WebView）功能验证通过。
- [ ] 遥控器方向键、确认键、返回键在所有页面路径可预测，不出现丢焦/焦点逃逸。
- [ ] 6 个子任务（scaffold-core / feature-home / feature-detail / feature-player / feature-search / feature-settings-content）全部验收通过并归档。
- [ ] `re-android/` 目录保留在磁盘、不删除，但仓库文档/README 标注为弃用参照。

## Out of Scope

- 删除 `re-android/` 目录（保留，仅弃用不维护）。
- 处理 `re-android` 下现存的 14 个进行中 Trellis 任务（用户选择"先都不动"，等 `kotlin-tv` 完成后再决定）。
- 真实直播功能（Flutter 端本身也是占位页）。
- 本地模式数据源支持（TV 端强制服务器模式）。
- 引入新的 DI 框架、状态管理框架等超出"低代码、模块适度"范围的架构变更。

## Task Structure

本任务为父任务，只负责跨模块的整体设计（工程骨架、Gradle 配置、路由约定、core 层契约、验收总纲）。实现工作拆到 6 个子任务，子任务之间的顺序依赖写在各自 `prd.md`（子任务 1 是其余 5 个子任务的前置依赖，需先完成）：

1. `kotlin-tv-scaffold-core` — app 壳 + core-common + core-design + core-player 骨架
2. `kotlin-tv-feature-home` — 首页 + 分类/视频库
3. `kotlin-tv-feature-detail` — 详情页
4. `kotlin-tv-feature-player` — 全屏播放器
5. `kotlin-tv-feature-search` — 搜索页
6. `kotlin-tv-feature-settings-content` — 设置 + 弹幕手动匹配 + 历史/收藏/直播占位

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Complex task: `design.md` 和 `implement.md` 已同步补充。
