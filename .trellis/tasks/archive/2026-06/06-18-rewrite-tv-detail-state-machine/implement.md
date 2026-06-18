# Kotlin TV 详情状态机和数据链路执行计划

## Read Before Coding

- `.trellis/spec/frontend/tv-mode.md`
- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/backend/error-handling.md`
- `.trellis/spec/guides/cross-layer-thinking-guide.md`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- 父任务：`.trellis/tasks/06-18-rewrite-kotlin-tv-detail-from-flutter`

## Checklist

### 1. 红灯测试：状态机核心

- [x] 补 `TvDetailViewModelTest`：精确源先到，立即生成播放请求，补源后追加线路。
- [x] 补 `TvDetailViewModelTest`：标题补源先到，立即生成播放请求，精确源后到追加线路。
- [x] 补 `TvDetailViewModelTest`：精确源失败不进错误态，补源成功后可播。
- [x] 补 `TvDetailViewModelTest`：两路完成无源时 `emptyPlaybackCompleted=true`。
- [x] 补 `TvDetailViewModelTest`：续播记录读取不阻塞精确源和标题补源请求启动。
- [x] 补 `TvDetailViewModelTest`：有续播目标时等待目标源，未命中前不自动起播。

### 2. 重写 ViewModel 状态模型

- [x] 引入 `TvDetailEntry`、`TvDetailResumeRecord`、必要的内部 load token。
- [x] 扩展 `TvDetailUiState`，显式加入 loaded flags、empty completed、resume target、playback request。
- [x] 保留现有 UI 依赖的派生属性：`currentSource`、`currentEpisode`、`episodeGroups`、`currentGroupEpisodes`。

### 3. 实现加载状态机

- [x] `load(entry)` 启动精确源、标题补源、续播、收藏读取。
- [x] `mergeSources` 支持新增、覆盖更完整源、当前源刷新。
- [x] `maybeSelectInitialSource` 对齐 Flutter 首播源选择。
- [x] `refreshLoadingFlags` 对齐首屏/补源 loading。
- [x] 异步回包检查 load token。

### 4. 续播目标和播放请求

- [x] `loadResumeRecord` 返回后设置目标和续播秒数。
- [x] 有目标时等待目标源；全部完成后回退。
- [x] `playbackRequest` 使用当前源/集和续播秒数。
- [x] `selectEpisode`、`selectSource` 更新请求并保持集数位置。

### 5. Repository / Container 接线

- [x] `TvDetailRepository` 增补 `loadExactSources(entry)` 或等价方法。
- [x] `TvDetailRepository` 标题补源支持 entry 中的 `searchTitle/year`。
- [x] `TvAppContainer.createDetailViewModel()` 注入新 loader。
- [x] 保持旧 route 输入兼容。

### 6. 绿灯验证

- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest --tests org.moontechlab.selene.tv.feature.detail.TvDetailViewModelTest`
- [x] `./re-android/gradlew -p re-android :core-data:testDebugUnitTest --tests org.moontechlab.selene.tv.core.data.repository.TvDetailRepositoryTest`
- [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.TvAppContainerTest`
- [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest :core-data:testDebugUnitTest :app-tv:testDebugUnitTest`
- [x] `git diff --check -- <changed files>`

## Implementation Record

- 2026-06-18：重写 `TvDetailViewModel` 为 Flutter TV 同款双路状态机，新增 `TvDetailEntry`、`TvDetailResumeRecord`、`TvDetailResumeTarget`。
- 2026-06-18：精确源、标题补源、续播记录、收藏读取并行启动；续播记录不阻塞网络请求启动，但会拦截首次选源，避免继续观看误播非目标源。
- 2026-06-18：新增 loaded flags、`emptyPlaybackCompleted`、续播目标和完成空态；`TvDetailRoute` 在搜索完成无源时展示“搜索已完成，未找到可播放信息”。
- 2026-06-18：`TvDetailRepository` 增加精确源和入口标题补源方法，`TvAppContainer` 改为注入新 loader，并保留旧 `source::id::title` route 兼容。

## Rollback Points

- 如果 ViewModel 重写影响旧 UI 编译，先保留旧字段和派生属性作为兼容层。
- 如果协程并行测试不稳定，先用可注入 fake loader + deterministic test dispatcher。
- 如果 route entry 扩展牵连过大，本阶段只内部使用 `source/videoId/title`，把完整 route payload 留给 UI 子任务。
