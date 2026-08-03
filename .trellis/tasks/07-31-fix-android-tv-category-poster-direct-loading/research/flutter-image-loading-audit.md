# Flutter 分类封面加载静态排查报告

## 结论摘要

当前没有连接 Android 设备（`adb devices -l` 只有表头），所以本报告能确认源码链路和高概率性能瓶颈，但不能确认豆瓣直连请求的实际 HTTP 状态、DNS、首字节时间或图片解码耗时。

目前最可信的结论不是“所有后续图片都单纯被直连源拖慢”，而是两类问题叠加；其中源码确认的重复异步工作已完成 Flutter 最小修复：

1. Flutter TV 有明确的**卡片开放、焦点触底、滚动/viewport 和缓存策略多级门控**，后续数据即使已经追加，也可能尚未构建或尚未真正发起图片请求。
2. Flutter TV 的每张卡片都会新建 `AppCacheService`，再次通过 Android MethodChannel 查询存储空间；同时每张卡片独立读取图片源配置。后续批量卡片会产生大量重复异步工作，足以造成“后面图片加载很慢”。这部分已通过共享默认服务、并发 Future 合并和图片源 key 内存缓存修复。
3. Flutter 普通分类页没有 TV 的 viewport 门控，但 `GridView` 嵌在 `SingleChildScrollView` 中并启用 `shrinkWrap`，当前列表批量追加后会集中构建卡片并发请求；直连豆瓣的并发、反盗链、连接或响应耗时仍需设备网络证据确认。

## 已确认的 Flutter TV 链路

### 1. 后续卡片不是数据到达就立即请求图片

`lib/tv_app/widgets/tv_video_grid.dart`：

- 默认首批只开放 80 个条目，之后每批开放 40 个（约 140-158 行）。
- `_visibleItemCount` 只决定有多少条目能参与构建和焦点导航（约 193-197、241-249 行）。
- 焦点接近当前批次尾部时才追加可构建卡片（约 454-470 行）。
- 分页请求不是由图片或滚动位置直接触发，而是焦点进入倒数第二行才触发（约 739-763 行）。

因此“列表数据已追加但图片没请求”必须先检查卡片是否已经组合；只看接口列表长度不能证明图片链路已启动。

### 2. 每张 TV 卡片有四层等待

`lib/tv_app/widgets/tv_video_card.dart`：

- `initState` 为每张卡片建立 `_coverFuture` 和 `_useImageDiskCacheFuture`（约 613-618 行）。
- `getImageUrl` 完成前显示骨架（约 750-760 行）。
- 滚动仍被 `Scrollable.recommendDeferredLoadingForContext` 延迟，或卡片不在 viewport 时，每 120ms 重试一次（约 638-742 行）。
- 放行后还要等缓存策略 Future，再选择 `CachedNetworkImage` 或 `Image.network`（约 772-810 行）。

这解释了“滚动中不加载、停下来才加载”的设计行为；如果卡片已在稳定视口仍长时间停留骨架，则再进入存储查询或网络请求阶段排查。

### 3. TV 存在高概率的重复平台调用

`lib/tv_app/widgets/tv_video_card.dart:616-618` 每张卡片都执行：

```dart
AppCacheService().shouldUseImageDiskCache()
```

`AppCacheService` 的 `_cachedUseImageDiskCache` 是实例字段（`lib/services/app_cache_service.dart:71-72`），而 `shouldUseImageDiskCache()` 未命中实例缓存时会调用 `selene/storage` MethodChannel 查询可用空间（约 89-100、172-185 行）。由于调用方每张卡片都创建新实例，缓存无法跨卡片复用。后续页一次放行几十张卡片时，会重复进行平台通道调用和 `StatFs` 查询，并把每张图片请求挡在第二个 FutureBuilder 后面。

同样，`getImageUrl()` 对豆瓣来源每张卡片都会调用 `UserDataService.getDoubanImageSourceKey()`；该方法原先每次从 `SharedPreferences` 读取（`lib/services/user_data_service.dart:807-810`），没有进程内图片源 key 缓存。现在已缓存 key，并在保存设置后主动刷新，避免卡片批次重复等待配置读取。

## 已确认的 Flutter 普通分类页链路

### 1. 普通端没有 TV 的视口延迟门控

`lib/widgets/video_card.dart:72-109` 在 `build` 中创建 `getImageUrl(...)` Future，Future 完成后直接构建 `CachedNetworkImage`。图片请求有 placeholder/errorWidget，但没有 TV `_isInViewport` 或滚动延迟策略。

### 2. 分类页会集中构建当前列表

`lib/widgets/douban_movies_grid.dart:191-215` 使用 `GridView.builder`，但同时设置 `shrinkWrap: true` 和 `NeverScrollableScrollPhysics`，外层由分类页的 `SingleChildScrollView` 负责滚动。分页追加后，当前列表会在一个外层滚动布局中集中参与测量/构建，后续 25 条图片可能同时进入请求阶段。

四个普通分类页都使用类似分页方式：滚动接近底部 50px 时请求下一页，默认 `pageLimit=25`，并将新数据追加到列表。`DoubanService.getCategoryData()` 的数据缓存只缓存分类 API 数据，不等于图片已缓存。

### 3. 直连模式的 URL 和请求头逻辑

`lib/utils/image_url.dart`：

- `direct` 分支保留原始图片 URL（约 8-31 行）。
- URL 命中豆瓣域名时添加 `Referer: https://movie.douban.com/`、Android User-Agent 和 Accept（约 36-49 行）。
- 因此静态上没有发现“直连模式被错误改成代理 URL”的问题；但仍需真实设备确认原始 host 的 HTTP 状态、响应时间和是否出现限速/403。

## 根因排序

| 范围 | 结论 | 证据等级 | 说明 |
|---|---|---|---|
| Flutter TV | 后续图片受多级 lazy/deferred/viewport 门控，可能未发请求 | 高 | 源码直接证明，专项测试也覆盖“滚动时延迟图片请求” |
| Flutter TV | 每张卡片重复创建 `AppCacheService`，重复调用存储 MethodChannel | 高，已修复 | 改为共享默认服务，并合并同一批并发策略读取；真实帧耗时仍需设备测量 |
| Flutter TV/普通 Flutter | 每张卡片重复读取图片源 SharedPreferences | 中高，已修复 | `UserDataService` 增加进程内 key 缓存、并发读取合并和保存后刷新；真实占比仍需设备测量 |
| Flutter 普通端 | 后续页集中构建并发起大量未缓存请求 | 高 | `shrinkWrap + 外层滚动 + pageLimit=25` 已确认 |
| Flutter 普通端/TV | 豆瓣直连源的 403、超时、DNS、连接复用或限速 | 中 | 现有源码无法给出 HTTP 证据，当前无设备 |
| Flutter 普通端/TV | 图片格式、尺寸或内存解码压力 | 低到中 | 当前没有 decode/GC/内存日志 |

## 验证结果

- `flutter analyze lib/tv_app/widgets/tv_video_card.dart lib/tv_app/widgets/tv_video_grid.dart lib/tv_app/screens/tv_home_screen.dart lib/widgets/douban_movies_grid.dart lib/widgets/video_card.dart lib/utils/image_url.dart`：通过，无 issues。
- `flutter test test/tv_app/tv_video_card_test.dart test/tv_app/tv_video_library_screen_test.dart test/widgets/video_card_metadata_test.dart`：通过，33 项。
- `flutter test test/tv_app/tv_video_card_test.dart test/tv_app/tv_video_library_screen_test.dart test/tv_app/tv_home_screen_test.dart test/widgets/video_card_metadata_test.dart`：有 1 项既有布局断言失败：`tv_home_screen_test.dart:41` 期望 `40`，实际 `46.0`；其余图片/网格相关测试通过。该失败与图片请求链路无直接关系，未修改。
- `adb devices -l`：当前没有可用设备，未能完成真实 APK、HTTP 和解码层验证。

## Implemented Flutter-Only Follow-up

- `AppCacheService.instance` 由启动清理、TV 设置默认操作和 TV 封面卡片共享；保留构造函数注入能力供测试和特殊调用方使用。
- `AppCacheService.shouldUseImageDiskCache()` 合并并发存储查询，并在清理缓存时使旧策略读取失效。
- `UserDataService.getDoubanImageSourceKey()` 合并并发偏好读取，`saveDoubanImageSource()` 保存后立即刷新内存 key。
- 未修改 `getImageUrl()` 的 URL 转换、图片请求头、直连/代理选择，也未修改普通端/TV 的分页与 viewport 门控。
- 相关服务、TV 卡片、TV 列表和普通卡片测试共 50 项通过；受影响文件 `flutter analyze` 通过。

## 下一步建议

在用户提供可运行 Flutter Android APK/设备后，先只加诊断或使用现有工具确认以下断点，不直接改图片策略：

1. 后续页数据长度是否增加。
2. 目标卡片是否进入组合、是否已进入 viewport、是否仍被 deferred gate 拦截。
3. `_useImageDiskCacheFuture` 完成前后各耗时多少，`selene/storage` 调用次数是否随卡片数增长。
4. 图片请求是否发出；发出后记录最终 host、HTTP 状态、响应时间、解码结果。

如果设备证据确认请求仍根本未发出，继续单独评估 Flutter TV 图片门控/分页触发；如果请求已发出且直连返回慢或失败，再单独创建图片网络/请求头任务。普通端的集中并发请求应与 TV 门控问题分开评估。
