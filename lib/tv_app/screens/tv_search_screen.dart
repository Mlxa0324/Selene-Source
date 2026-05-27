import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 搜索页数据加载函数。
///
/// [context] 用于复用现有搜索历史和推荐数据上下文。
typedef TvSearchDataLoader = Future<TvSearchData> Function(
    BuildContext context);

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
/// 左侧提供遥控器字母输入区，右侧展示搜索历史、搜索热词和推荐影片。
class TvSearchScreen extends StatefulWidget {
  /// 创建 TV 搜索页面。
  ///
  /// [loadSearchData] 可在测试中注入搜索历史和推荐数据。
  const TvSearchScreen({
    super.key,
    this.loadSearchData,
  });

  /// 搜索页数据加载函数。
  final TvSearchDataLoader? loadSearchData;

  /// mock 搜索热词。
  ///
  /// 先使用本地静态数据，后续有接口时再替换为服务端数据。
  static const List<String> mockHotWords = [
    '剑来',
    '主角',
    '黑袍纠察队第五季',
    '仙逆',
    '完美世界',
    '斗破苍穹年番',
    '牧神记',
    '雨霖铃',
    '低智商犯罪',
    '飞驰人生3',
  ];

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
      hotWords: mockHotWords,
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
      final movies = await cacheService.getHotMovies(context);
      return (movies ?? []).map((movie) => movie.toVideoInfo()).toList();
    } catch (_) {
      return <VideoInfo>[];
    }
  }
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  /// 搜索页首屏顶部留白。
  ///
  /// 左右面板共用，避免搜索入口和搜索历史默认状态显得偏下。
  static const double _panelTopPadding = 56;

  /// 搜索词列表列数。
  static const int _wordGridColumnCount = 3;

  /// 搜索词列表项高度。
  static const double _wordTileExtent = 52;

  /// 搜索词列表横向间距。
  static const double _wordTileCrossSpacing = 20;

  /// 搜索词列表纵向间距。
  static const double _wordTileMainSpacing = 18;

  /// 搜索页数据任务。
  Future<TvSearchData>? _searchDataFuture;

  /// 当前搜索输入内容。
  String _query = '';

  /// 推荐影片横向列表控制器。
  final ScrollController _recommendScrollController = ScrollController();

  /// 推荐影片卡片边界抖动控制键。
  final Map<int, GlobalKey<TvEdgeShakeState>> _recommendEdgeShakeKeys = {};

  /// 搜索历史首项焦点节点。
  final FocusNode _historyFirstFocusNode = FocusNode();

  /// 搜索热词首项焦点节点。
  final FocusNode _hotWordFirstFocusNode = FocusNode();

  /// 推荐区首张卡片焦点节点。
  final FocusNode _recommendFirstFocusNode = FocusNode();

  /// 是否已经完成首屏默认焦点分发。
  bool _didDispatchInitialContentFocus = false;

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
    _historyFirstFocusNode.dispose();
    _hotWordFirstFocusNode.dispose();
    _recommendFirstFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      autofocus: true,
      child: Scaffold(
        key: const ValueKey('tv-search-screen'),
        backgroundColor: const Color(0xFF10131D),
        body: SafeArea(
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
                    width: 404,
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
    );
  }

  /// 构建左侧搜索输入区。
  Widget _buildLeftPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(70, _panelTopPadding, 48, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
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
          Text(
            '如不习惯 TV 搜索方式，请使用电视联播功能',
            style: FontUtils.poppins(
              fontSize: 12,
              color: const Color(0xFF7F858F),
            ),
          ),
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
        return TvFocusable(
          onPressed: () => _appendQuery(keyLabel),
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

  /// 构建清空和删除按钮。
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: '清空',
            onPressed: () => setState(() => _query = ''),
          ),
        ),
        const SizedBox(width: 68),
        Expanded(
          child: _buildActionButton(
            label: '删除',
            onPressed: _deleteLastQueryChar,
          ),
        ),
      ],
    );
  }

  /// 构建搜索页操作按钮。
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TvFocusable(
      onPressed: onPressed,
      builder: (context, hasFocus) {
        return AnimatedContainer(
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
    final initialFocusTarget = _resolveInitialFocusTarget(data, isLoading);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, _panelTopPadding, 70, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWordSection(
            title: '搜索历史',
            words: data.searchHistory,
            emptyText: '暂无搜索历史',
            firstItemFocusNode: _historyFirstFocusNode,
            autofocusFirstItem:
                initialFocusTarget == _TvSearchInitialFocusTarget.history,
          ),
          const SizedBox(height: 28),
          _buildWordSection(
            title: '搜索热词',
            words: data.hotWords,
            emptyText: '暂无搜索热词',
            firstItemFocusNode: _hotWordFirstFocusNode,
            autofocusFirstItem:
                initialFocusTarget == _TvSearchInitialFocusTarget.hotWord,
          ),
          const SizedBox(height: 20),
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
    if (_didDispatchInitialContentFocus || isLoading) {
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
    bool isLoading,
    {
    required FocusNode firstCardFocusNode,
    required bool autofocusFirstCard,
  }
  ) {
    return Column(
      key: const ValueKey('tv-search-recommend-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '影片推荐',
          style: FontUtils.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: TvVideoCard.height + 42,
          child: isLoading
              ? _buildRecommendationLoadingList()
              : _buildRecommendationList(
                  recommends,
                  firstCardFocusNode: firstCardFocusNode,
                  autofocusFirstCard: autofocusFirstCard,
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
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(0, 12, 70, 22),
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
      separatorBuilder: (_, __) => const SizedBox(width: 24),
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
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(0, 12, 70, 22),
      itemBuilder: (context, index) {
        final videoInfo = recommends[index];
        final edgeShakeKey = _recommendEdgeShakeKeyFor(index);
        final isFirstItem = index == 0;
        final isLastItem = index == recommends.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: TvVideoCard(
            videoInfo: videoInfo,
            focusMemoryGroupKey: 'tv-search-recommend-list',
            focusNode: isFirstItem ? firstCardFocusNode : null,
            autofocus: autofocusFirstCard && isFirstItem,
            onPressed: () => _openVideo(videoInfo),
            onArrowLeft: isFirstItem
                ? () => _handleRecommendEdge(index, AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => _handleRecommendEdge(index, AxisDirection.right)
                : null,
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 24),
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
    required FocusNode firstItemFocusNode,
    required bool autofocusFirstItem,
  }) {
    return Column(
      key: ValueKey('tv-search-word-section-$title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FontUtils.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        if (words.isEmpty)
          _buildEmptyWords(emptyText)
        else
          GridView.builder(
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
            itemBuilder: (context, index) => _buildWordTile(
              words[index],
              focusNode: index == 0 ? firstItemFocusNode : null,
              autofocus: autofocusFirstItem && index == 0,
            ),
          ),
      ],
    );
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

  /// 构建搜索词按钮。
  Widget _buildWordTile(
    String word, {
    FocusNode? focusNode,
    required bool autofocus,
  }) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      directionalRepeatThrottleGroupKey: 'tv-search-word-tiles',
      focusMemoryGroupKey: 'tv-search-word-tiles',
      onPressed: () => _setQuery(word),
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
              fontSize: 19,
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
    setState(() {
      _query += value;
    });
  }

  /// 设置搜索词。
  void _setQuery(String value) {
    setState(() {
      _query = value;
    });
  }

  /// 删除最后一个搜索字符。
  void _deleteLastQueryChar() {
    if (_query.isEmpty) {
      return;
    }
    setState(() {
      _query = _query.substring(0, _query.length - 1);
    });
  }

  /// 打开 TV 详情页。
  void _openVideo(VideoInfo videoInfo) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TvVideoDetailScreen(videoInfo: videoInfo),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
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
