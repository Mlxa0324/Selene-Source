# re-android Kotlin 原生 TV 重建设计

**日期：** 2026-05-30

## 背景

Selene 当前已经有一套可用的 Flutter TV 端实现，核心页面、焦点交互、返回链、设置页、详情页和 TV 全屏播放器都已经形成稳定的产品语义。现计划在 `re-android/` 目录下直接重建一套 Kotlin 原生 Android TV 工程，尽量复刻现有 Flutter TV 端的样式、操作习惯、数据加载方式和播放体验。

用户明确要求：

- Kotlin 原生 TV 工程直接落在 `re-android/`，旧内容已清空，后续不再沿用旧结构。
- 首期产品能力以现有 Flutter TV 端已交付部分为准，不凭空扩展新产品线。
- 播放器采用 `ExoPlayer 主内核 + WebView 兜底` 的双内核方案。
- 用户可以在 TV 全屏底部菜单的“其它”里单击切换 `ExoPlayer / WebView`。
- 切换语义为软重载：允许短暂黑屏或转圈，但切换后仍停留在当前全屏、当前集和当前进度附近。
- 需要严格区分主线程与后台线程，避免页面滚动、焦点移动和菜单动画被播放链路拖慢。

## 目标

- 在 `re-android/` 下重建 Kotlin 原生 Android TV 工程。
- 首期完整对齐现有 Flutter TV 端已交付能力：
  - 首页
  - 搜索页
  - 详情页
  - 播放历史页
  - 收藏夹页
  - 设置页
  - TV 全屏播放器
- 顶部导航、右上角快捷入口、焦点规则、返回链、换源换集、继续观看、播放记录和设置交互保持与 Flutter TV 端一致。
- 默认使用 ExoPlayer 作为在线播放主内核，保留 WebView 兼容兜底能力。
- 提供原生可观测的播放器状态、切源、切集、切内核和 seek 指标，为后续逐步替代 WebView 提供依据。

## 非目标

- 首期不接入 DLNA。
- 首期不接入 TV 本地离线下载与离线播放入口。
- 首期不把“直播”做成真实业务页面，仅保留与现有 Flutter TV 端一致的“开发中”占位页语义。
- 首期不追求一次性抹掉全部 WebView 兼容路径，重点是让 ExoPlayer 成为默认主内核并可在异常流上兜底。
- 不改变 Flutter 普通端已有逻辑，本次重建聚焦 `re-android/` 原生 TV 工程。

## 方案对比

### 方案 A：ExoPlayer 单内核

只实现 ExoPlayer，不保留 WebView。

优点：

- 架构最纯粹。
- 后续维护成本最低。

缺点：

- 首期风险高，个别异常在线流一旦出现兼容问题，没有产品级退路。
- 不符合用户明确要求的“ExoPlayer 主内核 + WebView 兜底”。

### 方案 B：ExoPlayer 主内核 + WebView 兜底，统一播放器协议

页面层只依赖统一播放器协议，底层实现 `ExoPlayerEngine` 与 `WebViewPlayerEngine` 两套内核，并在全屏播放器内提供手动切换入口。

优点：

- 符合用户明确要求。
- 绝大多数路径可以优先走原生主内核。
- 兼容问题可通过 WebView 兜底，降低首期上线风险。
- 后续可基于指标逐步压缩 WebView 使用范围。

缺点：

- 状态迁移、切换容错和线程边界需要设计完整。

### 方案 C：双内核常驻并实时显隐切换

ExoPlayer 与 WebView 同时常驻，只通过显示状态切换。

优点：

- 理论上切换更快。

缺点：

- 资源开销大。
- 在 TV 设备上容易放大内存、合成与解码压力。
- 更容易拖慢焦点、滚动和菜单表现。

## 推荐方案

采用方案 B。

全局架构按“ExoPlayer 默认主路径，WebView 兼容兜底”设计，页面和业务层不直接依赖具体内核。这样既能满足用户在全屏里手动切换的要求，又能把未来完全替代 WebView 的演进空间保留下来。

## 产品范围与页面映射

首期范围与现有 Flutter TV 端实际已交付能力对齐：

| 原生页面 | Flutter 对照 |
|------|------|
| TV 首页 | `lib/tv_app/screens/tv_home_screen.dart` |
| TV 搜索页 | `lib/tv_app/screens/tv_search_screen.dart` |
| TV 详情页 | `lib/tv_app/screens/tv_video_detail_screen.dart` |
| TV 全屏播放器 | `lib/tv_app/screens/tv_fullscreen_player_screen.dart` |
| TV 播放历史页 | `lib/tv_app/screens/tv_history_screen.dart` |
| TV 收藏夹页 | `lib/tv_app/screens/tv_favorites_screen.dart` |
| TV 设置页 | `lib/tv_app/screens/tv_settings_screen.dart` |
| TV 直播页占位 | `lib/tv_app/screens/tv_live_screen.dart` |

原生版必须复刻以下产品语义：

- 顶部双层导航结构：左侧主菜单 + 右上角快捷入口。
- 焦点进入顶部时优先回到当前选中项。
- 分类页、历史页、收藏页使用纵向 Grid。
- 详情页支持换源、换集、相关推荐和内嵌预览播放。
- 全屏播放器保留底部一级/二级菜单结构。
- 返回键先收菜单、再退上一级页面。
- 设置页保持 TV 模式的浏览态与编辑态分离。

## 工程结构

`re-android/` 建议使用以下多模块结构：

```text
re-android/
├── app-tv/
├── core-data/
├── core-network/
├── core-player-api/
├── core-player-exo/
├── core-player-webview/
├── core-design/
├── core-benchmark/
├── feature-tv-home/
├── feature-tv-search/
├── feature-tv-detail/
├── feature-tv-player/
├── feature-tv-history/
├── feature-tv-favorites/
├── feature-tv-settings/
└── feature-tv-live/
```

### 模块职责

- `app-tv`
  - Application
  - MainActivity
  - TV 根导航
  - 顶层主题与窗口配置

- `core-data`
  - 播放记录
  - 收藏/历史
  - TV 设置
  - 继续观看
  - 代理配置
  - 与 Flutter 端对齐的数据模型映射

- `core-network`
  - Retrofit/OkHttp
  - Cookie 与账号态
  - 现有服务端接口封装
  - 搜索、详情、推荐、历史、收藏等 API 请求

- `core-player-api`
  - 统一播放器协议
  - 播放状态快照
  - 播放器切换策略
  - 播放器调度器接口

- `core-player-exo`
  - ExoPlayer 主内核实现
  - HLS/M3U8 播放
  - Seek 调优
  - 缓冲区间与预加载能力上报

- `core-player-webview`
  - WebView 兜底内核实现
  - HLS.js 注入与事件桥接
  - 与原生统一协议对接

- `core-design`
  - TV 设计标尺
  - 间距、字号、卡片尺寸、颜色与焦点态规范

- `core-benchmark`
  - Seek 指标采集
  - 切内核指标采集
  - 异常流标记
  - 后续对比 ExoPlayer / WebView 表现

- `feature-tv-*`
  - 各业务页面、ViewModel 与页面内焦点编排

## 播放器架构

### 统一播放器协议

原生 TV 页面层只依赖统一的 `PlayerEngine` 协议，而不直接依赖 ExoPlayer 或 WebView：

```kotlin
interface PlayerEngine {
    suspend fun load(request: PlaybackRequest)
    suspend fun play()
    suspend fun pause()
    suspend fun seekTo(positionMs: Long)
    suspend fun switchSource(request: PlaybackRequest)
    suspend fun captureSnapshot(): PlaybackSnapshot
    suspend fun restoreSnapshot(snapshot: PlaybackSnapshot)
    suspend fun setPlaybackSpeed(speed: Float)
    suspend fun setResizeMode(mode: TvResizeMode)
    suspend fun release()
    val events: Flow<PlayerEvent>
    val state: StateFlow<PlayerState>
}
```

### 播放状态快照

切内核、切源、切集和重建页面时统一使用 `PlaybackSnapshot`：

```kotlin
data class PlaybackSnapshot(
    val videoId: String,
    val sourceId: String,
    val episodeId: String?,
    val url: String,
    val positionMs: Long,
    val durationMs: Long?,
    val playbackSpeed: Float,
    val resizeMode: TvResizeMode
)
```

该快照用于保证以下路径都能复用同一套恢复语义：

- 全屏内核切换
- 详情页进入全屏
- 全屏切换线路
- 全屏切换集数
- 页面重建后的恢复

### ExoPlayer 主内核

ExoPlayer 是默认主路径，负责：

- 在线 HLS/M3U8 播放
- 主播控链路
- 默认 seek 行为
- 缓冲区间上报
- 倍速、画面比例、PiP 与媒体会话

ExoPlayer 需要优先围绕以下体验调优：

- 左右拖动响应
- 长按连续 seek 跟手
- 前后 seek 稳定性
- 进度条与实际画面同步
- 切集、切源时的恢复速度

### WebView 兜底内核

WebView 只作为兼容兜底，不作为默认主路径。其职责：

- 承接 ExoPlayer 对个别异常在线流的兼容回退
- 提供与现有 Flutter WebView 播放链接近的兼容语义
- 通过 JS bridge 把播放事件、缓冲区间和 seek 状态桥回原生层

### 全屏内核切换

内核切换入口固定在：

`底部菜单 -> 其它 -> 内核切换 -> ExoPlayer / WebView`

交互规则：

- 单击立即执行切换，不弹二级确认页。
- 切换采用软重载语义，允许出现短暂黑屏或 loading。
- 切换成功后停留在当前全屏播放器，不退出详情页、不退回上级页面。
- 尽可能恢复到切换前的当前集、当前线路、当前进度、当前倍速和当前画面比例。

切换流程：

1. 当前内核 `captureSnapshot()`。
2. 全屏 UI 进入切换中状态，禁止重复触发切换。
3. 后台初始化目标内核实例。
4. 调用目标内核 `load()` 并在准备完成后 `restoreSnapshot()`。
5. 目标内核首帧可用后，替换当前渲染层。
6. 释放旧内核资源。
7. 若中途失败，则继续保留旧内核并提示切换失败。

### 不采用双内核常驻

首期不采用 ExoPlayer 与 WebView 同时常驻的做法。原因：

- TV 设备更容易受到多 Surface 合成与双解码资源占用影响。
- 双内核常驻会放大菜单动画、焦点移动和滚动时的卡顿风险。
- 用户要求的是“可以切换”，不是“瞬时无缝显隐切换”。

## 线程模型

为了避免页面卡顿，原生 TV 工程必须显式区分主线程与后台执行域。

### 线程分层

- `Main`
  - Compose UI
  - 焦点变化
  - 动画与菜单显隐
  - 遥控器事件分发

- `Playback`
  - 播放器 `load / seek / switchSource / switchEngine`
  - 播放状态聚合
  - 进度同步
  - 切内核状态机

- `IO`
  - 网络请求
  - 配置读取
  - Cookie/账号态
  - 本地持久化

- `Default`
  - 播放地址解析
  - 结果去重
  - 推荐合并
  - benchmark 计算
  - 规则判定

### 强约束

- 主线程禁止执行播放地址解析、接口聚合、内核切换、预热与状态恢复。
- 遥控器左右键长按只在主线程发出 action，具体 seek 计算与执行由 `Playback` 域完成。
- 内核切换期间的准备、恢复、失败回退全部运行在 `Playback` 域。
- 接口聚合、配置预取、代理地址加载全部走后台协程。

## 数据与接口对齐

原生 TV 工程的数据结构与服务端请求尽量对齐现有 Flutter TV 端：

- 首页数据结构对齐 `TvHomeData`
- 详情页数据结构对齐 `TvVideoDetailData`
- 继续观看、历史、收藏、推荐、搜索词和设置项命名语义保持一致
- 账号配置、服务器模式、图片代理、弹幕地址、M3U8 代理地址保持同一业务含义

原生实现需要重点复刻以下业务链路：

- 首页继续观看
- 搜索页历史、热词、推荐
- 详情页首屏可播源优先、后台补源、相关推荐
- 播放历史与收藏夹独立页
- 设置页账号配置、主题、图片代理、弹幕配置
- M3U8 代理地址的预热与拼接策略

## 焦点与交互约束

原生 TV 版必须把 Flutter TV 端的交互当成行为规格：

- 顶部导航分为主菜单与右上角快捷区。
- 焦点从内容区回到顶部时，优先落到当前选中项。
- 详情页和全屏播放器里的换源、换集、分组、相关推荐保持遥控器优先体验。
- 全屏播放器保留左右键短按/长按 seek 语义。
- 返回键优先处理局部 UI 收口，再处理页面返回。
- 设置页输入框保持浏览态与编辑态分离，避免焦点移入即弹键盘。

## 错误与降级

- ExoPlayer 加载失败时，允许用户在“其它 -> 内核切换”里显式切到 WebView。
- WebView 切换失败时，保留原有 ExoPlayer 播放状态，不直接把用户踢出当前播放页。
- 首页、详情页、搜索页局部区块加载失败时，只影响当前区块，不拖垮整页。
- 代理地址缺失、账号态异常或推荐失败时，应保留基础页面可用性。

## benchmark 与验收指标

本次重建不以“能播”为唯一标准，重点验收以下体验：

- 前向 seek 响应速度
- 后向 seek 响应速度
- 左右键长按连续 seek 是否稳定
- 进度条是否跟手
- 切源、切集后恢复速度
- 内核切换恢复到原进度附近的稳定性
- 菜单显隐、焦点移动、列表滚动是否出现明显卡顿

建议首期在 `core-benchmark` 中记录：

- `seek request -> first frame` 耗时
- `switch engine -> ready` 耗时
- `switch source -> ready` 耗时
- `switch episode -> ready` 耗时
- 播放错误类型与当前内核类型

## 实施阶段建议

### 阶段 1：基础壳与数据层

- 重建 `re-android/` 工程骨架
- 搭好 TV 根壳、主题、导航和核心数据层
- 跑通首页、搜索、历史、收藏、设置基础页

### 阶段 2：详情页与 ExoPlayer 主路径

- 跑通详情页、内嵌预览播放与全屏播放器
- 完成 ExoPlayer 主内核
- 打通播放记录、继续观看、切源、切集

### 阶段 3：WebView 兜底与内核切换

- 接入 WebView 兜底内核
- 打通全屏内核切换
- 增加切换失败回退与指标采集

### 阶段 4：体验对齐与性能收敛

- 校准焦点与返回链
- 对齐 TV 菜单、seek 手感与设置页操作语义
- 跑 benchmark，压缩 WebView 使用范围

## 测试策略

- `core-player-api`、`core-player-exo`、`core-player-webview` 编写单元测试或集成测试，覆盖：
  - snapshot 捕获与恢复
  - 切内核状态机
  - 切换失败回退
- `feature-tv-player` 编写 UI/集成测试，覆盖：
  - 全屏菜单打开关闭
  - “其它 -> 内核切换”触发
  - 软重载切换后保留当前集与当前进度附近
- 对首页、搜索、详情、设置等重点页面编写 Compose UI 测试，覆盖焦点进入、返回链和关键按钮存在。
- 在真机或模拟器上执行针对性 benchmark，对比 ExoPlayer 与 WebView 的 seek 表现。

