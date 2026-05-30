import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/widgets/tv_home_section.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_section_title.dart';
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
    this.showTitle = true,
    this.titleHint,
    this.onClearPressed,
    this.onVideoPressed,
    this.onVideoLongPressed,
    this.onVideoFocusChanged,
    this.onVideoItemFocused,
    this.onArrowUp,
    this.onLeadingEdgeArrowLeft,
    this.onTopEdgeArrowUp,
    this.topEdgeArrowLockCount = 0,
    this.focusMemoryGroupKey,
    this.firstItemFocusNode,
    this.rightPadding = TvLayout.pageHorizontalPadding,
    this.crossAxisCount = TvLayout.gridCrossAxisCount,
    this.crossAxisSpacing = TvVideoGrid.defaultCrossAxisSpacing,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.onLoadMore,
    this.initialRenderCount = TvVideoGrid.defaultInitialRenderCount,
    this.renderBatchSize = TvVideoGrid.defaultRenderBatchSize,
  });

  /// 页面标题。
  final String title;

  /// 是否展示随列表滚动的标题区域。
  ///
  /// 搜索页会把标题固定在 Grid 外层，因此这里允许关闭内置标题。
  final bool showTitle;

  /// 页面标题右侧提示文案。
  ///
  /// 分类页用它提示用户可按确认键呼出筛选面板。
  final String? titleHint;

  /// 页面标题右侧清空按钮回调。
  final VoidCallback? onClearPressed;

  /// 视频列表。
  final List<VideoInfo> videos;

  /// 卡片点击回调。
  final TvVideoPressed? onVideoPressed;

  /// 卡片长按回调。
  final TvVideoPressed? onVideoLongPressed;

  /// 卡片焦点变化回调。
  ///
  /// 分类页用它感知内容区获焦，切换顶部筛选栏为摘要态。
  final ValueChanged<bool>? onVideoFocusChanged;

  /// 当前获焦卡片节点回调。
  ///
  /// 独立视频库页用它记住列表里最后停留的卡片，便于从顶部固定头返回原位置。
  final ValueChanged<FocusNode>? onVideoItemFocused;

  /// 卡片上方向键回调。
  ///
  /// 分类页用于呼出筛选面板；为空时保持默认焦点导航。
  final VoidCallback? onArrowUp;

  /// 最左列卡片左方向键回调。
  ///
  /// 搜索页可借此把结果区最左列焦点退回左侧输入区。
  final VoidCallback? onLeadingEdgeArrowLeft;

  /// 顶部边缘卡片上方向键回调。
  ///
  /// 搜索页可借此吞掉顶部若干卡片的上方向键，避免焦点误回到标题区。
  final VoidCallback? onTopEdgeArrowUp;

  /// 顶部禁上卡片数量。
  ///
  /// 大于 0 时，仅前 N 个卡片会拦截上方向键；其余顶部卡片仍走默认规则。
  final int topEdgeArrowLockCount;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 第一张卡片的外部焦点节点。
  ///
  /// 分类页从顶部菜单按下时用它稳定回到首张卡片。
  final FocusNode? firstItemFocusNode;

  /// 列表右侧留白。
  ///
  /// 分类页可传 `0`，让末列卡片直接贴到内容区域右边界。
  final double rightPadding;

  /// 当前页面使用的纵向 Grid 列数。
  ///
  /// 默认沿用 TV 全局列数，搜索页等特殊场景可按页面单独收窄。
  final int crossAxisCount;

  /// 当前页面使用的纵向 Grid 横向间距。
  ///
  /// 默认沿用全局卡片间距；搜索页结果区可单独收窄，避免大屏上卡片看起来被拉得过瘦。
  final double crossAxisSpacing;

  /// 是否处于加载状态。
  final bool isLoading;

  /// 是否正在加载下一页。
  final bool isLoadingMore;

  /// 是否还有下一页数据。
  final bool hasMore;

  /// 触发加载下一页的回调。
  final VoidCallback? onLoadMore;

  /// 首批渲染数量。
  ///
  /// 大列表首次进入时，只先挂载这一批卡片，
  /// 降低搜索结果页和独立视频库页首屏一次性建树压力。
  final int initialRenderCount;

  /// 每次追加渲染数量。
  ///
  /// 当焦点逼近当前批次尾部时，继续按这一批次扩充可导航卡片。
  final int renderBatchSize;

  /// Grid 横向间距。
  static const double defaultCrossAxisSpacing = 26.0;

  /// 默认首批渲染数量。
  static const int defaultInitialRenderCount = 80;

  /// 默认单次追加渲染数量。
  static const int defaultRenderBatchSize = 40;

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

  /// 当前已经开放给 Grid 的卡片数量。
  ///
  /// 这里只控制“能参与构建和焦点导航的条目数”，
  /// 让大列表先展示首批卡片，后续再随着焦点推进逐步放开。
  int _visibleItemCount = 0;

  @override
  void initState() {
    super.initState();
    _visibleItemCount = _computeInitialVisibleItemCount(widget.videos.length);
  }

  @override
  void didUpdateWidget(covariant TvVideoGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videos.length != widget.videos.length ||
        oldWidget.initialRenderCount != widget.initialRenderCount ||
        oldWidget.renderBatchSize != widget.renderBatchSize ||
        oldWidget.hasMore != widget.hasMore) {
      _syncVisibleItemCount(oldWidget);
    }
    if (oldWidget.videos.length != widget.videos.length ||
        oldWidget.isLoadingMore && !widget.isLoadingMore && widget.hasMore) {
      _lastLoadMoreTriggerLength = null;
    }
  }

  /// 当前实际参与构建的卡片数量。
  ///
  /// 结果必须落在 `0 ~ videos.length` 范围内，避免委托 childCount 越界。
  int get _renderedItemCount {
    if (widget.videos.isEmpty) {
      return 0;
    }
    return _visibleItemCount.clamp(0, widget.videos.length);
  }

  /// 计算首批应该开放的卡片数量。
  ///
  /// 当列表本身比首批阈值更短时，直接全部渲染，避免小列表反而被人为截断。
  int _computeInitialVisibleItemCount(int totalItemCount) {
    if (totalItemCount <= 0) {
      return 0;
    }
    return totalItemCount < widget.initialRenderCount
        ? totalItemCount
        : widget.initialRenderCount;
  }

  /// 在数据长度变化后同步当前可见批次。
  ///
  /// 1. 小列表始终全部开放。
  /// 2. 大列表默认回落到首批数量。
  /// 3. 真分页场景在“原列表已全部开放”的前提下，自动把新页数据一并放开。
  void _syncVisibleItemCount(TvVideoGrid oldWidget) {
    final totalItemCount = widget.videos.length;
    if (totalItemCount <= 0) {
      _visibleItemCount = 0;
      return;
    }

    final initialVisibleItemCount =
        _computeInitialVisibleItemCount(totalItemCount);
    if (totalItemCount <= widget.initialRenderCount) {
      _visibleItemCount = totalItemCount;
      return;
    }

    final appendedByPaging = totalItemCount > oldWidget.videos.length &&
        _visibleItemCount >= oldWidget.videos.length;
    if (appendedByPaging) {
      _visibleItemCount = totalItemCount;
      return;
    }

    _visibleItemCount = _visibleItemCount.clamp(
      initialVisibleItemCount,
      totalItemCount,
    );
  }

  /// 焦点逼近当前批次尾部时，提前开放下一批卡片。
  ///
  /// 让用户在长按方向键浏览大列表时，不需要等真的撞到“假尾部”才继续出项。
  void _maybeExtendVisibleItems(int focusedIndex, int crossAxisCount) {
    if (_renderedItemCount >= widget.videos.length) {
      return;
    }

    final triggerIndex = _renderedItemCount - crossAxisCount;
    if (focusedIndex < triggerIndex) {
      return;
    }

    setState(() {
      _visibleItemCount = (_renderedItemCount + widget.renderBatchSize)
          .clamp(0, widget.videos.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        TvLayout.pageHorizontalPadding,
        0,
        widget.rightPadding,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = widget.crossAxisCount;
          return CustomScrollView(
            key: const ValueKey('tv-video-grid-scroll'),
            clipBehavior: Clip.none,
            slivers: [
              if (widget.showTitle) _buildTitleSliver(),
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
        child: Row(
          children: [
            Expanded(
              child: TvSectionTitle(
                title: widget.title,
                titleHint: widget.titleHint,
                titleHintKey: const ValueKey('tv-video-grid-title-hint'),
                flexibleHint: true,
                hintOverflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onClearPressed != null) ...[
              const SizedBox(width: 16),
              TvVideoGridActionButton(
                key: const ValueKey('tv-video-library-clear-button'),
                label: '删除全部',
                onPressed: widget.onClearPressed,
              ),
            ],
          ],
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
          crossAxisSpacing: widget.crossAxisSpacing,
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
      padding: EdgeInsets.only(
        left: TvVideoGrid.focusSafePadding,
        right: widget.rightPadding == 0 ? 0 : TvVideoGrid.focusSafePadding,
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
    final renderedItemCount = _renderedItemCount;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        TvVideoGrid.focusSafePadding,
        8,
        widget.rightPadding == 0 ? 0 : TvVideoGrid.focusSafePadding,
        64,
      ),
      sliver: SliverGrid(
        key: const ValueKey('tv-video-grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: widget.crossAxisSpacing,
          mainAxisSpacing: TvVideoGrid.mainAxisSpacing,
          mainAxisExtent: TvVideoCard.height,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final videoInfo = widget.videos[index];
            return _TvGridEdgeItem(
              crossAxisCount: crossAxisCount,
              index: index,
              itemCount: renderedItemCount,
              videoInfo: videoInfo,
              scaleAlignment: _scaleAlignmentForGridItem(
                index: index,
                crossAxisCount: crossAxisCount,
                itemCount: renderedItemCount,
              ),
              focusNode: index == 0 ? widget.firstItemFocusNode : null,
              onPressed: () => widget.onVideoPressed?.call(videoInfo),
              onLongPressed: () => widget.onVideoLongPressed?.call(videoInfo),
              onFocusChanged: (hasFocus) {
                if (hasFocus) {
                  _maybeExtendVisibleItems(index, crossAxisCount);
                  _tryTriggerLoadMore(index, crossAxisCount);
                }
                widget.onVideoFocusChanged?.call(hasFocus);
              },
              onFocusedNodeChanged: widget.onVideoItemFocused,
              onArrowUp: widget.onArrowUp,
              onLeadingEdgeArrowLeft: widget.onLeadingEdgeArrowLeft,
              onTopEdgeArrowUp: widget.onTopEdgeArrowUp,
              topEdgeArrowLockCount: widget.topEdgeArrowLockCount,
              focusMemoryGroupKey:
                  widget.focusMemoryGroupKey ?? 'tv-grid-${widget.title}',
            );
          },
          childCount: renderedItemCount,
        ),
      ),
    );
  }

  /// 根据列位置计算卡片放大方向。
  ///
  /// 右侧贴边的末列卡片向左内收放大，避免贴边后焦点描边超出裁剪区。
  Alignment _scaleAlignmentForGridItem({
    required int index,
    required int crossAxisCount,
    required int itemCount,
  }) {
    final isRightEdge =
        index % crossAxisCount == crossAxisCount - 1 || index == itemCount - 1;
    if (widget.rightPadding == 0 && isRightEdge) {
      return Alignment.centerRight;
    }
    return Alignment.center;
  }

  /// 构建底部分页加载提示。
  Widget _buildLoadMoreIndicator() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          TvVideoGrid.focusSafePadding,
          0,
          widget.rightPadding == 0 ? 0 : TvVideoGrid.focusSafePadding,
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

/// TV 视频库标题操作按钮。
class TvVideoGridActionButton extends StatelessWidget {
  /// 创建视频库标题操作按钮。
  const TvVideoGridActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onArrowDown,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 下方向键回调。
  ///
  /// 供独立视频库页把焦点从固定头部恢复到用户刚离开的内容卡片。
  final VoidCallback? onArrowDown;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      onPressed: onPressed,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: hasFocus ? palette.accent : const Color(0xFF1A1E21),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFocus ? Colors.white : const Color(0xFF2A2F32),
              width: 2,
            ),
          ),
          child: Text(
            label,
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
    this.onLongPressed,
    this.onFocusChanged,
    this.onFocusedNodeChanged,
    this.onArrowUp,
    this.onLeadingEdgeArrowLeft,
    this.onTopEdgeArrowUp,
    this.topEdgeArrowLockCount = 0,
    this.scaleAlignment = Alignment.center,
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

  /// 长按回调。
  final VoidCallback? onLongPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 当前卡片真正获焦时的焦点节点回调。
  final ValueChanged<FocusNode>? onFocusedNodeChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 最左列左方向键回调。
  final VoidCallback? onLeadingEdgeArrowLeft;

  /// 顶部边缘上方向键回调。
  final VoidCallback? onTopEdgeArrowUp;

  /// 顶部禁上卡片数量。
  final int topEdgeArrowLockCount;

  /// 卡片放大对齐方向。
  final Alignment scaleAlignment;

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

  /// 当前卡片是否位于最后一行。
  ///
  /// 只有真正处于最后一行时，按下方向键才应该触发边界反馈。
  /// 如果只是“当前列正下方没有卡片”，但下方仍然存在其它卡片，
  /// 则需要把焦点导航交回给默认系统，落到下一行最近的卡片上。
  bool get _isLastRowItem =>
      widget.index ~/ widget.crossAxisCount ==
      (widget.itemCount - 1) ~/ widget.crossAxisCount;

  /// 当前卡片是否处于上边界。
  bool get _isTopEdge => widget.index < widget.crossAxisCount;

  /// 当前卡片是否命中顶部禁上范围。
  bool get _isTopArrowLocked =>
      widget.topEdgeArrowLockCount > 0 &&
      widget.index < widget.topEdgeArrowLockCount;

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
        scaleAlignment: widget.scaleAlignment,
        onPressed: widget.onPressed,
        onLongPressed: widget.onLongPressed,
        onFocusChanged: widget.onFocusChanged,
        onFocusedNodeChanged: widget.onFocusedNodeChanged,
        onArrowLeft: _isLeftEdge
            ? (widget.onLeadingEdgeArrowLeft ??
                () => _shake(AxisDirection.left))
            : null,
        onArrowRight: _isRightEdge ? () => _shake(AxisDirection.right) : null,
        onArrowUp: _isTopArrowLocked
            ? (widget.onTopEdgeArrowUp ?? widget.onArrowUp)
            : _isTopEdge
                ? widget.onArrowUp
                : null,
        onArrowDown: _isLastRowItem ? () => _shake(AxisDirection.down) : null,
      ),
    );
  }
}
