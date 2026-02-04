import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  final Future<void> Function()? onRefreshSources;
  final void Function(BuildContext context)? onDanmakuButtonPressed;
  final String videoCover;

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
    required this.videoCover,
  });

  @override
  State<ShortDramaControls> createState() => _ShortDramaControlsState();
}

class _ShortDramaControlsState extends State<ShortDramaControls>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  bool _isDragging = false;
  Duration? _dragPosition;
  double _originalSpeed = 1.0;
  bool _isEdgeLongPressing = false;

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
    );

    _playPauseScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _playPauseAnimController, curve: Curves.easeOutBack),
    );
    
    _playPauseOpacity = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(parent: _playPauseAnimController, curve: Curves.easeIn),
    );

    widget.player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _playPauseAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_isPlaying) {
      widget.player.pause();
      _playPauseAnimController.forward();
    } else {
      widget.player.play();
      _playPauseAnimController.reverse();
    }
  }

  void _showEpisodesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: PlayerEpisodesPanel(
          theme: Theme.of(context),
          episodes: List.generate(widget.totalEpisodes ?? 0, (index) => ""),
          episodesTitles: widget.episodesTitles ?? [],
          currentEpisodeIndex: widget.currentEpisodeIndex ?? 0,
          isReversed: false,
          onEpisodeTap: (index) {
            Navigator.pop(context);
            widget.onEpisodeTap?.call(index);
          },
          onToggleOrder: () {},
          crossAxisCount: 3,
          isCompact: false,
        ),
      ),
    );
  }

  void _showSourcesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: PlayerSourcesPanel(
          theme: Theme.of(context),
          sources: widget.allSources ?? [],
          currentSource: widget.currentSource ?? '',
          currentId: widget.currentId ?? '',
          sourcesSpeed: widget.allSourcesSpeed ?? {},
          onSourceTap: (source) {
            Navigator.pop(context);
            widget.onSourceTap?.call(source);
          },
          onRefresh: widget.onRefreshSources ?? () async {},
          videoCover: widget.videoCover,
          videoTitle: widget.videoTitle ?? '',
        ),
      ),
    );
  }

  void _showDownloadDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
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
        onSpeedChanged: (speed) {
          widget.onSetSpeed(speed);
          Navigator.pop(context);
        },
        onDanmakuPressed: () {
          Navigator.pop(context);
          widget.onDanmakuButtonPressed?.call(context);
        },
        onDownloadPressed: () {
          Navigator.pop(context);
          _showDownloadDialog();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildGestureLayer(),
        _buildPlayPauseIndicator(),
        _buildTopBar(),
        _buildBottomUI(),
      ],
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
          if (x < screenWidth * 0.15 || x > screenWidth * 0.85) {
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
                child: const Icon(Icons.play_arrow_rounded, size: 100, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
        onPressed: widget.onBackPressed,
      ),
    );
  }

  Widget _buildBottomUI() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressBar(),
          const SizedBox(height: 8),
          _buildActionButtons(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.list, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '选集 · 共 ${widget.totalEpisodes ?? 0} 集',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: _showSourcesDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.layers, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.sourceName ?? '默认源',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
                  ],
                ),
              ),
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
        final pos = _dragPosition ?? (snapshot.data ?? widget.player.state.position);
        final dur = widget.player.state.duration;
        double percent = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
        
        final double barHeight = _isDragging ? 6.0 : (_isPlaying ? 2.0 : 4.5);
        final Color activeColor = _isPlaying ? Colors.white.withOpacity(0.7) : Colors.orange;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) => setState(() {
            _isDragging = true;
            _dragPosition = widget.player.state.position;
          }),
          onHorizontalDragUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final width = box.size.width;
            double newPercent = (details.localPosition.dx / width).clamp(0.0, 1.0);
            setState(() {
              _dragPosition = Duration(milliseconds: (dur.inMilliseconds * newPercent).round());
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
            height: 40,
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
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    height: barHeight,
                    color: activeColor,
                  ),
                ),
                if (_isDragging && _dragPosition != null)
                  Positioned(
                    top: -55,
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
  final Function(double) onSpeedChanged;
  final VoidCallback onDanmakuPressed;
  final VoidCallback onDownloadPressed;

  const _ShortDramaSettingsSheet({
    required this.isDarkMode,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.onDanmakuPressed,
    required this.onDownloadPressed,
  });

  @override
  State<_ShortDramaSettingsSheet> createState() => _ShortDramaSettingsSheetState();
}

class _ShortDramaSettingsSheetState extends State<_ShortDramaSettingsSheet> {
  bool _danmakuEnabled = true;

  @override
  Widget build(BuildContext context) {
    final speeds = [0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    final subColor = Colors.white54;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(LucideIcons.heart, '收藏'),
              _buildActionButton(LucideIcons.monitorPlay, '投屏'),
              _buildActionButton(LucideIcons.download, '下载', onTap: widget.onDownloadPressed),
              _buildActionButton(LucideIcons.pictureInPicture2, '小窗'),
            ],
          ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('播放倍速', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: speeds.map((s) {
              final isSelected = (s - widget.currentSpeed).abs() < 0.01;
              return GestureDetector(
                onTap: () => widget.onSpeedChanged(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s}x', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          _buildMenuRow(
            Icons.subtitles,
            '弹幕', 
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_danmakuEnabled ? '开启' : '关闭', style: TextStyle(color: subColor, fontSize: 14)),
                const SizedBox(width: 8),
                Switch(
                  value: _danmakuEnabled, 
                  onChanged: (v) => setState(() => _danmakuEnabled = v),
                  activeColor: Colors.green,
                ),
                if (_danmakuEnabled) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: widget.onDanmakuPressed,
                    child: const Row(
                      children: [
                        Text('设置', style: TextStyle(color: Colors.green, fontSize: 14)),
                        Icon(Icons.chevron_right, color: Colors.green, size: 18),
                      ],
                    ),
                  ),
                ]
              ],
            )
          ),
          const SizedBox(height: 8),
          _buildMenuRow(
            LucideIcons.messageSquareText, 
            '弹幕列表', 
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('0 条', style: TextStyle(color: subColor, fontSize: 14)),
                const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
              ],
            )
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMenuRow(IconData icon, String title, {required Widget trailing}) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}