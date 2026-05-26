import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/api_service.dart';
import 'package:selene/services/douban_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/search_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/utils/font_utils.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

/// TV 详情页数据加载函数。
typedef TvVideoDetailLoader = Future<TvVideoDetailData> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

/// TV 详情页播放器构建函数。
typedef TvDetailPlayerBuilder = Widget Function(
  BuildContext context,
  void Function(VideoPlayerWidgetController controller) onControllerCreated,
);

/// TV 详情页聚合数据。
class TvVideoDetailData {
  /// 创建 TV 详情页聚合数据。
  const TvVideoDetailData({
    required this.currentDetail,
    required this.sources,
    required this.recommends,
  });

  /// 当前播放源详情。
  final SearchResult? currentDetail;

  /// 可切换播放源。
  final List<SearchResult> sources;

  /// 相关推荐。
  final List<VideoInfo> recommends;
}

/// TV 影视详情页。
///
/// TV 卡片点击后先进入该页面，再从页面内进行播放、换源、选集和推荐跳转。
class TvVideoDetailScreen extends StatefulWidget {
  /// 创建 TV 影视详情页。
  const TvVideoDetailScreen({
    super.key,
    required this.videoInfo,
    this.stype,
    this.loadDetail,
    this.playerBuilder,
    this.fullscreenPlayerBuilder,
  });

  /// 入口视频信息。
  final VideoInfo videoInfo;

  /// 搜索类型，沿用普通播放器的电影/剧集提示。
  final String? stype;

  /// 详情加载函数，测试时可注入。
  final TvVideoDetailLoader? loadDetail;

  /// 播放器构建函数，测试时可替换。
  final TvDetailPlayerBuilder? playerBuilder;

  /// 全屏播放器构建函数，测试时可替换。
  final TvFullscreenPlayerBuilder? fullscreenPlayerBuilder;

  @override
  State<TvVideoDetailScreen> createState() => _TvVideoDetailScreenState();

  /// 默认详情加载逻辑。
  static Future<TvVideoDetailData> defaultLoadDetail(
    BuildContext context,
    VideoInfo videoInfo,
  ) async {
    final isLocalMode = await UserDataService.getIsLocalMode();
    final query = videoInfo.searchTitle.trim().isNotEmpty
        ? videoInfo.searchTitle.trim()
        : videoInfo.title.trim();
    final sources = <SearchResult>[];

    // 有明确源和 ID 时优先加载对应详情，保证历史/收藏入口命中原源。
    if (videoInfo.source.isNotEmpty &&
        videoInfo.id.isNotEmpty &&
        videoInfo.source != 'douban' &&
        videoInfo.source != 'bangumi') {
      final exact = isLocalMode
          ? await SearchService.getDetailSync(videoInfo.source, videoInfo.id)
          : await ApiService.fetchSourceDetail(videoInfo.source, videoInfo.id);
      sources.addAll(exact);
    }

    // 继续补全同标题的可用源，作为换源列表。
    if (query.isNotEmpty) {
      final searched = isLocalMode
          ? await SearchService.searchSync(query)
          : await ApiService.fetchSourcesData(query, allowEarlyReturn: false);
      for (final source in searched) {
        final exists = sources.any(
          (item) => item.source == source.source && item.id == source.id,
        );
        if (!exists) {
          sources.add(source);
        }
      }
    }

    final currentDetail = sources.isNotEmpty ? sources.first : null;
    // 静态加载函数没有 State.mounted，可取消时由 FutureBuilder 丢弃页面结果。
    // ignore: use_build_context_synchronously
    final recommends = await _loadRecommends(context, videoInfo, currentDetail);

    return TvVideoDetailData(
      currentDetail: currentDetail,
      sources: sources,
      recommends: recommends,
    );
  }

  /// 加载豆瓣相关推荐。
  static Future<List<VideoInfo>> _loadRecommends(
    BuildContext context,
    VideoInfo videoInfo,
    SearchResult? currentDetail,
  ) async {
    final doubanId = currentDetail?.doubanId?.toString() ?? videoInfo.doubanId;
    if (doubanId == null || doubanId.isEmpty || doubanId == '0') {
      return const [];
    }

    final response = await DoubanService.getDoubanDetails(
      context,
      doubanId: doubanId,
    );
    return response.data?.recommends
            .map((recommend) => recommend.toVideoInfo())
            .toList() ??
        const [];
  }
}

class _TvVideoDetailScreenState extends State<TvVideoDetailScreen> {
  /// 选集分组大小，避免长剧集在 TV 端一次性横向铺满过长。
  static const int _episodeGroupSize = 20;

  /// 页面滚动控制器。
  final ScrollController _scrollController = ScrollController();

  /// 播放器控制器。
  VideoPlayerWidgetController? _playerController;

  /// 详情加载任务。
  late Future<TvVideoDetailData> _detailFuture;

  /// 当前源详情。
  SearchResult? _currentDetail;

  /// 所有可用播放源。
  List<SearchResult> _sources = const [];

  /// 相关推荐。
  List<VideoInfo> _recommends = const [];

  /// 当前选集下标。
  int _episodeIndex = 0;

  /// 当前选集分组下标。
  int _episodeGroupIndex = 0;

  /// 当前是否收藏。
  bool _isFavorite = false;

  /// 是否已应用加载结果。
  bool _appliedDetail = false;

  @override
  void initState() {
    super.initState();
    _detailFuture =
        (widget.loadDetail ?? TvVideoDetailScreen.defaultLoadDetail)(
      context,
      widget.videoInfo,
    );
    _loadFavoriteState();
  }

  @override
  void dispose() {
    _playerController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载收藏状态。
  Future<void> _loadFavoriteState() async {
    final isFavorite = PageCacheService().isFavoritedSync(
      widget.videoInfo.source,
      widget.videoInfo.id,
    );
    if (mounted) {
      setState(() => _isFavorite = isFavorite);
    }
  }

  /// 应用详情加载结果。
  void _applyDetail(TvVideoDetailData data) {
    if (_appliedDetail) {
      return;
    }
    _currentDetail = data.currentDetail;
    _sources = data.sources;
    _recommends = data.recommends;
    _appliedDetail = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentEpisode());
  }

  /// 播放当前选集。
  Future<void> _playCurrentEpisode() async {
    final detail = _currentDetail;
    final controller = _playerController;
    if (detail == null || controller == null || detail.episodes.isEmpty) {
      return;
    }

    final index = _episodeIndex.clamp(0, detail.episodes.length - 1);
    var url = detail.episodes[index];
    final proxy = await UserDataService.getM3u8ProxyUrl();
    if (proxy.isNotEmpty && url.startsWith('http')) {
      url = '$proxy${Uri.encodeComponent(url)}';
    }
    await controller.updateDataSource(url);
  }

  /// 切换播放源。
  void _switchSource(SearchResult source) {
    setState(() {
      _currentDetail = source;
      _episodeIndex = 0;
      _episodeGroupIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentEpisode());
  }

  /// 切换选集。
  void _switchEpisode(int index) {
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = index ~/ _episodeGroupSize;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentEpisode());
  }

  /// 切换选集分组。
  void _switchEpisodeGroup(int index) {
    setState(() => _episodeGroupIndex = index);
  }

  /// 获取选集分组数量。
  int _episodeGroupCount(int total) {
    if (total <= 0) {
      return 0;
    }
    return ((total - 1) ~/ _episodeGroupSize) + 1;
  }

  /// 获取选集分组标题。
  String _episodeGroupLabel(int groupIndex, int total) {
    final start = groupIndex * _episodeGroupSize + 1;
    final rawEnd = start + _episodeGroupSize - 1;
    final end = rawEnd > total ? total : rawEnd;
    return start == end ? '$start' : '$start-$end';
  }

  /// 获取当前分组内的选集下标。
  List<int> _episodeIndexesForGroup(int total, int groupIndex) {
    final start = groupIndex * _episodeGroupSize;
    final rawEnd = start + _episodeGroupSize;
    final end = rawEnd > total ? total : rawEnd;
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  /// 切换收藏状态。
  Future<void> _toggleFavorite() async {
    final detail = _currentDetail;
    if (detail == null) {
      return;
    }

    if (_isFavorite) {
      final result = await PageCacheService()
          .removeFavorite(detail.source, detail.id, context);
      if (result.success && mounted) {
        setState(() => _isFavorite = false);
      }
      return;
    }

    final favoriteData = {
      'cover': detail.poster,
      'save_time': DateTime.now().millisecondsSinceEpoch,
      'source_name': detail.sourceName,
      'title': detail.title,
      'total_episodes': detail.episodes.length,
      'year': detail.year,
    };
    final result = await PageCacheService().addFavorite(
      detail.source,
      detail.id,
      favoriteData,
      context,
    );
    if (result.success && mounted) {
      setState(() => _isFavorite = true);
    }
  }

  /// 进入 TV 专属全屏播放器页。
  void _openFullscreenPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TvFullscreenPlayerScreen(
          videoInfo: widget.videoInfo,
          currentDetail: _currentDetail,
          sources: _sources,
          stype: widget.stype,
          initialEpisodeIndex: _episodeIndex,
          playerBuilder: widget.fullscreenPlayerBuilder,
        ),
      ),
    );
  }

  /// 回到页面顶部。
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D0E),
        body: SafeArea(
          child: FutureBuilder<TvVideoDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CircularProgressIndicator(
                    color: TvTheme.of(context).accent,
                  ),
                );
              }

              _applyDetail(snapshot.data ??
                  const TvVideoDetailData(
                    currentDetail: null,
                    sources: [],
                    recommends: [],
                  ));

              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(
                  TvLayout.pageHorizontalPadding,
                  38,
                  TvLayout.pageHorizontalPadding,
                  56,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroArea(),
                    const SizedBox(height: 30),
                    _buildSourcesSection(),
                    const SizedBox(height: 28),
                    _buildEpisodesSection(),
                    const SizedBox(height: 34),
                    _buildRecommendsSection(),
                    const SizedBox(height: 38),
                    _buildBottomActions(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 构建播放器和简介区域。
  Widget _buildHeroArea() {
    final detail = _currentDetail;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useVerticalLayout = constraints.maxWidth < 980;
        final playerWidth = useVerticalLayout ? constraints.maxWidth : 620.0;
        final player = SizedBox(
          width: playerWidth,
          child: _buildPlayerBox(detail),
        );
        final info = _buildInfoPanel(detail);

        if (useVerticalLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player,
              const SizedBox(height: 22),
              info,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            player,
            const SizedBox(width: 34),
            Expanded(child: info),
          ],
        );
      },
    );
  }

  /// 构建播放器区域。
  Widget _buildPlayerBox(SearchResult? detail) {
    return TvFocusable(
      onPressed: _openFullscreenPlayer,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          key: const ValueKey('tv-detail-player-entry'),
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.playerBuilder?.call(
                    context,
                    (controller) {
                      _playerController = controller;
                      _playCurrentEpisode();
                    },
                  ) ??
                  VideoPlayerWidget(
                    surface: VideoPlayerSurface.desktop,
                    url: null,
                    videoTitle: detail?.title ?? widget.videoInfo.title,
                    videoYear: detail?.year ?? widget.videoInfo.year,
                    videoCover: detail?.poster ?? widget.videoInfo.cover,
                    currentEpisodeIndex: _episodeIndex,
                    totalEpisodes: detail?.episodes.length ?? 0,
                    episodesTitles: detail?.episodesTitles,
                    isShortDrama: false,
                    sourceName:
                        detail?.sourceName ?? widget.videoInfo.sourceName,
                    showControls: false,
                    onControllerCreated: (controller) {
                      _playerController = controller;
                      _playCurrentEpisode();
                    },
                    onFullscreenChanged: (_) {},
                    onEpisodeChanged: _switchEpisode,
                    onNextEpisode: () {
                      final total = detail?.episodes.length ?? 0;
                      if (_episodeIndex + 1 < total) {
                        _switchEpisode(_episodeIndex + 1);
                      }
                    },
                    onPreviousEpisode: () {
                      if (_episodeIndex > 0) {
                        _switchEpisode(_episodeIndex - 1);
                      }
                    },
                    onVideoCompleted: () {},
                  ),
            ),
          ),
        );
      },
    );
  }

  /// 构建右侧简介和按钮。
  Widget _buildInfoPanel(SearchResult? detail) {
    final title = detail?.title ?? widget.videoInfo.title;
    final meta = [
      if ((detail?.year ?? widget.videoInfo.year).isNotEmpty)
        detail?.year ?? widget.videoInfo.year,
      if ((detail?.sourceName ?? widget.videoInfo.sourceName).isNotEmpty)
        detail?.sourceName ?? widget.videoInfo.sourceName,
      if ((detail?.episodes.length ?? widget.videoInfo.totalEpisodes) > 0)
        '共 ${detail?.episodes.length ?? widget.videoInfo.totalEpisodes} 集',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FontUtils.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          meta,
          style: FontUtils.poppins(
            fontSize: 15,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          (detail?.desc?.trim().isNotEmpty == true)
              ? detail!.desc!.trim()
              : '暂无简介',
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: FontUtils.poppins(
            fontSize: 16,
            height: 1.45,
            color: const Color(0xFFD9E2E0),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            _TvDetailActionButton(
              label: '全屏',
              icon: LucideIcons.maximize2,
              onPressed: _openFullscreenPlayer,
            ),
            _TvDetailActionButton(
              label: _isFavorite ? '已收藏' : '收藏',
              icon: _isFavorite ? LucideIcons.heart : LucideIcons.heartPlus,
              iconColor: _isFavorite
                  ? const Color(0xFFE50914)
                  : const Color(0xFF131A21),
              onPressed: _toggleFavorite,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建换源区。
  Widget _buildSourcesSection() {
    return _TvDetailSection(
      title: '换源',
      child: _sources.isEmpty
          ? _buildEmptyText('暂无可用源')
          : SizedBox(
              height: 52,
              child: ListView.separated(
                key: const ValueKey('tv-detail-source-list'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _sources.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final source = _sources[index];
                  final selected = source.source == _currentDetail?.source &&
                      source.id == _currentDetail?.id;
                  return _TvChoiceChip(
                    label: source.sourceName,
                    selected: selected,
                    onPressed: () => _switchSource(source),
                  );
                },
              ),
            ),
    );
  }

  /// 构建选集区。
  Widget _buildEpisodesSection() {
    final detail = _currentDetail;
    final episodes = detail?.episodes ?? const <String>[];
    final groupCount = _episodeGroupCount(episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes = _episodeIndexesForGroup(episodes.length, groupIndex);
    return _TvDetailSection(
      title: '选集',
      child: episodes.isEmpty
          ? _buildEmptyText('暂无选集')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupCount > 1) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      key: const ValueKey('tv-detail-episode-group-list'),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: groupCount,
                      separatorBuilder: (_, __) => const SizedBox(width: 18),
                      itemBuilder: (context, index) {
                        return _TvTextChoice(
                          label: _episodeGroupLabel(index, episodes.length),
                          selected: index == groupIndex,
                          onPressed: () => _switchEpisodeGroup(index),
                          throttleGroupKey: 'tv-detail-episode-group-list',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    key: const ValueKey('tv-detail-episode-list'),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: visibleIndexes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, itemIndex) {
                      final index = visibleIndexes[itemIndex];
                      final title =
                          detail?.episodesTitles.length == episodes.length
                              ? detail!.episodesTitles[index]
                              : '${index + 1}';
                      return _TvChoiceChip(
                        label: title.isEmpty ? '${index + 1}' : title,
                        selected: index == _episodeIndex,
                        onPressed: () => _switchEpisode(index),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// 构建相关推荐区。
  Widget _buildRecommendsSection() {
    return _TvDetailSection(
      title: '相关推荐',
      child: _recommends.isEmpty
          ? _buildEmptyText('暂无推荐')
          : SizedBox(
              height: TvVideoCard.height + 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _recommends.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final videoInfo = _recommends[index];
                  return TvVideoCard(
                    videoInfo: videoInfo,
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => TvVideoDetailScreen(
                            videoInfo: videoInfo,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  /// 构建底部操作。
  Widget _buildBottomActions() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 12,
        children: [
          _TvDetailActionButton(
            label: '回到顶部',
            icon: LucideIcons.arrowUp,
            onPressed: _scrollToTop,
          ),
        ],
      ),
    );
  }

  /// 构建空状态文案。
  Widget _buildEmptyText(String text) {
    return Text(
      text,
      style: FontUtils.poppins(
        fontSize: 16,
        color: const Color(0xFF98A2A8),
      ),
    );
  }
}

/// TV 详情页分区。
class _TvDetailSection extends StatelessWidget {
  /// 创建 TV 详情页分区。
  const _TvDetailSection({
    required this.title,
    required this.child,
  });

  /// 分区标题。
  final String title;

  /// 分区内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FontUtils.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// TV 详情页操作按钮。
class _TvDetailActionButton extends StatelessWidget {
  /// 创建 TV 详情页操作按钮。
  const _TvDetailActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  /// 按钮文案。
  final String label;

  /// 按钮图标。
  final IconData icon;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 图标颜色。
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onPressed,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xCC1B2127),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: FontUtils.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// TV 详情页纯文字选项。
///
/// 用于选集分组这类轻量级切换，不展示按钮底色和边框。
class _TvTextChoice extends StatelessWidget {
  /// 创建 TV 详情页纯文字选项。
  const _TvTextChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.throttleGroupKey,
  });

  /// 文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 长按方向键节流分组 Key。
  final Object? throttleGroupKey;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      onPressed: onPressed,
      // 分组切换改成纯文字列表后，需要保留逐项经过的焦点节奏。
      directionalRepeatThrottleGroupKey: throttleGroupKey,
      builder: (context, hasFocus) {
        final highlight = hasFocus || selected;
        return AnimatedScale(
          scale: hasFocus ? 1.08 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FontUtils.poppins(
                fontSize: 15,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? palette.accent : const Color(0xFFD9E2E0),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TV 详情页选项按钮。
class _TvChoiceChip extends StatelessWidget {
  /// 创建 TV 详情页选项按钮。
  const _TvChoiceChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  /// 文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      onPressed: onPressed,
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minWidth: 86, maxWidth: 180),
          height: 42,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? palette.accent : const Color(0xFF15191B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFocus
                  ? Colors.white
                  : selected
                      ? palette.accent
                      : const Color(0xFF293136),
              width: hasFocus ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 15,
              color: selected ? palette.selectedText : const Color(0xFFD9E2E0),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}
