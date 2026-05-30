import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_section_title.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 视频区块点击回调。
///
/// [videoInfo] 为当前选中的视频数据。
typedef TvVideoPressed = void Function(VideoInfo videoInfo);

/// TV 首页横向内容区。
///
/// 用于展示继续观看、热门内容、播放历史和收藏夹等区块。
class TvHomeSection extends StatelessWidget {
  /// 创建 TV 首页内容区。
  ///
  /// [title] 为区块标题。
  /// [videos] 为区块视频列表。
  /// [onVideoPressed] 为卡片点击回调。
  const TvHomeSection({
    super.key,
    required this.title,
    required this.videos,
    this.titleHint,
    this.pendingFocusVideoId,
    this.onVideoPressed,
    this.onVideoLongPressed,
    this.onMorePressed,
    this.isLoading = false,
    this.scrollController,
    this.autofocusFirstItem = false,
    this.firstItemFocusNode,
    this.onArrowUpFromAnyItem,
    this.onArrowUpFromFirstItem,
    this.onArrowDownToNextSection,
  });

  /// 首页分区最大展示影视数量。
  static const int maxVisibleVideos = 15;

  /// 首页横向卡片间距。
  static const double cardSpacing = 18;

  /// 首页横向列表从第 5 个卡片开始触发滚动。
  ///
  /// 这里使用 0-based 下标，因此值为 `4`。
  static const int scrollStartIndex = 4;

  /// 计算首页横向区块的目标滚动位置。
  ///
  /// 首页横向列表改为按卡片序号直接控制开始滚动的时机，
  /// 避免再被“是否越过半屏触发线”这类条件影响体感。
  ///
  /// 约定：
  /// 1. 前 4 个卡片保持不滚动。
  /// 2. 第 5 个卡片获焦时，列表开始向左推进 1 个卡片步长。
  /// 3. 后续每往右一个卡片，列表继续按 1 个卡片步长推进。
  @visibleForTesting
  static double resolveScrollOffset({
    required int index,
    required double currentPixels,
    required double viewportDimension,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    if (index < scrollStartIndex) {
      return currentPixels;
    }

    // 这里不再依赖 viewportDimension，而是显式按卡片步长推进，
    // 让 scrollStartIndex 的调整能稳定映射到真实体感。
    const cardStride = TvVideoCard.width + cardSpacing;
    final targetOffset = ((index - scrollStartIndex + 1) * cardStride)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();

    if ((currentPixels - targetOffset).abs() <= 1) {
      return currentPixels;
    }

    return targetOffset;
  }

  /// 区块标题。
  final String title;

  /// 区块标题右侧弱提示文案。
  final String? titleHint;

  /// 刷新后优先恢复焦点的视频 ID。
  final String? pendingFocusVideoId;

  /// 视频列表数据。
  final List<VideoInfo> videos;

  /// 卡片点击回调。
  final TvVideoPressed? onVideoPressed;

  /// 卡片长按回调。
  final TvVideoPressed? onVideoLongPressed;

  /// 查看更多点击回调。
  final VoidCallback? onMorePressed;

  /// 是否处于加载状态。
  final bool isLoading;

  /// 横向列表滚动控制器。
  ///
  /// 默认由区块内部管理，测试或特殊场景可传入外部控制器。
  final ScrollController? scrollController;

  /// 是否把第一个卡片作为默认内容焦点入口。
  final bool autofocusFirstItem;

  /// 第一个卡片的外部焦点节点。
  final FocusNode? firstItemFocusNode;

  /// 任意卡片按上方向键时的回调。
  ///
  /// 仅当整个分区都需要把上键交给外层时使用，例如首页第一排任意卡片
  /// 都需要回到顶部导航。
  final VoidCallback? onArrowUpFromAnyItem;

  /// 首个卡片按上方向键时的回调。
  final VoidCallback? onArrowUpFromFirstItem;

  /// 任意卡片按下方向键时进入下一分区的回调。
  final VoidCallback? onArrowDownToNextSection;

  @override
  Widget build(BuildContext context) {
    return _TvHomeSectionBody(
      title: title,
      titleHint: titleHint,
      pendingFocusVideoId: pendingFocusVideoId,
      videos: videos,
      onVideoPressed: onVideoPressed,
      onVideoLongPressed: onVideoLongPressed,
      onMorePressed: onMorePressed,
      isLoading: isLoading,
      scrollController: scrollController,
      autofocusFirstItem: autofocusFirstItem,
      firstItemFocusNode: firstItemFocusNode,
      onArrowUpFromAnyItem: onArrowUpFromAnyItem,
      onArrowUpFromFirstItem: onArrowUpFromFirstItem,
      onArrowDownToNextSection: onArrowDownToNextSection,
    );
  }
}

/// TV 首页横向内容区主体。
class _TvHomeSectionBody extends StatefulWidget {
  /// 创建 TV 首页横向内容区主体。
  const _TvHomeSectionBody({
    required this.title,
    required this.videos,
    required this.isLoading,
    this.titleHint,
    this.pendingFocusVideoId,
    this.onVideoPressed,
    this.onVideoLongPressed,
    this.onMorePressed,
    this.scrollController,
    this.autofocusFirstItem = false,
    this.firstItemFocusNode,
    this.onArrowUpFromAnyItem,
    this.onArrowUpFromFirstItem,
    this.onArrowDownToNextSection,
  });

  /// 区块标题。
  final String title;

  /// 区块标题右侧弱提示文案。
  final String? titleHint;

  /// 刷新后优先恢复焦点的视频 ID。
  final String? pendingFocusVideoId;

  /// 视频列表数据。
  final List<VideoInfo> videos;

  /// 卡片点击回调。
  final TvVideoPressed? onVideoPressed;

  /// 卡片长按回调。
  final TvVideoPressed? onVideoLongPressed;

  /// 查看更多点击回调。
  final VoidCallback? onMorePressed;

  /// 是否处于加载状态。
  final bool isLoading;

  /// 横向列表滚动控制器。
  final ScrollController? scrollController;

  /// 是否把第一个卡片作为默认内容焦点入口。
  final bool autofocusFirstItem;

  /// 第一个卡片的外部焦点节点。
  final FocusNode? firstItemFocusNode;

  /// 任意卡片按上方向键时的回调。
  final VoidCallback? onArrowUpFromAnyItem;

  /// 首个卡片按上方向键时的回调。
  final VoidCallback? onArrowUpFromFirstItem;

  /// 任意卡片按下方向键时进入下一分区的回调。
  final VoidCallback? onArrowDownToNextSection;

  @override
  State<_TvHomeSectionBody> createState() => _TvHomeSectionBodyState();
}

class _TvHomeSectionBodyState extends State<_TvHomeSectionBody> {
  /// 当前横向列表获焦卡片下标。
  ///
  /// 由列表级共享焦点框读取，用于在同一行左右移动时平滑移动外边框。
  int? _focusedItemIndex;

  /// 当前分区是否已有任一卡片获得焦点。
  ///
  /// 用于识别“首次进入该分区”和“同分区内左右移动”这两种场景，
  /// 仅在真正进入分区时才驱动整块分区做纵向滚动。
  bool _sectionHasFocusedDescendant = false;

  /// 当前区块根节点，用于卡片获焦时驱动首页纵向滚动。
  final GlobalKey _sectionKey = GlobalKey();

  /// 当前分区自己的焦点域。
  ///
  /// 用于判断用户是否已经离开该横向分区，离开后再把横向列表复位到开头。
  final FocusScopeNode _sectionFocusScopeNode = FocusScopeNode(
    debugLabel: 'tv-home-section-scope',
  );

  /// 横向列表卡片边界抖动控制键。
  final Map<int, GlobalKey<TvEdgeShakeState>> _edgeShakeKeys = {};

  /// 区块内部横向列表控制器。
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  /// 区块内卡片稳定焦点节点。
  final Map<String, FocusNode> _videoFocusNodes = {};

  /// 当前分区横向列表真实挂载的滚动位置。
  ///
  /// 外部可能在切页动画期间把同一个 [ScrollController] 临时挂到多棵列表树上，
  /// 这里缓存当前分区自己的 position，避免直接读取 controller.position 触发断言。
  ScrollPosition? _listScrollPosition;

  /// 当前区块的焦点记忆分组。
  Object get _focusMemoryGroupKey => 'tv-home-section-${widget.title}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleHorizontalScrollChange);
  }

  /// 获取指定视频的稳定焦点节点。
  FocusNode _focusNodeForVideoId(String videoId) {
    return _videoFocusNodes.putIfAbsent(
      videoId,
      () => FocusNode(debugLabel: 'tv-home-section-video-$videoId'),
    );
  }

  @override
  void didUpdateWidget(covariant _TvHomeSectionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetVideoId = widget.pendingFocusVideoId;
    if (targetVideoId == null ||
        targetVideoId == oldWidget.pendingFocusVideoId ||
        !widget.videos.any((video) => video.id == targetVideoId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNodeForVideoId(targetVideoId).requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleHorizontalScrollChange);
    _detachListScrollPosition();
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    _sectionFocusScopeNode.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// 横向滚动时同步刷新列表级焦点框位置。
  void _handleHorizontalScrollChange() {
    if (!mounted || _focusedItemIndex == null) {
      return;
    }
    setState(() {});
  }

  /// 记录当前分区实际使用的滚动位置。
  void _attachListScrollPosition(ScrollPosition position) {
    if (identical(_listScrollPosition, position)) {
      return;
    }
    _detachListScrollPosition();
    _listScrollPosition = position;
  }

  /// 解除当前分区滚动位置监听。
  void _detachListScrollPosition() {
    _listScrollPosition = null;
  }

  /// 获取当前分区横向列表的滚动位置。
  ScrollPosition? get _currentScrollPosition {
    final position = _listScrollPosition;
    if (position == null || !position.hasPixels || !position.hasContentDimensions) {
      final positions = _scrollController.positions;
      if (positions.isEmpty) {
        return null;
      }
      return positions.last;
    }
    return position;
  }

  /// 基于滚动通知同步当前分区的滚动位置。
  bool _handleScrollNotification(ScrollNotification notification) {
    final scrollableState = Scrollable.maybeOf(notification.context!);
    final position = scrollableState?.position;
    if (position != null) {
      _attachListScrollPosition(position);
    }
    return false;
  }

  /// 卡片获得焦点时，把当前区块平滑滚动到大屏适合浏览的位置。
  void _handleItemFocusChange(
    bool hasFocus,
    int index, {
    required bool usesSmoothFrame,
  }) {
    if (!hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sectionFocusScopeNode.hasFocus) {
          return;
        }
        setState(() {
          _focusedItemIndex = null;
        });
        _sectionHasFocusedDescendant = false;
        _resetHorizontalScrollToLeadingEdge();
      });
      return;
    }

    if (usesSmoothFrame) {
      setState(() {
        _focusedItemIndex = index;
      });
    }
    final enteringFromOutside = !_sectionHasFocusedDescendant;
    _sectionHasFocusedDescendant = true;
    _revealFocusedItem(index);
    if (!enteringFromOutside) {
      return;
    }

    final sectionContext = _sectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }

    TvFocusScroll.ensureVisible(
      sectionContext,
      alignment: TvFocusScroll.sectionAlignment,
    );
  }

  /// 当焦点离开整个分区后，把横向列表复位到最左侧。
  void _resetHorizontalScrollToLeadingEdge() {
    final position = _currentScrollPosition;
    if (position == null) {
      return;
    }
    if ((position.pixels - position.minScrollExtent).abs() <= 1) {
      return;
    }
    position.jumpTo(position.minScrollExtent);
  }

  /// 当焦点抵达约定卡位后，按卡片步长推动横向列表。
  void _revealFocusedItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final position = _currentScrollPosition;
      if (position == null) {
        return;
      }
      final targetOffset = TvHomeSection.resolveScrollOffset(
        index: index,
        currentPixels: position.pixels,
        viewportDimension: position.viewportDimension,
        minScrollExtent: position.minScrollExtent,
        maxScrollExtent: position.maxScrollExtent,
      );
      if ((position.pixels - targetOffset).abs() <= 1) {
        return;
      }

      position.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// 获取指定位置的边界抖动控制键。
  GlobalKey<TvEdgeShakeState> _edgeShakeKeyFor(int index) {
    return _edgeShakeKeys.putIfAbsent(index, GlobalKey<TvEdgeShakeState>.new);
  }

  /// 处理横向列表卡片越界时的边界反馈。
  void _handleEdge(int index, AxisDirection direction) {
    if (_revealScrollableEdge(direction)) {
      return;
    }
    _edgeShakeKeys[index]?.currentState?.shake(direction);
  }

  /// 优先展示横向列表首尾 padding，再触发真正的边界反馈。
  bool _revealScrollableEdge(AxisDirection direction) {
    final position = _currentScrollPosition;
    if (position == null) {
      return false;
    }
    final target = switch (direction) {
      AxisDirection.left => position.minScrollExtent,
      AxisDirection.right => position.maxScrollExtent,
      _ => position.pixels,
    };
    if ((position.pixels - target).abs() <= 1) {
      return false;
    }

    // 还有可滚动余量时先把列表推到真实边界，让首尾安全留白完整露出。
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _sectionFocusScopeNode,
      child: RepaintBoundary(
        child: Padding(
          key: _sectionKey,
          padding: const EdgeInsets.only(bottom: 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TvLayout.pageHorizontalPadding,
                ),
                child: TvSectionTitle(
                  title: widget.title,
                  titleHint: widget.titleHint,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: TvVideoCard.height + 42,
                child:
                    widget.isLoading ? _buildLoadingList() : _buildVideoList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建加载骨架列表。
  Widget _buildLoadingList() {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(
          TvLayout.pageHorizontalPadding,
          12,
          TvLayout.pageHorizontalPadding,
          22,
        ),
        itemBuilder: (context, index) => SizedBox(
          width: TvVideoCard.width,
          height: TvVideoCard.height,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              key: const ValueKey('tv-home-loading-card'),
              width: TvVideoCard.width,
              height: TvVideoCard.coverHeight,
              decoration: BoxDecoration(
                color: TvThemeColors.cardSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TvThemeColors.cardSurfaceBorder),
              ),
            ),
          ),
        ),
        separatorBuilder: (_, __) =>
            const SizedBox(width: TvHomeSection.cardSpacing),
        itemCount: 6,
      ),
    );
  }

  /// 构建视频卡片列表。
  Widget _buildVideoList() {
    if (widget.videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TvLayout.pageHorizontalPadding,
        ),
        child: Container(
          width: double.infinity,
          height: 96,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: TvThemeColors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TvThemeColors.cardSurfaceBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '暂无内容',
            style: FontUtils.poppins(
              fontSize: 16,
              color: const Color(0xFF98A2A8),
            ),
          ),
        ),
      );
    }

    final showMore = widget.videos.length > TvHomeSection.maxVisibleVideos &&
        widget.onMorePressed != null;
    final visibleVideos =
        widget.videos.take(TvHomeSection.maxVisibleVideos).toList();
    final itemCount = visibleVideos.length + (showMore ? 1 : 0);
    final usesSmoothFrame =
        TvTheme.focusEffectModeOf(context) == TvFocusEffectMode.smoothFrame;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView.separated(
            key: ValueKey('tv-home-section-list-${widget.title}'),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(
              TvLayout.pageHorizontalPadding,
              12,
              TvLayout.pageHorizontalPadding,
              22,
            ),
            itemBuilder: (context, index) {
              final edgeShakeKey = _edgeShakeKeyFor(index);
              final isFirstItem = index == 0;
              final isLastItem = index == itemCount - 1;
              final onArrowUp = widget.onArrowUpFromAnyItem ??
                  (isFirstItem ? widget.onArrowUpFromFirstItem : null);
              Widget item;
              if (showMore && index == visibleVideos.length) {
                item = _TvMoreCard(
                  focusMemoryGroupKey: _focusMemoryGroupKey,
                  autofocus: widget.autofocusFirstItem && index == 0,
                  focusNode: index == 0 ? widget.firstItemFocusNode : null,
                  onPressed: widget.onMorePressed!,
                  onFocusChanged: (hasFocus) => _handleItemFocusChange(
                    hasFocus,
                    index,
                    usesSmoothFrame: usesSmoothFrame,
                  ),
                  onArrowLeft: isFirstItem
                      ? () => _handleEdge(index, AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () => _handleEdge(index, AxisDirection.right)
                      : null,
                  onArrowUp: onArrowUp,
                  onArrowDown: widget.onArrowDownToNextSection,
                );
              } else {
                final videoInfo = visibleVideos[index];
                final cardFocusNode =
                    index == 0 && widget.pendingFocusVideoId == null
                        ? widget.firstItemFocusNode
                        : _focusNodeForVideoId(videoInfo.id);
                item = TvVideoCard(
                  videoInfo: videoInfo,
                  focusMemoryGroupKey: _focusMemoryGroupKey,
                  autofocus: widget.autofocusFirstItem && index == 0,
                  focusNode: cardFocusNode,
                  onPressed: () => widget.onVideoPressed?.call(videoInfo),
                  onLongPressed: widget.onVideoLongPressed == null
                      ? null
                      : () => widget.onVideoLongPressed?.call(videoInfo),
                  onFocusChanged: (hasFocus) => _handleItemFocusChange(
                    hasFocus,
                    index,
                    usesSmoothFrame: usesSmoothFrame,
                  ),
                  // 首页横向列表的滚动节奏完全由区块统一控制，
                  // 避免卡片自身的自动滚动提前触发，导致 scrollStartIndex 失效。
                  autoScrollOnFocus: false,
                  focusScrollAlignment: 0.42,
                  showFocusFrame: !usesSmoothFrame,
                  enableFocusEffects: !usesSmoothFrame,
                  onArrowLeft: isFirstItem
                      ? () => _handleEdge(index, AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () => _handleEdge(index, AxisDirection.right)
                      : null,
                  onArrowUp: onArrowUp,
                  onArrowDown: widget.onArrowDownToNextSection,
                );
              }
              return TvEdgeShake(
                key: edgeShakeKey,
                child: item,
              );
            },
            separatorBuilder: (_, __) =>
                const SizedBox(width: TvHomeSection.cardSpacing),
            itemCount: itemCount,
          ),
        ),
        if (usesSmoothFrame)
          _TvHomeSectionFocusFrame(
            itemIndex: _focusedItemIndex,
            scrollOffset: _currentScrollPosition?.pixels ?? 0,
          ),
      ],
    );
  }
}

/// TV 首页横向列表共享焦点框。
class _TvHomeSectionFocusFrame extends StatelessWidget {
  /// 创建 TV 首页横向列表共享焦点框。
  const _TvHomeSectionFocusFrame({
    required this.itemIndex,
    required this.scrollOffset,
  });

  /// 当前获焦卡片下标。
  final int? itemIndex;

  /// 当前分区横向列表滚动偏移。
  final double scrollOffset;

  /// 焦点框顶部位置，与卡片封面顶部对齐。
  static const double top = 12.0;

  /// 焦点框尺寸相对封面的外扩距离。
  static const double outset = 5.0;

  /// 焦点框横向移动时长。
  static const Duration duration = Duration(milliseconds: 180);

  /// 首页横向卡片获焦时的中性白色光晕。
  static const Color neutralShadowColor = Color(0x3DFFFFFF);

  @override
  Widget build(BuildContext context) {
    final itemLeft = itemIndex == null
        ? 0.0
        : TvLayout.pageHorizontalPadding +
            itemIndex! * (TvVideoCard.width + TvHomeSection.cardSpacing) -
            scrollOffset -
            outset;

    return AnimatedPositioned(
      key: const ValueKey('tv-home-section-focus-frame'),
      left: itemLeft,
      top: top - outset,
      width: TvVideoCard.width + outset * 2,
      height: TvVideoCard.coverHeight + outset * 2,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: itemIndex == null ? 0 : 1,
          duration: const Duration(milliseconds: 90),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFE2E6EA), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: neutralShadowColor,
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// TV 首页查看更多卡片。
class _TvMoreCard extends StatelessWidget {
  /// 创建 TV 首页查看更多卡片。
  const _TvMoreCard({
    required this.onPressed,
    this.focusMemoryGroupKey,
    this.autofocus = false,
    this.focusNode,
    this.onFocusChanged,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
  });

  /// 点击回调。
  final VoidCallback onPressed;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 是否默认获取焦点。
  final bool autofocus;

  /// 外部焦点节点。
  final FocusNode? focusNode;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    final usesSmoothFrame =
        TvTheme.focusEffectModeOf(context) == TvFocusEffectMode.smoothFrame;
    return SizedBox(
      width: TvVideoCard.width,
      height: TvVideoCard.height,
      child: Align(
        alignment: Alignment.topCenter,
        child: TvFocusable(
          focusMemoryGroupKey: focusMemoryGroupKey,
          autofocus: autofocus,
          focusNode: focusNode,
          onPressed: onPressed,
          onFocusChanged: onFocusChanged,
          focusScrollAlignment: 0.42,
          onArrowUp: onArrowUp,
          onArrowDown: onArrowDown,
          onArrowLeft: onArrowLeft,
          onArrowRight: onArrowRight,
          builder: (context, hasFocus) {
            return AnimatedScale(
              scale:
                  hasFocus && !usesSmoothFrame ? TvVideoCard.focusedScale : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: Container(
                key: const ValueKey('tv-home-more-card'),
                width: TvVideoCard.width,
                height: TvVideoCard.coverHeight,
                decoration: BoxDecoration(
                  color: TvThemeColors.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFocus && !usesSmoothFrame
                        ? const Color(0xFFE2E6EA)
                        : TvThemeColors.cardSurfaceBorder,
                    width: hasFocus && !usesSmoothFrame ? 3 : 1,
                  ),
                  boxShadow: hasFocus && !usesSmoothFrame
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFFE2E6EA).withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 52,
                      color: hasFocus ? palette.focus : const Color(0xFFD9E2E0),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '查看更多',
                      style: FontUtils.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
