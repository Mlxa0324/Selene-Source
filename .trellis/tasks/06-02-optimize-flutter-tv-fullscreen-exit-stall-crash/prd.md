# 优化 Flutter TV 全屏退出卡顿与闪退

## Goal

优化 Flutter TV 端详情页预览播放器与全屏播放器的 loading 状态体验，重点解决四类问题：

1. 有时会在全屏播放器页面卡住几秒才返回详情页
2. 小概率会在退出全屏过程中闪退
3. 详情页播放器黑底等待首帧时没有转圈和网速提示
4. 全屏播放器长按进度松手后，中心转圈不能在播放恢复后消失

本任务目标是在不回退现有 TV 全屏返回、共享播放器复用、播放进度保存和焦点恢复行为的前提下，收紧全屏退出链路中的重操作与时序竞态，让退出尽量即时，并降低偶发崩溃风险。
同时修正详情页和全屏播放器 loading 的可见条件与清理信号，避免黑底无反馈或 seek 后转圈残留。

## Confirmed Facts

- `TvFullscreenPlayerScreen` 当前按 `ESC` / 返回键会走 `_handleBackKey()`，再进入 `_handleExitWithSave()`。
- `_handleExitWithSave()` 当前会先 `await _saveProgress(force: true, scene: '全屏返回')`，等保存完成后才继续：
  - 调 `widget.onExitRequested`
  - 或 `Navigator.of(context).maybePop()`
- 也就是说，当前退出链路本身就是“先同步等待一次进度保存，再关闭全屏”。
- `TvFullscreenPlayerScreen.dispose()` 中还会再执行一次：
  - `unawaited(_saveProgress(force: true, scene: '全屏页销毁'))`
- `TvFullscreenPlayerScreen._handlePopInvoked()` 在系统返回已完成时也会再补一次：
  - `unawaited(_saveProgress(force: true, scene: '全屏系统返回'))`
- 详情页共享全屏 overlay 路径会传：
  - `onExitRequested: _closeFullscreenOverlay`
  - `reuseExistingPlayer: widget.fullscreenPlayerBuilder == null`
- 也就是说，从详情页打开的共享全屏 overlay，在退出时不仅要处理全屏页自己的退出逻辑，还要回到详情页并恢复共享播放器与焦点。
- 仓库已有相关回归测试：
  - `escape closes shared fullscreen overlay without popping detail`
  - `closing shared fullscreen overlay returns detail to top player focus`
  - `detail fullscreen overlay reuses preview player controller`
- 当前这些测试主要验证“能退回去”和“焦点对不对”，并没有覆盖：
  - 退出是否被同步保存阻塞
  - 退出路径是否出现重复保存/重复关闭/已销毁对象回调
  - 退出期间是否存在小概率竞态崩溃窗口
- 当前详情页小播放器关闭了 `VideoPlayerWidget` 内部 loading：
  - `showLoadingIndicator: false`
  - 因此详情页自己的 preview overlay 必须承担转圈和网速提示
- 当前全屏长按 seek 松手会调用 `_markFullscreenPlayerLoading()`，但复用详情页播放器时，全屏页不一定能稳定收到自己的进度监听回调，容易导致 loading 无清理信号。
- 现有部分测试还在断言详情页 / 全屏 loading overlay 不显示，需要按新验收改成“加载时显示、播放恢复后消失”。

## Requirements

### R1: 全屏退出不能被同步重操作明显阻塞

- 从全屏按 `ESC` / 返回键回详情页时，页面退出动作应尽快发生。
- 不能因为一次进度保存、记录清理、焦点恢复或播放器状态同步，让用户长时间卡在全屏页。
- 如果确实需要保留退出前保存进度能力，应尽量改成不阻塞可见退出动作，或收缩为更轻的同步路径。

### R2: 退出链路要避免重复保存与重复收尾

- 需要梳理并收紧：
  - `全屏返回`
  - `全屏页销毁`
  - `全屏系统返回`
  这几条保存路径的职责边界。
- 避免一次退出同时触发多轮重保存、重复清理或相互竞争的异步回调。

### R3: 共享播放器 overlay 退出要优先稳住时序

- 从详情页进入的共享全屏 overlay，退出时不能破坏详情页原有播放器实例。
- 退出全屏后，详情页需要稳定恢复焦点和交互，不应因异步任务晚到而卡住、闪屏或误触发销毁。
- 任何异步保存、回调或定时器都不能在页面已退出后继续写入失效状态。

### R4: 降低退出过程中的偶发闪退风险

- 需要重点排查“已销毁对象仍被异步回调访问”、“重复 dispose”、“退出中又触发 focus / save / player callback 回写”等竞态窗口。
- 即使暂时无法在本地稳定复现闪退，也要通过代码收口把明显的高风险路径先关掉。

### R5: 不回退现有用户可见行为

- `ESC` / 返回键仍然要能从全屏退回详情页
- 共享全屏 overlay 退出后仍回到详情页，而不是误 pop 整个详情页
- 详情页顶部播放器焦点恢复逻辑不能丢
- 播放进度保存能力不能整体被移除，只能优化时机和阻塞方式

### R6: 保留并扩展测试

- 现有这些测试不能回退：
  - `escape closes shared fullscreen overlay without popping detail`
  - `closing shared fullscreen overlay returns detail to top player focus`
  - `detail fullscreen overlay reuses preview player controller`
- 需要新增或更新测试，覆盖：
  - 退出时不再等待耗时保存才关页面
  - 单次退出不会触发多次重保存
  - 退出后异步回调不会再写入已失效页面状态

### R7: 详情页黑底首帧等待要有 loading 反馈

- 详情页播放器区域在已有播放源、播放器黑底等待首帧或缓冲时，必须显示转圈和网速提示。
- 详情页自己的 loading overlay 不能依赖 `VideoPlayerWidget` 内部转圈，因为共享播放器路径已关闭内部 loading。
- loading overlay 不得阻断 TV 焦点移动到线路、选集或全屏按钮。

### R8: 全屏 seek 后 loading 必须有确定清理信号

- 全屏长按进度松手后可以短暂显示 loading，表示播放器正在恢复 seek 后画面。
- 一旦复用播放器或独立播放器收到播放恢复、真实进度更新或控制器不再 loading 的确认，中心转圈必须消失。
- 不能让底部进度壳层、seek 中心提示或菜单状态反向阻止 loading 清理。

## Acceptance Criteria

- [ ] 从共享全屏 overlay 按 `ESC` / 返回键回详情页时，不再出现明显的“停在全屏页几秒才退回”的体验。
- [ ] 已明确并收紧全屏退出时的保存路径职责，避免同一轮退出触发多次重保存竞争。
- [ ] 共享播放器 overlay 退出后，详情页仍能稳定恢复焦点和交互。
- [ ] 针对退出链路的新增或更新测试可以覆盖“非阻塞退出”或“避免重复收尾”的关键行为。
- [ ] 不回退现有全屏退出、焦点恢复、共享播放器复用相关测试。
- [ ] 详情页播放器黑底等待首帧或缓冲时显示 loading 转圈和网速提示。
- [ ] 详情页真实播放恢复后，loading 转圈和网速提示可以自动消失。
- [ ] 全屏播放器长按进度松手后，loading 转圈可以在播放 / 进度恢复后自动消失。

## Out of Scope

- Kotlin TV 端问题
- 详情页整体首播性能优化
- 真机系统级崩溃日志采集本身（如后续需要，可另开专项任务）

## Open Questions

- 当前先按 Flutter TV 代码侧优化推进；若后续需要精确定位“小概率闪退”的最终根因，再决定是否补真机日志采集任务。

## Notes

- 这个问题同时涉及退出交互、播放器复用、异步保存和页面生命周期，按复杂任务处理更稳妥；开始实现前建议补 `design.md` 与 `implement.md`。
