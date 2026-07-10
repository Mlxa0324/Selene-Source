# 实施计划

## 1. 实施目标

按“共享播放器宿主 + 页面壳层分离”的方向实现详情页与全屏页的无感切换，不在本阶段改 UI 外观，只收敛播放器会话、播放上下文和资源释放边界。

## 2. 实施步骤

### 2.1 新增共享播放器宿主

- 在 `re-android/app-tv` 新增 `TvSharedPlayerHost`
- 宿主管理：
  - 当前内核
  - 当前共享播放器会话
  - 当前播放上下文（request / sources / episodes）
  - 统一 `release` 入口
- 先补宿主单测，再接业务接线

### 2.2 改造 WebView 会话为可复用 View 宿主

- 扩展 `WebViewPlayerSession`
  - 承载可复用 `WebView`
  - 暴露回调绑定与父容器分离能力
  - 提供统一 `release`
- 改造 `WebViewPlayerSurface`
  - 从 session 获取已有 `WebView`
  - 同 URL 不重复 `loadUrl`
  - 保持现有播放事件回灌契约

### 2.3 改造导航图接线

- `TvNavGraph` 顶层 `remember` 共享播放器宿主
- 详情页和全屏页都从宿主读取同一播放器会话
- 用宿主替代 `TvPlaybackRequestStore` 作为播放上下文来源
- 根据最终方案决定：
  - 若去掉 `requestId`，同步调整 `TvDestination.Player`
  - 若暂时保留 `requestId`，也要保证会话唯一来源仍然是宿主

### 2.4 给详情页和全屏页补幂等加载

- `TvDetailViewModel.startPreviewPlayback()`
  - 同媒体身份时不重复 `engine.load`
- `TvPlayerViewModel.loadInitialRequest()`
  - 同媒体身份时不重复 `engine.load`
- 把“同媒体身份”的判断抽成共享 helper，避免两边各写一套

### 2.5 接入统一释放边界

- 在导航图按播放流路由集合控制宿主释放
- 验证以下跳转不释放：
  - 详情 -> 全屏
  - 全屏 -> 弹幕匹配
  - 弹幕匹配 -> 全屏
  - 全屏 -> 返回详情
- 验证离开播放流后会释放：
  - 详情 -> 首页/列表/设置
  - 全屏 -> 退出到非播放流页面

### 2.6 补测试

- `app-tv`
  - 共享宿主测试
  - 导航契约测试
- `feature-tv-detail`
  - 预览幂等加载测试
- `feature-tv-player`
  - 全屏幂等加载测试
- `core-player-webview`
  - WebView 复用契约测试

## 3. 验证命令

- `git diff --check -- re-android/app-tv re-android/feature-tv-detail re-android/feature-tv-player re-android/core-player-webview re-android/core-player-exo`
- `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest`
- `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`
- `./re-android/gradlew -p re-android :feature-tv-player:testDebugUnitTest`
- `./re-android/gradlew -p re-android :core-player-webview:testDebugUnitTest`
- `./re-android/gradlew -p re-android :core-player-exo:testDebugUnitTest`

## 4. 手动验证要点

- 进入详情页后预览正常起播
- 按全屏播放进入播放器时，画面切换无明显重缓冲感
- 退出全屏回详情时，当前播放状态仍能被详情页接住
- `exo` 与 `webview` 两种内核都验证一次
- 弹幕匹配页来回跳转不打断当前播放流

## 5. 风险点

- `WebView` 复用是本轮最敏感改动，必须优先用单测和真机验证兜住
- 如果路由去参导致契约波动过大，可以保留 `requestId` 作为过渡，但不能退回“双实例播放器”结构
- 如果共享 helper 写在错误层级，后续容易再次出现详情页和全屏页各修一套的分叉问题

## 6. 进入实现前检查

- [x] 用户已确认“页面分开，不合并文件”
- [x] 用户已确认“目标是详情页到全屏尽量无感切换”
- [x] 已完成 PRD / 设计 / 实施计划
- [ ] 用户确认按当前方案进入实现
