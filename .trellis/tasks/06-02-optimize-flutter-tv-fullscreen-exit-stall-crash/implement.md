# 优化 Flutter TV 全屏退出卡顿与闪退 - 实施计划

## Ordered Checklist

- [ ] 梳理 `TvFullscreenPlayerScreen` 当前主动退出、系统 pop、dispose 三条收尾路径的职责与重叠点。
- [ ] 为全屏退出增加“退出中 / 已调度收尾”守卫，避免单轮退出重复执行。
- [ ] 把主动退出链路改成“先执行可见退出，再后台保存进度”。
- [ ] 收紧 `dispose()` 与 `_handlePopInvoked()` 的兜底保存策略，避免重复重保存竞争。
- [ ] 给退出后的异步回调加守卫，减少已退出页面继续回写状态的风险。
- [ ] 补或改测试，覆盖共享 fullscreen overlay 的非阻塞退出与避免重复收尾行为。
- [x] 恢复详情页 preview loading overlay，黑底加载时显示转圈和真实网速，未知时才回退 `0KB/s`，并保持遥控器焦点可移动。
- [x] 续播记录未返回导致首播挂起时，详情页 preview loading overlay 仍然显示转圈和网速反馈。
- [x] 调整详情页 preview loading 测试，从“收到 ready/play 隐藏”改成“播放时间点从 loading 锚点前进后隐藏”。
- [x] 调整全屏 loading / seek 测试，从“收到 ready/play 或 loading=false 隐藏”改成“播放时间点从 loading 锚点前进后隐藏”。
- [x] 去掉详情页和全屏 loading 的背景色，只保留顶层转圈、加载文案和网速。
- [x] 给全屏长按 seek 松手后的 loading 增加真实进度清理路径，并监听复用详情页播放器的真实 controller 进度。
- [x] 给 WebView HLS loader 增加常驻网速 telemetry，避免关闭广告过滤时网速长期停在 `0KB/s`。
- [x] 运行 `flutter analyze`、相关 `flutter test` 与 `git diff --check`。

## Validation Commands

优先运行：

```bash
flutter analyze \
  lib/tv_app/screens/tv_fullscreen_player_screen.dart \
  lib/tv_app/screens/tv_video_detail_screen.dart \
  test/tv_app/tv_fullscreen_player_screen_test.dart \
  test/tv_app/tv_video_detail_screen_test.dart
```

```bash
flutter test test/tv_app/tv_fullscreen_player_screen_test.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
```

最后补一轮：

```bash
git diff --check
```

## Risky Files

- `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `test/tv_app/tv_fullscreen_player_screen_test.dart`
- `test/tv_app/tv_video_detail_screen_test.dart`

## Review Gates

实现前确认：

- [x] 退出时优先保证用户立刻回到详情页，不让保存阻塞可见退出
- [x] 播放进度保存能力不能整体移除，只能优化时机和重复收尾
- [x] 共享 fullscreen overlay 返回详情页与焦点恢复行为不能回退
- [x] 当前任务按复杂任务处理，已补 `prd.md` 与 `design.md`

## Rollback Points

- 若“先退后存”导致进度保存明显回退，优先保留退出守卫，只回退保存触发时机。
- 若退出守卫误伤系统返回路径，优先放宽兜底保存条件，而不是恢复同步阻塞退出。
- 若共享播放器 overlay 路径出现新问题，优先限定改动在 `onExitRequested` 分支，不扩大到独立全屏路由。
