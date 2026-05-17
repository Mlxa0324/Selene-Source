import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/theme_service.dart';
import '../utils/device_utils.dart';

class PlayerEpisodesPanel extends StatefulWidget {
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
    this.crossAxisCount = 3,
    this.backgroundOpacity,
    this.isCompact = true,
  });

  @override
  State<PlayerEpisodesPanel> createState() => _PlayerEpisodesPanelState();
}

class _PlayerEpisodesPanelState extends State<PlayerEpisodesPanel> {
  static const int _episodesPerGroup = 50;

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
    if (widget.episodes.length > _episodesPerGroup) {
      _selectedGroupIndex = (_currentActualIndex / _episodesPerGroup).floor();
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
    final start = widget.episodes.length > _episodesPerGroup
        ? _selectedGroupIndex * _episodesPerGroup
        : 0;
    final end = widget.episodes.length > _episodesPerGroup
        ? math.min(start + _episodesPerGroup, widget.episodes.length)
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
        widget.episodes.length <= _episodesPerGroup) {
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
    final groupStart = widget.episodes.length > _episodesPerGroup
        ? _selectedGroupIndex * _episodesPerGroup
        : 0;
    final groupEnd = widget.episodes.length > _episodesPerGroup
        ? math.min(groupStart + _episodesPerGroup, widget.episodes.length)
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
    final int maxColumns = widget.crossAxisCount.clamp(1, 5);
    final int minColumns = availableWidth < 260 ? 1 : 2;
    final TextStyle textStyle = TextStyle(
      fontSize: widget.isCompact ? 13 : 14,
      fontWeight: FontWeight.w500,
      height: widget.isCompact ? 1.25 : 1.3,
    );
    final TextDirection textDirection = Directionality.of(context);
    final double lineHeight =
        (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.0);
    final itemPadding = resolveEpisodeItemPadding(
      isCompact: widget.isCompact,
      lineCount: 1,
    );
    final double horizontalPadding = itemPadding.horizontal;

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
      final double verticalPadding = resolveEpisodeItemPadding(
        isCompact: widget.isCompact,
        lineCount: displayLines,
      ).vertical;
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
        (() {
          final fallbackVerticalPadding = resolveEpisodeItemPadding(
            isCompact: widget.isCompact,
            lineCount: 1,
          ).vertical;
          return _EpisodeGridLayout(
            crossAxisCount: 1,
            spacing: spacing,
            itemExtent: fallbackVerticalPadding * 2 + lineHeight + 12,
            maxLines: 1,
            textStyle: textStyle,
            horizontalPadding: horizontalPadding,
            verticalPadding: fallbackVerticalPadding,
          );
        })();
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
    final themeService = context.watch<ThemeService>();
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
              widget.isCompact ? 10 : 26,
              8,
              widget.isCompact ? 4 : 18,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选集 (${widget.episodes.length})',
                  style: TextStyle(
                    color: textColor,
                    fontSize: widget.isCompact ? 16 : 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  visualDensity:
                      widget.isCompact ? VisualDensity.compact : null,
                  icon: Icon(Icons.close, color: textColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (widget.episodes.length > _episodesPerGroup)
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
                      itemCount:
                          (widget.episodes.length / _episodesPerGroup).ceil(),
                      itemBuilder: (context, index) {
                        final start = index * _episodesPerGroup + 1;
                        final end = ((index + 1) * _episodesPerGroup)
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

                                final currentGroup =
                                    (_currentActualIndex / _episodesPerGroup)
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
                            selectedColor: themeService.accentWithAlpha(0.2),
                            backgroundColor: isDarkMode
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? themeService.accentColor
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
                                    ? themeService.accentColor
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
                      widget.isCompact ? 18 : 20,
                      16,
                      widget.isCompact ? 24 : 32,
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

@visibleForTesting
({double horizontal, double vertical}) resolveEpisodeItemPadding({
  required bool isCompact,
  int lineCount = 1,
}) {
  final normalizedLineCount = lineCount.clamp(1, 3);
  return (
    horizontal: 6.0,
    vertical: switch ((isCompact, normalizedLineCount)) {
      (true, 1) => 8.0,
      (true, 2) => 6.0,
      (true, _) => 5.0,
      (false, 1) => 8.0,
      (false, 2) => 6.0,
      (false, _) => 5.0,
    },
  );
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
    final themeService = context.watch<ThemeService>();
    final accentColor = themeService.accentColor;
    final selectedSurface = widget.isDarkMode
        ? accentColor.withValues(alpha: 0.14)
        : Color.lerp(Colors.white, accentColor, 0.04)!;
    final selectedBorder = widget.isDarkMode
        ? accentColor.withValues(alpha: 0.48)
        : Color.lerp(Colors.white, accentColor, 0.42)!;
    final hoverSurface = widget.isDarkMode
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFF8FAFC);
    final idleSurface = widget.isDarkMode
        ? Colors.white12
        : Colors.white.withValues(alpha: 0.88);
    final Color textColor = widget.isCurrentEpisode
        ? accentColor
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
                ? selectedSurface
                : (_isHovering && DeviceUtils.isPC()
                    ? hoverSurface
                    : idleSurface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isCurrentEpisode
                  ? selectedBorder
                  : (widget.isDarkMode
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE7ECF2)),
              width: widget.isCurrentEpisode ? 1.1 : 0.9,
            ),
            boxShadow: widget.isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
