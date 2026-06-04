# 修复 Flutter TV 详情与全屏加载态误判

## Goal

修复 Flutter TV 详情页小播放器与全屏播放器在首次进入、换源/换集后的首播阶段，以及长按 seek 后等待阶段的“加载态误判”问题。

当前用户体感问题不是“没有转圈”，而是“转圈和真实出画面不同步”：

- 黑屏或画面明显卡住时，屏幕中间缺少足够明确的加载反馈。
- 有时已经开始播放，中心转圈却还停留在画面上。
- 用户希望在真正视频画面稳定可见之前，中心始终显示转圈和网速；只有当画面真正开始播放时才隐藏。
- 用户已明确确认：网速与转圈只在两类中心 loading 态出现
  - 首次进入详情页播放器或全屏播放器，正在等待真实画面出来
  - 长按 seek 松手后，正在等待画面恢复
  - 一旦恢复播放，网速和转圈都立即消失

本任务目标是在不回退现有 TV 遥控操作、详情页预览播放器、全屏控制层与续播链路的前提下，建立一套比当前 `isPlaying / progress / isLoading` 更精准的“真实出画面”判断，并把它同时用于详情页和全屏页。

## Confirmed Facts

- 详情页当前已经有预览加载态逻辑，位于 `lib/tv_app/screens/tv_video_detail_screen.dart`：
  - `_previewPlayerLoading`
  - `_previewPlaybackStarted`
  - `_previewProgressSignalReceived`
  - `_isPreviewPlaybackReadyForDisplay`
  - `_buildPreviewLoadingIndicator()`
- 详情页当前的加载 UI 只有中心 `CircularProgressIndicator`，测试 key 为 `tv-detail-preview-loading`，没有网速展示。
- 全屏页当前已经有加载态逻辑，位于 `lib/tv_app/screens/tv_fullscreen_player_screen.dart`：
  - `_isFullscreenPlaybackReadyForDisplay`
  - `_shouldShowPlaybackChrome`
  - `_shouldShowCenterPlayButton`
  - `_isPlaybackLoading`
- 全屏页已有测试覆盖“loading 时显示 spinner，不显示暂停按钮/底部进度条”，测试位于 `test/tv_app/tv_fullscreen_player_screen_test.dart`。
- 详情页已有测试覆盖“播放前显示 spinner、播放开始后隐藏 spinner、仅收到进度信号后也能隐藏 spinner”，测试位于 `test/tv_app/tv_video_detail_screen_test.dart`。
- 历史任务 `06-02-fix-flutter-tv-fullscreen-seek-and-low-memory-resume` 已经说明：
  - 全屏页给 `VideoPlayerWidget` 传的是 `showControls: false`
  - TV 壳层自己的暂停按钮和底部条由 `_shouldShowPlaybackChrome` 控制
  - 之前已经出现过“全屏时还能看到暂停或底部按钮”的相关问题
- 用户这次最新反馈说明：现有“转圈显示/隐藏”策略虽然已有实现，但效果仍不理想，说明当前条件仍会把“事件到了”和“真实出画面了”混为一谈。
- 详情页进入卡顿优化任务 `06-02-fix-flutter-tv-detail-entry-jank-webview-2gb` 正在进行中，但该任务重点是首播链路瘦身，不负责重做加载态视觉与退出条件；本任务应独立处理。
- 继续观看路径在 `TvVideoDetailScreen` 中额外引入了：
  - `_initialResumePlaybackPositionSnapshot`
  - `_pendingResumeSeekPosition`
  - `_retryPendingResumeSeekAfterProgress()`
  这意味着“继续观看”和“非继续观看”当前并没有完全走同一套 loading 时序。
- 详情页播放器区域在 loading 期间并不是简单叠加一层背景，而是通过 `IndexedStack(index: 1)` 把 `_buildSharedPlayer(detail)` 整体切换成 `tv-detail-preview-loading-mask` 占位层。
- 上述 `tv-detail-preview-loading-mask` 当前硬编码为 `Colors.black`，位置在 `lib/tv_app/screens/tv_video_detail_screen.dart`。
- 详情页相关注释已明确说明：这里之所以要切到占位层，是为了避免 `WebView / 原生视频视图` 的底层黑屏把 Flutter 的转圈盖住；这说明“加背景后圈消失”更可能是平台视图层级问题，而不是颜色本身导致。
- 用户已确认：非全屏详情页 loading 期间的占位底色改为页面原背景色；全屏 loading 期间仍保持黑底。
- 用户已确认：继续观看路径里，即使 `onPlay` / `onReady` 已到，只要续播补 seek 还没真正追平到目标位置，中心 loading 就继续显示，直到真实进度恢复/追平再消失。
- 用户已确认：如果各播放器 adapter 仍拿不到稳定可信的实时网速，这一版接受先退成仅显示 `加载中` 文案，不强行展示数字速率。

## Requirements

### R1: 详情页与全屏页都要提供明确的加载反馈

- 在详情页小播放器首次进入、切换线路/剧集后的黑屏等待阶段，需要在画面中间展示明显的加载中反馈。
- 在全屏播放器首次进入、长按 seek 松手后等待真实画面追平的阶段，也需要展示同类反馈。
- 加载反馈至少包含：
  - 中心转圈
  - 当前网速展示
- 网速与转圈只在“首次进入等待真实画面”与“长按 seek 松手后等待恢复”这两类 loading 态出现，不做常驻。

### R2: 加载反馈的退出条件必须对齐“真实出画面”

- 不能再用过于宽松的 `isPlaying=true`、`收到 progress`、`loading=false` 直接判定“可以隐藏转圈”。
- 必须建立更精准的“真实画面已恢复可见”判断，避免还在黑屏/卡帧时就提前隐藏。
- 同时也必须避免相反问题：一旦真实画面已经稳定显示，转圈和网速要立即消失，不能继续盖在画面上。
- 对继续观看路径同样生效：`onPlay` / `onReady` 不能单独作为隐藏条件，续播补 seek 未追平前仍视为 loading。

### R3: 详情页与全屏页的判断语义要尽量统一

- 不允许详情页一套规则、全屏页另一套完全不同且难以维护的规则。
- 不允许“继续观看”和“非继续观看”再额外分裂出两套中心 loading 可见性判断。
- 如果底层 `VideoPlayerWidget` / adapter 已经能提供通用信号，应优先抽成共享能力。
- 若平台差异导致无法完全共用，也要把“共同语义”和“分歧原因”写清楚。

### R4: 不回退现有 TV 播放控制层行为

- 全屏 loading 阶段仍不应错误显示普通暂停按钮、中心播放按钮或底部进度条。
- 详情页 loading 阶段仍要保持外层 TV 焦点导航可用，不因为中间转圈遮罩导致焦点被吃掉。
- 详情页 loading 阶段需要确保原生播放器视图不会重新压到 Flutter 转圈之上；如果需要背景遮罩，必须采用“替换播放器区域”的方式，而不是仅做视觉叠加。
- 非全屏详情页 loading 占位底色应与页面背景一致；全屏 loading 继续使用黑底。
- 长按 seek 松手后，如果视频仍未真正恢复，应该显示加载反馈；恢复后必须及时消失。

### R5: 保留并扩展可执行测试

- 现有详情页与全屏页关于 spinner 的 widget test 不能回退。
- 需要新增或更新测试，覆盖以下场景：
  - 黑屏/卡顿时显示转圈和网速
  - 已经开始播放但画面仍不可见时，转圈不应过早隐藏
  - 真实画面恢复后，转圈和网速立即隐藏
  - 全屏长按 seek 后的等待态与恢复态

### R6: 本任务聚焦 Flutter TV 端

- 仅处理 Flutter TV 的详情页小播放器、共享播放器、全屏播放器壳和可能涉及的通用播放器封装。
- 不处理 Kotlin TV 端。
- 不处理真机网络本身的波动，只处理 UI 判断和播放器状态同步逻辑。

## Acceptance Criteria

- [ ] 详情页小播放器在首次进入或切源/切集后的黑屏等待阶段，会展示中心转圈和网速。
- [ ] 全屏播放器在首次进入或长按 seek 松手后等待真实画面恢复阶段，会展示中心转圈和网速。
- [ ] 详情页与全屏页在真实视频画面已经恢复可见后，中心转圈和网速会立即消失，不再残留覆盖。
- [x] loading 期间不会误显示不该出现的暂停按钮、中心播放按钮或底部进度条。
- [x] 现有 `test/tv_app/tv_video_detail_screen_test.dart` 和 `test/tv_app/tv_fullscreen_player_screen_test.dart` 的相关回归测试通过。
- [ ] 新增或更新测试能覆盖“真实出画面前不隐藏、真实出画面后立即隐藏”的关键判断。

### 当前证据快照

- 第 1、2、3 条暂未完成：当前详情页与全屏页只有中心 spinner，仓库内尚未看到网速展示实现；“可隐藏 loading”的判断仍主要基于 `isPlaying / progress / duration / isLoading` 组合，尚未证明已经对齐“真实出画面”。
- 第 4 条已完成：详情页与全屏页都已有 loading 态不显示暂停按钮、中心播放按钮或底部进度条的实现与测试。
- 第 5 条已完成：`flutter test test/tv_app/tv_video_detail_screen_test.dart` 与 `flutter test test/tv_app/tv_fullscreen_player_screen_test.dart` 已于 2026-06-02 在当前工作区通过。
- 第 6 条暂未完成：现有测试覆盖的是“播放开始后隐藏 spinner”与“收到进度/seek 完成后隐藏 spinner”，还没有证据证明已经覆盖“真实出画面前不隐藏、真实出画面后立即隐藏”的更严格语义。

## Out of Scope

- Kotlin TV 端修复
- 搜索页、首页、设置页的无关 UI 调整
- 详情页首播链路瘦身、续播记录读取、补源时序等与加载态视觉无关的独立性能问题
- 外部真机网络测速、路由器或投影仪固件问题本身

## Open Questions

- 暂无阻塞性产品问题，当前规划已具备进入实现前审阅条件。

## Notes

- 当前任务属于复杂任务，开始实现前需要补 `design.md` 和 `implement.md`。
