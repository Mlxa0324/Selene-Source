# Danmaku Manual Search Query Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让“手动匹配弹幕”弹框在点击搜索时立即缓存输入框内容，而不再等到用户选中某个弹幕结果后才缓存搜索词。

**Architecture:** 复用现有 `DanmakuService` 的手动匹配存储结构，但新增一个单独的 `saveManualMatchQuery(...)` 方法，只负责持久化搜索词。`DanmakuMatchPanel._onSearch()` 在发起搜索前调用它；现有 `saveManualMatch(...)` 选中结果保存逻辑保持不变。

**Tech Stack:** Flutter, Dart, SharedPreferences, Flutter widget test, service test

---

## File Map

- Modify: `lib/services/danmaku_service.dart`
  - 新增单独的搜索词保存方法，保留已有 `episodeId`。
- Modify: `lib/widgets/danmaku_match_panel.dart`
  - 在 `_onSearch()` 中点击搜索后立刻缓存搜索词。
- Modify: `test/services/danmaku_service_test.dart`
  - 增加 `saveManualMatchQuery(...)` 的 service 测试。
- Modify: `test/widgets/danmaku_match_panel_test.dart`
  - 增加点击搜索即缓存的 widget 回归测试。
- Optional modify: `AGENTS.md`
  - 记录手动匹配搜索词缓存时机调整。

## Task 1: 先锁定搜索词保存行为

**Files:**
- Modify: `test/services/danmaku_service_test.dart`
- Modify: `test/widgets/danmaku_match_panel_test.dart`
- Reference: `lib/services/danmaku_service.dart`
- Reference: `lib/widgets/danmaku_match_panel.dart`

- [ ] **Step 1: 为 service 写失败测试，锁定“仅保存搜索词”行为**

在 `test/services/danmaku_service_test.dart` 增加至少两个测试：

```dart
test('saveManualMatchQuery stores query without episode id', () async {
  final service = DanmakuService();

  await service.saveManualMatchQuery(
    'test_source',
    'video_1',
    2,
    'Naruto',
  );

  expect(
    await service.getManualMatchQuery('test_source', 'video_1', 2),
    'Naruto',
  );
  expect(
    await service.getManualMatch('test_source', 'video_1', 2),
    isNull,
  );
});

test('saveManualMatchQuery preserves existing episode id', () async {
  final service = DanmakuService();
  await service.saveManualMatch('test_source', 'video_1', 2, 101);

  await service.saveManualMatchQuery(
    'test_source',
    'video_1',
    2,
    'Bleach',
  );

  expect(await service.getManualMatch('test_source', 'video_1', 2), 101);
  expect(
    await service.getManualMatchQuery('test_source', 'video_1', 2),
    'Bleach',
  );
});
```

- [ ] **Step 2: 运行 service 测试确认先失败**

Run: `flutter test test/services/danmaku_service_test.dart`

Expected: FAIL，提示 `saveManualMatchQuery(...)` 尚未定义。

- [ ] **Step 3: 为 widget 写失败测试，锁定“点击搜索就缓存”**

在 `test/widgets/danmaku_match_panel_test.dart` 增加一个 widget test。思路：

- 构建 `DanmakuMatchPanel`
- 传入 `searchEpisodesOverride`，返回空结果
- 输入关键词
- 点击搜索按钮
- 断言 `DanmakuService().getManualMatchQuery(...)` 能读回这次输入词

关键点：

- 搜索结果为空也要通过
- 不依赖选中某个结果

- [ ] **Step 4: 运行 widget 测试确认先失败**

Run: `flutter test test/widgets/danmaku_match_panel_test.dart`

Expected: FAIL，提示点击搜索后尚未写缓存。

## Task 2: 最小实现点击搜索即缓存

**Files:**
- Modify: `lib/services/danmaku_service.dart`
- Modify: `lib/widgets/danmaku_match_panel.dart`
- Test: `test/services/danmaku_service_test.dart`
- Test: `test/widgets/danmaku_match_panel_test.dart`

- [ ] **Step 1: 在 `DanmakuService` 中新增 `saveManualMatchQuery(...)`**

实现一个独立方法，例如：

```dart
Future<void> saveManualMatchQuery(
  String source,
  String id,
  int episodeIndex,
  String searchKeyword,
) async {
  final cleanKeyword = searchKeyword.trim();
  if (cleanKeyword.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final matches = _decodeManualMatches(prefs.getString(_manualMatchKey));
  final key = _manualMatchStorageKey(source, id, episodeIndex);
  final existing = matches[key];

  if (existing is Map<String, dynamic>) {
    matches[key] = {
      ...existing,
      'searchKeyword': cleanKeyword,
    };
  } else if (existing is Map) {
    matches[key] = {
      ...existing.cast<String, dynamic>(),
      'searchKeyword': cleanKeyword,
    };
  } else {
    matches[key] = {
      'searchKeyword': cleanKeyword,
    };
  }

  await prefs.setString(_manualMatchKey, jsonEncode(matches));
}
```

要求：

- 空字符串不写入
- 已有 `episodeId` 时必须保留
- 不改 `saveManualMatch(...)` 现有行为

- [ ] **Step 2: 重跑 service 测试，确认转绿**

Run: `flutter test test/services/danmaku_service_test.dart`

Expected: PASS 或至少新增两个测试转绿。

- [ ] **Step 3: 修改 `DanmakuMatchPanel._onSearch()`，先缓存再搜索**

在 `lib/widgets/danmaku_match_panel.dart` 的 `_onSearch()` 中：

- 取到 `query`
- 若为空直接返回
- 若非空，先调用新的 `saveManualMatchQuery(...)`
- 然后继续现有搜索流程

注意：

- 不要移除当前 `_activeQuery` 的更新逻辑
- 不要改结果列表处理逻辑
- 不要改选中结果后 `saveManualMatch(...)` 的逻辑

- [ ] **Step 4: 重跑 widget 测试，确认“点击搜索就缓存”转绿**

Run: `flutter test test/widgets/danmaku_match_panel_test.dart`

Expected: PASS。

- [ ] **Step 5: 运行 service + widget 组合回归**

Run:

```bash
flutter test test/services/danmaku_service_test.dart test/widgets/danmaku_match_panel_test.dart
```

Expected: PASS。

- [ ] **Step 6: 提交最小实现**

```bash
git add lib/services/danmaku_service.dart lib/widgets/danmaku_match_panel.dart test/services/danmaku_service_test.dart test/widgets/danmaku_match_panel_test.dart
git commit -m "feat: cache danmaku search query on search"
```

## Task 3: 回归验证与记录

**Files:**
- Modify: `AGENTS.md`
- Verify: `test/services/danmaku_service_test.dart`
- Verify: `test/widgets/danmaku_match_panel_test.dart`

- [ ] **Step 1: 运行最终测试集**

Run:

```bash
flutter test test/services/danmaku_service_test.dart test/widgets/danmaku_match_panel_test.dart
```

Expected: PASS。

- [ ] **Step 2: 运行静态检查**

Run:

```bash
dart analyze lib/services/danmaku_service.dart lib/widgets/danmaku_match_panel.dart test/services/danmaku_service_test.dart test/widgets/danmaku_match_panel_test.dart
```

Expected: 没有新增 error；如有现存 info/warning，需要在结果说明中明确注明。

- [ ] **Step 3: 补 changelog**

在 `AGENTS.md` 追加一条记录：

- 手动匹配弹幕弹框点击搜索时会立即缓存搜索词
- 搜索为空或失败时也保留本次输入

- [ ] **Step 4: 提交收尾**

```bash
git add AGENTS.md
git commit -m "docs: record danmaku search query cache change"
```

- [ ] **Step 5: 准备手动验证说明**

最终结果中提醒人工验证：

1. 打开手动匹配弹框
2. 输入一个新关键词并点击搜索
3. 不选任何结果，直接关闭弹框
4. 再次打开弹框，确认输入框已回填刚才的关键词
5. 再测试一次“搜索无结果”场景，确认也能回填
