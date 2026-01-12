import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/search_result.dart';
import '../utils/device_utils.dart';

class SourceSpeed {
  String quality = '';
  String loadSpeed = '';
  String pingTime = '';

  SourceSpeed({
    required this.quality,
    required this.loadSpeed,
    required this.pingTime,
  });
}

class PlayerSourcesPanel extends StatefulWidget {
  final ThemeData theme;
  final List<SearchResult> sources;
  final String currentSource;
  final String currentId;
  final Map<String, SourceSpeed> sourcesSpeed;
  final Function(SearchResult) onSourceTap;
  final Future<void> Function() onRefresh;
  final String videoCover;
  final String videoTitle;

  const PlayerSourcesPanel({
    super.key,
    required this.theme,
    required this.sources,
    required this.currentSource,
    required this.currentId,
    required this.sourcesSpeed,
    required this.onSourceTap,
    required this.onRefresh,
    required this.videoCover,
    required this.videoTitle,
  });

  @override
  State<PlayerSourcesPanel> createState() => _PlayerSourcesPanelState();
}

class _PlayerSourcesPanelState extends State<PlayerSourcesPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isRefreshing = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scrollController = ScrollController();

    // 延迟滚动到当前源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSource();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRefreshAnimation() {
    _rotationController.repeat();
  }

  void _stopRefreshAnimation() {
    _rotationController.stop();
    _rotationController.reset();
  }

  void _scrollToCurrentSource() {
    if (!_scrollController.hasClients) return;

    // 找到当前源在列表中的索引
    final currentIndex = widget.sources.indexWhere((source) =>
        source.source == widget.currentSource && source.id == widget.currentId);

    if (currentIndex == -1) return;

    // 计算每个项目的高度（根据紧凑型 UI 调整）
    const itemHeight = 84.0; 
    const itemSpacing = 8.0; 
    const totalItemHeight = itemHeight + itemSpacing;

    final targetOffset = currentIndex * totalItemHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });
    _startRefreshAnimation();

    try {
      await widget.onRefresh();
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      _stopRefreshAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode 
        ? Colors.black.withOpacity(0.85) 
        : Colors.white.withOpacity(0.95);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '换源 (${widget.sources.length})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: RotationTransition(
                        turns: _rotationController,
                        child: Icon(
                          Icons.refresh,
                          size: 20,
                          color: _isRefreshing
                              ? Colors.green
                              : textColor.withOpacity(0.6),
                        ),
                      ),
                      onPressed: _isRefreshing ? null : _handleRefresh,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: widget.sources.length,
              itemBuilder: (context, index) {
                final source = widget.sources[index];
                final isCurrent = source.source == widget.currentSource &&
                    source.id == widget.currentId;
                final speedInfo =
                    widget.sourcesSpeed['${source.source}_${source.id}'];

                return _SourcePanelItemWithHover(
                  isCurrent: isCurrent,
                  isDarkMode: isDarkMode,
                  source: source,
                  speedInfo: speedInfo,
                  theme: widget.theme,
                  onTap: isCurrent ? null : () => widget.onSourceTap(source),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePanelItemWithHover extends StatefulWidget {
  final bool isCurrent;
  final bool isDarkMode;
  final SearchResult source;
  final SourceSpeed? speedInfo;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _SourcePanelItemWithHover({
    required this.isCurrent,
    required this.isDarkMode,
    required this.source,
    this.speedInfo,
    required this.theme,
    this.onTap,
  });

  @override
  State<_SourcePanelItemWithHover> createState() =>
      _SourcePanelItemWithHoverState();
}

class _SourcePanelItemWithHoverState extends State<_SourcePanelItemWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrent)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrent) {
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
          margin: const EdgeInsets.only(bottom: 8),
          height: 84, // 紧凑高度
          decoration: BoxDecoration(
            color: widget.isCurrent
                ? Colors.green.withOpacity(0.1)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05))
                    : (widget.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03))),
            borderRadius: BorderRadius.circular(10),
            border: widget.isCurrent
                ? Border.all(color: Colors.green, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: CachedNetworkImage(
                      imageUrl: widget.source.poster,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: widget.isDarkMode ? Colors.white10 : Colors.black12,
                        child: const Icon(Icons.movie, size: 20, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 信息区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.source.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.source.sourceName,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          if (widget.source.episodes.length > 1) ...[
                            Text(' • ', style: TextStyle(color: textColor.withOpacity(0.3))),
                            Text(
                              '${widget.source.episodes.length}集',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 测速信息
                      if (widget.speedInfo != null)
                        Row(
                          children: [
                            if (widget.speedInfo!.loadSpeed.isNotEmpty &&
                                !widget.speedInfo!.loadSpeed.contains('超时'))
                              Text(
                                widget.speedInfo!.loadSpeed,
                                style: const TextStyle(color: Colors.green, fontSize: 11),
                              ),
                            const SizedBox(width: 8),
                            if (widget.speedInfo!.pingTime.isNotEmpty &&
                                !widget.speedInfo!.pingTime.contains('超时'))
                              Text(
                                widget.speedInfo!.pingTime,
                                style: const TextStyle(color: Colors.orange, fontSize: 11),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                // 清晰度标识
                if (widget.speedInfo != null &&
                    widget.speedInfo!.quality.isNotEmpty &&
                    widget.speedInfo!.quality != '未知')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.speedInfo!.quality,
                      style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}