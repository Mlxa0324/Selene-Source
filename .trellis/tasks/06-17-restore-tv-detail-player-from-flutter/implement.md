# 执行计划：详情页 & 播放页 1:1 还原

## Step 1: PlaybackRequest 扩展 [core-player-api]

### 1.1 新增字段
**文件:** `core-player-api/.../PlaybackRequest.kt` (修改)

```kotlin
val availableSources: List<TvVideoSource>? = null,
val allEpisodes: List<TvEpisode>? = null,
```

**验证:** `./gradlew :core-player-api:compileDebugKotlin :core-player-api:test`

---

## Step 2: 详情页 ViewModel 扩展 [feature-tv-detail]

### 2.1 扩展 TvDetailUiState
**文件:** `feature-tv-detail/.../TvDetailViewModel.kt` (修改)

新增字段: `isFavorite`, `showResumePrompt`, `resumeEpisodeId`, `resumePositionMs`, `episodeGroups`, `selectedEpisodeGroup`, `fullscreenOverlayVisible`

### 2.2 新增 ViewModel 方法
- `toggleFavorite()` — 切换收藏状态
- `loadFavoriteState(videoId)` — 从 UserDataService 加载
- `checkResumeRecord(videoId)` — 从 PlaybackRepository 加载
- `dismissResumePrompt()` — 关闭续播提示
- `selectEpisodeGroup(index)` — 切换选集分组
- `enterFullscreen()` / `exitFullscreen()` — 全屏切换

### 2.3 选集分组工具
```kotlin
private fun List<TvEpisode>.toGroups(size: Int = 50): List<List<TvEpisode>>
```

**验证:** `./gradlew :feature-tv-detail:compileDebugKotlin :feature-tv-detail:test`

---

## Step 3: 详情页预览播放器 [feature-tv-detail]

### 3.1 新建 TvDetailVideoPreview
**文件:** `feature-tv-detail/.../TvDetailVideoPreview.kt` (新增)

16:9 播放器 composable，复用 `WebViewPlayerSurface`：
- 接收 `WebViewPlayerSession`
- 自动播放
- 底部进度条覆盖
- "全屏" 和 "收藏" 操作按钮

### 3.2 新建 TvEpisodeGroupSelector
**文件:** `feature-tv-detail/.../TvEpisodeGroupSelector.kt` (新增)

选集分组选择器，水平 chip 行。

### 3.3 重写 TvDetailRoute
**文件:** `feature-tv-detail/.../TvDetailRoute.kt` (修改)

替换静态 `TvPlaybackPreview` 为 `TvDetailVideoPreview`。添加：
- 骨架屏加载态（替代 `TvStatePanel(Loading)`）
- 续播提示弹窗
- 全屏覆盖层
- 选集分组

### 3.4 适配 TvAppContainer
**文件:** `app-tv/.../TvAppContainer.kt` (修改)

`createDetailViewModel()` 注入新依赖：
- `loadFavoriteState`
- `saveFavoriteState`
- `loadResumeRecord`
- `createWebViewPlayerSession()` 传递给详情页

### 3.5 适配 TvNavGraph
**文件:** `app-tv/.../navigation/TvNavGraph.kt` (修改)

详情页路由接入新的 `WebViewPlayerSession` 创建。

**验证:** `./gradlew :feature-tv-detail:compileDebugKotlin :app-tv:compileDebugKotlin`

---

## Step 4: 播放页线路 & 选集接入 [feature-tv-player]

### 4.1 扩展 TvPlayerUiState
**文件:** `feature-tv-player/.../TvPlayerViewModel.kt` (修改)

新增: `availableSources`, `allEpisodes`, `episodeGroups`, `selectedEpisodeGroup`

从 `PlaybackRequest` 初始化。

### 4.2 重写 TvPlayerSourceMenu
**文件:** `feature-tv-player/.../TvPlayerRoute.kt` (修改)

替换占位 chip 为真实线路列表，点击切换 source 并重新加载。

### 4.3 重写 TvPlayerPlaylistMenu
**文件:** `feature-tv-player/.../TvPlayerRoute.kt` (修改)

替换占位 chip 为分组选集列表，支持 episode 选择和 group 切换。

**验证:** `./gradlew :feature-tv-player:compileDebugKotlin :feature-tv-player:test`

---

## Step 5: 集成验证 & 回归测试

```bash
./gradlew :core-player-api:test :feature-tv-detail:test :feature-tv-player:test :app-tv:test
```

---

## 执行顺序

```
Step 1                  (PlaybackRequest 扩展)
  ↓
Step 2                  (ViewModel 扩展 + 选集分组)
  ↓
Step 3.1 → 3.2 → 3.3   (详情页 UI 重建)
  ↓
Step 3.4 → 3.5          (依赖注入 & 路由接线)
  ↓
Step 4.1 → 4.2 → 4.3   (播放页菜单接入)
  ↓
Step 5                  (回归测试)
```

## 回滚点

- Step 1 完成后 commit
- Step 3.3 完成后 commit（详情页核心改动）
- Step 5 全部通过后 final commit
