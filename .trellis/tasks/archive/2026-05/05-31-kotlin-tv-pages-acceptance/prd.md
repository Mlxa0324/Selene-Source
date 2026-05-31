# Kotlin TV 功能页与全量验收

## Goal

复刻剩余 Flutter TV 功能页，并完成父任务的全量 UI/交互验收。

## Parent

Parent task: `.trellis/tasks/05-31-flutter-tv-ui-to-kotlin`

## Requirements

- 源参考：`tv_search_screen.dart`、`tv_history_screen.dart`、`tv_favorites_screen.dart`、`tv_settings_screen.dart`、`tv_live_screen.dart`、`tv_danmaku_match_screen.dart`、TV services 和相关 tests。
- Kotlin 目标：`feature-tv-search`、`feature-tv-history`、`feature-tv-favorites`、`feature-tv-settings`、`feature-tv-live`，必要时补齐 danmaku landing point。
- 搜索、历史、收藏、设置、直播页面与 Flutter TV 信息架构、状态、焦点和空/错误态一致。
- 明确 Kotlin 弹幕匹配/弹幕 overlay 的页面或播放器落点。
- 最终清理所有用户可见 placeholder 文案，并完成父任务验收清单。

## Acceptance Criteria

- [x] 搜索/历史/收藏/设置/直播页面均不再是占位页。
- [x] 弹幕相关 TV UI 有 Kotlin 落点或明确等价实现。
- [x] 全仓 `re-android` 用户可见 TV placeholder 搜索无命中。
- [x] 父任务 PRD 中全量验收项逐项可验证。
- [x] 相关 Kotlin 测试和可运行验证命令完成或记录环境阻塞。

## Verification

- `rg "后续接入|临时占位|占位|正在开发|后续|placeholder|TODO|骨架" re-android --glob '!**/build/**'`
- `./re-android/gradlew -p re-android :feature-tv-search:testDebugUnitTest :feature-tv-history:testDebugUnitTest :feature-tv-favorites:testDebugUnitTest :feature-tv-settings:testDebugUnitTest :feature-tv-live:testDebugUnitTest :feature-tv-detail:testDebugUnitTest :feature-tv-player:testDebugUnitTest :core-design:testDebugUnitTest :app-tv:testDebugUnitTest`
- `./re-android/gradlew -p re-android :feature-tv-search:lintDebug :feature-tv-history:lintDebug :feature-tv-favorites:lintDebug :feature-tv-settings:lintDebug :feature-tv-live:lintDebug :feature-tv-detail:lintDebug :feature-tv-player:lintDebug :core-design:lintDebug :core-data:lintDebug :core-network:lintDebug :core-player-exo:lintDebug :core-player-webview:lintDebug :core-benchmark:lintDebug :app-tv:lintDebug`
- `git diff --check`

## Dependencies

- Depends on `05-31-kotlin-tv-design-shell`.
- Should run after home/library and detail/player children so final acceptance covers full UI.
