# 实施计划：Kotlin TV 骨架搭建

## Checklist

1. [ ] 创建 `kotlin-tv/` 根目录结构：`settings.gradle.kts`、根 `build.gradle.kts`、`gradle/libs.versions.toml`（基于 `re-android` 版本基线 + 新增 datastore 依赖）。
2. [ ] 创建 `local.gateway.properties.example`（复用 `re-android` 现有字段格式），确认 `.gitignore` 覆盖真实文件。
3. [ ] 搭建 `core-design` 模块：`TvTokens`/`TvTheme`/`TvLayout` + `TvDesignPreset`/`TvDesignMetrics`/`TvDesignCanvas`（4 预设等比缩放，对齐 Flutter `tv_design_canvas.dart`）+ 三维独立主题体系（主题色 3 选默认奈飞红/背景色 2 选默认深蓝灰/焦点效果模式 2 选默认放大镜，对齐 Flutter `tv_theme_service.dart`）+ `TvFocusableCard`（完整对齐 Flutter `TvFocusable` 的短按长按判定/焦点记忆分组/方向键长按节流分组/获焦自动滚动/`onFocusedNodeChanged`）/`TvRemotePressPolicy`/`TvFocusMemoryRegistry` + 页面骨架组件 + 表单组件集 + 状态反馈组件集。
4. [ ] 搭建 `core-common` 模块：network 层（API 接口 + DTO + SessionCookieStore + AuthInterceptor + NetworkClient）+ data 层（Repository 骨架签名 + 业务模型）+ storage 层（DataStore 版 `TvPreferencesStore`）。
5. [ ] 搭建 `core-player` 模块：`api`/`exo`/`webview` 三个子包，`PlayerEngine` 统一接口 + 两个实现。
6. [ ] 搭建 `app-tv` 模块：`TvDestination`/`TvNavGraph`/`TvAppContainer`/`TvApp`，接入 `AndroidManifest.xml`（`applicationId=uk.oxiang.ivy.tv.app`、`android:label=IvyTV`、TV Leanback feature 声明）。
7. [ ] 为 `feature/*` 六个模块创建最小占位骨架（空模块 + 一个占位 Composable），保证 `settings.gradle.kts` 的 include 声明可构建。
8. [ ] 跑 minSdk 24 兼容性验证（见 design.md 验证计划四步），记录并清零 `NewApi` 阻断性告警。
9. [ ] 补齐单元测试（core-common Repository 映射、DataStore 读写、core-player 双引擎契约、core-design 焦点契约、app-tv 容器注入）。
10. [ ] 在 API 24 模拟器上验证基础导航、焦点、双引擎播放可用性。

## Validation Commands

```bash
./gradlew -p kotlin-tv :app:app-tv:assembleDebug
./gradlew -p kotlin-tv :core:core-common:testDebugUnitTest
./gradlew -p kotlin-tv :core:core-design:testDebugUnitTest
./gradlew -p kotlin-tv :core:core-player:testDebugUnitTest
./gradlew -p kotlin-tv :app:app-tv:testDebugUnitTest
./gradlew -p kotlin-tv lintDebug
```

## Review Gates

- Gate A（步骤 3-5 完成后）：三个 core 模块各自独立编译通过、单测通过，此时冻结对外接口签名。
- Gate B（步骤 6-7 完成后）：`app-tv` 可安装运行，基础导航和首页占位可见。
- Gate C（步骤 8-10 完成后）：minSdk 24 兼容性验证通过，本任务整体验收，正式冻结契约供 5 个 feature 子任务消费。

## Rollback Points

- Gate A 未通过时，不进入 app-tv 搭建，先在 core 模块内部解决问题。
- Gate C 发现严重兼容性问题（例如某个关键依赖在 API 24 完全不可用）时，回到设计阶段重新评估该依赖的替代方案，不强行降级凑合。
