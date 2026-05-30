import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/search_service.dart';
import 'package:selene/tv_app/services/tv_search_recommend_service.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_confirm_dialog.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_route.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 搜索页数据加载函数。
///
/// [context] 用于复用现有搜索历史和推荐数据上下文。
typedef TvSearchDataLoader = Future<TvSearchData> Function(
    BuildContext context);

/// TV 搜索历史清空函数。
typedef TvSearchHistoryClearer = Future<bool> Function(BuildContext context);

/// TV 搜索联想加载函数。
///
/// [query] 表示当前左侧字母键盘已经拼出的首字母查询串。
typedef TvSearchSuggestionLoader = Future<List<String>> Function(String query);

/// TV 搜索结果加载函数。
///
/// [query] 表示联想词确认后真正发起搜索时使用的关键词。
typedef TvSearchResultLoader = Future<List<SearchResult>> Function(
    String query);

/// TV 搜索结果加载函数。
///
/// 允许调用方在返回最终结果前，持续回传增量搜索结果和资源站进度。
typedef TvSearchResultWithProgressLoader = Future<List<SearchResult>> Function(
  String query, {
  required ValueChanged<List<SearchResult>> onPartialResults,
  required ValueChanged<SearchProgressSnapshot> onProgress,
});

/// TV 搜索页数据。
class TvSearchData {
  /// 创建 TV 搜索页数据。
  const TvSearchData({
    required this.searchHistory,
    required this.hotWords,
    required this.recommends,
  });

  /// 搜索历史列表。
  final List<String> searchHistory;

  /// 搜索热词列表。
  final List<String> hotWords;

  /// 影片推荐列表。
  final List<VideoInfo> recommends;

  /// 创建空搜索页数据。
  factory TvSearchData.empty() {
    return const TvSearchData(
      searchHistory: [],
      hotWords: [],
      recommends: [],
    );
  }
}

/// TV 搜索页面。
///
/// 左侧提供遥控器字母输入区，右侧展示搜索历史和推荐影片。
class TvSearchScreen extends StatefulWidget {
  /// 创建 TV 搜索页面。
  ///
  /// [loadSearchData] 可在测试中注入搜索历史和推荐数据。
  const TvSearchScreen({
    super.key,
    this.loadSearchData,
    this.onClearSearchHistory,
    this.loadSuggestions,
    this.loadSearchResults,
    this.loadSearchResultsWithProgress,
  });

  /// 搜索页数据加载函数。
  final TvSearchDataLoader? loadSearchData;

  /// 搜索历史清空函数。
  final TvSearchHistoryClearer? onClearSearchHistory;

  /// 搜索联想加载函数。
  ///
  /// 允许测试注入固定联想结果，避免 widget test 依赖真实网络。
  final TvSearchSuggestionLoader? loadSuggestions;

  /// 搜索结果加载函数。
  ///
  /// 默认走现有 `SearchService.searchSync`，测试里可注入假结果。
  final TvSearchResultLoader? loadSearchResults;

  /// 带进度的搜索结果加载函数。
  ///
  /// 搜索页需要显示资源站进度时，优先使用这个回调。
  final TvSearchResultWithProgressLoader? loadSearchResultsWithProgress;

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();

  /// 默认搜索页数据加载逻辑。
  static Future<TvSearchData> defaultLoadSearchData(
    BuildContext context,
  ) async {
    final cacheService = PageCacheService();
    final historyFuture = _loadSearchHistory(context, cacheService);
    final recommendsFuture = _loadRecommends(context, cacheService);

    final history = await historyFuture;
    final recommends = await recommendsFuture;

    return TvSearchData(
      searchHistory: history.take(12).toList(),
      // 搜索热词暂时没有真实数据源，默认隐藏该区块。
      hotWords: const <String>[],
      recommends: recommends.take(20).toList(),
    );
  }

  /// 加载搜索历史。
  static Future<List<String>> _loadSearchHistory(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      final result = await cacheService.getSearchHistory(context);
      return result.success ? (result.data ?? <String>[]) : <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  /// 加载推荐影片。
  static Future<List<VideoInfo>> _loadRecommends(
    BuildContext context,
    PageCacheService cacheService,
  ) async {
    try {
      return await TvSearchRecommendService.loadSearchRecommends(
        fallbackLoader: () =>
            TvSearchRecommendService.loadFallbackHotRecommends(context),
      );
    } catch (_) {
      return <VideoInfo>[];
    }
  }

  /// 默认搜索历史清空逻辑。
  static Future<bool> defaultClearSearchHistory(BuildContext context) async {
    final result = await PageCacheService().clearSearchHistory(context);
    return result.success;
  }
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  /// 搜索页当前全局背景色。
  Color get _pageBackgroundColor => TvTheme.backgroundOf(context).color;

  /// 搜索页首屏顶部留白。
  ///
  /// 左右面板共用，避免搜索入口和搜索历史默认状态显得偏下。
  static const double _panelTopPadding = 28;

  /// 左侧搜索操作区宽度。
  ///
  /// 适当收窄左栏，给右侧搜索结果区释放更多横向空间。
  static const double _leftPanelWidth = 350;

  /// 左侧搜索操作区左边距。
  static const double _leftPanelLeftPadding = 40;

  /// 左侧搜索操作区右边距。
  ///
  /// 收窄左右两栏之间的大空档，让结果区更靠左。
  static const double _leftPanelRightPadding = 0;

  /// 右侧内容区左边距。
  ///
  /// 结果区和联想区统一贴近左栏，避免中间留出过宽过空的缝隙。
  static const double _rightPanelLeftPadding = 0;

  /// 右侧内容区右边距。
  static const double _rightPanelRightPadding = 36;

  /// 搜索词列表列数。
  static const int _wordGridColumnCount = 3;

  /// 搜索词列表项高度。
  static const double _wordTileExtent = 46;

  /// 搜索词列表横向间距。
  static const double _wordTileCrossSpacing = 16;

  /// 搜索词列表纵向间距。
  static const double _wordTileMainSpacing = 14;

  /// 搜索词标题和下方词条区之间的纵向留白。
  ///
  /// 给“搜索历史”“搜索热词”和首行词条之间补一点呼吸空间，避免标题和内容贴得过紧。
  static const double _wordSectionTitleBottomSpacing = 20;

  /// 搜索结果面板底部安全留白。
  ///
  /// 给右侧结果区底部保留一条稳定的呼吸空间，避免内容贴到页面最下沿。
  static const double _searchResultPanelBottomInset = 10;

  /// 联想词条横向间距。
  ///
  /// 右侧联想区改为更贴字的自然排布，横向间距适当收紧。
  static const double _suggestionTileSpacing = 12;

  /// 联想词条纵向行间距。
  static const double _suggestionRowSpacing = 16;

  /// 联想词条左右内边距。
  ///
  /// 联想结果宽度按文字实测值计算，再额外加上这一段左右内边距。
  static const double _suggestionTileHorizontalPadding = 12;

  /// 联想词条最大宽度。
  static const double _suggestionTileMaxWidth = 320;

  /// 联想词条额外安全余量。
  ///
  /// 给文字宽度再补一点呼吸空间，避免视觉上过于贴边。
  static const double _suggestionTileWidthSlack = 10;

  /// 搜索结果区每行卡片数。
  ///
  /// 收窄左右两栏留白后，右侧结果区可稳定放下 5 列卡片。
  static const int _searchResultCrossAxisCount = 5;

  /// 搜索结果区前四个卡片禁止向上的数量。
  ///
  /// 这些卡片位于标题正下方，继续按上时保持原焦点会更稳。
  static const int _searchResultTopArrowLockedCount = 4;

  /// 搜索结果区卡片横向间距。
  ///
  /// 结果区固定展示 5 列时，把卡片之间的缝隙再收一点，
  /// 让海报视觉上更饱满，不会因为列间空隙太大显得瘦长。
  static const double _searchResultCrossAxisSpacing = 18;

  /// 搜索结果区内容左侧起点。
  ///
  /// 固定标题、首屏雨刷骨架和真正的结果 Grid 都要共用同一条起始线，
  /// 这样“搜索结果”标题才能和第一列影视卡片严格对齐。
  static const double _searchResultContentLeftInset =
      TvLayout.pageHorizontalPadding + TvVideoGrid.focusSafePadding;

  /// 右侧默认内容区统一左侧起点。
  ///
  /// 搜索主页和搜索结果页共用同一条起始线，
  /// 避免左右两栏之间的视觉间隙在不同状态下忽大忽小。
  static const double _rightPanelContentLeftInset =
      _searchResultContentLeftInset;

  /// 搜索结果固定头部高度。
  ///
  /// 结果区标题、聚合数量和资源站进度统一占据这一行高度，
  /// 下方列表只在剩余区域滚动，避免标题被滚动内容覆盖。
  static const double _searchResultHeaderHeight = 50;

  /// 搜索结果头部向上延展的遮罩高度。
  ///
  /// 搜索结果 Grid 允许焦点和卡片轻微越界绘制，因此固定头部除了本身高度外，
  /// 还需要向上补一段纯色遮罩，把滚动内容在标题上方的穿透彻底盖住。
  static const double _searchResultHeaderTopCoverHeight = 34;

  /// 搜索结果头部与列表之间的垂直间距。
  static const double _searchResultHeaderBottomSpacing = 6;

  /// 推荐横向列表卡片间距。
  ///
  /// 推荐区需要和实际 `ListView.separated` 的卡片间距保持同一份常量，
  /// 这样滚动锚点换算出来的位置才不会和真实视觉卡位产生偏差。
  static const double _recommendCardSpacing = 24;

  /// 推荐横向列表左侧露头遮罩宽度。
  ///
  /// 当前卡片固定停在第 2 个卡位时，前一张卡片会在最左边露出一小截。
  /// 这里用一条和页面背景同色的遮罩把这段切掉，保持左边缘干净。
  static const double _recommendLeadingMaskWidth =
      _rightPanelContentLeftInset > _recommendCardSpacing
          ? _rightPanelContentLeftInset - _recommendCardSpacing
          : 0;

  /// 推荐横向列表滚动锚点卡位。
  ///
  /// 这里使用 0-based 下标，值为 `1` 表示让当前获焦卡片尽量稳定停在第 2 个卡位。
  static const int _recommendScrollAnchorIndex = 1;

  /// 推荐横向列表顶部焦点安全留白。
  ///
  /// 让首行卡片获焦放大时，顶部描边不会被裁掉。
  static const double _recommendListTopSafePadding = 12;

  /// 推荐横向列表底部焦点安全留白。
  ///
  /// 底部保留少量空间，避免卡片轻微缩放时压到容器裁剪边。
  static const double _recommendListBottomSafePadding = 18;

  /// 左侧搜索操作区焦点记忆分组。
  ///
  /// 推荐区回到搜索侧时，优先回到左侧最近一次停留的输入操作按钮。
  static const Object _leftPanelFocusMemoryGroupKey = 'tv-search-left-panel';

  /// 搜索历史焦点记忆分组。
  ///
  /// 推荐区向上回退时，热词区没有可用焦点项才回退到搜索历史区。
  static const Object _historyWordFocusMemoryGroupKey =
      'tv-search-history-word-tiles';

  /// 搜索热词焦点记忆分组。
  ///
  /// 推荐区向上回退时优先回到热词区最近一次停留的位置。
  static const Object _hotWordFocusMemoryGroupKey = 'tv-search-hot-word-tiles';

  /// 搜索联想焦点记忆分组。
  ///
  /// 当左侧继续输入字符后，右侧联想区应尽量保持最近一次停留位置。
  static const Object _suggestionFocusMemoryGroupKey =
      'tv-search-suggestion-tiles';

  /// 搜索结果焦点记忆分组。
  ///
  /// 左侧输入区回到结果区时，优先恢复用户刚离开的那张结果卡片。
  static const Object _searchResultFocusMemoryGroupKey =
      'tv-search-result-grid';

  /// 右下推荐区焦点记忆分组。
  ///
  /// 搜索历史、热词和联想词再次向下进入推荐区时，应尽量回到上次离开的位置。
  static const Object _recommendFocusMemoryGroupKey =
      'tv-search-recommend-list';

  /// 右侧纯文字词条方向键长按节流分组。
  ///
  /// 搜索历史和热词需要共用逐项节流，避免长按时直接跳过中间获焦态。
  static const String _wordTileDirectionalThrottleGroupKey =
      'tv-search-word-tiles';

  /// 搜索页数据任务。
  Future<TvSearchData>? _searchDataFuture;

  /// 右侧内容滚动目标对齐比例。
  ///
  /// 让获焦项尽量停留在视口中段略偏上的稳定浏览位置。
  static const double _rightPanelFocusAlignment = 0.46;

  /// 当前搜索输入内容。
  String _query = '';

  /// 从联想页进入搜索结果前的原始输入串。
  ///
  /// 命中联想词后，结果页左侧需要显示完整片名；
  /// 但按返回回退时，还要恢复成原来的首字母输入串，方便继续挑其它联想词。
  String? _suggestionQueryBeforeSearch;

  /// 当前联想结果列表。
  List<String> _suggestions = <String>[];

  /// 从联想页进入搜索结果前的联想词快照。
  ///
  /// 返回结果页上一层时，直接恢复这份快照，避免重新请求联想接口导致闪烁。
  List<String> _suggestionsBeforeSearch = <String>[];

  /// 当前搜索结果列表。
  List<SearchResult> _searchResults = <SearchResult>[];

  /// 当前搜索结果聚合后的卡片列表缓存。
  ///
  /// 搜索进度更新会频繁触发 rebuild，这里把“按片名 regroup”从 build 阶段挪到状态层，
  /// 避免进度文案变化时反复重算整份结果集。
  List<VideoInfo> _aggregatedSearchVideos = <VideoInfo>[];

  /// 当前搜索资源站总数。
  int _searchTotalResourceCount = 0;

  /// 当前已完成搜索的资源站数量。
  int _searchCompletedResourceCount = 0;

  /// 联想结果首项焦点节点。
  final FocusNode _suggestionFirstFocusNode = FocusNode();

  /// 当前联想结果是否正在加载。
  bool _isSuggestionLoading = false;

  /// 当前搜索结果是否正在加载。
  bool _isSearchResultLoading = false;

  /// 当前联想请求序号。
  ///
  /// 通过自增版本号丢弃过期响应，避免快速输入时旧请求覆盖新结果。
  int _suggestionRequestVersion = 0;

  /// 当前搜索请求序号。
  ///
  /// 用于丢弃较早发出的搜索请求响应，避免旧结果覆盖新搜索。
  int _searchRequestVersion = 0;

  /// 判断当前查询串是否应该进入首字母联想模式。
  ///
  /// 这里只接管纯英文字母和数字输入，避免历史词、热词或中文片名回填后误切到联想区。
  bool get _shouldShowSuggestionPanel =>
      _query.isNotEmpty &&
      !_isSearchResultLoading &&
      _searchResults.isEmpty &&
      RegExp(r'^[A-Z0-9]+$').hasMatch(_query);

  /// 当前查询串是否应该展示搜索结果区。
  ///
  /// 联想词确认后，右侧改为显示真正的搜索结果列表。
  bool get _shouldShowSearchResultPanel =>
      _query.isNotEmpty &&
      (_isSearchResultLoading || _searchResults.isNotEmpty);

  /// 搜索结果区首次回左时可承接焦点的键盘边缘列节点。
  List<FocusNode> get _searchResultKeyboardBridgeNodes => <FocusNode>[
        _keyboardTopRowFocusNodes.last,
        _keyboardBridgeLFocusNode,
        _keyboardBridgeRFocusNode,
        _keyboardBridgeXFocusNode,
        _keyboardBridge4FocusNode,
        _keyboardBottomRowFocusNodes.last,
      ];

  /// 返回指定键盘索引真正使用的焦点节点。
  ///
  /// 顶行和底行沿用现有节点；中间几行仅暴露最右列节点，
  /// 供结果区首次左移时落到 `F/L/R/X/4/0` 这一列。
  FocusNode? _focusNodeForKeyboardIndex(int index) {
    return switch (index) {
      0 || 1 || 2 || 3 || 4 || 5 => _keyboardTopRowFocusNodes[index],
      11 => _keyboardBridgeLFocusNode,
      17 => _keyboardBridgeRFocusNode,
      23 => _keyboardBridgeXFocusNode,
      29 => _keyboardBridge4FocusNode,
      30 ||
      31 ||
      32 ||
      33 ||
      34 ||
      35 =>
        _keyboardBottomRowFocusNodes[index - (_keyboardKeys.length - 6)],
      _ => null,
    };
  }

  /// 重置当前搜索结果页的焦点状态。
  ///
  /// 新搜索开始、退出结果页或回退到联想页时，都恢复成“首卡首焦点 + 首次回左就近落点”。
  void _resetSearchResultFocusState() {
    _didDispatchSearchResultInitialFocus = false;
    _searchResultRememberedLeftPanelFocusNode = null;
    TvFocusable.clearLastFocusedForGroup(_searchResultFocusMemoryGroupKey);
  }

  /// 重置当前搜索结果态缓存。
  ///
  /// 搜索主页、联想页和新搜索启动前，都要把旧结果卡片、聚合缓存和资源站进度一起清空，
  /// 避免后续维护时漏掉其中某个字段。
  void _resetSearchResultState({
    required bool isSearchResultLoading,
  }) {
    _searchResults = <SearchResult>[];
    _aggregatedSearchVideos = <VideoInfo>[];
    _searchTotalResourceCount = 0;
    _searchCompletedResourceCount = 0;
    _isSearchResultLoading = isSearchResultLoading;
  }

  /// 同步搜索结果聚合缓存。
  ///
  /// 只有 `_searchResults` 真正变更时才调用它，避免纯进度刷新重复 regroup。
  void _syncAggregatedSearchVideos() {
    _aggregatedSearchVideos = _aggregateSearchResults(_searchResults);
  }

  /// 记录结果页场景下最近一次停留的左侧输入区焦点节点。
  ///
  /// 只在当前处于结果页时更新，避免首页态或联想态污染结果页回左记忆。
  void _rememberLeftPanelFocusNodeForSearchResult(FocusNode focusNode) {
    if (!_shouldShowSearchResultPanel) {
      return;
    }
    _searchResultRememberedLeftPanelFocusNode = focusNode;
  }

  /// 推荐影片横向列表控制器。
  final ScrollController _recommendScrollController = ScrollController();

  /// 右侧内容纵向滚动控制器。
  final ScrollController _rightPanelScrollController = ScrollController();

  /// 推荐影片卡片边界抖动控制键。
  final Map<int, GlobalKey<TvEdgeShakeState>> _recommendEdgeShakeKeys = {};

  /// 搜索历史首项焦点节点。
  final FocusNode _historyFirstFocusNode = FocusNode();

  /// 搜索热词首项焦点节点。
  final FocusNode _hotWordFirstFocusNode = FocusNode();

  /// 推荐区首张卡片焦点节点。
  final FocusNode _recommendFirstFocusNode = FocusNode();

  /// 搜索结果首张卡片焦点节点。
  final FocusNode _searchResultFirstFocusNode = FocusNode();

  /// 联想结果标题定位键。
  ///
  /// 推荐区回到联想区时，需要把标题重新推回可视区顶部，避免被上边缘裁掉。
  final GlobalKey _suggestionTitleKey = GlobalKey();

  /// 字母键盘首行焦点节点。
  final List<FocusNode> _keyboardTopRowFocusNodes =
      List<FocusNode>.generate(6, (_) => FocusNode());

  /// 字母键盘底行焦点节点。
  ///
  /// 左侧清空/删除按钮向上回环时，需要稳定落到数字底行的就近位置。
  final List<FocusNode> _keyboardBottomRowFocusNodes =
      List<FocusNode>.generate(6, (_) => FocusNode());

  /// 左侧清空按钮焦点节点。
  final FocusNode _leftClearActionFocusNode = FocusNode();

  /// 左侧搜索按钮焦点节点。
  final FocusNode _leftSearchActionFocusNode = FocusNode();

  /// 左侧删除按钮焦点节点。
  final FocusNode _leftDeleteActionFocusNode = FocusNode();

  /// 结果区首次左移时承接第二行最右列的焦点节点。
  final FocusNode _keyboardBridgeLFocusNode = FocusNode();

  /// 结果区首次左移时承接第三行最右列的焦点节点。
  final FocusNode _keyboardBridgeRFocusNode = FocusNode();

  /// 结果区首次左移时承接第四行最右列的焦点节点。
  final FocusNode _keyboardBridgeXFocusNode = FocusNode();

  /// 结果区首次左移时承接第五行最右列的焦点节点。
  final FocusNode _keyboardBridge4FocusNode = FocusNode();

  /// 搜索历史标题清空按钮焦点节点。
  final FocusNode _historyClearButtonFocusNode = FocusNode();

  /// 是否已经完成首屏默认焦点分发。
  bool _didDispatchInitialContentFocus = false;

  /// 是否已经完成当前结果页的首个默认焦点分发。
  bool _didDispatchSearchResultInitialFocus = false;

  /// 当前结果页最近一次停留的左侧输入区焦点节点。
  ///
  /// 首次从结果区回左侧时，按视觉距离就近落到 `F/L/R/X/4/0`；
  /// 后续再恢复用户离开左侧前真正停留的位置。
  FocusNode? _searchResultRememberedLeftPanelFocusNode;

  /// TV 键盘字符。
  static const List<String> _keyboardKeys = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '0',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchDataFuture ??=
        (widget.loadSearchData ?? TvSearchScreen.defaultLoadSearchData)(
      context,
    );
  }

  @override
  void dispose() {
    _recommendScrollController.dispose();
    _rightPanelScrollController.dispose();
    _historyFirstFocusNode.dispose();
    _hotWordFirstFocusNode.dispose();
    _suggestionFirstFocusNode.dispose();
    _recommendFirstFocusNode.dispose();
    _searchResultFirstFocusNode.dispose();
    for (final focusNode in _keyboardTopRowFocusNodes) {
      focusNode.dispose();
    }
    for (final focusNode in _keyboardBottomRowFocusNodes) {
      focusNode.dispose();
    }
    _leftClearActionFocusNode.dispose();
    _leftSearchActionFocusNode.dispose();
    _leftDeleteActionFocusNode.dispose();
    _keyboardBridgeLFocusNode.dispose();
    _keyboardBridgeRFocusNode.dispose();
    _keyboardBridgeXFocusNode.dispose();
    _keyboardBridge4FocusNode.dispose();
    _historyClearButtonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageBackgroundColor = _pageBackgroundColor;
    return TvBackHandler(
      autofocus: true,
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        key: const ValueKey('tv-search-screen'),
        backgroundColor: pageBackgroundColor,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: pageBackgroundColor,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: pageBackgroundColor,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: ColoredBox(
            color: pageBackgroundColor,
            child: SafeArea(
              top: false,
              child: FutureBuilder<TvSearchData>(
                future: _searchDataFuture,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? TvSearchData.empty();
                  final isLoading =
                      snapshot.connectionState != ConnectionState.done;
                  _dispatchInitialContentFocusIfNeeded(data, isLoading);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _leftPanelWidth,
                        child: _buildLeftPanel(),
                      ),
                      Expanded(
                        child: _buildRightPanel(data, isLoading),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 处理搜索页返回动作。
  ///
  /// 当右侧正处于联想态、联想词编辑态或搜索结果态时，先回到搜索主页；
  /// 只有已经回到主页时，才继续执行页面级返回。
  Future<bool> _handleBackPressed() async {
    if (_shouldShowSearchResultPanel && _canRestoreSuggestionPanel) {
      _restoreSuggestionPanel();
      return true;
    }
    if (!_shouldShowSuggestionPanel &&
        !_shouldShowSearchResultPanel &&
        _query.isNotEmpty &&
        _canRestoreSuggestionPanel) {
      _restoreSuggestionPanel();
      return true;
    }
    if (_shouldReturnToSearchHomeOnBack) {
      _resetToSearchHome();
      return true;
    }
    return false;
  }

  /// 当前结果页是否可以回退到联想页。
  bool get _canRestoreSuggestionPanel => _suggestionQueryBeforeSearch != null;

  /// 当前返回键是否应该先把右侧恢复为搜索主页。
  bool get _shouldReturnToSearchHomeOnBack {
    return _query.isNotEmpty ||
        _suggestions.isNotEmpty ||
        _searchResults.isNotEmpty ||
        _isSuggestionLoading ||
        _isSearchResultLoading;
  }

  /// 恢复搜索主页默认态。
  ///
  /// 清掉联想词、搜索结果和加载状态，让右侧重新展示搜索历史与影片推荐。
  void _resetToSearchHome() {
    _invalidateSearchRequests();
    _resetSearchResultFocusState();
    setState(() {
      _query = '';
      _suggestions = <String>[];
      _isSuggestionLoading = false;
      _resetSearchResultState(isSearchResultLoading: false);
    });
    _clearSuggestionSearchContext();
  }

  /// 让当前联想请求和搜索请求全部失效。
  ///
  /// 用户已经切走页面状态后，旧请求回包不应再把右侧内容重新顶回来。
  void _invalidateSearchRequests() {
    _suggestionRequestVersion++;
    _searchRequestVersion++;
  }

  /// 清理“联想页进入结果页”上下文。
  void _clearSuggestionSearchContext() {
    _suggestionQueryBeforeSearch = null;
    _suggestionsBeforeSearch = <String>[];
  }

  /// 回退到进入结果页之前的联想页。
  ///
  /// 恢复首字母输入串和联想词快照，让用户可直接继续换其它联想结果。
  void _restoreSuggestionPanel() {
    final suggestionQuery = _suggestionQueryBeforeSearch;
    if (suggestionQuery == null) {
      return;
    }
    final suggestionSnapshot = List<String>.from(_suggestionsBeforeSearch);
    _invalidateSearchRequests();
    _resetSearchResultFocusState();
    setState(() {
      _query = suggestionQuery;
      _suggestions = suggestionSnapshot;
      _isSuggestionLoading = false;
      _resetSearchResultState(isSearchResultLoading: false);
    });
    _clearSuggestionSearchContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final restored = TvFocusable.requestRememberedFocusForGroup(
        _suggestionFocusMemoryGroupKey,
      );
      if (!restored) {
        _suggestionFirstFocusNode.requestFocus();
      }
    });
  }

  /// 构建左侧搜索输入区。
  Widget _buildLeftPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        _leftPanelLeftPadding,
        _panelTopPadding,
        _leftPanelRightPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                key: const ValueKey('tv-search-page-title'),
                '搜索',
                style: FontUtils.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '按返回键可退出本页面',
                  style: FontUtils.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9CA2AD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildSearchField(),
          const SizedBox(height: 34),
          _buildKeyboard(),
          const SizedBox(height: 30),
          _buildActionRow(),
          const SizedBox(height: 18),
          // Text(
          //   '如不习惯 TV 搜索方式，请使用电视联播功能',
          //   style: FontUtils.poppins(
          //     fontSize: 12,
          //     color: const Color(0xFF7F858F),
          //   ),
          // ),
        ],
      ),
    );
  }

  /// 构建搜索输入展示框。
  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('tv-search-input'),
      height: 46,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4B4E58),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: 19,
            color: Color(0xFFE1E4EA),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              _query.isEmpty ? '输入影片名称首字母进行搜索' : _query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: 16,
                fontWeight: _query.isEmpty ? FontWeight.w500 : FontWeight.w700,
                color: _query.isEmpty ? const Color(0xFFC4C8D0) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建遥控器字母键盘。
  Widget _buildKeyboard() {
    return GridView.builder(
      key: const ValueKey('tv-search-keyboard'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisExtent: 42,
        crossAxisSpacing: 8,
        mainAxisSpacing: 9,
      ),
      itemCount: _keyboardKeys.length,
      itemBuilder: (context, index) {
        final keyLabel = _keyboardKeys[index];
        final isRightEdge = _isKeyboardRightEdge(index);
        return TvFocusable(
          focusNode: _focusNodeForKeyboardIndex(index),
          focusMemoryGroupKey: _leftPanelFocusMemoryGroupKey,
          onPressed: () => _appendQuery(keyLabel),
          onArrowRight: isRightEdge ? _moveLeftPanelFocusToRightPanel : null,
          onArrowUp: index < 6 ? _moveKeyboardTopRowToBottomActions : null,
          onFocusedNodeChanged: _rememberLeftPanelFocusNodeForSearchResult,
          builder: (context, hasFocus) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasFocus ? const Color(0xFF737780) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFocus ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                keyLabel,
                style: FontUtils.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建清空、搜索和删除按钮。
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: '清空',
            containerKey: const ValueKey('tv-search-left-clear-button'),
            focusNode: _leftClearActionFocusNode,
            onPressed: () => _updateQuery(''),
            onArrowUp: _moveBottomActionFocusToKeyboardBottomRow,
            onArrowDown: _moveActionFocusToTopKeyboardRow,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _buildActionButton(
            label: '搜索',
            containerKey: const ValueKey('tv-search-left-submit-button'),
            focusNode: _leftSearchActionFocusNode,
            onPressed: () => unawaited(_searchCurrentQuery()),
            onArrowUp: _moveBottomActionFocusToKeyboardBottomRow,
            onArrowDown: _moveActionFocusToTopKeyboardRow,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _buildActionButton(
            label: '删除',
            containerKey: const ValueKey('tv-search-left-delete-button'),
            focusNode: _leftDeleteActionFocusNode,
            onPressed: _deleteLastQueryChar,
            enableRightPanelArrow: true,
            onArrowUp: _moveBottomActionFocusToKeyboardBottomRow,
            onArrowDown: _moveActionFocusToTopKeyboardRow,
          ),
        ),
      ],
    );
  }

  /// 构建搜索页操作按钮。
  Widget _buildActionButton({
    required String label,
    Key? containerKey,
    FocusNode? focusNode,
    required VoidCallback onPressed,
    bool enableRightPanelArrow = false,
    VoidCallback? onArrowUp,
    VoidCallback? onArrowDown,
  }) {
    return TvFocusable(
      focusNode: focusNode,
      focusMemoryGroupKey: _leftPanelFocusMemoryGroupKey,
      onPressed: onPressed,
      onArrowRight:
          enableRightPanelArrow ? _moveLeftPanelFocusToRightPanel : null,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      onFocusedNodeChanged: _rememberLeftPanelFocusNodeForSearchResult,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          key: containerKey,
          duration: const Duration(milliseconds: 140),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasFocus ? const Color(0xFF757983) : const Color(0xFF4A4D57),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: FontUtils.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// 构建右侧搜索内容区。
  Widget _buildRightPanel(TvSearchData data, bool isLoading) {
    if (_shouldShowSearchResultPanel) {
      return _buildSearchResultPanel();
    }

    if (_shouldShowSuggestionPanel) {
      return _buildSuggestionPanel(data, isLoading);
    }

    final initialFocusTarget = _resolveInitialFocusTarget(data, isLoading);

    return SingleChildScrollView(
      controller: _rightPanelScrollController,
      padding: const EdgeInsets.fromLTRB(
        _rightPanelLeftPadding,
        _panelTopPadding,
        _rightPanelRightPadding,
        42,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWordSection(
            title: '搜索历史',
            words: data.searchHistory,
            emptyText: '暂无搜索历史',
            // 搜索历史保存的是已确认过的关键词，短按后直接进入搜索结果。
            onWordPressed: (word) => unawaited(_performSearch(word)),
            firstItemFocusNode: _historyFirstFocusNode,
            autofocusFirstItem:
                initialFocusTarget == _TvSearchInitialFocusTarget.history,
            focusMemoryGroupKey: _historyWordFocusMemoryGroupKey,
            onItemFocus: _ensureRightPanelFocusCentered,
            onLastRowArrowDown: data.recommends.isNotEmpty
                ? _moveWordFocusDownToRecommendations
                : _keepWordFocusOnArrowDown,
            onClearPressed:
                data.searchHistory.isEmpty ? null : () => _clearSearchHistory(),
          ),
          if (data.hotWords.isNotEmpty) ...[
            const SizedBox(height: 30),
            _buildWordSection(
              title: '搜索热词',
              words: data.hotWords,
              emptyText: '暂无搜索热词',
              // 热词暂时保留“回填输入框”语义，便于后续接真实服务端数据时继续沿用。
              onWordPressed: _setQuery,
              firstItemFocusNode: _hotWordFirstFocusNode,
              autofocusFirstItem:
                  initialFocusTarget == _TvSearchInitialFocusTarget.hotWord,
              focusMemoryGroupKey: _hotWordFocusMemoryGroupKey,
              onItemFocus: _ensureRightPanelFocusCentered,
              onLastRowArrowDown: data.recommends.isEmpty
                  ? _keepWordFocusOnArrowDown
                  : _moveWordFocusDownToRecommendations,
            ),
          ],
          const SizedBox(height: 34),
          _buildRecommendationSection(
            data.recommends,
            isLoading,
            firstCardFocusNode: _recommendFirstFocusNode,
            autofocusFirstCard:
                initialFocusTarget == _TvSearchInitialFocusTarget.recommend,
          ),
        ],
      ),
    );
  }

  /// 构建联想结果模式下的右侧面板。
  ///
  /// 输入首字母后，右侧展示联想词，并在下方保留影片推荐区。
  Widget _buildSuggestionPanel(TvSearchData data, bool isLoading) {
    final suggestionContent = _isSuggestionLoading
        ? _buildSuggestionLoading()
        : _suggestions.isEmpty
            ? _buildEmptyWords('暂无联想结果')
            : _buildSuggestionGrid(
                _suggestions,
                onLastRowArrowDown: data.recommends.isNotEmpty
                    ? _moveWordFocusDownToRecommendations
                    : _keepWordFocusOnArrowDown,
              );

    return SingleChildScrollView(
      controller: _rightPanelScrollController,
      padding: const EdgeInsets.fromLTRB(
        _rightPanelLeftPadding,
        _panelTopPadding,
        _rightPanelRightPadding,
        42,
      ),
      child: Column(
        key: const ValueKey('tv-search-suggestion-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            key: _suggestionTitleKey,
            padding: const EdgeInsets.only(left: _rightPanelContentLeftInset),
            child: Text(
              '联想结果',
              style: FontUtils.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: _rightPanelContentLeftInset),
            child: suggestionContent,
          ),
          if (!_isSuggestionLoading && _suggestions.isNotEmpty) ...[
            const SizedBox(height: 34),
            _buildRecommendationSection(
              data.recommends,
              isLoading,
              firstCardFocusNode: _recommendFirstFocusNode,
              autofocusFirstCard: false,
            ),
          ],
        ],
      ),
    );
  }

  /// 构建联想结果加载态。
  Widget _buildSuggestionLoading() {
    return Container(
      key: const ValueKey('tv-search-suggestion-loading'),
      height: _wordTileExtent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E414B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '联想中...',
        style: FontUtils.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFC5CBD3),
        ),
      ),
    );
  }

  /// 构建联想结果流式词条区。
  ///
  /// 通过手工分行保留“上下滚动浏览”的节奏，同时让词条宽度跟随文案变化，
  /// 避免右侧联想区看起来像固定网格那样过于规整。
  Widget _buildSuggestionGrid(
    List<String> suggestions, {
    VoidCallback? onLastRowArrowDown,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _buildSuggestionRows(
          suggestions: suggestions,
          maxWidth: constraints.maxWidth,
        );

        return Column(
          key: const ValueKey('tv-search-suggestion-grid'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int itemIndex = 0;
                      itemIndex < rows[rowIndex].items.length;
                      itemIndex++) ...[
                    SizedBox(
                      width: rows[rowIndex].items[itemIndex].width,
                      child: _buildSuggestionTile(
                        rows[rowIndex].items[itemIndex].word,
                        focusNode: rows[rowIndex].items[itemIndex].index == 0
                            ? _suggestionFirstFocusNode
                            : null,
                        autofocus: rows[rowIndex].items[itemIndex].index == 0,
                        onArrowLeft: itemIndex == 0
                            ? _moveSuggestionFocusToLeftPanel
                            : null,
                        onArrowRight:
                            itemIndex == rows[rowIndex].items.length - 1
                                ? _keepFocusAtRightEdge
                                : null,
                        onArrowUp: rowIndex == 0
                            ? _moveSuggestionTopRowFocusToLeftPanel
                            : null,
                        onArrowDown: rowIndex == rows.length - 1
                            ? onLastRowArrowDown
                            : null,
                        // 联想区仍处于“筛词”阶段，保持页面静止，
                        // 避免还没进入推荐区就提前触发右侧纵向跟焦。
                        onFocus: null,
                      ),
                    ),
                    if (itemIndex != rows[rowIndex].items.length - 1)
                      const SizedBox(width: _suggestionTileSpacing),
                  ],
                ],
              ),
              if (rowIndex != rows.length - 1)
                const SizedBox(height: _suggestionRowSpacing),
            ],
          ],
        );
      },
    );
  }

  /// 根据右侧可用宽度，把联想词拆成多行。
  ///
  /// 每行首项负责承接从左侧输入区按右键进入的焦点，每行末项负责吃掉右边界。
  List<_TvSuggestionRow> _buildSuggestionRows({
    required List<String> suggestions,
    required double maxWidth,
  }) {
    final availableWidth = maxWidth <= 0 ? _suggestionTileMaxWidth : maxWidth;
    final rows = <_TvSuggestionRow>[];
    var currentItems = <_TvSuggestionTileData>[];
    var currentRowWidth = 0.0;

    for (int index = 0; index < suggestions.length; index++) {
      final word = suggestions[index];
      final tileWidth = _suggestionTileWidth(word, availableWidth);
      final nextRowWidth = currentItems.isEmpty
          ? tileWidth
          : currentRowWidth + _suggestionTileSpacing + tileWidth;

      // 当前行放不下时，先结束上一行，再开始新的一行。
      if (currentItems.isNotEmpty && nextRowWidth > availableWidth) {
        rows.add(_TvSuggestionRow(items: currentItems));
        currentItems = <_TvSuggestionTileData>[];
        currentRowWidth = 0.0;
      }

      currentItems.add(
        _TvSuggestionTileData(
          index: index,
          word: word,
          width: tileWidth,
        ),
      );
      currentRowWidth = currentItems.length == 1
          ? tileWidth
          : currentRowWidth + _suggestionTileSpacing + tileWidth;
    }

    if (currentItems.isNotEmpty) {
      rows.add(_TvSuggestionRow(items: currentItems));
    }

    return rows;
  }

  /// 估算联想词条宽度。
  ///
  /// 直接按当前标题字体测量文本宽度，再补上左右内边距和安全余量，
  /// 让联想词条既贴字又不会显得太挤。
  double _suggestionTileWidth(String word, double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: word,
        style: FontUtils.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: _suggestionTileMaxWidth);

    final measuredWidth = textPainter.width +
        (_suggestionTileHorizontalPadding * 2) +
        _suggestionTileWidthSlack;
    final width = measuredWidth.clamp(0, _suggestionTileMaxWidth).toDouble();
    return width.clamp(0, maxWidth).toDouble();
  }

  /// 构建联想结果词条。
  ///
  /// 仅在获焦时补背景，不再绘制白色描边，保持右侧文字列表更轻。
  Widget _buildSuggestionTile(
    String word, {
    FocusNode? focusNode,
    required bool autofocus,
    VoidCallback? onArrowLeft,
    VoidCallback? onArrowRight,
    VoidCallback? onArrowUp,
    VoidCallback? onArrowDown,
    VoidCallback? onFocus,
  }) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      // 联想词获焦只保留高亮，不触发 Scrollable.ensureVisible。
      // 真正进入影片推荐区后，再恢复右侧纵向跟焦。
      autoScrollOnFocus: false,
      directionalRepeatThrottleGroupKey: _wordTileDirectionalThrottleGroupKey,
      focusMemoryGroupKey: _suggestionFocusMemoryGroupKey,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      onPressed: () => _applySuggestionQuery(word),
      builder: (context, hasFocus) {
        return AnimatedContainer(
          key: ValueKey('tv-search-suggestion-tile-$word'),
          duration: const Duration(milliseconds: 140),
          height: _wordTileExtent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: _suggestionTileHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: hasFocus ? const Color(0xFF5E646E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// 解析搜索页首个默认焦点目标。
  ///
  /// 优先级保持为：搜索历史第一项 > 搜索热词第一项 > 影片推荐第一张卡片。
  _TvSearchInitialFocusTarget _resolveInitialFocusTarget(
    TvSearchData data,
    bool isLoading,
  ) {
    // 有历史时，默认让用户先落到最近一次使用过的搜索词。
    if (data.searchHistory.isNotEmpty) {
      return _TvSearchInitialFocusTarget.history;
    }

    // 没有历史时，回退到热词第一项，方便直接挑选热门内容。
    if (data.hotWords.isNotEmpty) {
      return _TvSearchInitialFocusTarget.hotWord;
    }

    // 词条区域都为空时，再让推荐区第一张卡片接管首焦点。
    if (!isLoading && data.recommends.isNotEmpty) {
      return _TvSearchInitialFocusTarget.recommend;
    }

    return _TvSearchInitialFocusTarget.none;
  }

  /// 在首屏数据准备完成后，把默认焦点交给目标内容区。
  void _dispatchInitialContentFocusIfNeeded(
    TvSearchData data,
    bool isLoading,
  ) {
    if (_didDispatchInitialContentFocus ||
        isLoading ||
        _shouldShowSuggestionPanel ||
        _shouldShowSearchResultPanel) {
      return;
    }

    final target = _resolveInitialFocusTarget(data, isLoading);
    if (target == _TvSearchInitialFocusTarget.none) {
      return;
    }

    _didDispatchInitialContentFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNodeForInitialTarget(target)?.requestFocus();
    });
  }

  /// 根据首焦点目标返回对应焦点节点。
  FocusNode? _focusNodeForInitialTarget(_TvSearchInitialFocusTarget target) {
    return switch (target) {
      _TvSearchInitialFocusTarget.history => _historyFirstFocusNode,
      _TvSearchInitialFocusTarget.hotWord => _hotWordFirstFocusNode,
      _TvSearchInitialFocusTarget.recommend => _recommendFirstFocusNode,
      _TvSearchInitialFocusTarget.none => null,
    };
  }

  /// 构建影片推荐横向列表。
  ///
  /// 搜索页右侧已经有整体边距，这里不再复用首页分区的 72px 内边距。
  Widget _buildRecommendationSection(
    List<VideoInfo> recommends,
    bool isLoading, {
    required FocusNode firstCardFocusNode,
    required bool autofocusFirstCard,
  }) {
    return Column(
      key: const ValueKey('tv-search-recommend-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _rightPanelContentLeftInset),
          child: Text(
            '影片推荐',
            style: FontUtils.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: TvVideoCard.height +
              _recommendListTopSafePadding +
              _recommendListBottomSafePadding,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: isLoading
                      ? _buildRecommendationLoadingList()
                      : _buildRecommendationList(
                          recommends,
                          firstCardFocusNode: firstCardFocusNode,
                          autofocusFirstCard: autofocusFirstCard,
                        ),
                ),
              ),
              if (_recommendLeadingMaskWidth > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _recommendLeadingMaskWidth,
                  child: IgnorePointer(
                    child: ColoredBox(
                      key: const ValueKey('tv-search-recommend-leading-mask'),
                      color: _pageBackgroundColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建推荐加载骨架。
  Widget _buildRecommendationLoadingList() {
    return ListView.separated(
      key: const ValueKey('tv-search-recommend-loading-list'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(
        _rightPanelContentLeftInset,
        _recommendListTopSafePadding,
        70 + _rightPanelContentLeftInset,
        _recommendListBottomSafePadding,
      ),
      itemBuilder: (context, index) {
        return SizedBox(
          width: TvVideoCard.width,
          height: TvVideoCard.height,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: TvVideoCard.width,
              height: TvVideoCard.coverHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1D2225),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2F32)),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: _recommendCardSpacing),
      itemCount: 6,
    );
  }

  /// 构建推荐卡片列表。
  Widget _buildRecommendationList(
    List<VideoInfo> recommends, {
    required FocusNode firstCardFocusNode,
    required bool autofocusFirstCard,
  }) {
    if (recommends.isEmpty) {
      return Container(
        key: const ValueKey('tv-search-recommend-empty'),
        height: 96,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF171A1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2F32)),
        ),
        child: Text(
          '暂无推荐',
          style: FontUtils.poppins(
            fontSize: 16,
            color: const Color(0xFF98A2A8),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('tv-search-recommend-list'),
      controller: _recommendScrollController,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.fromLTRB(
        _rightPanelContentLeftInset,
        _recommendListTopSafePadding,
        70 + _rightPanelContentLeftInset,
        _recommendListBottomSafePadding,
      ),
      itemBuilder: (context, index) {
        final videoInfo = recommends[index];
        final edgeShakeKey = _recommendEdgeShakeKeyFor(index);
        final isFirstItem = index == 0;
        final isLastItem = index == recommends.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: Builder(
            builder: (cardContext) => TvVideoCard(
              videoInfo: videoInfo,
              focusMemoryGroupKey: _recommendFocusMemoryGroupKey,
              autoScrollOnFocus: false,
              focusNode: isFirstItem ? firstCardFocusNode : null,
              autofocus: autofocusFirstCard && isFirstItem,
              onFocusChanged: (hasFocus) {
                if (hasFocus) {
                  if (isFirstItem) {
                    _snapRecommendationListToLeadingEdge();
                  } else {
                    _revealFocusedRecommendationItem(index);
                  }
                  _ensureRightPanelFocusCentered(cardContext);
                }
              },
              onPressed: () => _openVideo(videoInfo),
              onArrowLeft: isFirstItem
                  ? () => _moveRecommendFocusToSearchPanel(index)
                  : null,
              onArrowRight: isLastItem
                  ? () => _handleRecommendEdge(index, AxisDirection.right)
                  : null,
              onArrowUp: _moveRecommendFocusToUpperWordSection,
              onArrowDown: _keepRecommendFocusOnArrowDown,
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: _recommendCardSpacing),
      itemCount: recommends.length,
    );
  }

  /// 获取推荐卡片的边界抖动控制键。
  GlobalKey<TvEdgeShakeState> _recommendEdgeShakeKeyFor(int index) {
    return _recommendEdgeShakeKeys.putIfAbsent(
      index,
      GlobalKey<TvEdgeShakeState>.new,
    );
  }

  /// 处理推荐横向列表越界反馈。
  void _handleRecommendEdge(int index, AxisDirection direction) {
    if (_revealRecommendScrollableEdge(direction)) {
      return;
    }
    _recommendEdgeShakeKeys[index]?.currentState?.shake(direction);
  }

  /// 让推荐列表首卡获焦时回到最左边界。
  ///
  /// 从右向左逐步移动回第一张卡片时，需要先把横向列表滚回真实起点，
  /// 这样首卡左边缘才能重新和“影片推荐”标题保持对齐。
  void _snapRecommendationListToLeadingEdge() {
    if (!_recommendScrollController.hasClients) {
      return;
    }
    final position = _recommendScrollController.position;
    if ((position.pixels - position.minScrollExtent).abs() <= 1) {
      return;
    }
    position.jumpTo(position.minScrollExtent);
  }

  /// 让推荐区获焦卡片稳定停在第 2 个卡位。
  ///
  /// 搜索页推荐区横向浏览时，首卡仍保持贴左起步；从第 2 张开始，
  /// 列表按一个卡片步长逐步推进，让当前卡片尽量保持在固定浏览位。
  void _revealFocusedRecommendationItem(int index) {
    if (!_recommendScrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_recommendScrollController.hasClients) {
        return;
      }
      final position = _recommendScrollController.position;
      final targetOffset = _resolveRecommendationScrollOffset(
        index: index,
        currentPixels: position.pixels,
        minScrollExtent: position.minScrollExtent,
        maxScrollExtent: position.maxScrollExtent,
      );
      if ((position.pixels - targetOffset).abs() <= 1) {
        return;
      }
      position.animateTo(
        targetOffset,
        duration: TvFocusScroll.duration,
        curve: TvFocusScroll.curve,
      );
    });
  }

  /// 计算推荐区获焦卡片对应的目标滚动位置。
  ///
  /// 第 1 张卡片始终由首卡贴左逻辑单独处理；第 2 张卡片及之后的卡片，
  /// 统一按“当前卡片停在第 2 个卡位”换算目标偏移，再夹在真实滚动边界内。
  double _resolveRecommendationScrollOffset({
    required int index,
    required double currentPixels,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    if (index <= _recommendScrollAnchorIndex) {
      return minScrollExtent;
    }

    const cardStride = TvVideoCard.width + _recommendCardSpacing;
    final targetOffset = ((index - _recommendScrollAnchorIndex) * cardStride)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if ((currentPixels - targetOffset).abs() <= 1) {
      return currentPixels;
    }
    return targetOffset;
  }

  /// 让推荐区最左卡片可以返回左侧搜索操作区。
  ///
  /// 优先回到左侧上一次停留的键盘或按钮；没有历史位置时回退到首个可聚焦项。
  void _moveRecommendFocusToSearchPanel(int index) {
    final moved = TvFocusable.requestRememberedFocusForGroup(
      _leftPanelFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _handleRecommendEdge(index, AxisDirection.left);
  }

  /// 让推荐区向上优先回到热词区，再回退到搜索历史区。
  ///
  /// 这样可以避免搜索历史最近拿过焦点后，推荐区上移直接跳错到历史区。
  void _moveRecommendFocusToUpperWordSection() {
    final movedToSuggestions = TvFocusable.requestRememberedFocusForGroup(
      _suggestionFocusMemoryGroupKey,
    );
    if (movedToSuggestions) {
      _revealSuggestionHeaderAfterRecommendReturn();
      return;
    }

    final movedToHotWords = TvFocusable.requestRememberedFocusForGroup(
      _hotWordFocusMemoryGroupKey,
    );
    if (movedToHotWords) {
      return;
    }
    TvFocusable.requestRememberedFocusForGroup(
      _historyWordFocusMemoryGroupKey,
    );
  }

  /// 推荐区返回联想区后，把联想标题重新推回右侧可视区顶部。
  ///
  /// 联想词本身仍保持“获焦不自动跟滚”的静止浏览体验，
  /// 这里只在推荐区回退时补一次标题露出，避免联想区被顶部裁掉。
  void _revealSuggestionHeaderAfterRecommendReturn() {
    if (!_rightPanelScrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rightPanelScrollController.hasClients) {
        return;
      }
      final titleContext = _suggestionTitleKey.currentContext;
      final viewportContext =
          _rightPanelScrollController.position.context.notificationContext;
      if (titleContext == null ||
          !titleContext.mounted ||
          viewportContext == null ||
          !viewportContext.mounted) {
        return;
      }

      final titleRect = _globalRectForContext(titleContext);
      final viewportRect = _globalRectForContext(viewportContext);
      if (titleRect == null || viewportRect == null) {
        return;
      }

      final position = _rightPanelScrollController.position;
      final desiredTop = viewportRect.top;
      final targetOffset = (position.pixels + (titleRect.top - desiredTop))
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((position.pixels - targetOffset).abs() < 1) {
        return;
      }
      position.animateTo(
        targetOffset.toDouble(),
        duration: TvFocusScroll.duration,
        curve: TvFocusScroll.curve,
      );
    });
  }

  /// 吞掉词条区末行下方向键，避免焦点串到左侧字母区。
  ///
  /// 当下方已经没有推荐区或其它合法目标时，继续按下应保持当前词条焦点不变。
  void _keepWordFocusOnArrowDown() {}

  /// 把词条区焦点移动到推荐区。
  ///
  /// 搜索历史、热词和联想词再次向下进入推荐区时，优先回到上次离开的推荐卡片；
  /// 如果当前还没有记忆焦点，再回退到推荐区首张卡片。
  void _moveWordFocusDownToRecommendations() {
    final moved = TvFocusable.requestRememberedFocusForGroup(
      _recommendFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _recommendFirstFocusNode.requestFocus();
  }

  /// 吞掉推荐区下方向键，避免焦点掉出影片推荐列表。
  ///
  /// 搜索页推荐区是右侧内容末端，继续按下键应保持当前卡片不动。
  void _keepRecommendFocusOnArrowDown() {}

  /// 优先露出推荐列表首尾安全留白，再触发边界抖动。
  bool _revealRecommendScrollableEdge(AxisDirection direction) {
    if (!_recommendScrollController.hasClients) {
      return false;
    }

    final position = _recommendScrollController.position;
    final target = switch (direction) {
      AxisDirection.left => position.minScrollExtent,
      AxisDirection.right => position.maxScrollExtent,
      _ => position.pixels,
    };
    if ((position.pixels - target).abs() <= 1) {
      return false;
    }

    // 列表仍有可滚动空间时，先移动到真实边界，避免右侧留白被遥控器卡住。
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  /// 构建纯文字搜索词网格。
  Widget _buildWordSection({
    required String title,
    required List<String> words,
    required String emptyText,
    required ValueChanged<String> onWordPressed,
    required FocusNode firstItemFocusNode,
    required bool autofocusFirstItem,
    required Object focusMemoryGroupKey,
    required ValueChanged<BuildContext> onItemFocus,
    VoidCallback? onClearPressed,
    VoidCallback? onLastRowArrowDown,
  }) {
    return Column(
      key: ValueKey('tv-search-word-section-$title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _rightPanelContentLeftInset),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: FontUtils.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (title == '搜索历史') ...[
                const SizedBox(width: 12),
                _buildHistoryClearButton(
                  onClearPressed,
                  hasHistoryWords: words.isNotEmpty,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: _wordSectionTitleBottomSpacing),
        Padding(
          padding: const EdgeInsets.only(left: _rightPanelContentLeftInset),
          child: words.isEmpty
              ? _buildEmptyWords(emptyText)
              : GridView.builder(
                  key: ValueKey('tv-search-word-grid-$title'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _wordGridColumnCount,
                    mainAxisExtent: _wordTileExtent,
                    crossAxisSpacing: _wordTileCrossSpacing,
                    mainAxisSpacing: _wordTileMainSpacing,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    final isRightEdge =
                        _isWordGridRightEdge(index, words.length);
                    final isLastRow = _isWordGridLastRow(index, words.length);
                    return Builder(
                      builder: (tileContext) => _buildWordTile(
                        words[index],
                        onPressed: () => onWordPressed(words[index]),
                        focusNode: index == 0 ? firstItemFocusNode : null,
                        autofocus: autofocusFirstItem && index == 0,
                        focusMemoryGroupKey: focusMemoryGroupKey,
                        onArrowRight:
                            isRightEdge ? _keepFocusAtRightEdge : null,
                        onArrowDown: isLastRow ? onLastRowArrowDown : null,
                        onFocus: () => onItemFocus(tileContext),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 判断搜索词是否位于当前网格行的最右侧。
  bool _isWordGridRightEdge(int index, int itemCount) {
    final columnIndex = index % _wordGridColumnCount;
    final isFullRowRightEdge = columnIndex == _wordGridColumnCount - 1;
    final isLastItemInShortRow = index == itemCount - 1;
    return isFullRowRightEdge || isLastItemInShortRow;
  }

  /// 判断搜索词是否位于当前网格最后一行。
  bool _isWordGridLastRow(int index, int itemCount) {
    final lastRowStart =
        ((itemCount - 1) ~/ _wordGridColumnCount) * _wordGridColumnCount;
    return index >= lastRowStart;
  }

  /// 构建空搜索词状态。
  Widget _buildEmptyWords(String text) {
    return Container(
      height: _wordTileExtent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E414B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: FontUtils.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFC5CBD3),
        ),
      ),
    );
  }

  /// 构建搜索结果模式下的右侧面板。
  Widget _buildSearchResultPanel() {
    final shouldShowInitialSearchSkeleton =
        _isSearchResultLoading && _aggregatedSearchVideos.isEmpty;
    _dispatchSearchResultInitialFocusIfNeeded(_aggregatedSearchVideos);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _rightPanelLeftPadding,
        _panelTopPadding,
        _rightPanelRightPadding,
        _searchResultPanelBottomInset,
      ),
      child: Stack(
        key: const ValueKey('tv-search-result-panel'),
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: _searchResultHeaderHeight + _searchResultHeaderBottomSpacing,
            child: shouldShowInitialSearchSkeleton
                ? _buildSearchResultInitialSkeleton()
                : TvVideoGrid(
                    key: const ValueKey('tv-search-result-grid-panel'),
                    title: '搜索结果',
                    showTitle: false,
                    videos: _aggregatedSearchVideos,
                    firstItemFocusNode: _searchResultFirstFocusNode,
                    rightPadding: 0,
                    crossAxisCount: _searchResultCrossAxisCount,
                    crossAxisSpacing: _searchResultCrossAxisSpacing,
                    isLoading: false,
                    onLeadingEdgeArrowLeft: _moveSearchResultFocusToLeftPanel,
                    onTopEdgeArrowUp: _keepSearchResultTopFocusOnArrowUp,
                    topEdgeArrowLockCount: _searchResultTopArrowLockedCount,
                    focusMemoryGroupKey: _searchResultFocusMemoryGroupKey,
                    onVideoPressed: _openVideo,
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -_searchResultHeaderTopCoverHeight,
            child: _buildSearchResultHeader(_aggregatedSearchVideos.length),
          ),
        ],
      ),
    );
  }

  /// 构建固定在搜索结果区顶部的标题栏。
  ///
  /// 标题、聚合数量和资源站进度都固定在网格外层，避免随着结果列表一起滚动。
  Widget _buildSearchResultHeader(int aggregatedCount) {
    final progressText = _buildSearchProgressText();

    return Container(
      key: const ValueKey('tv-search-result-header'),
      color: _pageBackgroundColor,
      child: SizedBox(
        height: _searchResultHeaderTopCoverHeight + _searchResultHeaderHeight,
        child: Padding(
          padding:
              const EdgeInsets.only(top: _searchResultHeaderTopCoverHeight),
          child: Container(
            height: _searchResultHeaderHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(
              _searchResultContentLeftInset,
              0,
              0,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '搜索结果',
                    style: FontUtils.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '$aggregatedCount个影片',
                  key: const ValueKey('tv-search-result-count'),
                  style: FontUtils.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD8DDE5),
                  ),
                ),
                if (progressText != null) ...[
                  const SizedBox(width: 18),
                  Text(
                    progressText,
                    key: const ValueKey('tv-search-result-progress'),
                    style: FontUtils.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9CA2AD),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建搜索进度文案。
  ///
  /// 只展示当前已完成/总站源数，避免顶部信息过长挤占结果区宽度。
  String? _buildSearchProgressText() {
    if (_searchTotalResourceCount <= 0) {
      return null;
    }
    return '已搜索 $_searchCompletedResourceCount/$_searchTotalResourceCount 个资源站';
  }

  /// 构建搜索结果首屏雨刷骨架。
  ///
  /// 仅在搜索刚开始且右侧还没有任何聚合结果时显示，避免部分结果已经到达后又被整屏骨架覆盖。
  Widget _buildSearchResultInitialSkeleton() {
    return GridView.builder(
      key: const ValueKey('tv-search-result-initial-skeleton-grid'),
      padding: const EdgeInsets.fromLTRB(
        _searchResultContentLeftInset,
        8,
        0,
        64,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResultCrossAxisCount * 2,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _searchResultCrossAxisCount,
        crossAxisSpacing: _searchResultCrossAxisSpacing,
        mainAxisSpacing: TvVideoGrid.mainAxisSpacing,
        mainAxisExtent: TvVideoCard.height,
      ),
      itemBuilder: (context, index) {
        return const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: TvVideoCard.width,
            height: TvVideoCard.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: TvVideoCard.width,
                  height: TvVideoCard.coverHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: TvCoverLoadingSkeleton(
                      key: ValueKey('tv-search-result-loading-skeleton'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 将搜索结果按片名聚合为搜索页卡片。
  ///
  /// 同片名多来源结果只展示一张卡片，进入详情后再按标题继续补源。
  List<VideoInfo> _aggregateSearchResults(List<SearchResult> results) {
    final groupedResults = <String, List<SearchResult>>{};
    final orderedTitles = <String>[];

    for (final result in results) {
      final normalizedTitle = _normalizeSearchResultTitle(result.title);
      if (normalizedTitle.isEmpty) {
        continue;
      }

      final existingGroup = groupedResults[normalizedTitle];
      if (existingGroup == null) {
        groupedResults[normalizedTitle] = <SearchResult>[result];
        orderedTitles.add(normalizedTitle);
        continue;
      }

      existingGroup.add(result);
    }

    return orderedTitles
        .map((titleKey) => _buildAggregatedVideoInfo(groupedResults[titleKey]!))
        .toList();
  }

  /// 规范化搜索结果片名。
  ///
  /// 搜索页只按片名聚合，这里统一移除空白并折叠大小写差异。
  String _normalizeSearchResultTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }

  /// 根据同片名结果组装搜索页展示卡片。
  ///
  /// 取该组里信息最完整的一条作为代表源，同时把总集数提升为组内最大集数。
  VideoInfo _buildAggregatedVideoInfo(List<SearchResult> results) {
    final representative = results.reduce((currentBest, candidate) {
      final candidateEpisodeCount = candidate.episodes.length;
      final currentEpisodeCount = currentBest.episodes.length;
      if (candidateEpisodeCount != currentEpisodeCount) {
        return candidateEpisodeCount > currentEpisodeCount
            ? candidate
            : currentBest;
      }

      final candidatePosterScore = candidate.poster.trim().isNotEmpty ? 1 : 0;
      final currentPosterScore = currentBest.poster.trim().isNotEmpty ? 1 : 0;
      if (candidatePosterScore != currentPosterScore) {
        return candidatePosterScore > currentPosterScore
            ? candidate
            : currentBest;
      }

      return currentBest;
    });

    final maxEpisodeCount = results
        .map((result) => result.episodes.length)
        .fold<int>(
            0,
            (previousValue, element) =>
                element > previousValue ? element : previousValue);

    final uniqueSources = <String>{};
    for (final result in results) {
      final sourceIdentity = result.sourceName.trim().isNotEmpty
          ? result.sourceName.trim()
          : result.source.trim();
      if (sourceIdentity.isEmpty) {
        continue;
      }
      uniqueSources.add(sourceIdentity);
    }

    final resourceCount =
        uniqueSources.isEmpty ? results.length : uniqueSources.length;
    final resourceSummary = '$resourceCount个资源';

    return VideoInfo(
      id: representative.id,
      source: representative.source,
      title: representative.title,
      sourceName: resourceSummary,
      year: representative.year,
      cover: representative.poster,
      index: 1,
      totalEpisodes: maxEpisodeCount,
      playTime: 0,
      totalTime: 0,
      saveTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      searchTitle: representative.title,
      doubanId: representative.doubanId?.toString(),
    );
  }

  /// 构建搜索词按钮。
  Widget _buildWordTile(
    String word, {
    required VoidCallback onPressed,
    FocusNode? focusNode,
    required bool autofocus,
    required Object focusMemoryGroupKey,
    VoidCallback? onArrowRight,
    VoidCallback? onArrowDown,
    VoidCallback? onFocus,
  }) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      directionalRepeatThrottleGroupKey: _wordTileDirectionalThrottleGroupKey,
      focusMemoryGroupKey: focusMemoryGroupKey,
      onArrowRight: onArrowRight,
      onArrowDown: onArrowDown,
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      onPressed: onPressed,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasFocus ? const Color(0xFF7B7E86) : const Color(0xFF424550),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// 追加搜索输入字符。
  void _appendQuery(String value) {
    _updateQuery(
      '$_query$value',
      preserveSuggestionContext:
          _query.isNotEmpty && _canRestoreSuggestionPanel,
    );
  }

  /// 设置搜索词。
  void _setQuery(String value) {
    _updateQuery(value);
  }

  /// 把联想词回填到输入框。
  ///
  /// 先记住当前首字母联想上下文，方便后续手动搜索后仍可通过返回键回到联想页继续筛词。
  void _applySuggestionQuery(String value) {
    _suggestionQueryBeforeSearch = _query;
    _suggestionsBeforeSearch = List<String>.from(_suggestions);
    _updateQuery(value, preserveSuggestionContext: true);
  }

  /// 执行当前输入框里的搜索词。
  ///
  /// 纯首字母联想态和“联想词回填后的编辑态”都要保留原联想上下文，
  /// 这样结果页返回时还能回到之前那组联想词继续改。
  Future<void> _searchCurrentQuery() async {
    await _performSearch(
      _query,
      preserveSuggestionContext:
          _shouldShowSuggestionPanel || _canRestoreSuggestionPanel,
    );
  }

  /// 判断字母键盘是否处于所在行最右侧。
  ///
  /// 只有最右列项按右键时，才接管焦点并把用户送进联想区。
  bool _isKeyboardRightEdge(int index) {
    const keyboardColumnCount = 6;
    final columnIndex = index % keyboardColumnCount;
    final isFullRowRightEdge = columnIndex == keyboardColumnCount - 1;
    final isLastItemInShortRow = index == _keyboardKeys.length - 1;
    return isFullRowRightEdge || isLastItemInShortRow;
  }

  /// 按当前焦点的水平位置，选择最近的候选节点。
  ///
  /// 左侧键盘与操作按钮之间需要保持“就近回环”，因此统一按中心点横向距离选目标。
  void _requestNearestFocusNodeByCenterX({
    required List<FocusNode> candidateNodes,
    required FocusNode fallbackNode,
  }) {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedRect =
        focusedContext == null ? null : _globalRectForContext(focusedContext);
    if (focusedRect == null) {
      fallbackNode.requestFocus();
      return;
    }

    FocusNode? targetNode;
    double? minDistance;
    for (final focusNode in candidateNodes) {
      final keyRect = _globalRectForFocusNode(focusNode);
      if (keyRect == null) {
        continue;
      }
      final distance = (focusedRect.center.dx - keyRect.center.dx).abs();
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        targetNode = focusNode;
      }
    }

    (targetNode ?? fallbackNode).requestFocus();
  }

  /// 把字母键盘首行上方向环到底部就近按钮。
  ///
  /// 让首行按上时直接落到“清空/搜索/删除”，避免焦点卡在左上角出不去。
  void _moveKeyboardTopRowToBottomActions() {
    _requestNearestFocusNodeByCenterX(
      candidateNodes: <FocusNode>[
        _leftClearActionFocusNode,
        _leftSearchActionFocusNode,
        _leftDeleteActionFocusNode,
      ],
      fallbackNode: _leftClearActionFocusNode,
    );
  }

  /// 左侧操作按钮向下回到字母首行。
  ///
  /// 清空、搜索、删除三种操作都按视觉就近回到首行，避免新增按钮后纵向路径跳列。
  void _moveActionFocusToTopKeyboardRow() {
    _requestNearestFocusNodeByCenterX(
      candidateNodes: _keyboardTopRowFocusNodes,
      fallbackNode: _keyboardTopRowFocusNodes.first,
    );
  }

  /// 左侧操作按钮向上回到底部字母数字区。
  ///
  /// 形成“顶行 -> 操作按钮 -> 底行”的完整纵向焦点闭环，避免在清空/搜索/删除处卡住。
  void _moveBottomActionFocusToKeyboardBottomRow() {
    _requestNearestFocusNodeByCenterX(
      candidateNodes: _keyboardBottomRowFocusNodes,
      fallbackNode: _keyboardBottomRowFocusNodes.first,
    );
  }

  /// 吞掉右边界方向键，避免焦点跳出右侧内容区。
  void _keepFocusAtRightEdge() {}

  /// 把左侧输入区焦点移动到联想区。
  ///
  /// 联想词存在时，优先回到右侧最近一次停留的词条；没有记忆时回到首项。
  void _moveLeftPanelFocusToSuggestions() {
    if (!_shouldShowSuggestionPanel || _suggestions.isEmpty) {
      return;
    }
    final moved = TvFocusable.requestRememberedFocusForGroup(
      _suggestionFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _suggestionFirstFocusNode.requestFocus();
  }

  /// 把左侧输入区焦点移动到右侧内容区。
  ///
  /// 结果页优先进入结果列表，联想页进入联想词，默认主页则按垂直距离
  /// 就近进入搜索历史 / 热词 / 推荐区，避免最右列键位按右后像撞墙。
  void _moveLeftPanelFocusToRightPanel() {
    if (_shouldShowSearchResultPanel) {
      _moveLeftPanelFocusToSearchResults();
      return;
    }
    if (_shouldShowSuggestionPanel) {
      _moveLeftPanelFocusToSuggestions();
      return;
    }
    _moveLeftPanelFocusToDefaultRightPanel();
  }

  /// 把左侧输入区焦点移动到默认右侧内容区。
  ///
  /// 搜索主页默认展示搜索历史、热词和推荐区。这里按当前左侧键位的垂直位置，
  /// 优先回到视觉上最近的右侧分区首项或该分区最近一次停留位置。
  void _moveLeftPanelFocusToDefaultRightPanel() {
    final candidates =
        <({Object groupKey, FocusNode fallbackNode, Rect rect})>[];

    void addCandidate({
      required Object groupKey,
      required FocusNode fallbackNode,
    }) {
      final focusNode = fallbackNode;
      final rect = _globalRectForFocusNode(focusNode);
      if (rect == null || !focusNode.canRequestFocus) {
        return;
      }
      candidates.add((groupKey: groupKey, fallbackNode: focusNode, rect: rect));
    }

    addCandidate(
      groupKey: _historyWordFocusMemoryGroupKey,
      fallbackNode: _historyFirstFocusNode,
    );
    addCandidate(
      groupKey: _hotWordFocusMemoryGroupKey,
      fallbackNode: _hotWordFirstFocusNode,
    );
    addCandidate(
      groupKey: _recommendFocusMemoryGroupKey,
      fallbackNode: _recommendFirstFocusNode,
    );

    if (candidates.isEmpty) {
      return;
    }

    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedRect =
        focusedContext == null ? null : _globalRectForContext(focusedContext);
    if (focusedRect == null) {
      final firstCandidate = candidates.first;
      final moved = TvFocusable.requestRememberedFocusForGroup(
        firstCandidate.groupKey,
      );
      if (!moved) {
        firstCandidate.fallbackNode.requestFocus();
      }
      return;
    }

    ({Object groupKey, FocusNode fallbackNode, Rect rect})? nearestCandidate;
    double? minDistance;
    for (final candidate in candidates) {
      final distance = (focusedRect.center.dy - candidate.rect.center.dy).abs();
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestCandidate = candidate;
      }
    }

    if (nearestCandidate == null) {
      return;
    }

    final moved = TvFocusable.requestRememberedFocusForGroup(
      nearestCandidate.groupKey,
    );
    if (!moved) {
      nearestCandidate.fallbackNode.requestFocus();
    }
  }

  /// 把左侧输入区焦点移动到搜索结果区。
  ///
  /// 优先恢复结果区最近一次停留的卡片；没有记忆时回首张卡片。
  void _moveLeftPanelFocusToSearchResults() {
    if (!_shouldShowSearchResultPanel) {
      return;
    }

    final moved = TvFocusable.requestRememberedFocusForGroup(
      _searchResultFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _searchResultFirstFocusNode.requestFocus();
  }

  /// 把联想区焦点退回左侧输入区。
  ///
  /// 优先恢复左侧最近一次停留的字符键或操作按钮，保持遥控器来回切换手感稳定。
  void _moveSuggestionFocusToLeftPanel() {
    TvFocusable.requestRememberedFocusForGroup(
      _leftPanelFocusMemoryGroupKey,
    );
  }

  /// 把联想区顶行焦点回退到左侧最近一次停留的输入控件。
  ///
  /// 顶行上方没有其它可聚焦词条时，按上直接回左侧更符合遥控器浏览路径，
  /// 避免联想区首行中部词条卡在页面顶部出不去。
  void _moveSuggestionTopRowFocusToLeftPanel() {
    final moved = TvFocusable.requestRememberedFocusForGroup(
      _leftPanelFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _keyboardTopRowFocusNodes.first.requestFocus();
  }

  /// 吞掉搜索结果区顶部卡片的上方向键。
  ///
  /// 标题位于结果区正上方，前四个卡片继续按上时保持原焦点更稳。
  void _keepSearchResultTopFocusOnArrowUp() {}

  /// 把搜索结果区最左列焦点退回左侧输入区。
  ///
  /// 优先恢复左侧最近一次停留的字符键或操作按钮，保持左右切换手感一致。
  void _moveSearchResultFocusToLeftPanel() {
    final rememberedFocusNode = _searchResultRememberedLeftPanelFocusNode;
    if (rememberedFocusNode != null && rememberedFocusNode.canRequestFocus) {
      rememberedFocusNode.requestFocus();
      return;
    }
    _moveSearchResultFocusToNearestKeyboardBridge();
  }

  /// 把搜索结果区首次左移焦点落到左侧就近键位。
  ///
  /// 对应结果区左侧视觉上最近的 `F/L/R/X/4/0` 竖列。
  void _moveSearchResultFocusToNearestKeyboardBridge() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    final focusedRect =
        focusedContext == null ? null : _globalRectForContext(focusedContext);
    if (focusedRect == null) {
      _keyboardTopRowFocusNodes.last.requestFocus();
      return;
    }

    FocusNode? targetNode;
    double? minDistance;
    for (final focusNode in _searchResultKeyboardBridgeNodes) {
      final keyRect = _globalRectForFocusNode(focusNode);
      if (keyRect == null) {
        continue;
      }
      final distance = (focusedRect.center.dy - keyRect.center.dy).abs();
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        targetNode = focusNode;
      }
    }

    (targetNode ?? _keyboardTopRowFocusNodes.last).requestFocus();
  }

  /// 搜索结果首批卡片准备完成后，默认把焦点交给第一张卡片。
  ///
  /// 每轮新搜索只触发一次，避免流式补结果时把用户焦点从左侧抢回右侧。
  void _dispatchSearchResultInitialFocusIfNeeded(List<VideoInfo> videos) {
    if (_didDispatchSearchResultInitialFocus || videos.isEmpty) {
      return;
    }

    _didDispatchSearchResultInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_shouldShowSearchResultPanel) {
        return;
      }
      _searchResultFirstFocusNode.requestFocus();
    });
  }

  /// 让右侧内容获焦项尽量停留在屏幕中段。
  void _ensureRightPanelFocusCentered(BuildContext itemContext) {
    if (!_rightPanelScrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !itemContext.mounted ||
          !_rightPanelScrollController.hasClients) {
        return;
      }
      final itemRect = _globalRectForContext(itemContext);
      final viewportContext =
          _rightPanelScrollController.position.context.notificationContext;
      if (itemRect == null ||
          viewportContext == null ||
          !viewportContext.mounted) {
        return;
      }
      final viewportRect = _globalRectForContext(viewportContext);
      if (viewportRect == null) {
        return;
      }

      final position = _rightPanelScrollController.position;
      final desiredTop = viewportRect.top +
          ((viewportRect.height - itemRect.height) * _rightPanelFocusAlignment);
      final targetOffset = (position.pixels + (itemRect.top - desiredTop))
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((position.pixels - targetOffset).abs() < 1) {
        return;
      }
      position.animateTo(
        targetOffset.toDouble(),
        duration: TvFocusScroll.duration,
        curve: TvFocusScroll.curve,
      );
    });
  }

  /// 获取指定上下文对应控件的全局矩形。
  Rect? _globalRectForContext(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & size;
  }

  /// 获取指定焦点节点对应控件的全局矩形。
  Rect? _globalRectForFocusNode(FocusNode focusNode) {
    final nodeContext = focusNode.context;
    if (nodeContext == null || !nodeContext.mounted) {
      return null;
    }
    return _globalRectForContext(nodeContext);
  }

  /// 删除最后一个搜索字符。
  void _deleteLastQueryChar() {
    if (_query.isEmpty) {
      return;
    }
    final updatedQuery = _query.substring(0, _query.length - 1);
    _updateQuery(
      updatedQuery,
      preserveSuggestionContext:
          updatedQuery.isNotEmpty && _canRestoreSuggestionPanel,
    );
  }

  /// 更新当前搜索输入并触发联想查询。
  ///
  /// TV 搜索页的右侧联想区完全由 [_query] 驱动：
  /// 输入为空时恢复默认内容区，输入非空时切到联想结果模式。
  void _updateQuery(
    String value, {
    bool preserveSuggestionContext = false,
  }) {
    final normalizedQuery = value.trim().toUpperCase();
    if (_query == normalizedQuery) {
      return;
    }

    _searchRequestVersion++;
    _resetSearchResultFocusState();
    setState(() {
      _query = normalizedQuery;
      _resetSearchResultState(isSearchResultLoading: false);
      if (!preserveSuggestionContext) {
        _clearSuggestionSearchContext();
      }
      if (!_shouldShowSuggestionPanel) {
        _suggestions = <String>[];
        _isSuggestionLoading = false;
      } else {
        _isSuggestionLoading = true;
      }
    });

    _loadSearchSuggestions();
  }

  /// 加载当前搜索词对应的联想结果。
  ///
  /// 旧请求返回时，如果页面上已经输入了新的查询串，则直接丢弃旧结果。
  Future<void> _loadSearchSuggestions() async {
    final requestQuery = _query;
    final requestVersion = ++_suggestionRequestVersion;

    if (requestQuery.isEmpty) {
      return;
    }

    if (!_shouldShowSuggestionPanel) {
      return;
    }

    final loader = widget.loadSuggestions ?? SearchService.searchRecommand;
    List<String> suggestions = <String>[];
    try {
      suggestions = await loader(requestQuery);
    } catch (_) {
      suggestions = <String>[];
    }

    if (!mounted ||
        requestVersion != _suggestionRequestVersion ||
        requestQuery != _query) {
      return;
    }

    final normalizedSuggestions = _dedupeSuggestions(suggestions);
    setState(() {
      _suggestions = normalizedSuggestions;
      _isSuggestionLoading = false;
    });
  }

  /// 执行真正的搜索。
  ///
  /// 手动确认后立即发起搜索，并让右侧切换成结果 Grid。
  Future<void> _performSearch(
    String query, {
    bool preserveSuggestionContext = false,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }

    final requestVersion = ++_searchRequestVersion;
    _resetSearchResultFocusState();
    setState(() {
      if (preserveSuggestionContext) {
        if (!_canRestoreSuggestionPanel) {
          _suggestionQueryBeforeSearch = _query;
          _suggestionsBeforeSearch = List<String>.from(_suggestions);
        }
      } else {
        _clearSuggestionSearchContext();
      }
      _query = normalizedQuery;
      _suggestions = <String>[];
      _isSuggestionLoading = false;
      _resetSearchResultState(isSearchResultLoading: true);
    });

    await Future<void>.delayed(Duration.zero);

    // 搜索历史改为异步后台写入，避免写历史接口阻塞右侧实时出结果。
    unawaited(_saveSearchHistory(normalizedQuery));

    final progressLoader = widget.loadSearchResultsWithProgress;
    final basicLoader = widget.loadSearchResults ?? SearchService.searchSync;
    List<SearchResult> results = <SearchResult>[];
    try {
      if (progressLoader != null) {
        results = await progressLoader(
          normalizedQuery,
          onPartialResults: (partialResults) {
            if (!mounted || requestVersion != _searchRequestVersion) {
              return;
            }
            setState(() {
              _searchResults = partialResults;
              _syncAggregatedSearchVideos();
            });
          },
          onProgress: (progress) {
            if (!mounted || requestVersion != _searchRequestVersion) {
              return;
            }
            setState(() {
              _searchTotalResourceCount = progress.totalResources;
              _searchCompletedResourceCount = progress.completedResources;
            });
          },
        );
      } else if (widget.loadSearchResults != null) {
        results = await basicLoader(normalizedQuery);
        if (mounted && requestVersion == _searchRequestVersion) {
          setState(() {
            _searchResults = results;
            _syncAggregatedSearchVideos();
          });
        }
      } else {
        results = await SearchService.searchSync(
          normalizedQuery,
          onPartialResults: (partialResults) {
            if (!mounted || requestVersion != _searchRequestVersion) {
              return;
            }
            setState(() {
              _searchResults = partialResults;
              _syncAggregatedSearchVideos();
            });
          },
          onProgress: (progress) {
            if (!mounted || requestVersion != _searchRequestVersion) {
              return;
            }
            setState(() {
              _searchTotalResourceCount = progress.totalResources;
              _searchCompletedResourceCount = progress.completedResources;
            });
          },
        );
      }
    } catch (_) {
      results = <SearchResult>[];
    }

    if (!mounted || requestVersion != _searchRequestVersion) {
      return;
    }

    setState(() {
      _searchResults = results;
      _syncAggregatedSearchVideos();
      _isSearchResultLoading = false;
      if (_searchTotalResourceCount > 0 &&
          _searchCompletedResourceCount < _searchTotalResourceCount) {
        _searchCompletedResourceCount = _searchTotalResourceCount;
      }
    });
  }

  /// 保存搜索历史。
  ///
  /// 维持 TV 搜索页与普通搜索页一致的“确认搜索即记历史”行为。
  Future<void> _saveSearchHistory(String query) async {
    final cacheService = PageCacheService();
    final loadSearchData =
        widget.loadSearchData ?? TvSearchScreen.defaultLoadSearchData;
    try {
      await cacheService.addSearchHistory(query, context);
      if (!mounted) {
        return;
      }
      final currentData = await loadSearchData(context);
      if (!mounted) {
        return;
      }
      setState(() {
        _didDispatchInitialContentFocus = false;
        _searchDataFuture = Future<TvSearchData>.value(currentData);
      });
    } catch (_) {
      // 搜索历史保存失败时保持静默，不影响当前搜索链路。
    }
  }

  /// 对联想结果做稳定去重。
  ///
  /// 统一折叠多余空白，并保留首个出现的原始标题文案。
  List<String> _dedupeSuggestions(List<String> suggestions) {
    final orderedSuggestions = <String>[];
    final seenSuggestions = <String>{};
    for (final suggestion in suggestions) {
      final normalizedSuggestion =
          suggestion.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalizedSuggestion.isEmpty ||
          !seenSuggestions.add(normalizedSuggestion)) {
        continue;
      }
      orderedSuggestions.add(normalizedSuggestion);
    }
    return orderedSuggestions;
  }

  /// 清空搜索历史。
  Future<void> _clearSearchHistory() async {
    final confirmed = await showTvConfirmDialog(
      context: context,
      title: '清空搜索历史',
      message: '确定要清空全部搜索记录吗？',
      confirmLabel: '清空',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final clearHistory =
        widget.onClearSearchHistory ?? TvSearchScreen.defaultClearSearchHistory;
    final cleared = await clearHistory(context);
    if (!cleared || !mounted) {
      return;
    }

    setState(() {
      // 清空后重新请求搜索页数据，让历史、热词和推荐区一起保持统一来源。
      _didDispatchInitialContentFocus = false;
      _searchDataFuture =
          (widget.loadSearchData ?? TvSearchScreen.defaultLoadSearchData)(
        context,
      );
    });
  }

  /// 构建搜索历史标题右侧清空按钮。
  Widget _buildHistoryClearButton(
    VoidCallback? onPressed, {
    required bool hasHistoryWords,
  }) {
    return TvFocusable(
      focusNode: _historyClearButtonFocusNode,
      onPressed: onPressed,
      autoScrollOnFocus: false,
      onArrowDown: () => _moveHistoryClearFocusDown(
        hasHistoryWords: hasHistoryWords,
      ),
      builder: (context, hasFocus) {
        return AnimatedContainer(
          key: const ValueKey('tv-search-history-clear-button'),
          duration: const Duration(milliseconds: 140),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasFocus ? const Color(0xFF747881) : const Color(0xFF3C4048),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: hasFocus ? Colors.white : const Color(0xFF535861),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: Text(
            '清空',
            style: FontUtils.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// 搜索历史标题清空按钮向下时的焦点规则。
  ///
  /// 有历史先回第一条历史；没有历史时优先回影片推荐上次焦点，没有记忆再回首卡。
  void _moveHistoryClearFocusDown({
    required bool hasHistoryWords,
  }) {
    if (hasHistoryWords) {
      _historyFirstFocusNode.requestFocus();
      return;
    }

    final moved = TvFocusable.requestRememberedFocusForGroup(
      _recommendFocusMemoryGroupKey,
    );
    if (moved) {
      return;
    }
    _recommendFirstFocusNode.requestFocus();
  }

  /// 打开 TV 详情页。
  void _openVideo(VideoInfo videoInfo) {
    TvRoute.push<void>(context, TvVideoDetailScreen(videoInfo: videoInfo));
  }
}

/// 搜索页首焦点目标。
enum _TvSearchInitialFocusTarget {
  /// 不主动指定首焦点。
  none,

  /// 默认聚焦搜索历史首项。
  history,

  /// 默认聚焦搜索热词首项。
  hotWord,

  /// 默认聚焦推荐区首张卡片。
  recommend,
}

/// TV 联想区单行数据。
class _TvSuggestionRow {
  /// 创建联想区单行数据。
  const _TvSuggestionRow({
    required this.items,
  });

  /// 当前行中的联想词条。
  final List<_TvSuggestionTileData> items;
}

/// TV 联想词条布局数据。
class _TvSuggestionTileData {
  /// 创建联想词条布局数据。
  const _TvSuggestionTileData({
    required this.index,
    required this.word,
    required this.width,
  });

  /// 联想词在原始列表中的下标。
  final int index;

  /// 联想词文案。
  final String word;

  /// 当前词条渲染宽度。
  final double width;
}
