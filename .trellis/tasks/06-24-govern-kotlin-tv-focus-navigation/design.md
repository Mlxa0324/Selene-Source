# Kotlin TV 全局遥控焦点治理设计

## Design Principles

- 使用真实可见 focusable 节点承载焦点，不依赖隐藏桥接节点。
- 页面级焦点入口由宿主统一传入 `contentFocusRequester`，页面内部负责把入口绑定到当前最合理的真实节点。
- 列表组件记录最近真实获焦项，顶部/跨区回流优先落到该项。
- 复杂页面使用纯 Kotlin 焦点图描述方向键路径，Compose 只负责把路径结果转为 `FocusRequester.requestFocus()`。
- 对 LazyRow/LazyColumn，先滚动到目标位置，再请求焦点；避免请求器目标尚未组合时失败。

## Current Focus Surfaces

- App shell：`TvApp.kt` 维护顶部导航、当前 route 的 `contentFocusRequester`、顶部下探。
- Navigation graph：`TvNavGraph.kt` 把 `contentFocusRequester` 注入各 feature 页面。
- Shared design：`TvFocusableCard`、`TvPosterRail`、`TvPosterGrid`、`TvPosterFocusGroup`、`TvStatePanel`。
- Home/library：`TvHomeRoute.kt` 处理首页分区、分类筛选、视频库网格。
- Detail：`TvDetailPresentation.kt` 中已有 `TvDetailFocusGraph`，`TvDetailRoute.kt` 绑定请求器。
- Search：`TvSearchRoute.kt` 内部维护键盘、右侧面板和结果区请求器。
- Player：`TvPlayerRoute.kt` 内部维护主菜单、二级菜单和播放控制焦点。
- Settings/live/history/favorites：页面接收内容入口，但需要统一空态/列表态行为。

## Target Contracts

### App Shell

- `contentFocusRequester` 以当前 route 为 key 创建，切换页面时旧页面请求器不复用。
- 顶部导航 `focusProperties.down` 指向当前页面内容入口。
- 顶部导航自身不在 `onPreviewKeyEvent` 中消费下方向键。

### Shared List Components

- `TvPosterRail` 保持最近真实获焦项，并把外部入口请求器绑定到该项。
- `TvPosterGrid` 需要同等入口回流能力；网格场景默认回到最近真实获焦卡片。
- 列表边界行为由组件或页面焦点图明确定义，不交给系统猜测。

### Detail Page

- `TvDetailFocusGraph` 是单一方向路径来源。
- `TvDetailRoute` 对每个区域持有稳定 `FocusRequester` 列表。
- 上下跨区前先滚动目标 LazyRow/LazyColumn 到可见位置，再请求焦点。
- 当某一区域为空时，焦点图选择下一个可用 fallback，而不是返回空请求器。

### Search Page

- 键盘使用二维坐标焦点图，右侧面板使用一维列表焦点图。
- 键盘右移进入右侧面板时落到当前可用入口：结果 > 热词 > 历史 > 搜索按钮。
- 右侧面板左移回键盘时回到最近键盘按键。
- 清空、搜索、删除按钮上下左右需要可预测。

### Player Page

- 默认播放层不制造额外 focusable 节点。
- 菜单打开后焦点只在菜单内移动；关闭菜单后回到播放层。
- 主菜单上下进入二级菜单，二级菜单上移回对应主菜单。
- 左右 seek 只在非菜单态生效，菜单态左右用于菜单选项移动。

## Testing Strategy

- 纯焦点图：优先用普通 JVM 单测覆盖方向输入和目标输出。
- Compose 结构约束：用源码契约测试锁定 `focusProperties`、`focusRequester` 绑定顺序、入口请求器注入。
- Shared components：`core-design:testDebugUnitTest` 覆盖 rail/grid/card/state panel。
- Feature pages：各 `feature-tv-*:testDebugUnitTest` 覆盖页面级路径。
- App shell：`app-tv:testDebugUnitTest` 覆盖顶部导航和路由入口注入。

## Rollout

1. 先补全焦点审计文档和失败契约测试。
2. 先改 shared design 和 App shell，避免每个页面复制补丁。
3. 再按页面修复：home/library/history/favorites/live -> detail -> search/settings/player。
4. 每阶段跑对应模块测试，最后跑 `app-tv` 和受影响 feature 测试。

## Rollback

- 每阶段保持小批量改动；如果某页面焦点变差，回滚该页面绑定，不回滚已经通过的 shared component 契约。
- 如焦点图设计不适配某页面，保留 shared component 修复，重新规划该页面的局部图。
