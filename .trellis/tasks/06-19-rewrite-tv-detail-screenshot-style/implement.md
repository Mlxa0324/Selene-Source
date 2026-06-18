# 按截图重做 Kotlin TV 详情页样式执行计划

## Read Before Coding

- `.trellis/spec/frontend/tv-mode.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/guides/cross-layer-thinking-guide.md`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailPresentation.kt`

## Checklist

### 1. 红灯/契约测试

- [x] 更新 `TvDetailRouteFocusContractTest` 或新增 Route 样式契约测试，先锁定截图式关键组件和文案。
- [x] 运行单条契约测试确认红灯。

### 2. Route 推翻重做

- [x] 删除上一版 `TvDetailTopBar` / `TvDetailHeroSection` 等 IvyTV 视觉组件。
- [x] 新建 `NcatDetailTopBar`，实现品牌、说明、搜索、登录、时间。
- [x] 新建 `NcatDetailHero`，实现左播放器 + 右信息面板。
- [x] 新建 `NcatActionTile`，实现全屏/收藏/反馈大方块和红色焦点。
- [x] 新建 `NcatSourceRail` / `NcatSourceCard`，实现截图式线路卡。
- [x] 新建 `NcatEpisodeGroupRail`，实现顶部轨道和区间标签。
- [x] 新建 `NcatRecommendRail`，实现截图式推荐卡。
- [x] 新建 `NcatBottomActions`，实现底部胶囊按钮和提示。

### 3. 焦点和逻辑保持

- [x] 保留显式 `FocusRequester` 与 `focusProperties` 方向关系。
- [x] 保留线路、选集、分组横向 `LazyListState` 获焦滚动。
- [x] 推荐为空仍隐藏推荐区和底部动作。
- [x] 无数据/错误/空态仍沿用前两阶段逻辑。

### 4. 绿灯验证

- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest --tests org.moontechlab.selene.tv.feature.detail.TvDetailRouteFocusContractTest`
- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`
- [x] `git diff --check -- <task files>`

## Implementation Record

- 2026-06-19：用户补充两张详情页截图，明确要求推翻上一版详情页 UI，按截图整体重做。
- 2026-06-19：新增 `detail_route_uses_ncat_screenshot_style_structure` 契约测试，先确认旧结构红灯失败。
- 2026-06-19：从零重建 `TvDetailRoute.kt` 的截图式 `Ncat*` 组件树，保留 ViewModel 和 `TvDetailPresentation` 数据/焦点契约。
- 2026-06-19：验证 `TvDetailRouteFocusContractTest`、`:feature-tv-detail:testDebugUnitTest` 和任务文件 `git diff --check` 均通过。
