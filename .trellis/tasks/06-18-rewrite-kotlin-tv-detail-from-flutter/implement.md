# 重做 Kotlin TV 详情页执行计划

## Preconditions

- 用户确认本次范围后再执行 `task.py start`。
- 实现前读取：
  - `.trellis/spec/frontend/tv-mode.md`
  - `.trellis/spec/frontend/component-guidelines.md`
  - `.trellis/spec/frontend/state-management.md`
  - `.trellis/spec/backend/error-handling.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`

## Implementation Checklist

### 1. 建立详情入口和状态模型

- [ ] 新增或重写 `TvDetailEntry`，承载 route 解析后的 source、id、title、searchTitle、year、posterUrl、stype。
- [ ] 重写 `TvDetailUiState`，显式建模加载阶段、补源阶段、当前源/集、续播目标、播放器 loading、退出状态和空态。
- [ ] 新增状态机内部事件/私有 helper，避免 `load()` 继续变成一条长串顺序流程。
- [ ] 补单测：初始状态、首个可播源、无源完成空态、退出后忽略回包。

### 2. 重做加载状态机

- [ ] `load(entry)` 并行启动精确源、标题补源、续播记录、收藏/偏好等任务。
- [ ] 精确源失败只标记完成，不进入错误终态。
- [ ] 标题补源支持增量回调；首个可播源立即选择并生成播放请求。
- [ ] 补源结束后无源时设置完成空态。
- [ ] 去重合并同 `source + id`，保留更完整剧集。
- [ ] 补单测：精确失败补源成功、补源失败保留精确源、重复源覆盖。

### 3. 重做续播和播放请求

- [ ] 读取最新播放记录并锁定续播目标。
- [ ] 有续播目标时等待目标源；搜索结束未命中再回退。
- [ ] `PlaybackRequest.startPositionMs` 使用最新续播秒数。
- [ ] 播放器真实进度未到续播点时限次补偿 seek。
- [ ] 切源保留当前集数/秒数并生成新请求。
- [ ] 补单测：续播目标命中、未命中回退、无续播立即起播、切源保留进度。

### 4. 重做播放器预览链路

- [ ] 无播放 URL 时不渲染重型 WebView，只显示封面/轻量占位。
- [ ] 有播放请求后调用 `PlayerEngine.load`，维护 preview loading 锚点。
- [ ] loading 只在真实进度越过锚点后收起。
- [ ] 暴露真实网速和缓冲段给详情进度条。
- [ ] 补单测：控制器晚挂 loading、ready/play 不单独清 loading、进度前进后清 loading。

### 5. 拆分并重写 UI 组件

- [ ] `TvDetailRoute` 保留入口，拆出顶部栏、Hero、预览播放器、信息面板。
- [ ] 重写线路列表：单行、集数倒序、当前源首次 pinned、首尾边界反馈。
- [ ] 重写选集和分组：20 集一组、分组标签在下、确认才切换分组、跨组左右。
- [ ] 重写推荐区和底部操作：无推荐不渲染尾部。
- [ ] 统一空态、loading 和错误文案。
- [ ] 补 Compose/UI 单测或源码契约测试覆盖关键空态和结构。

### 6. 建立焦点图

- [ ] 评估 `TvFocusableCard` 是否需要扩展方向键目标。
- [ ] 实现顶部搜索、播放器、全屏/收藏、线路、选集、分组、推荐之间显式焦点跳转。
- [ ] 横向列表实现安全留白、可见性滚动和边界抖动。
- [ ] 纵向滚动实现获焦自动滚动到稳定位置。
- [ ] 补测试：播放器下到线路、按钮下到当前源、线路下到最近选集、选集跨组左右不丢焦。

### 7. 接入播放记录、收藏、返回

- [ ] 收藏读写接入真实仓库，失败回滚或显式错误。
- [ ] 播放进度按节流保存。
- [ ] 换源保存新记录成功后再清理旧源。
- [ ] 返回键先退出 UI，再后台保存，退出后回包早停。
- [ ] 补测试：返回立即退出、保存不阻塞、退出后异步事件不改状态。

### 8. 验证和收尾

- [ ] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`
- [ ] `./re-android/gradlew -p re-android :core-data:testDebugUnitTest`
- [ ] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest`
- [ ] `git diff --check -- <changed files>`
- [ ] 扫描用户可见 placeholder：
  `rg "后续接入|临时占位|占位|正在开发|后续|placeholder|TODO|骨架" re-android --glob '!**/build/**'`
- [ ] 更新任务记录和必要 spec。

## Risk Points

- `TvAppContainer.kt` 当前已有大量其它未提交改动，编辑前必须只碰详情相关区域。
- `TvDetailRoute.kt` 当前文件大，重写时优先拆小组件，避免继续扩大单文件复杂度。
- 播放器预览和全屏复用依赖当前 `WebViewPlayerSession` 能力，若无法完全复用，先用 `PlaybackSnapshot` 保证切全屏不丢源/集/进度。
- 焦点图是最高回归风险，必须用小步测试锁定。

## Suggested Task Split

如果用户接受分阶段，建议拆三个可独立验收的子任务：

1. 详情状态机和数据链路重做。
2. 页面 UI 和焦点图重做。
3. 预览/全屏共享、播放记录和退出收尾完善。

如果用户要求一口气完成，本任务直接承载全部三段，但每段仍按上面顺序提交验证。

## 2026-06-24 修复记录：详情页 WebView 黑屏不播放

### 问题现象

- Kotlin TV 详情页数据、线路和集数已加载完成。
- 预览播放器区域已经渲染为黑色 WebView 容器，但视频没有实际播放。

### 根因

- Android 内置播放页加载的是 `file:///android_asset/player/hls_player.html`。
- 播放页需要真实 `hls.min.js` 才能在 WebView 中播放远端 m3u8。
- 之前 asset 内的 `hls.min.js` 是占位内容，导致页面回退到原生 `<video src=m3u8>`，部分 Android WebView 对 HLS 只显示黑屏。
- 即使换成真实 hls.js 后，首次 `play()` 仍可能早于 manifest 解析或 video 可播放节点，被 WebView 吞掉。

### 修复内容

- 用真实 hls.js 替换 `re-android/core-player-webview/src/main/assets/player/hls.min.js`。
- WebView 打开 asset 页面访问远端 m3u8/分片所需的 file URL 跨域权限和 mixed content。
- `WebViewPlayerEngine.load()` 首次加载直接进入播放态并向页面下发 `Play` 命令。
- `hls_player.html` 在 `MANIFEST_PARSED`、`loadedmetadata`、`canplay` 后重试起播。
- `hls_player.html` 增加 HLS fatal 错误恢复：网络错误 `startLoad()`，媒体错误 `recoverMediaError()`。
- `WebViewPlayerSurface` 增加 WebView console、资源错误和 HTTP 错误 Logcat 输出，便于后续排查具体播放源问题。
- 补充 WebView 播放页、真实 hls.js、起播时机和日志契约测试。

### 验证结果

- `./re-android/gradlew -p re-android :core-player-webview:testDebugUnitTest`
- `./re-android/gradlew -p re-android :core-player-webview:testDebugUnitTest --tests org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSurfaceContractTest`
- `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`
- `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.navigation.TvNavGraphPlayerContractTest`
- `git diff --check -- re-android/core-player-webview/src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerSurface.kt re-android/core-player-webview/src/main/assets/player/hls_player.html re-android/core-player-webview/src/main/assets/player/hls.min.js re-android/core-player-webview/src/test/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerSurfaceContractTest.kt`

### 复测建议

- 需要重新构建并安装 debug 包，因为真实 hls.js 是 Android asset，旧安装包不会自动更新。
- 如果复测仍黑屏，优先看 Logcat 的 `SeleneWebViewPlayer`，确认是 manifest/分片 HTTP 错误、CORS、编码不支持，还是播放源需要特殊 header。
