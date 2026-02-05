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

  // 💡 优化：用于存储集数项的 GlobalKey，实现 100% 精准定位
  final Map<int, GlobalKey> _itemKeys = {};

  // 用于存储 ExpansionTile 的状态，方便定位时展开
  final Map<int, bool> _expansionStates = {};

  // 💡 核心修复：使用 ExpansionTileController 强力控制展开/收起
  final Map<int, ExpansionTileController> _tileControllers = {};

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
    // 💡 按照规范清理控制器（虽然 ExpansionTileController 不强制要求 dispose，但保持良好习惯）
    _tileControllers.clear();
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

  /// 💡 修复：使用控制器实现 100% 成功的展开定位
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
      // 2. 💡 核心修复：首先确保数据状态为展开
      setState(() {
        _expansionStates[animeId] = true;
      });

      // 3. 💡 核心修复：直接通过控制器下发展开指令
      // 这解决了 initiallyExpanded 在 Widget 已经存在时无效的问题
      _tileControllers[animeId]?.expand();

      // 4. 💡 核心优化：分两步精准定位
      // 必须给 ExpansionTile 一点动画和渲染子项的时间，否则 Scrollable 找不到目标 Context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 延时 250ms 以确保子项集数列表已经 layout 完成
        Future.delayed(const Duration(milliseconds: 250), () {
          final targetKey = _itemKeys[targetEpisodeId];
          if (targetKey?.currentContext != null) {
            Scrollable.ensureVisible(
              targetKey!.currentContext!,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.3, // 定位在屏幕上方 30% 处
            );
          } else {
            debugPrint('定位失败：目标 Context 为空，当前集数可能还在屏幕外或未渲染');
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
      _itemKeys.clear(); 
      _tileControllers.clear(); // 💡 搜索时清理控制器缓存
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
             // 延时一点点确保列表已构建
             WidgetsBinding.instance.addPostFrameCallback((_) => _locateToCurrent());
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

    // 💡 核心：为每个动画项绑定一个持久的控制器
    final controller = _tileControllers.putIfAbsent(
      anime.animeId, 
      () => ExpansionTileController()
    );

    return Container(
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
              key: PageStorageKey('tile_${anime.animeId}'), // 💡 使用 PageStorageKey 保持滚动后的状态
              initiallyExpanded: _expansionStates[anime.animeId] ?? false,
              onExpansionChanged: (expanded) {
                // 💡 实时同步数据状态
                setState(() {
                  _expansionStates[anime.animeId] = expanded;
                });
              },
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                anime.animeTitle,
                style: TextStyle(
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