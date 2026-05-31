# Kotlin TV 详情与播放器复刻

## Goal

复刻 Flutter TV 详情页和全屏播放器壳，接入真实 Kotlin player route，移除播放器占位。

## Parent

Parent task: `.trellis/tasks/05-31-flutter-tv-ui-to-kotlin`

## Requirements

- 源参考：`lib/tv_app/screens/tv_video_detail_screen.dart`、`tv_fullscreen_player_screen.dart`、`tv_play_record_service.dart`、`tv_search_recommend_service.dart`、`tv_danmaku_overlay.dart`、相关 detail/player tests。
- Kotlin 目标：`feature-tv-detail`、`feature-tv-player`、`core-player-*`、`core-data`。
- 详情页必须支持首源快速加载、后台补源、去重、推荐、线路切换、选集切换、播放记录恢复。
- 全屏播放器路由必须替代当前 `TvPlayerPlaceholder`，并支持现有 Exo/WebView 内核切换和播放快照恢复。
- UI 布局需包含 Flutter 对应的预览/播放区域、元信息、操作入口、源列表、选集和推荐。

## Acceptance Criteria

- [ ] Kotlin detail route 不再展示骨架占位文案。
- [ ] Player route 是真实播放器壳，不是 placeholder text。
- [ ] 详情 staged loading 和播放源去重有测试覆盖。
- [ ] 播放器快照恢复/内核切换现有测试继续通过。

## Dependencies

- Depends on `05-31-kotlin-tv-design-shell`.
- Should follow `05-31-kotlin-tv-home-library` if detail navigation depends on home card argument contracts.
