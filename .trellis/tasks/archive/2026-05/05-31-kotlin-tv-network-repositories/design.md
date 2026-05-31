# 补齐 Kotlin TV 后台接口和仓库契约 - Design

## Scope

本子任务补齐 Kotlin TV 端共享网络与数据契约，作为列表、搜索、播放历史、收藏夹页面接入真实数据的前置基础。

涉及模块：

- `re-android/core-network`
- `re-android/core-data`
- `re-android/app-tv`

## Confirmed Flutter API Contract

Flutter 端现有接口路径：

| Capability | Flutter source | Endpoint |
|------------|----------------|----------|
| 播放历史列表 | `PageCacheService.getPlayRecordsDirect` | `GET /api/playrecords` |
| 保存播放记录 | `ApiService.savePlayRecord` | `POST /api/playrecords` |
| 删除播放记录 | `ApiService.deletePlayRecord` | `DELETE /api/playrecords?key=<source+id>` |
| 清空播放记录 | `ApiService.clearPlayRecord` | `DELETE /api/playrecords` |
| 收藏夹列表 | `ApiService.getFavorites` | `GET /api/favorites` |
| 添加收藏 | `ApiService.favorite` | `POST /api/favorites` |
| 取消收藏 | `ApiService.unfavorite` | `DELETE /api/favorites?key=<source+id>` |
| 清空收藏夹 | `ApiService.clearFavorites` | `DELETE /api/favorites` |
| 搜索历史 | `ApiService.getSearchHistory` | `GET /api/searchhistory` |
| 搜索资源 | `ApiService.getSearchResources` | `GET /api/search/resources` |
| 搜索 | `ApiService.search` / `SearchService.searchSync` | `GET /api/search` |

## Target Boundaries

- `core-network` 定义 Retrofit API 和 DTO，不依赖 `core-data`。
- `core-data` 依赖 `core-network`，把 DTO 转成 `TvVideoCard`、搜索载荷、历史/收藏业务对象。
- `app-tv` 继续通过 `TvAppContainer.ensureSession()` 统一登录，页面不直接处理账号密码。
- `feature-tv-*` 不直接使用 Retrofit DTO。

## DTO Strategy

优先按 Flutter 模型字段建立最小 DTO：

- Play record: `source`、`id`、`title`、`source_name`、`cover`、`year`、`index`、`total_episodes`、`play_time`、`total_time`、`save_time`、`search_title`。
- Favorite item: `source`、`id`、`title`、`source_name`、`cover`、`year`、`total_episodes`、`save_time`、`origin`。
- Search result: `id`、`source`、`title`、`source_name`、`cover`、`year`、`total_episodes`。
- Search resource: `key`、`name`、`disabled`。

接口返回如果是 Map keyed by `<source>+<id>`，Repository 负责把 key 拆回 `source/id` 的兜底值。

## Repository Strategy

新增或扩展数据层仓库：

- `TvPlaybackRepository`
  - 读取远端播放历史。
  - 删除单条播放历史。
  - 清空播放历史。
  - 保留现有本地继续观看读取能力。
- `TvFavoritesRepository`
  - 读取远端收藏夹。
  - 删除单条收藏。
  - 清空收藏夹。
- `TvSearchRepository`
  - 读取搜索历史。
  - 读取搜索资源。
  - 执行基础搜索并返回 `TvSearchPayload`。
- `TvVideoLibraryRepository`
  - 提供分类列表查询入口。
  - 初期可复用后端搜索/资源能力；若后端无分类接口，必须在任务记录中明确缺口。

## Error Handling

- Retrofit 非 2xx、DTO 解析失败、缺少本地配置、登录失败都向调用方抛出明确异常。
- Repository 不把异常吞成空列表；空列表只代表接口成功但没有数据。
- `TvAppContainer` 仍是会话边界，所有真实数据请求前都先保证 Cookie。

## Compatibility

- 不改变 Flutter API。
- 不提交 `re-android/local.gateway.properties`。
- 保留现有 `admin/dashboard` 首页接口。
- 新 DTO 字段尽量 nullable/default，避免后端缺字段时整页崩溃。
