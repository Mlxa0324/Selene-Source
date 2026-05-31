# 修复 Kotlin TV 页面接口无数据

## Goal

对照 Flutter TV 端已有数据能力，补齐并修复 Kotlin TV 端页面接口接入，解决填写本地后台地址、用户名、密码后各页面仍无数据的问题。

## User Report

- 本地后台地址、用户名、密码已填写。
- Kotlin TV 端打开后多个页面没有显示数据。
- 受影响页面包括但不限于：首页、列表查询、收藏夹、播放历史。
- 用户期望按 Flutter TV 端的数据口径完整对齐，而不是只显示静态占位或空态。

## Confirmed Context

- 之前已完成 `re-android/local.gateway.properties` 的本地网关配置读取。
- 之前已修复 `app-tv` 缺少 `INTERNET` 权限导致的启动闪退。
- 当前已知 Kotlin TV 端只明确接入过登录和首页 `admin/dashboard` 链路，其他页面接口是否完整接入需要逐页核对。
- 真实本地网关配置文件必须保持 Git 忽略，不能提交地址、账号或密码。
- 代码证据显示 `SeleneTvApi` 当前只定义了 `admin/dashboard` 和登录相关链路，未定义 `/api/playrecords`、`/api/favorites`、`/api/search`、`/api/search/resources` 等 Flutter 端已使用接口。
- `TvNavGraph` 当前只有首页和设置页创建 ViewModel；电影、剧集、动漫、综艺直接传默认 `TvVideoLibraryUiState`，搜索、历史、收藏直接渲染默认 state。
- Kotlin `TvSearchRepository.search()` 当前固定返回空结果，历史/收藏 ViewModel 虽然存在但没有在 `app-tv` 中注入真实加载函数。

## Task Map

- `05-31-kotlin-tv-network-repositories`：先补齐后台 API、DTO 和 Repository 契约。
- `05-31-kotlin-tv-list-search-data`：在共享契约完成后接入分类列表和搜索页数据。
- `05-31-kotlin-tv-history-favorites-data`：在共享契约完成后接入播放历史和收藏夹数据。

## Requirements

- 逐页核对 Kotlin TV 端与 Flutter TV 端的数据来源和接口契约，确认哪些页面仍是占位数据、空仓库或未绑定 ViewModel。
- 修复本地后台登录后页面数据不显示的问题，优先覆盖最基础的列表查询、收藏夹、播放历史。
- 首页、分类列表、搜索/列表查询、收藏夹、播放历史必须通过同一套本地后台网关配置和会话 Cookie 访问数据。
- 接口失败时必须展示可诊断错误态，不能静默空列表导致用户误以为没有数据。
- 保持设置页中的本地网关配置只读取/展示本地值，不提交真实配置。
- 不顺带重构 Flutter TV 播放器转圈任务中已有未提交改动。

## Acceptance Criteria

- [x] 有一份 Kotlin TV 页面到 Flutter TV 数据能力的对照清单，标明已接入、未接入和差异点。
- [x] 填写有效本地后台配置后，Kotlin TV 首页能显示后端返回的分区数据或明确错误态。
- [x] 列表查询/分类页能显示后端返回的视频列表或明确错误态。
- [x] 收藏夹页面能显示后端收藏数据，删除/清空动作如已暴露则同步列表状态。
- [x] 播放历史页面能显示后端历史数据，删除/清空动作如已暴露则同步列表状态。
- [x] 所有新增或修改接口都有 focused 单元测试或可执行验证覆盖成功、空数据、失败态。
- [x] `re-android/local.gateway.properties` 不被提交。

## Kotlin TV / Flutter TV Data Capability Matrix

| Page | Flutter TV data capability | Kotlin TV status | Notes |
|------|----------------------------|------------------|-------|
| 首页 | 后台首页分区 + 继续观看记录 | 已接入 | `TvAppContainer.createHomeViewModel()` 统一登录后读取 `admin/dashboard` 和 `/api/playrecords`。 |
| 电影 / 剧集 / 动漫 / 综艺 | 分类/搜索数据源返回列表 | 已接入 | `TvVideoLibraryViewModel` 通过 `TvVideoLibraryRepository` 复用 `/api/search` 拉取首期分类列表。 |
| 搜索 | 搜索历史、搜索资源、搜索结果 | 已接入 | `TvSearchRepository` 覆盖 `/api/searchhistory`、`/api/search/resources`、`/api/search`，页面展示结果或错误态。 |
| 播放历史 | `/api/playrecords` 读取、删除、清空 | 已接入 | `TvHistoryViewModel` 绑定真实仓库，删除时使用 Flutter 兼容 `source+id` key。 |
| 收藏夹 | `/api/favorites` 读取、删除、清空 | 已接入 | `TvFavoritesViewModel` 绑定真实仓库，删除时使用 Flutter 兼容 `source+id` key。 |
| 详情 / 播放器 | 详情补源与播放链路 | 既有实现 | 不属于本次页面无数据修复范围。 |

## Notes

- 这是跨网络层、数据层、多个功能页的任务，需要 `design.md` 和 `implement.md` 后再进入实现。
- 当前播放器转圈任务仍在进行中，工作区已有 Flutter TV 文件改动；本任务实施时需避免覆盖那部分未提交变更。
- 当前任务作为父任务管理整体验收，具体实现落到子任务中独立完成。
