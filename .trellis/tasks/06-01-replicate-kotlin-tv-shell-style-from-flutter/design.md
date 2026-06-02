# Technical Design

## Architecture And Boundaries

本任务只改 Kotlin TV 端视觉层，边界集中在 `re-android`：

- `core-design` 负责统一 token、页面壳、海报卡片、网格和可复用焦点样式。
- `app-tv` 负责全局应用壳、顶部导航、播放器页是否隐藏普通导航。
- `feature-tv-home` 负责首页和分类页的页面结构。
- `feature-tv-detail` 负责详情页布局和横向选项样式。
- `feature-tv-player` 负责全屏播放器视觉壳。

Flutter 端只作为样式参照，不在本任务中修改。

## Visual System

采用 Flutter TV 默认观感作为 Kotlin TV 的第一轮目标：

- 背景：从接近纯黑调整为深蓝灰，减少 Kotlin 当前的空和冷。
- 主色：默认选中态切换到奈飞红系，保留 Ivy 绿仅作为后续可配置主题的可能值。
- 品牌：`IvyTV` 使用白色、更粗字重，不再用绿色品牌字作为默认首屏焦点。
- 焦点：焦点描边以白色为主，选中态用红色填充，弱焦点背景使用半透明白或深灰。
- 圆角：快捷入口使用 22dp 胶囊；主导航使用 8dp；海报卡片保持较小圆角但提高卡片尺寸和密度。
- 边距：继续沿用 Flutter 的 36dp 水平安全边距。

## Shared Component Changes

### `TvTokens`

新增或调整以下用途明确的 token：

- 默认背景、卡片背景、弱卡片背景、弱边框、焦点描边、默认选中主色。
- 顶部导航高度、快捷入口高度、主导航内边距。
- 海报卡片宽高、封面高度、列表间距、网格列数相关尺寸。

### `TvPageScaffold`

把当前强绑定 `title/subtitle/stats` 的页面壳改成更轻的内容壳：

- 支持隐藏头部或只展示页面标题。
- 首页默认不再展示内页标题，因为顶部导航已经表达品牌和位置。
- 分类、详情可保留标题，但不展示统计 chip。
- 状态面板继续复用，但需要套用新的背景和卡片色。

### `TvPosterCard` / `TvPosterRail` / `TvPosterGrid`

调整卡片尺寸、间距和焦点反馈：

- 横向列表卡片更接近 Flutter TV 的竖海报比例。
- 卡片标题和副标题层级更清晰，避免只有渐变占位感。
- 焦点放大保持轻量，避免四页同时改造时引入滚动跳动。

## Page Design

### Home

- 去掉 `TvPageScaffold(title = "IvyTV", subtitle = "横向分区首页", stats = ...)` 的占位头。
- 区块标题靠近 Flutter：`继续观看` 加弱提示，其他区块保持清晰标题。
- 横向列表保持现有数据结构，不改 ViewModel。

### Category

- 筛选区保留 `TvLibraryFilterPanel`，但 chip 样式改为 Flutter 风格。
- 视频网格列数优先接近 Flutter 的 7 列密度；如果 Kotlin 当前尺寸无法容纳，先以 token 控制到视觉接近。
- 保留当前筛选选中和焦点状态回传，避免破坏用户前面提到的焦点停留诉求。

### Detail

- 详情页不再使用统计 chip 展示线路和剧集。
- 预览播放器区域改成更大的暗色视觉块，右侧简介、播放入口和收藏/全屏入口更靠近 Flutter 的内容页层级。
- 线路、选集继续使用横向 LazyRow，但样式统一到新的 chip token。
- 推荐列表继续复用 `TvPosterRail`。

### Player

- 播放器页改为沉浸式黑底视觉壳。
- 当前没有真实视频画面时，先使用大面积播放画布占位，控制区放在底部或靠下区域。
- `播放列表`、`其它` 菜单保留现有 ViewModel 行为，但视觉从普通按钮改为播放器控制菜单。

## Data Flow And Contracts

- 不改变 `TvHomeUiState`、`TvVideoLibraryUiState`、`TvDetailUiState`、`TvPlayerUiState` 的字段语义。
- 不新增接口请求，不改变 `TvAppContainer` 的仓库和网关依赖。
- 视觉组件可以新增可选参数，但必须给默认值，避免影响历史、搜索、设置等已有调用点。

## Compatibility Notes

- `TvPageScaffold` 是共享组件，修改时需要同步检查历史、搜索、设置、直播等调用点，避免旧页面标题消失或间距异常。
- `TvTokens` 改色会影响整个 Kotlin TV，需要通过截图或运行验证确保页面没有文字对比度问题。
- `TvPosterCard` 尺寸变大后会影响横向列表和网格密度，需要同步调整 `TvPosterGrid` 列数或内容 padding。

## Trade-Offs

- 选择 C 可以最快让四个核心页面整体变像，但不会保证首页首屏先达到 1:1。
- 为降低 C 的不一致风险，先改共享 token 和组件，再改四个页面结构。
- 本轮播放器只做视觉壳，不把真实播放能力当作样式任务一起扩大。

## Rollback Considerations

- 共享 token 改动风险最高；如出现大面积对比度或布局问题，优先回退 `TvTokens` 和共享组件。
- 页面结构改动按 Home、Category、Detail、Player 分块提交或分块验证，方便定位问题。
