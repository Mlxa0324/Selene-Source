# 重做 Kotlin TV 详情页面 UI 和焦点图

## Goal

作为“重做 Kotlin TV 详情页对齐 Flutter TV”的第二阶段，在状态机和数据链路稳定后，重写 Kotlin TV 详情页 UI 结构和遥控器焦点图，使页面布局、线路/选集/分组/推荐的浏览方式对齐 Flutter TV。

## Parent Task

- `.trellis/tasks/06-18-rewrite-kotlin-tv-detail-from-flutter`

## Dependency

- 依赖 `06-18-rewrite-tv-detail-state-machine` 完成，确保详情状态字段稳定。

## Requirements

- `TvDetailRoute` 拆成可维护组件：顶部栏、Hero、预览播放器、信息面板、线路区、选集区、分组区、推荐区、底部操作。
- 顶部栏展示 `IvyTV`、说明文案、搜索按钮、当前时间。
- Hero 左侧 16:9 预览播放器，右侧标题、年份/来源/集数、简介、全屏和收藏按钮。
- 线路单行横向列表，展示 `线路名（集数）`，按集数倒序，相同集数保持原始顺序。
- 选集单行横向列表在上，分组标签在下；20 集一组；确认分组才切换显示范围。
- 横向列表具备首尾焦点安全留白、边界反馈和可见性滚动。
- 建立显式焦点图，不依赖默认几何焦点。
- 推荐为空不渲染推荐区和底部操作。

## Acceptance Criteria

- [ ] UI 结构源码或 Compose 测试覆盖顶部栏、Hero、线路、选集、推荐空态。
- [ ] 测试覆盖线路首尾方向键不会跳到其它列表。
- [ ] 测试覆盖全屏/收藏下键优先进入当前源。
- [ ] 测试覆盖线路下键进入最近选集，选集上键回最近线路。
- [ ] 测试覆盖选集左右跨组时焦点仍停留在选集链路。
- [ ] `:feature-tv-detail:testDebugUnitTest` 通过。

## Notes

- 本任务暂不开始，等待第一阶段完成后补 design/implement。
