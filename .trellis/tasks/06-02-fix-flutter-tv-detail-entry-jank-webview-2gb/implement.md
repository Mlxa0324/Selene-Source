# Implementation Plan

## Ordered Checklist

- [x] 梳理 `TvVideoDetailScreen` 当前“续播记录读取 -> 源加载 -> 首次起播”的时序，并定位最小改动点。
- [x] 调整详情页初始化流程，让精确源加载不再被续播记录读取整段阻塞。
- [x] 调整 `VideoPlayerWidget`，让 `url == null` 的预览占位态跳过重播放器初始化和无意义的 PiP 初始化。
- [x] 确保首次 `updateDataSource(startAt)` 仍能拿到最终续播信息，不回退到 0 秒。
- [x] 收紧相关状态更新，避免修复后引入新的 loading / ready 抖动。
- [x] 补或改针对性测试，覆盖首播门闩拆分和空 URL 懒初始化。
- [x] 跑 `flutter analyze` 和相关 `flutter test`，确认无回归。

## Validation Commands

优先运行：

```bash
flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart lib/widgets/video_player_widget.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
```

如存在针对播放器组件的独立测试，再补：

```bash
flutter test test/widgets/video_player_widget_preload_config_test.dart
```

最后补一轮：

```bash
git diff --check
```

## Risky Files

- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `lib/widgets/video_player_widget.dart`
- 可能涉及的现有详情页 / 播放器测试文件

## Rollback Points

- 若并行启动源加载后导致续播错位，优先回退“详情源先于续播记录启动”的改动
- 若懒初始化导致播放器控制器生命周期异常，优先回退 `url == null` 的懒初始化逻辑
- 若测试暴露跨端影响，优先加端侧条件而不是扩大重构范围

## Pre-Start Review

- [x] 任务目标已明确为“修复优化”，不是继续分析
- [x] 上一轮分析任务的结论已转化为本任务的实现范围
- [x] 当前范围只做 Flutter TV 侧可直接落地的第一轮优化，不依赖真机日志才能开始
