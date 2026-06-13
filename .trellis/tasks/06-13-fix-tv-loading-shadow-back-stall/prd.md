# 修复TV端加载动画阴影与返回卡顿

## Goal

修复三个 TV 端体验问题：加载转圈视觉效果、继续播放源选择、ESC 返回卡顿。

## 已确认事实（来自代码库分析）

### 问题1: 加载转圈双圈阴影
- 详情页 `_buildPreviewLoadingOverlay()` 和全屏 `_buildFullscreenLoadingOverlay()` 都用两个重叠 `CircularProgressIndicator`
- 下层 spinner 偏移 1px 作为"阴影"，效果不自然
- 用户期望：单圈 + 右下方向淡淡投影（光源左上方）

### 问题2: 继续播放源选择
- `PlayRecord` 存储 `source`+`id`+`index`，不存 URL
- 详情页进入后启动精确源搜索（`_loadInitialSources`），后台还有 SSE 标题补源（`_loadMoreSources`）
- 当前可能在续播源命中前就播放了其他源，后来再纠正
- `_hasPendingInitialPlaybackAfterResumeLoad` 门闩：续播记录未返回时阻塞播放
- 用户期望：等待流式搜索命中续播记录中的源后才起播，ESC 可打断

### 问题3: ESC 返回卡顿
- **根因**: `_handleDetailBackPressed` await `_saveProgress(force: true)` 后才 `Navigator.pop`
- `TvBackHandler._backDispatchScheduled` 锁在保存期间不释放
- `_isExitingDetail` 在保存之后才设置
- 全屏播放器无此问题（`unawaited` 保存，立即退出）

## Requirements

### R1: 加载转圈投影改为单圈+柔和阴影
- 移除双 `CircularProgressIndicator` 重叠
- 改为单圈，用 `BoxShadow`（右下偏移，低透明度黑色）实现光源左上方照射的投影效果
- 文字"加载中..."下方同款阴影
- 同时修改详情页和全屏播放器的加载 overlay

### R2: 继续播放等待命中续播源
- 从继续播放进入详情页时，不立即用首个匹配源起播
- 等待流式搜索（精确源 + 标题补源）命中续播记录中的 `source + id`
- 命中后才触发首播，此前保持 loading 状态
- ESC 在等待期间可随时打断整个过程

### R3: ESC 高优先级打断
- 详情页返回时：先设 `_isExitingDetail = true`，立即停止所有异步任务
- `_saveProgress` 改为 `unawaited` 后台保存
- 立即 `Navigator.pop`，不等保存完成
- 与全屏播放器退出逻辑（`_handleExitWithSave`）保持一致

## Acceptance Criteria

- [ ] 加载转圈为单圈 + 右下柔和投影，无重影
- [ ] 从继续播放进入详情页，始终播放续播记录中的源（不先闪其他源）
- [ ] 等待续播源期间按 ESC，流畅返回上一页
- [ ] 详情页按 ESC 返回无卡顿（<200ms 可感知）
- [ ] 详情页 ESC 返回后播放进度已后台保存（正常退出场景）
- [ ] 全屏播放器 ESC 返回逻辑不受影响

## Out of Scope

- 不修改 `PlayRecord` 数据结构（不新增 URL 存储）
- 不修改全屏播放器的退出逻辑（已正确）
