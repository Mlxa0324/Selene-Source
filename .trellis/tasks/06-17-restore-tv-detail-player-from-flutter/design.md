# 技术设计：详情页与播放页对齐 Flutter TV

## 1. 详情页改造

### 1.1 预览区改为视频播放器

当前 `TvPlaybackPreview` 是一个静态海报卡片。改为嵌入一个轻量播放器：

```
┌─────────────────────────────────────────┐
│ TvDetailRoute                            │
│  ┌─────────────────────────────────────┐ │
│  │ TvDetailVideoPreview                │ │  ← 16:9 播放器
│  │  ┌─────────────────────────────┐    │ │
│  │  │ WebViewPlayerSurface         │    │ │  ← 复用现有 WebView 播放
│  │  │ (autoPlay=true, muted?)      │    │ │
│  │  └─────────────────────────────┘    │ │
│  │  [进度条]                            │ │
│  │  [全屏] [收藏]                       │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ 元信息: 标题 / 年份·来源 / 简介     │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ 线路: chip chip chip ...            │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ 选集: [group selector]              │ │
│  │       chip chip chip ...            │ │
│  └─────────────────────────────────────┘ │
│  ┌─────────────────────────────────────┐ │
│  │ 相关推荐: TvPosterRail              │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**关键决策：**
- 复用 `WebViewPlayerSession` + `WebViewPlayerSurface` 作为预览播放器
- 自动播放（`autoPlay=true`），不静音（或可选静音，对齐 Flutter）
- 全屏按钮点击后，将当前的 `WebViewPlayerSession` 传给全屏覆盖层，避免重建播放器
- 预览播放器和全屏播放器共享同一个 command bus

### 1.2 TvDetailViewModel 扩展

```kotlin
data class TvDetailUiState(
    // 现有字段...
    val isFavorite: Boolean = false,
    val resumeEpisodeId: String? = null,
    val resumePositionMs: Long = 0L,
    val showResumePrompt: Boolean = false,
    val episodeGroups: List<List<TvEpisode>> = emptyList(),
    val selectedEpisodeGroup: Int = 0,
    val fullscreenOverlayVisible: Boolean = false,
)
```

新增依赖：
- `loadFavoriteState: suspend (videoId) -> Boolean`
- `saveFavoriteState: suspend (videoId, isFavorite) -> Unit`
- `loadResumeRecord: suspend (videoId) -> Pair<String, Long>?` — episodeId + position

### 1.3 选集分组

Flutter TV 每 50 集一组。实现：
```kotlin
fun List<TvEpisode>.toGroups(groupSize: Int = 50): List<List<TvEpisode>>
```

UI 展示：
- Primary row: 当前 group 的 episode chips
- Secondary row: group 选择器（"1-50", "51-100", ...）

## 2. 播放页改造

### 2.1 线路菜单

`TvPlayerSourceMenu` 当前是占位 chip。改为展示真实线路列表：

```kotlin
@Composable
fun TvPlayerSourceMenu(
    sources: List<TvVideoSource>,
    currentSourceId: String,
    onSourceSelected: (String) -> Unit,
)
```

数据来：`TvPlayerUiState` 新增 `availableSources: List<TvVideoSource>`。从 `TvDetailViewModel` 的 `state.detail?.sources` 传入播放器的 `PlaybackRequest` 扩展字段。

### 2.2 选集菜单

`TvPlayerPlaylistMenu` 当前也是占位。改为分组选集列表：

```kotlin
@Composable
fun TvPlayerPlaylistMenu(
    episodes: List<TvEpisode>,
    currentEpisodeId: String,
    onEpisodeSelected: (String) -> Unit,
)
```

### 2.3 PlaybackRequest 扩展

```kotlin
data class PlaybackRequest(
    // 现有字段...
    val availableSources: List<TvVideoSource>? = null,
    val allEpisodes: List<TvEpisode>? = null,
)
```

携带详情页已加载的 sources 和 episodes，播放页无需重复请求。

## 3. 全屏覆盖层

新增 `TvFullscreenPlayerOverlay` composable：
- 接收 `WebViewPlayerSession`（从详情页传入）
- `Positioned.fill` 覆盖整个详情页
- D-pad 向下键打开播放器菜单
- 返回键退出全屏，回到详情页（不销毁播放器）

```
详情页 → 点击"全屏" → 全屏覆盖层显示
                      ↑ 同一个 WebViewPlayerSession
                      ↑ 同一个播放状态（进度、倍速等保持）
详情页 ← 按返回 ← 全屏覆盖层隐藏
```

## 4. 边界与兼容

- **不破坏现有数据流**：新增字段都是可选的，默认值保持向后兼容
- **WebView 播放器**：预览和全屏共用，避免同时创建多个 WebView
- **焦点管理**：全屏覆盖层有自己的焦点链，退出时恢复详情页焦点
- **回滚点**：每个 composable 独立，可单独回滚不互相影响
