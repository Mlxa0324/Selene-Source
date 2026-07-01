# 重做 Kotlin TV 详情页技术设计

## Architecture

本次按 Flutter TV 的详情状态机重建 Kotlin TV 详情页，分四层：

1. `core-data`
   - 继续由 `TvDetailRepository` 负责精确详情、标题补源、更多源去重和业务模型转换。
   - 增补详情入口上下文模型，必要时承载 `source / id / title / searchTitle / year / posterUrl / stype`。
   - 播放记录、收藏、推荐分别由独立仓库或容器注入，不让 UI 直接读网络。

2. `feature-tv-detail`
   - `TvDetailViewModel` 重写成详情状态机，拆分事件、阶段和选择器。
   - `TvDetailUiState` 显式描述：初始加载、精确源完成、补源完成、当前源、当前集、续播目标、预览 loading、退出状态、空态原因、推荐状态。
   - UI 组件只消费状态和回调，不做网络、导航、播放器协议细节。

3. `feature-tv-detail` UI 组件
   - `TvDetailRoute` 变成组合入口。
   - 新增私有/内部组件：顶部栏、Hero、预览播放器框、信息面板、线路横向列表、选集横向列表、分组列表、推荐区、底部操作。
   - 每个组件只管理本组件的视觉和焦点请求器，不持有业务状态。

4. `app-tv`
   - `TvNavGraph` 仍负责解析详情 route 和导航到全屏/搜索/历史。
   - `TvAppContainer` 注入仓库、播放器会话、偏好读写、播放记录读写、收藏读写。
   - 不在 `feature-tv-detail` 内持有 `NavController`。

## Data Flow

```text
Route key
  -> TvDetailEntry
  -> TvAppContainer.createDetailViewModel(entry, playerSession)
  -> TvDetailViewModel.load(entry)
     -> launch exact detail
     -> launch title/more source search
     -> launch latest resume record
     -> launch favorite/ad/player preference
     -> first playable source selected
     -> PlaybackRequest emitted
     -> PlayerEngine.load(request)
     -> PlayerState updates preview progress/loading
     -> delayed recommend load after playback starts
```

## State Contracts

- `isInitialLoading` 只代表“还没有可展示详情，且精确源/补源未全部完成”。
- `isMoreSourcesLoading` 代表后台补源尚未结束，不阻止已有源播放。
- `playbackRequest` 只在当前源、当前集和 URL 都有效时生成。
- `previewLoading` 由详情状态机维护，不能直接等同 `PlayerState.Loading`。
- `emptyPlaybackCompleted` 在精确源和标题补源都结束且无可播源时为 true。
- `isExiting` 一旦为 true，后续异步结果和播放器事件全部忽略。

## Source Selection

首播源选择顺序：

1. 非继续观看入口：精确源或补源中第一个可播源立即起播。
2. 继续观看入口：
   - 优先匹配最新播放记录中的 `source + id`。
   - 其次同资源站 `source`。
   - 再其次同线路名。
   - 搜索全部完成仍未命中时，选择集数匹配记录的源或最佳可用源。

线路展示顺序：

- 默认按集数倒序，相同集数保持返回顺序。
- 首次进入时当前源固定展示在第一位，避免补源后当前线路跳动。
- 用户主动换源后恢复纯排序结果。

## Resume And Progress

- 加载详情时并行读取最新继续观看记录。
- 首次播放请求必须携带最新续播秒数。
- 播放器上报真实进度后，如果仍未到达续播点附近，限次 `seekTo(startAt)` 补偿。
- 保存播放记录节流：播放位置小于 1 秒不保存；10 秒内重复进度不重复保存。
- 换源时保留当前集数和播放秒数，先保存新源记录，成功后再清理旧源记录。

## Focus Design

显式焦点图：

- 顶部搜索：左回播放器，上/右边界停留，下到全屏按钮。
- 播放器：确认进全屏，下到当前线路，左边界抖动。
- 全屏/收藏：上到搜索，下到当前线路。
- 线路：上按水平位置回播放器/按钮，下到最近选集，左右首尾边界抖动。
- 选集：上到最近线路，下到分组或推荐，左右支持跨组切换。
- 分组：上到最近选集，下到推荐；焦点移动只改变焦点，不切分组，确认才切换。
- 推荐：获焦滚到底部；确认 `pushReplacement` 新详情。

需要优先复用 `TvFocusableCard`；如果当前共享组件不支持显式方向目标和滚动跟随，则在 `core-design/focus` 增补能力，而不是在页面里散落按键逻辑。

## UI Layout

- 顶部栏固定在详情页第一屏，展示 `IvyTV`、说明、搜索、当前时间。
- Hero 使用 16:9 预览播放器 + 右侧信息面板。
- 线路、选集、分组均为 flush 横向视口，内容使用页面统一 40dp 左基线和焦点安全留白。
- 空态和 loading 使用正式用户文案，不出现开发中、TODO、占位类文案。
- 推荐为空时不渲染推荐区和底部操作，避免尾部空白。

## Compatibility

- 保持旧 route：`source::id::title`。
- 可新增兼容解析：`source::id::title::searchTitle::year::posterUrl` 或改为 request store，但旧 key 必须继续可用。
- `TvDetailRepository` 已有标题补源能力，重做时复用并补足 `searchTitle/year/poster` 入参。
- 当前仓库工作区较脏，不回滚其它正在进行的 TV 改动；只修改详情链路必要文件。

## Rollback

- 状态机重写集中在 `feature-tv-detail` 和 `TvAppContainer` 注入层。
- 如果 UI 重写风险过大，可以先保留旧 `TvDetailRoute` 壳，替换 ViewModel 和状态，再逐段替换组件。
- 每完成一段用 focused unit test 锁住行为，避免最后一次性排错。
