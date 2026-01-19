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

  /// 定位到当前正在使用的弹幕位置
  void _locateToCurrent() {
    if (widget.currentEpisodeId == null || _searchResults.isEmpty) return;

    int animeIndex = -1;
    int episodeIndex = -1;

    // 1. 查找当前 ID 所在的动画索引和集数索引
    for (int i = 0; i < _searchResults.length; i++) {
      final episodes = _searchResults[i].episodes;
      for (int j = 0; j < episodes.length; j++) {
        if (episodes[j].episodeId == widget.currentEpisodeId) {
          animeIndex = i;
          episodeIndex = j;
          break;
        }
      }
      if (animeIndex != -1) break;
    }

    if (animeIndex != -1) {
      // 2. 确保目标动画条目处于展开状态
      setState(() {
        _expansionStates[_searchResults[animeIndex].animeId] = true;
      });

      // 3. 执行精确滚动
      // 这里的计算逻辑：
      // - 动画卡片折叠时高度约为 68
      // - 每集条目高度约为 48 (12+12 padding + 13 font + border)
      // - ExpansionTile 展开后会有一些额外的内边距
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;

        double animeHeaderHeight = 68.0;
        double episodeItemHeight = 48.5;
        
        // 计算偏移量：之前的动画项总高度 + 当前动画项内的集数偏移
        double offset = (animeIndex * animeHeaderHeight) + (episodeIndex * episodeItemHeight);
        
        // 适当向上偏移一点，避免贴顶
        double finalOffset = (offset - 100).clamp(0.0, _scrollController.position.maxScrollExtent);

        _scrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
        );
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

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
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
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  '手动匹配弹幕',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 定位按钮
                if (widget.currentEpisodeId != null && _searchResults.isNotEmpty)
                  IconButton(
                    tooltip: '定位到当前弹幕',
                    icon: const Icon(Icons.location_searching, color: Colors.green, size: 18),
                    onPressed: _locateToCurrent,
                  ),
                // 排序切换按钮
                IconButton(
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
              height: 42,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: inputColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: textColor.withOpacity(0.05), width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 14),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: '输入作品名称搜索',
                  hintStyle: TextStyle(color: subTextColor),
                  prefixIcon:
                      Icon(Icons.search, color: subTextColor, size: 18),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.green, size: 18),
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
        border: hasSelected
            ? Border.all(color: Colors.green.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Theme(
        data: widget.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('tile_${anime.animeId}'),
          initiallyExpanded: _expansionStates[anime.animeId] ?? false,
          onExpansionChanged: (expanded) {
            _expansionStates[anime.animeId] = expanded;
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text(
            anime.animeTitle,
            style: TextStyle(
                color: hasSelected ? Colors.green : textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${anime.typeDescription} • ${anime.episodes.length}个结果',
            style: TextStyle(color: subTextColor, fontSize: 11),
          ),
          iconColor: textColor.withOpacity(0.5),
          collapsedIconColor: textColor.withOpacity(0.5),
          childrenPadding: EdgeInsets.zero, // 移除默认边距
          children: [
            // 针对大量集数的情况，虽然这里不能直接用 ListView，但我们可以预先处理数据
            ...anime.episodes.map((ep) => _buildEpisodeItem(ep, textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(DanmakuSearchEpisode episode, Color textColor) {
    bool isSelected = episode.episodeId == widget.currentEpisodeId;
    
    return Material(
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