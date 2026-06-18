# 按截图重做 Kotlin TV 详情页样式设计

## Scope

本任务只重做 `feature-tv-detail` 的详情页 Compose 展示层，保留前两阶段已经完成的状态机、展示模型和焦点策略：

- `TvDetailRoute.kt`：整体替换截图式布局与组件。
- `TvDetailPresentation.kt`：保留线路排序、选集分组、布局显隐、焦点策略。
- `TvDetailRouteFocusContractTest.kt`：扩展为截图样式源码契约测试。

## Visual Architecture

`TvDetailRoute` 重组为截图式组件：

- `NcatDetailTopBar`
- `NcatDetailHero`
- `NcatPreviewPanel`
- `NcatInfoPanel`
- `NcatActionTile`
- `NcatSourceRail`
- `NcatSourceCard`
- `NcatEpisodeGroupRail`
- `NcatRecommendRail`
- `NcatBottomActions`

这些组件替换上一版 `TvDetailTopBar` / `TvDetailHeroSection` / `TvDetailSourceSection` 的视觉角色。旧组件可以删除或改名，避免继续在上一版结构上追加颜色补丁。

## Layout Contract

- 页面背景固定深色 `#11131C` 近似截图底色。
- 水平安全边距接近截图，仍复用 `TvTokens.PageHorizontalPadding` 作为基线。
- 顶部栏高度约 96dp，品牌字号大于说明文案。
- Hero 区域左右布局：
  - 左侧预览播放器宽约 620dp、16:9。
  - 右侧信息面板占剩余宽度，标题、标签、简介、操作按钮垂直排列。
- 线路卡使用固定大尺寸，避免文字和焦点缩放改变列表高度。
- 选集分组轨道用 `LazyRow` 展示灰色短轨道和下方区间文字。
- 推荐继续使用横向列表，但卡片视觉改成浅色封面、底部渐变集数状态和标题。
- 底部操作居中，按钮为圆角胶囊。

## Focus Contract

- 保留 `TvDetailFocusTargets` 的显式请求器集合。
- 新增登录、反馈、返回顶部、随便看看等 UI 焦点项时，若不进入业务状态机，使用局部 `FocusRequester` 并接到明确上下左右目标。
- 当前主焦点视觉：
  - 操作 tile：红底 + 白色外描边。
  - 线路卡：红底表示选中/获焦。
  - 分组标签：红色文字表示当前或获焦。
  - 推荐卡：沿用海报卡焦点放大。
- 横向轨道继续使用 `LazyListState` 获焦滚动，不回退到默认几何焦点。

## Compatibility

- `TvDetailRoute` public signature 不破坏现有调用。
- `onHistoryClick` 可映射到底部“返回顶部”或保留为空操作；本任务不新增导航依赖。
- `onExitClick` 可映射到“随便看看”或保留宿主回调；不在本任务新增随机推荐逻辑。
- `onSearchClick` 继续打开搜索入口。

## Testing Strategy

- 源码契约测试锁定截图关键结构和文案：
  - `NcatDetailTopBar`
  - `网飞猫`
  - `立即登录`
  - `NcatSourceCard`
  - `NcatEpisodeGroupRail`
  - `好片推荐`
  - `返回顶部`
  - `随便看看`
- 保留上一阶段 presentation/focus tests，确保逻辑不被视觉重写破坏。
- 跑 `:feature-tv-detail:testDebugUnitTest` 作为模块验证。

## Rollback

如果截图样式实现影响焦点编译或 Route 过大，先保留 `TvDetailPresentation` 和焦点测试，回退到单文件内截图式组件，但不回退到上一版视觉结构。
