import 'package:flutter/material.dart';
import '../models/danmaku_model.dart';
import '../services/danmaku_service.dart';

/// 弹幕手动匹配面板
class DanmakuMatchPanel extends StatefulWidget {
  final String initialQuery;
  final Function(int episodeId) onEpisodeSelected;

  const DanmakuMatchPanel({
    super.key,
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

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _onSearch();
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
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '手动匹配弹幕',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '输入作品名称搜索',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.green, size: 18),
                    onPressed: _onSearch,
                  ),
                ),
                onSubmitted: (_) => _onSearch(),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 结果列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white54)))
                    : _searchResults.isEmpty
                        ? const Center(child: Text('未找到相关弹幕', style: TextStyle(color: Colors.white54)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final anime = _searchResults[index];
                              return _buildAnimeItem(anime);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeItem(DanmakuSearchAnime anime) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          anime.animeTitle,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          anime.typeDescription,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        children: anime.episodes.map((ep) => _buildEpisodeItem(ep)).toList(),
      ),
    );
  }

  Widget _buildEpisodeItem(DanmakuSearchEpisode episode) {
    return InkWell(
      onTap: () => widget.onEpisodeSelected(episode.episodeId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          episode.episodeTitle,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}
