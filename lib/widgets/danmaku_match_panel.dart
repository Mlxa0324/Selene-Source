import 'dart:async';

import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';

/// 弹幕手动匹配面板
class DanmakuMatchPanel extends StatefulWidget {
  final ThemeData theme;
  final String initialQuery;
  final int? currentEpisodeId; // 当前选中的弹幕 ID
  final int? currentEpisodeCommentCount; // 当前选中弹幕的条数
  final Function(
    int episodeId,
    String searchKeyword,
    DanmakuSearchAnime anime,
    int episodeIndex,
  ) onEpisodeSelected;
  final Future<void> Function(String query)? onSearchSubmitted;
  final Future<DanmakuSearchResult?> Function(String query)?
      searchEpisodesOverride;
  final double? backgroundOpacity;
  final BorderRadius? borderRadiusOverride;
  final bool forceDarkStyle;

  const DanmakuMatchPanel({
    super.key,
    required this.theme,
    required this.initialQuery,
    this.currentEpisodeId,
    this.currentEpisodeCommentCount,
    required this.onEpisodeSelected,
    this.onSearchSubmitted,
    this.searchEpisodesOverride,
    this.backgroundOpacity,
    this.borderRadiusOverride,
    this.forceDarkStyle = false,
  });

  @override
  State<DanmakuMatchPanel> createState() => _DanmakuMatchPanelState();
}

class _DanmakuMatchPanelState extends State<DanmakuMatchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<DanmakuSearchAnime> _searchResults = [];
  String? _errorMessage;
  bool _isDescending = true;
  int? _selectedAnimeId;
  String? _activeQuery;

  // 💡 优化：改为使用复合字符串 Key (animeId_episodeId)，防止不同搜索结果下重复的 episodeId 导致 GlobalKey 冲突
  final Map<String, GlobalKey> _itemKeys = {};
  final Map<int, GlobalKey> _animeItemKeys = {};

  // 用于存储 ExpansionTile 的状态，方便定位时展开
  final Map<int, bool> _expansionStates = {};

  // 💡 核心修复：使用 ExpansionTileController 强力控制展开/收起
  final Map<int, ExpansionTileController> _tileControllers = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    final initialQuery = widget.initialQuery.trim();
    _activeQuery = initialQuery.isEmpty ? null : initialQuery;
    _onSearch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _tileControllers.clear();
    _itemKeys.clear();
    _animeItemKeys.clear();
    super.dispose();
  }

  void _toggleSort() {
    setState(() {
      _isDescending = !_isDescending;
      _sortResults();
    });
  }

  void _sortResults() {
    if (_searchResults.isEmpty) return;
    if (_isDescending) {
      _searchResults.sort((a, b) => b.year.compareTo(a.year));
    } else {
      _searchResults.sort((a, b) => a.year.compareTo(b.year));
    }
  }

  void _syncSelectedAnimeId() {
    final currentId = widget.currentEpisodeId;
    if (currentId == null || _searchResults.isEmpty) {
      _selectedAnimeId = null;
      return;
    }

    for (final anime in _searchResults) {
      if (anime.episodes.any((e) => e.episodeId == currentId)) {
        _selectedAnimeId = anime.animeId;
        return;
      }
    }

    _selectedAnimeId = null;
  }

  /// 💡 修复：使用控制器强制收起所有已展开的项
  void _collapseAll() {
    setState(() {
      _expansionStates.clear();
    });

    // 遍历所有已绑定的控制器执行收起动画
    for (final controller in _tileControllers.values) {
      if (controller.isExpanded) {
        controller.collapse();
      }
    }
  }

  int? _findCurrentAnimeId(int targetEpisodeId) {
    final selectedAnimeId = _selectedAnimeId;
    if (selectedAnimeId != null &&
        _searchResults.any((anime) =>
            anime.animeId == selectedAnimeId &&
            anime.episodes.any((e) => e.episodeId == targetEpisodeId))) {
      return selectedAnimeId;
    }

    for (final anime in _searchResults) {
      if (anime.episodes.any((e) => e.episodeId == targetEpisodeId)) {
        return anime.animeId;
      }
    }
    return null;
  }

  /// 💡 修复：先滚动到父级动画项，再滚动到具体剧集
  Future<void> _locateToCurrent() async {
    if (widget.currentEpisodeId == null || _searchResults.isEmpty) return;

    final targetEpisodeId = widget.currentEpisodeId!;
    final animeId = _findCurrentAnimeId(targetEpisodeId);
    if (animeId == null) return;

    setState(() {
      _expansionStates[animeId] = true;
    });

    _tileControllers[animeId]?.expand();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final animeKey = _animeItemKeys[animeId];
    if (animeKey?.currentContext != null) {
      await Scrollable.ensureVisible(
        animeKey!.currentContext!,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    final compositeKey = '${animeId}_$targetEpisodeId';
    final targetKey = _itemKeys[compositeKey];
    if (targetKey?.currentContext != null) {
      await Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
      return;
    }

    if (animeKey?.currentContext != null) {
      await Scrollable.ensureVisible(
        animeKey!.currentContext!,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    await widget.onSearchSubmitted?.call(query);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _expansionStates.clear();
      _itemKeys.clear();
      _animeItemKeys.clear();
      _tileControllers.clear(); // 💡 搜索时清理控制器缓存
    });

    try {
      final result = await (widget.searchEpisodesOverride?.call(query) ??
          DanmakuService().searchEpisodes(query));
      if (mounted) {
        if (result != null && result.success) {
          setState(() {
            _searchResults = result.animes;
            _activeQuery = query;
            _sortResults();
            _syncSelectedAnimeId();
            _isLoading = false;
          });
          // 如果有当前 ID，自动定位一次
          if (widget.currentEpisodeId != null) {
            // 延时一点点确保列表已构建
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_locateToCurrent());
            });
          }
        } else {
          setState(() {
            _errorMessage = result?.errorMessage ?? '搜索失败';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '请求出错: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant DanmakuMatchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisodeId != widget.currentEpisodeId) {
      setState(() {
        _syncSelectedAnimeId();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.forceDarkStyle
        ? true
        : widget.theme.brightness == Brightness.dark;
    final backgroundOpacity =
        widget.backgroundOpacity ?? (isDarkMode ? 0.9 : 0.98);
    final backgroundColor = isDarkMode
        ? Colors.black.withOpacity(backgroundOpacity)
        : Colors.white.withOpacity(backgroundOpacity);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white38 : Colors.black38;
    final inputColor =
        isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05);

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity, // 💡 改为填满宽度
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: widget.borderRadiusOverride ??
              (isPortrait
                  ? const BorderRadius.vertical(
                      top: Radius.circular(24)) // 💡 底部弹出时使用顶部圆角
                  : const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    )),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  20, 10, 8, 4), // 💡 压缩上下边距 (16/8 -> 10/4)
              child: Row(
                children: [
                  Text(
                    '手动匹配弹幕',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16, // 💡 略微缩小字号
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // 收起按钮
                  if (_searchResults.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact, // 💡 紧凑模式
                      tooltip: '收起所有结果',
                      icon: Icon(Icons.unfold_less,
                          color: textColor.withOpacity(0.7), size: 18),
                      onPressed: _collapseAll,
                    ),
                  // 定位按钮
                  if (widget.currentEpisodeId != null &&
                      _searchResults.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '定位到当前弹幕',
                      icon: const Icon(Icons.location_searching,
                          color: Colors.green, size: 18),
                      onPressed: () {
                        unawaited(_locateToCurrent());
                      },
                    ),
                  // 排序切换按钮
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _isDescending ? '当前：年份倒序' : '当前：年份正序',
                    icon: Icon(
                      _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
                      color: textColor.withOpacity(0.7),
                      size: 18,
                    ),
                    onPressed: _toggleSort,
                  ),
                  // 关闭按钮
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close,
                        color: textColor.withOpacity(0.7), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 搜索框区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 38, // 💡 降低高度 (42 -> 38)
                margin:
                    const EdgeInsets.only(bottom: 12), // 💡 缩小下方间距 (16 -> 12)
                decoration: BoxDecoration(
                  color: inputColor,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: textColor.withOpacity(0.05), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor, fontSize: 13), // 💡 缩小字号
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: '输入作品名称搜索',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                    prefixIcon:
                        Icon(Icons.search, color: subTextColor, size: 17),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: IconButton(
                      padding: EdgeInsets.zero,
                      icon:
                          const Icon(Icons.send, color: Colors.green, size: 17),
                      onPressed: _onSearch,
                    ),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
            ),

            // 可滚动区域
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.green, strokeWidth: 2))
                  : _errorMessage != null
                      ? Center(
                          child: Text(_errorMessage!,
                              style:
                                  TextStyle(color: textColor.withOpacity(0.5))))
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text('未找到相关弹幕',
                                  style: TextStyle(color: subTextColor)))
                          : SingleChildScrollView(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  for (final anime in _searchResults)
                                    _buildAnimeItem(
                                      anime,
                                      isDarkMode,
                                      textColor,
                                      subTextColor,
                                    ),
                                ],
                              ),
                            ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeItem(DanmakuSearchAnime anime, bool isDarkMode,
      Color textColor, Color subTextColor) {
    bool hasSelected = _selectedAnimeId == anime.animeId &&
        anime.episodes.any((e) => e.episodeId == widget.currentEpisodeId);

    // 💡 核心：为每个动画项绑定一个持久的控制器
    final controller = _tileControllers.putIfAbsent(
        anime.animeId, () => ExpansionTileController());
    final animeKey =
        _animeItemKeys.putIfAbsent(anime.animeId, () => GlobalKey());

    return Container(
      key: animeKey,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: hasSelected
            ? Border.all(color: Colors.green.withOpacity(0.2), width: 1)
            : null,
      ),
      child: Stack(
        children: [
          if (hasSelected)
            Positioned(
              left: 0,
              top: 12,
              bottom: 12,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Theme(
            data: widget.theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              controller: controller, // 💡 绑定控制器
              key: PageStorageKey(
                  'tile_${anime.animeId}'), // 💡 使用 PageStorageKey 保持滚动后的状态
              initiallyExpanded: _expansionStates[anime.animeId] ?? false,
              onExpansionChanged: (expanded) {
                // 💡 实时同步数据状态
                setState(() {
                  _expansionStates[anime.animeId] = expanded;
                });
              },
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                anime.animeTitle,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight:
                        hasSelected ? FontWeight.w600 : FontWeight.normal),
              ),
              subtitle: Text(
                '${anime.typeDescription} • ${anime.episodes.length}个结果',
                style: TextStyle(color: subTextColor, fontSize: 11),
              ),
              iconColor: textColor.withOpacity(0.5),
              collapsedIconColor: textColor.withOpacity(0.5),
              childrenPadding: EdgeInsets.zero,
              children: [
                ...anime.episodes.map((ep) => _buildEpisodeItem(
                      anime,
                      anime.animeId,
                      ep,
                      textColor,
                      subTextColor,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(
    DanmakuSearchAnime anime,
    int animeId,
    DanmakuSearchEpisode episode,
    Color textColor,
    Color subTextColor,
  ) {
    bool isSelected = _selectedAnimeId == animeId &&
        episode.episodeId == widget.currentEpisodeId;
    final selectedCommentCount =
        isSelected ? widget.currentEpisodeCommentCount : null;

    // 💡 复合 Key 生成
    final compositeKey = '${animeId}_${episode.episodeId}';
    final key = _itemKeys.putIfAbsent(compositeKey, () => GlobalKey());
    final effectiveQuery = (_activeQuery?.trim().isNotEmpty ?? false)
        ? _activeQuery!.trim()
        : widget.initialQuery.trim();

    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAnimeId = animeId;
          });
          widget.onEpisodeSelected(
            episode.episodeId,
            effectiveQuery,
            anime,
            anime.episodes.indexWhere((item) => item.episodeId == episode.episodeId),
          );
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.withOpacity(0.1) : null,
            border: Border(
                bottom:
                    BorderSide(color: textColor.withOpacity(0.05), width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  episode.episodeTitle,
                  style: TextStyle(
                    color:
                        isSelected ? Colors.green : textColor.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if ((selectedCommentCount ?? 0) > 0) ...[
                Text(
                  '$selectedCommentCount条',
                  style: TextStyle(
                    color: isSelected ? Colors.green : subTextColor,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
