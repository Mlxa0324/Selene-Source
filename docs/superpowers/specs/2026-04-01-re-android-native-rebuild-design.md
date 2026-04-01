# Selene Android 原生重构设计

**日期：** 2026-04-01

## 目标

把当前 Flutter 版 Selene 重构为面向 Android 手机和 Android 平板的 Kotlin 原生应用，新工程位于根目录 `re-android/`。

这次重构不是把 Flutter 页面逐个翻译成 Kotlin，而是把现有产品能力重新组织为可长期维护的 Android 原生架构，同时尽量兼容现有服务端接口与业务语义。

## 现状判断

当前 Flutter 工程并不是单一播放器应用，而是多个独立子系统组合而成：

1. 登录与模式切换：服务器模式、本地订阅模式、自动登录。
2. 首页与内容聚合：首页推荐、历史、收藏、分类页。
3. 搜索链路：多源搜索、SSE 搜索、详情抓取、特殊资源站解析。
4. 点播播放器：HLS 播放、选集、换源、倍速、画面比例、PiP、睡眠定时。
5. 弹幕：自动匹配、手动匹配、设置持久化、seek 后同步。
6. 下载：M3U8 分片下载、断点续传、前台服务、离线播放。
7. 直播：直播源、频道分组、EPG、直播播放。
8. 资源站浏览：分类、分页、源切换。
9. 隐藏实验能力：播放器 benchmark 链路。

这意味着第一版原生工程必须先建立完整模块边界，再逐步把复杂能力做成稳定实现，而不是继续把逻辑堆在单个页面里。

## 设计原则

1. Android-only：只服务 Android 手机和平板，不再保留桌面端和 iOS 分支。
2. 接口尽量兼容：优先兼容现有服务端接口、Cookie 登录和业务语义。
3. 存储原生化：本地存储改为 Android 原生 schema，不强求兼容 Flutter 旧键名和旧文件布局。
4. 功能域拆分：按 `app / core / feature` 拆工程，不沿用 `screens/services/widgets/models` 横切结构。
5. 单一状态源：复杂页面通过 `ViewModel + UiState` 管理，避免巨型页面文件。
6. 手机平板共用能力层：只在导航壳和布局层区分设备，不复制业务逻辑。

## 总体方案

采用 `单 App + 多 feature module + Jetpack Compose + Media3` 的原生方案。

核心技术选型：

- UI：Jetpack Compose
- 导航：Navigation Compose
- 播放器：Media3 ExoPlayer
- 网络：Retrofit + OkHttp
- 本地数据库：Room
- 偏好设置：DataStore
- 后台任务：WorkManager
- 前台下载：Foreground Service
- 图片加载：Coil
- 依赖注入：Hilt
- 异步：Kotlin Coroutines + Flow

这样可以在首轮就铺开完整产品模块，同时保持工程可运行、可扩展、可测试。

## 工程结构

`re-android/` 建议采用以下结构：

```text
re-android/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
├── app/
├── core/
│   ├── common/
│   ├── ui/
│   ├── model/
│   ├── network/
│   ├── database/
│   ├── datastore/
│   ├── parser/
│   ├── player/
│   └── download/
└── feature/
    ├── startup/
    ├── auth/
    ├── home/
    ├── search/
    ├── detail/
    ├── player/
    ├── live/
    ├── sourcebrowser/
    ├── favorites/
    ├── history/
    ├── downloads/
    ├── settings/
    └── benchmark/
```

职责划分：

- `app`：应用入口、全局导航、权限与 deep link。
- `core/*`：跨功能复用的基础设施和通用模型。
- `feature/*`：按产品能力划分的页面、状态和业务编排。

## 数据层与兼容策略

### 1. 远端接口兼容

新工程优先兼容 Flutter 版现有服务端链路：

- 登录与自动登录
- 搜索源和资源站配置获取
- 搜索与详情
- 收藏、历史、搜索历史
- 直播源、频道、EPG
- 特殊资源站 HTML 详情解析

网络层统一收口为：

- `SeleneApi`
- `DownstreamApi`
- `SseSearchClient`
- `CookieStore`
- `AuthInterceptor`

401 或认证失效不在网络层直接导航，而是转换为认证状态事件，由 `feature/startup` 与 `feature/auth` 处理跳转。

### 2. 本地存储原生化

本地存储分为三层：

- `DataStore`：用户偏好、开关、主题、播放器设置、本地模式标记
- `Room`：收藏、历史、搜索历史、下载任务、弹幕匹配、源缓存
- 文件系统：离线视频、M3U8 清单、分片、封面缓存、原始弹幕/XML、M3U 内容

建议的核心实体：

- `AuthSessionEntity`
- `SearchSourceEntity`
- `PlayHistoryEntity`
- `FavoriteEntity`
- `SearchHistoryEntity`
- `DownloadTaskEntity`
- `DownloadSegmentEntity`
- `DanmakuMatchEntity`
- `SubscriptionSnapshotEntity`

### 3. 兼容边界

兼容优先级如下：

1. 服务端 API 兼容：高
2. 用户可见业务语义兼容：高
3. Flutter 本地键名、缓存目录、文件组织完全兼容：低

也就是说，新应用会尽量保持功能表现一致，但内部表结构、缓存目录和下载元数据按 Android 原生方式重建。

## 复杂子系统设计

### 1. 点播播放器

点播播放器以 `Media3 ExoPlayer` 为唯一主播放内核，不再保留 Flutter 时代的多后端切换设计。

关键单元：

- `PlayerRoute` / `PlayerScreen`
- `PlayerViewModel`
- `PlaybackSessionCoordinator`
- `AndroidVideoPlayerEngine`
- `PlayerUiState`

职责拆分：

- 页面负责渲染和交互分发
- `ViewModel` 负责状态编排
- 协调器负责串联详情、选集、换源、历史、完成态
- 播放引擎负责播放、seek、倍速、比例、PiP、亮度、音量

### 2. 弹幕

弹幕不直接照搬 Flutter 的渲染实现，而保留其业务语义与同步能力。

关键单元：

- `DanmakuRepository`
- `DanmakuParser`
- `DanmakuMatcher`
- `DanmakuSyncController`
- `DanmakuOverlay`

需要覆盖的行为：

- 自动匹配和手动匹配
- 设置持久化
- seek 后快速重建索引
- 暂停恢复
- 与播放速度同步
- 横竖屏字体和显示区域适配

### 3. 下载

下载系统采用 Android 后台任务体系重建，不再让页面直接承载任务生命周期。

关键单元：

- `DownloadRepository`
- `M3u8DownloadPlanner`
- `SegmentDownloadWorker`
- `DownloadForegroundService`
- `OfflineCatalog`
- `DownloadsViewModel`

能力目标：

- M3U8 分片下载
- 并行调度
- 断点续传
- 前台服务保活
- 离线播放索引
- 播放页快速加入下载

### 4. 直播

直播与点播共用底层播放器能力，但业务编排分开。

关键单元：

- `LiveRepository`
- `LiveChannelGrouper`
- `LiveViewModel`
- `LivePlayerViewModel`

能力目标：

- 直播源切换
- 频道分组与筛选
- 频道搜索
- EPG 读取与展示
- 直播播放

### 5. 资源站浏览

资源站浏览作为独立功能域实现：

- 源切换
- 分类树
- 分页列表
- 快速返回顶部
- 从资源站条目进入详情或播放器

### 6. Benchmark

`benchmark` 模块保留为隐藏实验功能，不接入默认主导航。首轮先完成模块接线与隐藏入口边界，后续按需要再补完整体验。

## 导航与页面信息架构

### 1. 手机

手机采用底部导航 + 独立详情页/播放器页：

- 首页
- 搜索
- 直播
- 资源站
- 下载
- 我的/设置

收藏和历史既保留首页区块，也在“我的”中提供独立入口。

### 2. 平板

平板采用 `NavigationRail + 双栏/三栏布局`：

- 搜索：结果列表 + 详情预览
- 直播：分组 + 频道 + 节目单/播放器
- 下载：任务列表 + 详情
- 资源站：源/分类 + 内容网格
- 播放器非全屏：视频区 + 右侧控制面板

平板不是简单放大手机版，而是默认提供更高信息密度与更少跳转。

### 3. 导航参数

导航层只传稳定参数，不承载业务状态：

- 搜索到详情：`source + id + title`
- 详情到播放器：`source + id + episodeIndex + lineIndex`
- 首页继续观看到播放器：`playHistoryId` 或 resume 参数
- 下载到离线播放：`downloadTaskId`

## 测试策略

虽然原项目测试覆盖不高，但 `re-android/` 必须从一开始建立基础测试骨架。

建议测试层次：

1. 单元测试
   - parser
   - repository
   - use case
   - player state reducer
   - danmaku matcher / sync logic
2. 数据库测试
   - Room DAO
   - migration
   - 下载任务状态流转
3. UI 测试
   - Compose screen state rendering
   - 手机/平板布局分支
   - 关键交互如搜索、播放控制、下载操作
4. 集成测试
   - 登录到首页
   - 搜索到播放
   - 下载到离线播放
   - 直播频道切换

首轮最低要求：

- 核心 parser 有单元测试
- Room schema 和 migration 有测试
- 至少覆盖启动、搜索、播放器、下载的关键 `ViewModel`

## 迁移顺序

这次是全量铺开，但实现顺序仍然必须分层推进：

1. 建立 `re-android/` Gradle 工程、模块和基础依赖
2. 建立 `core/common`、`core/model`、`core/network`、`core/ui`
3. 建立 `feature/startup`、`feature/auth`，打通启动与登录模式
4. 建立 `feature/home`、`feature/search`、`feature/detail`
5. 建立 `core/player` 与 `feature/player`
6. 建立 `core/download` 与 `feature/downloads`
7. 建立 `feature/live` 与 `feature/sourcebrowser`
8. 补齐 `feature/favorites`、`feature/history`、`feature/settings`
9. 接入 `feature/benchmark` 的隐藏入口和归档说明

这条顺序的目的，是先保证工程和核心主链路稳定，再逐步把复杂子系统装进来。

## 第一版交付边界

由于用户要求全量铺开，第一版代码生成的目标不是只做空目录，而是做到：

1. `re-android/` 成为可编译、可运行的 Android 原生工程。
2. 全部一级功能域都有模块和基础路由接线。
3. 启动、登录/本地模式、首页、搜索、详情、播放器、下载、直播、资源站浏览都有基础可运行链路。
4. 收藏、历史、设置、本地偏好与下载元数据完成原生落库。
5. 弹幕、DLNA、benchmark 至少完成接口边界与基础骨架，复杂实现按模块逐步补深。

这一定义允许首轮既覆盖全量产品版图，又避免承诺一次性把每个复杂细节都做到 Flutter 当前成熟度。

## 非目标

以下内容不作为本次设计的目标：

1. 兼容桌面端和 iOS。
2. 保持 Flutter 本地缓存格式和旧键名完全一致。
3. 保留 Flutter 多播放器后端切换方案。
4. 在第一轮就追平所有弹幕、DLNA、benchmark 的边缘交互细节。

## 风险与应对

### 1. 范围过大

风险：功能域很多，容易做成“全有模块、全没深度”的空骨架。  
应对：先搭稳定基础设施，再优先打通主链路，每个复杂子系统都有明确可运行最小闭环。

### 2. 播放器页复杂度再次失控

风险：Android 版若仍把状态和渲染混在页面，会复制 Flutter 的巨页问题。  
应对：播放器强制拆为引擎、协调器、`ViewModel`、UI 四层。

### 3. 下载与离线播放容易和页面耦合

风险：任务生命周期受页面影响。  
应对：统一收敛到 `Repository + Worker + ForegroundService`。

### 4. 平板适配沦为放大版手机

风险：宽屏体验差，后续还要重做导航。  
应对：从一开始设计独立的平板布局壳和多栏信息架构。

## 结论

`re-android/` 应作为一个 Android-only 的全新原生工程来建设：接口尽量兼容旧系统，本地实现彻底原生化，按功能域拆分模块，用 Compose 构建手机和平板共用的产品能力层。

这样才能在保留 Selene 全量产品面的同时，把当前 Flutter 工程已经显现出的复杂度问题收束到可维护的 Android 架构中。
