# Implementation Plan

## Ordered Checklist

- [x] 更新 `TvTokens.kt`，建立接近 Flutter TV 的默认背景、主色、焦点、按钮、海报和间距 token。
- [x] 调整 `SeleneTvTheme` 如有必要，让 Material color scheme 使用新的 TV 默认背景和 surface。
- [x] 改造 `TvApp.kt` 顶部导航：白色 IvyTV、右侧快捷入口、时间、主导航顺序和 Flutter TV 接近。
- [x] 改造 `TvPageScaffold.kt`，让页面头部可选，移除默认统计 chip 对核心页面的侵入。
- [x] 调整 `TvPosterCard.kt`、`TvPosterRail.kt`、`TvPosterGrid.kt`，统一海报尺寸、间距、焦点和文字层级。
- [x] 精修横向列表和纵向网格安全留白，避免焦点放大贴边、网格二次缩进和滚动状态隐式丢失。
- [x] 改造 `TvHomeRoute` 首页：去掉占位头，突出“继续观看”和横向内容区。
- [x] 改造 `TvVideoLibraryRoute` 分类页：筛选 chip 和视频网格套用新样式，保留已有焦点回传。
- [x] 修复首页数据兜底：`admin/dashboard` 不可用时复用分类搜索接口组装真实首页列表。
- [x] 改造 `TvDetailRoute` 详情页：去掉统计头，重排播放预览、简介、线路、选集和推荐。
- [x] 改造 `TvPlayerRoute` 播放器页：从普通页面按钮改为沉浸式播放画布和控制菜单。
- [x] 检查历史、搜索、设置、直播等仍使用共享组件的页面，补默认参数或局部样式，避免被核心页面改造误伤。
- [x] 运行 Kotlin 格式、编译或相关测试命令，确认没有编译和现有测试回归。

## Validation Commands

优先运行：

```bash
./re-android/gradlew -p re-android test
```

如果全量耗时或项目配置不允许，至少运行相关模块测试：

```bash
./re-android/gradlew -p re-android :feature-tv-home:testDebugUnitTest :feature-tv-detail:testDebugUnitTest :feature-tv-player:testDebugUnitTest :app-tv:testDebugUnitTest
```

如果存在 Compose 或 Android instrumentation 可用环境，再补：

```bash
./re-android/gradlew -p re-android connectedDebugAndroidTest
```

## Risky Files

- `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTokens.kt`
- `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPageScaffold.kt`
- `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPosterCard.kt`
- `re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvApp.kt`
- `re-android/feature-tv-home/src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeRoute.kt`
- `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- `re-android/feature-tv-player/src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerRoute.kt`

## Rollback Points

- 如果四页风格不一致，先保留 token，回退单页结构改动。
- 如果共享组件影响历史、搜索、设置、直播，优先通过 `TvPageScaffold` 默认参数兼容，而不是让核心页面复制布局。
- 如果海报尺寸导致网格溢出，先降低 Kotlin 网格列数或卡片宽度，不改数据层。

## Pre-Start Review

- [ ] 用户确认本规划确实按方案 C 推进。
- [ ] 确认本轮目标是“四页整体粗对齐”，不是首页 1:1 精修。
- [ ] 确认实现前读取 `trellis-before-dev` 和相关 `.trellis/spec`。
