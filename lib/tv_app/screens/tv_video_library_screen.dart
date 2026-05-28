import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_confirm_dialog.dart';
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
  /// 列表数据加载任务。
  Future<List<VideoInfo>>? _videosFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _videosFuture ??= widget.loadVideos(context);
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      autofocus: true,
      onBackPressed: _handleBackPressed,
      child: Scaffold(
        key: ValueKey('tv-video-library-screen-${widget.title}'),
        backgroundColor: const Color(0xFF10131D),
        body: SafeArea(
          child: FutureBuilder<List<VideoInfo>>(
            future: _videosFuture,
            builder: (context, snapshot) {
              final videos = snapshot.data ?? const <VideoInfo>[];
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              return TvVideoGrid(
                title: widget.title,
                videos: videos,
                isLoading: isLoading,
                onClearPressed: widget.onClearVideos == null
                    ? null
                    : () => _clearVideos(context),
                onVideoPressed: _openVideo,
                onVideoLongPressed: widget.onDeleteVideo == null
                    ? null
                    : (videoInfo) => _deleteVideo(context, videoInfo),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 打开当前卡片对应的 TV 详情页。
  Future<void> _openVideo(VideoInfo videoInfo) async {
    final detailPage = widget.buildDetailPage?.call(videoInfo) ??
        TvVideoDetailScreen(videoInfo: videoInfo);
    final shouldRefresh = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            TvTheme.wrapScope(
          context: context,
          child: detailPage,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
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
