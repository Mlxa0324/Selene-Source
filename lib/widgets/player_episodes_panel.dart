import 'package:flutter/material.dart';
import '../utils/device_utils.dart';

class PlayerEpisodesPanel extends StatefulWidget {
  final ThemeData theme;
  final List<String> episodes;
  final List<String> episodesTitles;
  final int currentEpisodeIndex;
  final bool isReversed;
  final Function(int) onEpisodeTap;
  final VoidCallback onToggleOrder;
  final int crossAxisCount;
  final double? backgroundOpacity; // 背景不透明度
  final bool isCompact; // 是否紧凑模式

  const PlayerEpisodesPanel({
    super.key,
    required this.theme,
    required this.episodes,
    required this.episodesTitles,
    required this.currentEpisodeIndex,
    required this.isReversed,
    required this.onEpisodeTap,
    required this.onToggleOrder,
    this.crossAxisCount = 2,
    this.backgroundOpacity,
    this.isCompact = true,
  });

  @override
  State<PlayerEpisodesPanel> createState() => _PlayerEpisodesPanelState();
}

class _PlayerEpisodesPanelState extends State<PlayerEpisodesPanel> {
  final GlobalKey _gridKey = GlobalKey();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrent();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (_gridKey.currentContext == null) return;

    final gridBox = _gridKey.currentContext!.findRenderObject() as RenderBox;

    final targetIndex = widget.isReversed
        ? widget.episodes.length - 1 - widget.currentEpisodeIndex
        : widget.currentEpisodeIndex;

    final crossAxisCount = widget.crossAxisCount;
    final mainAxisSpacing = widget.isCompact ? 8.0 : 12.0;
    final childAspectRatio = widget.crossAxisCount == 4 
        ? 2.2 
        : (widget.crossAxisCount == 3 ? 2.0 : (widget.isCompact ? 3.0 : 2.5));

    final itemWidth =
        (gridBox.size.width - (crossAxisCount - 1) * mainAxisSpacing) / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;

    final row = (targetIndex / crossAxisCount).floor();
    final offset = row * (itemHeight + mainAxisSpacing);

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final opacity = widget.backgroundOpacity ?? (isDarkMode ? 0.85 : 0.95);
    final backgroundColor = isDarkMode 
        ? Colors.black.withOpacity(opacity) 
        : Colors.white.withOpacity(opacity);
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: EdgeInsets.fromLTRB(20, widget.isCompact ? 16 : 20, 8, widget.isCompact ? 8 : 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选集 (${widget.episodes.length})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.isCompact ? 17 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 集数网格
          Expanded(
            child: GridView.builder(
              key: _gridKey,
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 4, 16, widget.isCompact ? 16 : 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.crossAxisCount,
                crossAxisSpacing: widget.isCompact ? 8 : 12,
                mainAxisSpacing: widget.isCompact ? 8 : 12,
                childAspectRatio: widget.crossAxisCount == 4 
                    ? 2.2 
                    : (widget.crossAxisCount == 3 ? 2.0 : (widget.isCompact ? 3.0 : 2.5)),
              ),
              itemCount: widget.episodes.length,
              itemBuilder: (context, index) {
                final episodeIndex = widget.isReversed
                    ? widget.episodes.length - 1 - index
                    : index;
                final isCurrentEpisode =
                    episodeIndex == widget.currentEpisodeIndex;

                String episodeTitle = '';
                if (widget.episodesTitles.isNotEmpty &&
                    episodeIndex < widget.episodesTitles.length) {
                  episodeTitle = widget.episodesTitles[episodeIndex];
                } else {
                  episodeTitle = '第${episodeIndex + 1}集';
                }

                return _EpisodePanelItemWithHover(
                  isCurrentEpisode: isCurrentEpisode,
                  isDarkMode: isDarkMode,
                  episodeTitle: episodeTitle,
                  isCompact: widget.isCompact,
                  onTap: isCurrentEpisode ? null : () => widget.onEpisodeTap(episodeIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


/// 带 hover 效果的选集面板项
class _EpisodePanelItemWithHover extends StatefulWidget {
  final bool isCurrentEpisode;
  final bool isDarkMode;
  final String episodeTitle;
  final bool isCompact;
  final VoidCallback? onTap;

  const _EpisodePanelItemWithHover({
    required this.isCurrentEpisode,
    required this.isDarkMode,
    required this.episodeTitle,
    required this.isCompact,
    this.onTap,
  });

  @override
  State<_EpisodePanelItemWithHover> createState() => _EpisodePanelItemWithHoverState();
}

class _EpisodePanelItemWithHoverState extends State<_EpisodePanelItemWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrentEpisode) 
          ? SystemMouseCursors.click 
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrentEpisode) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentEpisode
                ? Colors.green.withOpacity(0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode 
                        ? const Color(0xFF1A3D2E)
                        : const Color(0xFFE8F5E9))
                    : (widget.isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05))),
            borderRadius: BorderRadius.circular(8),
            border: widget.isCurrentEpisode
                ? Border.all(color: Colors.green, width: 1.5)
                : null,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: widget.isCompact ? 2 : 6),
              child: Text(
                widget.episodeTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isCurrentEpisode
                      ? Colors.green
                      : (widget.isDarkMode
                          ? Colors.white70
                          : Colors.black87),
                  fontWeight: widget.isCurrentEpisode ? FontWeight.bold : FontWeight.normal,
                  fontSize: widget.isCompact ? 13 : 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
