# 修复 Flutter TV 继续观看续播时间失效

## Goal

修复 Flutter TV 端从「继续观看」进入详情/播放时没有按历史播放时间续播的问题，确保用户点击继续观看卡片后能从记录的集数和时间点接着播放。

## What I already know

- 用户反馈 TV 端从继续观看入口点开后，没有从记录的时间点播放。
- TV 端继续观看数据通常通过 `VideoInfo.index/playTime/totalTime` 承载。
- 详情页和全屏播放器已有 `startAt`、`initialPlaybackPosition`、`TvPlayRecordService` 等续播链路。

## Assumptions

- 修复范围优先限定在 Flutter TV 端继续观看卡片、详情页初始选集/续播时间、全屏共享播放器链路。
- 不改动后端接口和普通端播放体验。
- 若继续观看记录缺少有效播放时间，则保持从当前集开头播放。

## Requirements

- 从 TV 首页「继续观看」点击进入详情页时，详情页预览播放器必须按记录的 `playTime` 下发 `startAt`。
- 从继续观看进入后再打开全屏播放器时，全屏播放器必须继承当前预览播放器进度或初始记录时间，不得从 0 秒起播。
- 继续观看记录中的集数下标必须仍然正确映射到当前播放源的选集。
- 对无效时间（0 秒、缺少总时长、超出总时长）保持现有安全回退，不引入异常。
- 补充覆盖继续观看续播时间的 TV widget 回归测试。

## Acceptance Criteria

- [x] TV 继续观看入口进入详情页后，播放器收到的 `startAt` 等于记录的播放时间。
- [x] TV 继续观看入口打开全屏后，播放器不会丢失详情页传入的续播时间。
- [x] 换源、选集、普通影片详情入口不受影响。
- [x] 相关 Flutter TV 测试和分析通过。

## Out of Scope

- 不重构播放记录服务。
- 不改动后端播放历史接口。
- 不调整非 TV 端继续观看入口。

## Technical Notes

- 重点检查 `TvHomeScreen` 继续观看卡片传参、`TvVideoDetailScreen` 初始化 `_pendingInitialPlaybackPosition` 和 `_playCurrentEpisode`、`TvFullscreenPlayerScreen` 初始播放位置消费逻辑。
