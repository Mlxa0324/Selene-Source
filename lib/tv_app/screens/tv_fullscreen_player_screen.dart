import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/utils/font_utils.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

/// TV 全屏播放器构建函数。
typedef TvFullscreenPlayerBuilder = Widget Function(
  BuildContext context,
  void Function(VideoPlayerWidgetController controller) onControllerCreated,
);

/// TV 全屏播放器播放控制接口。
///
/// 测试和生产播放器都通过该接口完成播放、暂停和进度跳转。
abstract class TvFullscreenPlaybackController {
  /// 当前播放位置。
  Duration? get currentPosition;

  /// 当前视频总时长。
  Duration? get totalDuration;

  /// 当前是否正在播放。
  bool get isPlaying;

  /// 播放视频。
  Future<void> play();

  /// 暂停视频。
  Future<void> pause();

  /// 跳转到指定播放位置。
  Future<void> seekTo(Duration position);
}

/// TV 全屏播放器遥控器 seek 步长规则。
///
/// 左右键长按时从 5 秒逐步加速到 29 秒，避免一开始跳得太猛。
class TvFullscreenSeekStep {
  /// 私有构造，避免工具类被实例化。
  const TvFullscreenSeekStep._();

  /// 起始 seek 秒数。
  static const int minSeconds = 5;

  /// 长按加速后的最大 seek 秒数。
  static const int maxSeconds = 29;

  /// 从起始到最大步长的加速时间。
  static const Duration rampDuration = Duration(seconds: 3);

  /// 根据长按持续时间计算当前 seek 秒数。
  static int secondsForElapsed(Duration elapsed) {
    final progress = elapsed.inMilliseconds <= 0
        ? 0.0
        : (elapsed.inMilliseconds / rampDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    return (minSeconds + (maxSeconds - minSeconds) * progress).round();
  }
}

/// TV 全屏播放器页面。
///
/// 该页面为 TV 端独立播放器壳，播放器画面上方仅展示信息装饰，
/// 遥控器下键弹出底部一二级菜单，返回键优先关闭菜单。
class TvFullscreenPlayerScreen extends StatefulWidget {
  /// 创建 TV 全屏播放器页面。
  const TvFullscreenPlayerScreen({
    super.key,
    required this.videoInfo,
    required this.currentDetail,
    required this.sources,
    this.initialEpisodeIndex = 0,
    this.stype,
    this.playerBuilder,
    this.playbackController,
  });

  /// 入口视频信息。
  final VideoInfo videoInfo;

  /// 当前播放源详情。
  final SearchResult? currentDetail;

  /// 可切换播放源。
  final List<SearchResult> sources;

  /// 初始选集下标。
  final int initialEpisodeIndex;

  /// 搜索类型，保留给后续 TV 播放策略使用。
  final String? stype;

  /// 测试或特殊场景播放器替换入口。
  final TvFullscreenPlayerBuilder? playerBuilder;

  /// 测试注入的播放控制器。
  final TvFullscreenPlaybackController? playbackController;

  @override
  State<TvFullscreenPlayerScreen> createState() =>
      _TvFullscreenPlayerScreenState();
}

class _TvFullscreenPlayerScreenState extends State<TvFullscreenPlayerScreen> {
  /// 根焦点节点，用于接收遥控器下键和返回键。
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'tv-fullscreen-root');

  /// 一级菜单焦点节点。
  late final List<FocusNode> _menuFocusNodes = List<FocusNode>.generate(
    _menuTabs.length,
    (index) => FocusNode(debugLabel: 'tv-player-menu-$index'),
  );

  /// 播放器控制器。
  VideoPlayerWidgetController? _playerController;

  /// 当前播放源详情。
  late SearchResult? _currentDetail = widget.currentDetail;

  /// 当前选集下标。
  late int _episodeIndex = _safeInitialEpisodeIndex();

  /// 当前播放地址。
  String? _playUrl;

  /// 当前菜单是否展示。
  bool _menuVisible = false;

  /// 当前一级菜单下标。
  int _activeMenuIndex = 0;

  /// 当前画面比例。
  VideoFitType _fitType = VideoFitType.contain;

  /// 当前播放倍速。
  double _playbackSpeed = 1.0;

  /// TV 菜单里的弹幕开关展示状态。
  bool _danmakuEnabled = true;

  /// 当前时间刷新定时器。
  Timer? _clockTimer;

  /// seek 提示隐藏定时器。
  Timer? _seekOverlayTimer;

  /// 顶部右侧当前时间。
  late String _clockText;

  /// 当前 seek 预览位置。
  Duration? _seekPreviewPosition;

  /// 当前 seek 提示总时长。
  Duration? _seekPreviewDuration;

  /// 当前 seek 方向，-1 为后退，1 为前进。
  int _seekDirection = 0;

  /// 当前方向键连续 seek 起始时间。
  DateTime? _seekHoldStartAt;

  /// 上一次 seek 按键触发时间。
  DateTime? _lastSeekAt;

  /// seek 中心提示是否展示。
  bool _seekOverlayVisible = false;

  /// 播放地址解析任务序号，避免异步回写旧地址。
  int _loadToken = 0;

  /// TV 播放器一级菜单。
  static const List<String> _menuTabs = [
    '播放列表',
    '播放线路',
    '画面比例',
    '倍速',
    '其它',
  ];

  /// 顶部暂停态操作提示。
  static const String _pausedHintText = '按【菜单键】或【下键】选择集数、线路和播放设置';

  /// 安全刷新壳层状态。
  ///
  /// 播放器会在子组件 `initState/build` 过程中同步回调控制器创建和播放状态。
  /// 这些场景如果直接 `setState`，会触发 build 阶段重建异常，因此统一延后到本帧结束。
  void _scheduleChromeRefresh() {
    if (!mounted) {
      return;
    }

    final schedulerPhase = SchedulerBinding.instance.schedulerPhase;
    final isBuildRelatedPhase =
        schedulerPhase == SchedulerPhase.persistentCallbacks ||
            schedulerPhase == SchedulerPhase.transientCallbacks ||
            schedulerPhase == SchedulerPhase.midFrameMicrotasks;

    if (isBuildRelatedPhase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _clockText = _formatClock(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _clockText = _formatClock(DateTime.now()));
    });
    _loadCurrentEpisode(updateController: false);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _playerController?.dispose();
    _rootFocusNode.dispose();
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// 将当前时间格式化为顶部短时间。
  static String _formatClock(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 获取安全初始选集下标。
  int _safeInitialEpisodeIndex() {
    final total = widget.currentDetail?.episodes.length ?? 0;
    if (total <= 0) {
      return 0;
    }
    return widget.initialEpisodeIndex.clamp(0, total - 1).toInt();
  }

  /// 获取当前播放源的选集地址列表。
  List<String> get _episodes => _currentDetail?.episodes ?? const <String>[];

  /// 获取当前播放源的选集标题列表。
  List<String> get _episodeTitles =>
      _currentDetail?.episodesTitles ?? const <String>[];

  /// 当前标题。
  String get _title => _currentDetail?.title ?? widget.videoInfo.title;

  /// 当前年份。
  String get _year => _currentDetail?.year ?? widget.videoInfo.year;

  /// 当前来源名称。
  String get _sourceName =>
      _currentDetail?.sourceName ?? widget.videoInfo.sourceName;

  /// 当前选集展示文案。
  String get _episodeLabel {
    final titles = _episodeTitles;
    if (titles.length == _episodes.length && _episodeIndex < titles.length) {
      final title = titles[_episodeIndex];
      if (title.trim().isNotEmpty) {
        return title;
      }
    }
    return '第${_episodeIndex + 1}集';
  }

  /// 加载当前选集地址。
  Future<void> _loadCurrentEpisode({required bool updateController}) async {
    final token = ++_loadToken;
    if (_episodes.isEmpty) {
      setState(() => _playUrl = null);
      return;
    }

    final index = _episodeIndex.clamp(0, _episodes.length - 1).toInt();
    var url = _episodes[index];
    final proxy = await UserDataService.getM3u8ProxyUrl();
    if (proxy.isNotEmpty && url.startsWith('http')) {
      url = '$proxy${Uri.encodeComponent(url)}';
    }

    if (!mounted || token != _loadToken) {
      return;
    }

    setState(() => _playUrl = url);
    if (updateController) {
      await _playerController?.updateDataSource(url);
    }
  }

  /// 处理全屏播放器键盘和遥控器按键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_menuVisible) {
      if (_isBackKey(event.logicalKey)) {
        _hideMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _showMenu();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      unawaited(_togglePlayPause());
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekByDirection(-1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekByDirection(1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 判断是否为返回类按键。
  bool _isBackKey(LogicalKeyboardKey key) {
    return TvBackIntent.isBackKey(key);
  }

  /// 展示底部菜单。
  void _showMenu() {
    _resetSeekState();
    setState(() {
      _menuVisible = true;
      _seekOverlayVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _menuFocusNodes[_activeMenuIndex].requestFocus();
    });
  }

  /// 切换播放和暂停。
  Future<void> _togglePlayPause() async {
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      if (injectedController.isPlaying) {
        await injectedController.pause();
      } else {
        await injectedController.play();
      }
      return;
    }

    final controller = _playerController;
    if (controller == null) {
      return;
    }
    if (controller.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    // 播放/暂停切换后主动刷新壳层状态，确保暂停态 UI 立即同步。
    if (mounted) {
      setState(() {});
    }
  }

  /// 按左右方向键执行相对 seek。
  void _seekByDirection(int direction) {
    final duration = _currentPlaybackDuration;
    if (duration <= Duration.zero) {
      return;
    }

    final now = DateTime.now();
    final lastSeekAt = _lastSeekAt;
    final shouldReset = _seekDirection != direction ||
        lastSeekAt == null ||
        now.difference(lastSeekAt) > const Duration(milliseconds: 900);
    if (shouldReset) {
      _seekDirection = direction;
      _seekHoldStartAt = now;
      _seekPreviewPosition = _currentPlaybackPosition;
    }
    _lastSeekAt = now;

    final elapsed = now.difference(_seekHoldStartAt ?? now);
    final seconds = TvFullscreenSeekStep.secondsForElapsed(elapsed);
    final basePosition = _seekPreviewPosition ?? _currentPlaybackPosition;
    final target = _clampDuration(
      basePosition + Duration(seconds: seconds * direction),
      Duration.zero,
      duration,
    );

    setState(() {
      _seekPreviewPosition = target;
      _seekPreviewDuration = duration;
      _seekOverlayVisible = true;
    });
    unawaited(_seekTo(target));
    _scheduleSeekOverlayHide();
  }

  /// 获取当前播放位置，播放器尚未准备好时回退播放记录进度。
  Duration get _currentPlaybackPosition {
    return widget.playbackController?.currentPosition ??
        _playerController?.currentPosition ??
        Duration(seconds: widget.videoInfo.playTime);
  }

  /// 获取当前播放总时长，播放器尚未准备好时回退播放记录总时长。
  Duration get _currentPlaybackDuration {
    return widget.playbackController?.totalDuration ??
        _playerController?.duration ??
        Duration(seconds: widget.videoInfo.totalTime);
  }

  /// 当前播放器是否处于播放中。
  ///
  /// 控制器尚未创建时按“播放中”处理，避免页面初次进入时误闪暂停壳层。
  bool get _isPlaybackPlaying {
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      return injectedController.isPlaying;
    }
    final controller = _playerController;
    if (controller != null) {
      return controller.isPlaying;
    }
    return true;
  }

  /// 是否显示暂停/拖动时的播放器信息壳层。
  bool get _shouldShowPlaybackChrome {
    return !_menuVisible && (_seekOverlayVisible || !_isPlaybackPlaying);
  }

  /// 是否显示中心播放按钮。
  bool get _shouldShowCenterPlayButton {
    return !_menuVisible && !_isPlaybackPlaying;
  }

  /// 是否处于拖动进度中的快进/快退态。
  bool get _isSeekingPreviewOnly {
    return !_menuVisible && _seekOverlayVisible && _isPlaybackPlaying;
  }

  /// 执行播放器 seek。
  Future<void> _seekTo(Duration position) async {
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      await injectedController.seekTo(position);
      return;
    }
    await _playerController?.seekTo(position);
  }

  /// 限制时间在合法播放区间内。
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    final milliseconds = value.inMilliseconds.clamp(
      min.inMilliseconds,
      max.inMilliseconds,
    );
    return Duration(milliseconds: milliseconds);
  }

  /// 安排 seek 提示自动隐藏。
  void _scheduleSeekOverlayHide() {
    _seekOverlayTimer?.cancel();
    _seekOverlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      setState(() => _seekOverlayVisible = false);
      _resetSeekState();
    });
  }

  /// 重置连续 seek 状态。
  void _resetSeekState() {
    _seekOverlayTimer?.cancel();
    _seekDirection = 0;
    _seekHoldStartAt = null;
    _lastSeekAt = null;
    _seekPreviewPosition = null;
    _seekPreviewDuration = null;
  }

  /// 隐藏底部菜单。
  void _hideMenu() {
    setState(() => _menuVisible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rootFocusNode.requestFocus();
      }
    });
  }

  /// 处理系统返回。
  void _handlePopInvoked(bool didPop) {
    if (didPop || !_menuVisible) {
      return;
    }
    _hideMenu();
  }

  /// 切换一级菜单。
  void _switchPrimaryMenu(int index) {
    if (_activeMenuIndex == index) {
      return;
    }
    setState(() => _activeMenuIndex = index);
  }

  /// 切换选集。
  void _switchEpisode(int index) {
    if (index < 0 || index >= _episodes.length) {
      return;
    }
    setState(() => _episodeIndex = index);
    _loadCurrentEpisode(updateController: true);
  }

  /// 切换播放线路。
  void _switchSource(SearchResult source) {
    setState(() {
      _currentDetail = source;
      _episodeIndex = 0;
    });
    _loadCurrentEpisode(updateController: true);
  }

  /// 切换画面比例。
  void _switchFit(VideoFitType fitType) {
    setState(() => _fitType = fitType);
    _playerController?.setVideoFit(fitType);
  }

  /// 切换播放倍速。
  Future<void> _switchSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _playerController?.setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_menuVisible,
      onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
      child: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          key: const ValueKey('tv-fullscreen-player'),
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(child: _buildPlayer()),
              if (_shouldShowPlaybackChrome)
                Positioned.fill(child: _buildPlaybackChromeScrim()),
              if (_shouldShowPlaybackChrome) _buildTopDecorations(),
              if (_shouldShowCenterPlayButton) _buildCenterPlayButton(),
              if (_shouldShowPlaybackChrome) _buildBottomProgressBar(),
              if (_seekOverlayVisible) _buildSeekOverlay(),
              if (_menuVisible) _buildBottomMenu(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建播放器画面。
  Widget _buildPlayer() {
    return widget.playerBuilder?.call(
          context,
          (controller) {
            _playerController = controller;
            _scheduleChromeRefresh();
          },
        ) ??
        VideoPlayerWidget(
          surface: VideoPlayerSurface.desktop,
          url: _playUrl,
          videoTitle: _title,
          videoYear: _year,
          currentEpisodeIndex: _episodeIndex,
          totalEpisodes: _episodes.length,
          episodesTitles: _episodeTitles,
          sourceName: _sourceName,
          initialFitType: _fitType,
          isShortDrama: false,
          showControls: false,
          onControllerCreated: (controller) {
            _playerController = controller;
            _scheduleChromeRefresh();
          },
          onPlay: () {
            _scheduleChromeRefresh();
          },
          onPause: () {
            _scheduleChromeRefresh();
          },
          onVideoCompleted: () {},
        );
  }

  /// 构建暂停态顶部和底部的可读性遮罩。
  Widget _buildPlaybackChromeScrim() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.34),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.28),
            ],
            stops: const [0.0, 0.18, 0.72, 1.0],
          ),
        ),
      ),
    );
  }

  /// 构建顶部说明和装饰层。
  Widget _buildTopDecorations() {
    final showHintText = !_isSeekingPreviewOnly;
    return Positioned(
      key: const ValueKey('tv-fullscreen-top-decorations'),
      left: 34,
      right: 34,
      top: 14,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 38,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 左右两组分别贴顶部两侧，避免长标题或提示文字把装饰信息挤到中间。
                final contentWidth = constraints.maxWidth;
                final leftWidth = contentWidth * (showHintText ? 0.45 : 0.58);
                final rightWidth = contentWidth * (showHintText ? 0.52 : 0.34);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        key: const ValueKey('tv-fullscreen-top-left'),
                        width: leftWidth,
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.arrowLeft,
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Text(
                                '$_title | $_episodeLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FontUtils.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        key: const ValueKey('tv-fullscreen-top-right'),
                        width: rightWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (showHintText) ...[
                              Flexible(
                                child: Text(
                                  _pausedHintText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: FontUtils.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.94),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                            ],
                            const Icon(
                              LucideIcons.grip,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _clockText,
                              style: FontUtils.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建中心播放按钮。
  Widget _buildCenterPlayButton() {
    return Center(
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('tv-fullscreen-center-play'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.play,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// 构建暂停态和拖动进度时的底部细进度条。
  Widget _buildBottomProgressBar() {
    final palette = TvTheme.of(context);
    final duration = _seekPreviewDuration ?? _currentPlaybackDuration;
    final position = _seekPreviewPosition ?? _currentPlaybackPosition;
    final clampedPosition = _clampDuration(position, Duration.zero, duration);
    final progress = duration <= Duration.zero
        ? 0.0
        : (clampedPosition.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0);
    final statusIcon =
        _isPlaybackPlaying ? LucideIcons.pause : LucideIcons.play;

    return Positioned(
      left: 34,
      right: 34,
      bottom: 26,
      child: IgnorePointer(
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: Row(
            children: [
              Icon(
                statusIcon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formatProgressBarDuration(clampedPosition),
                style: FontUtils.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  key: const ValueKey('tv-fullscreen-bottom-progress'),
                  height: 18,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      final playedWidth = trackWidth * progress;
                      final knobLeft =
                          (playedWidth - 5).clamp(0.0, trackWidth - 10.0);
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.54),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Container(
                            width: playedWidth,
                            height: 3,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Positioned(
                            left: knobLeft,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                _formatProgressBarDuration(duration),
                style: FontUtils.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                LucideIcons.expand,
                size: 16,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建左右键拖动进度时的中心时间提示。
  Widget _buildSeekOverlay() {
    final position = _seekPreviewPosition ?? _currentPlaybackPosition;
    final duration = _seekPreviewDuration ?? _currentPlaybackDuration;
    final icon =
        _seekDirection < 0 ? LucideIcons.rewind : LucideIcons.fastForward;
    return Center(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _seekOverlayVisible ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            key: const ValueKey('tv-fullscreen-seek-overlay'),
            width: 244,
            height: 94,
            decoration: BoxDecoration(
              color: const Color(0xFF10161D).withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 31,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatDuration(position)}/${_formatDuration(duration)}',
                  style: FontUtils.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 格式化播放时间。
  String _formatDuration(Duration duration) {
    final safeDuration = duration < Duration.zero ? Duration.zero : duration;
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化底部进度条时间。
  ///
  /// 底部进度条对齐电视端播放器习惯，小于 1 小时时也固定显示 `mm:ss`。
  String _formatProgressBarDuration(Duration duration) {
    final safeDuration = duration < Duration.zero ? Duration.zero : duration;
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  /// 构建底部一二级菜单。
  Widget _buildBottomMenu() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: const ValueKey('tv-fullscreen-menu'),
        constraints: const BoxConstraints(minHeight: 230),
        padding: const EdgeInsets.fromLTRB(42, 28, 42, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF111822).withValues(alpha: 0.94),
              const Color(0xFF060A10).withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecondaryMenu(),
            const SizedBox(height: 30),
            _buildPrimaryMenu(),
          ],
        ),
      ),
    );
  }

  /// 构建一级菜单。
  Widget _buildPrimaryMenu() {
    return SizedBox(
      height: 58,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var index = 0; index < _menuTabs.length; index++) ...[
              _TvPlayerMenuButton(
                focusNode: _menuFocusNodes[index],
                label: _menuTabs[index],
                selected: _activeMenuIndex == index,
                minWidth: 120,
                onFocus: () => _switchPrimaryMenu(index),
                onPressed: () => _switchPrimaryMenu(index),
              ),
              if (index != _menuTabs.length - 1) const SizedBox(width: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建当前一级菜单对应的二级菜单。
  Widget _buildSecondaryMenu() {
    switch (_menuTabs[_activeMenuIndex]) {
      case '播放线路':
        return _buildSourceChoices();
      case '画面比例':
        return _buildFitChoices();
      case '倍速':
        return _buildSpeedChoices();
      case '其它':
        return _buildOtherChoices();
      case '播放列表':
      default:
        return _buildEpisodeChoices();
    }
  }

  /// 构建播放列表二级菜单。
  Widget _buildEpisodeChoices() {
    if (_episodes.isEmpty) {
      return _buildHint('暂无选集');
    }
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-episode-list'),
      itemCount: _episodes.length,
      itemBuilder: (index) {
        final label = _episodeTitles.length == _episodes.length
            ? _episodeTitles[index]
            : '第${index + 1}集';
        return _TvPlayerMenuButton(
          label: label.isEmpty ? '第${index + 1}集' : label,
          selected: index == _episodeIndex,
          minWidth: 104,
          onPressed: () => _switchEpisode(index),
        );
      },
    );
  }

  /// 构建播放线路二级菜单。
  Widget _buildSourceChoices() {
    if (widget.sources.isEmpty) {
      return _buildHint('暂无线路');
    }
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-source-list'),
      itemCount: widget.sources.length,
      itemBuilder: (index) {
        final source = widget.sources[index];
        final selected = source.source == _currentDetail?.source &&
            source.id == _currentDetail?.id;
        return _TvPlayerMenuButton(
          label: source.sourceName,
          selected: selected,
          minWidth: 128,
          onPressed: () => _switchSource(source),
        );
      },
    );
  }

  /// 构建画面比例二级菜单。
  Widget _buildFitChoices() {
    const fits = [
      (VideoFitType.contain, '适应'),
      (VideoFitType.fill, '填充'),
      (VideoFitType.fitWidth, '宽度'),
      (VideoFitType.fitHeight, '高度'),
    ];
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-fit-list'),
      itemCount: fits.length,
      itemBuilder: (index) {
        final item = fits[index];
        return _TvPlayerMenuButton(
          label: item.$2,
          selected: item.$1 == _fitType,
          minWidth: 126,
          onPressed: () => _switchFit(item.$1),
        );
      },
    );
  }

  /// 构建倍速二级菜单。
  Widget _buildSpeedChoices() {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-speed-list'),
      itemCount: speeds.length,
      itemBuilder: (index) {
        final speed = speeds[index];
        return _TvPlayerMenuButton(
          label: '${speed}x',
          selected: (speed - _playbackSpeed).abs() < 0.01,
          minWidth: 110,
          onPressed: () => _switchSpeed(speed),
        );
      },
    );
  }

  /// 构建其它二级菜单。
  Widget _buildOtherChoices() {
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-other-list'),
      itemCount: 3,
      itemBuilder: (index) {
        if (index == 0) {
          return _TvPlayerMenuButton(
            label: '片头 00:00',
            selected: false,
            minWidth: 138,
            onPressed: () {},
          );
        }
        if (index == 1) {
          return _TvPlayerMenuButton(
            label: '片尾 00:00',
            selected: false,
            minWidth: 138,
            onPressed: () {},
          );
        }
        return _TvPlayerMenuButton(
          label: _danmakuEnabled ? '弹幕 开' : '弹幕 关',
          selected: _danmakuEnabled,
          minWidth: 138,
          onPressed: () {
            setState(() => _danmakuEnabled = !_danmakuEnabled);
          },
        );
      },
    );
  }

  /// 构建横向二级菜单列表。
  Widget _buildHorizontalChoices({
    required Key key,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        key: key,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => itemBuilder(index),
      ),
    );
  }

  /// 构建空提示。
  Widget _buildHint(String text) {
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: FontUtils.poppins(
            fontSize: 18,
            color: const Color(0xFF98A2A8),
          ),
        ),
      ),
    );
  }
}

/// TV 播放器菜单按钮。
class _TvPlayerMenuButton extends StatelessWidget {
  /// 创建 TV 播放器菜单按钮。
  const _TvPlayerMenuButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.onFocus,
    this.minWidth = 118,
  });

  /// 按钮文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 焦点进入回调。
  final VoidCallback? onFocus;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 最小宽度。
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      onPressed: onPressed,
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      builder: (context, hasFocus) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 56,
          constraints: BoxConstraints(minWidth: minWidth, maxWidth: 220),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: selected ? palette.accent : const Color(0xFF303741),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FontUtils.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
