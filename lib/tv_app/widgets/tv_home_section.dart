import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
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

  /// 首个卡片按上方向键时的回调。
  final VoidCallback? onArrowUpFromFirstItem;

  /// 任意卡片按下方向键时进入下一分区的回调。
  final VoidCallback? onArrowDownToNextSection;

  @override
  State<_TvHomeSectionBody> createState() => _TvHomeSectionBodyState();
}

class _TvHomeSectionBodyState extends State<_TvHomeSectionBody> {
  /// 当前区块根节点，用于卡片获焦时驱动首页纵向滚动。
  final GlobalKey _sectionKey = GlobalKey();

  /// 横向列表卡片边界抖动控制键。
  final Map<int, GlobalKey<TvEdgeShakeState>> _edgeShakeKeys = {};

  /// 区块内部横向列表控制器。
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();

  /// 区块内卡片稳定焦点节点。
  final Map<String, FocusNode> _videoFocusNodes = {};

  /// 当前区块的焦点记忆分组。
  Object get _focusMemoryGroupKey => 'tv-home-section-${widget.title}';

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
    for (final node in _videoFocusNodes.values) {
      node.dispose();
    }
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// 卡片获得焦点时，把当前区块平滑滚动到大屏适合浏览的位置。
  void _handleItemFocusChange(bool hasFocus, int index) {
    if (!hasFocus) {
      return;
    }

    _revealFocusedItem(index);

    final sectionContext = _sectionKey.currentContext;
    if (sectionContext == null) {
      return;
    }

    TvFocusScroll.ensureVisible(
      sectionContext,
      alignment: TvFocusScroll.sectionAlignment,
    );
  }

  /// 当焦点抵达约定卡位后，按卡片步长推动横向列表。
  void _revealFocusedItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
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
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
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
    return Padding(
      key: _sectionKey,
      padding: const EdgeInsets.only(bottom: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TvLayout.pageHorizontalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.title,
                  style: FontUtils.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (widget.titleHint?.isNotEmpty == true) ...[
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      widget.titleHint!,
                      style: FontUtils.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7F858F),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: TvVideoCard.height + 42,
            child: widget.isLoading ? _buildLoadingList() : _buildVideoList(),
          ),
        ],
      ),
    );
  }

  /// 构建加载骨架列表。
  Widget _buildLoadingList() {
    return ListView.separated(
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
              color: const Color(0xFF1D2225),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2F32)),
            ),
          ),
        ),
      ),
      separatorBuilder: (_, __) =>
          const SizedBox(width: TvHomeSection.cardSpacing),
      itemCount: 6,
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
            color: const Color(0xFF171A1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2F32)),
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

    return ListView.separated(
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
        Widget item;
        if (showMore && index == visibleVideos.length) {
          item = _TvMoreCard(
            focusMemoryGroupKey: _focusMemoryGroupKey,
            autofocus: widget.autofocusFirstItem && index == 0,
            focusNode: index == 0 ? widget.firstItemFocusNode : null,
            onPressed: widget.onMorePressed!,
            onFocusChanged: (hasFocus) =>
                _handleItemFocusChange(hasFocus, index),
            onArrowLeft: isFirstItem
                ? () => _handleEdge(index, AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => _handleEdge(index, AxisDirection.right)
                : null,
            onArrowUp: isFirstItem ? widget.onArrowUpFromFirstItem : null,
            onArrowDown: widget.onArrowDownToNextSection,
          );
        } else {
          final videoInfo = visibleVideos[index];
          final cardFocusNode = index == 0 && widget.pendingFocusVideoId == null
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
            onFocusChanged: (hasFocus) =>
                _handleItemFocusChange(hasFocus, index),
            // 首页横向列表的滚动节奏完全由区块统一控制，
            // 避免卡片自身的自动滚动提前触发，导致 scrollStartIndex 失效。
            autoScrollOnFocus: false,
            focusScrollAlignment: 0.42,
            onArrowLeft: isFirstItem
                ? () => _handleEdge(index, AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => _handleEdge(index, AxisDirection.right)
                : null,
            onArrowUp: isFirstItem ? widget.onArrowUpFromFirstItem : null,
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
              scale: hasFocus ? TvVideoCard.focusedScale : 1,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: Container(
                key: const ValueKey('tv-home-more-card'),
                width: TvVideoCard.width,
                height: TvVideoCard.coverHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF15191B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasFocus ? palette.focus : const Color(0xFF2A2F32),
                    width: hasFocus ? 3 : 1,
                  ),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: palette.focus.withValues(alpha: 0.22),
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
