# 修复 Kotlin TV 详情页无数据设计

## Scope

- `core-data` 负责把精确详情和标题补源统一转换为 `TvVideoDetail`。
- `app-tv` 负责从路由 key 中解析 `source / id / title`，并为详情 ViewModel 注入与 Flutter TV 对齐的加载函数。
- `feature-tv-detail` 保持状态驱动 UI，不直接依赖网络或导航。

## Data Flow

1. 首页或分类页卡片生成 `source::id::title` 详情 key。
2. `TvNavGraph` 解析 key 并调用 `TvAppContainer.createDetailViewModel(source, videoTitle, ...)`。
3. `TvDetailViewModel.load(videoId)` 调用 `loadInitialDetail(videoId)`。
4. `TvAppContainer` 先尝试 `TvDetailRepository.loadDetail(source, id)`，仅当入口具备可直连身份时请求 `/api/detail`。
5. 精确详情为空、异常或没有可播放集数时，回退 `TvDetailRepository.loadDetailBySearchTitle(title, fallbackId, fallbackPoster...)`。
6. ViewModel 继续调用 `loadMoreSources(detail)` 合并更多线路。

## Contracts

- 可直连身份：`source` 和 `id` 非空，且 `source` 不是 `douban` / `bangumi`。
- 标题补源：优先用路由传入标题；为空时允许使用 `videoId` 兜底，但空查询不发请求。
- 匹配策略：标题归一化后相等；年份任一方为空、`unknown`、`未知` 时允许匹配。
- 去重策略：同一 `source + id` 保留剧集数量更多的来源。

## Risk

- 当前路由只携带 title，尚未携带 `searchTitle/poster/year`；本次不改路由结构，避免扩大兼容面。
- 工作区已有详情相关未提交改动，本次只做增量修复，不回滚既有代码。
