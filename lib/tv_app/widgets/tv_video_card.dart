import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/app_cache_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';
import 'package:selene/utils/image_url.dart';

/// TV 视频卡片组件。
///
/// 用于 TV 首页横向内容区，突出封面、标题和遥控器焦点态。
class TvVideoCard extends StatelessWidget {
  /// 创建 TV 视频卡片。
  ///
  /// [videoInfo] 提供视频展示数据。
  /// [onPressed] 处理选中播放。
  const TvVideoCard({
    super.key,
    required this.videoInfo,
    this.onPressed,
    this.onFocusChanged,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.focusNode,
    this.autofocus = false,
    this.autoScrollOnFocus = true,
    this.focusScrollAlignment = TvFocusScroll.defaultAlignment,
    this.focusMemoryGroupKey,
  });

  /// 视频展示数据。
  final VideoInfo videoInfo;

  /// 卡片点击回调。
  final VoidCallback? onPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 外部焦点节点。
  ///
  /// 测试和特殊焦点编排场景可传入，默认由 Focus 自行管理。
  final FocusNode? focusNode;

  /// 是否默认获取焦点。
  final bool autofocus;

  /// 获焦后是否自动滚动到可见区域。
  final bool autoScrollOnFocus;

  /// 获焦自动滚动时的目标对齐位置。
  final double focusScrollAlignment;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 当前视频数据 ID，用于 TV 测试和焦点定位。
  String get focusKey => 'tv-video-card-focus-${videoInfo.id}';

  /// TV 卡片固定宽度。
  static const double width = 158.0;

  /// TV 卡片固定高度。
  static const double height = 296.0;

  /// TV 卡片封面固定高度。
  static const double coverHeight = 237.0;

  /// TV 卡片获取焦点后的整体放大比例。
  static const double focusedScale = 1.08;

  /// TV 雨刷光带起点，横向为主并轻微向下倾斜。
  static const Alignment shimmerBegin = Alignment(-1.2, -0.34);

  /// TV 雨刷光带终点，横向为主并轻微向下倾斜。
  static const Alignment shimmerEnd = Alignment(1.2, 0.34);

  /// TV 雨刷纵向位移系数，避免光带角度过于对角。
  static const double shimmerVerticalTravelFactor = 0.34;

  /// TV 雨刷动画时长，焦点雨刷与骨架雨刷保持同速。
  static const Duration shimmerDuration = Duration(milliseconds: 1800);

  /// TV 焦点雨刷触发延迟，避免快速路过卡片时频繁闪动。
  static const Duration focusSweepDelay = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      key: ValueKey(focusKey),
      focusNode: focusNode,
      autofocus: autofocus,
      autoScrollOnFocus: autoScrollOnFocus,
      focusScrollAlignment: focusScrollAlignment,
      focusMemoryGroupKey: focusMemoryGroupKey,
      onPressed: onPressed,
      onFocusChanged: onFocusChanged,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedScale(
          scale: hasFocus ? focusedScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(context, hasFocus),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 0),
                  child: Text(
                    videoInfo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontUtils.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontUtils.poppins(
                      fontSize: 12,
                      color: const Color(0xFF98A2A8),
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

  /// 卡片副标题文案。
  String get _subtitle {
    if (videoInfo.playTime > 0 || videoInfo.index > 1) {
      // 继续观看卡片下方只展示线路，集数和进度保留在封面徽标与进度条中表达。
      if (videoInfo.sourceName.isNotEmpty) {
        return videoInfo.sourceName;
      }
    }

    final parts = <String>[];
    if (videoInfo.year.isNotEmpty) {
      parts.add(videoInfo.year);
    }
    if (videoInfo.rate?.isNotEmpty == true) {
      parts.add('${videoInfo.rate} 分');
    } else if (videoInfo.sourceName.isNotEmpty) {
      parts.add(videoInfo.sourceName);
    }
    return parts.isEmpty ? 'Selene' : parts.join(' · ');
  }

  /// 构建封面区域。
  Widget _buildCover(BuildContext context, bool hasFocus) {
    final palette = TvTheme.of(context);
    return AnimatedContainer(
      width: width,
      height: coverHeight,
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1C),
        borderRadius: BorderRadius.circular(8),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: palette.focus.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasFocus ? palette.focus : const Color(0xFF2A2F32),
          width: hasFocus ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TvCoverImage(videoInfo: videoInfo),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: hasFocus ? 0.20 : 0.34),
                ],
              ),
            ),
          ),
          if (_shouldShowEpisodeBadge) _buildEpisodeBadge(),
          if (_shouldShowProgress) _buildProgressBar(),
          _TvFocusSweepOverlay(active: hasFocus),
        ],
      ),
    );
  }

  /// 是否展示多集播放进度徽章。
  bool get _shouldShowEpisodeBadge {
    return videoInfo.totalEpisodes > 1 && videoInfo.index > 0;
  }

  /// 是否展示封面底部播放进度条。
  bool get _shouldShowProgress {
    return videoInfo.progressPercentage > 0;
  }

  /// 构建右上角多集进度徽章。
  Widget _buildEpisodeBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        key: const ValueKey('tv-card-episode-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Text(
          '${videoInfo.index}/${videoInfo.totalEpisodes}',
          style: FontUtils.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 构建封面底部播放进度条。
  Widget _buildProgressBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: const ValueKey('tv-card-progress-bar'),
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: FractionallySizedBox(
          key: const ValueKey('tv-card-progress-fill'),
          alignment: Alignment.centerLeft,
          widthFactor: videoInfo.progressPercentage,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF27AE60),
            ),
          ),
        ),
      ),
    );
  }
}

/// TV 卡片获得焦点时的一次性雨刷动画。
class _TvFocusSweepOverlay extends StatefulWidget {
  /// 创建焦点雨刷动画。
  const _TvFocusSweepOverlay({
    required this.active,
  });

  /// 是否处于焦点态。
  final bool active;

  @override
  State<_TvFocusSweepOverlay> createState() => _TvFocusSweepOverlayState();
}

class _TvFocusSweepOverlayState extends State<_TvFocusSweepOverlay>
    with SingleTickerProviderStateMixin {
  /// 焦点停留延迟计时器。
  Timer? _delayTimer;

  /// 是否允许绘制当前这次焦点雨刷。
  bool _showSweep = false;

  /// 焦点雨刷动画控制器。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TvVideoCard.shimmerDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _scheduleSweep();
    }
    _controller.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _TvFocusSweepOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _scheduleSweep();
    } else if (!widget.active && oldWidget.active) {
      _cancelSweep();
    }
  }

  /// 焦点停留超过阈值后启动一次雨刷。
  void _scheduleSweep() {
    _delayTimer?.cancel();
    _delayTimer = Timer(TvVideoCard.focusSweepDelay, () {
      if (!mounted || !widget.active) {
        return;
      }
      setState(() {
        _showSweep = true;
      });
      _controller.forward(from: 0);
    });
  }

  /// 焦点离开时取消待触发或正在播放的雨刷。
  void _cancelSweep() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _controller.stop();
    _controller.reset();
    if (_showSweep && mounted) {
      setState(() {
        _showSweep = false;
      });
    }
  }

  /// 雨刷播放完成后移除覆盖层，避免透明控件长期停留。
  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() {
      _showSweep = false;
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSweep && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress =
              (Curves.easeOutCubic.transform(_controller.value) * 2.8) - 1.4;
          return Opacity(
            opacity: 1 - _controller.value,
            child: Transform.translate(
              offset: Offset(
                progress * TvVideoCard.width,
                progress *
                    TvVideoCard.coverHeight *
                    TvVideoCard.shimmerVerticalTravelFactor,
              ),
              child: child,
            ),
          );
        },
        child: DecoratedBox(
          key: const ValueKey('tv-cover-focus-sweep'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: TvVideoCard.shimmerBegin,
              end: TvVideoCard.shimmerEnd,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
                Colors.transparent,
              ],
              stops: const [0.30, 0.44, 0.50, 0.56, 0.70],
            ),
          ),
        ),
      ),
    );
  }
}

/// TV 卡片封面图片。
///
/// 复用现有图片地址处理逻辑，避免豆瓣等来源封面在 TV 卡片里降级成占位图。
class _TvCoverImage extends StatefulWidget {
  /// 创建 TV 卡片封面图片。
  const _TvCoverImage({
    required this.videoInfo,
  });

  /// 视频展示数据。
  final VideoInfo videoInfo;

  @override
  State<_TvCoverImage> createState() => _TvCoverImageState();
}

class _TvCoverImageState extends State<_TvCoverImage> {
  /// 封面地址解析任务。
  late Future<String> _coverFuture;

  /// 图片磁盘缓存策略任务。
  late Future<bool> _useImageDiskCacheFuture;

  @override
  void initState() {
    super.initState();
    _coverFuture = _resolveCoverUrl();
    _useImageDiskCacheFuture = AppCacheService().shouldUseImageDiskCache();
  }

  @override
  void didUpdateWidget(covariant _TvCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoInfo.cover != widget.videoInfo.cover ||
        oldWidget.videoInfo.source != widget.videoInfo.source) {
      _coverFuture = _resolveCoverUrl();
      _useImageDiskCacheFuture = AppCacheService().shouldUseImageDiskCache();
    }
  }

  /// 解析当前来源的封面地址。
  Future<String> _resolveCoverUrl() {
    return getImageUrl(widget.videoInfo.cover, widget.videoInfo.source);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _coverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            widget.videoInfo.cover.isNotEmpty) {
          return const _TvCoverLoadingSkeleton();
        }

        final coverUrl = snapshot.data ?? widget.videoInfo.cover;
        if (coverUrl.isEmpty) {
          return const _TvCoverFallback();
        }

        return FutureBuilder<bool>(
          future: _useImageDiskCacheFuture,
          builder: (context, cacheSnapshot) {
            if (cacheSnapshot.connectionState != ConnectionState.done) {
              return const _TvCoverLoadingSkeleton();
            }

            final headers =
                getImageRequestHeaders(coverUrl, widget.videoInfo.source);
            if (cacheSnapshot.data != false) {
              return CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                cacheKey: coverUrl,
                httpHeaders: headers,
                placeholder: (_, __) => const _TvCoverLoadingSkeleton(),
                errorWidget: (_, __, ___) => const _TvCoverFallback(),
                fadeInDuration: const Duration(milliseconds: 160),
                fadeOutDuration: const Duration(milliseconds: 80),
              );
            }

            return Image.network(
              coverUrl,
              fit: BoxFit.cover,
              headers: headers,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const _TvCoverLoadingSkeleton();
              },
              errorBuilder: (_, __, ___) => const _TvCoverFallback(),
            );
          },
        );
      },
    );
  }
}

/// TV 卡片封面加载骨架。
///
/// 用轻微倾斜的横向雨刷光带提示图片正在首次加载。
class _TvCoverLoadingSkeleton extends StatefulWidget {
  /// 创建 TV 卡片封面加载骨架。
  const _TvCoverLoadingSkeleton();

  @override
  State<_TvCoverLoadingSkeleton> createState() =>
      _TvCoverLoadingSkeletonState();
}

class _TvCoverLoadingSkeletonState extends State<_TvCoverLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  /// 雨刷光带动画控制器。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TvVideoCard.shimmerDuration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('tv-cover-loading-skeleton'),
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF20282B),
                Color(0xFF14191B),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = (_controller.value * 2.6) - 1.3;
            return Transform.translate(
              offset: Offset(
                progress * TvVideoCard.width,
                progress *
                    TvVideoCard.coverHeight *
                    TvVideoCard.shimmerVerticalTravelFactor,
              ),
              child: child,
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: TvVideoCard.shimmerBegin,
                end: TvVideoCard.shimmerEnd,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.28, 0.42, 0.50, 0.58, 0.72],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// TV 卡片封面占位。
class _TvCoverFallback extends StatelessWidget {
  /// 创建 TV 卡片封面占位。
  const _TvCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF252B2E),
            Color(0xFF15191B),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF5E6B72), width: 2),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Color(0xFF7A878E),
          size: 38,
        ),
      ),
    );
  }
}
