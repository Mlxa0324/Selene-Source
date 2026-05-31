# 接入 Kotlin TV 历史和收藏数据 - Implement

## Preconditions

- `05-31-kotlin-tv-network-repositories` 已完成并提供：
  - 播放历史 API/DTO。
  - 收藏夹 API/DTO。
  - 历史和收藏 Repository。
  - DTO 到 `TvVideoCard` 的映射测试。

## Checklist

1. 更新状态模型
   - 为 `TvHistoryUiState` 增加 `isLoading`、`errorMessage`。
   - 为 `TvFavoritesUiState` 增加 `isLoading`、`errorMessage`。
   - 保留 `videos` 作为页面列表唯一展示来源。

2. 更新 ViewModel
   - `load()` 先进入 loading，再调用 Repository。
   - 成功后写入 `videos` 并清空错误。
   - 失败后退出 loading，保留旧数据并写入 `errorMessage`。
   - `deleteVideo()` 和 `clear()` 失败时不能先改列表。

3. 更新 Route
   - loading 状态展示加载态。
   - error 状态展示错误态。
   - 空数据状态展示正式空态。
   - 有数据时继续展示 `TvPosterGrid`。

4. 更新 `TvAppContainer`
   - 新增 `createHistoryViewModel()`。
   - 新增 `createFavoritesViewModel()`。
   - 复用统一 `ensureSession()` 和 `requireGatewayClient()`。

5. 更新 `TvNavGraph`
   - History route 中创建并 collect `TvHistoryViewModel`。
   - Favorites route 中创建并 collect `TvFavoritesViewModel`。
   - 用 `LaunchedEffect(viewModel)` 触发首次加载。

6. 补充测试
   - 历史 ViewModel：加载成功、加载失败、删除成功、删除失败、清空成功、清空失败。
   - 收藏 ViewModel：加载成功、加载失败、删除成功、删除失败、清空成功、清空失败。
   - 必要时补 Route 测试，确认错误态不再显示成空列表。

## Validation Commands

```bash
./re-android/gradlew -p re-android :feature-tv-history:testDebugUnitTest :feature-tv-favorites:testDebugUnitTest :app-tv:testDebugUnitTest
./re-android/gradlew -p re-android :feature-tv-history:lintDebug :feature-tv-favorites:lintDebug :app-tv:lintDebug
git diff --check
```

## Rollback Notes

- 若前置 Repository 接口不可用，只保留状态模型和错误态改造，不把页面切到不可运行的真实仓库。
- 不触碰 Flutter TV 当前未提交文件。
