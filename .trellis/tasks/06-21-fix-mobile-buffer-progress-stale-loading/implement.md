# 修复手机端缓存进度残留与误转圈 - Implement

## Checklist

- [x] 补纯函数/单测红灯：缓存 key 可由 controller 传入媒体身份，不依赖旧 widget 时序。
- [x] 补纯函数/单测红灯：空 `cached_ranges` 会清空当前媒体显示缓存。
- [x] 补纯函数/单测红灯：实时缓存覆盖当前位置时抑制短暂 buffering loading。
- [x] 修改 `VideoPlayerWidgetController.updateDataSource()` 和 `_updateDataSource()`，支持明确媒体身份。
- [x] 修改 `PlayerScreen.updateVideoUrl()` 调用，传入当前 source/id/episodeIndex。
- [x] 修改 `_recordCachedRanges()`，允许当前 key 的空列表清空显示缓存。
- [x] 修改 loading 显示条件，只在未被实时缓存覆盖时显示 buffering 遮罩。
- [x] 运行验证：
  - `flutter test test/widgets/video_player_widget_preload_config_test.dart`
  - `flutter test test/widgets/player_adapter_webview_preload_test.dart`
  - `flutter test test/widgets/mobile_player_controls_preload_test.dart`
  - `flutter test test/widgets/mobile_player_controls_seek_test.dart`
  - `flutter analyze lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart lib/screens/player_screen.dart test/widgets/video_player_widget_preload_config_test.dart`

## Validation Notes

- `flutter test test/widgets/video_player_widget_preload_config_test.dart`：通过，15 个测试全部通过。
- `flutter test test/widgets/player_adapter_webview_preload_test.dart`：通过，10 个测试全部通过。
- `flutter test test/widgets/mobile_player_controls_preload_test.dart`：通过，2 个测试全部通过。
- `flutter test test/widgets/mobile_player_controls_seek_test.dart`：通过，10 个测试全部通过。
- `flutter analyze lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart test/widgets/video_player_widget_preload_config_test.dart`：通过，无新增问题。
- `flutter analyze lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart lib/screens/player_screen.dart test/widgets/video_player_widget_preload_config_test.dart`：未通过，失败项均来自 `lib/screens/player_screen.dart` 的既有 warning/info（未使用字段、旧 `print`、旧 `withOpacity` 等），本次改动附近无新增 analyzer 问题。

## Review Questions

- 切集瞬间是否仍可能显示上一集缓存段？应不可能：controller 调用带明确媒体身份，切源前先清空当前 key。
- 已缓存位置是否还会短转圈？实时缓存覆盖当前位置时不会；如果浏览器真实 buffer 已淘汰或当前位置在 HLS 小洞外，仍会正常转圈。

## Rollback

- 如发现抑制 loading 影响真实卡顿反馈，回滚 loading 判定 helper，保留缓存 key/清空修复。
