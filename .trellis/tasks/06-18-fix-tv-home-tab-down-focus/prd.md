# 修复 Kotlin TV 首页 Tab 下移焦点失效

## Goal

修复首页从继续观看横向列表上移到顶部 Tab 后，再按下方向键无法回到内容区的问题，并补充焦点契约验证。

## Confirmed Facts

- 原生 Kotlin TV 根导航在 `TvNavigationPill` 中通过 `focusProperties { down = contentFocusRequester }` 把顶部导航下方向键交给首页内容入口。
- 首页内容入口 `contentFocusRequester` 只传给第一个可聚焦首页分区，当前场景通常是「继续观看」。
- `TvPosterRail` 当前只把内容入口请求器绑定在第 1 张海报上；横向列表向右滚到靠后位置时，第 1 张海报可能已经脱离 LazyRow 组合树，导致顶部导航再次下探时请求器没有稳定目标。
- 本次修复应保留现有顶部导航和分区组件边界，避免引入新的不可见 focusable 中转节点。

## Requirements

- 用户从首页「继续观看」横向列表移动到靠右卡片后，按上方向键进入顶部 Tab，再按下方向键必须能回到内容区。
- 首页横向分区需要记录最近一次真实获焦卡片，并把顶部下探入口绑定到该卡片；首次进入内容区时仍从首张卡片开始。
- 焦点入口必须绑定到真实海报卡片节点，不新增隐藏 focusable 桥接节点。
- 修复范围限定在原生 Kotlin TV 首页/海报轨道焦点契约和对应单元测试。

## Acceptance Criteria

- [x] 新增或更新契约测试覆盖：`TvPosterRail` 会记住最近获焦卡片，并把公开内容入口请求器绑定到该入口卡片。
- [x] 从继续观看靠右卡片上移到顶部导航后，再按下方向键不再因首卡脱离 LazyRow 组合树而无响应。
- [x] 首次从顶部导航下探首页内容仍落到第一个可用卡片。
- [x] 不新增可获焦的隐藏容器节点，避免破坏现有焦点树。
- [x] 相关 Android unit test 通过。

## Notes

- 根因调查按系统化调试流程完成：先追踪焦点请求器绑定位置，再补红灯测试，最后做最小实现。
- 红灯验证：`./re-android/gradlew -p re-android :core-design:testDebugUnitTest --tests org.moontechlab.selene.tv.core.design.layout.TvPosterFocusContractTest` 在新增契约后失败，失败点为 `posterRail_remembers_last_focused_card_for_top_navigation_reentry`。
- 绿灯验证：同一测试类、`TvHomeRouteFocusContractTest`、`TvAppFocusContractTest` 和完整 `:core-design:testDebugUnitTest` 均已通过。
