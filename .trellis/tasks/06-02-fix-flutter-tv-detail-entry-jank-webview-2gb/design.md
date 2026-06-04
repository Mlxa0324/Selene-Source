# Technical Design

## Scope

本任务只修 Flutter TV 详情页“进入瞬间”的早期卡顿，不扩展到首页、搜索页、全屏播放器的独立优化。

落点限定在：

1. `lib/tv_app/screens/tv_video_detail_screen.dart`
2. `lib/widgets/video_player_widget.dart`
3. 必要时少量补充 `test/tv_app/` 或现有播放器测试

## Root-Cause Translation

上一轮分析已经证明：当前卡顿不是单点 bug，而是下面三段叠加：

1. **首播门闩过宽**
   - `_loadResumeRecordThenStartDetailLoading()` 读完续播记录前，详情页不会真正开始源加载
2. **空播放器壳过早挂载**
   - `VideoPlayerWidget(url: null)` 进入树后仍跑初始化、PiP 配置和控制器准备
3. **首个可播源命中后立即进入重 WebView 初始化**
   - `updateDataSource(startAt)` 命中 `_adapter == null` 时，才真正创建 `WebViewPlayerAdapter`
   - 这一步与页面早期多次状态回流发生在同一小窗口里

本任务不试图一次性消除全部成本，而是把最不必要的等待和最早窗口里的额外工作先挪开。

## Proposed Fixes

### 1. 拆开“续播记录读取”和“详情源加载”

当前：

- `initState()`
- `_loadResumeRecordThenStartDetailLoading()`
- `_startDetailLoading()`

优化后：

- `initState()` 里同时启动
  - 续播记录异步读取
  - 详情源加载
- 续播记录只负责更新 `_resumeVideoInfo` / 首次续播参数
- 真正需要 `startAt` 的时点放在首次 `_playCurrentEpisode()` 前对齐，而不是在详情源加载前整段等待

### 2. 让 `VideoPlayerWidget` 支持“空 URL 轻量占位态”

目标：

- `url == null` 时不提前做重初始化
- 控制器仍可创建并回传给详情页，以保持外部交互接口不变

具体思路：

- `initState()` 保留控制器创建回调
- 当 `_currentUrl == null` 时跳过 `_initializePlayer()`
- PiP 相关初始化也不在空 URL 预览态执行
- 等第一次 `updateDataSource(url, startAt)` 进来时，再真正执行 `_initializePlayer(startAt: ...)`

这样可以把“详情页空壳进入树”和“WebView 重初始化”解耦开。

### 3. 收紧早期状态波动

这轮不大改状态机，只做最小收敛：

- 尽量避免无意义的首屏 loading 切换
- 保持推荐区继续延后，不引入新抢占
- 不让次要配置读取影响精确源起播时机

如果实现过程中发现某些状态波动来自同一个点位，可在局部顺手合并，但不扩大为全面重构。

## Behavior Contracts

### Contract A: 续播语义不回退

- 即使源加载早于续播记录完成启动，第一次真正起播时仍必须拿到最终续播集数和 `startAt`
- 若续播记录晚于首个可播源到达，也不能导致直接从 0 秒起播

### Contract B: 外部控制器接口不变

- 详情页继续通过 `onControllerCreated` 拿到 `VideoPlayerWidgetController`
- 不要求业务层改造控制器调用方式

### Contract C: TV 详情页播放器壳仍可见

- 优化后不是把播放器区域隐藏掉，而是允许它在无 URL 时展示轻量占位态
- 页面布局、焦点与全屏入口不应因为延迟初始化而整体失位

## Compatibility Notes

- `VideoPlayerWidget` 是跨多端组件，改动时要避免影响手机 / 桌面已有逻辑
- 本任务实际变更应尽量限定在“`url == null` 时的行为”和“TV 详情首播时机”
- 若 PiP 初始化被延后，需要确认：
  - TV 详情页本身 `enablePip: false` 不受影响
  - 其它显式启用 PiP 的调用场景，在有真实 URL 后仍按原先时机完成初始化

## Tests Needed

1. `tv_video_detail_screen_test.dart`
   - 覆盖“详情页不会等待续播读取完成才启动源加载”
   - 覆盖“首次起播仍能承接最终续播位置”
2. `video_player_widget` 相关测试
   - 覆盖“`url == null` 时不执行重播放器初始化”
   - 覆盖“首次 `updateDataSource` 仍能正常触发初始化和 ready”

## Rollback Plan

- 如果延迟初始化导致控制器生命周期异常，优先回退 `VideoPlayerWidget` 的懒初始化逻辑
- 如果续播链路拆开后导致首播从 0 秒起播，优先回退“源加载与续播记录并行”这一步，保留其它轻量优化
