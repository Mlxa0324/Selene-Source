import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/tv_layout.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_confirm_dialog.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_route.dart';
import 'package:selene/tv_app/widgets/tv_section_title.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

/// TV 视频库列表数据加载函数。
typedef TvVideoLibraryLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
);

/// TV 视频库详情页构建函数。
typedef TvVideoLibraryDetailPageBuilder = Widget Function(VideoInfo videoInfo);

/// TV 视频库单条删除函数。
typedef TvVideoLibraryDeleteVideo = Future<bool> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

/// TV 视频库清空函数。
typedef TvVideoLibraryClearVideos = Future<bool> Function(
  BuildContext context,
);

/// TV 独立视频库页面。
///
/// 用于承载播放历史、收藏夹等需要整页浏览的视频列表。
class TvVideoLibraryScreen extends StatefulWidget {
  /// 创建 TV 独立视频库页面。
  const TvVideoLibraryScreen({
    super.key,
    required this.title,
    required this.loadVideos,
    this.buildDetailPage,
    this.onDeleteVideo,
    this.onClearVideos,
    this.popResultOnBack,
  });

  /// 页面标题。
  final String title;

  /// 页面数据加载函数。
  final TvVideoLibraryLoader loadVideos;

  /// 详情页构建函数。
  final TvVideoLibraryDetailPageBuilder? buildDetailPage;

  /// 单条删除函数。
  final TvVideoLibraryDeleteVideo? onDeleteVideo;

  /// 清空列表函数。
  final TvVideoLibraryClearVideos? onClearVideos;

  /// 返回时携带的路由结果。
  ///
  /// 播放历史页会传 `true`，用于通知首页刷新继续观看数据。
  final bool? popResultOnBack;

  @override
  State<TvVideoLibraryScreen> createState() => _TvVideoLibraryScreenState();
}

class _TvVideoLibraryScreenState extends State<TvVideoLibraryScreen> {
  /// 视频库 Grid 焦点记忆分组。
  ///
  /// 让顶部“删除全部”按钮回到内容区时，优先恢复到用户离开前停留的那张卡片。
  Object get _gridFocusMemoryGroupKey => 'tv-video-library-grid-${widget.title}';

  /// 页面内容顶部留白。
  ///
  /// 独立播放历史页和收藏夹页没有首页那样的顶部导航，
  /// 需要额外留出一点呼吸空间，避免标题区紧贴安全区上边缘。
  static const double _contentTopPadding = 24.0;

  /// 固定头部与下方 Grid 的间距。
  ///
  /// 让标题区常驻顶部后，仍保留原来标题与首行卡片之间的呼吸感。
  static const double _headerBottomSpacing = 24.0;

  /// Grid 顶部焦点安全留白。
  ///
  /// 播放历史和收藏夹改成“固定头 + 裁剪内容区”后，
  /// 首排卡片获焦时会整体放大并带有向上的描边和阴影。
  /// 这里额外补一段顶部安全空间，避免第一排获焦时被内容区上边缘裁掉。
  static const double _gridTopFocusSafePadding =
      (TvVideoCard.height * (TvVideoCard.focusedScale - 1) / 2) + 8;

  /// 列表数据加载任务。
  Future<List<VideoInfo>>? _videosFuture;

  /// Grid 第一张卡片焦点节点。
  ///
  /// 页面首次进入后，会把首焦点显式交给它，
  /// 避免根级返回键焦点把默认下移目标算到中间卡片上。
  final FocusNode _firstVideoFocusNode = FocusNode();

  /// 最近一次在视频列表内获焦的卡片节点。
  ///
  /// 顶部“删除全部”按钮向下返回时，优先回到它，保持用户离开列表前的停留位置。
  FocusNode? _lastFocusedGridItemNode;

  /// 是否已经派发过首屏内容焦点。
  ///
  /// 同一个页面实例只在首屏数据准备完成后派发一次，
  /// 避免删除、刷新或从详情页返回时强行打断用户当前停留位置。
  bool _didDispatchInitialGridFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _videosFuture ??= widget.loadVideos(context);
  }

  @override
  void dispose() {
    _firstVideoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageBackgroundColor = TvTheme.backgroundOf(context).color;
    return TvBackHandler(
      autofocus: true,
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        key: ValueKey('tv-video-library-screen-${widget.title}'),
        backgroundColor: pageBackgroundColor,
        body: SafeArea(
          child: FutureBuilder<List<VideoInfo>>(
            future: _videosFuture,
            builder: (context, snapshot) {
              final videos = snapshot.data ?? const <VideoInfo>[];
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              _dispatchInitialGridFocusIfNeeded(
                videos: videos,
                isLoading: isLoading,
              );
              return Padding(
                padding: const EdgeInsets.only(top: _contentTopPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPinnedHeader(),
                    const SizedBox(height: _headerBottomSpacing),
                    Expanded(
                      child: ClipRect(
                        key: const ValueKey('tv-video-library-grid-clip'),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: _gridTopFocusSafePadding,
                          ),
                          child: TvVideoGrid(
                            title: widget.title,
                            showTitle: false,
                            videos: videos,
                            isLoading: isLoading,
                            focusMemoryGroupKey: _gridFocusMemoryGroupKey,
                            firstItemFocusNode: _firstVideoFocusNode,
                            onVideoItemFocused: _rememberLastFocusedGridItem,
                            onVideoPressed: _openVideo,
                            onVideoLongPressed: widget.onDeleteVideo == null
                                ? null
                                : (videoInfo) =>
                                    _deleteVideo(context, videoInfo),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 在首屏数据准备完成后，把焦点显式交给第一张卡片。
  ///
  /// 独立视频库页进入时，页面根节点会先拿到返回键焦点。
  /// 如果不主动把焦点下发到第一张卡片，首次按下方向键时，
  /// Flutter 默认的几何寻焦可能会直接跳到中间某一张卡片。
  void _dispatchInitialGridFocusIfNeeded({
    required List<VideoInfo> videos,
    required bool isLoading,
  }) {
    if (_didDispatchInitialGridFocus || isLoading || videos.isEmpty) {
      return;
    }

    _didDispatchInitialGridFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _firstVideoFocusNode.requestFocus();
      _lastFocusedGridItemNode = _firstVideoFocusNode;
    });
  }

  /// 记录视频列表最近一次真正获焦的卡片节点。
  ///
  /// 顶部“删除全部”按钮返回列表时会优先恢复到这里。
  void _rememberLastFocusedGridItem(FocusNode focusNode) {
    _lastFocusedGridItemNode = focusNode;
  }

  /// 构建固定在页面顶部的标题区。
  ///
  /// 播放历史和收藏夹按最新交互要求把标题与“删除全部”按钮固定在顶部，
  /// 这样长列表滚动时也能随时看到当前页面名称，并快速执行清空操作。
  Widget _buildPinnedHeader() {
    return ColoredBox(
      color: TvTheme.backgroundOf(context).color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TvLayout.pageHorizontalPadding + TvVideoGrid.focusSafePadding,
          0,
          TvLayout.pageHorizontalPadding + TvVideoGrid.focusSafePadding,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: TvSectionTitle(title: widget.title),
            ),
            if (widget.onClearVideos != null) ...[
              const SizedBox(width: 16),
              TvVideoGridActionButton(
                key: const ValueKey('tv-video-library-clear-button'),
                label: '删除全部',
                onPressed: () => _clearVideos(context),
                onArrowDown: _restoreGridFocusFromHeader,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 打开当前卡片对应的 TV 详情页。
  Future<void> _openVideo(VideoInfo videoInfo) async {
    final detailPage = widget.buildDetailPage?.call(videoInfo) ??
        TvVideoDetailScreen(videoInfo: videoInfo);
    final shouldRefresh = await TvRoute.push<bool>(context, detailPage);
    if (!mounted || shouldRefresh != true) {
      return;
    }
    setState(() {
      _videosFuture = widget.loadVideos(context);
    });
  }

  /// 删除当前视频条目。
  Future<void> _deleteVideo(
    BuildContext pageContext,
    VideoInfo videoInfo,
  ) async {
    final confirmed = await _showConfirmDialog(
      context: pageContext,
      title: widget.title.contains('收藏') ? '删除当前收藏' : '删除当前条目',
      message: '确定要删除「${videoInfo.title}」吗？',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final deleted =
        await widget.onDeleteVideo?.call(context, videoInfo) ?? false;
    if (!deleted || !mounted) {
      return;
    }

    setState(() {
      _videosFuture = widget.loadVideos(context);
    });
  }

  /// 清空当前列表。
  Future<void> _clearVideos(BuildContext pageContext) async {
    final confirmed = await _showConfirmDialog(
      context: pageContext,
      title: '清空${widget.title}',
      message: '确定要清空全部内容吗？',
      confirmLabel: '清空',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final cleared = await widget.onClearVideos?.call(context) ?? false;
    if (!cleared || !mounted) {
      return;
    }

    setState(() {
      _videosFuture = widget.loadVideos(context);
    });
  }

  /// 从固定头部回到视频列表。
  ///
  /// 先回到用户离开列表前的最近焦点卡片；若当前还没有焦点记忆，
  /// 再兜底回到第一张卡片，保证“删除全部”向下总能回到内容区。
  void _restoreGridFocusFromHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final lastFocusedGridItemNode = _lastFocusedGridItemNode;
      if (lastFocusedGridItemNode != null &&
          lastFocusedGridItemNode.canRequestFocus) {
        lastFocusedGridItemNode.requestFocus();
        return;
      }
      final restored =
          TvFocusable.requestRememberedFocusForGroup(_gridFocusMemoryGroupKey);
      if (restored) {
        return;
      }
      _firstVideoFocusNode.requestFocus();
    });
  }

  /// 处理页面返回键。
  ///
  /// 返回时直接携带预设路由结果，保证首页能够感知“需要刷新”。
  Future<bool> _handleBackPressed() async {
    if (!mounted) {
      return true;
    }
    Navigator.of(context).pop(widget.popResultOnBack);
    return true;
  }

  /// 展示删除确认弹窗。
  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return showTvConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
  }
}
