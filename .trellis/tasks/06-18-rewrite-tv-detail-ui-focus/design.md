# Kotlin TV 详情页面 UI 和焦点图设计

## Scope

本阶段重写 Kotlin TV 详情页 UI 结构和遥控器焦点图，只消费第一阶段稳定后的 `TvDetailUiState`，不再改动详情数据加载状态机主语义。

主要涉及：

- `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt`
- `re-android/feature-tv-detail/src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailPresentation.kt`
- `re-android/feature-tv-detail/src/test/java/org/moontechlab/selene/tv/feature/detail/*Test.kt`

## Flutter Source Of Truth

对齐 `lib/tv_app/screens/tv_video_detail_screen.dart`：

- `_buildHeroArea`
- `_buildPlayerBox`
- `_buildInfoPanel`
- `_buildSourcesSection`
- `_buildEpisodesSection`
- `_focusNearestHeroControlFrom`
- `_focusPreferredSource`
- `_focusPreferredEpisodeInCurrentGroup`
- `_focusNextEpisodeGroupFirstItemOrShake`
- `_focusPreviousEpisodeGroupLastItemOrShake`
- `_focusRecommendationUpTarget`

## Architecture

### Presentation Layer

新增 `TvDetailPresentation.kt`，承载可单测的展示和焦点策略：

- `TvDetailSourceOption`
- `TvDetailEpisodeOption`
- `TvDetailEpisodeGroupOption`
- `TvDetailFocusArea`
- `TvDetailFocusMove`
- `TvDetailFocusGraph`
- `buildDetailSourceOptions`
- `buildDetailEpisodeGroups`
- `resolveDetailFocusMove`

Compose 只负责渲染和调用策略，不在 UI 分支里重复写排序、分组和跨组规则。

### Compose Layer

`TvDetailRoute` 拆成这些私有组件：

- `TvDetailTopBar`
- `TvDetailHeroSection`
- `TvDetailPreviewPlayer`
- `TvDetailInfoPanel`
- `TvDetailSourceSection`
- `TvDetailEpisodeSection`
- `TvDetailRecommendSection`
- `TvDetailBottomActions`

各组件通过明确参数和回调连接：

- `onSourceSelected(sourceId)`
- `onEpisodeSelected(episodeId)`
- `onEpisodeGroupSelected(groupIndex)`
- `onPlayPressed()`
- `onFavoriteToggle()`
- `onHistoryClick()`
- `onExitClick()`

### Focus Graph

焦点区域枚举：

```kotlin
enum class TvDetailFocusArea {
    Search,
    Player,
    Fullscreen,
    Favorite,
    Source,
    Episode,
    EpisodeGroup,
    Recommend,
    BottomAction,
}
```

显式规则：

- `Player.down -> Source`
- `Fullscreen.down / Favorite.down -> Source`
- `Source.up -> nearest Hero control`
- `Source.down -> nearest Episode`
- `Episode.up -> nearest Source`
- `Episode.down -> EpisodeGroup`，无分组时进入 `Recommend`，无推荐时进入 `BottomAction`
- `Episode.left/right` 在当前组内移动；到组边界时跨到上一组最后一集或下一组第一集；没有目标时停留当前项并触发边界反馈
- `EpisodeGroup.up -> same group nearest Episode`
- `EpisodeGroup.down -> Recommend`，无推荐时进入 `BottomAction`
- `Recommend.up -> EpisodeGroup` 优先；没有分组时回到 `Episode`
- 横向列表首尾不跳其它区域

Compose 使用 `FocusRequester` 和 `Modifier.focusProperties` 固化这些方向目标；列表内部方向键需要特殊处理时，通过 `onPreviewKeyEvent` 拦截并调用 focus graph。

## UI Layout

### Top Bar

- 左侧展示 `IvyTV` 和详情页说明。
- 右侧展示搜索按钮和当前时间。
- 作为详情页第一屏固定结构，不再完全依赖 `TvPageScaffold` 的标题。

### Hero

- 左侧 16:9 预览播放器，宽度约 620dp，低宽度时纵向堆叠。
- 无播放请求时展示封面/占位，不提前初始化重型播放器。
- 有播放请求后展示 `playerSurface`，loading 覆盖层使用单圈进度和网速。
- 右侧展示标题、年份/来源/集数、简介、全屏、收藏。

### Sources

- 来源按剧集数倒序展示。
- 当前来源首次固定在最前；用户主动切源后按剧集数排序。
- 文案为 `线路名（集数）`。
- 空线路时根据 `emptyPlaybackCompleted` 展示完成空态或临时空态。

### Episodes

- 每组 20 集。
- 选集横向列表在上，分组标签横向列表在下。
- 分组获焦不切换当前分组，确认键才切换显示范围。
- 选集左右跨组时仍停留在选集链路。

### Recommends

- 推荐为空时不渲染推荐区。
- 推荐为空时不渲染底部操作，避免页面底部多余可焦点项。

## Compatibility

- `TvDetailRoute` 现有 public signature 保持可用。
- 第一阶段 `TvDetailUiState` 的 `detail/currentSource/currentEpisode/currentGroupEpisodes/playbackRequest` 继续作为单一状态来源。
- 后续播放记录/退出收尾子任务可以继续复用本阶段组件和 focus graph。

## Testing Strategy

纯 Kotlin 单测优先覆盖：

- 来源排序和当前源固定。
- 20 集分组与标签。
- 线路首尾方向键停留。
- 全屏/收藏下键进入当前源。
- 线路下键进入最近选集，选集上键回最近线路。
- 选集左右跨组仍在选集链路。
- 推荐为空时布局模型不包含推荐和底部动作。

Compose UI 仅保留必要语义测试；焦点策略不依赖 Android instrumented test 才能稳定回归。

## Rollback

- 如果 Compose focusProperties 在当前 Compose 版本存在兼容问题，先保留 `TvDetailPresentation.kt` 的策略测试，UI 层回退到局部 `onPreviewKeyEvent` 请求焦点。
- 如果播放器 surface 和 focus scope 冲突，预览播放器外层保持焦点，播放器内部 `canFocus=false`。
