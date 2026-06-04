# 修复 Flutter TV 详情与全屏加载态误判 - 实施计划

## Ordered Checklist

- [x] 梳理详情页与全屏页当前 loading 显示/隐藏链路，明确首播等待态与 seek 恢复态的进入/退出点。
- [x] 设计并落地可复用的 TV 中心 loading 组件，包含转圈与网速文本。
- [x] 收紧详情页小播放器的 loading 退出条件，避免“开始播了但转圈还在”与“黑屏时提前隐藏”两类误判。
- [x] 收紧全屏播放器的 loading 退出条件，并区分 seek overlay 与 seek 松手后的恢复 loading。
- [x] 为详情页和全屏页接入网速文本来源；若真实速率无法稳定获取，提供可接受的近似/降级方案。
- [x] 新增或更新 widget test，覆盖首次进入与长按 seek 恢复场景下的 loading 显示/隐藏。
- [x] 运行针对性 `flutter analyze`、`flutter test` 与 `git diff --check`。

## Validation Commands

优先运行：

```bash
flutter analyze \
  lib/tv_app/screens/tv_video_detail_screen.dart \
  lib/tv_app/screens/tv_fullscreen_player_screen.dart \
  lib/tv_app/widgets/tv_player_loading_indicator.dart
```

```bash
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_fullscreen_player_screen_test.dart
```

最后补一轮：

```bash
git diff --check
```

## Risky Files

- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- `lib/widgets/video_player_widget.dart`
- `lib/widgets/player_adapter.dart`
- `test/tv_app/tv_video_detail_screen_test.dart`
- `test/tv_app/tv_fullscreen_player_screen_test.dart`

## Review Gates

实现前确认：

- [x] 网速只在首次进入与长按 seek 松手后的恢复 loading 阶段显示，不做常驻
- [x] 一旦恢复播放，网速与转圈立即一起消失
- [x] 本任务独立于当前详情页卡顿瘦身任务，不把目标扩展到无关性能优化
- [x] 本任务是复杂任务，已补 `prd.md` 与 `design.md`
- [x] 若拿不到稳定可信的实时网速，允许退成仅显示 `加载中` 文案

## Rollback Points

- 若“真实出画面”判断过严导致转圈长期不消失，优先回退新加的严格门闩，保留 loading 组件结构与测试。
- 若网速来源不稳定导致 UI 抖动，优先回退为只保留转圈，先不阻塞 loading 判断修复。
- 若速率数值本身不可信，直接降级为只显示 `加载中` 文案，不再继续扩大底层适配范围。
- 若全屏 seek 恢复 loading 与现有 seek overlay 打架，优先保留 seek overlay 交互，再单独收缩恢复 loading 的进入窗口。
