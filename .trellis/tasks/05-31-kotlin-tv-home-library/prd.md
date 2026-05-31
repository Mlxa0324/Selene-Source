# Kotlin TV 首页与视频库复刻

## Goal

基于子任务 1 的设计系统，复刻 Flutter TV 首页、顶部导航实际使用方式、分类筛选和视频库列表页。

## Parent

Parent task: `.trellis/tasks/05-31-flutter-tv-ui-to-kotlin`

## Requirements

- 源参考：`lib/tv_app/screens/tv_home_screen.dart`、`tv_video_library_screen.dart`、`tv_home_section.dart`、`tv_video_grid.dart`、`tv_category_filter_panel.dart`、相关 `test/tv_app/*home*` 和 `*library*` 测试。
- Kotlin 目标：`feature-tv-home`、`core-data` 需要的 repository/model 补齐、必要 `core-design` 使用。
- 首页分区覆盖继续观看、热门电影、热门剧集、新番放送、热门综艺、历史、收藏。
- 顶部导航在首页中具备 Flutter 同等分类切换、快捷入口跳转、焦点上下左右移动和当前时间展示。
- 视频库/分类页具备筛选、网格、加载、空、错误和焦点行为。

## Acceptance Criteria

- [ ] `feature-tv-home` 不再展示“骨架/后续再接”类用户可见占位。
- [ ] 首页 ViewModel 能输出所有 Flutter TV 首页分区状态。
- [ ] 分类/视频库列表具备可测试的 filter/grid/focus 行为。
- [ ] 首页和库页关键状态有测试覆盖。

## Dependencies

- Depends on `05-31-kotlin-tv-design-shell`.
