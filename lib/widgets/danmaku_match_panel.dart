import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';

/// 弹幕手动匹配面板
class DanmakuMatchPanel extends StatefulWidget {
  final ThemeData theme;
  final String initialQuery;
  final int? currentEpisodeId; // 当前选中的弹幕 ID
  final Function(int episodeId) onEpisodeSelected;

  const DanmakuMatchPanel({
    super.key,
    required this.theme,
    required this.initialQuery,
    this.currentEpisodeId,
    required this.onEpisodeSelected,
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
  int _resetCounter = 0; // 💡 新增：用于强制重置所有 Tile 状态

  // 💡 优化：用于存储集数项的 GlobalKey，实现 100% 精准定位
  final Map<int, GlobalKey> _itemKeys = {};

  // 用于存储 ExpansionTile 的状态，方便定位时展开
  final Map<int, bool> _expansionStates = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _onSearch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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

  /// 💡 新增：收起所有已展开的项
  void _collapseAll() {
    setState(() {
      _expansionStates.clear();
      _resetCounter++; // 💡 增加计数器，强制 Key 变化
    });
  }

  /// 定位到当前正在使用的弹幕位置
  void _locateToCurrent() {
    if (widget.currentEpisodeId == null || _searchResults.isEmpty) return;

    int animeId = -1;
    int targetEpisodeId = widget.currentEpisodeId!;

    // 1. 查找当前 ID 所在的动画
    for (var anime in _searchResults) {
      if (anime.episodes.any((e) => e.episodeId == targetEpisodeId)) {
        animeId = anime.animeId;
        break;
      }
    }

    if (animeId != -1) {
      // 2. 确保目标动画条目处于展开状态
      setState(() {
        _expansionStates[animeId] = true;
      });

      // 3. 💡 核心优化：分两步精准定位
      // 第一步：先快速滚动到动画标题位置，确保目标组件在渲染范围内
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 给 ExpansionTile 展开一点时间
        Future.delayed(const Duration(milliseconds: 150), () {
          final targetKey = _itemKeys[targetEpisodeId];
          if (targetKey?.currentContext != null) {
            // 第二步：使用官方提供的 ensureVisible 自动对齐，完美避开高度计算
            Scrollable.ensureVisible(
              targetKey!.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.3, // 💡 0.3 表示定位在距离顶部 30% 的位置，视觉最舒适
            );
          }
        });
      });
    }
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _expansionStates.clear();
      _itemKeys.clear(); // 💡 搜索时清理 Key 缓存
    });

    try {
      final result = await DanmakuService().searchEpisodes(query);
      if (mounted) {
        if (result != null && result.success) {
          setState(() {
            _searchResults = result.animes;
            _sortResults();
            _isLoading = false;
          });
          // 如果有当前 ID，自动定位一次
          if (widget.currentEpisodeId != null) {
             _locateToCurrent();
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
  Widget build(BuildContext context) {
    final isDarkMode = widget.theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? Colors.black.withOpacity(0.9)
        : Colors.white.withOpacity(0.98);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white38 : Colors.black38;
    final inputColor =
        isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05);

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Container(
      width: double.infinity, // 💡 改为填满宽度
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: isPortrait 
          ? const BorderRadius.vertical(top: Radius.circular(24)) // 💡 底部弹出时使用顶部圆角
          : const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
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
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 4), // 💡 压缩上下边距 (16/8 -> 10/4)
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
                    icon: Icon(Icons.unfold_less, color: textColor.withOpacity(0.7), size: 18),
                    onPressed: _collapseAll,
                  ),
                // 定位按钮
                if (widget.currentEpisodeId != null && _searchResults.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '定位到当前弹幕',
                    icon: const Icon(Icons.location_searching, color: Colors.green, size: 18),
                    onPressed: _locateToCurrent,
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
              margin: const EdgeInsets.only(bottom: 12), // 💡 缩小下方间距 (16 -> 12)
              decoration: BoxDecoration(
                color: inputColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: textColor.withOpacity(0.05), width: 1),
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
                    icon: const Icon(Icons.send,
                        color: Colors.green, size: 17),
                    onPressed: _onSearch,
                  ),
                ),
                onSubmitted: (_) => _onSearch(),
              ),
            ),
          ),

          // 可滚动区域 - 使用 ListView.builder 优化性能
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.green, strokeWidth: 2))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: TextStyle(color: textColor.withOpacity(0.5))))
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text('未找到相关弹幕',
                                style: TextStyle(color: subTextColor)))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _searchResults.length,
                            itemExtent: null, // 高度自适应
                            cacheExtent: 1000, // 增加预渲染区域减少闪烁
                            itemBuilder: (context, index) {
                              final anime = _searchResults[index];
                              return _buildAnimeItem(
                                anime,
                                isDarkMode,
                                textColor,
                                subTextColor,
                              );
                            },
                          ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAnimeItem(DanmakuSearchAnime anime, bool isDarkMode,
      Color textColor, Color subTextColor) {
    bool hasSelected =
        anime.episodes.any((e) => e.episodeId == widget.currentEpisodeId);

    return Container(
      key: PageStorageKey('anime_${anime.animeId}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        // 💡 优化：移除外层厚重的绿色边框，改为仅在有选中项时显示极淡的底色
        border: hasSelected
            ? Border.all(color: Colors.green.withOpacity(0.2), width: 1)
            : null,
      ),
      child: Stack(
        children: [
          // 💡 优化：在左侧增加一个细长的绿色指示条，代替原本的标题变绿，这样更专业
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
              key: ValueKey('tile_${anime.animeId}_$_resetCounter'),
              initiallyExpanded: _expansionStates[anime.animeId] ?? false,
              onExpansionChanged: (expanded) {
                _expansionStates[anime.animeId] = expanded;
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                anime.animeTitle,
                style: TextStyle(
                    // 💡 优化：标题颜色不再强制变绿，保持统一，仅通过左侧条指示
                    color: textColor, 
                    fontSize: 14,
                    fontWeight: hasSelected ? FontWeight.w600 : FontWeight.normal),
              ),
              subtitle: Text(
                '${anime.typeDescription} • ${anime.episodes.length}个结果',
                style: TextStyle(color: subTextColor, fontSize: 11),
              ),
              iconColor: textColor.withOpacity(0.5),
              collapsedIconColor: textColor.withOpacity(0.5),
              childrenPadding: EdgeInsets.zero,
              children: [
                ...anime.episodes.map((ep) => _buildEpisodeItem(ep, textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(DanmakuSearchEpisode episode, Color textColor) {
    bool isSelected = episode.episodeId == widget.currentEpisodeId;
    
    // 💡 优化：为每个集数项生成一个 GlobalKey，并在定位时使用
    final key = _itemKeys.putIfAbsent(episode.episodeId, () => GlobalKey());

    return Material(
      key: key, // 💡 绑定 Key
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onEpisodeSelected(episode.episodeId),
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
                    color: isSelected ? Colors.green : textColor.withOpacity(0.7), 
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}