import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';
import 'package:provider/provider.dart';
import '../screens/download_screen.dart';
import '../utils/device_utils.dart';

const double _compactChildAspectRatioPC = 2.0;
const double _compactChildAspectRatioDefault = 3.2;
const double _normalChildAspectRatio = 2.0;
const double _maxEpisodeGridCardWidth = 150.0;
const double _episodeGridSpacing = 8.0;
const double _episodeGridHorizontalPadding = 24.0;
const double _tabletEpisodeMinWidth = 168.0;
const double _tabletEpisodeMaxWidth = 220.0;
const double _tabletEpisodeMinHeight = 80.0;
const double _tabletEpisodeMaxHeight = 96.0;
const EdgeInsets _defaultEpisodeTitlePadding =
    EdgeInsets.symmetric(horizontal: 4);
const EdgeInsets _tabletEpisodeTitlePadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const TextStyle _episodeTitleMeasureStyle =
    TextStyle(fontSize: 13, height: 1.22);

@immutable
class PlayerDownloadGridLayout {
  const PlayerDownloadGridLayout({
    required this.crossAxisCount,
    required this.titleMaxLines,
    required this.titlePadding,
    this.childAspectRatio,
    this.mainAxisExtent,
  });

  final int crossAxisCount;
  final double? childAspectRatio;
  final double? mainAxisExtent;
  final int titleMaxLines;
  final EdgeInsets titlePadding;

  bool get usesMainAxisExtent => mainAxisExtent != null;
}

@visibleForTesting
PlayerDownloadGridLayout resolvePlayerDownloadGridLayout({
  required double gridWidth,
  required bool isTablet,
  required bool isPC,
  required bool isCompact,
  required List<String> titles,
  required TextDirection textDirection,
}) {
  final defaultCrossAxisCount = _resolveDefaultEpisodeGridCrossAxisCount(
    gridWidth,
    isCompact: isCompact,
  );
  final defaultChildAspectRatio = isCompact
      ? (isPC ? _compactChildAspectRatioPC : _compactChildAspectRatioDefault)
      : _normalChildAspectRatio;

  if (!(isCompact && isTablet && !isPC)) {
    return PlayerDownloadGridLayout(
      crossAxisCount: defaultCrossAxisCount,
      childAspectRatio: defaultChildAspectRatio,
      titleMaxLines: 2,
      titlePadding: _defaultEpisodeTitlePadding,
    );
  }

  final usableWidth = math.max(0.0, gridWidth - _episodeGridHorizontalPadding);
  if (usableWidth <= 0) {
    return PlayerDownloadGridLayout(
      crossAxisCount: defaultCrossAxisCount,
      childAspectRatio: defaultChildAspectRatio,
      titleMaxLines: 2,
      titlePadding: _defaultEpisodeTitlePadding,
    );
  }

  final safeTitles = titles
      .map((title) => title.trim())
      .where((title) => title.isNotEmpty)
      .toList(growable: false);

  final requiredContentWidth = safeTitles.fold<double>(
    0.0,
    (current, title) {
      final measuredWidth = _measureRequiredEpisodeTitleWidthForLines(
        title,
        textDirection: textDirection,
        maxLines: 3,
      );
      return math.max(current, measuredWidth);
    },
  );

  final desiredCardWidth =
      (requiredContentWidth + _tabletEpisodeTitlePadding.horizontal + 18)
          .clamp(_tabletEpisodeMinWidth, _tabletEpisodeMaxWidth);
  final minCrossAxisCount = usableWidth >= 360 ? 3 : 2;
  final rawCrossAxisCount = ((usableWidth + _episodeGridSpacing) /
          (desiredCardWidth + _episodeGridSpacing))
      .floor();
  final crossAxisCount = rawCrossAxisCount.clamp(minCrossAxisCount, 4).toInt();
  final actualCardWidth =
      (usableWidth - (crossAxisCount - 1) * _episodeGridSpacing) /
          crossAxisCount;
  final contentWidth = math.max(
      48.0, actualCardWidth - _tabletEpisodeTitlePadding.horizontal - 18);

  final maxTextHeight = safeTitles.fold<double>(
    0.0,
    (current, title) => math.max(
      current,
      _measureEpisodeTitleWrappedHeight(
        title,
        maxWidth: contentWidth,
        textDirection: textDirection,
        maxLines: 3,
      ),
    ),
  );

  final mainAxisExtent =
      (maxTextHeight + _tabletEpisodeTitlePadding.vertical + 26)
          .clamp(_tabletEpisodeMinHeight, _tabletEpisodeMaxHeight)
          .toDouble();

  return PlayerDownloadGridLayout(
    crossAxisCount: crossAxisCount,
    mainAxisExtent: mainAxisExtent,
    titleMaxLines: 3,
    titlePadding: _tabletEpisodeTitlePadding,
  );
}

int _resolveDefaultEpisodeGridCrossAxisCount(
  double gridWidth, {
  required bool isCompact,
}) {
  final baseCount = isCompact ? 4 : 3;
  final usableWidth = math.max(0.0, gridWidth - _episodeGridHorizontalPadding);
  final dynamicCount = ((usableWidth + _episodeGridSpacing) /
          (_maxEpisodeGridCardWidth + _episodeGridSpacing))
      .floor();
  return math.max(baseCount, math.max(1, dynamicCount));
}

double _measureRequiredEpisodeTitleWidthForLines(
  String title, {
  required TextDirection textDirection,
  required int maxLines,
}) {
  double low = 36.0;
  double high = _tabletEpisodeMaxWidth;

  while (high - low > 1) {
    final mid = (low + high) / 2;
    if (_doesEpisodeTitleFitWithinLines(
      title,
      maxWidth: mid,
      textDirection: textDirection,
      maxLines: maxLines,
    )) {
      high = mid;
    } else {
      low = mid;
    }
  }

  return high;
}

double _measureEpisodeTitleWrappedHeight(
  String title, {
  required double maxWidth,
  required TextDirection textDirection,
  required int maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: _episodeTitleMeasureStyle),
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  return painter.height;
}

bool _doesEpisodeTitleFitWithinLines(
  String title, {
  required double maxWidth,
  required TextDirection textDirection,
  required int maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: _episodeTitleMeasureStyle),
    textDirection: textDirection,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines;
}

class PlayerDownloadPanel extends StatefulWidget {
  final ThemeData theme;
  final String title;
  final String cover;
  final List<String> episodes;
  final List<String> episodesTitles;
  final int? currentEpisodeIndex; // 💡 新增：当前播放集数索引
  final bool isCompact;

  const PlayerDownloadPanel({
    super.key,
    required this.theme,
    required this.title,
    required this.cover,
    required this.episodes,
    required this.episodesTitles,
    this.currentEpisodeIndex,
    this.isCompact = true,
  });

  @override
  State<PlayerDownloadPanel> createState() => _PlayerDownloadPanelState();
}

class _PlayerDownloadPanelState extends State<PlayerDownloadPanel>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  int _selectedGroupIndex = 0;
  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController(); // 集数网格滚动
  final ScrollController _groupScrollController =
      ScrollController(); // 💡 分组列表滚动
  final GlobalKey _gridKey = GlobalKey();
  bool _isHoveringGroupPager = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // 💡 初始化选中分组：如果当前播放集在 50 集以后，自动切换分组
    if (widget.currentEpisodeIndex != null && widget.episodes.length > 50) {
      _selectedGroupIndex = (widget.currentEpisodeIndex! / 50).floor();
    }

    // 💡 自动滚动到当前集
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToCurrent();
        _scrollToActiveGroup(); // 💡 同时定位分组列表
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    _groupScrollController.dispose(); // 💡 释放分组控制器
    super.dispose();
  }

  // 💡 定位到当前激活的分组
  void _scrollToActiveGroup() {
    if (!_groupScrollController.hasClients || widget.episodes.length <= 50) {
      return;
    }

    // 估算每个 ChoiceChip 的平均宽度（Label + Padding）约 85px
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

  // 💡 滚动到当前播放集逻辑
  void _scrollToCurrent() {
    if (widget.currentEpisodeIndex == null ||
        _gridKey.currentContext == null ||
        !_scrollController.hasClients) {
      return;
    }

    // 检查当前播放集是否在当前显示的分组内
    final startOfGroup = _selectedGroupIndex * 50;
    final endOfGroup =
        ((_selectedGroupIndex + 1) * 50).clamp(0, widget.episodes.length);

    if (widget.currentEpisodeIndex! < startOfGroup ||
        widget.currentEpisodeIndex! >= endOfGroup) {
      return;
    }

    final physicalIndexInGrid = widget.currentEpisodeIndex! - startOfGroup;

    final RenderBox gridBox =
        _gridKey.currentContext!.findRenderObject() as RenderBox;
    final gridLayout = resolvePlayerDownloadGridLayout(
      gridWidth: gridBox.size.width,
      isTablet: DeviceUtils.isTablet(context),
      isPC: DeviceUtils.isPC(),
      isCompact: widget.isCompact,
      titles: _visibleEpisodeTitles(),
      textDirection:
          Directionality.maybeOf(_gridKey.currentContext!) ?? TextDirection.ltr,
    );
    const mainAxisSpacing = _episodeGridSpacing;
    const crossAxisSpacing = _episodeGridSpacing;
    const horizontalPadding = _episodeGridHorizontalPadding;

    // 计算宽度和高度（需要减去横向 padding 24，因为左右各 12）
    final itemWidth = (gridBox.size.width -
            horizontalPadding -
            (gridLayout.crossAxisCount - 1) * crossAxisSpacing) /
        gridLayout.crossAxisCount;
    final itemHeight = gridLayout.usesMainAxisExtent
        ? gridLayout.mainAxisExtent!
        : itemWidth / gridLayout.childAspectRatio!;

    final row = (physicalIndexInGrid / gridLayout.crossAxisCount).floor();
    final offset = row * (itemHeight + mainAxisSpacing);

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _episodeTitleAt(int index) {
    if (widget.episodesTitles.isNotEmpty &&
        index >= 0 &&
        index < widget.episodesTitles.length) {
      return widget.episodesTitles[index];
    }
    return '第${index + 1}集';
  }

  List<String> _visibleEpisodeTitles() {
    final startIndex = _isGrouped ? _groupStartIndex : 0;
    final endIndex = _isGrouped ? _groupEndIndex : widget.episodes.length;
    return List<String>.generate(
      endIndex - startIndex,
      (offset) => _episodeTitleAt(startIndex + offset),
    );
  }

  Widget _buildDownloadingAnimation() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        // 防御性检查：确保控制器已初始化
        if (!mounted) return const SizedBox.shrink();

        double animValue = 0;
        try {
          animValue = _animController.value;
        } catch (_) {
          return const Icon(
            Icons.keyboard_double_arrow_down,
            color: Colors.green,
            size: 20,
          );
        }

        return Transform.translate(
          offset: Offset(0, 3 * animValue),
          child: Opacity(
            opacity: 1.0 - animValue,
            child: const Icon(
              Icons.keyboard_double_arrow_down,
              color: Colors.green,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  bool get _isGrouped => widget.episodes.length > 50;

  int get _groupStartIndex => _selectedGroupIndex * 50;

  int get _groupEndIndex =>
      ((_selectedGroupIndex + 1) * 50).clamp(0, widget.episodes.length);

  Iterable<int> get _currentGroupIndices =>
      Iterable<int>.generate(_groupEndIndex - _groupStartIndex)
          .map((i) => _groupStartIndex + i);

  bool get _isCurrentGroupAllSelected {
    if (!_isGrouped) {
      return _selectedIndices.length == widget.episodes.length;
    }
    for (final index in _currentGroupIndices) {
      if (!_selectedIndices.contains(index)) {
        return false;
      }
    }
    return true;
  }

  void _selectAll() {
    setState(() {
      if (_isGrouped) {
        if (_isCurrentGroupAllSelected) {
          _selectedIndices.removeWhere(
              (index) => index >= _groupStartIndex && index < _groupEndIndex);
        } else {
          _selectedIndices.addAll(_currentGroupIndices);
        }
      } else {
        if (_selectedIndices.length == widget.episodes.length) {
          _selectedIndices.clear();
        } else {
          _selectedIndices.addAll(Iterable.generate(widget.episodes.length));
        }
      }
    });
  }

  Future<void> _startDownload() async {
    if (_selectedIndices.isEmpty) return;

    debugPrint(
        "开始下载任务: 标题=${widget.title}, 选中集数=${_selectedIndices.toList()}, 地址=${_selectedIndices.map((i) => widget.episodes[i]).toList()}");

    final downloadService = context.read<DownloadService>();
    final appDir = await getApplicationDocumentsDirectory();

    for (var index in _selectedIndices) {
      final episodeUrl = widget.episodes[index];
      String subtitle = '';
      if (widget.episodesTitles.isNotEmpty &&
          index < widget.episodesTitles.length) {
        subtitle = widget.episodesTitles[index];
      } else {
        subtitle = '第${index + 1}集';
      }

      final taskId = '${widget.title}_$subtitle'.hashCode.toString();
      final savePath = "${appDir.path}/downloads/${widget.title}/$subtitle";

      final task = DownloadTask(
        id: taskId,
        url: episodeUrl,
        title: widget.title,
        subtitle: subtitle,
        episodeIndex: index, // 记录原始索引
        cover: widget.cover,
        savePath: savePath,
        createdAt: DateTime.now(),
      );

      await downloadService.addTask(task);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已添加 ${_selectedIndices.length} 个下载任务")),
      );
      // Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.isCompact
            ? const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              )
            : const BorderRadius.vertical(
                top: Radius.circular(24)), // 💡 竖屏底部弹窗显示完整的顶部圆角
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: EdgeInsets.fromLTRB(20, widget.isCompact ? 16 : 20, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '缓存选集 (${widget.episodes.length})',
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

          // 分组选择器
          if (widget.episodes.length > 50)
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
                      itemCount: (widget.episodes.length / 50).ceil(),
                      itemBuilder: (context, index) {
                        final start = index * 50 + 1;
                        final end =
                            ((index + 1) * 50).clamp(0, widget.episodes.length);
                        final isSelected = _selectedGroupIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$start-$end'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedGroupIndex = index;
                                });
                              }
                            },
                            selectedColor: Colors.green.withOpacity(0.2),
                            backgroundColor: isDarkMode
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.green
                                  : textColor.withOpacity(0.7),
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

          // 集数选择列表
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridLayout = resolvePlayerDownloadGridLayout(
                  gridWidth: constraints.maxWidth,
                  isTablet: DeviceUtils.isTablet(context),
                  isPC: DeviceUtils.isPC(),
                  isCompact: widget.isCompact,
                  titles: _visibleEpisodeTitles(),
                  textDirection: Directionality.of(context),
                );
                final gridDelegate = gridLayout.usesMainAxisExtent
                    ? SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridLayout.crossAxisCount,
                        crossAxisSpacing: _episodeGridSpacing,
                        mainAxisSpacing: _episodeGridSpacing,
                        mainAxisExtent: gridLayout.mainAxisExtent,
                      )
                    : SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridLayout.crossAxisCount,
                        crossAxisSpacing: _episodeGridSpacing,
                        mainAxisSpacing: _episodeGridSpacing,
                        childAspectRatio: gridLayout.childAspectRatio!,
                      );

                return GridView.builder(
                  key: _gridKey,
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  gridDelegate: gridDelegate,
                  itemCount: _isGrouped
                      ? (_groupEndIndex - _groupStartIndex)
                      : widget.episodes.length,
                  itemBuilder: (context, index) {
                    final actualIndex = (widget.episodes.length > 50)
                        ? (_selectedGroupIndex * 50 + index)
                        : index;

                    final downloadService = context.watch<DownloadService>();
                    final isSelected = _selectedIndices.contains(actualIndex);
                    // 💡 新增：是否是当前播放集
                    final isCurrentPlaying =
                        actualIndex == widget.currentEpisodeIndex;

                    final title = _episodeTitleAt(actualIndex);

                    // 判断状态

                    final taskId = "${widget.title}_$title".hashCode.toString();

                    final task = downloadService.tasks.firstWhere(
                      (t) => t.id == taskId,
                      orElse: () => DownloadTask(
                        id: '',
                        url: '',
                        title: '',
                        subtitle: '',
                        episodeIndex: 0,
                        cover: '',
                        savePath: '',
                        createdAt: DateTime.now(),
                      ),
                    );

                    final isDownloaded = task.id.isNotEmpty &&
                        task.status == DownloadStatus.completed;

                    final isDownloading = task.id.isNotEmpty &&
                        task.status == DownloadStatus.downloading;

                    final bool isInQueue = task.id.isNotEmpty &&
                        task.status != DownloadStatus.completed;

                    // 只要是正在下载、已下载或者用户当前勾选的，都显示选中样式

                    final bool isEffectivelySelected =
                        isSelected || isDownloaded || isInQueue;

                    return GestureDetector(
                      onTap: () {
                        if (isDownloaded) {
                          // 已经下载完成：弹出删除确认
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除缓存'),
                              content: Text('确定要删除 "$title" 的本地缓存吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndices.remove(actualIndex);
                                    });
                                    downloadService.deleteTask(taskId);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('删除',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        } else if (isInQueue) {
                          // 正在下载或排队中：弹出取消下载确认
                          final int progress = (task.progress * 100).toInt();

                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('取消下载'),
                              content: Text('该视频已下载 $progress%，是否取消下载？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('继续下载'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedIndices.remove(actualIndex);
                                    });
                                    downloadService.deleteTask(taskId);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('取消下载',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        } else {
                          _toggleSelection(actualIndex);
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              // 💡 优化：手动选中颜色正常，仅播放颜色变淡
                              color: isEffectivelySelected
                                  ? Colors.green.withOpacity(0.2)
                                  : (isCurrentPlaying
                                      ? Colors.green.withOpacity(0.08)
                                      : (isDarkMode
                                          ? Colors.white10
                                          : Colors.black.withOpacity(0.05))),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isEffectivelySelected
                                    ? Colors.green
                                    : (isCurrentPlaying
                                        ? Colors.green.withOpacity(0.4)
                                        : Colors.transparent),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: gridLayout.titlePadding,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: (isEffectivelySelected ||
                                            isCurrentPlaying)
                                        ? Colors.green
                                        : textColor,
                                    fontSize: 13,
                                    height: gridLayout.titleMaxLines > 2
                                        ? 1.22
                                        : null,
                                    fontWeight: isCurrentPlaying
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: gridLayout.titleMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          // 💡 新增：正在播放标记
                          if (isCurrentPlaying)
                            const Positioned(
                              top: 3,
                              right: 5,
                              child: Text(
                                '正在播放',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isDownloaded)
                            const Positioned(
                              right: 4,
                              bottom: 4,
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                          if (isDownloading || (isInQueue && !isDownloaded))
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isInQueue && !isDownloaded)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 1),
                                      child: Text(
                                        '${(task.progress * 100).toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (isDownloading) ...[
                                    _buildDownloadingAnimation(),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 查看缓存按钮 (位于底部按钮上方一点)
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 6),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DownloadScreen()),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_for_offline_outlined,
                      color: Colors.green,
                      size: widget.isCompact ? 18 : 20,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '查看缓存',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: widget.isCompact ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部操作按钮
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAll,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _isGrouped
                          ? (_isCurrentGroupAllSelected ? '取消本组' : '本组全选')
                          : (_selectedIndices.length == widget.episodes.length
                              ? '取消全选'
                              : '全选'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedIndices.isEmpty ? null : _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('立即下载 (${_selectedIndices.length})'),
                  ),
                ),
              ],
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
