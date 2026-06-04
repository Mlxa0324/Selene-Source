# Flutter TV 详情页 SSE 无播放信息提示 - 实施计划

## Step 1: 搜索页共享搜索会话

- [ ] 在搜索页抽出“一轮搜索请求共享状态”对象，承载：
  - 当前原始 `SearchResult` 列表
  - 是否已完成
  - 增量/完成通知
  - 请求失效保护
- [ ] `_performSearch` 在开始新请求时创建/重置共享会话。
- [ ] 搜索页收到增量结果和最终结果时，同时更新页面状态与共享会话。
- [ ] 搜索请求被新请求覆盖或页面回退失效时，旧会话不再继续派发。

## Step 2: 详情页复用共享搜索会话

- [ ] 给 `TvVideoDetailScreen` 增加可选“共享搜索会话”入参。
- [ ] 详情页初始化时，优先合并共享会话当前快照。
- [ ] 若共享会话未完成，订阅后续更新并持续 `_mergeSources(...)`。
- [ ] 若共享会话已完成或结束，正确驱动详情页“补源完成”状态。
- [ ] 没有共享会话时，维持原有 `loadMoreSources` 标题补源逻辑。

## Step 3: 详情页空状态

- [ ] 在“切换线路”分区新增图标 + 提示空状态 builder。
- [ ] 仅在“补源已完成且仍无可播放线路”时展示该空状态。
- [ ] 补源进行中保持现有加载态/等待态，不提前显示“无播放信息”。

## Step 4: 测试回归

- [ ] 更新详情页测试，覆盖“共享搜索会话已完成时跳过二次补源”。
- [ ] 新增或更新测试，覆盖“共享搜索会话进行中进入详情页后继续收到后续增量结果”。
- [ ] 新增或更新测试，覆盖“共享搜索会话结束且无源时显示图标空状态”。
- [ ] 新增或更新测试，覆盖“有源时不显示空状态”。

## Validation Commands

```bash
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_search_screen_test.dart
flutter analyze lib/tv_app/screens/tv_search_screen.dart lib/tv_app/screens/tv_video_detail_screen.dart test/tv_app/tv_video_detail_screen_test.dart test/tv_app/tv_search_screen_test.dart
```

## Risky Files

- `lib/tv_app/screens/tv_search_screen.dart`
- `lib/tv_app/screens/tv_video_detail_screen.dart`
- `test/tv_app/tv_video_detail_screen_test.dart`
- `test/tv_app/tv_search_screen_test.dart`

## Rollback Notes

- 若共享搜索会话逻辑引入跨页状态问题，可先回退到“详情页只吃静态 `prefetchedSources` 快照”的旧逻辑。
- 若图标空状态影响其它无源场景，可先保留共享会话复用逻辑，仅回退空状态展示条件。
