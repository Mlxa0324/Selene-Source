import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/device_utils.dart';

class PlayerEpisodesPanel extends StatefulWidget {
  static const int episodesPerGroup = 50;

  final ThemeData theme;
  final List<String> episodes;
  final List<String> episodesTitles;
  final int currentEpisodeIndex;
  final bool isReversed;
  final Function(int) onEpisodeTap;
  final VoidCallback onToggleOrder;
  final int crossAxisCount; // 最大列数
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
    this.crossAxisCount = 4,
    this.backgroundOpacity,
    this.isCompact = true,
  });

  static EpisodePanelAdaptiveLayout estimateAdaptiveLayout({
    required BuildContext context,
    required List<String> episodes,
    required List<String> episodesTitles,
    required double maxWidth,
    required double maxHeight,
    bool isCompact = true,
    double minWidth = 280,
    double? maxPanelWidth,
  }) {
    final titles = List<String>.generate(episodes.length, (index) {
      if (episodesTitles.isNotEmpty && index < episodesTitles.length) {
        return episodesTitles[index];
      }
      return '第${index + 1}集';
    });

    final sampledTitles = _sampleTitlesForMeasurement(titles);
    final spacing = isCompact ? 8.0 : 12.0;
    const panelHorizontalPadding = 32.0;
    const horizontalPadding = 12.0;
    final verticalPadding = isCompact ? 8.0 : 10.0;
    final textStyle = TextStyle(
      fontSize: isCompact ? 13 : 14,
      fontWeight: FontWeight.w500,
      height: isCompact ? 1.25 : 1.3,
    );
    final textDirection = Directionality.of(context);
    final lineHeight = (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.0);

    double longestTitleWidth = 0;
    for (final title in sampledTitles) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: textStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      longestTitleWidth = math.max(longestTitleWidth, painter.width);
    }

    final panelMaxWidth = math.max(
      minWidth,
      math.min(maxPanelWidth ?? maxWidth, maxWidth),
    );
    final panelMinWidth = math.min(panelMaxWidth, minWidth);
    final targetItemWidth = (longestTitleWidth + horizontalPadding * 2 + 18)
        .clamp(isCompact ? 92.0 : 102.0, isCompact ? 188.0 : 224.0)
        .toDouble();

    int desiredColumns;
    if (titles.length <= 4) {
      desiredColumns = titles.length.clamp(1, 2).toInt();
    } else if (titles.length <= 12) {
      desiredColumns = 3;
    } else if (titles.length <= 28) {
      desiredColumns = 4;
    } else {
      desiredColumns = 5;
    }

    if (longestTitleWidth > 120) {
      desiredColumns = math.max(1, desiredColumns - 1);
    }

    final preferredWidth = math.min(
      panelMaxWidth,
      math.max(
        panelMinWidth,
        panelHorizontalPadding +
            desiredColumns * targetItemWidth +
            math.max(0, desiredColumns - 1) * spacing,
      ),
    );

    final maxColumnsByWidth = math.max(
      1,
      ((preferredWidth - panelHorizontalPadding + spacing) /
              (targetItemWidth + spacing))
          .floor(),
    );
    final maxColumns = math.min(maxColumnsByWidth, 6);
    final itemWidth = math.max(
      64.0,
      (preferredWidth -
              panelHorizontalPadding -
              math.max(0, maxColumns - 1) * spacing) /
          maxColumns,
    );
    final textStats = _measureTitleStats(
      titles: sampledTitles,
      maxTextWidth: math.max(40.0, itemWidth - horizontalPadding * 2),
      style: textStyle,
      textDirection: textDirection,
    );
    final useThreeLines =
        textStats.threeLineRatio > 0.08 || textStats.overflowRatio > 0;
    final displayLines =
        useThreeLines ? 3 : (textStats.multiLineRatio > 0.28 ? 2 : 1);
    final itemExtent = verticalPadding * 2 +
        lineHeight * displayLines +
        (isCompact ? 10.0 : 12.0);
    final visibleCount = math.min(titles.length, episodesPerGroup);
    final rows = math.max(1, (visibleCount / maxColumns).ceil());

    // 根据文本换行和当前分组内的行数，预估一个更贴近内容的弹框高度。
    final estimatedHeight = (isCompact ? 66.0 : 76.0) +
        (titles.length > episodesPerGroup ? 48.0 : 0.0) +
        (isCompact ? 28.0 : 40.0) +
        rows * itemExtent +
        math.max(0, rows - 1) * spacing;

    return EpisodePanelAdaptiveLayout(
      preferredWidth: preferredWidth,
      preferredHeight: estimatedHeight
          .clamp(isCompact ? 220.0 : 260.0, maxHeight)
          .toDouble(),
      maxColumns: maxColumns,
    );
  }

  static List<String> _sampleTitlesForMeasurement(List<String> titles) {
    if (titles.length <= 60) {
      return titles;
    }

    final sorted = List<String>.from(titles)
      ..sort((a, b) => b.length.compareTo(a.length));
    return sorted.take(60).toList();
  }

  static _EpisodeTextStats _measureTitleStats({
    required List<String> titles,
    required double maxTextWidth,
    required TextStyle style,
    required TextDirection textDirection,
  }) {
    if (titles.isEmpty) {
      return const _EpisodeTextStats(
        multiLineRatio: 0,
        threeLineRatio: 0,
        overflowRatio: 0,
      );
    }

    int multiLineCount = 0;
    int threeLineCount = 0;
    int overflowCount = 0;

    for (final title in titles) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: textDirection,
        maxLines: 4,
        ellipsis: '…',
      )..layout(maxWidth: maxTextWidth);

      final lineCount = painter.computeLineMetrics().length;
      if (lineCount > 1) {
        multiLineCount++;
      }
      if (lineCount > 2) {
        threeLineCount++;
      }
      if (lineCount > 3 || painter.didExceedMaxLines) {
        overflowCount++;
      }
    }

    final total = titles.length.toDouble();
    return _EpisodeTextStats(
      multiLineRatio: multiLineCount / total,
      threeLineRatio: threeLineCount / total,
      overflowRatio: overflowCount / total,
    );
  }

  @override
  State<PlayerEpisodesPanel> createState() => _PlayerEpisodesPanelState();
}

class _PlayerEpisodesPanelState extends State<PlayerEpisodesPanel> {
  late final ScrollController _scrollController;
  late final ScrollController _groupScrollController;
  final Map<int, GlobalKey> _episodeItemKeys = <int, GlobalKey>{};

  int _selectedGroupIndex = 0;
  bool _isHoveringGroupPager = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _groupScrollController = ScrollController();

    _updateSelectedGroup();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        _scrollToCurrent();
        _scrollToCurrentGroup();
      });
    });
  }

  int get _currentActualIndex => widget.isReversed
      ? widget.episodes.length - 1 - widget.currentEpisodeIndex
      : widget.currentEpisodeIndex;

  void _updateSelectedGroup() {
    if (widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup) {
      _selectedGroupIndex =
          (_currentActualIndex / PlayerEpisodesPanel.episodesPerGroup).floor();
    } else {
      _selectedGroupIndex = 0;
    }
  }

  @override
  void didUpdateWidget(PlayerEpisodesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisodeIndex != widget.currentEpisodeIndex ||
        oldWidget.isReversed != widget.isReversed ||
        oldWidget.episodes.length != widget.episodes.length) {
      _updateSelectedGroup();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCurrent();
        _scrollToCurrentGroup();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _groupScrollController.dispose();
    super.dispose();
  }

  List<_EpisodePanelEntry> _visibleEntries() {
    final start = widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup
        ? _selectedGroupIndex * PlayerEpisodesPanel.episodesPerGroup
        : 0;
    final end = widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup
        ? math.min(start + PlayerEpisodesPanel.episodesPerGroup,
            widget.episodes.length)
        : widget.episodes.length;

    return List.generate(end - start, (index) {
      final actualIndex = start + index;
      final episodeIndex = widget.isReversed
          ? widget.episodes.length - 1 - actualIndex
          : actualIndex;

      final episodeTitle = (widget.episodesTitles.isNotEmpty &&
              episodeIndex < widget.episodesTitles.length)
          ? widget.episodesTitles[episodeIndex]
          : '第${episodeIndex + 1}集';

      return _EpisodePanelEntry(
        actualIndex: actualIndex,
        episodeIndex: episodeIndex,
        title: episodeTitle,
        isCurrentEpisode: episodeIndex == widget.currentEpisodeIndex,
      );
    });
  }

  GlobalKey _keyForEpisode(int actualIndex) {
    return _episodeItemKeys.putIfAbsent(actualIndex, GlobalKey.new);
  }

  void _scrollToCurrentGroup() {
    if (!_groupScrollController.hasClients ||
        widget.episodes.length <= PlayerEpisodesPanel.episodesPerGroup) {
      return;
    }

    const double approxItemWidth = 85.0;
    final double offset = _selectedGroupIndex * approxItemWidth;

    _groupScrollController.animateTo(
      offset.clamp(0.0, _groupScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _pageScrollGroup(bool forward) {
    if (!_groupScrollController.hasClients) return;

    final position = _groupScrollController.position;
    final page = position.viewportDimension * 0.9;
    final target = (position.pixels + (forward ? page : -page))
        .clamp(0.0, position.maxScrollExtent);

    _groupScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _scrollToCurrent() {
    final groupStart =
        widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup
            ? _selectedGroupIndex * PlayerEpisodesPanel.episodesPerGroup
            : 0;
    final groupEnd =
        widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup
            ? math.min(
                groupStart + PlayerEpisodesPanel.episodesPerGroup,
                widget.episodes.length,
              )
            : widget.episodes.length;

    if (_currentActualIndex < groupStart || _currentActualIndex >= groupEnd) {
      return;
    }

    final targetContext = _episodeItemKeys[_currentActualIndex]?.currentContext;
    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: widget.isCompact ? 0.08 : 0.04,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  _EpisodeGridLayout _resolveGridLayout(
    BuildContext context,
    double maxWidth,
    List<_EpisodePanelEntry> entries,
  ) {
    final double spacing = widget.isCompact ? 8.0 : 12.0;
    final double availableWidth = math.max(120.0, maxWidth - 32.0);
    final int maxColumns = widget.crossAxisCount.clamp(1, 6);
    final int minColumns = availableWidth < 260 ? 1 : 2;
    final TextStyle textStyle = TextStyle(
      fontSize: widget.isCompact ? 13 : 14,
      fontWeight: FontWeight.w500,
      height: widget.isCompact ? 1.25 : 1.3,
    );
    final TextDirection textDirection = Directionality.of(context);
    final double lineHeight =
        (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.0);
    const double horizontalPadding = 12.0;
    final double verticalPadding = widget.isCompact ? 8.0 : 10.0;

    _EpisodeGridLayout? fallbackLayout;

    for (int columns = maxColumns; columns >= minColumns; columns--) {
      final double itemWidth =
          (availableWidth - (columns - 1) * spacing) / columns;
      final _EpisodeTextStats stats = _measureTextStats(
        entries: entries,
        maxTextWidth: math.max(40.0, itemWidth - horizontalPadding * 2),
        style: textStyle,
        textDirection: textDirection,
      );

      final bool useThreeLines =
          stats.threeLineRatio > 0.08 || stats.overflowRatio > 0.0;
      final int displayLines =
          useThreeLines ? 3 : (stats.multiLineRatio > 0.28 ? 2 : 1);
      final double itemExtent = verticalPadding * 2 +
          lineHeight * displayLines +
          (widget.isCompact ? 10.0 : 12.0);

      fallbackLayout ??= _EpisodeGridLayout(
        crossAxisCount: columns,
        spacing: spacing,
        itemExtent: itemExtent,
        maxLines: displayLines,
        textStyle: textStyle,
        horizontalPadding: horizontalPadding,
        verticalPadding: verticalPadding,
      );

      final bool fitsWell =
          stats.overflowRatio <= 0.1 && stats.threeLineRatio <= 0.24;
      if (fitsWell) {
        return _EpisodeGridLayout(
          crossAxisCount: columns,
          spacing: spacing,
          itemExtent: itemExtent,
          maxLines: displayLines,
          textStyle: textStyle,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
        );
      }
    }

    return fallbackLayout ??
        _EpisodeGridLayout(
          crossAxisCount: 1,
          spacing: spacing,
          itemExtent: verticalPadding * 2 + lineHeight + 12,
          maxLines: 1,
          textStyle: textStyle,
          horizontalPadding: horizontalPadding,
          verticalPadding: verticalPadding,
        );
  }

  _EpisodeTextStats _measureTextStats({
    required List<_EpisodePanelEntry> entries,
    required double maxTextWidth,
    required TextStyle style,
    required TextDirection textDirection,
  }) {
    if (entries.isEmpty) {
      return const _EpisodeTextStats(
        multiLineRatio: 0,
        threeLineRatio: 0,
        overflowRatio: 0,
      );
    }

    int multiLineCount = 0;
    int threeLineCount = 0;
    int overflowCount = 0;

    for (final entry in entries) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: entry.title, style: style),
        textDirection: textDirection,
        maxLines: 4,
        ellipsis: '…',
      )..layout(maxWidth: maxTextWidth);

      final int lineCount = painter.computeLineMetrics().length;
      if (lineCount > 1) {
        multiLineCount++;
      }
      if (lineCount > 2) {
        threeLineCount++;
      }
      if (lineCount > 3 || painter.didExceedMaxLines) {
        overflowCount++;
      }
    }

    final double total = entries.length.toDouble();
    return _EpisodeTextStats(
      multiLineRatio: multiLineCount / total,
      threeLineRatio: threeLineCount / total,
      overflowRatio: overflowCount / total,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final opacity = widget.backgroundOpacity ?? (isDarkMode ? 0.85 : 0.95);
    final backgroundColor = isDarkMode
        ? Colors.black.withValues(alpha: opacity)
        : Colors.white.withValues(alpha: opacity);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final visibleEntries = _visibleEntries();

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.isCompact
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              )
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              widget.isCompact ? 16 : 20,
              8,
              widget.isCompact ? 8 : 12,
            ),
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
          if (widget.episodes.length > PlayerEpisodesPanel.episodesPerGroup)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: MouseRegion(
                onEnter: (_) {
                  if (DeviceUtils.isPC()) {
                    setState(() => _isHoveringGroupPager = true);
                  }
                },
                onExit: (_) {
                  if (DeviceUtils.isPC()) {
                    setState(() => _isHoveringGroupPager = false);
                  }
                },
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _groupScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (widget.episodes.length /
                              PlayerEpisodesPanel.episodesPerGroup)
                          .ceil(),
                      itemBuilder: (context, index) {
                        final start =
                            index * PlayerEpisodesPanel.episodesPerGroup + 1;
                        final end =
                            ((index + 1) * PlayerEpisodesPanel.episodesPerGroup)
                                .clamp(0, widget.episodes.length);
                        final isSelected = _selectedGroupIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$start-$end'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _selectedGroupIndex = index;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted || !_scrollController.hasClients) {
                                  return;
                                }

                                final currentGroup = (_currentActualIndex /
                                        PlayerEpisodesPanel.episodesPerGroup)
                                    .floor();
                                if (index == currentGroup) {
                                  _scrollToCurrent();
                                } else {
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                              });
                            },
                            selectedColor: Colors.green.withValues(alpha: 0.2),
                            backgroundColor: isDarkMode
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.green
                                  : textColor.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      },
                    ),
                    if (DeviceUtils.isPC() &&
                        _isHoveringGroupPager &&
                        _groupScrollController.hasClients &&
                        _groupScrollController.position.maxScrollExtent > 0)
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _GroupPagerButton(
                                isLeft: true,
                                isDarkMode: isDarkMode,
                                onTap: () => _pageScrollGroup(false),
                              ),
                              _GroupPagerButton(
                                isLeft: false,
                                isDarkMode: isDarkMode,
                                onTap: () => _pageScrollGroup(true),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _resolveGridLayout(
                    context, constraints.maxWidth, visibleEntries);

                return SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      widget.isCompact ? 16 : 24,
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.crossAxisCount,
                          crossAxisSpacing: layout.spacing,
                          mainAxisSpacing: layout.spacing,
                          mainAxisExtent: layout.itemExtent,
                        ),
                        children: visibleEntries.map((entry) {
                          return KeyedSubtree(
                            key: _keyForEpisode(entry.actualIndex),
                            child: _EpisodePanelItemWithHover(
                              isCurrentEpisode: entry.isCurrentEpisode,
                              isDarkMode: isDarkMode,
                              episodeTitle: entry.title,
                              isCompact: widget.isCompact,
                              maxLines: layout.maxLines,
                              textStyle: layout.textStyle,
                              horizontalPadding: layout.horizontalPadding,
                              verticalPadding: layout.verticalPadding,
                              onTap: entry.isCurrentEpisode
                                  ? null
                                  : () =>
                                      widget.onEpisodeTap(entry.episodeIndex),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPagerButton extends StatelessWidget {
  final bool isLeft;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _GroupPagerButton({
    required this.isLeft,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.9);
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

class _EpisodePanelItemWithHover extends StatefulWidget {
  final bool isCurrentEpisode;
  final bool isDarkMode;
  final String episodeTitle;
  final bool isCompact;
  final int maxLines;
  final TextStyle textStyle;
  final double horizontalPadding;
  final double verticalPadding;
  final VoidCallback? onTap;

  const _EpisodePanelItemWithHover({
    required this.isCurrentEpisode,
    required this.isDarkMode,
    required this.episodeTitle,
    required this.isCompact,
    required this.maxLines,
    required this.textStyle,
    required this.horizontalPadding,
    required this.verticalPadding,
    this.onTap,
  });

  @override
  State<_EpisodePanelItemWithHover> createState() =>
      _EpisodePanelItemWithHoverState();
}

class _EpisodePanelItemWithHoverState
    extends State<_EpisodePanelItemWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.isCurrentEpisode
        ? Colors.green
        : (widget.isDarkMode ? Colors.white70 : Colors.black87);

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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isCurrentEpisode
                ? Colors.green.withValues(alpha: 0.2)
                : (_isHovering && DeviceUtils.isPC()
                    ? (widget.isDarkMode
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05))
                    : (widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03))),
            borderRadius: BorderRadius.circular(10),
            border: widget.isCurrentEpisode
                ? Border.all(color: Colors.green, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontalPadding,
              vertical: widget.verticalPadding,
            ),
            child: Text(
              widget.episodeTitle,
              textAlign: TextAlign.center,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis,
              style: widget.textStyle.copyWith(
                color: textColor,
                fontWeight: widget.isCurrentEpisode
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodePanelEntry {
  final int actualIndex;
  final int episodeIndex;
  final String title;
  final bool isCurrentEpisode;

  const _EpisodePanelEntry({
    required this.actualIndex,
    required this.episodeIndex,
    required this.title,
    required this.isCurrentEpisode,
  });
}

class _EpisodeGridLayout {
  final int crossAxisCount;
  final double spacing;
  final double itemExtent;
  final int maxLines;
  final TextStyle textStyle;
  final double horizontalPadding;
  final double verticalPadding;

  const _EpisodeGridLayout({
    required this.crossAxisCount,
    required this.spacing,
    required this.itemExtent,
    required this.maxLines,
    required this.textStyle,
    required this.horizontalPadding,
    required this.verticalPadding,
  });
}

class _EpisodeTextStats {
  final double multiLineRatio;
  final double threeLineRatio;
  final double overflowRatio;

  const _EpisodeTextStats({
    required this.multiLineRatio,
    required this.threeLineRatio,
    required this.overflowRatio,
  });
}

class EpisodePanelAdaptiveLayout {
  final double preferredWidth;
  final double preferredHeight;
  final int maxColumns;

  const EpisodePanelAdaptiveLayout({
    required this.preferredWidth,
    required this.preferredHeight,
    required this.maxColumns,
  });
}
