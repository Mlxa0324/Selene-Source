# 换源面板按集数倒序排序

## 背景

`PlayerSourcesPanel`(`lib/widgets/player_sources_panel.dart`)是同一组件,被 3 个位置复用作为"换源"弹框:

- `lib/screens/player_screen.dart` — 非全屏播放页的换源弹框
- `lib/widgets/short_drama_controls.dart` — 短剧 / 竖屏 controls 的换源弹框
- mobile / pc player controls 触发的换源弹框

当前源列表按上层传入的原始顺序展示,没有按集数排序。剧集场景下,集数多(更完整)的源往往更可用,但用户在面板里需要手动滚动寻找。

## 目标

在 `PlayerSourcesPanel` 内部,按 `SearchResult.episodes.length` 对 `widget.sources` 倒序排序(稳定排序,原顺序作为次序兜底)。一次性覆盖上述 3 个调用位置,上层调用方不需要改动。

## 排序规则

- 主键:`source.episodes.length` 倒序(集数多在前)。
- 次序:同集数时保持上层传入的原始相对顺序(稳定排序)。
- 电影场景(所有源 `episodes.length <= 1`)排序结果与原顺序一致,不引入回归。
- 单集 vs 多集混合的列表也按集数绝对值排序(不区分单集 / 多集分组)。

## 范围

### 代码范围

- `lib/widgets/player_sources_panel.dart`
  - 在 `_PlayerSourcesPanelState` 内引入排序后的列表(例如 `List<SearchResult> _sortedSources`)。
  - `initState` 中根据初始 `widget.sources` 计算一次。
  - `didUpdateWidget` 中,当 `widget.sources` 引用变化时重新计算。
  - `build` 中所有遍历 `widget.sources` 的位置(`ListView.builder` 的 `itemCount` / `itemBuilder`、`_scrollToCurrentSource` 的 `indexWhere` 等)统一改用 `_sortedSources`。

### 测试范围

- 新增 widget / 单元测试覆盖排序行为,至少包含:
  - 多集源按集数倒序。
  - 同集数保持原顺序(稳定性)。
  - 全部单集(电影场景)顺序不变。

### 不在范围

- 不修改上层调用方(`player_screen.dart`、`short_drama_controls.dart`、mobile / pc controls)。
- 不修改 `SearchResult` 模型。
- 不改"换源"的其它逻辑(测速、当前源高亮、滚动到当前源等)。
- TV 端(`lib/tv_app/`)若有独立的换源 UI,本次不动。

## 验收标准

- [ ] `PlayerSourcesPanel` 在传入混合集数的源列表时,显示顺序为按 `episodes.length` 倒序。
- [ ] 同集数的源之间的相对顺序与传入顺序一致。
- [ ] 当所有源都是单集(`episodes.length <= 1`)时,显示顺序与传入顺序一致。
- [ ] "滚动到当前源"逻辑(`_scrollToCurrentSource`)仍然定位到正确位置(因为基于排序后的列表索引)。
- [ ] 当前源高亮、测速信息显示、刷新按钮等既有行为不受影响。
- [ ] 新增 / 相关 widget 测试通过,`flutter analyze` 无新增告警。

## 验证方法

- Widget 测试:构造一份混合集数的 mock `SearchResult` 列表,渲染 `PlayerSourcesPanel`,断言渲染顺序。
- 真机体感:在播放页(非全屏 / 全屏)打开换源面板,目视确认集数多的源排在前面。

## 非目标

- 不引入分组(如"多集 / 单集"分两段)。
- 不按测速、清晰度等其它维度排序。
- 不持久化用户对排序的偏好(本次只是固定按集数倒序)。

## 回滚策略

改动集中在 `lib/widgets/player_sources_panel.dart` 单文件,出问题直接 revert 即可。

## 备注

- 判定为轻量任务,PRD-only。
- 排序计算开销可忽略(源列表通常 ≤ 几十条),无需缓存或懒计算。
