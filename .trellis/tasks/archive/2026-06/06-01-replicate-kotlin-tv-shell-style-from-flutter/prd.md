# 复刻 Kotlin TV 全套样式到接近 Flutter TV

## Goal

把 `re-android` 的 Kotlin TV 端从当前偏占位、偏工程样式的界面，粗对齐到 Flutter TV 端的整体视觉气质。用户已选择方案 C：首页、分类、详情、全屏播放四个页面一起先做一轮粗对齐，让整体先不像两个不同 App，再进入后续精修。

## User Value

- 用户在模拟器或 TV 设备上打开 Kotlin TV 时，第一眼能看到与 Flutter TV 接近的品牌、导航、背景、卡片和焦点反馈。
- 页面之间的视觉语言一致，避免首页像 Flutter、详情或播放器又回到 Kotlin 占位样式。
- 本轮只做“全局粗对齐”，为后续 1:1 精修留出稳定 token 和组件基础。

## Confirmed Facts

- Flutter TV 顶部导航位于 `lib/tv_app/widgets/tv_top_nav.dart`，使用 36dp 左右安全边距、白色 IvyTV 标识、右侧快捷入口、时间和二级主导航。
- Flutter TV 默认主题使用奈飞红作为选中主色，背景默认深蓝灰，相关定义位于 `lib/tv_app/services/tv_theme_service.dart`。
- Flutter TV 页面统一安全边距定义位于 `lib/tv_app/tv_layout.dart`，`pageHorizontalPadding` 为 36。
- Kotlin TV 当前全局 token 位于 `re-android/core-design/src/main/java/org/moontechlab/selene/tv/core/design/TvTokens.kt`，品牌色仍偏 Ivy 绿，背景更黑，卡片尺寸与 Flutter 不一致。
- Kotlin TV 当前页面壳位于 `TvPageScaffold.kt`，默认强制展示标题、副标题和统计 chip，导致首页、分类、详情看起来像管理面板。
- Kotlin TV 顶部导航位于 `TvApp.kt`，当前按钮顺序、选中态、字号、圆角、品牌色与 Flutter TV 差异明显。
- Kotlin TV 首页、分类、详情、播放器分别位于 `TvHomeRoute.kt`、`TvHomeRoute.kt` 内的 `TvVideoLibraryRoute`、`TvDetailRoute.kt`、`TvPlayerRoute.kt`。
- Kotlin TV 播放器页当前只有标题和两个按钮，离 Flutter 全屏播放的沉浸式样式差距最大。

## Requirements

- 全局视觉 token 对齐 Flutter TV 的默认观感：深蓝灰背景、红色选中态、白色焦点边框、36dp 页面安全边距、圆角与间距节奏更接近 Flutter。
- 顶部导航改为 Flutter TV 气质：左侧白色 `IvyTV`，右侧快捷入口、时间和主导航的顺序、圆角、字体大小、选中态接近 Flutter。
- 首页去掉当前 `横向分区首页`、分区统计、焦点统计等占位式头部，保留内容区层级，第一屏重点呈现“继续观看”和横向海报列表。
- 分类页保留筛选与视频网格能力，但视觉上去掉管理面板感，让筛选 chip、标题、网格密度接近 Flutter TV。
- 详情页保留预览播放、线路、选集、推荐能力，但需要调整为 Flutter TV 的暗色内容面板、横向选项、按钮和推荐卡片节奏。
- 全屏播放器页先做视觉壳粗对齐：沉浸黑底、底部或侧边控制区、顶部菜单入口，避免继续展示普通页面标题。
- 本轮不重写数据链路，不改变播放、筛选、收藏、历史等业务行为。
- 本轮不解决所有焦点策略问题，但不能引入新的自动归位或明显滚动抖动。

## Acceptance Criteria

- [ ] Kotlin TV 启动后，首页首屏没有 `横向分区首页`、`分区`、`焦点` 这类占位统计信息。
- [ ] Kotlin TV 顶部导航品牌、快捷入口、时间、主导航在布局顺序和视觉重量上接近 Flutter TV。
- [ ] 首页、分类、详情、播放器四个页面都使用同一套背景、主色、焦点描边、卡片圆角和间距 token。
- [ ] 首页“继续观看”等横向列表的海报卡片尺寸、标题层级、间距比当前 Kotlin 版本更接近 Flutter TV。
- [ ] 分类筛选 chip 与视频网格不再呈现明显工程占位样式，选中态与焦点态清晰可辨。
- [ ] 详情页预览区、线路、选集、推荐区不再依赖通用统计头部，整体更像 Flutter TV 的内容页。
- [ ] 播放器页不再展示普通页面式 `全屏播放` 大标题，而是展示沉浸式播放背景和控制菜单。
- [ ] 单元测试或 Compose 可测范围通过；至少运行相关 Gradle 测试命令验证没有编译或现有测试回归。

## Out Of Scope

- 精确 1:1 复刻每个像素、动效曲线和所有 Flutter 设置主题。
- 重做播放器真实内核、视频画面渲染或播放协议。
- 重写搜索、历史、收藏、设置页的完整业务流程。
- 新增服务端接口或修改网关配置读取逻辑。
- 大规模改造焦点导航算法；本轮只避免视觉粗对齐时引入新的焦点回退问题。

## Open Questions

- 无阻塞问题。用户已选择方案 C，规划按“四页同时粗对齐”推进。
