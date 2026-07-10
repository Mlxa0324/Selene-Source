# 技术设计：详情页与全屏共享播放器会话

## 1. 设计目标

本轮不是把详情页和全屏页合成一个页面，而是把“播放器生命周期”和“播放上下文生命周期”从页面里提到导航图顶层，让两页继续保留各自壳层、焦点和 UI 责任，但共享同一个播放器会话。

核心目标只有四个：

1. 详情页预览进入全屏时尽量无感切换。
2. 详情页和全屏页继续分文件、分职责维护。
3. `exo` 和 `webview` 两种内核都遵守同一套共享宿主契约。
4. 播放器资源由宿主统一释放，不再散落在页面内部。

## 2. 当前问题拆解

### 2.1 路由层重复创建播放器

当前 `TvNavGraph` 在两个页面内分别 `remember` 出各自的播放器实例：

- 详情页：
  - `detailPlayerSession`
  - `detailExoEngine`
- 全屏页：
  - `webViewPlayerSession`
  - `exoPlayerEngine`

结果是同一条播放流在“预览 -> 全屏”切换时，天然就会像开了两个播放器。

### 2.2 播放上下文重复存放

当前播放请求、线路和剧集列表先放进 `TvPlaybackRequestStore`，播放器页再从 store 里读；同时详情页和全屏页各自的 `ViewModel` 也各自持有一套播放态。这导致状态来源分散，后续很难保证真正的单一事实源。

### 2.3 WebView 无法自然无感切换

`WebViewPlayerSurface` 现在每次都会新建一个 `WebView`，即便底层 `PlayerEngine` 共用，实际播放页也还是会被重新创建，切全屏时仍然会有明显的重新加载感。

### 2.4 缺少统一释放边界

当前主链路里没有明确的“播放流结束”宿主。页面离开后何时释放、切到弹幕匹配页时是否继续保留、返回详情时是否还应复用，都没有集中管理点。

## 3. 目标方案

### 3.1 新增 `TvSharedPlayerHost`

在 `app-tv` 模块新增一个导航级共享播放器宿主，建议放在 `re-android/app-tv/.../player/` 或 `navigation/` 下，职责只做三件事：

- 持有当前播放流唯一的共享播放器会话
- 持有当前播放流唯一的播放上下文
- 按导航流边界统一释放资源

宿主建议持有以下状态：

```kotlin
data class TvSharedPlaybackContext(
    val request: PlaybackRequest,
    val sources: List<PlaybackSource>,
    val episodes: List<PlaybackEpisode>,
)

class TvSharedPlayerHost {
    val currentKernel: String?
    val currentContext: TvSharedPlaybackContext?
    val currentSession: TvSharedPlayerSession?

    fun openOrReuseSession(...)
    fun updatePlaybackContext(...)
    fun clearPlaybackFlow()
    suspend fun release()
}
```

### 3.2 共享会话模型

共享宿主内部维护一份统一的 `TvSharedPlayerSession`，按内核类型复用底层对象：

```kotlin
data class TvSharedPlayerSession(
    val kernel: String,
    val playerEngine: PlayerEngine,
    val exoEngine: ExoPlayerEngine? = null,
    val webViewSession: WebViewPlayerSession? = null,
)
```

说明：

- `exo` 内核复用同一 `ExoPlayerEngine`
- `webview` 内核复用同一 `WebViewPlayerSession`
- 路由层不再自己 `remember` 第二套会话对象

## 4. WebView 共享方案

### 4.1 为什么只共享 `engine` 不够

`WebViewPlayerEngine` 只是状态和命令的桥，真正播放 HLS 的是 `WebView` 里的播放页。只复用 `engine`、但重新创建 `WebView`，实际仍会重新打开播放器页面，因此不能满足“切全屏足够顺滑”的目标。

### 4.2 `WebViewPlayerSession` 升级为“会话 + View 宿主”

需要把 `WebViewPlayerSession` 从“命令总线 + 引擎”升级为“命令总线 + 引擎 + 可复用 WebView 宿主”：

- 会话内部缓存同一个 `WebView` 实例
- 详情页和全屏页的 `WebViewPlayerSurface` 都从 session 里获取这个实例
- 同一播放地址不重新 `loadUrl`
- 切换页面时仅做 View 重新挂载，不重新创建播放页

建议新增能力：

```kotlin
class WebViewPlayerSession {
    val commandBus: WebViewPlayerCommandBus
    val engine: WebViewPlayerEngine

    fun obtainWebView(context: Context): WebView
    fun bindPlaybackCallback(callback: ((WebViewPlaybackEvent) -> Unit)?)
    fun detachFromParent()
    fun release()
}
```

### 4.3 `WebViewPlayerSurface` 改造方向

`WebViewPlayerSurface` 不再自己 new `WebView`，改为消费共享 session：

- 由 session 负责创建和配置唯一 `WebView`
- Surface 只负责把已有 View 接入 Compose
- `update` 阶段只在媒体 URL 真变化时触发加载

这样详情页切全屏时，同一 `WebView` 就能在两个壳层之间移动，最大限度减少重载感。

## 5. Exo 共享方案

Exo 这条链路相对简单：

- 宿主持有唯一 `ExoPlayerEngine`
- 详情页和全屏页各自继续用自己的 `ExoPlayerSurface`
- `ExoPlayerSurface` 绑定同一个 `ExoPlayer`

因为当前 `ExoPlayerSurface` 已经在 `DisposableEffect` 中做了旧 `PlayerView` 解绑定，所以只要底层 `ExoPlayerEngine` 不重建，就可以把重建成本压到最小。

## 6. 播放上下文收口

### 6.1 用共享宿主替代 `TvPlaybackRequestStore`

当前 `TvPlaybackRequestStore` 只是把完整请求藏到内存里再给全屏页取回，本质上也是一个临时上下文容器。共享宿主出现后，这部分职责应直接收口到宿主本身：

- `currentContext.request`
- `currentContext.sources`
- `currentContext.episodes`

这样播放器页只读取宿主上下文，不再需要另一份 in-memory store。

### 6.2 路由建议

建议把全屏路由简化成不带 `requestId` 的播放页：

- 详情页点击全屏前，先把当前播放上下文写入共享宿主
- 再导航到全屏页
- 全屏页从共享宿主读取当前播放上下文

这不会带来新的恢复退化，因为现在的 `TvPlaybackRequestStore` 也是纯内存态，进程重建后同样无法恢复。

## 7. ViewModel 调整

### 7.1 `TvDetailViewModel`

详情页需要保留选源、选集、续播和预览 UI 责任，但在调用 `engine.load(request)` 前要先判断：

- 当前共享引擎是否已经在播放同一媒体身份
- 如果是，则只接管状态收集，不再重复加载

这里的“同一媒体身份”建议至少包含：

- `videoId`
- `sourceId`
- `episodeId`
- `url`

`startPositionMs` 不应作为“是否重复加载”的唯一判断条件，否则预览中进度变化后切全屏仍会被误判成新请求。

### 7.2 `TvPlayerViewModel`

全屏页也需要相同的幂等策略：

- 如果共享引擎当前就是同一媒体，不再调用 `loadInitialRequest -> engine.load`
- 直接同步当前引擎状态并开始观察

这样从详情页进入全屏时，全屏页只是“接管同一播放器状态”，不是重新起播。

## 8. 释放策略

共享宿主的释放边界应该由导航流而不是页面自身决定。

建议保留播放会话的路由集合：

- `detail`
- `player`
- `danmakuMatch`

规则：

- 在这些路由内部相互跳转时，不释放共享会话
- 当前导航目标离开这个集合后，统一 `release` 并清空上下文

这样可以保证：

- 详情 -> 全屏：不断流
- 全屏 -> 弹幕匹配：不断流
- 弹幕匹配 -> 全屏：不断流
- 退出整个播放流：统一释放

## 9. 测试设计

至少补四类测试：

1. 共享宿主测试
   - 创建会话
   - 复用同内核会话
   - 切换内核时重建并释放旧会话
   - 清空播放流时释放资源
2. 导航契约测试
   - 详情页和全屏页都从同一共享宿主读取会话
   - 全屏路由不再创建第二套会话
   - 离开播放流时会触发统一释放
3. ViewModel 幂等加载测试
   - 同媒体身份时 `loadInitialRequest` 不重复调用 `engine.load`
   - 详情页预览重新接管共享会话时不重复加载
4. WebView 复用契约测试
   - `WebViewPlayerSession` 能复用同一 `WebView`
   - 同 URL 不重复加载页面
   - 重新挂载时仍能继续回灌播放事件

## 10. 风险与回滚

### 风险

- `WebView` 复用涉及平台 View 重新挂载，若处理不当容易出现父容器冲突或焦点异常。
- 共享宿主一旦状态边界写错，可能把旧视频状态带到新详情页。
- 路由若去掉 `requestId`，相关契约测试和空上下文保护要一起补齐。

### 回滚点

- 若 WebView 真机复用不稳定，可先保留共享上下文和 Exo 共享，再把 WebView 复用拆成子步骤继续推进。
- 若路由去参带来额外风险，可先保留 `player/{requestId}`，但共享宿主仍作为播放器会话唯一来源。

## 11. 推荐落地顺序

推荐按以下顺序实现，保证每一步都能单独验证：

1. 先引入共享宿主和共享播放上下文
2. 再把 Exo 链路切到共享会话
3. 再升级 WebView session 为可复用 View 宿主
4. 最后补导航释放边界和回归测试
