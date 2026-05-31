# 修复 Kotlin TV 页面接口无数据 - Implement

## Checklist

1. 执行子任务 `05-31-kotlin-tv-network-repositories`
   - 补齐 `/api/playrecords`、`/api/favorites`、`/api/searchhistory`、`/api/search/resources`、`/api/search` 等接口契约。
   - 建立共享 DTO 和 Repository 映射。
   - 添加 Repository 和 DTO 单元测试。

2. 执行子任务 `05-31-kotlin-tv-list-search-data`
   - 给分类列表页增加真实加载状态。
   - 给搜索页接入 `TvSearchViewModel` 和真实搜索仓库。
   - 更新 `TvNavGraph` 注入逻辑和页面错误态。

3. 执行子任务 `05-31-kotlin-tv-history-favorites-data`
   - 给历史页接入 `TvHistoryViewModel` 和真实历史仓库。
   - 给收藏页接入 `TvFavoritesViewModel` 和真实收藏仓库。
   - 补删除/清空成功后的列表同步和失败态。

4. 父任务整体验收
   - 对照 Flutter TV 端页面数据能力做最终清单。
   - 启动 Kotlin TV 后验证填写本地网关配置后页面不再静默空数据。
   - 确认 `re-android/local.gateway.properties` 未被暂存或提交。

## Risk Points

- 后台接口路径和返回结构需以 Flutter TV 端实际调用或后端现有接口为准，不能凭名称猜接口。
- 当前工作区有 Flutter TV 播放器任务未提交改动，实施时不要覆盖这些文件。
- 如果后台接口缺失，需要在任务中记录阻塞点，再决定是否新增后端接口或先接已有接口。

## Validation Commands

```bash
./re-android/gradlew -p re-android :core-network:testDebugUnitTest :core-data:testDebugUnitTest
./re-android/gradlew -p re-android :feature-tv-home:testDebugUnitTest :feature-tv-history:testDebugUnitTest :feature-tv-favorites:testDebugUnitTest :app-tv:testDebugUnitTest
./re-android/gradlew -p re-android :core-network:lintDebug :core-data:lintDebug :feature-tv-home:lintDebug :feature-tv-history:lintDebug :feature-tv-favorites:lintDebug :app-tv:lintDebug
git diff --check
```
