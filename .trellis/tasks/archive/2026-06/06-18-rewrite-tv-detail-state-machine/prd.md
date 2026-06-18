# 重做 Kotlin TV 详情状态机和数据链路

## Goal

作为“重做 Kotlin TV 详情页对齐 Flutter TV”的第一阶段，先重建详情页状态机和数据链路，让进入详情页后的精确源、标题补源、首个可播源起播、续播目标匹配、无源完成空态和播放请求生成稳定下来。

本阶段只要求数据和状态语义对齐 Flutter TV 主链路，不要求完成最终 UI 像素级和焦点图重写；后续 UI/焦点和播放记录/退出收尾由兄弟子任务继续。

## Parent Task

- `.trellis/tasks/06-18-rewrite-kotlin-tv-detail-from-flutter`

## Confirmed Facts

- Flutter TV 详情页生产加载拆成精确源、后台标题补源、推荐延迟三段。
- Flutter TV 首个可播源到达后立即设置当前源、结束首屏转圈并触发内嵌播放器起播。
- Flutter TV 精确源失败只标记精确源完成，继续等待标题补源；标题补源失败但已有源时保持播放。
- Flutter TV 继续观看会重新读取最新播放记录，锁定 `source + id` 续播目标；目标未命中前不自动起播非目标源，搜索全部完成后才回退。
- Kotlin 当前 `TvDetailViewModel.load(videoId)` 是顺序流程，先等 `loadInitialDetail` 成功，再读续播/收藏，再补源；无法表达 Flutter TV 的增量首播、精确/补源完成状态和续播目标等待。
- Kotlin 当前 `TvDetailRepository` 已有精确详情、标题补源、更多源去重能力，可作为第一阶段数据基础继续扩展。
- Kotlin route 当前只稳定传递 `source::id::title`，已有 `TvVideoCard.searchTitle/year/posterUrl` 字段，但详情 route 尚未完整携带。

## Requirements

- 重写 `TvDetailViewModel` 或抽出独立状态机，让详情加载不再依赖单个 `loadInitialDetail` 聚合结果。
- 支持精确源和标题补源两条加载链路：
  - 精确源具备 `source + id` 时请求详情。
  - 标题补源使用 `searchTitle/title`，当前 route 缺失 `searchTitle` 时用 title。
  - 两条链路都可失败，但失败不能直接清空已有可播状态。
- 支持增量合并源：
  - 首个可播源立即成为当前源并生成 `PlaybackRequest`。
  - 后续源继续去重追加。
  - 同 `source + id` 保留剧集数更多/更完整的结果。
- 支持显式加载完成状态：
  - `initialSourcesLoaded`
  - `moreSourcesLoaded`
  - `isInitialLoading`
  - `isMoreSourcesLoading`
  - `emptyPlaybackCompleted`
- 支持续播目标匹配：
  - 从最新继续观看记录中解析目标 `source + id`、集数和秒数。
  - 有续播目标时，非目标源不自动首播。
  - 精确源和标题补源都结束仍未命中时，回退最佳可用源。
  - 无续播记录时，任意首个可播源立即起播。
- 生成播放请求：
  - 当前源、当前集、URL 有效才生成 `PlaybackRequest`。
  - `startPositionMs` 使用续播秒数。
  - 切集和切源能重新生成请求。
- 错误和空态：
  - 精确失败 + 补源失败 + 无源时，状态展示“搜索已完成，未找到可播放信息”语义。
  - 推荐、收藏、偏好失败不影响本阶段首播状态。
- 保持 UI 回调兼容：
  - `TvDetailRoute` 现有参数尽量不破坏。
  - `TvAppContainer.createDetailViewModel()` 改成注入新状态机所需 loader。

## Acceptance Criteria

- [ ] 单测覆盖：精确源先返回可播源时立即生成播放请求，标题补源后续追加。
- [ ] 单测覆盖：标题补源先返回可播源时立即生成播放请求，精确源后续追加。
- [ ] 单测覆盖：精确源失败后继续等待标题补源并可播放。
- [ ] 单测覆盖：标题补源失败但精确源已可播时保持播放状态。
- [ ] 单测覆盖：两条链路都完成且无源时设置完成空态。
- [ ] 单测覆盖：重复 `source + id` 源使用更完整剧集覆盖。
- [ ] 单测覆盖：无续播记录时首个可播源立即起播。
- [ ] 单测覆盖：有续播目标时等待目标源命中后起播。
- [ ] 单测覆盖：有续播目标但搜索完成未命中时回退最佳源。
- [ ] 单测覆盖：切集、切源后 `PlaybackRequest` 更新正确。
- [ ] `:feature-tv-detail:testDebugUnitTest` 通过。
- [ ] `:core-data:testDebugUnitTest` 相关测试通过。
- [ ] `:app-tv:testDebugUnitTest` 相关容器测试通过。
- [ ] 对本阶段变更文件执行 `git diff --check`。

## Out Of Scope

- 不重写最终 UI 组件和焦点图，由 `06-18-rewrite-tv-detail-ui-focus` 负责。
- 不完善播放记录保存、换源清理旧记录、返回高优先级退出，由 `06-18-finish-tv-detail-playback-record-exit` 负责。
- 不重做全屏播放器底部菜单。

## Notes

- 本阶段完成后，旧 UI 仍可能存在焦点问题，但状态和数据链路应已对齐 Flutter TV 主链路。
