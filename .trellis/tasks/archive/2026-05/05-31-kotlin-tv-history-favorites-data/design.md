# 接入 Kotlin TV 历史和收藏数据 - Design

## Scope

本子任务只处理 Kotlin TV 播放历史页和收藏夹页的数据接入。

涉及模块：

- `re-android/app-tv`
- `re-android/feature-tv-history`
- `re-android/feature-tv-favorites`
- `re-android/core-data`
- `re-android/core-network`

## Confirmed Current State

- `TvNavGraph` 当前直接调用 `TvHistoryRoute()` 和 `TvFavoritesRoute()`，没有创建或绑定 ViewModel。
- `TvHistoryViewModel` / `TvFavoritesViewModel` 已存在，但当前只接收注入函数，没有与 `app-tv` 容器连接。
- `TvHistoryUiState` / `TvFavoritesUiState` 只有 `videos` 字段，缺少 loading 和 error。
- `TvHistoryRoute` / `TvFavoritesRoute` 只按 `videos.isEmpty()` 展示空态，接口失败会和真实空数据混在一起。
- Flutter TV 端历史使用 `/api/playrecords`，收藏使用 `/api/favorites`。

## Dependency

本子任务依赖 `05-31-kotlin-tv-network-repositories`：

- 需要网络层提供 `/api/playrecords` 和 `/api/favorites` 的 Retrofit API。
- 需要数据层提供历史和收藏 Repository。
- 需要 DTO 映射到 `TvVideoCard` 的统一业务模型。

如果前置子任务未完成，本任务只能补 UI 状态结构，不能完成真实数据接入。

## Target Data Flow

```text
TvNavGraph
  -> TvAppContainer.createHistoryViewModel()
  -> TvHistoryRepository
  -> SeleneTvApi.getPlayRecords()
  -> TvHistoryUiState
  -> TvHistoryRoute

TvNavGraph
  -> TvAppContainer.createFavoritesViewModel()
  -> TvFavoritesRepository
  -> SeleneTvApi.getFavorites()
  -> TvFavoritesUiState
  -> TvFavoritesRoute
```

## State Contract

历史和收藏状态都需要显式表达：

- `videos`: 当前列表。
- `isLoading`: 页面是否正在加载。
- `errorMessage`: 接口失败或配置失败时的错误信息。

空数据和接口失败必须分开：

- `videos.isEmpty() && errorMessage == null && !isLoading` 展示正式空态。
- `errorMessage != null` 展示错误态。
- `isLoading == true` 展示加载态。

## Delete / Clear Contract

- 删除单条：先调用 Repository 删除，成功后再从 `videos` 移除对应卡片。
- 清空全部：先调用 Repository 清空，成功后再置空 `videos`。
- 删除/清空失败：保留原列表并展示错误信息。

## Out Of Scope

- 不实现搜索和分类列表。
- 不定义新的后端接口路径；路径来自前置网络契约子任务。
- 不修改 Flutter TV 播放器和设置页当前未提交改动。
