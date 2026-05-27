import 'package:flutter/material.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/utils/font_utils.dart';

/// TV 手动匹配搜索回调。
typedef TvDanmakuSearchCallback = Future<DanmakuSearchResult?> Function(
  String query,
);

/// TV 手动匹配选集回调。
typedef TvDanmakuEpisodeSelected = void Function(
  int episodeId,
  String searchKeyword,
  DanmakuSearchAnime anime,
  int episodeIndex,
);

/// TV 专属手动匹配弹幕面板。
///
/// 遥控器端不适合直接输入中文，因此搜索框只负责展示当前搜索词，
/// 用户通过“删一字 / 清空 / 恢复片名”来调整查询，再按确认键执行搜索。
class TvDanmakuMatchScreen extends StatefulWidget {
  /// 创建 TV 专属手动匹配弹幕面板。
  const TvDanmakuMatchScreen({
    super.key,
    required this.initialQuery,
    required this.onSearch,
    required this.onEpisodeSelected,
    this.currentEpisodeId,
    this.currentEpisodeCommentCount,
  });

  /// 初始搜索词。
  final String initialQuery;

  /// 当前已命中的弹幕剧集 ID。
  final int? currentEpisodeId;

  /// 当前已命中的弹幕条数。
  final int? currentEpisodeCommentCount;

  /// 搜索回调。
  final TvDanmakuSearchCallback onSearch;

  /// 选中剧集后的回调。
  final TvDanmakuEpisodeSelected onEpisodeSelected;

  @override
  State<TvDanmakuMatchScreen> createState() => _TvDanmakuMatchScreenState();
}

class _TvDanmakuMatchScreenState extends State<TvDanmakuMatchScreen> {
  /// 当前搜索词。
  late String _query = widget.initialQuery;

  /// 当前搜索结果。
  List<DanmakuSearchAnime> _results = const <DanmakuSearchAnime>[];

  /// 当前是否正在请求搜索。
  bool _isLoading = false;

  /// 当前错误提示。
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_query.trim().isNotEmpty) {
      _runSearch();
    }
  }

  /// 删除当前搜索词的最后一个可见字符。
  void _deleteLastCharacter() {
    final characters = _query.characters;
    if (characters.isEmpty) {
      return;
    }
    setState(() {
      _query = characters.skipLast(1).toString();
    });
  }

  /// 清空当前搜索词。
  void _clearQuery() {
    setState(() {
      _query = '';
    });
  }

  /// 恢复到初始片名搜索词。
  void _restoreInitialQuery() {
    setState(() {
      _query = widget.initialQuery;
    });
  }

  /// 执行一次弹幕搜索。
  Future<void> _runSearch() async {
    final query = _query.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <DanmakuSearchAnime>[];
        _errorMessage = '请至少保留一个搜索字符';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onSearch(query);
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() {
          _results = const <DanmakuSearchAnime>[];
          _errorMessage = '弹幕服务暂不可用';
          _isLoading = false;
        });
        return;
      }
      if (!result.success) {
        setState(() {
          _results = const <DanmakuSearchAnime>[];
          _errorMessage = result.errorMessage.isEmpty ? '搜索失败' : result.errorMessage;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _results = result.animes;
        _errorMessage = result.animes.isEmpty ? '未找到相关弹幕' : null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = const <DanmakuSearchAnime>[];
        _errorMessage = '搜索失败: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return Material(
      color: const Color(0xFF10131D),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 780,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF10131D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF2A3137),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '手动匹配弹幕',
              style: FontUtils.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '默认带入当前片名，遥控器仅支持删字微调后搜索。',
              style: FontUtils.poppins(
                fontSize: 14,
                color: const Color(0xFF98A2A8),
              ),
            ),
            const SizedBox(height: 18),
            _buildQueryPreview(),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  label: '删一字',
                  onPressed: _deleteLastCharacter,
                  accent: palette.focus,
                ),
                _buildActionButton(
                  label: '清空',
                  onPressed: _clearQuery,
                  accent: const Color(0xFFE05A5A),
                ),
                _buildActionButton(
                  label: '恢复片名',
                  onPressed: _restoreInitialQuery,
                  accent: const Color(0xFF5B7CFA),
                ),
                _buildActionButton(
                  label: '开始搜索',
                  onPressed: _runSearch,
                  accent: palette.accent,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildResultArea(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建只读搜索词预览框。
  Widget _buildQueryPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF293136)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索词',
            style: FontUtils.poppins(
              fontSize: 13,
              color: const Color(0xFF98A2A8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _query.isEmpty ? '已清空，请恢复片名或继续删减后再搜索' : _query,
            style: FontUtils.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建顶部动作按钮。
  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color accent,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: FontUtils.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }

  /// 构建搜索结果区域。
  Widget _buildResultArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: FontUtils.poppins(
            fontSize: 16,
            color: const Color(0xFF98A2A8),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final anime = _results[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B21),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2D353C)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                anime.animeTitle,
                style: FontUtils.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                anime.typeDescription.isEmpty
                    ? anime.type
                    : '${anime.typeDescription} · ${anime.year == 0 ? '未知年份' : anime.year}',
                style: FontUtils.poppins(
                  fontSize: 14,
                  color: const Color(0xFF98A2A8),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var episodeIndex = 0;
                      episodeIndex < anime.episodes.length;
                      episodeIndex++)
                    _buildEpisodeButton(
                      anime: anime,
                      episode: anime.episodes[episodeIndex],
                      episodeIndex: episodeIndex,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个候选弹幕剧集按钮。
  Widget _buildEpisodeButton({
    required DanmakuSearchAnime anime,
    required DanmakuSearchEpisode episode,
    required int episodeIndex,
  }) {
    final selected = widget.currentEpisodeId == episode.episodeId;
    return OutlinedButton(
      onPressed: () {
        widget.onEpisodeSelected(
          episode.episodeId,
          _query.trim(),
          anime,
          episodeIndex,
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: selected ? Colors.white : const Color(0xFF46515A),
          width: selected ? 2 : 1,
        ),
        backgroundColor:
            selected ? const Color(0xFF2A6545) : const Color(0xFF1D242B),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(
        episode.episodeTitle,
        style: FontUtils.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
