# Kotlin TV 详情状态机和数据链路设计

## Scope

本阶段只重建详情页状态机和数据加载链路，不做最终视觉和焦点图重写。

涉及文件预计为：

- `re-android/feature-tv-detail/src/main/java/.../TvDetailViewModel.kt`
- `re-android/core-data/src/main/java/.../TvDetailRepository.kt`
- `re-android/app-tv/src/main/java/.../TvAppContainer.kt`
- `re-android/app-tv/src/main/java/.../navigation/TvDestination.kt`（仅当需要扩展 route payload）
- 对应 `*Test.kt`

## Models

### TvDetailEntry

详情入口上下文：

- `source`: 播放来源。
- `videoId`: 视频 ID。
- `title`: 展示标题和标题补源兜底。
- `searchTitle`: 搜索标题，缺省使用 `title`。
- `year`: 年份过滤，缺省允许匹配未知年份。
- `posterUrl`: 封面兜底。
- `stype`: movie/tv 类型过滤，可为空。

旧 route 只携带 `source::id::title` 时，构建 entry 时补齐缺省字段。

### TvDetailUiState

关键字段：

- `detail`: 当前详情基础信息。
- `sources`: 所有已发现播放源。
- `currentSourceId`: 当前源 ID。
- `currentEpisodeId`: 当前集 ID。
- `isInitialLoading`: 首屏是否还在等可展示结果。
- `isMoreSourcesLoading`: 后台补源是否进行中。
- `initialSourcesLoaded`: 精确源是否结束。
- `moreSourcesLoaded`: 标题补源是否结束。
- `emptyPlaybackCompleted`: 搜索完成仍无源。
- `resumeTarget`: 续播目标 source/id。
- `resumePositionMs`: 续播秒数。
- `playbackRequest`: 当前可下发给播放器的请求。
- `errorMessage`: 不可恢复错误；普通源加载失败不写这里。

## Loader Contracts

`TvDetailViewModel` 构造参数从单个 `loadInitialDetail` 改为多 loader：

- `loadExactSources(entry): List<TvVideoSource>`
- `loadMoreSources(entry, onIncremental): List<TvVideoSource>`
- `loadResumeRecord(entry): TvDetailResumeRecord?`
- `loadFavoriteState(entry): Boolean`
- `loadRecommends(entry, detail): List<TvVideoCard>` 后续阶段可保留空实现

其中 `loadMoreSources` 的 `onIncremental` 是对齐 Flutter SSE 增量回调的接口。Kotlin 当前 Retrofit search 是批量结果时，也要通过同一入口回调一次。

## State Machine

```text
Idle
  -> Loading(entry)
      launch exact
      launch more
      launch resume
      launch favorite
  -> FirstPlayableSelected
      playbackRequest emitted
      isInitialLoading=false
      isMoreSourcesLoading may remain true
  -> SourcesCompleted
      moreSourcesLoaded=true
      emptyPlaybackCompleted=true if no source
```

每个异步回包处理前检查：

- load token 一致。
- `isExiting == false`。
- 当前 entry 未被新 load 覆盖。

## Source Merge

合并 key：`source.id` 或 `source + videoId`，以 `TvVideoSource.id` 为第一选择。

规则：

- 新源为空不改变状态。
- 不存在则追加。
- 已存在且新源剧集更多，则覆盖。
- 当前源被覆盖且已有当前集下标仍合法，保留集数位置。
- 当前源被空集数替换为真实剧集时，重新应用续播集数。

## Initial Source Selection

无续播目标：

- `preferAsCurrent=true` 时优先 incoming first。
- 否则 all first。

有续播目标：

1. `source + id` 完全匹配。
2. 同 `source`。
3. 同线路名（如果记录里有线路名）。
4. 搜索未完成前不回退。
5. 搜索完成后选择同集数源，否则选择剧集最多源。

## Playback Request

`playbackRequest` 派生自当前状态：

- `videoId`: 当前详情 ID。
- `videoTitle`: 当前详情标题。
- `sourceId`: 当前源 source。
- `episodeId`: 当前集 ID。
- `episodeIndex`: 当前集下标。
- `episodeTitle`: 当前集标题。
- `url`: 当前集 URL。
- `startPositionMs`: 首次续播或切源保留进度。

本阶段只负责生成请求和更新状态，不实现保存记录节流。

## Error Handling

- 精确源异常：记录内部诊断，标记 `initialSourcesLoaded=true`。
- 标题补源异常：标记 `moreSourcesLoaded=true`。
- 两者结束仍无源：`emptyPlaybackCompleted=true`，UI 走正式空态。
- `ensureSession` 或配置缺失这种入口级失败仍可进入 `errorMessage`。

## Compatibility

- `TvDetailRoute` 当前可继续消费 `state.detail/currentSource/currentEpisode/playbackRequest`。
- 旧 UI 可以先保持视觉结构不变，只根据新 state 展示 loading/empty。
- `TvAppContainer.createDetailViewModel(source, videoTitle, playerEngine)` 可先保留签名，内部构建 `TvDetailEntry`，后续 UI 子任务再扩展 route。
