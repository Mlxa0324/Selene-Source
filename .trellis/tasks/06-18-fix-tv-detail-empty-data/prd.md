# 修复 Kotlin TV 详情页无数据

## Goal

修复首页或其他 Tab 页进入详情页时无数据的问题，按 Flutter TV 端详情页数据加载逻辑尽量 1:1 对齐。

## Confirmed Facts

- Flutter TV 详情页以完整 `VideoInfo` 为入口：先 `source + id` 精确加载可播源；当入口无可播放身份、精确加载失败或未命中时，继续用 `searchTitle` 或 `title` 后台搜索补源。
- Flutter TV 判断可直连身份时排除 `douban` / `bangumi`；这类入口只能走标题补源。
- Flutter TV 补源完成仍没有线路时展示明确空态：搜索已完成，未找到可播放信息，而不是一直转圈或直接停在错误页。
- Kotlin TV 当前详情入口通过 `source::id::title` key 传递，`TvAppContainer.createDetailViewModel()` 只有在 `source` 为空或 `douban` 时才标题搜索；当 `source/id` 存在但 `/api/detail` 返回异常或空集数时会直接错误，导致首页或分类页进入详情页无数据。
- Kotlin `TvVideoCard` 已带 `searchTitle` 字段，但详情路由当前只传 title；本次先按现有路由能力使用 title 兜底，避免扩大到路由 payload 重构。

## Requirements

- 首页、电影、剧集、动漫、综艺、搜索、历史、收藏等 Tab 卡片进入详情页时，只要标题能搜索到可播源，详情页必须展示播放线路和选集。
- 精确详情接口优先；精确详情失败、来源不可直连或返回无可播集数时，必须继续按标题补源，不直接进入错误态。
- 标题补源需要按 Flutter 的 `searchTitle/title` 思路选择搜索词，并过滤到当前影片：标题归一化匹配，年份为空/未知时允许匹配。
- 补源结果需要去重，同一 `source + id` 保留集数更多的线路。
- 如果精确详情和标题补源都没有任何可播源，详情页保留正式空态或错误态，不崩溃。

## Acceptance Criteria

- [x] 新增/更新单测覆盖：精确详情失败后，Kotlin TV 会按标题搜索并构建详情模型。
- [x] 新增/更新单测覆盖：精确详情返回空集数时，Kotlin TV 会按标题搜索并构建可播详情模型。
- [x] 新增/更新单测覆盖：`douban` / 空来源入口不请求 `/api/detail`，直接按标题补源。
- [x] 新增/更新单测覆盖：标题补源按标题和年份过滤，年份缺失时允许匹配。
- [x] 首页或其他 Tab 传来的 `source::id::title` key 可继续兼容现有解析。
- [x] 相关 Android unit test 通过。

## Validation

- `./re-android/gradlew -p re-android :core-data:testDebugUnitTest :feature-tv-detail:testDebugUnitTest :app-tv:testDebugUnitTest`
- `git diff --check -- re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepository.kt re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvAppContainer.kt re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepositoryTest.kt re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/TvAppContainerTest.kt`

## Notes

- 用户要求“创建任务并直接开始”，本任务在写入必要计划后直接进入实现。
