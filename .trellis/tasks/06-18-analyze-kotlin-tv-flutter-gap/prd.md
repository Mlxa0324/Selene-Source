# 分析 Kotlin TV 与 Flutter TV 未对齐项

## Goal

整理 Kotlin TV 与 Flutter TV 的功能、样式、交互、数据流差异，输出按页面和优先级排序的未对齐清单，作为后续逐页追齐的依据。

## Requirements

- 覆盖首页、分类/视频库、搜索、历史、收藏、设置、详情、全屏播放器、直播与顶部壳层。
- 区分已对齐、部分对齐、未对齐三类结果。
- 明确每一项差异属于功能、样式、焦点/遥控交互、数据流或路由层。
- 给出可验证的优先级结论，至少区分 P0、P1、P2。
- 结论必须基于代码与运行态证据，不凭印象下判断。
- 输出结果需要能够继续细化到“逐页功能点清单”，便于直接拆子任务落实。
- 功能点清单至少覆盖：
  - 首页分区与顶部导航
  - 分类筛选、分页与数据源
  - 搜索输入、联想、进度、结果会话
  - 历史/收藏页操作闭环
  - 设置页各分组真实接线
  - 详情页补源、续播、推荐、焦点流
  - 全屏播放器控制、菜单、弹幕、切集切源
  - 直播页是否保留或回退到占位实现

## Acceptance Criteria

- [ ] 形成按页面分组的未对齐清单。
- [ ] 每个页面至少标出 1 条关键差异或确认“已基本对齐”。
- [ ] 对用户可见的交互/样式差异给出明确说明。
- [ ] 输出可直接用于后续修复排期的优先级结论。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
