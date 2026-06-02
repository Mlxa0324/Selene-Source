# 实施计划

## Step 1: 梳理详情页进入关键链路

- [x] 画出 `initState -> resume record -> startDetailLoading -> attach controller -> play current episode` 的时序。
- [x] 标记每一步是“必须阻塞首播”还是“可以后置”。
- [x] 对照现有 spec，找出可能仍未拆开的次要链路。

## Step 2: 分析 WebView 路径成本

- [x] 审查 `VideoPlayerWidget` 首次初始化与 `WebViewPlayerAdapter` 首次建链的成本点。
- [x] 明确 WebView 在首进详情页时的资源开销类型：视图创建、HTML/JS 装载、播放器 ready、事件桥回流。
- [x] 评估它与 2GB 设备内存/GC 压力的关系。

## Step 3: 分析非 WebView 成本

- [x] 审查详情页初期的并发请求、setState、推荐容器、图片与焦点相关成本。
- [x] 结合已有低内存任务，判断哪些成本已经缓解，哪些仍在详情页进入瞬间生效。
- [x] 把“共因”与“次要因素”分开，不把所有问题混成一个大桶。

## Step 4: 输出结论与后续方向

- [x] 给出进入详情页卡顿因素的优先级排序。
- [x] 判断 WebView 属于主因、重要共因还是次要因素。
- [x] 输出后续优化建议清单，并标记哪些可以直接开修复任务，哪些仍需真机验证。

## Validation / Evidence Commands

```bash
rg -n "initState|_startDetailLoading|_loadRecommendsIfNeeded|updateDataSource|WebViewPlayerAdapter|InAppWebView" lib/tv_app/screens/tv_video_detail_screen.dart lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart
```

如需后续进入实现，可追加：

```bash
flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
```

## Risky Files

- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `lib/widgets/video_player_widget.dart`
- `lib/widgets/player_adapter.dart`
- `.trellis/tasks/archive/2026-06/06-01-analyze-flutter-tv-low-memory-performance/`

## Rollback Notes

- 本任务当前只做分析文档，不涉及代码回滚。
- 若后续基于本任务继续实现，优先拆成独立优化任务，避免把“分析结论”和“实现试验”混在一个任务里。
