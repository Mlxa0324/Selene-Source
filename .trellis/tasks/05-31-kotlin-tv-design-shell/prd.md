# Kotlin TV 设计系统与根导航复刻

## Goal

复刻 Flutter TV 的设计视口、主题、页面壳、焦点基础、顶部导航和 Kotlin 根导航能力，为后续页面复刻提供稳定 Compose 基础组件。

## Parent

Parent task: `.trellis/tasks/05-31-flutter-tv-ui-to-kotlin`

## Requirements

- 源参考：`lib/tv_app/tv_app_shell.dart`、`lib/tv_app/widgets/tv_design_canvas.dart`、`tv_top_nav.dart`、`tv_focusable.dart`、`tv_focus_scroll.dart`、`tv_back_handler.dart`、`tv_edge_shake.dart`、`tv_confirm_dialog.dart`、`.trellis/spec/frontend/tv-mode.md`。
- Kotlin 目标：`re-android/app-tv`、`re-android/core-design`。
- 补齐 Compose 等价基础组件：设计预设/缩放、主题 token、页面壳、分区、stat chip、海报卡、rail/grid、空/加载/错误面板、确认弹窗。
- 顶部导航需要支持主分类、右侧快捷入口、当前时间、焦点回到当前选中项。
- 焦点组件需要支持确认短按、长按、KeyRepeat 去重、方向键回调、焦点记忆和自动滚动。
- 根导航需要保留所有最终页面目的地，不再以难以替换的占位实现阻塞后续页面。

## Acceptance Criteria

- [x] `core-design` 提供后续子任务可复用的 TV Compose 组件，不要求页面重复实现同类 UI。
- [x] 根导航包含 home/search/history/favorites/settings/live/detail/player 等目的地的稳定契约。
- [x] 焦点短按/长按/重复事件策略有单元测试或 Compose 测试覆盖。
- [x] 设计视口选择和缩放策略有测试覆盖。
- [x] 不破坏现有 `re-android` 编译结构。

## Dependencies

- This is the first implementation child and should be completed before page children.
