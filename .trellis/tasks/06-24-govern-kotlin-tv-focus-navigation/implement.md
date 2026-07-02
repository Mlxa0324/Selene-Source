# Kotlin TV 全局遥控焦点治理执行计划

## Preconditions

- 当前任务进入 `in_progress` 后再改代码。
- 实施前读取：
  - `.trellis/spec/frontend/tv-mode.md`
  - `.trellis/spec/frontend/component-guidelines.md`
  - `.trellis/spec/frontend/state-management.md`
  - `.trellis/spec/guides/code-reuse-thinking-guide.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`

## Phase 1: 焦点审计和红灯测试

- [x] 梳理 `TvApp.kt`、`TvNavGraph.kt`、`core-design` 和各 `feature-tv-*` 的焦点入口。
- [x] 生成焦点地图记录：页面、入口目标、上下左右路径、边界行为。
- [x] 为已知问题补红灯测试：
  - [x] 顶部导航下探列表最近获焦项。
  - [x] 网格页面顶部下探最近获焦项。
  - [x] 详情页空区域 fallback。
  - [x] 搜索页键盘和右侧面板往返。
- [x] 跑红灯测试，确认失败原因和焦点缺口一致。

## Phase 2: Shared Design 和 App Shell

- [x] 统一 `TvPosterRail` / `TvPosterGrid` 内容入口回流策略。
- [x] 检查 `TvFocusableCard` 请求器绑定顺序，确保真实 focusable 前绑定。
- [x] 检查 `TvStatePanel` 空态/错误态入口焦点。
- [x] 检查 `TvSkeleton` 加载态入口焦点。
- [x] 检查 `TvApp.kt` 顶部导航下探不被 preview key 消费。
- [x] 验证：
  - [x] `./re-android/gradlew -p re-android :core-design:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.TvAppFocusContractTest`

## Phase 3: 首页和列表类页面

- [x] 修复首页和视频库筛选/分区/网格焦点路径。
- [x] 修复历史页加载态、列表态和空态入口。
- [x] 修复收藏页加载态、列表态和空态入口。
- [x] 修复直播页频道空态和列表态入口。
- [x] 验证：
  - [x] `./re-android/gradlew -p re-android :feature-tv-home:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :feature-tv-history:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :feature-tv-favorites:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :feature-tv-live:testDebugUnitTest`

## Phase 4: 详情页

- [x] 扩展 `TvDetailFocusGraphTest` 覆盖播放器、操作按钮、线路、选集、分组、推荐、底部操作。
- [x] 修复空区域 fallback 和跨区滚动后 request focus。
- [x] 确保线路和选集横向边界不逃逸。
- [x] 验证：
  - [x] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest`

## Phase 5: 搜索、设置和播放页

- [x] 抽出或补齐搜索页键盘/右侧面板焦点图测试。
- [x] 修复搜索页键盘到结果区、结果区回键盘、操作按钮路径。
- [x] 修复设置页表单项入口和上下移动。
- [x] 修复全屏播放器菜单态与非菜单态方向键职责。
- [x] 验证：
  - [x] `./re-android/gradlew -p re-android :feature-tv-search:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :feature-tv-settings:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :feature-tv-player:testDebugUnitTest`

## Phase 6: 集成验证和记录

- [x] 跑关键 app shell/navigation 测试：
  - [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest`
- [x] 跑 diff 检查：
  - [x] `git diff --check -- <changed files>`
- [x] 更新任务记录和必要 spec。
- [x] 给用户列出遥控器手测路径：
  - [x] 首页 tab -> rail -> tab -> rail。
  - [x] 详情播放器 -> 线路 -> 选集 -> 推荐 -> 顶部。
  - [x] 搜索键盘 -> 结果区 -> 键盘。
  - [x] 设置表单上下移动。
  - [x] 全屏播放器菜单开关与上下左右。

## Regression: 顶部主导航右键卡住

- [x] 复现/定位：焦点从「首页」右移到「电影」时，被外部进入重定向逻辑拉回当前 tab。
- [x] 补合同测试：`TvAppFocusContractTest.navigation_pill_handles_left_right_inside_current_group`。
- [x] 修复：`TvNavigationPill` 显式处理左右方向键，`TvDestinationGroup` 用 `pendingInternalFocusRoute` 标记组内移动。
- [x] 验证：
  - [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.TvAppFocusContractTest`

## Regression: 1080P 视口压缩成 7 列

- [x] 复现/定位：当前 TV 视觉 token 以固定 dp 直接渲染，`TvDesignMetrics` 虽然已有 scale 计算，但首页和根壳没有真正使用，导致 1080P 下不是按 2K 设计稿等比缩放，而是继续硬塞 7 列。
- [x] 修复：新增 `TvDesignCanvas`，在 `TvApp` 根节点固定使用 `TvDesignPreset.QHD_1440`，让 1080P 视口按 0.75 比例整体缩放，不再切换到另一套更紧凑的布局。
- [x] 补验证：
  - [x] `TvDesignMetricsTest.qhdPreset_scales1080ViewportWithoutSwitchingLayoutPreset`
  - [x] `TvAppFocusContractTest.app_shell_scopes_content_focus_requester_to_current_route` 同时锁定 `TvDesignCanvas(QHD_1440)` 已接入根壳
- [x] 运行验证：
  - [x] `./re-android/gradlew -p re-android :core-design:testDebugUnitTest`
  - [x] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.TvAppFocusContractTest`
  - [x] `./re-android/gradlew -p re-android :app-tv:assembleDebug`

## Regression: 4K 视口停留在 2K 画布

- [x] 复现/定位：4K BlueStacks 下仍固定显示 2560x1440 画布，根因是 `TvDesignMetrics.scale` 被限制为最大 1，且 `TvDesignCanvas` 没有为缩放后的可见边界预留布局尺寸。
- [x] 修复：固定 QHD 设计稿在 4K 视口下按 1.5 等比放大，同时外层画布预留 `designWidth * scale` / `designHeight * scale`，避免缩放后偏移或裁剪。
- [x] 补验证：
  - [x] `TvDesignMetricsTest.qhdPreset_scales4kViewportWithSameVisualRatio`
  - [x] `TvDesignCanvasContractTest.canvas_reservesScaledBoundsBeforeGraphicsTransform`

## Regression: 切换分辨率后恢复旧滚动偏移

- [x] 复现/定位：BlueStacks 在 4K 和 1080P 之间切换时，Compose `rememberSaveable` 会把首页、横向 rail、网格和详情横向列表的旧滚动位置恢复到新视口，表现为页面直接落在半截内容里、首卡被裁掉或顶部导航消失。
- [x] 修复：把 `TvPosterRail`、`TvPosterGrid`、`TvHomeRoute` 和 `TvDetailRoute` 的可保存滚动状态改为按 `viewportWidth/viewportHeight` 分桶；视口变化时重建滚动状态和最近获焦索引，不再把旧分辨率的偏移硬套到新分辨率。
- [x] 补验证：
  - [x] `TvPosterFocusContractTest` 断言共享列表使用 `LocalTvDesignMetrics` 作为保存状态 key
  - [x] `TvHomeRouteFocusContractTest` 断言首页纵向列表使用视口 key
  - [x] `TvDetailRouteFocusContractTest` 断言详情横向列表使用视口 key

## Regression: 1080P 顶栏被画布缩放裁掉

- [x] 复现/定位：1080P 冷启动时 `TvDesignCanvas` 日志已恢复 `viewportPx=1920x1080 scale=0.75`，但 `TvTopNavigationBar` 的 `positionInWindow()` 仍是负坐标，说明根因不再是状态栏，而是 `Box + graphicsLayer` 组合把逻辑 2K 画布缩小后摆到了左上角屏幕外。
- [x] 修复：保留 `TvDesignMetrics` 的统一缩放计算，但把 `TvDesignCanvas` 改成固定设计尺寸测量 + `placeWithLayer(0, 0)` 从左上角放置；不再依赖嵌套 `Box` 预留缩放边界，避免 1080P 下顶部导航和首屏内容整体落到负坐标。
- [x] 补验证：
  - [x] `TvDesignCanvasContractTest.canvas_placesScaledLayerFromTopLeft`
  - [x] `./re-android/gradlew -p re-android :core-design:testDebugUnitTest --tests org.moontechlab.selene.tv.core.design.layout.TvDesignMetricsTest --tests org.moontechlab.selene.tv.core.design.layout.TvDesignCanvasContractTest`
  - [x] `./re-android/gradlew -p re-android :app-tv:assembleDebug :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.MainActivityContractTest --tests org.moontechlab.selene.tv.app.TvAppFocusContractTest`
  - [x] `adb logcat -d -s SeleneTV:D '*:S'` 冷启动日志确认 `TopNav column position=Offset(69.0, 42.0)`、`TopNav primaryRow position=Offset(69.0, 135.0)` 已恢复非负坐标
  - [x] `adb shell screencap` 截图 `/private/tmp/selene-tv-current4.png` 确认 1080P 顶栏与首页内容完整可见

## Review Gates

- 每阶段至少有对应测试通过后再进入下一阶段。
- 如果某阶段暴露需求不清，回到 PRD 更新验收路径。
- 不在本任务中顺手重构播放、数据、网络逻辑。
