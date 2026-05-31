# 补齐 Kotlin TV 后台接口和仓库契约 - Implement

## Checklist

1. 读取现有契约
   - `re-android/core-network/src/main/java/.../SeleneTvApi.kt`
   - `re-android/core-network/src/main/java/.../model/`
   - `re-android/core-data/src/main/java/.../repository/`
   - Flutter `ApiService` / `PageCacheService` / `SearchService` 对应接口。

2. 扩展 `core-network`
   - 给 `SeleneTvApi` 增加播放历史、收藏、搜索历史、搜索资源、搜索接口。
   - 新增 DTO 文件，字段名用 `@SerializedName` 对齐 snake_case。
   - 对 Map 响应使用 `Map<String, Dto>`，由数据层处理 key。

3. 扩展 `core-data`
   - 扩展 `TvPlaybackRepository`，增加远端历史读/删/清空。
   - 新增 `TvFavoritesRepository`。
   - 扩展 `TvSearchRepository`，从固定空结果改为依赖 API。
   - 必要时新增 `TvVideoLibraryRepository` 作为分类列表入口。

4. 更新 `app-tv` 容器准备点
   - 保持 `ensureSession()` 为所有远端请求前置。
   - 暂不把页面切换到新仓库，留给页面子任务接入。

5. 补测试
   - `core-network` DTO key/path 契约测试。
   - `core-data` Repository 映射测试：
     - 播放历史 map -> `TvVideoCard`。
     - 收藏 map -> `TvVideoCard`。
     - 搜索结果 list -> `TvSearchPayload`。
     - 失败时异常不被吞成空列表。

6. 验证
   - 运行 `core-network` 和 `core-data` 单测、lint。
   - 运行 `git diff --check`。
   - 确认未暂存本地网关配置。

## Validation Commands

```bash
./re-android/gradlew -p re-android :core-network:testDebugUnitTest :core-data:testDebugUnitTest
./re-android/gradlew -p re-android :core-network:lintDebug :core-data:lintDebug
git diff --check
git check-ignore -v re-android/local.gateway.properties
```

## Review Gate

本任务规划完成后再执行：

```bash
python3 ./.trellis/scripts/task.py start 05-31-kotlin-tv-network-repositories
```

启动后进入实现阶段，先完成共享网络/仓库，再回到历史/收藏和列表/搜索子任务。
