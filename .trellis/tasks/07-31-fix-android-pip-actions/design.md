# Flutter Android PIP Controls Technical Design

## Scope and Boundaries

实现边界固定在 Flutter Android APK：

- Dart：`lib/widgets/video_player_widget.dart`。
- Android 宿主：`android/app/src/main/kotlin/com/example/selene/MainActivity.kt`、`PipActionReceiver.kt`，以及必要的 Flutter Android 测试/构建配置。
- 外部依赖：只读检查 `pip:0.0.3` 的调用行为，不直接修改 pub 缓存源码。

`re-android/` 与 `kotlin-tv/` 不属于本任务的实现目标，即使它们也存在播放器或 PIP 代码。

## Current Data Flow

```text
VideoPlayerWidget
  ├─ _setupPip() -> pip:0.0.3 -> Activity.setPictureInPictureParams()
  └─ _pushPipActionsState() -> pip_controls MethodChannel
                                  -> MainActivity.updatePipActions()
                                  -> RemoteAction + PendingIntent
                                  -> PipActionReceiver
                                  -> MainActivity static Handler
                                  -> pip_controls.onPipAction
                                  -> VideoPlayerWidget._handlePipAction()
```

当前存在两个系统参数写入者：第三方 PIP 插件负责比例/自动进入/来源区域，本项目宿主负责动作列表。Android 的 PIP 参数是同一组 Activity 状态，不能假设两个独立 `setPictureInPictureParams()` 调用会自动合并。

## Root-Cause Findings

1. **已确认：动作列表被插件 start/setup 覆盖。** `pip:0.0.3` 的 `PipController.start()` 和 `setup()` 使用不含本项目 `RemoteAction` 的 Builder 写入系统参数；`start()` 的进入参数会覆盖进入前刚写入的动作列表。
2. **已确认：Dart 异步写入竞态。** `_setupPip()` 与 `_pushPipActionsState()` 原先多处 `unawaited` 并行触发，进入 PIP、播放状态变化和换集时可能交错写入。
3. **已治理：生命周期丢事件。** Receiver、宿主 Handler 和 Flutter 通道都增加了不可用时的明确丢弃日志和空值保护；真实设备日志仍需补充确认具体设备上的事件路径。
4. **已治理：动作状态过期。** Native 不再乐观翻转播放状态，Flutter Adapter 状态成为最终来源；所有 Dart PIP 写入通过串行队列完成。

以上是待验证假设，不在未验证前把某一项写成确定根因。

## Design Decisions

### 1. Separate ownership but serialize the writes

- PIP 插件继续负责其公开 API 能力：支持检查、比例、自动进入、来源区域和真正进入 PIP。
- Flutter Android 宿主继续负责自定义 `RemoteAction` 的完整集合。
- Dart 侧把“插件 setup 完成后同步当前动作集合”收敛到一个可串行的协调入口；所有初始化、换集、播放状态变化和进入 PIP 的路径都经过该入口。
- 同一个播放器实例的旧状态不能在新状态之后写入。若需要保留异步调用，则使用顺序链/版本号丢弃过期写入，禁止继续增加互相独立的 `unawaited` PIP 写操作。

### 2. Keep one action contract across native and Dart

动作契约固定为：

```text
previous          -> Flutter onPreviousEpisode
toggle_play_pause -> Flutter pause/play
next              -> Flutter onNextEpisode
```

Native 只做系统动作识别和通道转发，不自行切集或控制播放器。播放/暂停的显示状态以 Flutter 播放器实际状态为最终来源；Native 的即时刷新不能覆盖 Flutter 随后确认的真实状态。

### 3. Make lifecycle failure explicit

- Receiver 先记录收到的 action，再调用宿主分发。
- 宿主分发前检查当前 Handler/MethodChannel 是否可用；不可用时只记录丢弃原因。
- Flutter 绑定通道时确保当前播放器拥有处理权，销毁时解除自身绑定，避免旧播放器处理新播放器动作。
- Handler 不应持有已销毁播放器的强引用；如果现有静态桥接必须保留，则至少使用明确的活动生命周期和清理顺序。

### 4. Do not hide plugin replacement behind a cache

不能只通过重复调用 `updatePipActions` 掩盖写入竞态。实现必须能证明：最后一次影响 PIP 参数的 setup/write 完成后，系统动作集合仍然是当前快照。若外部插件调用无法稳定排序，再评估把完整 PIP 参数写入能力收敛到 Flutter Android 宿主；不得编辑 pub 缓存源码。

## Diagnostics Contract

日志 Tag 继续使用 `PipControls` 或统一的 `[PiP控制]` 前缀，日志事件至少包括：

| Stage | 必须包含 | 禁止包含 |
|---|---|---|
| setup/write | reason、action 数量、上一集/下一集存在性、播放状态 | 播放 URL、Cookie |
| receiver | action 名称 | 用户信息 |
| native dispatch | action、Handler 是否存在、Channel 是否可用 | 通道 payload 全量 |
| Flutter receive | action、当前集索引 | URL 查询参数 |
| player callback | action、回调是否执行 | 敏感数据 |

通过同一次点击的 stage 日志判定断点，而不是只看最终“按钮无效”。

## Compatibility and Rollback

- Android O 以下继续跳过自定义 PIP action 写入，保持现有能力判断。
- Android S 及以上的自动进入配置必须继续保留。
- 失败时优先回滚到“串行 setup + action 同步”这一小范围改动，不回滚播放器内核、换源或集数业务。
- 不引入持久化、网络协议或数据库变更。

### Implementation Note

`pip:0.0.3` 不可修改，因此 Flutter Android 宿主在 `onPictureInPictureModeChanged(true)` 中再次写入当前 `RemoteAction` 集合，作为插件 `start()` 参数覆盖动作后的恢复点。该恢复只处理系统动作，不把集数切换或播放控制迁移到 Kotlin。

## Test Design

- Dart：覆盖动作可见性、旧状态被新状态覆盖、播放/暂停回调以及上一集/下一集边界；MethodChannel 用测试 handler 验证收到的 action。
- Android 宿主：覆盖 `RemoteAction` 的 action/title/`PendingIntent` 映射、Receiver 到 Handler 的分发，以及 Handler 缺失时不崩溃。
- 集成/手工：在真实支持 PIP 的 Android 设备上验证进入 PIP、点击三个动作、换集后再次点击、播放状态变化后再次点击和退出/重进 PIP。
- 不把 `pip:0.0.3` pub 缓存源码作为可提交测试目标；若只能通过设备验证系统动作，必须把设备、Android API、APK 变体和日志结论记录到任务结果。
