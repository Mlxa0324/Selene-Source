# Kotlin TV 详情页面 UI 和焦点图执行计划

## Read Before Coding

- `.trellis/spec/frontend/tv-mode.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/guides/cross-layer-thinking-guide.md`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `.trellis/tasks/06-18-rewrite-tv-detail-state-machine`

## Checklist

### 1. 红灯测试：展示和焦点策略

- [x] 新增 `TvDetailPresentationTest`：线路按剧集数倒序，当前源首次固定在前。
- [x] 新增 `TvDetailPresentationTest`：20 集分组标签和当前组剧集正确。
- [x] 新增 `TvDetailFocusGraphTest`：线路首尾左右键停留当前链路。
- [x] 新增 `TvDetailFocusGraphTest`：全屏/收藏下键进入当前源。
- [x] 新增 `TvDetailFocusGraphTest`：线路下键进入最近选集，选集上键回最近线路。
- [x] 新增 `TvDetailFocusGraphTest`：选集左右跨组仍停留在选集链路。
- [x] 新增 `TvDetailPresentationTest`：推荐为空时不渲染推荐区和底部动作。

### 2. Presentation 层

- [x] 新增 `TvDetailPresentation.kt`。
- [x] 实现来源展示模型和排序规则。
- [x] 实现选集 20 集分组、标签和当前组解析。
- [x] 实现推荐/底部动作是否渲染的布局标记。
- [x] 实现焦点图纯策略。

### 3. Compose UI 重构

- [x] 重写 `TvDetailRoute` 为顶部栏、Hero、线路、选集、推荐、底部动作组件。
- [x] Hero 左侧预览播放器保持 16:9，右侧信息面板对齐 Flutter TV。
- [x] 来源区展示 `线路名（集数）`，空态区分“搜索中”和“搜索完成无源”。
- [x] 选集区改为选集在上、分组在下；分组确认才切换。
- [x] 推荐为空时不渲染推荐区和底部动作。

### 4. Compose 焦点接线

- [x] 为搜索、播放器、全屏、收藏、来源、选集、分组、推荐、底部动作建立 `FocusRequester`。
- [x] 用 `focusProperties` 和必要的 `onPreviewKeyEvent` 固定上下左右目标。
- [x] 横向列表首尾只触发边界停留，不跳其它列表。
- [x] 上下移动按当前水平位置或当前选中项进入最近列表项。
- [x] 获焦时调用 `BringIntoViewRequester` 或 LazyListState 滚动，保证当前项可见且有安全留白。

### 5. 绿灯验证

- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest --tests org.moontechlab.selene.tv.feature.detail.TvDetailPresentationTest`
- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest --tests org.moontechlab.selene.tv.feature.detail.TvDetailFocusGraphTest`
- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest --tests org.moontechlab.selene.tv.feature.detail.TvDetailRouteFocusContractTest`
- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`
- [x] `git diff --check -- <Phase 2 files>`

## Rollback Points

- Presentation 层和测试可以独立保留；如果 UI 接线风险过大，先提交策略层，再拆小步接 Compose。
- 若焦点 requester 在 LazyRow 复用中不稳定，保留显式 key + stable requester map，不依赖 item 默认焦点恢复。

## Implementation Record

- 2026-06-18：新增纯 Kotlin `TvDetailPresentation` / `TvDetailFocusGraph`，用单测锁定 Flutter TV 同款线路排序、20 集分组、推荐显隐和关键焦点移动规则。
- 2026-06-18：重写 `TvDetailRoute` 结构，加入顶部栏、Hero、线路、选集、推荐、底部操作组件，推荐为空时隐藏推荐和底部动作。
- 2026-06-18：为详情页搜索、播放器、全屏、收藏、线路、选集、分组、推荐和底部动作接入显式 `FocusRequester` / `focusProperties`。
- 2026-06-18：收紧上下焦点落点，Hero 按钮下键进入当前源，线路下键进入当前选集，推荐为空时不导向未渲染的底部动作。
- 2026-06-18：为线路、选集、分组三条横向轨道接入 `LazyListState` 获焦滚动，并新增 `TvDetailRouteFocusContractTest` 锁定滚动契约。
