# 实施计划

## Steps

- [x] 确认当前搜索联想任务是否已提交或暂存，避免混入本调查任务改动。
- [x] 在 Flutter TV 续播链路加入可验证的进度确认兜底，覆盖播放器吞掉首次 seek 的设备差异。
- [ ] 构建同一个 TV 安装包，并分别安装到模拟器和投影仪。
- [ ] 准备同一条继续观看记录，确保两端 `source/id/playTime/index` 一致。
- [ ] 使用 adb/logcat 分别采集模拟器与投影仪从继续观看进入详情页的完整日志。
- [x] 对比失败点：
   - 记录读取失败
   - 记录匹配失败
   - resume position 计算失败
   - `startAt` 未下发
   - `seekTo` 未执行
   - `seekTo` 执行失败或设备忽略
- [x] 根据定位结果选择最小修复：
   - 记录/匹配问题：修正 `VideoInfo` 或 `PlayRecord` 匹配链路。
   - 时序问题：调整播放器 ready 后 seek 兜底时机。
   - 设备播放器问题：增加投影仪兼容路径或更强制的延迟 seek 验证。
- [x] 补充或调整测试，至少覆盖详情页 `startAt` 下发和忽略 `startAt` 后 seek 兜底。
- [x] 运行验证命令并更新 PRD 验收项。

## Validation Commands

```bash
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_fullscreen_player_screen_test.dart
flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart lib/tv_app/screens/tv_fullscreen_player_screen.dart lib/tv_app/services/tv_play_record_service.dart
```

## Device Log Commands

```bash
adb devices
adb logcat -c
adb logcat | rg "TV 详情页|续播|startAt|seek|PlayRecord|updateDataSource|VideoPlayer"
```

当前 adb 设备：

```text
emulator-5554 device product:p3sxxx model:SM_G998B device:p3s
```

投影仪暂未连接，真机对比日志待设备接入后继续采集。

## Risk Notes

- 投影仪硬件较弱，不能只依赖一次首帧前 seek；如果日志显示播放器晚于 `updateDataSource` 才 ready，需要验证延迟 seek 或 ready callback。
- 不要用模拟器现象覆盖投影仪结论，必须同包同账号同记录对比。
- 若加入临时高频日志，提交前需要收敛为必要的诊断日志或移除。
