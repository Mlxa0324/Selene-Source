# 修复 Kotlin TV 页面接口无数据 - Design

## Scope

本任务聚焦 Kotlin 原生 TV 工程 `re-android/`，对照 Flutter TV 端已有页面数据能力补齐接口接入。

当前优先页面：

- 首页分区数据。
- 分类/列表查询页。
- 搜索结果页。
- 播放历史页。
- 收藏夹页。

不处理当前 Flutter TV 播放器 loading 任务中的未提交文件。

## Current Risk

用户已填写本地后台配置但页面无数据，可能有三类根因：

- 页面仍使用静态 `UiState` 或占位数据，没有 ViewModel/Repository 加载链路。
- 网络层只定义了首页接口，缺少列表、历史、收藏等 API。
- 接口失败被 UI 当成空列表展示，缺少错误态和日志线索。

代码检查已确认：

- `SeleneTvApi` 当前只有 `@GET("admin/dashboard")`。
- `TvNavGraph` 对 Movie/Tv/Anime/Show 只传 `TvVideoLibraryUiState.forCategory(...)`。
- `TvNavGraph` 对 Search/History/Favorites 只调用 Route 默认 state，没有创建 ViewModel。
- `TvSearchRepository.search()` 当前固定返回 `emptyList()`。
- Flutter 端真实数据路径包括 `/api/playrecords`、`/api/favorites`、`/api/searchhistory`、`/api/search/resources`、`/api/search`。

## Target Architecture

Kotlin TV 页面统一采用以下数据流：

```text
TvLocalGatewayConfig
  -> TvAppContainer
  -> SeleneTvGatewayClient / SeleneTvApi
  -> core-data Repository
  -> feature-tv-* ViewModel
  -> feature-tv-* Route(state)
```

## Subtasks

| Subtask | Responsibility | Depends On |
|---------|----------------|------------|
| `05-31-kotlin-tv-network-repositories` | 补齐 `core-network` API/DTO 和 `core-data` Repository | none |
| `05-31-kotlin-tv-list-search-data` | 分类列表和搜索页接入真实 ViewModel 状态 | network/repositories |
| `05-31-kotlin-tv-history-favorites-data` | 播放历史和收藏夹接入真实 ViewModel 状态 | network/repositories |

## Boundaries

- `app-tv` 只负责依赖装配、导航和 ViewModel 创建。
- `core-network` 只负责 Retrofit API、请求/响应 DTO、Cookie 会话。
- `core-data` 负责把接口 DTO 转成 TV 业务模型。
- `feature-tv-*` 只负责 ViewModel 状态、页面渲染和用户动作。
- Flutter `lib/tv_app/` 只作为数据能力对照来源，不在本任务中改播放器相关逻辑。

## Error Handling

- 缺少本地配置、登录失败、接口失败、解析失败都必须进入页面错误态。
- 空数据与接口失败必须区分：空数据展示正式空态，接口失败展示错误文案。
- 登录 Cookie 复用由 `TvAppContainer.ensureSession()` 统一处理，功能页不重复登录。

## Validation Strategy

- 单元测试覆盖 Repository 映射和 ViewModel 成功/失败/空数据状态。
- Gradle 验证优先覆盖受影响模块：
  - `:core-network:testDebugUnitTest`
  - `:core-data:testDebugUnitTest`
  - `:feature-tv-home:testDebugUnitTest`
  - `:feature-tv-history:testDebugUnitTest`
  - `:feature-tv-favorites:testDebugUnitTest`
  - `:app-tv:testDebugUnitTest`
  - 相关 lint。
- 如设备可用，安装启动后通过 logcat 或页面状态确认没有静默空数据。
