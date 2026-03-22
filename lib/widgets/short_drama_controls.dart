import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'danmaku_control_icons.dart';
import 'player_adapter.dart';
import '../models/search_result.dart';
import '../widgets/player_episodes_panel.dart';
import '../widgets/player_sources_panel.dart';
import '../widgets/player_download_panel.dart';

class ShortDramaControls extends StatefulWidget {
  final PlayerAdapter player;
  final Function(bool) onControlsVisibilityChanged;
  final VoidCallback? onBackPressed;
  final Function(bool) onFullscreenChange;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onPause;
  final String videoUrl;
  final String? videoTitle;
  final String? videoYear;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final List<String>? episodesTitles;
  final String? sourceName;
  final String? currentSource;
  final String? currentId;
  final List<SearchResult>? allSources;
  final Map<String, SourceSpeed>? allSourcesSpeed;
  final bool live;
  final ValueNotifier<double> playbackSpeedListenable;
  final Future<void> Function(double speed) onSetSpeed;
  final void Function(int index)? onEpisodeTap;
  final void Function(SearchResult source)? onSourceTap;
  final Future<void> Function()? onRefreshSources; // 💡 补全缺失的变量
  final void Function(BuildContext context)?
      onDanmakuButtonPressed; // 💡 补全缺失的变量
  final void Function(BuildContext context)? onDanmakuMatchButtonPressed;
  final void Function(BuildContext context)? onSleepTimerButtonPressed;
  final bool? isFavorite; // 💡 新增
  final VoidCallback? onFavoriteToggle; // 💡 新增
  final VoidCallback? onCastPressed; // 💡 新增
  final VoidCallback? onPipPressed; // 💡 新增
  final bool isPipMode; // 💡 新增：小窗模式标记
  final String videoCover;
  final bool isLocal;
  final bool hasActiveSleepTimer;

  const ShortDramaControls({
    super.key,
    required this.player,
    required this.onControlsVisibilityChanged,
    this.onBackPressed,
    required this.onFullscreenChange,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.onPause,
    required this.videoUrl,
    this.videoTitle,
    this.videoYear,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.episodesTitles,
    this.sourceName,
    this.currentSource,
    this.currentId,
    this.allSources,
    this.allSourcesSpeed,
    this.live = false,
    required this.playbackSpeedListenable,
    required this.onSetSpeed,
    this.onEpisodeTap,
    this.onSourceTap,
    this.onRefreshSources,
    this.onDanmakuButtonPressed,
    this.onDanmakuMatchButtonPressed,
    this.onSleepTimerButtonPressed,
    this.isFavorite,
    this.onFavoriteToggle,
    this.onCastPressed,
    this.onPipPressed,
    this.isPipMode = false, // 💡 默认非小窗
    required this.videoCover,
    this.isLocal = false,
    this.hasActiveSleepTimer = false,
  });

  @override
  State<ShortDramaControls> createState() => ShortDramaControlsState();
}

class ShortDramaControlsState extends State<ShortDramaControls>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  bool _isDragging = false;
  Duration? _dragPosition;
  double _originalSpeed = 1.0;
  bool _isEdgeLongPressing = false;
  String? _toastMessage; // 💡 新增
  Timer? _toastTimer; // 💡 新增
  StreamSubscription? _playStateSubscription; // 💡 新增：管理订阅

  // 💡 进度条微调相关状态
  double _dragStartPercent = 0;
  double _dragStartLocalX = 0;
  double _currentDragPercent = 0;

  late AnimationController _playPauseAnimController;
  late Animation<double> _playPauseScale;
  late Animation<double> _playPauseOpacity;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.player.state.playing;

    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      // 💡 关键修复：根据初始状态设置动画进度，防止切换后图标消失
      value: _isPlaying ? 0.0 : 1.0,
    );

    _playPauseScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _playPauseAnimController, curve: Curves.easeOutBack),
    );

    _playPauseOpacity = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(parent: _playPauseAnimController, curve: Curves.easeIn),
    );

    // 💡 强化同步逻辑
    _playStateSubscription = widget.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
        if (playing) {
          _playPauseAnimController.reverse();
        } else {
          _playPauseAnimController.forward();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortDramaControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 💡 核心修复 1：如果播放器实例发生了变化（通常是适配器重置），必须重新绑定监听器
    if (oldWidget.player != widget.player) {
      _playStateSubscription?.cancel();
      _isPlaying = widget.player.state.playing;
      _playPauseAnimController.value = _isPlaying ? 0.0 : 1.0;

      _playStateSubscription = widget.player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
          if (playing) {
            _playPauseAnimController.reverse();
          } else {
            _playPauseAnimController.forward();
          }
        }
      });
    }

    // 💡 核心修复 2：同步集数变化时的状态
    if (oldWidget.currentEpisodeIndex != widget.currentEpisodeIndex) {
      final bool nowPlaying = widget.player.state.playing;
      if (_isPlaying != nowPlaying) {
        setState(() => _isPlaying = nowPlaying);
        _playPauseAnimController.value = nowPlaying ? 0.0 : 1.0;
      }
    }
  }

  /// 💡 新增：显示局部提示
  void showToast(String message) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _playStateSubscription?.cancel(); // 💡 释放资源
    _playPauseAnimController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    // 直接读取播放器实时状态，解决本地变量同步滞后的问题
    final bool isActuallyPlaying = widget.player.state.playing;
    if (isActuallyPlaying) {
      widget.player.pause();
    } else {
      widget.player.play();
    }
  }

  void _showEpisodesDialog() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final currentEpisodes = widget.allSources
            ?.where((s) =>
                s.source == widget.currentSource && s.id == widget.currentId)
            .firstOrNull
            ?.episodes ??
        [];

    // 手机模式：从底部弹出，预留出上方 16:9 的空间
    final playerHeight = screenWidth / (16 / 9);
    final maxPanelHeight = screenHeight - statusBarHeight - playerHeight;
    final adaptiveLayout = PlayerEpisodesPanel.estimateAdaptiveLayout(
      context: context,
      episodes: currentEpisodes,
      episodesTitles: widget.episodesTitles ?? [],
      maxWidth: screenWidth,
      maxHeight: maxPanelHeight,
      isCompact: false,
      minWidth: screenWidth,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return SizedBox(
              height: adaptiveLayout.preferredHeight,
              width: double.infinity,
              child: PlayerEpisodesPanel(
                theme: theme,
                episodes: currentEpisodes,
                episodesTitles: widget.episodesTitles ?? [],
                currentEpisodeIndex: widget.currentEpisodeIndex ?? 0,
                isReversed: false,
                crossAxisCount: adaptiveLayout.maxColumns,
                backgroundOpacity: 1.0, // 竖屏不透明
                isCompact: false, // 竖屏宽松模式
                onEpisodeTap: (index) {
                  Navigator.pop(context);
                  if (widget.onEpisodeTap != null) {
                    widget.onEpisodeTap!(index);
                  }
                },
                onToggleOrder: () {
                  dialogSetState(() {
                    // 内部切换排序
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showSourcesDialog() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 手机模式高度计算
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter dialogSetState) {
            return SizedBox(
              height: panelHeight,
              width: double.infinity,
              child: PlayerSourcesPanel(
                theme: theme,
                sources: widget.allSources ?? [],
                currentSource: widget.currentSource ?? '',
                currentId: widget.currentId ?? '',
                sourcesSpeed: widget.allSourcesSpeed ?? {},
                backgroundOpacity: 1.0, // 竖屏不透明
                isCompact: false, // 竖屏宽松模式
                onSourceTap: (source) {
                  Navigator.pop(context);
                  widget.onSourceTap?.call(source);
                },
                onRefresh: () async {
                  if (widget.onRefreshSources != null) {
                    await widget.onRefreshSources!();
                    dialogSetState(() {}); // 刷新完成后通知弹窗重绘
                  }
                },
                videoCover: widget.videoCover,
                videoTitle: widget.videoTitle ?? '',
              ),
            );
          },
        );
      },
    );
  }

  void _showDownloadDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height *
            0.64, // 💡 0.8 * 0.8 = 0.64 (降低 20%)
        child: PlayerDownloadPanel(
          theme: Theme.of(context),
          title: widget.videoTitle ?? '',
          cover: widget.videoCover,
          episodes: List.generate(widget.totalEpisodes ?? 0, (i) => ""),
          episodesTitles: widget.episodesTitles ?? [],
          currentEpisodeIndex: widget.currentEpisodeIndex,
          isCompact: false,
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShortDramaSettingsSheet(
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
        currentSpeed: widget.playbackSpeedListenable.value,
        isLocal: widget.isLocal,
        isFavorite: widget.isFavorite,
        onSpeedChanged: (speed) {
          widget.onSetSpeed(speed);
          Navigator.pop(context);
        },
        onDanmakuPressed: () {
          Navigator.pop(context);
          widget.onDanmakuButtonPressed?.call(context);
        },
        onDanmakuMatchPressed: () {
          // 💡 新增
          Navigator.pop(context);
          widget.onDanmakuMatchButtonPressed?.call(context);
        },
        onDownloadPressed: () {
          Navigator.pop(context);
          _showDownloadDialog();
        },
        onFavoriteToggle: () {
          Navigator.pop(context);
          widget.onFavoriteToggle?.call();
        },
        onSleepTimerPressed: widget.onSleepTimerButtonPressed == null
            ? null
            : () {
                Navigator.pop(context);
                widget.onSleepTimerButtonPressed?.call(context);
              },
        onCastPressed: () {
          Navigator.pop(context);
          widget.onCastPressed?.call();
        },
        onPipPressed: widget.onPipPressed == null
            ? null
            : () {
                Navigator.pop(context);
                widget.onPipPressed?.call();
              },
        hasActiveSleepTimer: widget.hasActiveSleepTimer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildGestureLayer(),
        _buildPlayPauseIndicator(),
        // 💡 优化：进入小窗前自动隐藏，从小窗返回渐入
        _buildTopBar(),
        _buildBottomUI(),
        _buildToast(),
      ],
    );
  }

  /// 💡 新增：构建局部提示 UI
  Widget _buildToast() {
    if (_toastMessage == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 120, // 💡 在底部按钮组上方一点，不挡住操作
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _toastMessage != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              _toastMessage!,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureLayer() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _handleTap,
        // 💡 移除 onVerticalDragEnd，交给 PageView 处理
        onLongPressStart: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final x = details.localPosition.dx;
          // 💡 优化：将两侧倍速感应区域从 15% 扩大到 20%
          if (x < screenWidth * 0.2 || x > screenWidth * 0.8) {
            _originalSpeed = widget.playbackSpeedListenable.value;
            widget.onSetSpeed(2.0);
            setState(() => _isEdgeLongPressing = true);
          } else {
            _showSettingsDialog();
          }
        },
        onLongPressEnd: (details) {
          if (_isEdgeLongPressing) {
            widget.onSetSpeed(_originalSpeed);
            setState(() => _isEdgeLongPressing = false);
          }
        },
        behavior: HitTestBehavior.opaque,
      ),
    );
  }

  Widget _buildPlayPauseIndicator() {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _playPauseAnimController,
          builder: (context, child) {
            return Opacity(
              opacity: _isPlaying ? 0.0 : _playPauseOpacity.value,
              child: Transform.scale(
                scale: _playPauseScale.value,
                child: const Icon(Icons.play_arrow_rounded,
                    size: 100, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: widget.isPipMode ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: widget.onBackPressed,
              ),
              Expanded(
                child: Text(
                  widget.videoTitle ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onCastPressed != null)
                IconButton(
                  icon: const Icon(Icons.cast, color: Colors.white, size: 22),
                  onPressed: widget.onCastPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomUI() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: widget.isPipMode ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(),
            const SizedBox(height: 8),
            _buildActionButtons(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: _showEpisodesDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.list, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '选集 · 第${(widget.currentEpisodeIndex ?? 0) + 1}集 · 共 ${widget.totalEpisodes ?? 0} 集',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_up,
                        color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => widget.onFullscreenChange(false),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fullscreen_exit,
                  color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, snapshot) {
        final dur = widget.player.state.duration;
        final pos =
            _dragPosition ?? (snapshot.data ?? widget.player.state.position);
        double percent = dur.inMilliseconds > 0
            ? pos.inMilliseconds / dur.inMilliseconds
            : 0.0;

        final double barHeight = _isDragging ? 6.0 : (_isPlaying ? 2.0 : 4.5);
        // 💡 颜色同步：根据 MobilePlayerControls，暂停时应显眼
        final Color activeColor =
            _isPlaying ? Colors.white.withOpacity(0.7) : Colors.red;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final width = box.size.width;
            setState(() {
              _isDragging = true;
              _dragStartLocalX = details.localPosition.dx;
              _dragStartPercent = dur.inMilliseconds > 0
                  ? widget.player.state.position.inMilliseconds /
                      dur.inMilliseconds
                  : 0.0;
              _currentDragPercent = _dragStartPercent;
              _dragPosition = widget.player.state.position;
            });
          },
          onHorizontalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final width = box.size.width;
            if (width <= 0 || dur.inMilliseconds <= 0) return;

            // 💡 核心：垂直距离检测（微调逻辑）
            // 进度条在 80px 容器底部，dy < 40 意味着手指向上拉离了 40px 以上
            final double dy = details.localPosition.dy;
            double factor = 1.0;
            if (dy < -20) {
              factor = 0.2; // 远离进度条，进入微调模式
            } else if (dy < 20) {
              factor = 0.5; // 中间距离，半速模式
            }

            // 计算横向位移增量
            final double deltaX = details.localPosition.dx - _dragStartLocalX;
            final double deltaPercent = (deltaX / width) * factor;

            setState(() {
              _currentDragPercent =
                  (_dragStartPercent + deltaPercent).clamp(0.0, 1.0);
              _dragPosition = Duration(
                  milliseconds:
                      (dur.inMilliseconds * _currentDragPercent).round());
            });
          },
          onHorizontalDragEnd: (_) {
            if (_dragPosition != null) {
              widget.player.seek(_dragPosition!);
              if (!_isPlaying) widget.player.play();
            }
            setState(() {
              _isDragging = false;
              _dragPosition = null;
            });
          },
          child: Container(
            height: 80, // 💡 优化：显著增大触摸响应范围，从 40 提高到 80，提高滑动成功率
            width: double.infinity,
            alignment: Alignment.bottomCenter,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: barHeight,
                  width: double.infinity,
                  color: Colors.white.withOpacity(0.12),
                ),
                FractionallySizedBox(
                  widthFactor: (_isDragging ? _currentDragPercent : percent)
                      .clamp(0.0, 1.0),
                  child: Container(
                    height: barHeight,
                    color: activeColor,
                  ),
                ),
                if (_isDragging && _dragPosition != null)
                  Positioned(
                    top: -80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "${_formatDuration(_dragPosition!)} / ${_formatDuration(dur)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }
}

class _ShortDramaSettingsSheet extends StatefulWidget {
  final bool isDarkMode;
  final double currentSpeed;
  final bool isLocal;
  final bool? isFavorite;
  final Function(double) onSpeedChanged;
  final VoidCallback onDanmakuPressed;
  final VoidCallback onDanmakuMatchPressed; // 💡 新增
  final VoidCallback onDownloadPressed;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onCastPressed;
  final VoidCallback? onSleepTimerPressed;
  final VoidCallback? onPipPressed;
  final bool hasActiveSleepTimer;

  const _ShortDramaSettingsSheet({
    required this.isDarkMode,
    required this.currentSpeed,
    required this.isLocal,
    required this.onSpeedChanged,
    required this.onDanmakuPressed,
    required this.onDanmakuMatchPressed, // 💡 新增
    required this.onDownloadPressed,
    required this.onFavoriteToggle,
    required this.onCastPressed,
    this.onSleepTimerPressed,
    this.onPipPressed,
    this.isFavorite,
    this.hasActiveSleepTimer = false,
  });

  @override
  State<_ShortDramaSettingsSheet> createState() =>
      _ShortDramaSettingsSheetState();
}

class _ShortDramaSettingsSheetState extends State<_ShortDramaSettingsSheet> {
  bool _danmakuEnabled = true;

  @override
  Widget build(BuildContext context) {
    final speeds = (Platform.isIOS && !widget.isLocal)
        ? [0.75, 1.0, 1.25, 1.5, 2.0]
        : [0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

    // 💡 颜色适配逻辑
    final bool isDark = widget.isDarkMode;
    final Color bgColor =
        isDark ? Colors.black.withOpacity(0.92) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subColor = isDark ? Colors.white54 : Colors.black54;
    final Color itemBgColor = isDark ? Colors.white10 : Colors.grey[200]!;
    final Color iconBtnColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 24, horizontal: 20), // 💡 缩小外边距 (32 -> 24)
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1)
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                  widget.isFavorite! ? Icons.favorite : LucideIcons.heart, '收藏',
                  iconColor: widget.isFavorite! ? Colors.red : iconBtnColor,
                  labelColor: subColor,
                  onTap: widget.onFavoriteToggle),
              if (widget.onSleepTimerPressed != null)
                _buildActionButton(Icons.timer_outlined, '定时',
                    iconColor: widget.hasActiveSleepTimer
                        ? Colors.green
                        : iconBtnColor,
                    labelColor: subColor,
                    onTap: widget.onSleepTimerPressed),
              _buildActionButton(LucideIcons.monitorPlay, '投屏',
                  iconColor: iconBtnColor,
                  labelColor: subColor,
                  onTap: widget.onCastPressed),
              _buildActionButton(LucideIcons.download, '下载',
                  iconColor: iconBtnColor,
                  labelColor: subColor,
                  onTap: widget.onDownloadPressed),
              if (widget.onPipPressed != null)
                _buildActionButton(LucideIcons.pictureInPicture2, '小窗',
                    iconColor: iconBtnColor,
                    labelColor: subColor,
                    onTap: widget.onPipPressed),
            ],
          ),
          const SizedBox(height: 20), // 💡 缩小间距 (32 -> 20)
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text('播放倍速', style: TextStyle(color: subColor, fontSize: 13)),
          ),
          const SizedBox(height: 8), // 💡 缩小间距 (12 -> 8)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: speeds.map((s) {
              final isSelected = (s - widget.currentSpeed).abs() < 0.01;
              return GestureDetector(
                onTap: () => widget.onSpeedChanged(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : itemBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s}x',
                      style: TextStyle(
                          color: isSelected ? Colors.white : subColor,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20), // 💡 缩小间距 (32 -> 20)
          _buildMenuRow('弹幕',
              titleColor: textColor,
              iconColor: iconBtnColor,
              leading: DanmakuSettingsIcon(
                color: iconBtnColor,
                size: 18,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _danmakuEnabled = !_danmakuEnabled);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: DanmakuToggleIcon(
                      enabled: _danmakuEnabled,
                      size: 22,
                      primaryColor: iconBtnColor,
                    ),
                  ),
                  if (_danmakuEnabled) ...[
                    const SizedBox(width: 8), // 💡 缩小间距
                    GestureDetector(
                      onTap: widget.onDanmakuPressed,
                      child: const Row(
                        children: [
                          Text('设置',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 13)),
                          Icon(Icons.chevron_right,
                              color: Colors.green, size: 16),
                        ],
                      ),
                    ),
                  ]
                ],
              )),
          const SizedBox(height: 4),
          _buildMenuRow('手动匹配弹幕',
              icon: Icons.search,
              titleColor: textColor,
              iconColor: iconBtnColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: widget.onDanmakuMatchPressed,
                    child: const Row(
                      children: [
                        Text('搜索',
                            style:
                                TextStyle(color: Colors.green, fontSize: 13)),
                        Icon(Icons.chevron_right,
                            color: Colors.green, size: 16),
                      ],
                    ),
                  ),
                ],
              )),
          const SizedBox(height: 4),
          _buildMenuRow('弹幕列表',
              icon: LucideIcons.messageSquareText,
              titleColor: textColor,
              iconColor: iconBtnColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('0 条', style: TextStyle(color: subColor, fontSize: 14)),
                  Icon(Icons.chevron_right,
                      color: subColor.withOpacity(0.5), size: 18),
                ],
              )),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label,
      {VoidCallback? onTap,
      Color iconColor = Colors.white,
      Color labelColor = Colors.white70}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, // 💡 缩小图标背景 (56 -> 52)
            height: 52,
            decoration: BoxDecoration(
                color: widget.isDarkMode ? Colors.white10 : Colors.grey[200],
                shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22), // 💡 缩小图标 (24 -> 22)
          ),
          const SizedBox(height: 6), // 💡 缩小间距 (8 -> 6)
          Text(label,
              style: TextStyle(
                  color: labelColor, fontSize: 11)), // 💡 缩小字体 (12 -> 11)
        ],
      ),
    );
  }

  Widget _buildMenuRow(
    String title, {
    IconData? icon,
    Widget? leading,
    required Widget trailing,
    Color titleColor = Colors.white,
    Color iconColor = Colors.white,
  }) {
    return SizedBox(
      height: 48, // 💡 降低高度 (56 -> 48)
      child: Row(
        children: [
          leading ??
              Icon(icon, color: iconColor, size: 18), // 💡 缩小图标 (20 -> 18)
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  color: titleColor, fontSize: 15)), // 💡 缩小字号 (16 -> 15)
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}
