# 接入 Kotlin TV 历史和收藏数据

## Goal

让 Kotlin TV 播放历史页和收藏夹页接入真实后台数据，并支持删除/清空后的状态同步。

## Requirements

- `TvNavGraph` 必须创建并绑定 `TvHistoryViewModel` 和 `TvFavoritesViewModel`，不能继续直接渲染默认空状态。
- 历史页对齐 Flutter TV `TvVideoLibraryService.loadHistory/loadHistoryDirect` 和 `/api/playrecords` 口径。
- 收藏夹页对齐 Flutter TV `TvVideoLibraryService.loadFavorites` 和 `/api/favorites` 口径。
- 删除单条和清空全部必须先调用仓库动作，成功后同步当前 UI 列表。
- 页面必须区分 loading、空数据和错误态。
- 依赖 `05-31-kotlin-tv-network-repositories` 提供的 API/Repository 契约。

## Acceptance Criteria

- [x] 播放历史页能显示后台 `/api/playrecords` 返回的数据。
- [x] 收藏夹页能显示后台 `/api/favorites` 返回的数据。
- [x] 删除单条历史/收藏后当前列表同步移除。
- [x] 清空历史/收藏后当前列表同步为空。
- [x] 接口失败时页面展示错误态，不静默显示空列表。
- [x] ViewModel 测试覆盖加载、删除、清空、失败态。

## Notes

- 父任务：`.trellis/tasks/05-31-fix-kotlin-tv-pages-no-data`。
- 前置依赖：`05-31-kotlin-tv-network-repositories`。
