# 排查 Flutter TV 继续观看未按保存时间续播

## Goal

修复 Flutter TV 端从「继续观看」进入详情页后，播放器没有从保存的 `playTime` 时间点继续播放的问题。

## What I already know

- 用户反馈继续观看入口仍然没有从保存时间点播放，说明之前修复可能只覆盖了部分路径。
- TV 详情页首播会把继续观看的 `VideoInfo.playTime` 转成播放器 `updateDataSource(startAt)`。
- 最近已调整过继续观看选源、同源补源替换、全屏兜底时间等逻辑，当前需要重新追踪实际断点。

## Assumptions

- 继续观看卡片带有有效 `playTime > 0`，但详情页或播放器路径没有稳定消费这个时间。
- 可能存在以下路径遗漏：当前源为空集数后补源、播放器控制器晚于选源创建、播放地址重复去重、`startAt` 被提前消费、进入全屏前小播放器进度仍为 0。
- 本任务优先修 Flutter TV，不改普通端播放行为。

## Requirements

- 从继续观看进入 TV 详情页时，首次可播源下发给播放器必须携带保存的 `playTime`。
- 若播放器控制器晚于当前播放源创建，也必须在控制器 attach 后携带保存时间起播。
- 若先拿到空集数源、后续同源补全 episodes，也必须携带保存时间起播。
- 不得因重复 URL 防抖把带 `startAt` 的首次续播请求吞掉。
- 补充回归测试覆盖失败路径，并保留现有继续观看兜底逻辑。

## Acceptance Criteria

- [x] 能复现并定位继续观看时间点丢失的具体代码路径。
- [x] 修复后继续观看首播 `updateDataSource` 收到正确 `startAt`。
- [x] 控制器晚 attach、同源补源替换等路径仍能按保存时间播放。
- [x] 相关 TV widget 测试、分析和 `git diff --check` 通过。

## Notes

- 不调整后端记录格式。
- 不改变普通端播放器续播逻辑。
