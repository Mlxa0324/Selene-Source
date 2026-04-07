# 手动匹配弹幕搜索词即时缓存设计

## 背景

当前“手动匹配弹幕”弹框只有在用户最终选中某个弹幕结果后，才会把搜索词一并保存到手动匹配记录中。这样会导致：

- 用户点击“搜索”后，即使输入了新的关键词，也不会立即被缓存
- 如果这次搜索没有结果，或者用户只是想先尝试不同关键词，下一次打开弹框时仍然只能看到旧的缓存词

用户期望改成：只要点击了搜索，就立刻缓存输入框中的内容，无论这次搜索是否成功，也无论最终有没有选中某个弹幕结果。

## 目标

- 全平台统一支持：点击“搜索”时立即缓存当前输入框内容
- 搜索结果为空、搜索失败时，也保留本次输入词
- 保持现有“选中具体弹幕后保存匹配关系”的逻辑不变
- 下次打开弹框时，仍能用最近一次搜索词回填输入框

## 非目标

- 不改手动匹配成功后的 `episodeId` 保存结构
- 不修改搜索结果展示、排序和定位逻辑
- 不改自动匹配逻辑

## 方案对比

### 方案 A：在点击搜索时直接缓存搜索词

在 `DanmakuMatchPanel._onSearch()` 里，取到 query 后先保存，再发起搜索请求。

优点：

- 最符合需求
- 改动范围小
- 搜索成功、失败、空结果都统一生效

缺点：

- 会缓存一些最终没有被选中的尝试性关键词

但这正是本次需求明确接受的行为。

### 方案 B：只有搜索成功时才缓存

优点：

- 能减少“无效关键词”缓存

缺点：

- 不符合“即使没结果也要缓存”的要求

### 方案 C：沿用 `saveManualMatch(...)`，允许只存搜索词

优点：

- 表面上少一个方法

缺点：

- 语义混乱：搜索词缓存和匹配关系保存不是同一层行为
- 需要让 `saveManualMatch(...)` 兼容没有 `episodeId` 的状态，容易让数据结构变脏

## 推荐方案

采用方案 A，并配合新增一个单独的搜索词保存方法。

也就是：

- 点击搜索 -> 保存搜索词
- 选中结果 -> 保存匹配关系

两个动作分别用不同接口处理，职责更清楚。

## 详细设计

### 1. 在 `DanmakuService` 中新增单独的搜索词保存方法

当前 `DanmakuService` 已有：

- `getManualMatch(...)`
- `getManualMatchQuery(...)`
- `saveManualMatch(...)`

本次新增一个专门方法，例如：

```dart
Future<void> saveManualMatchQuery(
  String source,
  String id,
  int episodeIndex,
  String searchKeyword,
)
```

该方法只负责把 `searchKeyword` 持久化到现有手动匹配存储结构中，不负责写入 `episodeId`。

要求：

- 复用现有 `_manualMatchKey` 和 `_manualMatchStorageKey(...)`
- 如果该 key 下已经有 `episodeId`，则保留它，只更新 `searchKeyword`
- 如果还没有匹配结果，则只建立带 `searchKeyword` 的记录
- 空字符串或纯空白输入不写入

### 2. 在 `DanmakuMatchPanel._onSearch()` 中前移缓存时机

修改 `lib/widgets/danmaku_match_panel.dart` 中的 `_onSearch()`：

- 取出 `query = _searchController.text.trim()`
- 如果非空，先调用新的 `saveManualMatchQuery(...)`
- 然后再执行 `searchEpisodes(...)`

这样搜索词的缓存不再依赖搜索结果，也不依赖用户最终选中某个弹幕。

### 3. 保持现有选中匹配逻辑不变

当前选中具体剧集后的逻辑继续保留：

- 仍通过 `saveManualMatch(...)` 保存 `episodeId`
- 如有 `searchKeyword`，也继续保存

这意味着：

- 点击搜索：更新“最近一次搜索词”
- 点击选中：更新“最终匹配关系”

两者语义不同，但数据可共存。

## 测试策略

### Service 测试

在 `test/services/danmaku_service_test.dart` 中补充：

- 新增 `saveManualMatchQuery(...)` 测试
- 断言只保存搜索词时，`getManualMatchQuery(...)` 能读回
- 断言已有 `episodeId` 时更新搜索词不会把 `episodeId` 覆盖掉

### Widget 测试

在 `test/widgets/danmaku_match_panel_test.dart` 中补充：

- 输入关键词
- 点击搜索
- 让 `searchEpisodesOverride` 返回空结果或失败结果
- 断言 service 中仍能读回这次输入词

### 回归测试

确保现有“选中结果后保存匹配关系”的行为不回归。

## 风险

- 搜索失败的关键词也会被缓存

这是本次设计主动接受的行为，因为需求明确要求“只要点击搜索就缓存”。

## 实施范围

- 修改：`lib/services/danmaku_service.dart`
- 修改：`lib/widgets/danmaku_match_panel.dart`
- 修改：`test/services/danmaku_service_test.dart`
- 修改：`test/widgets/danmaku_match_panel_test.dart`

不修改：

- `player_screen.dart` 的弹幕加载主链
- 自动匹配逻辑
- 匹配结果 UI 结构
