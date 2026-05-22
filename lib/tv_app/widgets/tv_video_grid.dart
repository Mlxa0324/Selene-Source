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
class TvVideoGrid extends StatelessWidget {
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
    this.isLoading = false,
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

  /// 是否处于加载状态。
  final bool isLoading;

  /// Grid 横向间距。
  static const double crossAxisSpacing = 26.0;

  /// Grid 纵向间距。
  static const double mainAxisSpacing = 34.0;

  /// 焦点放大安全边距，避免首尾列卡片被滚动视口裁剪。
  static const double focusSafePadding = 12.0;

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
              if (isLoading)
                _buildLoadingGrid(crossAxisCount)
              else if (videos.isEmpty)
                _buildEmptyState()
              else
                _buildVideoGrid(crossAxisCount),
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
          focusSafePadding,
          0,
          focusSafePadding,
          24,
        ),
        child: Text(
          title,
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
        focusSafePadding,
        8,
        focusSafePadding,
        64,
      ),
      sliver: SliverGrid(
        key: const ValueKey('tv-video-loading-grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
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
      padding: const EdgeInsets.symmetric(horizontal: focusSafePadding),
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
        focusSafePadding,
        8,
        focusSafePadding,
        64,
      ),
      sliver: SliverGrid(
        key: const ValueKey('tv-video-grid'),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          mainAxisExtent: TvVideoCard.height,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final videoInfo = videos[index];
            return _TvGridEdgeItem(
              crossAxisCount: crossAxisCount,
              index: index,
              itemCount: videos.length,
              videoInfo: videoInfo,
              onPressed: () => onVideoPressed?.call(videoInfo),
              onFocusChanged: onVideoFocusChanged,
              onArrowUp: onArrowUp,
            );
          },
          childCount: videos.length,
        ),
      ),
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
    this.onPressed,
    this.onFocusChanged,
    this.onArrowUp,
  });

  /// 视频展示数据。
  final VideoInfo videoInfo;

  /// 当前卡片下标。
  final int index;

  /// 卡片总数。
  final int itemCount;

  /// 当前网格列数。
  final int crossAxisCount;

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

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
