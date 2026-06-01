# 调查设计

## Scope

本任务只调查 Flutter TV 包在投影仪真机上继续观看进入详情页后无法按记录时间起播的问题。重点链路是播放记录读取、详情页续播状态应用、播放器 `startAt` 下发和 seek 兜底执行情况。

## Known Flow

`TvVideoDetailScreen` 进入后先通过 `PageCacheService().getPlayRecords(context)` 读取最新播放记录，再用 `source + id` 匹配入口影片。匹配成功后，`VideoInfo.fromPlayRecord` 会刷新 `_resumeVideoInfo`。

详情源加载完成后，`_applyInitialResumeState` 会用 `TvPlayRecordService.resumePositionFromVideoInfo` 把 `playTime` 转成 `_pendingInitialPlaybackPosition`。小播放器起播时，`_updatePreviewPlaybackSource` 取出该时间点并传给 `controller.updateDataSource(url, startAt: startAt)`。

如果底层播放器没有吃到 `startAt`，`_seekToInitialPlaybackPositionIfNeeded` 会读取 `controller.currentPosition` 并补一次 `controller.seekTo(startAt)`。

## Investigation Boundaries

- 如果投影仪上 `getPlayRecords` 返回为空或旧值，优先查缓存/服务端记录同步和本地模式差异。
- 如果播放记录存在但没有匹配到入口影片，优先查 `source/id` 是否在投影仪入口数据中丢失或变化。
- 如果 `startAt` 已下发但播放器仍从 0 秒起播，优先查 `VideoPlayerWidgetController` 对投影仪设备的 `updateDataSource(startAt)` 和 `seekTo` 支持。
- 如果 `seekTo` 被调用但失败或无效，优先查底层播放器日志、媒体格式、硬解兼容性和低内存设备时序。

## Logging Points

- 继续观看入口 `VideoInfo` 的 `source/id/index/playTime/totalTime/searchTitle`。
- `getPlayRecords` 返回数量和命中记录字段。
- `_applyInitialResumeState` 计算出的集数下标与 `resumePosition`。
- `_updatePreviewPlaybackSource` 下发的 `url` 与 `startAt`。
- `_seekToInitialPlaybackPositionIfNeeded` 中的 `currentPosition`、是否调用 `seekTo`、seek 结果或异常。

## Validation Shape

模拟器和投影仪使用同一个安装包、同一个账号/服务器、同一条继续观看记录、同一个视频源。对比日志后只针对失效环节做最小修复。

## Investigation Result 2026-06-01

在投影仪真机未连接前，先基于现有代码和测试完成静态链路定位：

- 记录读取与匹配：详情页会重新读取最新 `PlayRecord`，并按 `source + id` 或同片源匹配修正入口 `VideoInfo`。
- 起播参数：`_takeInitialPlaybackPosition` 会把 `playTime` 转成 `startAt` 下发给 `VideoPlayerWidgetController.updateDataSource`。
- 首次兜底：原实现会在 `updateDataSource` 后立即读取 `currentPosition` 并补一次 `seekTo(startAt)`。
- 设备差异点：Android WebView/低端播放器在 `loadedmetadata` 或真实可 seek 前可能吞掉首次 seek，Flutter 侧又会先乐观更新位置，导致一次性兜底误以为成功。

修复策略：详情页和全屏页记录本轮续播 seek 目标，等真实进度事件回来后确认当前位置；如果仍在续播点之前，限次补 seek。这样不阻塞首播，也不改变模拟器已经正常的 `startAt` 路径。
