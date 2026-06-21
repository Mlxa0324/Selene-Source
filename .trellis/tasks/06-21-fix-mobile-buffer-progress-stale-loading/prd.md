# 修复手机端缓存进度残留与误转圈

## Goal

修复手机端在线播放时两个相邻问题：

- 当前播放位置已经显示在缓存进度段内，但播放器偶发自己转圈加载 1-2 秒。
- 切到下一集或继续切集后，上一集的预加载缓存段残留在进度条上，不会及时清掉。

目标是让手机端预加载进度条只展示当前媒体身份下可信的缓存段，并让短暂 WebView `waiting` 不再在已有真实缓冲覆盖当前位置时误触发转圈。

## Confirmed Facts

- WebView HTML 从 `player.buffered` 上报 `cached_ranges`，`FRAG_LOADED` 后也会主动同步缓存段。
- `VideoPlayerWidget` 当前把缓存段持久累计在 `_persistedCachedRangesByMedia` 中，进度条读取 `_currentPreloadProgressRanges`。
- `_recordCachedRanges()` 当前忽略空列表，导致切源时 WebView 发出的空缓存事件无法清掉持久进度段。
- 手机端播放页 `VideoPlayerWidget` 构建时 `url` 通常为 `null`，真实切集通过 `VideoPlayerWidgetController.updateDataSource()` 触发，可能早于子 widget 收到新的 `currentEpisodeIndex` rebuild。
- loading 遮罩当前直接使用 `_isBuffering || _isLoadingVideo`，没有结合当前真实 `adapter.state.cachedRanges` 判断当前位置是否仍可播放。

## Requirements

- 切集、换源、controller 手动更新数据源时，当前显示用的预加载进度必须先切换到正确媒体身份，并清空新媒体的旧显示段。
- WebView 切源发出的空 `cached_ranges` 必须能清掉当前媒体身份的显示缓存，不再被 `_recordCachedRanges()` 吞掉。
- 预加载进度条可以继续累计当前媒体已确认过的缓存段，但不能把上一集的持久段带到下一集。
- 播放器内部 loading 遮罩必须区分真实加载和瞬时 `waiting`：
  - 如果当前播放位置仍在 adapter 实时 `cachedRanges` 中，短暂 `buffering=true` 不应立刻显示中心转圈。
  - 首次加载、切源加载、真实当前位置未被实时缓存覆盖时，仍应显示 loading。
- 修复仅限 Flutter 手机/桌面共享播放器缓存进度和 loading 判定，不改 TV Kotlin 代码，不改 HLS 主 buffer 级别配置。

## Acceptance Criteria

- [ ] 单测覆盖：手动 `updateDataSource()` 时可以使用调用方传入的媒体身份生成缓存 key，避免旧集数时序污染。
- [ ] 单测覆盖：当前媒体身份收到空缓存段时，持久预加载进度会被清空。
- [ ] 单测覆盖：`buffering=true` 且当前位置在 adapter 实时缓存段内时，中心 loading 不显示；真实未缓存时仍显示。
- [ ] 现有 WebView preload、seek、移动端控制层测试继续通过。
- [ ] `flutter analyze` 覆盖本次修改文件通过。

## Out Of Scope

- 不调整预加载档位含义和 1/3/5 分钟 forward buffer 配置。
- 不改变播放记录、弹幕、投屏、TV 详情页逻辑。
- 不承诺规避所有真实网络卡顿；真实 buffer miss 时仍允许 loading。
