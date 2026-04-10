# Online Preload Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把全平台在线播放统一成同一套“预加载”产品语义：应用设置默认开启，持续尽量补当前位置右侧 5 分钟，浅色进度条展示已确认缓存范围，左拖只认已确认缓存区间，本地离线不受影响。

**Architecture:** 先把现有 macOS 专用 `mediaKitPreloadEnabled` 收敛成统一的 `playbackPreloadEnabled` 配置，并引入一个跨后端可复用的“已确认缓存区间”抽象。然后分别接入 `WebViewPlayerAdapter` 和 macOS `media_kit` 的缓存观测，把缓存区间透传到播放器控件层，由移动端和桌面端进度条统一绘制浅色缓存范围。

**Tech Stack:** Flutter, Dart, SharedPreferences, `flutter_test`, `dart analyze`, `flutter_inappwebview`, `media_kit`

---

## File Map

- Modify: `lib/services/user_data_service.dart`
  - 新增统一预加载配置 key 与兼容旧 macOS key 的读写接口。
- Modify: `lib/widgets/user_menu.dart`
  - 把现有 macOS 专用开关改成全平台“预加载”横向单选。
- Modify: `lib/screens/player_screen.dart`
  - 用统一配置替代 `_mediaKitPreloadEnabled`，把开关下发给播放器。
- Modify: `lib/widgets/video_player_widget.dart`
  - 把播放器参数与 adapter 接入统一配置；macOS/在线播放统一使用新参数。
- Modify: `lib/widgets/player_adapter.dart`
  - 为 adapter 增加统一的缓存区间读取/事件能力；WebView 与 VideoPlayer/MediaKit 状态接入这里。
- Create: `lib/models/player_cached_range.dart`
  - 定义缓存区间数据模型，例如 `PlayerCachedRange(start, end)`。
- Create: `lib/utils/player_cached_range_utils.dart`
  - 提供区间排序、合并、查找“包含当前位置的主区间”等纯函数。
- Modify: `lib/widgets/mobile_player_controls.dart`
  - 进度条浅色层改为读取统一缓存区间，而不是只画已播放红条。
- Modify: `lib/widgets/pc_player_controls.dart`
  - 当前 `showPreloadProgress + buffer` 逻辑改成统一缓存区间绘制。
- Create or Modify: `test/services/user_data_service_preload_test.dart`
  - 覆盖统一配置默认值、迁移回退与显式写入行为。
- Create: `test/utils/player_cached_range_utils_test.dart`
  - 覆盖缓存区间合并和命中判定。
- Modify: `test/widgets/user_menu_version_entry_test.dart`
  - 保留版本入口测试；如不合适则拆出新文件，不要污染已有版本测试意图。
- Create: `test/widgets/user_menu_preload_setting_test.dart`
  - 覆盖全平台预加载设置展示和交互。
- Create: `test/widgets/mobile_player_controls_preload_test.dart`
  - 覆盖移动端进度条浅色缓存范围绘制语义。
- Create: `test/widgets/pc_player_controls_preload_test.dart`
  - 覆盖桌面端浅色缓存范围绘制语义。
- Create or Modify: `test/widgets/video_player_widget_preload_config_test.dart`
  - 覆盖统一配置切换时播放器参数透传。
- Optional Modify: `AGENTS.md`
  - 记录全平台在线播放预加载统一行为。

## Task 1: 先锁定统一预加载配置行为

**Files:**
- Create: `test/services/user_data_service_preload_test.dart`
- Create: `test/widgets/user_menu_preload_setting_test.dart`
- Reference: `lib/services/user_data_service.dart`
- Reference: `lib/widgets/user_menu.dart`

- [ ] **Step 1: 为统一配置读取写失败测试**

在 `test/services/user_data_service_preload_test.dart` 新增至少三个测试：

```dart
test('getPlaybackPreloadEnabled defaults to true when nothing is stored', () async {
  SharedPreferences.setMockInitialValues({});

  expect(
    await UserDataService.getPlaybackPreloadEnabled(),
    isTrue,
  );
});

test('getPlaybackPreloadEnabled falls back to legacy media kit key', () async {
  SharedPreferences.setMockInitialValues({
    'media_kit_preload_enabled': false,
  });

  expect(
    await UserDataService.getPlaybackPreloadEnabled(),
    isFalse,
  );
});

test('savePlaybackPreloadEnabled writes the unified key', () async {
  SharedPreferences.setMockInitialValues({});

  await UserDataService.savePlaybackPreloadEnabled(false);

  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getBool('playback_preload_enabled_v1'), isFalse);
});
```

- [ ] **Step 2: 运行 service 测试确认先失败**

Run: `flutter test test/services/user_data_service_preload_test.dart`

Expected: FAIL，提示统一配置接口或 key 尚未定义。

- [ ] **Step 3: 为设置页写失败测试，锁定“全平台展示横向开关”**

在 `test/widgets/user_menu_preload_setting_test.dart` 增加一个 widget test：

- 初始化 `SharedPreferences` 为空
- 构建 `UserMenu(isDarkMode: false)`
- 进入“应用设置”
- 断言能看到“预加载”文案
- 断言设置控件不是 macOS 条件分支专用文案 `预加载（media_kit）`
- 断言默认选中“开”

如果 UI 使用 `ChoiceChip`、自定义横向 pill、或其他横向单选实现，都可以，但测试必须只锁定用户可见行为，不锁定内部具体 widget 类型。

- [ ] **Step 4: 运行 widget 测试确认先失败**

Run: `flutter test test/widgets/user_menu_preload_setting_test.dart`

Expected: FAIL，提示新文案或交互尚未实现。

## Task 2: 最小实现统一配置与设置 UI

**Files:**
- Modify: `lib/services/user_data_service.dart`
- Modify: `lib/widgets/user_menu.dart`
- Test: `test/services/user_data_service_preload_test.dart`
- Test: `test/widgets/user_menu_preload_setting_test.dart`

- [ ] **Step 1: 在 `UserDataService` 中新增统一预加载配置接口**

添加统一 key 和方法，例如：

```dart
static const String _playbackPreloadEnabledKey = 'playback_preload_enabled_v1';

static Future<void> savePlaybackPreloadEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_playbackPreloadEnabledKey, enabled);
}

static Future<bool> getPlaybackPreloadEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  final unified = prefs.getBool(_playbackPreloadEnabledKey);
  if (unified != null) return unified;
  return prefs.getBool(_mediaKitPreloadEnabledKey) ?? true;
}
```

要求：

- 默认值为 `true`
- 兼容旧 `media_kit_preload_enabled`
- 暂时保留旧接口，避免一次性破坏现有调用

- [ ] **Step 2: 重跑 service 测试，确认统一配置转绿**

Run: `flutter test test/services/user_data_service_preload_test.dart`

Expected: PASS。

- [ ] **Step 3: 在 `user_menu.dart` 中新增横向单选 helper**

不要强行复用现有 `_buildToggleOption()`，而是在同文件新增一个专门的横向单选 helper，例如：

```dart
Widget _buildSegmentOption({
  required String title,
  required IconData icon,
  required bool value,
  required Future<void> Function(bool) onChanged,
})
```

UI 要求：

- 左侧仍沿用当前设置项图标和标题风格
- 右侧为横向 “开 / 关” 单选
- 默认展示“开”
- 文案统一为 `预加载`

- [ ] **Step 4: 用统一配置替换现有 macOS 专用开关**

把：

```dart
if (DeviceUtils.isMacOS()) _buildToggleOption(title: '预加载（media_kit）', ...)
```

改成：

- 全平台都显示
- 读取/写入 `getPlaybackPreloadEnabled()` / `savePlaybackPreloadEnabled()`
- 内部 state 变量重命名为更中性的 `_playbackPreloadEnabled`

- [ ] **Step 5: 重跑设置 widget 测试，确认 UI 行为转绿**

Run: `flutter test test/widgets/user_menu_preload_setting_test.dart`

Expected: PASS。

- [ ] **Step 6: 提交统一设置最小实现**

```bash
git add lib/services/user_data_service.dart lib/widgets/user_menu.dart test/services/user_data_service_preload_test.dart test/widgets/user_menu_preload_setting_test.dart
git commit -m "feat: unify playback preload setting"
```

## Task 3: 先锁定缓存区间抽象的失败测试

**Files:**
- Create: `lib/models/player_cached_range.dart`
- Create: `lib/utils/player_cached_range_utils.dart`
- Create: `test/utils/player_cached_range_utils_test.dart`

- [ ] **Step 1: 为缓存区间合并写失败测试**

在 `test/utils/player_cached_range_utils_test.dart` 新增纯函数测试：

```dart
test('mergeCachedRanges merges overlapping and adjacent ranges', () {
  final merged = mergePlayerCachedRanges([
    PlayerCachedRange(start: Duration.zero, end: const Duration(minutes: 2)),
    PlayerCachedRange(start: const Duration(minutes: 2), end: const Duration(minutes: 4)),
    PlayerCachedRange(start: const Duration(minutes: 6), end: const Duration(minutes: 7)),
  ]);

  expect(merged, [
    PlayerCachedRange(start: Duration.zero, end: const Duration(minutes: 4)),
    PlayerCachedRange(start: const Duration(minutes: 6), end: const Duration(minutes: 7)),
  ]);
});
```

- [ ] **Step 2: 为“目标时间是否命中已确认缓存”写失败测试**

同文件再加一个测试：

```dart
test('findContainingCachedRange returns hit only for confirmed ranges', () {
  final range = findContainingPlayerCachedRange(
    const Duration(minutes: 3),
    [
      PlayerCachedRange(start: Duration.zero, end: const Duration(minutes: 5)),
    ],
  );

  expect(range, isNotNull);
});
```

再补一个 miss 场景，确保未来理论窗口不会被这个 helper 误认为命中。

- [ ] **Step 3: 运行 utils 测试确认先失败**

Run: `flutter test test/utils/player_cached_range_utils_test.dart`

Expected: FAIL，提示模型或 helper 未定义。

## Task 4: 实现缓存区间模型与纯函数

**Files:**
- Create: `lib/models/player_cached_range.dart`
- Create: `lib/utils/player_cached_range_utils.dart`
- Test: `test/utils/player_cached_range_utils_test.dart`

- [ ] **Step 1: 实现最小数据模型**

在 `lib/models/player_cached_range.dart` 新增轻量数据类：

```dart
class PlayerCachedRange {
  final Duration start;
  final Duration end;

  const PlayerCachedRange({
    required this.start,
    required this.end,
  });
}
```

补上：

- `assert(end >= start)`
- `copyWith`
- `==` / `hashCode`

- [ ] **Step 2: 实现区间合并与命中 helper**

在 `lib/utils/player_cached_range_utils.dart` 新增：

```dart
List<PlayerCachedRange> mergePlayerCachedRanges(List<PlayerCachedRange> ranges)
PlayerCachedRange? findContainingPlayerCachedRange(
  Duration position,
  List<PlayerCachedRange> ranges,
)
PlayerCachedRange? findPrimaryPlayerCachedRange(
  Duration position,
  List<PlayerCachedRange> ranges,
)
```

约束：

- 纯函数
- 先排序再合并
- 相邻区间也视为可合并
- `findPrimary...` 用于第一版只支持单段浅色条时的退化显示

- [ ] **Step 3: 重跑 utils 测试，确认区间逻辑转绿**

Run: `flutter test test/utils/player_cached_range_utils_test.dart`

Expected: PASS。

- [ ] **Step 4: 提交区间抽象**

```bash
git add lib/models/player_cached_range.dart lib/utils/player_cached_range_utils.dart test/utils/player_cached_range_utils_test.dart
git commit -m "feat: add player cached range utilities"
```

## Task 5: 先锁定 adapter 与播放器配置透传的失败测试

**Files:**
- Create or Modify: `test/widgets/video_player_widget_preload_config_test.dart`
- Reference: `lib/widgets/video_player_widget.dart`
- Reference: `lib/widgets/player_adapter.dart`
- Reference: `lib/screens/player_screen.dart`

- [ ] **Step 1: 写失败测试，锁定 `PlayerScreen` 下发统一配置**

如果 `PlayerScreen` 现有测试挂载成本过高，可以先抽 `@visibleForTesting` 的轻量 helper；否则新增 widget test，目标是证明：

- 读取 `getPlaybackPreloadEnabled()` 后，播放器拿到的是统一开关
- 不再只依赖 `Platform.isMacOS`

最小断言示例：

```dart
testWidgets('video player widget receives unified playback preload flag', (tester) async {
  // build minimal host that passes playbackPreloadEnabled: false
  // assert rendered child gets the same value
});
```

- [ ] **Step 2: 写失败测试，锁定 adapter 对统一缓存区间的接口**

在 `test/widgets/video_player_widget_preload_config_test.dart` 或拆出的 `test/widgets/player_adapter_cached_ranges_test.dart` 中增加 fake adapter 测试，断言 `PlayerAdapterStream/State` 新增的缓存区间读取能力能被控件层消费。

- [ ] **Step 3: 运行相关测试确认先失败**

Run:

```bash
flutter test test/widgets/video_player_widget_preload_config_test.dart
```

Expected: FAIL，提示统一参数或缓存区间接口尚未存在。

## Task 6: 实现播放器统一预加载参数与 adapter 接口

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/widgets/video_player_widget.dart`
- Modify: `lib/widgets/player_adapter.dart`
- Test: `test/widgets/video_player_widget_preload_config_test.dart`

- [ ] **Step 1: 在 `PlayerScreen` 中重命名状态并切换到统一配置读取**

把 `_mediaKitPreloadEnabled` 改成 `_playbackPreloadEnabled`，并在 `_loadPlayerGeneralSettings()` 中改为：

```dart
final playbackPreloadEnabled =
    await UserDataService.getPlaybackPreloadEnabled();
```

同时确保传给 `VideoPlayerWidget` 的参数名同步更新。

- [ ] **Step 2: 在 `VideoPlayerWidget` 中用统一参数替代旧命名**

把：

```dart
final bool mediaKitPreloadEnabled;
```

改成：

```dart
final bool playbackPreloadEnabled;
```

并同步更新：

- `_mediaKitBufferSize` 判断
- `didUpdateWidget(...)` 中的配置变化监听
- `showPreloadProgress` 的启用条件

- [ ] **Step 3: 在 `PlayerAdapter` 接口中新增统一缓存区间读取能力**

新增最小接口，例如：

```dart
abstract class PlayerAdapterStream {
  Stream<List<PlayerCachedRange>> get cachedRanges;
}

abstract class PlayerAdapterState {
  List<PlayerCachedRange> get cachedRanges;
}
```

要求：

- `VideoPlayerAdapter` 暂时返回空列表或来自底层 `buffered`
- `MediaKitAdapter` 第一版可转换现有 `buffer` 为单段范围
- `WebViewPlayerAdapter` 下一任务再填充真实区间逻辑

- [ ] **Step 4: 修复已有 fake adapter 测试桩**

更新以下测试中的 fake adapter，补上新接口，避免全量测试因接口变化而大面积编译失败：

- `test/widgets/video_player_widget_seek_notify_test.dart`
- `test/widgets/mobile_player_controls_seek_test.dart`
- `test/widgets/mobile_player_panel_style_test.dart`

- [ ] **Step 5: 重跑配置/adapter 测试，确认转绿**

Run:

```bash
flutter test test/widgets/video_player_widget_preload_config_test.dart test/widgets/video_player_widget_seek_notify_test.dart test/widgets/mobile_player_controls_seek_test.dart
```

Expected: PASS。

- [ ] **Step 6: 提交统一参数改造**

```bash
git add lib/screens/player_screen.dart lib/widgets/video_player_widget.dart lib/widgets/player_adapter.dart test/widgets/video_player_widget_preload_config_test.dart test/widgets/video_player_widget_seek_notify_test.dart test/widgets/mobile_player_controls_seek_test.dart test/widgets/mobile_player_panel_style_test.dart
git commit -m "refactor: unify playback preload config and adapter ranges"
```

## Task 7: 先锁定 WebView 已确认缓存区间行为的失败测试

**Files:**
- Modify: `lib/widgets/player_adapter.dart`
- Create: `test/widgets/player_adapter_webview_preload_test.dart`

- [ ] **Step 1: 抽出可测试的 WebView 缓存区间状态 helper**

先不要直接写难测的 JS 集成逻辑；先在 Dart 侧规划一个 `@visibleForTesting` helper 或小类，负责：

- 记录确认到的区间
- 合并区间
- 记录 seek 后的新窗口版本

例如：

```dart
final tracker = WebViewPreloadTracker();
tracker.confirmRange(Duration.zero, const Duration(minutes: 4));
tracker.confirmRange(const Duration(minutes: 4), const Duration(minutes: 7));
```

- [ ] **Step 2: 为“左拖只认已确认缓存”写失败测试**

在 `test/widgets/player_adapter_webview_preload_test.dart` 增加：

```dart
test('left seek only hits confirmed cached ranges', () {
  final tracker = WebViewPreloadTracker();
  tracker.confirmRange(Duration.zero, const Duration(minutes: 10));
  tracker.updateTargetWindow(
    position: const Duration(minutes: 20),
    window: const Duration(minutes: 5),
  );

  expect(
    tracker.contains(const Duration(minutes: 3)),
    isTrue,
  );
  expect(
    tracker.contains(const Duration(minutes: 18)),
    isFalse,
  );
});
```

- [ ] **Step 3: 为“seek 后右侧窗口重建，但旧确认区间保留”写失败测试**

再补一个测试证明：

- `updateTargetWindow(...)` 不会抹掉旧的 confirmed ranges
- 只有显式 reset（切集/换源/新 URL）才清空

- [ ] **Step 4: 运行 WebView 预加载测试确认先失败**

Run: `flutter test test/widgets/player_adapter_webview_preload_test.dart`

Expected: FAIL，提示 tracker 或相关行为未实现。

## Task 8: 实现 WebView 已确认缓存区间与右侧 5 分钟窗口

**Files:**
- Modify: `lib/widgets/player_adapter.dart`
- Test: `test/widgets/player_adapter_webview_preload_test.dart`

- [ ] **Step 1: 在 `player_adapter.dart` 中实现 WebView 预加载 tracker**

新增一个最小可测试的状态对象，例如：

```dart
class WebViewPreloadTracker {
  final Duration targetWindowSize;
  List<PlayerCachedRange> confirmedRanges = const [];

  void confirmRange(Duration start, Duration end) { ... }
  void updateTargetWindow(Duration position) { ... }
  void resetForNewMedia() { ... }
  bool contains(Duration position) { ... }
}
```

注意：

- `contains(...)` 只查 `confirmedRanges`
- `targetWindow` 只表示计划，不直接视为 confirmed

- [ ] **Step 2: 把 tracker 接到 `WebViewPlayerAdapter`**

要求：

- 初始化或 `url` 变化时重置 tracker
- 正常播放/预取成功后确认缓存区间
- seek 到新位置后仅更新目标窗口，不立即清掉旧 confirmed ranges
- 把 `confirmedRanges` 同步到 `state.cachedRanges` 和 `stream.cachedRanges`

- [ ] **Step 3: 给主动预加载逻辑加统一开关与窗口限制**

在现有 WebView/hls.js 逻辑基础上：

- 只有 `playbackPreloadEnabled && !isLocal` 时才主动补窗口
- 窗口固定为 `const Duration(minutes: 5)`
- 并发继续受已有 `seekWarmupConcurrency` 等配置约束，不要无界放大

- [ ] **Step 4: 重跑 WebView tracker 测试，确认转绿**

Run: `flutter test test/widgets/player_adapter_webview_preload_test.dart`

Expected: PASS。

- [ ] **Step 5: 提交 WebView 预加载行为**

```bash
git add lib/widgets/player_adapter.dart test/widgets/player_adapter_webview_preload_test.dart
git commit -m "feat: track confirmed preload ranges for webview playback"
```

## Task 9: 先锁定移动端与桌面端浅色进度条展示的失败测试

**Files:**
- Create: `test/widgets/mobile_player_controls_preload_test.dart`
- Create: `test/widgets/pc_player_controls_preload_test.dart`
- Reference: `lib/widgets/mobile_player_controls.dart`
- Reference: `lib/widgets/pc_player_controls.dart`

- [ ] **Step 1: 为移动端进度条写失败测试**

新增 widget test，使用 fake adapter 提供：

```dart
cachedRanges = [
  PlayerCachedRange(start: Duration.zero, end: const Duration(minutes: 8)),
];
position = const Duration(minutes: 3);
duration = const Duration(minutes: 30);
```

目标：

- 断言进度条除了红色已播放层，还会绘制浅色缓存层
- 浅色层宽度按缓存区间而不是按理论目标窗口计算

如果难以断言颜色层，可先抽 `@visibleForTesting` helper：

```dart
double resolveCachedProgressValue({
  required Duration duration,
  required Duration position,
  required List<PlayerCachedRange> ranges,
})
```

- [ ] **Step 2: 为桌面端进度条写失败测试**

同理在 `test/widgets/pc_player_controls_preload_test.dart` 锁定：

- `showPreloadProgress` 不再只依赖 macOS
- 桌面端浅色条读取 `player.state.cachedRanges`

- [ ] **Step 3: 运行控件测试确认先失败**

Run:

```bash
flutter test test/widgets/mobile_player_controls_preload_test.dart test/widgets/pc_player_controls_preload_test.dart
```

Expected: FAIL，提示新 helper 或展示逻辑尚未实现。

## Task 10: 实现统一浅色缓存进度条

**Files:**
- Modify: `lib/widgets/mobile_player_controls.dart`
- Modify: `lib/widgets/pc_player_controls.dart`
- Test: `test/widgets/mobile_player_controls_preload_test.dart`
- Test: `test/widgets/pc_player_controls_preload_test.dart`

- [ ] **Step 1: 先抽可测试的进度计算 helper**

在两个控件文件中不要复制粘贴复杂计算。优先抽一个 `@visibleForTesting` helper，至少能根据：

- 总时长
- 当前播放位置
- 缓存区间集合

算出第一版要展示的“主缓存段”比例值。

- [ ] **Step 2: 移动端进度条增加浅色缓存层**

在 `_MobileVideoProgressBar` 的 `Stack` 中新增浅色层，绘制顺序保持：

1. 背景轨道
2. 浅色缓存层
3. 红色已播放层
4. 拖拽 thumb

第一版限制：

- 若只实现单段显示，优先展示“包含当前位置的主缓存段”
- 不要错误把右侧理论 5 分钟直接画出来

- [ ] **Step 3: 桌面端进度条改读统一缓存区间**

把当前：

```dart
final buffer = widget.player.state.buffer;
preloadValue = buffer.inMilliseconds / duration.inMilliseconds;
```

改成根据 `cachedRanges` 计算展示值。

- [ ] **Step 4: 重跑控件测试，确认浅色缓存层语义转绿**

Run:

```bash
flutter test test/widgets/mobile_player_controls_preload_test.dart test/widgets/pc_player_controls_preload_test.dart
```

Expected: PASS。

- [ ] **Step 5: 提交控件层改造**

```bash
git add lib/widgets/mobile_player_controls.dart lib/widgets/pc_player_controls.dart test/widgets/mobile_player_controls_preload_test.dart test/widgets/pc_player_controls_preload_test.dart
git commit -m "feat: show confirmed preload ranges on player controls"
```

## Task 11: 回归验证与记录

**Files:**
- Modify: `AGENTS.md`
- Verify: `test/services/user_data_service_preload_test.dart`
- Verify: `test/utils/player_cached_range_utils_test.dart`
- Verify: `test/widgets/user_menu_preload_setting_test.dart`
- Verify: `test/widgets/video_player_widget_preload_config_test.dart`
- Verify: `test/widgets/player_adapter_webview_preload_test.dart`
- Verify: `test/widgets/mobile_player_controls_preload_test.dart`
- Verify: `test/widgets/pc_player_controls_preload_test.dart`
- Verify: `test/widgets/mobile_player_controls_seek_test.dart`
- Verify: `test/widgets/video_player_widget_seek_notify_test.dart`

- [ ] **Step 1: 跑本次新增与受影响测试集**

Run:

```bash
flutter test \
  test/services/user_data_service_preload_test.dart \
  test/utils/player_cached_range_utils_test.dart \
  test/widgets/user_menu_preload_setting_test.dart \
  test/widgets/video_player_widget_preload_config_test.dart \
  test/widgets/player_adapter_webview_preload_test.dart \
  test/widgets/mobile_player_controls_preload_test.dart \
  test/widgets/pc_player_controls_preload_test.dart \
  test/widgets/mobile_player_controls_seek_test.dart \
  test/widgets/video_player_widget_seek_notify_test.dart
```

Expected: PASS。

- [ ] **Step 2: 运行静态检查**

Run:

```bash
dart analyze \
  lib/services/user_data_service.dart \
  lib/models/player_cached_range.dart \
  lib/utils/player_cached_range_utils.dart \
  lib/widgets/user_menu.dart \
  lib/screens/player_screen.dart \
  lib/widgets/video_player_widget.dart \
  lib/widgets/player_adapter.dart \
  lib/widgets/mobile_player_controls.dart \
  lib/widgets/pc_player_controls.dart \
  test/services/user_data_service_preload_test.dart \
  test/utils/player_cached_range_utils_test.dart \
  test/widgets/user_menu_preload_setting_test.dart \
  test/widgets/video_player_widget_preload_config_test.dart \
  test/widgets/player_adapter_webview_preload_test.dart \
  test/widgets/mobile_player_controls_preload_test.dart \
  test/widgets/pc_player_controls_preload_test.dart
```

Expected: 没有新增 error；若有现存 warning/info，需要在最终结果中单独注明。

- [ ] **Step 3: 补 changelog**

在 `AGENTS.md` 追加记录：

- 应用设置新增统一“预加载”开关，默认开启
- 全平台在线播放统一按当前位置右侧 5 分钟进行主动预加载
- 浅色进度条展示已确认缓存范围
- 左拖只认已确认缓存区间，本地离线不受影响

- [ ] **Step 4: 提交文档收尾**

```bash
git add AGENTS.md
git commit -m "docs: record unified online preload behavior"
```

- [ ] **Step 5: 准备手动验证说明**

最终执行结果中提醒人工验证：

1. Android/iOS/Windows/macOS 在线播放开启预加载，从 0 分钟连续看到 10 分钟。
2. 左拖回 3 分钟，确认体感优先命中缓存，且浅色条覆盖该范围。
3. 右拖到 25 分钟，确认右侧围绕新位置继续补窗口，旧已确认范围不被 UI 立即抹掉。
4. 关闭应用设置“预加载”，确认不再主动补右侧 5 分钟，但播放器自然缓冲不被强行清空。
5. 打开本地离线视频，确认没有新增预加载 UI 或行为回归。
