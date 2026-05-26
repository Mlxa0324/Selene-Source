import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/widgets/tv_home_section.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 视频纵向网格。
///
/// 用于播放历史和收藏夹等需要上下滚动浏览的完整列表。
class TvVideoGrid extends StatefulWidget {
  /// 创建 TV 视频纵向网格。
  ///
  /// [title] 为页面标题。
  /// [videos] 为需要展示的视频列表。
  /// [onVideoPressed] 为卡片点击回调。
  const TvVideoGrid({
    super.key,
    required this.title,
    required this.videos,
    this.onVideoPressed,
    this.onVideoFocusChanged,
    this.onArrowUp,
    this.focusMemoryGroupKey,
    this.firstItemFocusNode,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
  });

  /// 页面标题。
  final String title;

  /// 视频列表。
  final List<VideoInfo> videos;

  /// 卡片点击回调。
  final TvVideoPressed? onVideoPressed;

  /// 卡片焦点变化回调。
  ///
  /// 分类页用它感知内容区获焦，切换顶部筛选栏为摘要态。
  final ValueChanged<bool>? onVideoFocusChanged;

  /// 卡片上方向键回调。
  ///
  /// 分类页用于呼出筛选面板；为空时保持默认焦点导航。
  final VoidCallback? onArrowUp;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 第一张卡片的外部焦点节点。
  ///
  /// 分类页从顶部菜单按下时用它稳定回到首张卡片。
  final FocusNode? firstItemFocusNode;

  /// 是否处于加载状态。
  final bool isLoading;

  /// 是否正在加载下一页。
  final bool isLoadingMore;

  /// 是否还有下一页数据。
  final bool hasMore;

  /// 触发加载下一页的回调。
  final VoidCallback? onLoadMore;

  /// Grid 横向间距。
  static const double crossAxisSpacing = 26.0;

  /// Grid 纵向间距。
  static const double mainAxisSpacing = 34.0;

  /// 焦点放大安全边距，避免首尾列卡片被滚动视口裁剪。
  static const double focusSafePadding = 12.0;

  @override
  State<TvVideoGrid> createState() => _TvVideoGridState();
}

class _TvVideoGridState extends State<TvVideoGrid> {
  /// 最近一次触发加载更多时的列表长度。
  ///
  /// 同一批数据里多个倒数第二行卡片连续获焦时，只触发一次分页。
  int? _lastLoadMoreTriggerLength;

  @override
  void didUpdateWidget(covariant TvVideoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videos.length != widget.videos.length ||
        oldWidget.isLoadingMore && !widget.isLoadingMore && widget.hasMore) {
      _lastLoadMoreTriggerLength = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvLayout.pageHorizontalPadding,
        0,
        TvLayout.pageHorizontalPadding,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossAxisCount = TvLayout.gridCrossAxisCount;
          return CustomScrollView(
            key: const ValueKey('tv-video-grid-scroll'),
            clipBehavior: Clip.none,
            slivers: [
              _buildTitleSliver(),
              if (widget.isLoading)
                _buildLoadingGrid(crossAxisCount)
              else if (widget.videos.isEmpty)
                _buildEmptyState()
              else ...[
                _buildVideoGrid(crossAxisCount),
                if (widget.isLoadingMore) _buildLoadMoreIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 构建跟随列表滚动的页面标题。
  Widget _buildTitleSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TvVideoGrid.focusSafePadding,
          0,
          TvVideoGrid.focusSafePadding,
          24,
        ),
        child: Text(
          widget.title,
          style: FontUtils.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 构建加载骨架网格。
  Widget _buildLoadingGrid(int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        TvVideoGrid.focusSafePadding,
        8,
        TvVideoGrid.focusSafePadding,
        64,
      ),
      sliver: SliverGrid(
        key: const ValueKey('tv-video-loading-grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: TvVideoGrid.crossAxisSpacing,
          mainAxisSpacing: TvVideoGrid.mainAxisSpacing,
          mainAxisExtent: TvVideoCard.height,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Align(
            alignment: Alignment.topLeft,
            child: Container(
              key: const ValueKey('tv-video-grid-loading-card'),
              width: TvVideoCard.width,
              height: TvVideoCard.coverHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1D2225),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2F32)),
              ),
            ),
          ),
          childCount: crossAxisCount * 2,
        ),
      ),
    );
  }

  /// 构建空状态。
  Widget _buildEmptyState() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: TvVideoGrid.focusSafePadding,
      ),
      sliver: SliverToBoxAdapter(
        child: Container(
          key: const ValueKey('tv-video-grid-empty'),
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
      ),
    );
  }

  /// 构建视频网格。
  Widget _buildVideoGrid(int crossAxisCount) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        TvVideoGrid.focusSafePadding,
        8,
        TvVideoGrid.focusSafePadding,
        64,
      ),
      sliver: SliverGrid(
        key: const ValueKey('tv-video-grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: TvVideoGrid.crossAxisSpacing,
          mainAxisSpacing: TvVideoGrid.mainAxisSpacing,
          mainAxisExtent: TvVideoCard.height,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final videoInfo = widget.videos[index];
            return _TvGridEdgeItem(
              crossAxisCount: crossAxisCount,
              index: index,
              itemCount: widget.videos.length,
              videoInfo: videoInfo,
              focusNode: index == 0 ? widget.firstItemFocusNode : null,
              onPressed: () => widget.onVideoPressed?.call(videoInfo),
              onFocusChanged: (hasFocus) {
                if (hasFocus) {
                  _tryTriggerLoadMore(index, crossAxisCount);
                }
                widget.onVideoFocusChanged?.call(hasFocus);
              },
              onArrowUp: widget.onArrowUp,
              focusMemoryGroupKey:
                  widget.focusMemoryGroupKey ?? 'tv-grid-${widget.title}',
            );
          },
          childCount: widget.videos.length,
        ),
      ),
    );
  }

  /// 构建底部分页加载提示。
  Widget _buildLoadMoreIndicator() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TvVideoGrid.focusSafePadding,
          0,
          TvVideoGrid.focusSafePadding,
          46,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '加载更多',
              style: FontUtils.poppins(
                fontSize: 14,
                color: const Color(0xFF98A2A8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 焦点进入倒数第二行时触发分页加载。
  void _tryTriggerLoadMore(int index, int crossAxisCount) {
    if (!widget.hasMore ||
        widget.isLoading ||
        widget.isLoadingMore ||
        widget.onLoadMore == null ||
        widget.videos.isEmpty) {
      return;
    }

    final lastRowIndex = (widget.videos.length - 1) ~/ crossAxisCount;
    if (lastRowIndex < 2) {
      return;
    }

    final rowIndex = index ~/ crossAxisCount;
    final triggerRowIndex = lastRowIndex - 1;
    if (rowIndex < triggerRowIndex ||
        _lastLoadMoreTriggerLength == widget.videos.length) {
      return;
    }

    // 当前批次只触发一次，等下一页追加后再允许继续触发。
    _lastLoadMoreTriggerLength = widget.videos.length;
    widget.onLoadMore?.call();
  }
}

/// TV 网格卡片边界反馈项。
class _TvGridEdgeItem extends StatefulWidget {
  /// 创建 TV 网格卡片边界反馈项。
  const _TvGridEdgeItem({
    required this.videoInfo,
    required this.index,
    required this.itemCount,
    required this.crossAxisCount,
    this.focusNode,
    this.onPressed,
    this.onFocusChanged,
    this.onArrowUp,
    this.focusMemoryGroupKey,
  });

  /// 视频展示数据。
  final VideoInfo videoInfo;

  /// 当前卡片下标。
  final int index;

  /// 卡片总数。
  final int itemCount;

  /// 当前网格列数。
  final int crossAxisCount;

  /// 外部焦点节点。
  final FocusNode? focusNode;

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  @override
  State<_TvGridEdgeItem> createState() => _TvGridEdgeItemState();
}

class _TvGridEdgeItemState extends State<_TvGridEdgeItem> {
  /// 当前网格卡片边界抖动控制键。
  final GlobalKey<TvEdgeShakeState> _edgeShakeKey =
      GlobalKey<TvEdgeShakeState>();

  /// 当前卡片是否处于左边界。
  bool get _isLeftEdge => widget.index % widget.crossAxisCount == 0;

  /// 当前卡片是否处于右边界。
  bool get _isRightEdge =>
      widget.index % widget.crossAxisCount == widget.crossAxisCount - 1 ||
      widget.index == widget.itemCount - 1;

  /// 当前卡片是否处于下边界。
  bool get _isBottomEdge =>
      widget.index + widget.crossAxisCount >= widget.itemCount;

  /// 当前卡片是否处于上边界。
  bool get _isTopEdge => widget.index < widget.crossAxisCount;

  /// 播放指定方向的边界抖动。
  void _shake(AxisDirection direction) {
    _edgeShakeKey.currentState?.shake(direction);
  }

  @override
  Widget build(BuildContext context) {
    return TvEdgeShake(
      key: _edgeShakeKey,
      child: TvVideoCard(
        videoInfo: widget.videoInfo,
        focusNode: widget.focusNode,
        focusMemoryGroupKey: widget.focusMemoryGroupKey,
        onPressed: widget.onPressed,
        onFocusChanged: widget.onFocusChanged,
        onArrowLeft: _isLeftEdge ? () => _shake(AxisDirection.left) : null,
        onArrowRight: _isRightEdge ? () => _shake(AxisDirection.right) : null,
        onArrowUp: _isTopEdge ? widget.onArrowUp : null,
        onArrowDown: _isBottomEdge ? () => _shake(AxisDirection.down) : null,
      ),
    );
  }
}
