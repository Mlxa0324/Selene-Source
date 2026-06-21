# 修复手机端缓存进度残留与误转圈 - Design

## Root Cause

### 缓存进度残留

`VideoPlayerWidget` 为了让预加载进度条在 WebView 切源/重建后保持可见，使用 `_persistedCachedRangesByMedia` 累计缓存段。当前媒体 key 由 `source / id / episodeIndex / url` 拼出，但手机播放页真实切集通过 controller `updateDataSource(finalUrl)` 完成，子 widget 的 `currentEpisodeIndex` rebuild 可能晚于 controller 调用。

同时 WebView 切源会发空 `cached_ranges`，但 `_recordCachedRanges()` 直接忽略空列表。因此一旦 active key 没切准，或者新源还没上报非空段，上一集持久缓存段会继续显示。

### 已缓存位置短暂误转圈

中心 loading 由 `_isBuffering || _isLoadingVideo` 直接驱动。WebView HTML5 video 遇到分片边界、readyState 瞬时回落或 HLS 小洞时会发 `waiting`，Flutter 立即显示转圈。缓存条展示的是持久累计段，不代表当前真实 `adapter.state.cachedRanges` 仍覆盖当前位置。

## Data Flow

1. `PlayerScreen.startPlay(index, playTime)` 更新外层集数，再调用 `updateVideoUrl()`。
2. `updateVideoUrl()` 调用 `VideoPlayerWidgetController.updateDataSource(finalUrl)`。
3. controller 将数据源更新转交给 `_VideoPlayerWidgetState._updateDataSource()`。
4. `_updateDataSource()` 需要在切源前用明确媒体身份切换 key，并清空当前显示缓存。
5. WebView adapter 切源后发空 `cached_ranges`，Flutter 允许空段清空当前 key。
6. 后续 `FRAG_LOADED/progress/timeupdate` 上报真实非空段，再累积到当前 key。
7. loading 遮罩显示时，使用 adapter 实时缓存段判断当前 position 是否被真实覆盖。

## Contracts

- `VideoPlayerWidgetController.updateDataSource()` 增加可选媒体身份参数：`source / id / episodeIndex / url`。
- `VideoPlayerWidget` 内部新增纯函数，集中判断：
  - 当前缓存 key 构建。
  - 空缓存段是否应清空当前 key。
  - 当前 buffering 是否应被实时缓存段抑制。
- `preloadProgressRanges` 继续传给控制层用于展示进度条；loading 判定必须读取 adapter 实时 `state.cachedRanges`，不能使用持久累计列表。

## Compatibility

- 参数全部可选，现有 controller 调用不强制修改；手机播放页改为传入明确媒体身份。
- 本地播放、直播、TV/桌面控制层保持原逻辑。
- 真实 `_isLoadingVideo` 初始加载不被缓存段抑制，避免首帧黑屏无反馈。

## Risks

- 如果过度抑制 buffering，真实卡顿可能不显示 loading。规避：只在当前位置命中 adapter 实时缓存段时抑制 `_isBuffering` 的视觉显示，不改变 adapter 自身状态。
- 如果清空过于激进，进度条可能在切集瞬间空白。预期行为：新集开始时应该空白，收到新源真实缓存段后再显示。
