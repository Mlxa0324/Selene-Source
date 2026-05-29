# TV Grid 性能优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 降低 TV 搜索结果页和全局 TV Grid 在大列表场景下的卡顿，优先优化首屏进入、长按换焦和大结果集滚动时的流畅度。

**架构：** 保持现有 TV 页面结构和焦点语义不变，先在 `TvVideoGrid` 增加分批渲染能力，再让搜索结果页复用该能力并缓存聚合结果。焦点滚动链路维持现有行为，但在长按和列表频繁切换时减少不必要的动画与重复计算。

**技术栈：** Flutter、SliverGrid、FocusNode、Widget test

---

### 任务 1：为大搜索结果列表补充性能行为测试

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_search_screen_test.dart`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_video_library_screen_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
testWidgets('search result grid renders only first batch initially', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TvSearchScreen(
        loadSearchData: (_) async => const TvSearchData(
          searchHistory: [],
          hotWords: [],
          recommends: [],
        ),
        loadSuggestions: (_) async => const ['剑来'],
        loadSearchResults: (_) async => List<SearchResult>.generate(
          120,
          (index) => SearchResult(
            id: 'video_$index',
            title: '结果$index',
            poster: '',
            episodes: const ['episode-1'],
            episodesTitles: const ['第1集'],
            source: 'source_$index',
            sourceName: '源$index',
            year: '2025',
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('J'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tv-search-suggestion-tile-剑来')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('tv-video-card-focus-video_0')), findsOneWidget);
  expect(find.byKey(const ValueKey('tv-video-card-focus-video_79')), findsOneWidget);
  expect(find.byKey(const ValueKey('tv-video-card-focus-video_80')), findsNothing);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result grid renders only first batch initially"`
预期：FAIL，当前会一次性渲染全部结果卡片。

- [ ] **步骤 3：补充全局 Grid 分批渲染回归测试**

```dart
testWidgets('video library grid appends next batch after focus reaches batch tail', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TvVideoLibraryScreen(
        title: '播放历史',
        videos: List<VideoInfo>.generate(
          120,
          (index) => _videoInfo('history_$index', '影片$index'),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('tv-video-card-focus-history_79')), findsOneWidget);
  expect(find.byKey(const ValueKey('tv-video-card-focus-history_80')), findsNothing);
});
```

- [ ] **步骤 4：运行测试验证失败**

运行：`flutter test test/tv_app/tv_video_library_screen_test.dart --plain-name "video library grid appends next batch after focus reaches batch tail"`
预期：FAIL，当前 `TvVideoGrid` 不支持分批渲染。

- [ ] **步骤 5：Commit**

```bash
git add test/tv_app/tv_search_screen_test.dart test/tv_app/tv_video_library_screen_test.dart
git commit -m "test: 补充tv大列表性能回归"
```

### 任务 2：实现 TvVideoGrid 分批渲染能力

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_video_grid.dart`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_video_library_screen_test.dart`

- [ ] **步骤 1：为 TvVideoGrid 增加分批渲染配置与状态**

```dart
class TvVideoGrid extends StatefulWidget {
  const TvVideoGrid({
    super.key,
    required this.title,
    required this.videos,
    this.initialRenderCount = 80,
    this.renderBatchSize = 40,
    // ...
  });

  final int initialRenderCount;
  final int renderBatchSize;
}

class _TvVideoGridState extends State<TvVideoGrid> {
  int _visibleItemCount = 0;

  @override
  void initState() {
    super.initState();
    _visibleItemCount = _computeInitialVisibleItemCount();
  }
}
```

- [ ] **步骤 2：只向 SliverGrid 暴露当前可见批次**

```dart
int get _renderedItemCount {
  final videosLength = widget.videos.length;
  if (videosLength <= 0) {
    return 0;
  }
  return _visibleItemCount.clamp(0, videosLength);
}

delegate: SliverChildBuilderDelegate(
  (context, index) {
    final videoInfo = widget.videos[index];
    // ...
  },
  childCount: _renderedItemCount,
),
```

- [ ] **步骤 3：在焦点逼近当前批次尾部时追加下一批**

```dart
void _maybeExtendVisibleItems(int focusedIndex, int crossAxisCount) {
  final nextThreshold = _visibleItemCount - crossAxisCount;
  if (focusedIndex < nextThreshold || _visibleItemCount >= widget.videos.length) {
    return;
  }

  setState(() {
    _visibleItemCount = (_visibleItemCount + widget.renderBatchSize)
        .clamp(0, widget.videos.length);
  });
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
- `flutter test test/tv_app/tv_video_library_screen_test.dart --plain-name "video library grid appends next batch after focus reaches batch tail"`
- `flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result grid renders only first batch initially"`

预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/tv_app/widgets/tv_video_grid.dart test/tv_app/tv_video_library_screen_test.dart test/tv_app/tv_search_screen_test.dart
git commit -m "feat: 优化tv grid分批渲染"
```

### 任务 3：缓存搜索结果聚合，避免每次 build 全量 regroup

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/screens/tv_search_screen.dart`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_search_screen_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
testWidgets('search result aggregation cache reuses previous grouped videos until results change', (tester) async {
  // 通过注入同一批 searchResults 并多次触发无关 rebuild，
  // 断言结果卡片 key 不发生额外抖动，且分组数量稳定。
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result aggregation cache reuses previous grouped videos until results change"`
预期：FAIL，当前每次 build 都会重新 `_aggregateSearchResults(_searchResults)`。

- [ ] **步骤 3：把聚合结果缓存到状态层**

```dart
List<SearchResult> _lastAggregatedSourceResults = const <SearchResult>[];
List<VideoInfo> _aggregatedSearchVideos = const <VideoInfo>[];

void _syncAggregatedSearchVideos() {
  if (identical(_lastAggregatedSourceResults, _searchResults)) {
    return;
  }
  _lastAggregatedSourceResults = _searchResults;
  _aggregatedSearchVideos = _aggregateSearchResults(_searchResults);
}
```

- [ ] **步骤 4：仅在搜索结果变更时更新缓存**

```dart
setState(() {
  _searchResults = partialResults;
  _syncAggregatedSearchVideos();
});
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result aggregation cache reuses previous grouped videos until results change"`
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add lib/tv_app/screens/tv_search_screen.dart test/tv_app/tv_search_screen_test.dart
git commit -m "optimize: 缓存tv搜索结果聚合"
```

### 任务 4：降低大列表场景下的焦点滚动动画开销

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_focus_scroll.dart`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_focusable.dart`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_search_screen_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
testWidgets('search result focus scrolling skips redundant animations for near-still targets', (tester) async {
  // 构造大结果区，连续移动同列焦点，
  // 断言滚动位置在小位移场景不会每次都触发完整动画。
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result focus scrolling skips redundant animations for near-still targets"`
预期：FAIL，当前只要目标偏移超过极小阈值就会 `animateTo`。

- [ ] **步骤 3：为焦点滚动增加最小位移阈值**

```dart
if ((position.pixels - targetOffset).abs() < 12) {
  return;
}
```

- [ ] **步骤 4：为同帧重复请求增加去重保护**

```dart
double? _lastRequestedScrollOffset;

if (_lastRequestedScrollOffset != null &&
    (_lastRequestedScrollOffset! - targetOffset).abs() < 1) {
  return;
}
_lastRequestedScrollOffset = targetOffset;
```

- [ ] **步骤 5：运行测试验证通过**

运行：`flutter test test/tv_app/tv_search_screen_test.dart --plain-name "search result focus scrolling skips redundant animations for near-still targets"`
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add lib/tv_app/widgets/tv_focus_scroll.dart lib/tv_app/widgets/tv_focusable.dart test/tv_app/tv_search_screen_test.dart
git commit -m "optimize: 降低tv焦点滚动动画开销"
```

### 任务 5：执行整体验证

**文件：**
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/screens/tv_search_screen.dart`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_video_grid.dart`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_focus_scroll.dart`
- 修改：`/Volumes/My2TDrive/StudioProjects/Selene-Source/lib/tv_app/widgets/tv_focusable.dart`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_search_screen_test.dart`
- 测试：`/Volumes/My2TDrive/StudioProjects/Selene-Source/test/tv_app/tv_video_library_screen_test.dart`

- [ ] **步骤 1：运行搜索页回归**

运行：`flutter test test/tv_app/tv_search_screen_test.dart`
预期：PASS

- [ ] **步骤 2：运行视频库页回归**

运行：`flutter test test/tv_app/tv_video_library_screen_test.dart`
预期：PASS

- [ ] **步骤 3：运行卡片回归**

运行：`flutter test test/tv_app/tv_video_card_test.dart`
预期：PASS

- [ ] **步骤 4：运行 diff 检查**

运行：`git diff --check -- lib/tv_app/screens/tv_search_screen.dart lib/tv_app/widgets/tv_video_grid.dart lib/tv_app/widgets/tv_focus_scroll.dart lib/tv_app/widgets/tv_focusable.dart test/tv_app/tv_search_screen_test.dart test/tv_app/tv_video_library_screen_test.dart test/tv_app/tv_video_card_test.dart`
预期：无输出

- [ ] **步骤 5：Commit**

```bash
git add lib/tv_app/screens/tv_search_screen.dart lib/tv_app/widgets/tv_video_grid.dart lib/tv_app/widgets/tv_focus_scroll.dart lib/tv_app/widgets/tv_focusable.dart test/tv_app/tv_search_screen_test.dart test/tv_app/tv_video_library_screen_test.dart test/tv_app/tv_video_card_test.dart docs/superpowers/plans/2026-05-29-tv-grid-performance-optimization.md
git commit -m "optimize: 提升tv大列表浏览性能"
```
