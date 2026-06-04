# 实施计划

## Step 1: 复核全屏长按 seek 现状

- [ ] 核对 `TvFullscreenSeekStep` 当前参数与测试基线，确认“首段太快”来自哪一档参数。
- [ ] 复核 `_handleSeekKeyUp`、`_scheduleNextSeekHoldTick`、`_applySeekDelta` 的收尾顺序，确认 key up 后是否还可能有残留 tick。
- [ ] 给长按首段调速准备最小回归测试，避免只靠主观手感改参数。

## Step 2: 排查长按松手后的残留快进

- [ ] 检查 key up 后 `_seekHoldTimer`、`_seekOverlayTimer`、`_activeSeekKey` 是否完全清理。
- [ ] 确认底层 `seekTo` 是否在 key up 后仍会晚到生效，导致看起来像“倍速画面残留”。
- [ ] 如果需要，补充日志或测试钩子验证“最后一次 key up 之后不再发生新的 seek 请求”。

## Step 3: 定位全屏普通控件来源

- [ ] 从 `TvFullscreenPlayerScreen` 壳层条件入手，确认 Flutter 这层是否真的在渲染暂停/底部控件。
- [ ] 从 `VideoPlayerWidget` 的 `showControls`、WebView / adapter 路径确认底层是否仍会露出原生控件。
- [ ] 根据归因决定修复边界：TV 壳层修复、`VideoPlayerWidget` 修复，或记录为底层网页控件限制。

## Step 4: 重新审视 2GB 电视端续播链路

- [ ] 复核详情页与全屏页的 `startAt`、首次 seek、真实进度确认重试三段逻辑。
- [ ] 审视当前重试上限、触发时机和“乐观位置”判断是否仍可能让低端设备漏掉续播点。
- [ ] 若发现明确时序漏洞，补最小修复并同步到详情页/全屏页。

## Step 5: 回归验证

- [ ] 更新或新增全屏长按、key up 收尾、暂停壳层相关测试。
- [ ] 更新或新增续播时序相关测试，确保不会回退已覆盖的继续观看路径。
- [ ] 跑针对性 analyze / test 命令，必要时再跑完整 `test/tv_app/`。

## Validation Commands

```bash
flutter analyze lib/tv_app/screens/tv_fullscreen_player_screen.dart lib/tv_app/screens/tv_video_detail_screen.dart test/tv_app/tv_fullscreen_player_screen_test.dart test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_fullscreen_player_screen_test.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
```

## Risky Files

- `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `lib/widgets/video_player_widget.dart`
- `test/tv_app/tv_fullscreen_player_screen_test.dart`
- `test/tv_app/tv_video_detail_screen_test.dart`

## Rollback Notes

- 如果长按参数调整引起大跨度拖动体验明显变差，可先只保留 key up 收尾修复，回退节奏参数。
- 如果全屏控件问题最终确认来自底层网页/原生控件，避免继续在 TV 壳层堆补丁，应记录为下层播放器问题。
- 如果续播修复导致播放已推进后被旧记录回拉，优先回退重试条件而不是回退整个 `startAt` 链路。
