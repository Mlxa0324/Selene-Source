# 修复 Flutter TV 详情页进入卡顿（WebView/2GB设备）

## Goal

在 Flutter TV 端修复进入 `TvVideoDetailScreen` 时的首段卡顿问题，优先降低 2GB 运存电视设备上的首帧、首个可交互状态和首播前等待成本。

本任务不是继续做“原因分析”，而是把上一轮分析里已确认的高优先级问题真正落成代码优化，重点缓解：

- 详情页刚进入时的明显卡一下
- 首个可播源出现前后 UI 和播放器一起抖一下
- 2GB 设备上 WebView 初始化过重导致的早期发涩

## Requirements

## User Value

- 2GB 电视端进入详情页时，用户能更快看到稳定页面，不会先被明显卡顿打断。
- 首个可播源到达后，播放器能更顺地进入加载与起播，不再在页面进入瞬间承受过多无关工作。
- Flutter TV 的详情页优化后，不影响已有的换源、选集、收藏、推荐和续播业务行为。

## Confirmed Facts

- 已有归档分析任务：
  - `.trellis/tasks/archive/2026-06/06-02-analyze-flutter-tv-detail-entry-jank-factors/`
- 上一轮分析确认了 4 个优先级：
  1. `WebViewPlayerAdapter -> InAppWebView -> loadData(HTML + hls.js + JS bridge)` 首次初始化是最重共因
  2. 详情页进入阶段多异步回调和状态波动是第二层放大器
  3. 详情页较重的 UI / 焦点树会继续放大体感
  4. 图片和推荐区已后移，当前不是第一嫌疑
- 当前 `TvVideoDetailScreen.initState()` 会并行触发：
  - `_loadM3u8ProxyUrl()`
  - `_loadResumeRecordThenStartDetailLoading()`
  - `_loadFavoriteState()`
  - `_loadAdFilterPreference()`
- 当前 `_loadResumeRecordThenStartDetailLoading()` 结束前，不会进入 `_startDetailLoading()`。
- 当前详情页会先构建 `url: null` 的 `VideoPlayerWidget`，控制器先挂载，首个可播源命中后再走 `_playCurrentEpisode() -> updateDataSource(startAt) -> _initializePlayer(startAt)`。
- `VideoPlayerWidget.initState()` 即使 `url == null`，仍会执行：
  - `_initializePlayer()`
  - `_setupPip()`
  - `_registerPipObserver()`
  - `_bindPipControlChannel()`
  - `_pushPipActionsState(...)`
- 当前 TV 详情页内嵌播放器使用 `showControls: false`、`enablePip: false`。
- 当前 `AppCacheService.lowStorageThresholdBytes` 为 `500MB`，且 `main()` 会在进入 App 前调用 `AppCacheService().prepareBeforeAppEnter()` 执行缓存整理。

## Requirements

### R1: 首播关键链路只保留“必须现在做”的动作

- 详情页进入时，不能再让续播记录读取阻塞精确源请求启动。
- 详情页首播关键链路应尽量只剩：
  - 精确源尽快命中
  - 首次 `updateDataSource(startAt)` 下发
  - 底层 ready / progress 回流

### R2: 无播放 URL 时不提前拉起重型播放器初始化

- 详情页还没有真正可播 URL 时，应避免提前执行高成本 WebView 初始化。
- 预览播放器区域允许先渲染轻量占位 UI，但不应在空态下装配完整 WebView 页面。

### R3: 收紧进入详情页早期的状态波动

- 收藏态、广告偏好、代理预热、后台补源等次要任务不能把详情页推进成多次剧烈状态切换。
- 优化后不能让“源命中 -> loading 结束 -> ready/buffering/play 回流”在视觉上形成更强抖动。

### R4: 不破坏已有 TV 详情页业务语义

- 保持继续观看、换源、选集、推荐延后、共享搜索会话、空源提示、进度保存等既有行为不回退。
- 不引入新的焦点丢失、详情页白屏或首播失败问题。

### R5: 下调低空间阈值，避免 2GB 设备过早禁用图片磁盘缓存

- Flutter TV 端缓存低空间阈值从 `500MB` 调整到 `200MB`。
- 调整后，只有当 Android 可用空间低于 `200MB` 时，启动前缓存整理才额外清理图片磁盘缓存，并暂时关闭新的图片磁盘缓存写入。
- 该调整不能破坏现有缓存管理页面展示、低空间提示和相关测试语义。

## Acceptance Criteria

- [x] `TvVideoDetailScreen` 不再等待续播记录读取完成后才启动精确源请求。
- [x] `VideoPlayerWidget` 在 `url == null` 的 TV 详情预览占位态下，不再提前拉起重型 WebView 初始化链路。
- [x] 详情页首个可播源命中后，播放器仍能正确承接续播集数和 `startAt`，继续观看不回退到 0 秒。
- [x] `AppCacheService.lowStorageThresholdBytes` 从 `500MB` 调整到 `200MB`，相关缓存策略测试同步更新通过。
- [x] 现有 TV 详情页相关测试通过；新增或更新测试覆盖“详情页首播不被续播读取阻塞”和“空 URL 不提前初始化重播放器”。
- [x] 至少运行针对性 `flutter analyze` 和相关 `flutter test`，确认没有编译或回归问题。

### 当前证据快照

- 第 1 条已完成：`TvVideoDetailScreen.initState()` 已改为并行启动 `_loadResumeRecord()` 与 `_startDetailLoading()`，不再等待续播记录读取完成才发起详情源加载。
- 第 2 条已完成：`VideoPlayerWidget` 在 `url == null` 时不再提前执行 `_initializePlayer()` / PiP 初始化链路，仅保留控制器回传与轻量占位态。
- 第 3 条已完成：详情页在续播记录晚于首屏源返回时，会通过 `_syncPendingPlaybackWithLatestResumeRecord()` 与 `_hasPendingInitialPlaybackAfterResumeLoad` 对齐首次集数和 `startAt`，避免回退到 0 秒。
- 第 4 条已完成：`AppCacheService.lowStorageThresholdBytes` 已从 `500MB` 下调到 `200MB`，相关缓存测试已同步更新通过。
- 第 5、6 条已完成：本地已通过
  - `flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart lib/widgets/video_player_widget.dart lib/services/app_cache_service.dart`
  - `flutter test test/tv_app/tv_video_detail_screen_test.dart`
  - `flutter test test/services/app_cache_service_test.dart test/widgets/video_player_widget_preload_config_test.dart`

## Out Of Scope

- 重写播放器内核，或把 WebView 主链路整体替换成 media_kit
- 调整搜索页、首页、全屏播放器的独立性能问题
- 依赖真机 adb 采样才能确认的系统 WebView / GC 细节
- Kotlin TV 原生端性能优化

## Open Questions

- 当前没有额外产品决策阻塞；本任务按“上一轮分析已完成，直接进入修复实现”的范围推进。

## Acceptance Criteria

## Notes

- 这是复杂修复任务，必须补 `design.md` 和 `implement.md` 再进入 `task.py start`。
- 本任务默认以 Flutter 侧可直接落地的优化为主，不把“需要真机确认的进一步分析”混进第一轮修复里。
