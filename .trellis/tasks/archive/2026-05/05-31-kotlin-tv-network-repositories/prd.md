# 补齐 Kotlin TV 后台接口和仓库契约

## Goal

补齐 Kotlin TV 端缺失的后台 API、DTO 和 Repository 契约，为列表、搜索、播放历史、收藏夹等页面提供统一真实数据来源。

## Requirements

- 对照 Flutter `ApiService` / `PageCacheService` / `SearchService` 的接口路径，确认 Kotlin TV 需要接入的最小后台接口。
- 在 `core-network` 中补齐接口定义和响应 DTO，不让 feature 层直接拼接口路径。
- 在 `core-data` 中补齐 Repository 和 DTO 到 `TvVideoCard` 等业务模型的转换。
- 所有接口必须复用 `TvAppContainer` 维护的登录 Cookie，不重复散落登录逻辑。
- 接口失败时向调用方返回明确异常或错误结果，不能静默吞掉后变成空列表。

## Acceptance Criteria

- [x] `SeleneTvApi` 覆盖 `/api/playrecords`、`/api/favorites`、`/api/searchhistory`、`/api/search/resources`、`/api/search` 等当前页面所需接口，或在文档中记录无法接入的后端缺口。
- [x] `core-data` 提供列表/搜索/历史/收藏所需 Repository。
- [x] DTO 映射覆盖 Flutter 端 `PlayRecord`、`FavoriteItem`、`SearchResult` 的关键展示字段。
- [x] 单元测试覆盖接口 DTO 映射成功、空数据和异常路径。

## Notes

- 依赖父任务：`.trellis/tasks/05-31-fix-kotlin-tv-pages-no-data`。
- 此子任务必须先完成，列表/搜索、历史/收藏子任务才能接入真实仓库。
