# Flutter 全端分类封面加载问题分析设计

## Analysis Scope

本任务包含静态诊断和已确认 Flutter 性能问题的最小修复。分析对象限定为两条 Flutter 链路：

1. **Flutter 普通端分类页**
   - 页面：`lib/screens/movie_screen.dart`、`tv_screen.dart`、`anime_screen.dart`、`show_screen.dart`。
   - 列表/卡片：`lib/widgets/douban_movies_grid.dart`、`lib/widgets/video_card.dart`。
   - 公共图片：`lib/utils/image_url.dart`、`lib/services/user_data_service.dart`。
2. **Flutter TV**
   - 页面：`lib/tv_app/screens/tv_home_screen.dart`、`tv_video_library_screen.dart`。
   - 列表/卡片：`lib/tv_app/widgets/tv_video_grid.dart`、`tv_video_card.dart`。
   - 公共图片：`lib/utils/image_url.dart`、`AppCacheService`。

明确排除 `re-android/`、`kotlin-tv/` 和其它原生 TV 工程，不因它们存在相似问题而扩大本任务范围。

## Implementation Boundary

- 允许共享 Flutter 配置/缓存服务提供进程内缓存和并发请求合并。
- 允许 TV 卡片复用共享的默认缓存服务实例。
- 不改变图片 URL 转换、请求头、直连/代理选择、分页触发、图片预取或解码策略。
- 保留带依赖注入构造函数的 `AppCacheService`，测试和设置页专用实例不能被共享单例替代。

## Data and Image Flow Map

### Flutter TV

```text
category page data/page N
  -> TvVideoGrid SliverGrid lazy child
  -> TvVideoCard
  -> _TvCoverImage
  -> getImageUrl + image-source setting Future
  -> deferred-loading / viewport gate
  -> AppCacheService disk-cache decision Future
  -> CachedNetworkImage or Image.network
  -> request headers + decode + paint
```

关键门控是串联的：URL Future 未结束、滚动仍建议延迟、卡片不在 viewport、缓存策略 Future 未结束，任一条件都可能只显示骨架而不发真实请求。

### Flutter 普通分类页

```text
Douban service/category page
  -> DoubanMoviesGrid
  -> VideoCard
  -> getImageUrl(source, image-source setting)
  -> CachedNetworkImage/Image.network path
  -> cache/network/decode
```

这条链路不应直接套用 TV 视口门控结论，必须单独确认分页和图片组件行为。

## Hypothesis Matrix

| 假设 | 可解释现象 | 必须观察的证据 | 初始置信度 |
|---|---|---|---|
| Flutter TV 延迟/viewport/缓存 Future 门控导致请求未放行 | 首屏快，后续卡片停在骨架，滚动停止后才出现 | 卡片 build、视口、deferred、真实请求开始时间 | 高 |
| 直连豆瓣图片对未缓存请求返回慢/403/超时 | 已缓存快，未缓存慢或失败；代理源可能不同 | 最终 host、HTTP 状态、响应耗时、失败类型、请求头 | 高 |
| 分页数据已追加但焦点/懒列表没有触发或组合 | 后续标题/卡片数据存在，图片请求数不增长 | 页码、列表长度、组合 item、触底事件 | 中 |
| 每张 Flutter 卡片重复异步读取缓存策略/URL 设置造成请求排队 | 后续批次同时出现较长等待，网络尚未开始 | Future 完成时间、卡片数量、请求开始间隔 | 高，源码问题已修复 |
| URL 字段或图片 host 在后续数据中不同/失效 | 只有某些批次或来源失败 | 原始封面字段、最终 URL、格式/尺寸 | 中 |
| 解码或内存压力使后续图片被回收/失败 | 请求成功但图片迟迟不绘制、设备内存上升 | HTTP 成功、decode 错误、GC/内存、图片尺寸 | 低到中 |

置信度只能在完成运行时对照后更新；静态代码只能证明存在门控或潜在竞态，不能证明某个网络假设已经发生。

## Evidence Collection Contract

每个样本统一记录：

```text
端实现 / APK 版本 / 设备 API
tab / filter / page / item index / title
raw image URL -> final image URL / source key
card composed? / in viewport? / deferred? / cache hit?
request started / response status / response duration / decode result / paint result
```

日志或截图中不得保留 Cookie、授权信息、完整查询参数或用户数据。URL 对外汇报时可只保留 scheme、host、路径模板和 hash。

## Decision Rules

- 有数据但没有 card composition：归类为分页/懒列表/焦点触发问题。
- 有 composition 但没有 request started：归类为 Flutter 门控、空 URL 或图片组件条件问题。
- 有 request started 但无 response/状态异常：归类为直连网络、反盗链、DNS、连接或请求头问题。
- response 成功但 decode/paint 失败：归类为格式、尺寸、解码器、内存或 Flutter 生命周期问题。
- 只有某一条 Flutter 链路失败：优先查该端 loader/门控/配置，不改公共 URL 逻辑。
- 两条链路访问同一 URL 均失败：优先查图片源、反盗链和网络环境。
- 只有缓存命中样本正常不能证明源站正常；必须清理或绕过缓存后复现。

## Change Constraint

本轮可以修改已确认的 Flutter 重复配置/缓存读取路径。不得为了猜测网络原因修改图片组件、请求头或图片源；如果现有日志不足，报告中继续明确标注“需要后续最小诊断埋点”。
