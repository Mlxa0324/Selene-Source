# 修复 Flutter Android PIP 后上一集下一集与播放暂停按钮失效

## Goal

恢复 Flutter Android APK 进入系统画中画（PIP）后，上一集、播放/暂停、下一集三个系统操作的可用性。点击操作必须经过 Android 宿主桥接回到当前 Flutter 播放器，并正确更新后续 PIP 控件状态。

本任务只处理 Flutter Android 工程：Dart 播放器逻辑和 `android/app` 宿主桥接。不得把修复扩展到 `re-android`、`kotlin-tv`、iOS 或 pub 缓存中的第三方插件源码。

## Confirmed Facts

- Flutter 播放器位于 `lib/widgets/video_player_widget.dart`，通过 `pip: 0.0.3` 配置 PIP，同时使用 `org.moontechlab.selene/pip_controls` MethodChannel 维护自定义操作。
- `VideoPlayerWidget` 在初始化、首个 URL 接入、集数变化、播放状态变化以及主动进入 PIP 时多次异步调用 `_setupPip()`；动作状态则由 `_pushPipActionsState()` 另一路异步写入宿主。
- `android/app/src/main/kotlin/com/example/selene/MainActivity.kt` 收到 `updatePipActions` 后构造三个 `RemoteAction`，并调用 `setPictureInPictureParams()`。
- `android/app/src/main/kotlin/com/example/selene/PipActionReceiver.kt` 接收系统 `PendingIntent`，再通过 `MainActivity` 的静态 Handler 转发到 Flutter MethodChannel。
- 本地 pub 缓存中的 `pip:0.0.3` 原生 `PipController.setup()` 也会调用 `Activity.setPictureInPictureParams()`，但其参数没有本项目的自定义 `RemoteAction`。两个调用方存在覆盖动作列表的风险。
- PIP 动作 Handler 在 `MainActivity.onDestroy()` 中清理；Receiver、宿主 Activity 和 Flutter 播放器之间存在生命周期窗口，当前日志尚未证明动作到底丢在系统参数、Receiver、宿主分发还是 Flutter 回调阶段。

## Implementation Findings

- 已通过源码和 pub 缓存只读核对确认：`pip:0.0.3` 的 `PipController.start()` 使用只包含插件参数的 `PictureInPictureParams.Builder` 调用 `enterPictureInPictureMode()`，会覆盖宿主此前写入的 `RemoteAction` 列表。
- Flutter 播放器原先在 setup、播放状态、换集和进入 PIP 路径中并行写入插件参数与动作状态；后完成的插件 setup 可能再次清空动作集合。
- Flutter Android 宿主原先在播放/暂停动作到达时先乐观翻转 `pipIsPlaying`，可能与 Flutter 播放器实际状态回写发生竞态。
- 当前修复采用 Flutter 侧串行同步、进入 PIP 后宿主恢复动作、Flutter 状态作为播放状态唯一来源三部分收敛；未修改第三方 pub 缓存。

## Requirements

- 仅修复 Flutter Android APK 的 PIP 链路，不修改原生 TV 重构工程。
- 保留 PIP 的比例、自动进入、来源区域和已有进入/退出行为。
- 有上一集时展示并执行上一集；有下一集时展示并执行下一集；播放/暂停操作始终存在并与真实播放状态一致。
- 每次 PIP 参数更新只能产生最终一致的动作集合，不能被第三方插件的后续 setup 调用清空或覆盖。
- 系统动作必须最多转发一次到当前 Flutter 播放器；播放器销毁、换集或 MethodChannel 尚未就绪时不得崩溃。
- 播放/暂停、换集完成后重新同步动作状态，下一次点击不能使用旧集数或旧播放状态。
- 增加分阶段、低频诊断日志，至少能区分：PIP 参数写入、Receiver 收到、宿主分发、Flutter 收到、播放器回调执行和动作被丢弃；不得记录 URL 查询参数、Cookie 或用户隐私。

## Acceptance Criteria

- [ ] Flutter Android APK 在支持 PIP 的 Android 设备上进入 PIP 后，播放/暂停、上一集、下一集动作按当前集数条件出现。
- [ ] 点击播放/暂停后实际播放器状态改变，PIP 图标/标题在下一次同步后反映新状态。
- [ ] 点击上一集或下一集只触发一次对应 Flutter 回调，并切换到正确集数；首集隐藏上一集，末集隐藏下一集。
- [ ] 播放状态变化、换集、重复进入 PIP 和 PIP 重试后，三个动作不会消失或恢复为旧状态。
- [ ] Receiver 收到的动作能够稳定到达 Flutter；Activity 销毁或通道未就绪时动作有明确丢弃日志且不崩溃。
- [ ] Flutter 相关测试、Android Flutter 宿主构建和 `git diff --check` 通过；未引入 `re-android` 或第三方 pub 缓存修改。
- [ ] 在真实 Android PIP 系统界面完成至少一轮手工回归，不能只依赖 Dart 单元测试。

> 当前环境没有可连接的 Android 设备，且 ADB 守护进程无法启动；源码测试、Flutter 分析和 Android Debug APK 构建已完成，系统界面手工回归待设备可用后执行。

## Out of Scope

- 不修改 `re-android/`、`kotlin-tv/` 或其它原生 TV 播放器的 PIP 行为。
- 不修改 iOS PIP 行为。
- 不直接编辑 `/Users/lx/.pub-cache/hosted/pub.dev/pip-0.0.3`；如必须替换插件，另行提出依赖治理任务。
- 不重做 PIP UI，不增加快进、字幕、弹幕等新系统动作。

## Implementation Gate

用户已确认进入实现阶段，任务已切换为 `in_progress`。实现前先完成代码级调用时序与生命周期核对；设备日志和系统界面回归作为实现后的验证项。若设备不可用，必须明确记录未完成的真机验证，不得用 Dart 测试替代系统 PIP 证据。
