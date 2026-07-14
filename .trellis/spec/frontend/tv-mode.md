# TV 模式前端实现规格

## 1. Scope / Trigger

当需求涉及 Android TV、BlueStacks TV 调试、TV 首页、TV 设置页、TV 详情页、TV 卡片、遥控器焦点行为时，必须遵守本文档。

本规格覆盖：

- Android TV 启动分流。
- TV 专属页面和组件边界。
- TV 首页内容和焦点交互。
- TV 详情页数据流和播放器入口。
- TV 设置页复用普通端配置。
- TV 端测试与验证要求。

## 2. 文件边界

### 2.1 TV 专属代码

TV 端新增页面、组件和服务优先放在：

```text
lib/tv_app/
├── screens/
├── services/
└── widgets/
```

当前核心文件：

| 文件 | 职责 |
|------|------|
| `lib/tv_app/tv_app_shell.dart` | TV 端 App Shell |
| `lib/tv_app/screens/tv_home_screen.dart` | TV 首页与顶部导航快捷入口 |
| `lib/tv_app/screens/tv_video_library_screen.dart` | TV 独立视频库列表页基座 |
| `lib/tv_app/screens/tv_history_screen.dart` | TV 播放历史独立页 |
| `lib/tv_app/screens/tv_favorites_screen.dart` | TV 收藏夹独立页 |
| `lib/tv_app/screens/tv_live_screen.dart` | TV 直播占位页 |
| `lib/tv_app/screens/tv_settings_screen.dart` | TV 设置页 |
| `lib/tv_app/screens/tv_search_screen.dart` | TV 搜索页 |
| `lib/tv_app/screens/tv_video_detail_screen.dart` | TV 影视详情页 |
| `lib/tv_app/screens/tv_fullscreen_player_screen.dart` | TV 专属全屏播放器壳与遥控器菜单 |
| `lib/tv_app/widgets/tv_top_nav.dart` | TV 顶部导航 |
| `lib/tv_app/widgets/tv_focusable.dart` | TV 遥控器焦点封装 |
| `lib/tv_app/widgets/tv_home_section.dart` | TV 首页横向内容区 |
| `lib/tv_app/widgets/tv_video_card.dart` | TV 影视卡片 |
| `lib/tv_app/widgets/tv_video_grid.dart` | TV 纵向影视网格 |
| `lib/tv_app/services/tv_account_config_service.dart` | TV 账号配置适配 |

### 2.2 跨端启动与配置

| 文件 | 职责 |
|------|------|
| `lib/app_bootstrap.dart` | 根据设备类型选择普通 App 或 TV App |
| `lib/services/app_device_service.dart` | 解析当前设备类型 |
| `lib/models/app_device_type.dart` | 设备类型枚举 |
| `lib/config/device_mode_config.dart` | 调试强制 TV 模式配置 |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Android 原生 TV 能力判断 |

## 3. Signatures

### 3.1 强制 TV 模式配置

```dart
class DeviceModeConfig {
  static const bool localDebugForceTvMode = false;
  static const bool dartDefineForceTvMode = bool.fromEnvironment(
    'SELENE_FORCE_TV_MODE',
    defaultValue: false,
  );
  static const bool forceTvMode =
      localDebugForceTvMode || dartDefineForceTvMode;
}
```

约定：

- 默认自动识别设备类型，避免手机开发包误进 TV 壳。
- 调试 BlueStacks 或平板 TV 壳时，可直接修改 `DeviceModeConfig.localDebugForceTvMode`，这是本机最直观的手动入口。
- 也可显式传入 `SELENE_FORCE_TV_MODE=true`。
- Release 默认不强制 TV。
- `forceTvMode` 统一汇总本地变量和 `dart-define` 两种强制来源，业务层只读取这一处结果。

### 3.2 TV 首页数据加载

```dart
typedef TvHomeDataLoader = Future<TvHomeData> Function(BuildContext context);

class TvHomeData {
  final List<VideoInfo> continueWatching;
  final List<VideoInfo> hotMovies;
  final List<VideoInfo> hotTvShows;
  final List<VideoInfo> bangumiCalendar;
  final List<VideoInfo> hotShows;
  final List<VideoInfo> history;
  final List<VideoInfo> favorites;
}
```

实现要求：

- `TvHomeScreen.defaultLoadHomeData` 负责聚合首页数据。
- `TvHomeScreen` 可注入 `loadHomeData` 以支持测试。
- 首页卡片点击进入 TV 详情页，不进入普通播放器页。

### 3.4 TV 设计视口

```dart
enum TvDesignPreset {
  auto,
  hd720,
  fullHd1080,
  qhd1440,
}

class TvDesignCanvas extends StatelessWidget {
  final TvDesignPreset preset;
}
```

约定：

- TV 设计稿预设统一收敛为 `TvDesignPreset.auto / hd720 / fullHd1080 / qhd1440`。
- 固定预设分别对应 `1280x720 / 1920x1080 / 2560x1440` 三套逻辑设计稿尺寸。
- `auto` 需要根据当前视口动态解析：`>= 2560x1440` 使用 `qhd1440`，`>= 1920x1080` 使用 `fullHd1080`，更低分辨率回退 `hd720`。
- 当前设备分辨率低于设计稿时，TV 页面整体按较短边等比缩小，避免较低分辨率设备把设计稿视觉占比放大一圈。
- 当前设备分辨率高于当前设计稿时，TV 页面整体按较短边等比放大，保证 1080P、2K、4K 切换时视觉占比一致。
- Kotlin 原生 TV 的 `TvDesignCanvas` 必须先按设计稿尺寸固定测量内容，再以 `placeWithLayer(0, 0)` 和 `TransformOrigin(0f, 0f)` 从左上角缩放放置；不要依赖嵌套 `Box + graphicsLayer` 居中预留边界，否则 1080P 下顶栏和首屏内容会落到负坐标被裁切。
- `TvDesignMetrics` 需要同时保留“配置预设”和“当前生效预设”，便于路由、新弹窗和调试面板继续继承同一套策略。
- TV 独立路由和 TV 风格弹窗都必须继承同一套设计视口，避免首页、详情页、搜索页、设置页和弹窗比例不一致。

### 3.3 TV 详情页数据加载

```dart
typedef TvVideoDetailLoader = Future<TvVideoDetailData> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

typedef TvVideoInitialSourcesLoader = Future<List<SearchResult>> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

typedef TvVideoMoreSourcesLoader = Future<List<SearchResult>> Function(
  BuildContext context,
  VideoInfo videoInfo,
  ValueChanged<List<SearchResult>> onIncrementalResults,
);

typedef TvVideoRecommendsLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
  VideoInfo videoInfo,
  SearchResult? currentDetail,
);

class TvVideoDetailData {
  final SearchResult? currentDetail;
  final List<SearchResult> sources;
  final List<VideoInfo> recommends;
}
```

实现要求：

- `currentDetail` 是当前播放源。
- `sources` 是可切换播放源。
- `recommends` 是相关推荐卡片数据。
- 详情页可注入 `loadDetail`、`loadInitialSources`、`loadMoreSources`、`loadRecommends` 和 `playerBuilder` 以支持测试。
- 生产加载必须拆成首屏可播源、后台补源和推荐三段；只有测试旧聚合路径时才使用 `loadDetail` 一次性回填。
- 详情页首播关键链路只能阻塞“定位首个可播源 + 下发首次 `updateDataSource(startAt)`”；收藏态、广告偏好、代理预热、推荐加载等次要任务不得串行卡住首播。
- 续播记录如果只用于决定初始集数和 `startAt`，不得阻塞精确源请求本身；最迟只需要在首次 `updateDataSource(startAt)` 前完成对齐。
- `loadMoreSources` 的 `onIncrementalResults` 一旦回调到首个匹配源，详情页必须立即设置 `currentDetail`、结束首屏转圈并触发内嵌播放器起播，后续完整结果继续去重追加到 `sources`。
- 从 `TvSearchScreen` 进入 `TvVideoDetailScreen` 时，如果搜索页已经持有同片名候选源或同一轮 SSE 搜索会话，详情页必须优先复用这份快照和后续增量结果，不得再额外发起一次按标题补源的 SSE 搜索。
- 搜索页进入详情页时，如果共享搜索会话尚未结束，详情页必须继续订阅后续增量结果直到该轮搜索结束；不能只消费进入瞬间的快照后就停住。
- 详情页在首屏精确源和后台补源都结束后仍无任何可播线路时，播放线路区必须展示“搜索已完成，未找到可播放信息”的图标空态，用于区分“还在搜”和“已搜完但无结果”。

### 3.3.1 Kotlin TV 详情页状态机

#### 1. Scope / Trigger

- Trigger: 修改 Kotlin TV 详情页的 loader 接线、播放源合并、续播匹配、空态收敛、route 兼容或播放请求派生。
- Scope: `re-android/feature-tv-detail`、`re-android/core-data`、`re-android/app-tv`。
- This contract exists to keep the Kotlin TV detail flow aligned with Flutter TV's two-lane loading model.

#### 2. Signatures

```kotlin
data class TvDetailEntry(
  val source: String,
  val videoId: String,
  val title: String = "",
  val searchTitle: String = "",
  val year: String = "",
  val posterUrl: String = "",
  val stype: String = "",
)

data class TvDetailResumeRecord(
  val source: String,
  val videoId: String,
  val episodeIndex: Int = 0,
  val positionMs: Long = 0L,
  val sourceName: String = "",
)

data class TvDetailResumeTarget(
  val source: String,
  val videoId: String,
  val sourceName: String = "",
)

class TvDetailViewModel(
  initialEntry: TvDetailEntry? = null,
  loadExactSources: suspend (TvDetailEntry) -> List<TvVideoSource>,
  loadMoreSources: suspend (TvDetailEntry, onIncremental: (List<TvVideoSource>) -> Unit) -> List<TvVideoSource>,
  loadRecommends: suspend (TvDetailEntry, TvVideoDetail?) -> List<TvVideoCard>,
  loadResumeRecord: suspend (TvDetailEntry) -> TvDetailResumeRecord?,
  loadFavoriteState: suspend (TvDetailEntry) -> Boolean,
  saveFavoriteState: suspend (TvDetailEntry?, Boolean) -> Unit,
  playerEngine: PlayerEngine? = null,
)
```

#### 3. Contracts

- `loadExactSources(source, id)` owns the exact `source + id` request path. Blank input and资料源 (`douban`, `bangumi`) must short-circuit to an empty list.
- `loadMoreSourcesByEntry(title, searchTitle, year)` owns the title fallback path. `searchTitle` wins; `title` is the fallback.
- Kotlin TV title fallback search should prefer the backend SSE stream when available. Each `source_result` event must be filtered and merged incrementally before the full stream completes.
- `loadMoreSources` must call `onIncrementalResults` as soon as a playable batch arrives, even if the final list is still being assembled.
- `initialSourcesLoaded` and `moreSourcesLoaded` are per-lane completion flags. `emptyPlaybackCompleted` becomes true only when both lanes are done and no playable source exists.
- `isInitialLoading` stops when the first playable source is selected or when both lanes complete with no source. `isMoreSourcesLoading` tracks the fallback lane only.
- `playbackRequest` must only be emitted when current source, current episode, and URL are all valid. `startPositionMs` comes from preview progress first, then resume position.
- `load(videoId)` stays as a compatibility entry and must build a `TvDetailEntry` from the stored initial entry fields.

#### 4. Validation & Error Matrix

- Exact lane fails, more lane succeeds -> keep playing, no fatal error.
- More lane fails, exact lane succeeds -> keep playing, no fatal error.
- SSE stream fails before any playable batch arrives -> title fallback may degrade to batch `api.search(query)`, but once incremental batches have arrived they must remain visible and usable.
- Both lanes finish with no playable source -> set `emptyPlaybackCompleted=true` and show the completed empty state.
- Resume target exists but does not match any current source -> do not auto-pick a wrong source before both lanes finish.
- Duplicate `source + id` with more episodes -> keep the source with the larger episode list.

#### 5. Good/Base/Bad Cases

- Good: exact source returns first, current source is selected immediately, more sources append later.
- Base: route only passes `source::id::title`, and the view model reconstructs the full entry context locally.
- Bad: one aggregated loader blocks exact playback, or a non-fatal source failure clears already discovered playable data.

#### 6. Tests Required

- `TvDetailViewModelTest` must cover exact-first, more-first, exact-failure-then-more-success, dual-empty completion, duplicate merge, resume wait, and playback request refresh.
- `TvDetailRepositoryTest` must cover `hasPlayableIdentity`, exact source loading, and title fallback source loading.
- `TvDetailRepositoryTest` must also cover SSE incremental source emission and the batch-search fallback when the SSE connection fails before the first result.
- `TvAppContainerTest` must cover loader injection and old `source::id::title` compatibility.
- `git diff --check` must pass for the files in the task batch.

#### 7. Wrong vs Correct

**Wrong**

```kotlin
val detail = loadInitialDetail(videoId)
val more = loadMoreSources(videoId, detail)
```

**Correct**

```kotlin
val exactSources = loadExactSources(entry)
val moreSources = loadMoreSources(entry) { incremental ->
  mergeSources(incremental)
}
```

### 3.3.2 Kotlin TV 详情页相关推荐契约

#### 1. Scope / Trigger

- Trigger: 修改 Kotlin TV 详情页推荐调度、豆瓣身份解析、豆瓣详情 HTML 抓取/解析或推荐列表回写。
- Scope: `re-android/core-network`、`re-android/core-data`、`re-android/feature-tv-detail`、`re-android/app-tv`。
- 推荐属于独立次要任务，不得等待标题补源、收藏态或其它非首播任务完成，也不得反向改写播放源、首播空态或收藏状态。

#### 2. Signatures

```kotlin
fun interface DoubanSubjectHtmlSource {
  suspend fun fetchSubjectHtml(doubanId: String): String
}

enum class TvDetailRecommendLoadState {
  Idle,
  Scheduled,
  Loading,
  Loaded,
  Empty,
  Failed,
}

suspend fun DoubanRepository.loadDetailRecommends(
  doubanId: String,
): List<TvVideoCard>

internal suspend fun resolveTvDetailRecommendDoubanId(
  entry: TvDetailEntry,
  latestDetail: TvVideoDetail?,
  exactDetail: TvVideoDetail?,
  resolveByTitle: suspend (TvVideoDetail?) -> String,
): String?
```

#### 3. Contracts

- 有有效预览播放器时，只在当前媒体真实进入 `PlayerState.Playing` 后安排推荐，并固定延迟 `2_000ms` 执行；普通 `Loading` 不能提前走兜底。
- 以下终态无法再等待正常 `Playing` 时立即加载推荐：双源链路完成仍无可播源、未注入播放器内核、`engine.load(request)` 真实失败、当前播放器进入 `PlayerState.Error`。
- 同一详情加载序号只能安排一个推荐任务；切换详情必须取消旧任务、清空旧推荐、重置为 `Idle`，并用 `loadSerial` 拒绝旧回包。
- 协程正常取消必须继续抛出 `CancellationException`，不能写成 `Failed` 或误记业务失败。
- 豆瓣 ID 优先级固定为：当前最新详情 `doubanId` → 同入口精确详情 `doubanId` → 豆瓣入口 `videoId` → 标题/年份解析；空字符串和哨兵值 `"0"` 都属于无效 ID。
- 精确详情只能按规范化 `source::videoId` 保存；同入口并发请求必须使用单调递增 token，旧请求晚到不得覆盖新详情或恢复已删除的豆瓣身份。
- `SeleneDoubanHtmlApi` 保留豆瓣直连、PoW 验证和镜像回退；`DoubanSubjectHtmlSource` 是仓库测试注入边界。
- `DoubanDetailsParser` 必须平衡扫描完整 `div#recommendations`，支持单双引号、属性乱序、绝对/协议相对/站内相对 subject 链接、可选评分，并把协议相对海报补为 HTTPS。
- HTML 抓取异常必须传播到 ViewModel 推荐边界；解析空列表写成 `Empty`，异常写成 `Failed`，二者都不得清除已经发现的播放源。
- 诊断只记录阶段、入口键、触发原因、数量和短错误说明；HTML 正文、Cookie、Authorization、密码和 token 不得进入日志。

#### 4. Validation & Error Matrix

- 当前媒体 `Playing`，标题补源仍未结束 -> 延迟 2 秒独立加载推荐并允许回写列表。
- 有可播源且播放器仍为正常 `Loading` -> 保持 `Scheduled` 之前状态，继续等待真实 `Playing`。
- 双源为空、无播放器、真实 load 失败或播放器错误 -> 不等待 2 秒，立即执行唯一兜底任务。
- 推荐抓取/解析抛异常 -> `recommendLoadState=Failed`，保留播放请求、线路列表、首播空态和收藏态。
- 推荐 HTML 合法但没有完整卡片 -> `recommendLoadState=Empty`，推荐轨道继续隐藏。
- 第二个详情已加载，首个详情推荐晚到 -> 记录 `StaleIgnored` 并丢弃结果，不覆盖当前页面。
- 延迟推荐任务因切换详情或页面释放被正常取消 -> 不写 `Failure`，也不额外写 `StaleIgnored`。
- 当前共享播放器上报其它媒体的 Playing/Paused -> 不修改当前预览状态，不触发当前详情推荐。

#### 5. Good/Base/Bad Cases

- Good: 当前影片真实起播后延迟 2 秒抓取豆瓣详情 HTML，标题补源仍在后台继续，推荐卡片先独立显示。
- Base: 当前影片没有可播源，但入口能解析出豆瓣 ID；双源链路收敛后立即加载推荐，页面仍可展示推荐列表。
- Bad: 把推荐放到精确源、全量标题补源和收藏全部完成之后，或用 `runCatching(...).getOrDefault(emptyList())` 把网络失败静默伪装成空结果。

#### 6. Tests Required

- `TvDetailViewModelTest` 必须覆盖 Playing 后 2 秒独立加载、Loading 不提前兜底、四类终态兜底、单任务去重、失败状态隔离、错误媒体隔离和旧结果拒绝。
- `DoubanDetailsParserTest` 必须覆盖嵌套容器、支持的链接形态、缺失评分、无推荐区、标签不平衡和不完整条目。
- `DoubanRepositoryTest` 必须覆盖 HTML 数据源注入、解析成功、未注入数据源和抓取异常传播。
- `TvAppContainerTest` 必须覆盖豆瓣 ID 优先级、空值/`0` 拒绝、假 HTML 推荐接线、跨入口隔离和同入口 token 版本保护。
- `TvDetailPresentationTest` 必须覆盖非空推荐展示轨道、空推荐隐藏轨道但保留底部操作。

#### 7. Wrong vs Correct

**Wrong**

```kotlin
val recommends = runCatching {
  loadRecommends(entry, detail)
}.getOrDefault(emptyList())
```

**Correct**

```kotlin
if (playerState.matchesPlaybackRequest(expectedRequest)) {
  scheduleRecommends(
    serial = serial,
    delayMs = 2_000L,
    trigger = "preview-playing",
  )
}
```

### 3.4 TV 焦点封装

```dart
class TvFocusable extends StatefulWidget {
  final TvFocusableBuilder builder;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;
  final ValueChanged<bool>? onFocusChanged;
  final bool autofocus;
}
```

实现要求：

- `onPressed` 处理确认键和鼠标点击。
- 确认键短按必须按一次物理按压只触发一次 `onPressed`；`KeyRepeatEvent` 和 `KeyUpEvent` 只能消费或结束按压态，不能重复执行点击业务，避免卡片进入详情页时连续 `push`。
- 提供 `onLongPressed` 时，`KeyRepeatEvent` 只触发一次长按业务；未触发长按的 `KeyUpEvent` 才回落为短按确认。
- `onFocusChanged` 处理焦点进入和离开。
- 顶部导航通过 `onFocusChanged(true)` 直接切换标签页。
- 顶部导航需要为每个菜单项持有独立 `FocusNode`，用于外部焦点进入时重定向到当前选中项。
- 顶部导航左侧主菜单承载「首页、电影、剧集、动漫、综艺、直播」；其中「直播」是独立页面，同时保留进入右上角快捷区的焦点过渡能力，不呼出分类筛选。右侧「搜索、播放历史、收藏夹、设置」属于快捷按钮区，使用图标加文字按钮展示。四个快捷入口都必须跳转独立页面，不再复用 `TvHomeScreen` 内嵌 tab。快捷按钮与 `IvyTV` Logo 同处顶部第一行并靠右展示，主分类菜单在下一行，二者上下错开，右侧同时展示当前时间。

### 3.5 TV 播放记录服务

```dart
class TvPlayRecordService {
  static bool hasResumeHint(VideoInfo videoInfo);
  static int episodeIndexFromVideoInfo(VideoInfo videoInfo, int totalEpisodes);
  static Duration? resumePositionFromVideoInfo(VideoInfo videoInfo);
  static PlayRecord buildRecord({
    required VideoInfo videoInfo,
    required SearchResult detail,
    required int episodeIndex,
    required int playTime,
    required int totalTime,
    DateTime? now,
  });
  static Future<bool> saveRecord(BuildContext context, PlayRecord playRecord);
  static Future<void> cleanupOtherSourceRecords({
    required BuildContext context,
    required SearchResult keepSource,
    required String searchTitle,
  });
}
```

实现要求：

- TV 详情页和 TV 全屏播放器都必须复用 `TvPlayRecordService` 构建 `PlayRecord`。
- 继续观看入口必须先按手机端播放器逻辑重新读取最新 `PlayRecord`，用 `source + id` 命中记录后再换算续播状态；缓存或首页传入的 `VideoInfo.index/playTime` 只能作为兜底，避免入口卡片字段过期导致从 0 秒起播。
- 继续观看首播使用最终续播记录的 `index` 换算初始集数下标，使用最终续播记录的 `playTime` 作为首次 `updateDataSource(startAt)`。
- 详情页小播放器和全屏播放器在 `updateDataSource(startAt)` 后，若底层控制器当前位置仍未到达 `startAt` 附近，必须补一次 `seekTo(startAt)`；这是对齐手机端 `PlayerScreen._resumeStartAt -> _onVideoPlayerReady -> seekToProgress` 的兜底。
- 详情页小播放器和全屏播放器不能只相信首次 `seekTo(startAt)` 调用成功；低端 Android WebView 可能在真实可 seek 前吞掉 seek。首次续播 seek 后必须等真实播放进度信号确认，如果当前位置仍在续播点之前，需要限次补偿 seek，避免继续观看从 0 秒起播。
- 播放进度上报沿用手机端节流：播放位置小于 1 秒不保存，10 秒内重复进度不重复保存。
- 换源时必须先保存新源 `PlayRecord`，保存失败不得清理旧源记录；保存成功后才清理同一影片其它源记录，避免网络抖动造成继续观看丢失。

### 3.5.1 TV 全屏退出收尾契约

实现要求：

- TV 全屏页主动返回必须先触发可见退出，再后台保存播放进度；不得在 `onExitRequested`、`Navigator.maybePop` 之前同步等待 `saveRecord`、旧源清理、焦点恢复或其它 IO。
- 主动返回、系统返回和 `dispose` 必须共享同一轮退出守卫；单次退出最多只能安排一次强制保存，`dispose` 只作为兜底入口。
- 退出流程开始后，播放器进度、网速、loading、焦点恢复、post-frame 和 timer 回调不得继续 `setState` 或请求焦点；必须以 `mounted && !isExiting` 语义早停。
- 共享播放器 overlay 退出时，全屏壳只负责发出退出意图和后台收尾；详情页负责恢复自身焦点和滚动位置，避免全屏页晚到回调改写已关闭页面。

测试要求：

- 返回键/ESC 关闭全屏页时，测试必须覆盖路由或 overlay 立即消失。
- 连续返回键/ESC 触发时，测试必须覆盖退出回调只执行一次。
- 共享播放器 overlay 退出后，测试必须覆盖详情页仍停留在当前路由，并恢复到顶部播放器焦点。

### 3.5.2 TV 全屏遥控 seek 契约

实现要求：

- 左右键短按保持单次 10 秒 seek。
- 左右键长按必须先经过 250ms 短按保护阈值；进入连续 seek 后，从首次按下到未满 4 秒使用第一档。
- 物理按住达到 4 秒后切换第二档；内部 tick 固定按 100ms 调度，第一档每 tick 下发 12 视频秒，第二档每 tick 下发 22 视频秒。
- 按住 10 秒的累计目标约为 30 分钟；按现有 250ms 启动、100ms tick 计算，包含首次 10 秒短按时累计为 1786 视频秒（29 分 46 秒）。
- 实际 `seekTo` 目标、底部进度条和 seek 后 loading 恢复锚点必须使用真实 seek 目标，不能使用中心提示的装饰性展示时间。
- 中心 seek 提示允许单独计算展示时间：秒个位每个物理秒只变化一次，秒十位继续跟随真实 seek 目标快速变化，用于提升长按时的数字可读性。
- 左右方向键 `KeyUp` 必须先停止内部连续 seek 任务，再消费按键事件，避免松手后继续跳转。

测试要求：

- 测试必须覆盖短按 10 秒不变。
- 测试必须覆盖 250ms 进入第一档、4 秒切换到第二档，以及 10 秒累计约 30 分钟。
- 测试必须覆盖中心提示展示时间与真实 seek 目标分离，避免后续把装饰性展示时间误用于 `seekTo` 或 loading 锚点。
- 测试必须覆盖秒个位按物理秒变化、250ms 边界平滑衔接和 `KeyUp` 立即停止连续 seek。

### 3.6 原生 TV 数据与网络层契约

```kotlin
interface SeleneTvApi {
    @GET("admin/dashboard")
    suspend fun getDashboard(): TvHomeResponse
}

data class TvHomeResponse(
    val sections: List<TvHomeSectionResponse>,
)

data class TvHomeSectionResponse(
    val key: String,
    val title: String,
    val videos: List<TvVideoCardResponse>,
)

class TvHomeRepository(
    private val api: SeleneTvApi,
    private val playbackRepository: TvPlaybackRepository,
) {
    suspend fun loadHome(): TvHomePayload
}
```

实现要求：

- `core-network` 只定义 Retrofit/OkHttp、会话 Cookie 和接口响应 DTO，不得依赖 `core-data`。
- `core-data` 可以依赖 `core-network`，并在 Repository 内把接口 DTO 转换为业务模型。
- 首页仓库必须把本地继续观看分区插入到远端分区前，分区标识固定为 `continue_watching`，标题固定为「继续观看」。
- 远端分区顺序保持服务端返回顺序，避免原生 TV 首页和 Flutter TV 首页排序不一致。
- 如果当前后台未提供 `GET admin/dashboard` 或该接口返回失败，原生 TV 首页不得直接进入错误态；必须降级复用分类搜索接口组装首页分区。兜底分区固定为：`hot_movies -> 电影`、`hot_tv_shows -> 剧集`、`bangumi_calendar -> 动漫`、`hot_shows -> 综艺`。继续观看分区仍保持第一位。
- 会话存储至少暴露 `baseUrl / account / cookie` 三个字段；未接入持久化前允许内存实现，但外部调用契约保持不变。
- 设置仓库保存服务器配置时只保存表单值，不直接触发登录请求，保持 TV 设置页现有语义。
- `app-tv` Manifest 必须声明 `android.permission.INTERNET`；TV 首页启动会立即登录后台，缺少权限会让 OkHttp 线程抛出 `SecurityException` 并导致打开闪退。
- 本地后台使用 HTTP 调试时，只允许 debug 包通过 manifest placeholder 开启 `usesCleartextTraffic=true`；release 包默认关闭明文流量。

### 3.7 原生 TV 功能页路由契约

```kotlin
@Composable
fun TvSearchRoute(
    state: TvSearchUiState = TvSearchUiState(),
    onQuerySelected: (String) -> Unit = {},
    onVideoClick: (String) -> Unit = {},
)

@Composable
fun TvHistoryRoute(
    state: TvHistoryUiState = TvHistoryUiState(),
    onVideoClick: (String) -> Unit = {},
)

@Composable
fun TvFavoritesRoute(
    state: TvFavoritesUiState = TvFavoritesUiState(),
    onVideoClick: (String) -> Unit = {},
)

@Composable
fun TvSettingsRoute(
    state: TvSettingsUiState = TvSettingsUiState(),
    onDanmakuMatchClick: () -> Unit = {},
)

@Composable
fun TvLiveRoute(
    state: TvLiveUiState = TvLiveUiState(),
    onChannelClick: (String) -> Unit = {},
)
```

实现要求：

- `feature-tv-*` 页面只接收 UI 状态和业务回调，不直接持有 `NavController`。
- `app-tv` 的 `TvNavGraph` 负责把视频卡片点击统一跳转到 `TvDestination.Detail.createRoute(videoId)`。
- 搜索页必须至少提供搜索入口、搜索历史、搜索热词和结果区；无结果时显示正式空态，不使用开发计划文案。
- 历史和收藏 ViewModel 必须暴露 `load / deleteVideo / clear` 三类状态动作，并在删除成功后同步当前列表。
- 设置页必须展示服务器配置、弹幕匹配、播放媒体、外观焦点四组入口；弹幕手动匹配必须通过显式回调暴露给宿主。
- 直播页必须建模频道、当前节目和节目单；无频道或节目单时使用正式空态，不展示“开发中/占位”文案。
- 全仓 TV 用户可见 placeholder 扫描命令固定为：

```bash
rg "后续接入|临时占位|占位|正在开发|后续|placeholder|TODO|骨架" re-android --glob '!**/build/**'
```

### 3.8 原生 TV 本地后台网关配置

```properties
# re-android/local.gateway.properties
SELENE_TV_BASE_URL=http://127.0.0.1:3000
SELENE_TV_USERNAME=your_username
SELENE_TV_PASSWORD=your_password
```

```kotlin
data class TvLocalGatewayConfig(
    val baseUrl: String,
    val username: String,
    val password: String,
)

interface SeleneTvAuthApi {
    @POST("api/login")
    suspend fun login(
        @Body request: SeleneTvLoginRequest,
    ): Response<ResponseBody>
}

data class SeleneTvLoginRequest(
    val username: String,
    val password: String,
)
```

实现要求：

- 真实配置文件固定为 `re-android/local.gateway.properties`，必须被 `.gitignore` 忽略。
- 仓库只提交 `re-android/local.gateway.properties.example`，不得提交真实地址、用户名、密码、Cookie。
- `app-tv` Gradle 负责读取本地配置并注入 `BuildConfig.SELENE_TV_BASE_URL / SELENE_TV_USERNAME / SELENE_TV_PASSWORD`。
- 本地配置缺失时 BuildConfig 字段保持空字符串，TV 首页必须进入错误态，不得崩溃。
- `core-network` 负责 baseUrl 标准化、Retrofit/OkHttp 创建、`POST /api/login`、`Set-Cookie` 解析和 Cookie header 注入。
- `core-data` 只消费 `SeleneTvApi`，不得读取本地 properties 或 BuildConfig。
- `feature-tv-*` 页面仍保持状态和回调驱动，不直接读取本地配置或网络客户端。

测试要求：

- `SeleneTvNetworkFactoryTest` 必须覆盖 baseUrl 标准化、空地址拒绝和 Cookie 解析。
- `SeleneTvNetworkClientTest` 必须覆盖登录成功保存会话和 401 错误文案。
- `TvAppContainerTest` 必须覆盖缺配置错误态和完整配置下“先登录再加载 dashboard”。
- 提交前必须执行：

```bash
git check-ignore -v re-android/local.gateway.properties
./re-android/gradlew -p re-android :core-network:testDebugUnitTest :app-tv:testDebugUnitTest
```

错误示例：

```kotlin
// 错误：feature 页面直接读取 BuildConfig 或 properties，破坏 UI 和数据层边界。
val password = BuildConfig.SELENE_TV_PASSWORD
```

正确示例：

```kotlin
// 正确：app-tv 容器读取本地配置，feature 页面只消费 ViewModel 状态。
val container = TvAppContainer(
    gatewayConfig = TvLocalGatewayConfig.fromBuildConfig(),
)
```

测试要求：

- `SessionCookieStoreTest.saveSession_persists_base_url_account_and_cookie` 必须覆盖服务器地址、账号和 Cookie 的保存读取。
- `TvHomeRepositoryTest.loadHome_aggregates_continue_watching_and_hot_sections` 必须覆盖 `continue_watching / hot_movies / hot_tv_shows / bangumi_calendar / hot_shows` 分区聚合。
- `TvHomeRepositoryTest.loadHome_fallsBackToCategorySearchWhenDashboardUnavailable` 必须覆盖 dashboard 失败时按「电影、剧集、动漫、综艺」顺序调用搜索接口并返回非空分区。

错误示例：

```kotlin
// 错误：network 层 DTO 直接复用 data 层业务模型，会造成模块依赖反向耦合。
data class TvHomeResponse(
    val sections: List<TvHomeSection>,
)
```

正确示例：

```kotlin
// 正确：network 层 DTO 独立存在，由 data 层 Repository 负责映射。
data class TvHomeResponse(
    val sections: List<TvHomeSectionResponse>,
)
```

## 4. Contracts

### 4.1 启动分流契约

| 场景 | 预期 |
|------|------|
| Android TV 真机 | 进入 TV App Shell |
| Android 手机 | 进入普通 App |
| Android 平板 | 默认进入普通 App |
| BlueStacks Debug | 因 `forceTvMode=true` 进入 TV App |
| iOS、macOS、Windows | 进入普通 App |
| 原生 TV 判断失败 | 回退普通 App，不崩溃 |

### 4.2 首页内容契约

| 分区 | 数据来源 | 布局 |
|------|----------|------|
| 继续观看 | `PageCacheService.getPlayRecords` | 横向列表 |
| 热门电影 | `PageCacheService.getHotMovies` | 横向列表 |
| 热门剧集 | `PageCacheService.getHotTvShows` | 横向列表 |
| 新番放送 | `BangumiService.getTodayCalendar` | 横向列表 |
| 热门综艺 | `PageCacheService.getHotShows` | 横向列表 |
| 电影标签 | `TvHomeData.hotMovies` | 纵向 Grid |
| 剧集标签 | `TvHomeData.hotTvShows` | 纵向 Grid |
| 动漫标签 | `TvHomeData.bangumiCalendar` | 纵向 Grid |
| 综艺标签 | `TvHomeData.hotShows` | 纵向 Grid |
| 直播标签 | `TvLiveScreen` | 居中占位页 |
| 播放历史 | `PageCacheService.getPlayRecords` | 独立页纵向 Grid |
| 收藏夹 | `PageCacheService.getFavorites` | 独立页纵向 Grid |

首页横向列表每个分区最多展示 15 个影视卡片。分区数据超过 15 个时，第 16 个位置展示“查看更多”卡片，宽度等于 `TvVideoCard.width`，高度等于 `TvVideoCard.coverHeight`，点击后切换到对应顶部分类页或播放历史页。

首页横向列表与纵向 Grid 到达边界时，当前卡片播放轻微边界抖动。横向列表在首尾卡片按边界方向键时，必须先滚动到真实 `minScrollExtent/maxScrollExtent`，让首尾 padding 安全留白完整露出；只有已经到达真实边界后才触发抖动。长按方向键时抖动必须有冷却间隔，避免持续重启动画。纵向 Grid 的上方向不做边界拦截，必须允许焦点继续回到顶部导航。

纵向 Grid 页必须使用同一个滚动容器承载二级标题和卡片列表。顶部导航固定在 `TvHomeScreen` 外层，二级标题（例如「电影」「播放历史」「收藏夹」）不能固定在 Grid 外部。Grid 滚动视口必须允许焦点绘制外溢，并在首尾列预留安全边距，避免卡片放大和封面焦点边框被左右裁剪；但 Grid 外层必须被页面内容区域裁剪，避免卡片向上绘制到顶部导航或筛选面板文字上。二级标题、空状态与首列卡片封面左边缘必须保持对齐，不能因为安全边距产生明显错位。

纵向 Grid 在 `smoothFrame` 平滑外框模式下，共享焦点框必须始终跟随封面区域本身，不能短暂包住标题、副标题或整张卡片；当焦点切到下一行并触发自动滚动时，外框要优先贴住新的封面位置，不能因为追逐滚动动画而扫到文字区域。

TV 页面左右统一边距由 `TvLayout.pageHorizontalPadding` 集中控制，当前值为 `40px`，供顶部导航、首页横向分区、分类筛选区、纵向 Grid、搜索页、设置页和详情页共用。横向列表如果需要避免获焦放大裁切，可在页面边距基础上追加列表自己的焦点安全留白，不得把列表安全留白误写成页面统一边距。纵向 Grid 在 1080p 主场景下固定为 `7` 列，避免不同页面因为可用宽度变化出现列数抖动。

纵向 Grid 需要支持焦点驱动的提前分页：当当前焦点进入底部倒数第二行时，触发下一页加载。加载中、无更多数据或同一批数据已触发过时不能重复请求；新页数据追加后才允许下一次触发。电影、剧集、动漫、综艺分类页使用豆瓣推荐接口的 `page` 参数执行真实分页，并按 `source + id` 去重追加；播放历史和收藏夹当前服务层一次性返回完整列表，暂不伪造分页。

TV 焦点控件进入纵向滚动视口时，必须自动触发平滑滚动，把当前焦点移动到视口偏上的稳定浏览位置。首页横向分区卡片获焦时按区块整体滚动，形成更明显的整行上移效果；播放历史、收藏夹、电影、剧集、动漫、综艺等纵向 Grid，以及详情页、搜索页、设置页中的上下滚动内容，复用 `TvFocusable` 的自动滚动能力。设置页输入框因直接使用 `TextField`，需要单独接入同一套滚动辅助。

纯文字型焦点列表（例如分类筛选项、搜索历史/热词、设置页文字选项）在长按方向键时，必须保留逐项经过的中间选中态，不能直接跳过中间项。实现上允许 `TvFocusable` 对同一文字列表分组启用重复方向键冷却，吞掉过密的 `KeyRepeatEvent`；海报卡片、顶部主导航、播放器菜单等非文字列表保持原有焦点节奏，不强制复用该节流。

原生 Kotlin TV 表单输入行通过 `onPreviewKeyEvent` 自定义上、下焦点链时，只有对应 `onArrowUp` 或 `onArrowDown` 回调存在且实际负责转交焦点，才可以消费该方向键；没有回调时必须返回 `false`，交还 Compose 默认空间导航。不得出现“返回 `true` 但未请求相邻焦点”的分支，否则页面首个输入行会阻断整页的方向键浏览。`TvFormTextFieldFocusContractTest` 必须覆盖无回调时不消费上下键的回归场景。

电影、剧集、动漫、综艺四个分类页只有在顶部导航对应菜单项已获得焦点时，按确认键才呼出 TV 分类筛选面板。对应分类页标题右侧需要提供一条弱提示文案，例如“按确认键打开分类筛选”，帮助用户理解入口，但提示字号和颜色都要克制，不能压过页面标题。直播菜单项不呼出筛选面板，确认键进入独立直播占位页；主菜单所有项按上方向键都进入右上角搜索快捷入口。右上快捷入口按下方向键必须回到进入快捷区前的来源主菜单项，没有来源记忆时才回直播兜底，左右方向键不负责主菜单和快捷区的跨区跳转。内容区卡片或 Grid 按上方向键必须先按正常焦点逻辑回到顶部导航，不能直接呼出筛选面板。筛选面板包含排序、类型、地区、年份四行，每行第一个选项必须是「全部」，后续选项使用横向列表展示。每一行横向列表必须裁剪到选项视口内，避免横向滚动时覆盖左侧「排序:」「类型:」等行标题；首尾选项继续按左右方向键必须触发边界抖动并保持当前行焦点，长按左右键不能跳到其它筛选行。确认键选中筛选项后，必须记录当前分类的筛选条件，立即执行对应豆瓣推荐查询，并用查询结果刷新下方 Grid；请求中展示 Grid 骨架，不再继续显示旧列表。面板呼出时顶部导航淡出并收起，筛选面板从顶部缓慢下滑展开，Grid 留在正常布局流中被面板向下顶开，不能遮住卡片。面板呼出后标题提示文案需要随筛选面板一起隐藏，避免和筛选区内容重复。筛选面板必须使用半透黑色背景遮罩，避免滚动卡片和筛选项文字重叠。面板呼出后焦点默认落到第一行「全部」，便于继续用左右方向键选择筛选项。返回键必须先关闭筛选面板并恢复顶部导航。播放历史和收藏夹不接入该筛选面板，继续保持原有纵向 Grid 行为。

分类筛选面板需要支持两种展示态：焦点停留在顶部筛选区时展示完整四行展开态；焦点下移到分类 Grid 浏览内容时，同一块区域自动切换成更紧凑的一行摘要态，仅保留当前排序、类型、地区、年份结果，给下方列表释放更多高度。摘要态下 Grid 首行卡片继续按上方向键时，必须先把筛选区恢复为完整展开态，再按既有焦点逻辑回到顶部。展开态的行高、按钮高度、字号和间距需要比初版更紧凑，保证筛选区整体高度收敛。

展开态筛选项需要明显收窄，单个按钮宽度控制在约 `56~96px`，让同一行首屏内露出更多选项。每一行右侧还要贴边提供一个浅色箭头和渐变遮罩提示，视觉上暗示后方还有更多可横向浏览的选项，箭头尽量贴近列表可视区域的最右侧边缘。

除首页外，顶部固定导航区域必须使用半透黑色背景遮罩，且内容区域外层需要裁剪滚动内容，避免 Grid 向上滚动时海报覆盖顶部菜单文字。首页保持透明顶部导航效果。

### 4.3 TV 卡片契约

| 字段 | 当前值 |
|------|--------|
| `TvVideoCard.width` | `158` |
| `TvVideoCard.height` | `296` |
| `TvVideoCard.coverHeight` | `237` |
| `TvVideoCard.focusedScale` | `1.08` |
| 标题行数 | `1` |
| 焦点边框范围 | 仅封面 |
| 焦点放大范围 | 整张卡片 |
| 横向列表首尾安全留白 | `10dp`，只用于获焦放大，不能重复叠加页面 `40dp` 安全边距 |
| 纵向 Grid 左右安全留白 | `10dp`，页面壳内使用，避免首列二次缩进 |
| 封面加载骨架 | 图片首次加载和网络加载中展示 |
| 骨架雨刷方向 | `Alignment.topLeft` 到 `Alignment.bottomRight` |
| 多集进度徽章 | `totalEpisodes > 1` 且 `index > 0` 时在封面右上角展示 `index/totalEpisodes` |
| 播放进度条 | `progressPercentage > 0` 时在封面底部展示播放进度条 |

### 4.4 TV 详情页契约

| 操作 | 预期 |
|------|------|
| 卡片点击 | 打开 `TvVideoDetailScreen` |
| 详情加载 | 精确源详情与标题补源并行启动；任一任务先拿到可播源就先渲染详情并起播，标题补源结果后续增量追加 |
| 性能探针 | `--dart-define=SELENE_TV_PERF_TRACE=true` 开启 TV 性能探针；详情页必须把 init、续播记录、配置预热、精确源、后台补源、首个可播源、播放器控制器、`updateDataSource`、真实进度恢复和推荐加载写入 Timeline 与 `[TV PERF]` 日志 |
| 顶部说明 | 顶部展示 `IvyTV` 与 `按返回键返回上一页 | 全屏时向下键可进行播放设置（倍数，其它）`，不得出现「内核」相关字样 |
| 顶部快捷 | 顶部右侧展示搜索按钮和当前系统时间；搜索按钮打开 `TvSearchScreen`，当前时间以 `HH:mm` 格式定时刷新 |
| 详情页基础背景 | 进入详情页时必须读取设置页保存的背景键；`deep_blue / pure_black / dark_purple / deep_green` 映射到共享设计 Token，未知值回退深蓝，海报缺失时同样使用该背景色 |
| 继续观看 | 根据播放记录恢复对应集数与秒数，例如第 497 集从记录秒数继续播 |
| 首播门闩 | 详情页进入后只允许“首个可播源命中”和“首次 `updateDataSource(startAt)`”留在首播门闩内，其它配置读取和推荐任务不得阻塞 |
| 进度上报 | 内嵌播放器进度变化时保存当前源、集数、播放秒数和总时长 |
| 换源 | 切换 `currentDetail`，保留当前集数和播放秒数，保存新源记录成功后再清理旧源记录 |
| 选集 | 更新 `_episodeIndex` 并刷新内嵌播放器 |
| 换源布局 | 标题展示为「切换线路」，并补充 `遇播放卡顿，音画不同步或无法播放时，请切换播放线路`；单行横向列表，不使用多行换行布局；线路展示为 `线路名（集数）`，并按集数倒序排列，相同集数保持原始返回顺序；线路卡片获焦必须使用 `TvVideoCard.focusedScale` 与影视卡片一致放大；换源卡片按上方向键必须按实际位置就近回到播放器、全屏或收藏按钮；全屏和收藏按钮按下方向键必须优先回到当前选中的播放源，当前源未构建时才回到第一个已构建源，避免依赖几何焦点导致丢焦或跳到非当前源；线路行与选集行之间上下移动时必须按当前焦点水平位置选择目标行最近可见项，不得优先恢复上次停留项；焦点中心超过横向视口 50% 后才开始平滑滚动；首尾继续按左右只触发当前项边界抖动，不能跳到其它列表 |
| 选集布局 | 单行横向集数列表在上，分组标签在集数列表下方；分组标签字号必须与全屏播放选集分组一致使用 17 号；总集数不超过 20 集时不展示分组，长剧集按固定区间切换；分组标签通过上下或左右获焦时只更新焦点和滚动位置，不得刷新当前选集范围；只有确认键或点击分组标签才切换分组；选集卡片和分组标签获焦必须使用 `TvVideoCard.focusedScale` 与影视卡片一致放大；换源、选集、分组和相关推荐之间必须设置明确的上下焦点目标，向下按顺序进入下一块，向上回到就近的上一块；选集行和分组行之间上下移动时必须按当前焦点水平位置选择目标行最近可见项，不得优先恢复上次停留项；详情页所有横向列表首尾必须按获焦放大尺寸预留安全留白，确保长按到右端再回到首项时焦点框不会贴边或被裁剪；集数列表和分组列表焦点中心超过横向视口 50% 后才开始平滑滚动；选集卡片左右键必须显式处理相邻集数或跨组边界，不能交给默认焦点遍历落到分组行；有分组时，当前选集列表最后一项按右键必须无缝切到下一组第一集，当前选集列表第一项按左键必须无缝切到上一组最后一集，并继续保持选集焦点；首组左边界、最后一组右边界或无分组时才触发当前项边界抖动，不能跳到其它列表 |
| 内嵌播放器 | 关闭播放器控制层和 PiP/小窗最小化能力，焦点确认只用于进入全屏；无播放 URL 的预览占位态不得提前拉起重型 WebView HTML/JS 初始化；播放中在视频底部叠加精简版进度条（含缓冲段），用 `IgnorePointer` 包裹不拦截焦点 |
| 详情页进度条 | 比全屏版略小（轨道 4px，圆点 10x10，字号 14），无全屏按钮，与全屏版同步显示缓冲段；仅当 `_previewPlaybackStarted && _currentDetail != null` 时展示；缓冲数据从 `_playerController.cachedRanges` 读取 |
| 预览 loading | 详情页小播放器关闭 `VideoPlayerWidget.showLoadingIndicator` 后，外层必须用 `tv-detail-preview-loading` 承担转圈和网速反馈；加载转圈使用单 `CircularProgressIndicator` + `BoxShadow`（`alpha: 0.32, blurRadius: 4, offset: (2, 2)`），不得使用双 spinner 重叠；已有可播源、控制器晚挂、续播记录未返回导致首播挂起、首帧黑底或缓冲时必须显示；只有当前播放时间点从本轮 loading 锚点向前推进后才能收起，`ready`、`play`、`isPlaying` 或 `isLoading=false` 不得单独清理；网速优先显示播放器控制器的真实下载速度，未知或暂无样本时才回退 `0KB/s`；overlay 必须无背景且 `IgnorePointer`，不得阻断遥控器焦点进入线路、选集或全屏按钮 |
| 全屏 loading | 全屏播放器同样使用单圈 + `BoxShadow` 投影（同预览 loading 参数），圈颜色为白色（黑底），不得使用双 spinner 重叠 |
| 全屏 | 详情页内展示 `TvFullscreenPlayerScreen` 覆盖层，携带当前详情、线路列表和集下标；生产路径必须通过同一个 `VideoPlayerWidget`/控制器在预览和全屏之间移动，避免进入全屏时重新起播或黑屏；TV 全屏播放器同样禁用 PiP/小窗最小化 |
| 收藏 | 使用 `PageCacheService.addFavorite/removeFavorite` |
| 影片简介浮层 | 直接覆盖在当前详情页上并复用详情页现有背景，不传入或加载独立海报；Android 12+ 打开时整体模糊下方详情内容，旧系统改为淡化内容层以避免文字重叠；浮层自身保持清晰并叠加半透明黑色遮罩，返回键仅关闭简介浮层 |
| 推荐焦点 | 任意相关推荐卡片获焦时，详情页外层滚动必须直接到达底部，确保推荐区和底部操作同时露出 |
| 推荐点击 | `pushReplacement` 到新的 TV 详情页 |
| 回到顶部 | 当前详情页滚动到顶部 |
| 返回上一级 | 不显示页面级按钮，直接依赖遥控器返回键 |

详情页选集跨组补充契约：
- 选集卡片左右键跨组期间，重建过渡帧必须继续限制焦点停留在选集链路内；目标集数获焦前，不得让播放器、线路、分组、相关推荐或底部操作成为 `FocusScope` 的临时回退目标，避免推荐区历史焦点闪现后再跳回选集。

Kotlin TV 详情页焦点滚动契约：
- `TvDetailRoute` 的线路、选集和选集分组横向轨道必须分别持有 `rememberSaveable(saver = LazyListState.Saver)` 创建的 `LazyListState`，并传入对应 `LazyRow(state = ...)`。
- 横向轨道 item 获焦时必须在 `onFocusChanged` 内调用统一滚动 helper，根据 `TvListLayoutMetrics.resolveRailFirstVisibleItemIndex(focusedIndex, itemCount)` 计算目标首个可见项，再执行 `listState.animateScrollToItem(targetIndex)`；只接 `FocusRequester` 不能算完成，因为默认几何焦点会把靠右选项移出可视区。
- 推荐横向海报轨道继续复用 `TvPosterRail` 的内置获焦滚动，不在详情页重复实现。
- 详情页焦点滚动改动必须补源码契约或等价 Compose 焦点测试，至少断言 `LazyListState.Saver`、`onFocusChanged`、统一滚动 helper 和 `animateScrollToItem` 同时存在。

TV 详情页加载错误契约：

| 场景 | 预期 |
|------|------|
| 精确源详情失败 | 标记精确源加载完成，继续等待标题补源增量结果，不阻塞页面后续起播 |
| 标题补源失败 | 标记后台补源完成；如果已有精确源则保持播放，如果仍无源则结束首屏转圈并展示空源/空选集状态 |
| 推荐加载失败 | 仅保持相关推荐为空，不影响播放器和换源列表 |
| 增量补源重复返回同一 `source + id` | 去重后不重复展示线路 |
| 旧 `loadDetail` 测试入口 | 只用于兼容既有 widget test；生产默认路径不得等待推荐和全量补源完成后才渲染 |

### 4.4.1 继续播放续播源匹配契约

从继续观看进入详情页时，必须等待流式搜索命中续播记录中的源：

```dart
// 续播源目标：从 PlayRecord 提取 source + id
({String source, String id})? _resumeSourceTarget;

bool _sourceMatchesResumeTarget(SearchResult detail) {
  final target = _resumeSourceTarget;
  if (target == null) return true; // 无续播目标，任何源可播
  return detail.source == target.source && detail.id == target.id;
}
```

实现要求：
- 进入详情页后同时发起续播记录加载和源搜索，互不阻塞。
- 续播记录返回后设置 `_resumeSourceTarget`。
- 源到达后先检查 `_sourceMatchesResumeTarget()`，不匹配则暂不起播，继续等待。
- 精确源搜索和标题补源都完成后仍无命中时，回退用最佳可用源起播。
- 非续播路径（直接点卡片进入）`_resumeSourceTarget` 为 null，任何源立即起播。
- ESC 在等待期间可随时打断（见 4.4.2）。

测试要求：
- 测试必须覆盖续播目标命中后起播。
- 测试必须覆盖搜索完成未命中后的回退起播。
- 测试必须覆盖无续播记录时立即起播。

### 4.4.2 详情页返回高优先级打断契约

详情页退出必须优先销毁 UI，保存逻辑不得阻塞路由弹出：

```dart
Future<void> _handleDetailBackPressed() async {
  if (_isExitingDetail) return;
  _isExitingDetail = true;                // ← 必须最先设置
  unawaited(_saveProgress(force: true));  // ← 后台保存，不 await
  if (mounted) {
    Navigator.of(context).maybePop();     // ← 立即退出
  }
}
```

实现要求：
- `_isExitingDetail` 必须在任何 await 之前设置为 true。
- 进度保存使用 `unawaited`，不得 await 阻塞退出。
- 使用 `maybePop` 而非 `pop`，避免路由已不在栈上时崩溃。
- 所有异步回包处理（搜索、续播记录、ad filter、player kernel、controller 创建）必须在处理前检查 `mounted && !_isExitingDetail`。
- 所有 `addPostFrameCallback` 回调必须在执行前检查 `mounted && !_isExitingDetail`。
- `dispose()` 中检查 `_hasManuallySavedOnExit` 避免重复保存。
- 全屏播放器退出逻辑不受影响（已有同策略的 `_handleExitWithSave`）。

测试要求：
- 测试必须覆盖返回后路由立即消失。
- 测试必须覆盖 exit 标志设置后的回调被正确丢弃。
- 测试必须覆盖 dispose 不重复保存。

#### Wrong

```dart
// 错误：await 等数据库写入完成才 pop，UI 冻结
Future<void> _handleDetailBackPressed() async {
  if (_isExitingDetail) return;
  await _saveProgress(force: true);  // 阻塞！
  _isExitingDetail = true;            // 太晚！
  Navigator.of(context).pop();
}
```

#### Correct

```dart
// 正确：先设退出标志，unawaited 保存，立即 pop
Future<void> _handleDetailBackPressed() async {
  if (_isExitingDetail) return;
  _isExitingDetail = true;
  unawaited(_saveProgress(force: true));
  if (mounted) {
    Navigator.of(context).maybePop();
  }
}
```

### 4.9 TV 全屏播放器契约

| 操作 | 预期 |
|------|------|
| 顶部左侧 | 只展示返回图标、标题和当前集信息，不可点击 |
| 顶部右侧 | 只展示装饰图标，不可点击 |
| 下方向键 | 当前无菜单时弹出底部一二级菜单 |
| 一级菜单 | 焦点移入即切换二级菜单，不需要按确认 |
| 一级菜单上键 | 焦点进入当前一级菜单对应的二级菜单选中项 |
| 二级菜单 | 只有二级菜单按钮执行实际操作 |
| 二级菜单下键 | 焦点回到当前一级菜单项 |
| 禁用菜单 | 不展示「清晰度」和「内核」 |
| 底部弹框样式 | 背景必须保留视频可见度，不使用过实遮罩；一级菜单保持原字号和尺寸，普通二级菜单文字比一级菜单小 2 号，选集分组标签使用 17 号；一级菜单获焦必须使用 `TvVideoCard.focusedScale` 与影视卡片一致放大；播放列表和播放线路属于内容卡片，卡片尺寸保持约 2/3 缩放，不得套用一级菜单按钮尺寸；画面比例、倍速和其它属于非内容型二级菜单，宽度保持缩小尺寸，高度在缩小基础上增加 1/3，二级按钮获焦必须使用 `TvVideoCard.focusedScale` 放大；底部一级菜单行必须贴底固定，切换不同高度二级菜单时不得上下跳动；弹框顶部必须按当前二级菜单实际高度收紧，非选集菜单不得保留大块顶部空白 |
| 播放器画面层 | 底部菜单显隐、一级/二级菜单焦点切换、自动隐藏、顶部时钟和 seek 提示都属于壳层 UI 状态，不得重建底层 `VideoPlayerWidget` 或 Android 平台视图；只有选集、线路、画面比例、去广告配置、播放器 builder 等真正影响播放器配置的字段变化时才允许失效缓存 |
| 播放列表 | 横向展示当前源选集，选集标题不得省略，选集卡片必须给足宽高并让横向列表视口高度同步增高，文本边界必须落在卡片边框内，确认后切换选集；分组标签通过上下或左右获焦时只更新菜单焦点和滚动位置，不得刷新当前播放列表分组；只有确认键或点击分组标签才切换分组；选集卡片和分组标签获焦必须使用 `TvVideoCard.focusedScale` 与影视卡片一致放大；播放列表一级菜单上键必须优先进入当前或最近选集行，不得先落到分组行，避免当前集数左移时被分组焦点劫走；选集行和分组行之间上下移动时必须按当前焦点水平位置选择目标行最近可见项，不得优先恢复上次停留项；选集卡片左右键必须显式处理相邻集数或跨组边界，不能交给默认焦点遍历落到分组行；有分组时，当前组选集最后一项按右键必须切到下一组第一集，当前组选集第一项按左键必须切到上一组最后一集，并保持在播放列表选集行；首组左边界、最后一组右边界或无分组时才触发边界抖动 |
| 播放线路 | 横向展示可用线路，线路卡片必须比普通菜单按钮更宽更高，线路名和集数完整展示在卡片边框内；线路展示为 `线路名（集数）`，并按集数倒序排列；线路卡片获焦必须使用 `TvVideoCard.focusedScale` 与影视卡片一致放大；播放线路一级菜单上键进入线路行时必须按当前焦点水平位置选择最近可见线路，不得优先恢复上次停留线路；确认后切换线路并保留当前集数和播放秒数 |
| 画面比例 | 选项文案与手机端播放器设置一致：适应、填充、宽度、高度 |
| 倍速 | 提供常用倍速，确认后调用播放器倍速切换 |
| 其它 | 展示片头、片尾和弹幕开关入口；片头/片尾上方展示“确认/空格/Enter 设置当前时间，长按清空”提示；短按确认、空格或 Enter 保存当前播放时间点，长按清空对应配置 |
| 底部进度条 | 当前时间和总时长必须使用稳定宽度的时间槽位，并启用等宽数字；长按快进/快退时，进度轨道起止位置不能因为时间文本变化而左右跳动；播放中进度条常驻显示，不再仅在暂停/seek 时出现；菜单打开或加载中时隐藏 |
| 底部进度条缓冲段 | 在已播放轨道和背景轨道之间叠加浅灰色缓冲段（`Colors.white.withValues(alpha: 0.24)`），数据来自 `TvFullscreenPlaybackController.cachedRanges`，通过 `resolvePlayerCachedProgressSegments()` 计算分段位置；缓冲显示范围截断至当前播放位置 + 3 分钟 |
| 底部进度条尺寸 | 轨道高度 6px，当前时间圆点 15x15；圆点居中偏移量 `knobLeft = (playedWidth - 7.5).clamp(0.0, trackWidth - 15.0)` |
| 菜单未弹出时确认键 | 切换播放和暂停，不弹出底部菜单 |
| 菜单未弹出时左右键 | 短按跳转 10 秒；长按 250ms 后按 100ms tick 连续跳转，未满 4 秒每 tick 12 秒，达到 4 秒后每 tick 22 秒，按住 10 秒约跨越 30 分钟 |
| 左右键进度提示 | 屏幕中心展示浅灰圆角时间提示，格式为 `当前时间 / 总时长` |
| seek 后 loading | 短按或长按 seek 后应显示无背景的 `tv-fullscreen-loading` 与网速反馈；长按松手后先收起 seek 中心提示和底部进度壳层；只有当前播放时间点从本轮 seek/loading 锚点向前推进后才能收起，`ready`、`play`、`isPlaying` 或 `isLoading=false` 不得单独清理；复用详情页播放器时全屏壳必须监听真实 `VideoPlayerWidgetController` 的进度事件，避免底层 `isLoading` 滞留或缺少全屏页本地 controller 时转圈永久残留；网速优先复用播放器控制器真实下载速度，未知或暂无样本时才回退 `0KB/s` |
| 底部提醒 | 菜单未弹出时展示返回键、下键和安全提醒文案 |
| 返回键 | `Esc`、遥控器返回键和系统返回统一处理；菜单已弹出时先关闭菜单；无菜单时退出全屏回到详情页 |

#### 原生播放器内核协议

```kotlin
interface PlayerEngine {
    val state: StateFlow<PlayerState>
    suspend fun load(request: PlaybackRequest)
    suspend fun play()
    suspend fun pause()
    suspend fun seekTo(positionMs: Long)
    suspend fun captureSnapshot(): PlaybackSnapshot
    suspend fun restoreSnapshot(snapshot: PlaybackSnapshot)
    suspend fun release()
}

data class PlaybackSnapshot(
    val videoId: String,
    val sourceId: String,
    val episodeId: String,
    val url: String,
    val positionMs: Long,
    val durationMs: Long,
    val playbackSpeed: Float,
    val resizeMode: TvResizeMode,
)
```

实现要求：

- `core-player-api` 只定义播放器协议、播放请求、播放快照、状态和画面比例枚举，不依赖 ExoPlayer 或 WebView。
- `core-player-exo` 是 ExoPlayer 主内核实现，必须依赖 `DispatcherProvider.playback` 执行 `load / play / pause / seekTo / restoreSnapshot / release` 等播放控制动作。
- `PlaybackSnapshot` 必须保留 `videoId / sourceId / episodeId / url / positionMs / durationMs / playbackSpeed / resizeMode`，用于全屏切内核后恢复当前线路、剧集、进度、倍速和画面比例。
- `TvSeekController.computeDeltaSeconds(holdMs)` 的规则固定为：`holdMs < 250` 返回 10 秒，`250 <= holdMs < 4000` 返回 12 秒，`holdMs >= 4000` 返回 22 秒。
- `TvSeekController.computeDisplayPositionMs(...)` 只负责中心提示的可读性：秒个位按物理秒慢变，真实 seek 目标、进度条和 loading 锚点仍使用实际位置。
- ExoPlayer 和 WebView 兜底内核都必须实现 `PlayerEngine`，全屏播放器壳只依赖协议，不直接引用具体内核类。
- 全屏播放器底部弹框进入「其它」后，必须展示 `内核切换` 入口；切换状态机要先从当前内核 `captureSnapshot()`，再对目标内核执行 `load + restoreSnapshot`，最后释放旧内核。
- WebView 兜底链路的 JS 桥至少要上报 `positionMs / durationMs / isPlaying` 三个字段，原生桥接层负责把 JSON 映射成可驱动 UI 的播放事件。

测试要求：

- `PlaybackSnapshotTest.snapshot_keeps_source_episode_position_speed_and_resize_mode` 覆盖快照恢复字段。
- `ExoPlayerEngineTest.seekTo_runs_on_playback_dispatcher` 覆盖 seek 不在主线程直接执行。
- `TvSeekControllerTest.longPress_seek_delta_changes_gear_at_four_physical_seconds` 覆盖 4 秒换挡。
- `TvSeekControllerTest.continuousSeek_ten_second_hold_travels_about_thirty_minutes` 覆盖 10 秒累计约 30 分钟。
- `TvSeekControllerTest.displayPosition_seconds_ones_advances_once_per_physical_second` 覆盖秒个位慢变。
- `TvPlayerRouteControlContractTest.route_direction_key_up_branch_stops_continuous_seek_before_consuming_event` 覆盖松手立即停止内部任务。
- `TvPlayerEngineSwitcherTest.switchEngine_restores_snapshot_on_target_engine` 覆盖 Exo -> WebView 切换恢复。
- `WebViewPlayerBridgeTest.onPlaybackEvent_maps_js_payload_to_player_state` 覆盖 JS 事件桥接。

#### 原生共享播放会话契约

##### 1. Scope / Trigger

- Trigger: 修改 Kotlin TV 详情页预览、全屏播放器、播放器导航、WebView 播放页复用或播放器会话释放边界。
- Scope: `re-android/app-tv`、`re-android/feature-tv-detail`、`re-android/feature-tv-player`、`re-android/core-player-api`、`re-android/core-player-webview`。
- This contract exists to keep detail preview -> fullscreen transition smooth without merging the two pages into one file.

##### 2. Signatures

```kotlin
data class TvSharedPlaybackContext(
  val request: PlaybackRequest,
  val sources: List<PlaybackSource> = emptyList(),
  val episodes: List<PlaybackEpisode> = emptyList(),
)

class TvSharedPlayerSession(
  val kernel: String,
  val playerEngine: PlayerEngine,
  val exoEngine: ExoPlayerEngine? = null,
  val webViewSession: WebViewPlayerSession? = null,
)

class TvSharedPlayerHost(
  createExoSession: () -> TvSharedPlayerSession,
  createWebViewSession: () -> TvSharedPlayerSession,
) {
  var currentKernel: String?
  var currentContext: TvSharedPlaybackContext?

  fun openOrReuseSession(kernel: String): TvSharedPlayerSession
  fun updatePlaybackContext(
    request: PlaybackRequest,
    sources: List<PlaybackSource> = emptyList(),
    episodes: List<PlaybackEpisode> = emptyList(),
  )
  suspend fun clearPlaybackFlow()
}

fun PlaybackRequest.toPlaybackIdentity(): PlaybackIdentity
fun PlaybackSnapshot.toPlaybackIdentity(): PlaybackIdentity
fun PlaybackRequest.matchesPlaybackSnapshot(snapshot: PlaybackSnapshot?): Boolean
fun PlayerState.snapshotOrNull(): PlaybackSnapshot?
fun PlayerState.matchesPlaybackRequest(request: PlaybackRequest): Boolean
```

##### 3. Contracts

- 详情页和全屏页继续保持独立 route、独立文件、独立 ViewModel；共享的是播放器会话，不是把两页 UI 合并成一个页面。
- `TvNavGraph` 顶层必须持有唯一 `TvSharedPlayerHost`，详情页和全屏页都从宿主读取同一份 `TvSharedPlayerSession`。
- `TvSharedPlayerHost.currentContext` 是当前播放流的主上下文来源；旧的 `TvPlaybackRequestStore` 只能作为过渡回退，命中后要回写宿主。
- 详情页预览起播前和全屏页 `loadInitialRequest()` 前，都必须先用 `PlayerState.matchesPlaybackRequest(request)` 判断当前引擎是否已经承载同一媒体。
- “同一媒体”只比较 `videoId / sourceId / episodeId / url`；`startPositionMs`、倍速、画面比例不参与“是否重载”的身份判断。
- WebView 链路必须复用 `WebViewPlayerSession` 持有的唯一 `WebView`；同一 `playbackUrl` 只允许重新挂载 View，不允许再次 `loadUrl(...)`。
- `WebViewPlayerSurface` 只负责消费共享 session、挂载 WebView 和分发命令；WebView 设置、JS bridge、资源错误日志和页面 reload 判定都归 `WebViewPlayerSession`。
- 详情页和全屏页同时处于导航过渡组合树时，只有当前活跃 route 可以持有播放器画面输出；`ExoPlayerSurface` 必须先解绑失活 `PlayerView`，再由活跃页面下一帧接管，`WebViewPlayerSurface` 必须把共享 `WebView` 重新挂到活跃页面的独立容器。
- 全屏播放器根节点必须主动请求焦点，菜单关闭后必须把焦点交还根节点；`PlayerView`、`WebView` 等平台画面层不得抢占遥控器或键盘焦点。
- 系统返回键只能由 `BackHandler` 处理一次；键盘 `Esc` 可以走 Compose 按键链路，但不得同时再监听 `Key.Back` 导致菜单关闭和退出连续执行。
- 共享会话只允许在离开整条播放流后释放；播放流内允许保活的 route 至少包含 `detail`、`player`、`danmakuMatch`。

##### 4. Validation & Error Matrix

- 当前 `PlayerState` 与目标 `PlaybackRequest` 媒体身份一致 -> 只同步状态，不调用新的 `engine.load(...)`。
- `PlaybackRequest.url` 为空或空白 -> `WebViewPlayerSession.attachPlaybackRequest()` 直接返回，不触发 `loadUrl(...)`。
- `sharedPlayerHost.currentContext == null` 且 `TvPlaybackRequestStore` 命中 -> 允许回退恢复，但必须立即 `updatePlaybackContext(...)` 回写宿主。
- 详情页或全屏页在播放流内部切换 route -> 不得调用 `clearPlaybackFlow()`，否则会导致预览 -> 全屏重新建播放器。
- 全屏返回详情页且媒体身份未变化 -> 不重新 `load(...)`，但必须重新绑定活跃画面输出并触发平台视图重绘，不能出现声音继续、画面黑屏。
- 当前 route 离开播放流集合 -> 必须 `clearPlaybackFlow()`，统一释放 Exo/WebView 会话和播放上下文，避免串到下一部片。
- `WebView` JS bridge 回调抛异常或 JSON 映射失败 -> 只记日志，不得打断整个 HLS 页面事件链。

##### 5. Good/Base/Bad Cases

- Good: 详情页预览已经在播第 3 集，进入全屏时全屏页直接接管同一会话，画面不中断，也不重新缓冲。
- Base: 全屏页首次打开时宿主上下文为空，但旧 `requestId` store 仍有数据，播放器页先用回退上下文起播，再把上下文回写到宿主。
- Bad: 详情页和全屏页各自创建一套 WebView / PlayerEngine，或把 `startPositionMs` 变化误判成新媒体，导致切全屏时再次 `load(...)`。

##### 6. Tests Required

- `TvSharedPlayerHostTest.openOrReuseSession_reuses_existing_session_for_same_kernel` 覆盖同内核会话复用。
- `TvSharedPlayerHostTest.clearPlaybackFlow_releases_cached_sessions_and_context` 覆盖离开播放流后的统一释放。
- `TvDetailViewModelTest.load_skips_preview_reload_when_engine_already_has_same_media` 覆盖详情页预览幂等加载。
- `TvPlayerViewModelTest.loadInitialRequest_skips_reload_when_engine_already_has_same_media` 覆盖全屏页幂等加载。
- `WebViewPlayerSurfaceContractTest.webview_player_session_reuses_single_webview_instance` 覆盖 WebView 单实例复用。
- `WebViewPlayerSurfaceContractTest.webview_player_surface_reattaches_shared_view_to_active_route_container` 覆盖 WebView 返回页面后的重新挂载。
- `ExoPlayerSurfaceContractTest.exo_surface_rebinds_video_output_when_route_becomes_active` 覆盖 Exo 画面输出所有权交接。
- `TvPlayerRouteControlContractTest.route_requests_root_focus_for_fullscreen_keyboard_controls` 覆盖全屏按键焦点。
- `TvNavGraphPlayerContractTest.player_route_shares_webview_session_between_view_model_and_surface` 覆盖导航层共享会话接线。

##### 7. Wrong vs Correct

**Wrong**

```kotlin
val detailSession = appContainer.createWebViewPlayerSession()
val playerSession = appContainer.createWebViewPlayerSession()

detailSession.engine.load(request)
playerSession.engine.load(request)
```

**Correct**

```kotlin
val sharedSession = sharedPlayerHost.openOrReuseSession(playerKernel)

if (!sharedSession.playerEngine.state.value.matchesPlaybackRequest(request)) {
  sharedSession.playerEngine.load(request)
}
```

### 4.5 TV 设置输入框契约

| 状态 | 预期 |
|------|------|
| 焦点移入 | 输入框保持 `readOnly=true`，不弹系统键盘 |
| 按确认键 | 输入框进入编辑态，`readOnly=false`，主动显示键盘 |
| 鼠标点击输入框 | 进入编辑态，用于桌面调试 |
| 编辑完成 | 退出编辑态并隐藏键盘 |
| 焦点离开 | 退出编辑态，避免下次移入直接弹键盘 |

### 4.6 TV 图片代理契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `图片代理` |
| 存储复用 | `UserDataService.saveDoubanImageSource` |
| 读取复用 | `UserDataService.getDoubanImageSourceDisplayName` |
| 生效链路 | `getImageUrl` 根据 `getDoubanImageSourceKey` 替换豆瓣图片域名 |
| 可选项 | `直连`、`豆瓣官方精品 CDN`、`豆瓣 CDN By CMLiussss（腾讯云）`、`豆瓣 CDN By CMLiussss（阿里云）` |
| 交互 | 选中后立即保存，并显示 `图片代理已保存` |

### 4.7 TV 缓存管理契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `缓存管理` |
| 缓存大小 | 设置页展示图片、临时目录与豆瓣业务缓存合计占用 |
| 手动清理 | `清除所有缓存` 清理业务运行缓存、图片磁盘缓存、临时目录和 HLS 脚本缓存 |
| 配置保留 | 不清理服务器地址、账号、密码、主题色、弹幕设置和图片代理设置 |
| 启动清理 | 每次进入 App 前清理非配置类运行缓存和内存图片缓存 |
| 图片默认缓存 | TV 影视封面默认使用 `CachedNetworkImage` 写入磁盘缓存，减少重复请求 |
| 低空间策略 | Android 可用空间低于 200MB 时清理图片磁盘缓存，并暂时不再写入新的图片磁盘缓存 |

### 4.8 TV 主题色契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `主题色` |
| 存储 | `TvThemeService.storageKey` |
| 默认主题 | `Ivy 绿` |
| 新增主题 | `奈飞红`，主色 `#E50914` |
| 生效范围 | TV 顶部导航、卡片焦点、详情页按钮、设置页选中态、开关和滑杆 |
| 普通端影响 | 不影响普通端 `ThemeService` |

## 5. Validation & Error Matrix

| 风险 | 处理方式 | 测试点 |
|------|----------|--------|
| 非 TV 端被误导到 TV App | `DeviceModeConfig` 和原生判断分层 | `app_device_service_test.dart` |
| TV 首页数据加载失败 | 单个分区 catch 后返回空列表 | 首页空数据测试 |
| 首页横向分区无限展示 | `TvHomeSection.maxVisibleVideos=15`，超出后展示封面高度“查看更多”卡片 | `tv_home_section_test.dart` / `tv_home_screen_test.dart` |
| 历史或收藏无数据 | 展示空状态 | `tv_home_screen_test.dart` |
| 详情页共享搜索会话仍在进行中 | 继续复用搜索页 SSE 增量结果，不重复发起标题补源 | `tv_video_detail_screen_test.dart`, `tv_search_screen_test.dart` |
| 详情页被收藏态/广告偏好/代理预热卡住首播 | 这些任务只允许后台回填，不得阻塞首个可播源起播 | `tv_video_detail_screen_test.dart` 可新增 |
| 详情页空播放器壳过早初始化重 WebView | 无播放 URL 时只保留轻量占位态，首个可播源到达后才执行重初始化 | `tv_video_detail_screen_test.dart`, `video_player_widget_preload_config_test.dart` 可新增 |
| 详情页补源完成后仍无可用源 | 展示带图标的“搜索已完成，未找到可播放信息”空态 | `tv_video_detail_screen_test.dart` |
| 详情页无选集 | 展示「暂无选集」 | `tv_video_detail_screen_test.dart` 可扩展 |
| 详情页无推荐 | 展示「暂无推荐」 | `tv_video_detail_screen_test.dart` 可扩展 |
| 详情页换源或选集换行 | 使用横向 `ListView`，选集长列表先按分组切换 | `tv_video_detail_screen_test.dart` |
| 详情页显示返回按钮 | 不展示“返回上一级”，保留系统/遥控器返回 | `tv_video_detail_screen_test.dart` |
| 详情页播放器出现控制按钮组 | `VideoPlayerWidget.showControls=false`，播放器焦点确认只进全屏 | `tv_video_detail_screen_test.dart` / `video_player_widget_preload_config_test.dart` |
| 详情页播放器黑底首帧无反馈 | 外层 `tv-detail-preview-loading` 在首个可播源到达、控制器晚挂、续播记录未返回导致首播挂起或缓冲时显示无背景转圈和真实网速，未知时才回退 `0KB/s`；只有播放时间点从 loading 锚点前进后才能收起，不依赖内部播放器 loading | `detail preview shows loading overlay while controller attaches late`, `detail preview keeps loading until playback position changes`, `renders first incremental source with preview loading before all sources finish`, `detail starts initial source loading before resume record finishes` |
| 分类页筛选入口触发错误 | 电影、剧集、动漫、综艺菜单按确认键展示筛选面板；上键统一进入右上快捷入口，内容区上键不直接呼出 | `tv_home_screen_test.dart`, `tv_top_nav_test.dart` |
| 筛选面板遮挡卡片或顶部导航仍占位 | 顶部导航用收起动画让出空间，筛选面板用尺寸动画下滑展开并顶开 Grid | `tv_home_screen_test.dart` |
| 筛选项横向滚动盖住行标题或左右边界跳行 | 筛选行 `ListView` 使用视口裁剪，首尾选项复用 `TvEdgeShake` 拦截左右边界方向键 | `tv_home_screen_test.dart` |
| 筛选项确认后 Grid 不刷新 | `TvHomeScreen.loadCategoryData` 执行筛选查询，`FutureBuilder` 用筛选结果替换当前分类 Grid | `tv_home_screen_test.dart` |
| 卡片焦点边框包住文字 | 边框只放在封面 `AnimatedContainer` | `tv_video_card_test.dart` |
| 纵向 Grid 首尾列焦点被裁剪 | `TvVideoGrid` 使用 `Clip.none` 并预留 `focusSafePadding` | `tv_home_screen_test.dart` |
| 纵向 Grid 标题和首列卡片错位 | 标题和空状态使用同一份 `focusSafePadding` 缩进 | `tv_home_screen_test.dart` |
| TV 主题色没有持久化或未覆盖奈飞红 | `TvThemeService` 负责保存主题色并解析调色板 | `tv_theme_service_test.dart` |
| TV 设置页主题色切换无反馈 | 设置页提供 `主题色` 选项并保存 `netflix_red` | `tv_settings_screen_test.dart` |
| 图片首次加载空白或闪烁 | 封面加载中显示左上到右下雨刷骨架 | `tv_video_card_test.dart` |
| TV 卡片封面视口判定构建期崩溃 | 封面延迟加载的 viewport/reveal 计算必须使用 `RenderAbstractViewport.maybeOf`、滚动位置初始化检查和安全回退；`getOffsetToReveal` 失败时允许加载，不能让图片优化打断页面构建 | `TV video card falls back when sliver reveal offset is unavailable` |
| 横向列表保留旧滚动位置 | 分区失焦时 `jumpTo(0)` | `tv_home_section_test.dart` |
| 列表边界长按方向键狂抖 | `TvEdgeShake` 使用冷却间隔控制重复触发 | `tv_edge_shake_test.dart` |
| 横向列表遥控器无法显示首尾留白 | 首尾方向键先滚到真实滚动边界，再触发边界抖动 | `tv_home_section_test.dart` |
| 纵向 Grid 上方向被拦截 | Grid 不设置上边界抖动，焦点可回顶部导航 | `tv_home_screen_test.dart` |
| Grid 海报滚到顶部后盖住菜单或筛选面板 | 内容区和分类 Grid 外层使用 `ClipRect`，顶部导航与筛选面板提供半透黑色遮罩 | `tv_home_screen_test.dart` |
| 纵向滚动页焦点移动没有平滑滚动 | `TvFocusable` 获焦后调用 `TvFocusScroll`，首页分区使用更明显的区块滚动对齐 | `tv_focusable_test.dart`, `tv_home_section_test.dart` |
| TV 卡片缺少继续观看进度 | 多集徽章和封面底部播放进度条复用 `VideoInfo` 进度字段 | `tv_video_card_test.dart` |
| TV 卡片缺少继续观看秒数和源名 | 继续观看卡片副标题展示当前集、播放时间和源名 | `tv_video_card_test.dart` |
| TV 详情页继续观看从第 1 集起播 | 详情页重新读取最新 `PlayRecord`，把最终 `index/playTime` 转成 `updateDataSource(startAt)`，并在底层未吃到 `startAt` 时补 `seekTo(startAt)` | `tv_video_detail_screen_test.dart` |
| TV 详情页或全屏页播放不更新记录 | 播放器控制器进度监听调用 `TvPlayRecordService.saveRecord` | `tv_video_detail_screen_test.dart`, `tv_fullscreen_player_screen_test.dart` |
| TV 换源后旧记录被误删 | 换源先保存新源记录，失败时跳过清理，成功后才删除同影片其它源记录 | `tv_video_detail_screen_test.dart`, `tv_fullscreen_player_screen_test.dart` |
| 顶部导航需要按确认才切换 | 菜单项获得焦点时触发 `onChanged` | `tv_top_nav_test.dart` |
| 从内容区回顶部时误切到就近菜单 | 导航栏外部进入时先请求当前选中项焦点 | `tv_top_nav_test.dart` |
| TV 顶部缺少快捷入口 | `TvTopNav` 右侧快捷区提供搜索、播放历史、收藏夹、设置四个图标文字按钮 | `tv_home_screen_test.dart`, `tv_top_nav_test.dart` |
| 全屏播放器菜单未弹出时缺少遥控器播放控制 | 确认键切换播放暂停，左右键按加速步长 seek，并显示中心时间提示 | `tv_fullscreen_player_screen_test.dart` |
| 全屏长按 seek 松手后转圈残留 | key up 后的 recovery loading 必须在进度/播放恢复后收起；共享详情页播放器可用播放态兜底 stale `isLoading` | `long press seek clears recovery loading when reused controller keeps stale loading` |
| 全屏播放器底部菜单弹出或切换时卡顿 | 菜单壳层状态不得重建 `VideoPlayerWidget`；播放器画面层需要稳定缓存并用 `RepaintBoundary` 隔离菜单覆盖层重绘 | `tv_fullscreen_player_screen_test.dart` |
| 详情页进入全屏时播放器重新创建 | 详情页用同页覆盖层和共享播放器 Key 复用当前控制器，注入全屏播放器时才允许走独立 builder | `tv_video_detail_screen_test.dart` |
| TV 搜索页缺少历史和热词 | 搜索历史使用纯文字 Grid，搜索热词使用本地 mock Grid | `tv_search_screen_test.dart` |
| TV 搜索页推荐列表无边界反馈或放大不明显 | 推荐列表卡片复用 `TvVideoCard.focusedScale`，首尾方向键复用 `TvEdgeShake` 边界抖动 | `tv_search_screen_test.dart` |
| 设置输入框移入就弹键盘 | 输入框默认浏览态，确认后进入编辑态 | `tv_settings_screen_test.dart` |
| TV 设置页 widget test 拉起真实扫码桥接 | `FLUTTER_TEST` 环境下返回无副作用桥接会话，不启动真实 `HttpServer` 和局域网探测 | `tv_settings_screen_test.dart` |
| TV 封面图无法切换代理 | 设置页复用普通端豆瓣图片源保存逻辑 | `tv_settings_screen_test.dart` |
| TV 缺少缓存大小和清理入口 | 设置页展示缓存大小并提供 `清除所有缓存` 操作 | `tv_settings_screen_test.dart` |
| 低空间仍继续写图片磁盘缓存 | `AppCacheService` 低于 200MB 返回不使用图片磁盘缓存 | `app_cache_service_test.dart` |
| 二级标题固定不动 | `TvVideoGrid` 使用 `CustomScrollView`，标题作为首个 sliver | `tv_home_screen_test.dart` |

## 6. Good / Base / Bad Cases

### 6.1 Good Case

用户在 BlueStacks Debug 环境启动 App，直接进入 `IvyTV` 顶部导航的 TV 首页。用户在「继续观看」中向右浏览，再按下方向键进入「热门电影」，「继续观看」横向列表自动回到开头。用户选择影片卡片后进入详情页，在详情页内完成换源、选集、收藏，点击全屏进入普通播放器页。

用户也可以在顶部导航切到「电影」「剧集」「动漫」「综艺」大类。焦点移动到对应菜单后页面立即切换，并使用纵向 Grid 展示该大类内容。

顶部导航第一行左侧展示 `IvyTV` Logo，右上角提供「搜索、播放历史、收藏夹、设置」四个快捷按钮，并在最右侧展示当前时间。播放历史、收藏夹和设置不再出现在左侧主分类菜单中，快捷入口必须与 Logo 同行、靠右展示，主分类菜单独立放在下一行，确认快捷按钮后统一 `push` 对应独立页面，而不是切首页内部内容。

### 6.2 Base Case

用户在普通 Android 手机启动 App。由于不是 TV 设备，且 Release 不强制 TV，应用进入原有登录、本地模式和普通首页流程。

### 6.3 Bad Case

用户在 TV 首页横向列表移动到靠后的卡片后切到下一个分区，再返回时焦点被重置到第一个卡片。该行为会打断用户浏览上下文，必须保留分区最近一次停留的卡片位置，并在上下分区返回时恢复。

用户从顶部导航首次进入首页内容区时，焦点直接落回某个历史卡片，而不是当前首个可用卡片。该行为会让冷启动和首次浏览手感混乱，必须只在用户真实浏览过内容区后才恢复分区记忆；首次从顶部导航下探仍然从首个可用卡片开始。

用户在 TV 搜索页「影片推荐」移动到最右侧后继续按右键没有任何反馈，或推荐卡片获焦放大比例小于首页卡片。该行为会让搜索页和首页的遥控器手感不一致，必须复用 `TvEdgeShake` 与 `TvVideoCard.focusedScale`。

## 7. Tests Required

新增或修改 TV 功能时，根据触达范围选择测试：

```bash
flutter test test/services/app_device_service_test.dart
flutter test test/app_bootstrap_test.dart
flutter test test/tv_app/tv_home_screen_test.dart
flutter test test/tv_app/tv_search_screen_test.dart
flutter test test/tv_app/tv_home_section_test.dart
flutter test test/tv_app/tv_top_nav_test.dart
flutter test test/tv_app/tv_video_card_test.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_fullscreen_player_screen_test.dart
flutter test test/tv_app/tv_settings_screen_test.dart
```

针对性分析：

```bash
flutter analyze lib/tv_app test/tv_app
```

构建验证：

```bash
flutter build apk --debug
```

提交前空白检查：

```bash
git diff --check
```

Kotlin 原生 TV 模块新增 Compose Android 测试时，功能模块必须同时声明：

```kotlin
androidTestImplementation(libs.androidx.compose.ui.test.junit4)
debugImplementation(libs.androidx.compose.ui.test.manifest)
```

缺少 `ui-test-manifest` 时，`createComposeRule()` 会在 `connectedDebugAndroidTest` 中无法解析 `androidx.activity.ComponentActivity`，表现为测试 APK 已安装但测试 Activity 启动失败。

## 8. Wrong vs Correct

### 8.1 TV 页面边界

#### Wrong

```dart
// 在普通首页里塞 TV 判断和 TV 布局分支。
if (isTv) {
  return TvLayoutInsideNormalHome();
}
```

#### Correct

```dart
// 启动阶段分流，TV 页面放入 lib/tv_app/。
return isTv ? const TvAppShell() : const SeleneApp();
```

### 8.2 卡片焦点样式

#### Wrong

```dart
// 整张卡片都画焦点边框，标题和年份也被包住。
Container(
  decoration: focusedBorder,
  child: Column(children: [cover, title, subtitle]),
);
```

#### Correct

```dart
// 整张卡片做轻微缩放，焦点边框只画在封面上。
AnimatedScale(
  scale: hasFocus ? TvVideoCard.focusedScale : 1,
  child: Column(children: [coverWithBorder, title, subtitle]),
);
```

### 8.3 顶部导航切换

#### Wrong

```dart
// 焦点移动到菜单后还要按确认键才切换。
TvFocusable(onPressed: () => onChanged(index));
```

#### Correct

```dart
// 焦点进入菜单项就切换，确认键只作为兼容输入。
TvFocusable(
  onFocusChanged: (hasFocus) {
    if (hasFocus && !selected) {
      onChanged(index);
    }
  },
  onPressed: () => onChanged(index),
);
```

顶部导航还有一个特殊规则：当焦点从内容区进入顶部导航时，不允许按空间距离直接落到就近菜单项。必须先请求 `selectedIndex` 对应菜单项的焦点；只有导航栏内部左右移动时，才能焦点到哪就切到哪。

Kotlin 原生 TV 顶部主导航必须显式处理 `Key.DirectionLeft` / `Key.DirectionRight`，不能只依赖 Compose 几何焦点搜索。原因是顶部导航还存在“外部进入时重定向到当前选中 tab”的保护逻辑；如果左右移动没有先标记为组内移动，焦点落到相邻 tab 后会被立即拉回当前 tab，表现为首页无法右移到电影。实现上 `TvNavigationPill` 应消费左右键，`TvDestinationGroup` 在请求相邻 `FocusRequester` 前设置类似 `pendingInternalFocusRoute` 的组内移动标记；对应源码契约测试必须断言左右键处理、相邻目标请求和 pending 标记同时存在。

顶部导航右上角必须提供搜索、播放历史、收藏夹、设置四个图标文字快捷入口，且快捷入口与 `IvyTV` Logo 同行、与左侧主分类菜单上下错开，不放在同一行。快捷入口属于顶部导航内部焦点成员：从内容区回到顶部导航时仍先回当前选中菜单项或当前选中快捷入口。直播菜单项作为快捷区过渡；首页、电影、剧集、动漫、综艺、直播这些主菜单项按上方向键都进入搜索快捷入口。右上快捷入口按下方向键必须回到进入快捷区前的来源主菜单项，例如从首页按上进入搜索则按下回首页，从直播按上进入搜索则按下回直播；没有来源记忆时才回直播兜底，不能越过下方主菜单直接跳到内容卡片。电影、剧集、动漫、综艺菜单项的分类筛选只允许通过确认键呼出，不能再占用上方向键。筛选面板展开时顶部导航整体收起，快捷入口和当前时间也随顶部导航隐藏。

TV 搜索页必须使用 `lib/tv_app/screens/tv_search_screen.dart`，不要直接打开普通端 `SearchScreen`。页面左侧提供搜索输入展示、字母数字遥控器键盘、清空和删除按钮；右侧顶部展示搜索历史纯文字 Grid，下面展示搜索热词纯文字 Grid。搜索页左侧搜索标题和右侧搜索历史标题必须使用统一顶部留白，首屏默认状态不能明显偏下。搜索历史复用 `PageCacheService.getSearchHistory`，搜索热词当前使用本地 mock 列表，后续有接口后再替换。搜索历史和搜索热词的每行最右项按右方向键必须保持当前焦点，不能跳出右侧内容区；右侧内容纵向浏览时必须自动滚动，让当前获焦项尽量停留在屏幕中段。右侧下方可展示影片推荐横向列表，推荐点击进入 `TvVideoDetailScreen`。影片推荐列表的焦点放大比例必须与首页 `TvVideoCard.focusedScale` 一致，到达左右边界时必须复用 `TvEdgeShake` 给出边界抖动反馈。

### 8.4 Kotlin 原生 TV 设计系统与根导航

Kotlin 原生 TV 工程必须把 Flutter TV 的设计系统和根导航契约收敛在 `re-android/core-design` 与 `re-android/app-tv`：

- `core-design` 使用 `androidx.tv.material3`，不要在 TV 设计基础组件里混用普通 `androidx.compose.material3.MaterialTheme`。
- `TvDesignPreset` 必须包含 `AUTO / HD720 / FULL_HD_1080 / QHD_1440`，`TvDesignMetrics` 必须同时暴露 `configuredPreset` 和 `effectivePreset`，用于页面和弹窗继承同一设计视口。
- 可复用页面组件放在 `core-design/layout/`，包括页面壳、区块、海报卡、横向 rail、纵向 grid、空/加载/错误状态面板。
- Kotlin 原生 TV 首页横向分区必须对齐 Flutter TV 首屏节奏：单个分区首屏最多展示 `15` 张海报，超出时在 rail 尾部追加一个与海报同宽的「查看更多」卡片；`continue_watching/history -> 播放历史`、`hot_movies -> 电影`、`hot_tv_shows -> 剧集`、`bangumi_calendar -> 动漫`、`hot_shows -> 综艺`、`favorites -> 收藏夹`，不要为首页更多入口再造一套中转路由。
- 遥控器确认键策略放在 `core-design/focus/`，短按、长按和重复 KeyDown 去重必须由共享策略处理，避免页面各自实现导致重复跳转。
- TV 风格确认弹窗放在 `core-design/dialog/`，后续页面只传 title/message/action，不重复写弹窗视觉。
- `app-tv` 顶部导航必须使用 `TvDestination` 的统一 route/label 契约；主菜单顺序是：首页、电影、剧集、动漫、综艺、直播；快捷入口顺序是：搜索、播放历史、收藏夹、设置。
- 播放器目的地不属于顶部导航，但 `TvDestination.Player.createRoute(videoId)` 必须保留 URL 编码，防止 `/`、空格和中文破坏导航层级。

#### Wrong

```kotlin
// 页面里各自硬编码遥控器重复事件处理。
Modifier.onPreviewKeyEvent {
    if (it.type == KeyEventType.KeyDown) {
        onClick()
    }
    true
}
```

#### Correct

```kotlin
// 共享策略负责短按、长按和重复事件去重。
val policy = remember { TvRemotePressPolicy(hasLongPressHandler = onLongPressed != null) }
```

### 8.5 横向分区滚动复位

#### Wrong

```dart
// 横向列表滚动状态完全留给 ListView，离开分区后不复位。
ListView.separated(scrollDirection: Axis.horizontal);
```

#### Correct

```dart
// 分区上下切换时保留最近一次停留卡片，首次从顶部导航进入时再显式回到首卡。
ListView.separated(
  controller: controller,
  scrollDirection: Axis.horizontal,
);

// 顶部导航首次下探内容区时，只重置入口焦点，不清掉分区内部的最近停留位置。
TvFocusable.resetGroupEntryToFirstFocusable(groupKey);
TvFocusable.requestRememberedFocusForGroup(groupKey);
```

## 9. Development Notes

- TV 端可以多写小文件，优先保持边界清晰。
- API 和 service 能复用就复用，但不要让普通端页面承担 TV 逻辑。
- Widget test 中需要避免真实网络加载，使用注入的 loader 或 builder。
- `TvHomeScreen` 的 `buildDetailPage` 用于测试替换真实详情页，避免卡片跳转测试触发详情页网络请求。
- `TvVideoDetailScreen` 的 `loadDetail` 和 `playerBuilder` 用于隔离详情数据和播放器。
- 新增 TV 焦点行为时，优先在 `TvFocusable` 或具体 TV 组件内封装，不要在页面里散落键盘事件。

### 9.1 播放器缓冲数据流

```
PlayerAdapter.state.cachedRanges          ← Exo/WebView 内核都实现
  ↓ (stream 订阅，已持久化合并)
_VideoPlayerWidgetState._currentPreloadProgressRanges
  ↓ (新增 getter)
VideoPlayerWidgetController.cachedRanges
  ↓ (适配器桥接)
TvFullscreenPlaybackController.cachedRanges
  ↓ (UI 消费)
_buildBottomProgressBar() / _buildDetailProgressBar()
```

- `VideoPlayerWidgetController.cachedRanges` 委托到已有的 `_currentPreloadProgressRanges`，不新增数据链路或订阅。
- `_TvDetailFullscreenPlaybackController` 实时读取 `_controller?.cachedRanges`，因为控制器可能在全屏打开后才挂上。
- 缓冲数据更新时无需额外订阅；进度监听回调触发 `setState` 时顺带读取最新 `cachedRanges` 即可。

### 9.2 TV 进度条实现约定

- TV 进度条不使用 Flutter `Slider`，由 `Stack` + `Container` + `Positioned` 手写，四层结构：背景轨道 → 缓冲段 → 已播放轨道 → 时间圆点。
- 全屏播放器进度条由 `_buildBottomProgressBar()` 构建，详情页进度条由 `_buildDetailProgressBar()` 构建。
- 缓冲段使用 `resolvePlayerCachedProgressSegments()` 计算归一化位置，截断至 `position + 3min`。
- 播放中进度条常驻显示：`_shouldShowPlaybackChrome` 只检查 `!_menuVisible && !_isPlaybackLoading`。
- 进度条通过 `IgnorePointer` 包裹，不拦截遥控器焦点事件。
- 时间格式化复用 `lib/utils/playback_time_utils.dart` 中的 `clampDuration()` 和 `formatPlaybackDuration()`。

### 9.3 TV 加载转圈约定

- TV 端所有加载转圈使用单 `CircularProgressIndicator` + `BoxShadow` 实现投影，不得使用双 spinner 重叠。
- `BoxShadow` 参数：`color: Colors.black.withValues(alpha: 0.32), blurRadius: 4, offset: Offset(2, 2)`，模拟光源左上方照射效果。
- 圈颜色：详情页用 `palette.accent`，全屏用 `Colors.white`。
- 圈 `strokeWidth` 统一为 3。
- 文字阴影使用 `TextSpan` 的 `Shadow` 属性，保持现有实现不变。
