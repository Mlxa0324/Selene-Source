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

/// TV 封面延迟加载判断函数。
typedef TvDeferredLoadingDecider = bool Function(BuildContext context);

/// TV 封面真实图片请求开始回调。
typedef TvCoverImageRequestStarted = void Function(String coverUrl);

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
    this.onLongPressed,
    this.onFocusChanged,
    this.onFocusedNodeChanged,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.focusNode,
    this.autofocus = false,
    this.autoScrollOnFocus = true,
    this.focusScrollAlignment = TvFocusScroll.defaultAlignment,
    this.scaleAlignment = Alignment.center,
    this.focusMemoryGroupKey,
    this.deferredLoadingDecider,
    this.deferredLoadingRetryDelay =
        _TvCoverImage.defaultDeferredLoadingRetryDelay,
    this.onCoverImageRequestStarted,
  });

  /// 视频展示数据。
  final VideoInfo videoInfo;

  /// 卡片点击回调。
  final VoidCallback? onPressed;

  /// 卡片长按回调。
  final VoidCallback? onLongPressed;

  /// 焦点变化回调。
  final ValueChanged<bool>? onFocusChanged;

  /// 当前卡片真正获焦时的焦点节点回调。
  ///
  /// 上层可借此记录用户最近一次停留的卡片位置。
  final ValueChanged<FocusNode>? onFocusedNodeChanged;

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

  /// 焦点放大的对齐方向。
  ///
  /// 末列卡片贴右边时改为向内放大，避免右侧焦点描边被裁掉。
  final Alignment scaleAlignment;

  /// 上下跨列表焦点记忆分组 Key。
  final Object? focusMemoryGroupKey;

  /// 图片延迟加载判断函数。
  ///
  /// 默认复用 Flutter 提供的滚动期延迟加载建议，测试场景可注入稳定判断。
  final TvDeferredLoadingDecider? deferredLoadingDecider;

  /// 图片延迟加载重试间隔。
  ///
  /// 滚动期间会按该节流间隔重新判断是否可以开始请求图片。
  final Duration deferredLoadingRetryDelay;

  /// 封面真实图片请求开始回调。
  ///
  /// 仅在首次允许开始构建网络图片时触发一次，主要用于测试滚动期延迟加载行为。
  final TvCoverImageRequestStarted? onCoverImageRequestStarted;

  /// 当前视频数据 ID，用于 TV 测试和焦点定位。
  String get focusKey => 'tv-video-card-focus-${videoInfo.id}';

  /// TV 卡片固定宽度。
  static const double width = 158.0;

  /// TV 卡片固定高度。
  static const double height = 298.0;

  /// TV 卡片封面固定高度。
  static const double coverHeight = 237.0;

  /// TV 卡片获取焦点后的整体放大比例。
  static const double focusedScale = 1.08;

  /// TV 卡片标题字号。
  static const double titleFontSize = 16.0;

  /// TV 卡片副标题字号。
  static const double subtitleFontSize = 13.0;

  /// TV 焦点雨刷光带起点。
  ///
  /// 保持纯横向移动，避免卡片停留后的延迟雨刷继续出现斜向扫过效果。
  static const Alignment shimmerBegin = Alignment(-1.2, 0);

  /// TV 焦点雨刷光带终点。
  ///
  /// 与起点保持同一水平线，只做从左到右的平移。
  static const Alignment shimmerEnd = Alignment(1.2, 0);

  /// TV 焦点雨刷纵向位移系数。
  ///
  /// 当前交互明确要求只做左右平移，因此固定为 0。
  static const double shimmerVerticalTravelFactor = 0;

  /// TV 焦点雨刷边缘高光色。
  ///
  /// 维持轻量提亮，让光带两侧先有一层柔和扩散，避免看起来像硬白线。
  static const Color shimmerSoftEdgeColor = Color(0x12FFFFFF);

  /// TV 焦点雨刷中段高光色。
  ///
  /// 位于中心亮带两侧，用于拉宽整体高光过渡范围。
  static const Color shimmerMidColor = Color(0x20FFFFFF);

  /// TV 焦点雨刷中心高光色。
  ///
  /// 中心保持最亮，但不使用纯实心白条，避免在深色封面上显得生硬。
  static const Color shimmerCenterColor = Color(0x2CFFFFFF);

  /// TV 焦点雨刷渐变停靠点。
  ///
  /// 使用更宽的七段式渐变，让延迟雨刷从“细线”变成更有体积感的柔和光带。
  static const List<double> shimmerStops = <double>[
    0.08,
    0.24,
    0.38,
    0.50,
    0.62,
    0.76,
    0.92,
  ];

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
      onLongPressed: onLongPressed,
      onFocusChanged: onFocusChanged,
      onFocusedNodeChanged: onFocusedNodeChanged,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      builder: (context, hasFocus) {
        return AnimatedScale(
          scale: hasFocus ? focusedScale : 1,
          alignment: scaleAlignment,
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
                      fontSize: titleFontSize,
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
                      fontSize: subtitleFontSize,
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
    return parts.isEmpty ? 'IvyTV' : parts.join(' · ');
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
          _TvCoverImage(
            videoInfo: videoInfo,
            deferredLoadingDecider: deferredLoadingDecider,
            deferredLoadingRetryDelay: deferredLoadingRetryDelay,
            onCoverImageRequestStarted: onCoverImageRequestStarted,
          ),
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
        child: const DecoratedBox(
          key: ValueKey('tv-cover-focus-sweep'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: TvVideoCard.shimmerBegin,
              end: TvVideoCard.shimmerEnd,
              colors: <Color>[
                Colors.transparent,
                TvVideoCard.shimmerSoftEdgeColor,
                TvVideoCard.shimmerMidColor,
                TvVideoCard.shimmerCenterColor,
                TvVideoCard.shimmerMidColor,
                TvVideoCard.shimmerSoftEdgeColor,
                Colors.transparent,
              ],
              stops: TvVideoCard.shimmerStops,
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
    this.deferredLoadingDecider,
    this.deferredLoadingRetryDelay = defaultDeferredLoadingRetryDelay,
    this.onCoverImageRequestStarted,
  });

  /// 默认延迟加载重试间隔。
  static const Duration defaultDeferredLoadingRetryDelay =
      Duration(milliseconds: 120);

  /// 视频展示数据。
  final VideoInfo videoInfo;

  /// 图片延迟加载判断函数。
  final TvDeferredLoadingDecider? deferredLoadingDecider;

  /// 图片延迟加载重试间隔。
  final Duration deferredLoadingRetryDelay;

  /// 封面真实图片请求开始回调。
  final TvCoverImageRequestStarted? onCoverImageRequestStarted;

  @override
  State<_TvCoverImage> createState() => _TvCoverImageState();
}

class _TvCoverImageState extends State<_TvCoverImage> {
  /// 封面地址解析任务。
  late Future<String> _coverFuture;

  /// 图片磁盘缓存策略任务。
  late Future<bool> _useImageDiskCacheFuture;

  /// 延迟加载重试定时器。
  Timer? _deferredLoadingRetryTimer;

  /// 当前卡片是否已经允许发起真实图片请求。
  bool _canStartImageRequest = false;

  /// 是否已经通知过“开始构建真实图片请求”。
  bool _didNotifyImageRequestStarted = false;

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
      _cancelDeferredLoadingRetry();
      _canStartImageRequest = false;
      _didNotifyImageRequestStarted = false;
      _coverFuture = _resolveCoverUrl();
      _useImageDiskCacheFuture = AppCacheService().shouldUseImageDiskCache();
    }
  }

  /// 解析当前来源的封面地址。
  Future<String> _resolveCoverUrl() {
    return getImageUrl(widget.videoInfo.cover, widget.videoInfo.source);
  }

  /// 是否建议在当前滚动状态下延迟图片请求。
  bool _shouldDeferLoading(BuildContext context) {
    final decider = widget.deferredLoadingDecider;
    return decider?.call(context) ??
        Scrollable.recommendDeferredLoadingForContext(context);
  }

  /// 为滚动中的卡片安排下一次可加载判断。
  void _scheduleDeferredLoadingRetry() {
    if (_deferredLoadingRetryTimer != null) {
      return;
    }
    _deferredLoadingRetryTimer = Timer(widget.deferredLoadingRetryDelay, () {
      _deferredLoadingRetryTimer = null;
      if (!mounted) {
        return;
      }
      setState(() {
        // 仅触发重建，是否放行由 build 阶段重新判断。
      });
    });
  }

  /// 取消滚动期间的延迟加载重试。
  void _cancelDeferredLoadingRetry() {
    _deferredLoadingRetryTimer?.cancel();
    _deferredLoadingRetryTimer = null;
  }

  /// 通知封面已经允许开始构建真实图片请求。
  void _notifyImageRequestStarted(String coverUrl) {
    if (_didNotifyImageRequestStarted) {
      return;
    }
    _didNotifyImageRequestStarted = true;
    widget.onCoverImageRequestStarted?.call(coverUrl);
  }

  /// 根据当前滚动状态决定是否可以开始发起真实图片请求。
  bool _resolveCanStartImageRequest(BuildContext context) {
    if (_canStartImageRequest) {
      _cancelDeferredLoadingRetry();
      return true;
    }

    if (_shouldDeferLoading(context)) {
      _scheduleDeferredLoadingRetry();
      return false;
    }

    _cancelDeferredLoadingRetry();
    _canStartImageRequest = true;
    return true;
  }

  @override
  void dispose() {
    _cancelDeferredLoadingRetry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _coverFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            widget.videoInfo.cover.isNotEmpty) {
          return const TvCoverLoadingSkeleton();
        }

        final coverUrl = snapshot.data ?? widget.videoInfo.cover;
        if (coverUrl.isEmpty) {
          return const _TvCoverFallback();
        }

        if (!_resolveCanStartImageRequest(context)) {
          // 列表快速滚动时先展示骨架，等滚动趋稳后再真正发起网络图片请求。
          return const TvCoverLoadingSkeleton(
            key: ValueKey('tv-cover-deferred-loading-skeleton'),
          );
        }

        _notifyImageRequestStarted(coverUrl);

        return FutureBuilder<bool>(
          future: _useImageDiskCacheFuture,
          builder: (context, cacheSnapshot) {
            if (cacheSnapshot.connectionState != ConnectionState.done) {
              return const TvCoverLoadingSkeleton();
            }

            final headers =
                getImageRequestHeaders(coverUrl, widget.videoInfo.source);
            if (cacheSnapshot.data != false) {
              return CachedNetworkImage(
                key: const ValueKey('tv-cover-network-image'),
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                cacheKey: coverUrl,
                httpHeaders: headers,
                placeholder: (_, __) => const TvCoverLoadingSkeleton(),
                errorWidget: (_, __, ___) => const _TvCoverFallback(),
                fadeInDuration: const Duration(milliseconds: 160),
                fadeOutDuration: const Duration(milliseconds: 80),
              );
            }

            return Image.network(
              coverUrl,
              key: const ValueKey('tv-cover-network-image'),
              fit: BoxFit.cover,
              headers: headers,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const TvCoverLoadingSkeleton();
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
/// 用从左到右的柔和横向雨刷光带提示图片正在首次加载，也可复用到搜索结果首屏骨架。
class TvCoverLoadingSkeleton extends StatefulWidget {
  /// 创建 TV 卡片封面加载骨架。
  const TvCoverLoadingSkeleton({super.key});

  /// 骨架雨刷最大播放次数。
  ///
  /// 骨架只在首屏加载初期做有限次提示，避免图片慢加载时持续无限刷动分散注意力。
  static const int maxSweepCount = 2;

  /// 骨架雨刷起点，保持纯横向移动，不再带纵向斜切角度。
  static const Alignment shimmerBegin = Alignment(-1.2, 0);

  /// 骨架雨刷终点，保持纯横向移动，不再带纵向斜切角度。
  static const Alignment shimmerEnd = Alignment(1.2, 0);

  /// 骨架雨刷纵向位移系数。
  ///
  /// 当前骨架明确要求只做左右平移，因此固定为 0。
  static const double shimmerVerticalTravelFactor = 0;

  /// 骨架雨刷边缘高光色。
  ///
  /// 使用偏灰白的低透明度高光，避免在深色海报占位上显得过亮突兀。
  static const Color shimmerSoftEdgeColor = Color(0x12E4EAED);

  /// 骨架雨刷中段高光色。
  ///
  /// 在中心高光外再补一层过渡，拉宽可见高光区域。
  static const Color shimmerMidColor = Color(0x1EE4EAED);

  /// 骨架雨刷中心高光色。
  ///
  /// 中心亮度仍高于边缘，但相比纯白高光更柔和，减少“白条”割裂感。
  static const Color shimmerCenterColor = Color(0x2AE4EAED);

  /// 骨架雨刷渐变停靠点。
  ///
  /// 采用更宽的七段式高光，让封面加载时的雨刷更有体积感。
  static const List<double> shimmerStops = <double>[
    0.10,
    0.26,
    0.40,
    0.50,
    0.60,
    0.74,
    0.90,
  ];

  @override
  State<TvCoverLoadingSkeleton> createState() => _TvCoverLoadingSkeletonState();
}

class _TvCoverLoadingSkeletonState extends State<TvCoverLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  /// 已完成的雨刷轮次。
  int _completedSweepCount = 0;

  /// 雨刷光带动画控制器。
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TvVideoCard.shimmerDuration,
  )..addStatusListener(_handleSweepStatus);

  @override
  void initState() {
    super.initState();
    // 骨架雨刷只播放有限次数，避免图片迟迟未返回时一直循环干扰浏览。
    _controller.forward();
  }

  /// 处理骨架雨刷轮次收口。
  void _handleSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    _completedSweepCount += 1;
    if (_completedSweepCount >= TvCoverLoadingSkeleton.maxSweepCount) {
      // 收在最后一帧，保持光带停在右侧淡出位置，不再继续无限重播。
      _controller.stop(canceled: false);
      _controller.value = 1;
      return;
    }

    // 仍有剩余轮次时，从头开始下一次雨刷。
    _controller
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleSweepStatus);
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
                    TvCoverLoadingSkeleton.shimmerVerticalTravelFactor,
              ),
              child: child,
            );
          },
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: TvCoverLoadingSkeleton.shimmerBegin,
                end: TvCoverLoadingSkeleton.shimmerEnd,
                colors: <Color>[
                  Colors.transparent,
                  TvCoverLoadingSkeleton.shimmerSoftEdgeColor,
                  TvCoverLoadingSkeleton.shimmerMidColor,
                  TvCoverLoadingSkeleton.shimmerCenterColor,
                  TvCoverLoadingSkeleton.shimmerMidColor,
                  TvCoverLoadingSkeleton.shimmerSoftEdgeColor,
                  Colors.transparent,
                ],
                stops: TvCoverLoadingSkeleton.shimmerStops,
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
