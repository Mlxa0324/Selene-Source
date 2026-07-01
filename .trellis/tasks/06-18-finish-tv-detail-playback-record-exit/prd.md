# 完善 Kotlin TV 详情播放器续播记录和退出收尾

## Goal

作为“重做 Kotlin TV 详情页对齐 Flutter TV”的第三阶段，在详情状态机和 UI/焦点稳定后，补齐预览/全屏播放器共享、播放记录保存/清理、续播 seek 补偿和返回退出高优先级打断。

## Parent Task

- `.trellis/tasks/06-18-rewrite-kotlin-tv-detail-from-flutter`

## Dependency

- 依赖 `06-18-rewrite-tv-detail-state-machine` 提供稳定播放请求和续播状态。
- 建议在 `06-18-rewrite-tv-detail-ui-focus` 后执行，以免播放器 overlay 和焦点恢复反复改。

## Requirements

- 详情预览和全屏播放器复用同一播放会话或快照，避免进入全屏重新起播或黑屏。
- 首次 `PlaybackRequest.startPositionMs` 后，如果真实进度未到续播点附近，限次补偿 `seekTo(startAt)`。
- 播放进度保存节流：小于 1 秒不保存；10 秒内重复进度不重复保存。
- 换源时先保存新源播放记录，成功后再清理同影片其它源记录。
- 详情返回先退出 UI，再后台保存播放进度，不等待 IO。
- 退出后播放器事件、保存回包、焦点恢复、post-frame 回调全部早停。
- 全屏退出回详情页时恢复到详情页播放器焦点和滚动位置。

## Acceptance Criteria

- [ ] 测试覆盖预览进入全屏不丢源、集、进度。
- [ ] 测试覆盖续播 seek 被吞后限次补偿。
- [ ] 测试覆盖播放记录保存节流。
- [ ] 测试覆盖换源保存成功后才清理旧源。
- [ ] 测试覆盖返回立即退出且保存不阻塞。
- [ ] 测试覆盖退出后异步回调不再改状态或抢焦点。
- [ ] `:feature-tv-detail:testDebugUnitTest`、`:feature-tv-player:testDebugUnitTest`、`:app-tv:testDebugUnitTest` 相关测试通过。

## Notes

- 本任务暂不开始，等待前两阶段完成后补 design/implement。
