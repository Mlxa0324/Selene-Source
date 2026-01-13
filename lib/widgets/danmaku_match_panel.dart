import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';

/// 弹幕手动匹配面板
class DanmakuMatchPanel extends StatefulWidget {
  final ThemeData theme;
  final String initialQuery;
  final Function(int episodeId) onEpisodeSelected;

  const DanmakuMatchPanel({
    super.key,
    required this.theme,
    required this.initialQuery,
    required this.onEpisodeSelected,
  });

  @override
  State<DanmakuMatchPanel> createState() => _DanmakuMatchPanelState();
}

class _DanmakuMatchPanelState extends State<DanmakuMatchPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<DanmakuSearchAnime> _searchResults = [];
  String? _errorMessage;
  bool _isDescending = true; // 默认年份倒序

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _onSearch();
  }

  /// 切换排序顺序
  void _toggleSort() {
    setState(() {
      _isDescending = !_isDescending;
      _sortResults();
    });
  }

  /// 执行排序逻辑
  void _sortResults() {
    if (_searchResults.isEmpty) return;
    if (_isDescending) {
      _searchResults.sort((a, b) => b.year.compareTo(a.year));
    } else {
      _searchResults.sort((a, b) => a.year.compareTo(b.year));
    }
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DanmakuService().searchEpisodes(query);
      if (mounted) {
        if (result != null && result.success) {
          setState(() {
            _searchResults = result.animes;
            _sortResults(); // 应用当前排序
            _isLoading = false;
          });
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

          // 可滚动区域
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 搜索框
                Container(
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
                    textAlignVertical: TextAlignVertical.center, // 强制垂直居中
                    decoration: InputDecoration(
                      hintText: '输入作品名称搜索',
                      hintStyle: TextStyle(color: subTextColor),
                      prefixIcon:
                          Icon(Icons.search, color: subTextColor, size: 18),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero, // 移除多余填充
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send,
                            color: Colors.green, size: 18),
                        onPressed: _onSearch,
                      ),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),

                // 状态展示
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.green, strokeWidth: 2)),
                  )
                else if (_errorMessage != null)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: textColor.withOpacity(0.5))),
                  ))
                else if (_searchResults.isEmpty)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child:
                        Text('未找到相关弹幕', style: TextStyle(color: subTextColor)),
                  ))
                else
                  ..._searchResults.map((anime) => _buildAnimeItem(
                      anime, isDarkMode, textColor, subTextColor)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeItem(DanmakuSearchAnime anime, bool isDarkMode,
      Color textColor, Color subTextColor) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        hoverColor: textColor.withOpacity(0.05),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text(
            anime.animeTitle,
            style: TextStyle(
                color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${anime.typeDescription} • ${anime.episodes.length}个结果',
            style: TextStyle(color: subTextColor, fontSize: 11),
          ),
          iconColor: textColor.withOpacity(0.5),
          collapsedIconColor: textColor.withOpacity(0.5),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: anime.episodes
              .map((ep) => _buildEpisodeItem(ep, textColor))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildEpisodeItem(DanmakuSearchEpisode episode, Color textColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onEpisodeSelected(episode.episodeId),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: textColor.withOpacity(0.05), width: 0.5)),
          ),
          child: Text(
            episode.episodeTitle,
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13),
          ),
        ),
      ),
    );
  }
}
