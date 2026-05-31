# 接入 Kotlin TV 列表和搜索数据

## Goal

让 Kotlin TV 的电影、剧集、动漫、综艺列表页和搜索页接入真实后台数据，不再只展示默认空状态。

## Requirements

- `TvNavGraph` 不能继续给分类页直接传 `TvVideoLibraryUiState.forCategory(...)` 后结束，必须接入 ViewModel 或等价状态加载。
- 搜索页必须创建并绑定 `TvSearchViewModel`，提交搜索后调用真实 Repository。
- 列表和搜索页面必须区分 loading、空数据和错误态。
- 数据字段、排序和过滤口径优先对照 Flutter TV 端 `TvHomeScreen.defaultLoadCategoryData`、`TvSearchScreen`、`SearchService.searchSync`。
- 依赖 `05-31-kotlin-tv-network-repositories` 提供的 API/Repository 契约。

## Acceptance Criteria

- [x] 电影、剧集、动漫、综艺至少能通过后台或已有数据源加载列表数据。
- [x] 搜索页提交关键词后能显示后端搜索结果。
- [x] 列表/搜索接口失败时页面展示错误态，不静默显示空列表。
- [x] ViewModel 测试覆盖成功、空数据、失败态。

## Notes

- 父任务：`.trellis/tasks/05-31-fix-kotlin-tv-pages-no-data`。
- 前置依赖：`05-31-kotlin-tv-network-repositories`。
