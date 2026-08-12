import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/search_result.dart';
import '../utils/device_utils.dart';
import '../utils/font_utils.dart';

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
  final double? backgroundOpacity;
  final bool isCompact;

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
    this.backgroundOpacity,
    this.isCompact = true,
  });

  /// 按 `episodes.length` 倒序稳定排序。Dart 的 `sort` 不是稳定排序,
  /// 因此用 `index` 作为次序兜底,保证同集数源的相对顺序与传入顺序一致。
  @visibleForTesting
  static List<SearchResult> computeSortedSourcesForTest(
      List<SearchResult> sources) {
    final indexed = sources.asMap().entries.toList();
    indexed.sort((a, b) {
      final cmp = b.value.episodes.length.compareTo(a.value.episodes.length);
      if (cmp != 0) return cmp;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  @override
  State<PlayerSourcesPanel> createState() => _PlayerSourcesPanelState();
}

class _PlayerSourcesPanelState extends State<PlayerSourcesPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isRefreshing = false;
  late ScrollController _scrollController;
  bool _isHoveringPager = false;

  /// 按 `episodes.length` 倒序的稳定排序结果。所有 build 遍历都基于此列表,
  /// 保证换源弹框(全屏 / 非全屏 / 短剧)统一按集数多的优先展示。
  late List<SearchResult> _sortedSources;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scrollController = ScrollController();
    _sortedSources = _computeSortedSources(widget.sources);

    // 延迟滚动到当前源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSource();
    });
  }

  @override
  void didUpdateWidget(covariant PlayerSourcesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sources, widget.sources)) {
      _sortedSources = _computeSortedSources(widget.sources);
    }
  }

  /// 按 `episodes.length` 倒序稳定排序。委托给 `PlayerSourcesPanel.computeSortedSourcesForTest`,
  /// 便于测试覆盖同一份排序逻辑。
  List<SearchResult> _computeSortedSources(List<SearchResult> sources) {
    return PlayerSourcesPanel.computeSortedSourcesForTest(sources);
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
    final currentIndex = _sortedSources.indexWhere((source) =>
        source.source == widget.currentSource && source.id == widget.currentId);

    if (currentIndex == -1) return;

    // 计算每个项目的高度
    final itemHeight = widget.isCompact ? 84.0 : 100.0;
    final itemSpacing = widget.isCompact ? 8.0 : 12.0;
    final totalItemHeight = itemHeight + itemSpacing;

    final targetOffset = currentIndex * totalItemHeight;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _pageScrollList(bool forward) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final page = position.viewportDimension * 0.9;
    final target = (position.pixels + (forward ? page : -page))
        .clamp(0.0, position.maxScrollExtent);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
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
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, widget.isCompact ? 10 : 20, 8, widget.isCompact ? 4 : 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '换源 (${_sortedSources.length})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.isCompact ? 16 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity:
                          widget.isCompact ? VisualDensity.compact : null,
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
                      visualDensity:
                          widget.isCompact ? VisualDensity.compact : null,
                      icon: Icon(Icons.close, color: textColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MouseRegion(
              onEnter: (_) {
                if (DeviceUtils.isPC()) {
                  setState(() => _isHoveringPager = true);
                }
              },
              onExit: (_) {
                if (DeviceUtils.isPC()) {
                  setState(() => _isHoveringPager = false);
                }
              },
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                        16, 4, 16, widget.isCompact ? 16 : 24),
                    itemCount: _sortedSources.length,
                    itemBuilder: (context, index) {
                      final source = _sortedSources[index];
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
                        isCompact: widget.isCompact,
                        onTap:
                            isCurrent ? null : () => widget.onSourceTap(source),
                      );
                    },
                  ),
                  if (DeviceUtils.isPC() &&
                      _isHoveringPager &&
                      _scrollController.hasClients &&
                      _scrollController.position.maxScrollExtent > 0)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ListPagerButton(
                              isLeft: true,
                              isDarkMode: isDarkMode,
                              onTap: () => _pageScrollList(false),
                            ),
                            _ListPagerButton(
                              isLeft: false,
                              isDarkMode: isDarkMode,
                              onTap: () => _pageScrollList(true),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
  final bool isCompact;
  final VoidCallback? onTap;

  const _SourcePanelItemWithHover({
    required this.isCurrent,
    required this.isDarkMode,
    required this.source,
    this.speedInfo,
    required this.theme,
    required this.isCompact,
    this.onTap,
  });

  @override
  State<_SourcePanelItemWithHover> createState() =>
      _SourcePanelItemWithHoverState();
}

class _ListPagerButton extends StatelessWidget {
  final bool isLeft;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ListPagerButton({
    required this.isLeft,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.9);
    final borderColor = isDarkMode ? Colors.white24 : Colors.black12;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;

    return MouseRegion(
      cursor: DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            isLeft ? Icons.chevron_left : Icons.chevron_right,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _SourcePanelItemWithHoverState extends State<_SourcePanelItemWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final itemHeight = widget.isCompact ? 84.0 : 100.0;

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
          margin: EdgeInsets.only(bottom: widget.isCompact ? 8 : 12),
          height: itemHeight,
          decoration: BoxDecoration(
            color: widget.isCurrent
                ? Colors.green.withOpacity(0.1)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode
                        ? Colors.white10
                        : Colors.black.withOpacity(0.05))
                    : (widget.isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03))),
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
                        color:
                            widget.isDarkMode ? Colors.white10 : Colors.black12,
                        child: Icon(Icons.movie,
                            size: widget.isCompact ? 20 : 24,
                            color: Colors.grey),
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
                        maxLines: widget.isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: widget.isCompact ? 14 : 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            widget.source.sourceName,
                            style: FontUtils.poppins(
                              color: textColor.withOpacity(0.6),
                              fontSize: widget.isCompact ? 12 : 13,
                            ),
                          ),
                          if (widget.source.episodes.length > 1) ...[
                            Text(' • ',
                                style: TextStyle(
                                    color: textColor.withOpacity(0.3))),
                            Text(
                              '${widget.source.episodes.length}集',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: widget.isCompact ? 12 : 13,
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
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: widget.isCompact ? 11 : 12),
                              ),
                            const SizedBox(width: 8),
                            if (widget.speedInfo!.pingTime.isNotEmpty &&
                                !widget.speedInfo!.pingTime.contains('超时'))
                              Text(
                                widget.speedInfo!.pingTime,
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: widget.isCompact ? 11 : 12),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.speedInfo!.quality,
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: widget.isCompact ? 10 : 11,
                          fontWeight: FontWeight.bold),
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
