# 调查 Flutter TV 投影仪继续观看续播失效

## Goal

同一个 Flutter TV 安装包在模拟器上从继续观看进入详情页可以按记录时间起播，但在 Amlogic S905Y2 / 2GB RAM / 8GB ROM 投影仪真机上无法从记录时间点播放，需要定位设备差异和续播链路失败点。

## Requirements

- 对比同一 TV 安装包在模拟器与投影仪真机上的继续观看续播链路差异。
- 设备范围明确为投影仪：Amlogic S905Y2，四核 A53，ARM 架构，2GB RAM，8GB ROM（系统占用约 4GB，可用约 3.9GB）。
- 调查入口为 Flutter TV 端“继续观看”卡片进入 `TvVideoDetailScreen` 后的小播放器起播行为。
- 必须确认投影仪上播放记录是否被正确读取，包含 `source/id/index/playTime/totalTime/searchTitle`。
- 必须确认详情页是否匹配到正确播放记录并生成 `_resumeVideoInfo`。
- 必须确认 `_applyInitialResumeState` 是否把 `playTime` 转成 `_pendingInitialPlaybackPosition`。
- 必须确认 `_updatePreviewPlaybackSource` 是否把 `startAt` 传给 `VideoPlayerWidgetController.updateDataSource`。
- 必须确认底层播放器如果忽略 `startAt`，`_seekToInitialPlaybackPositionIfNeeded` 是否执行并成功。
- 必须区分“记录没读到/匹配不到”和“播放器收到时间点但设备上 seek 失败”两类问题，避免盲目改 UI。
- 保持模拟器已可续播的行为不回退。

## Acceptance Criteria

- [ ] 产出模拟器与投影仪真机的续播链路对比结论。
- [x] 明确失败点属于记录读取、记录匹配、起播参数下发、seek 兜底、播放器内核或设备性能/解码差异中的哪一类。
- [x] 若需要代码修复，提供最小修复方案和对应 widget/integration 验证点。
- [x] 若需要真机日志，列出具体 adb/logcat 采集命令和需要观察的日志字段。
- [x] 修复或结论不得破坏现有详情页续播测试：`resumes continue watching episode and playback position`、`continue watching seeks after source update when startAt is ignored`。

## Notes

- 已知模拟器同包可正常从记录时间点起播，投影仪同包不行。
- 已知相关代码集中在 `lib/tv_app/screens/tv_video_detail_screen.dart`、`lib/tv_app/screens/tv_fullscreen_player_screen.dart`、`lib/tv_app/services/tv_play_record_service.dart`。
- 已知详情页当前已有 `startAt` 下发和 seek 兜底测试。
- 本任务是 Flutter TV 端调查，不是 Kotlin 原生 TV 任务。

## Progress 2026-06-01

- 已确认当前 adb 只连接到模拟器，投影仪真机日志仍需后续接入设备后采集。
- 代码链路显示播放记录读取、记录匹配、`startAt` 下发和一次性 seek 兜底已有覆盖；投影仪更可能落在低端 Android WebView/播放器 ready 前吞掉首次 seek 的时序差异。
- 已补详情页和全屏页的真实进度确认重试：当首次 seek 后真实进度仍回到 0 秒或续播点之前时，限次补 seek，避免模拟器正常路径回退。
