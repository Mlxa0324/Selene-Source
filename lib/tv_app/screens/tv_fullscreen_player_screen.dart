import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_play_record_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_focusable.dart';
import 'package:selene/tv_app/widgets/tv_focus_scroll.dart';
import 'package:selene/utils/font_utils.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

/// TV 全屏播放器构建函数。
typedef TvFullscreenPlayerBuilder = Widget Function(
  BuildContext context,
  void Function(VideoPlayerWidgetController controller) onControllerCreated,
);

/// TV 全屏播放器测试钩子。
///
/// 仅测试场景使用，用于在占位播放器下模拟“视频播放完成”这类播放器事件。
class TvFullscreenPlayerScreenTestHooks {
  /// 视频播放完成回调。
  VoidCallback? onVideoCompleted;
}

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

  /// 当前是否仍在加载或缓冲。
  bool get isLoading;

  /// 播放视频。
  Future<void> play();

  /// 暂停视频。
  Future<void> pause();

  /// 跳转到指定播放位置。
  Future<void> seekTo(Duration position);
}

/// 提供全屏壳可直接操作的底层播放器控制器。
///
/// 详情页同页全屏覆盖层会复用原有播放器实例，此时全屏壳未必能重新收到
/// `onControllerCreated` 回调，因此需要额外透出当前真实控制器给换集、换源等动作使用。
abstract interface class TvFullscreenVideoControllerProvider {
  /// 当前可用的底层播放器控制器。
  VideoPlayerWidgetController? get videoController;
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
    this.initialPlaybackPosition,
    this.initialPlaybackWasPlaying = true,
    this.stype,
    this.playerBuilder,
    this.playbackController,
    this.onExitRequested,
    this.onEpisodeChanged,
    this.onSourceChanged,
    this.reuseExistingPlayer = false,
    this.testHooks,
  });

  /// 入口视频信息。
  final VideoInfo videoInfo;

  /// 当前播放源详情。
  final SearchResult? currentDetail;

  /// 可切换播放源。
  final List<SearchResult> sources;

  /// 初始选集下标。
  final int initialEpisodeIndex;

  /// 初始续播位置。
  ///
  /// 从详情页小播放器进入全屏时传入当前播放位置，避免全屏播放器重新从头播。
  final Duration? initialPlaybackPosition;

  /// 进入全屏前是否正在播放。
  final bool initialPlaybackWasPlaying;

  /// 搜索类型，保留给后续 TV 播放策略使用。
  final String? stype;

  /// 测试或特殊场景播放器替换入口。
  final TvFullscreenPlayerBuilder? playerBuilder;

  /// 测试注入的播放控制器。
  final TvFullscreenPlaybackController? playbackController;

  /// 是否复用详情页里的同一个播放器实例。
  ///
  /// 同页全屏覆盖层在生产路径下设置为 true，避免重新创建播放器导致黑屏。
  final bool reuseExistingPlayer;

  /// 退出全屏请求回调。
  ///
  /// 详情页内全屏覆盖层会使用该回调隐藏覆盖层，保持共享播放器不销毁。
  final VoidCallback? onExitRequested;

  /// 全屏内选集变化回调。
  final ValueChanged<int>? onEpisodeChanged;

  /// 全屏内播放源变化回调。
  final ValueChanged<SearchResult>? onSourceChanged;

  /// 测试钩子，允许 widget test 模拟播放器完成事件。
  final TvFullscreenPlayerScreenTestHooks? testHooks;

  @override
  State<TvFullscreenPlayerScreen> createState() =>
      _TvFullscreenPlayerScreenState();
}

/// 播放列表最近一次停留的二级菜单行。
enum _TvPlaylistSecondaryRow { episode, group }

class _TvFullscreenPlayerScreenState extends State<TvFullscreenPlayerScreen> {
  /// 根焦点节点，用于接收遥控器下键和返回键。
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'tv-fullscreen-root');

  /// 一级菜单焦点节点。
  late final List<FocusNode> _menuFocusNodes = List<FocusNode>.generate(
    _menuTabs.length,
    (index) => FocusNode(debugLabel: 'tv-player-menu-$index'),
  );

  /// 二级菜单焦点节点。
  final Map<String, FocusNode> _secondaryMenuFocusNodes = {};

  /// 播放列表分组焦点节点。
  final Map<int, FocusNode> _episodeGroupFocusNodes = <int, FocusNode>{};

  /// 播放列表选集定位 Key。
  final Map<int, GlobalKey> _episodeTargetKeys = <int, GlobalKey>{};

  /// 播放列表分组定位 Key。
  final Map<int, GlobalKey> _episodeGroupTargetKeys = <int, GlobalKey>{};

  /// 非播放列表二级菜单最近一次获焦下标。
  ///
  /// 一级菜单上下切换时，优先回到各自最近一次停留的二级项。
  final Map<String, int> _lastFocusedSecondaryIndexes = <String, int>{};

  /// 一级菜单边界抖动 Key 表。
  final Map<int, GlobalKey<TvEdgeShakeState>> _primaryMenuEdgeShakeKeys =
      <int, GlobalKey<TvEdgeShakeState>>{};

  /// 二级菜单边界抖动 Key 表。
  final Map<String, GlobalKey<TvEdgeShakeState>> _secondaryEdgeShakeKeys =
      <String, GlobalKey<TvEdgeShakeState>>{};

  /// 播放列表选集横向滚动控制器。
  final ScrollController _episodeListScrollController = ScrollController();

  /// 播放列表分组横向滚动控制器。
  final ScrollController _episodeGroupListScrollController = ScrollController();

  /// 播放器控制器。
  VideoPlayerWidgetController? _playerController;

  /// 当前播放源详情。
  late SearchResult? _currentDetail = widget.currentDetail;

  /// 当前选集下标。
  late int _episodeIndex = _safeInitialEpisodeIndex();

  /// 当前菜单是否展示。
  bool _menuVisible = false;

  /// 当前一级菜单下标。
  int _activeMenuIndex = 0;

  /// 当前播放列表分组下标。
  int _episodeGroupIndex = 0;

  /// 播放列表最近一次获焦所在行。
  _TvPlaylistSecondaryRow? _lastFocusedPlaylistRow;

  /// 播放列表最近一次获焦的选集下标。
  int? _lastFocusedEpisodeIndex;

  /// 播放列表最近一次获焦的分组下标。
  int? _lastFocusedEpisodeGroupIndex;

  /// 当前画面比例。
  VideoFitType _fitType = VideoFitType.contain;

  /// 当前播放倍速。
  double _playbackSpeed = 1.0;

  /// TV 菜单里的弹幕开关展示状态。
  bool _danmakuEnabled = true;

  /// 片头跳过秒数。
  int _skipIntroSeconds = 0;

  /// 片尾跳过秒数。
  int _skipOutroSeconds = 0;

  /// 当前时间刷新定时器。
  Timer? _clockTimer;

  /// seek 提示隐藏定时器。
  Timer? _seekOverlayTimer;

  /// 底部菜单空闲自动隐藏定时器。
  Timer? _menuAutoHideTimer;

  /// 全屏播放器初始加载保护计时器。
  Timer? _fullscreenLoadingHoldTimer;

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

  /// 全屏播放器是否正在加载当前视频。
  bool _fullscreenPlayerLoading = false;

  /// 播放地址解析任务序号，避免异步回写旧地址。
  int _loadToken = 0;

  /// 上次保存播放进度的时间。
  DateTime? _lastSaveTime;

  /// 上次保存播放进度的秒数。
  int? _lastSavePosition;

  /// 换源记录任务序号，避免快速换源时旧任务误清理。
  int _sourceSwitchRecordSerial = 0;

  /// 初次加载全屏播放器时需要使用的续播位置。
  Duration? _pendingInitialPlaybackPosition;

  /// 是否已经应用过初始续播位置。
  bool _hasAppliedInitialPlaybackPosition = false;

  /// 是否已经把首次播放地址下发给全屏播放器控制器。
  bool _hasRequestedInitialControllerLoad = false;

  /// TV 播放器一级菜单。
  static const List<String> _menuTabs = [
    '播放列表',
    '播放线路',
    '画面比例',
    '倍速',
    '其它',
  ];

  /// TV 播放器画面比例选项。
  static const List<(VideoFitType, String)> _fitOptions = [
    (VideoFitType.contain, '适应'),
    (VideoFitType.fill, '填充'),
    (VideoFitType.fitWidth, '宽度'),
    (VideoFitType.fitHeight, '高度'),
  ];

  /// TV 播放器倍速选项。
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  /// 中心 seek 提示宽度，保持比暂停提示更紧凑。
  static const double _seekOverlayWidth = 232;

  /// 顶部暂停态操作提示。
  static const String _pausedHintText = '按【菜单键】或【下键】选择集数、线路和播放设置';

  /// 播放进度保存间隔，对齐手机端节流策略。
  static const Duration _saveProgressInterval = Duration(seconds: 10);

  /// 进入播放器后短暂保护加载态，避免初始 `playing=false` 被误判为暂停。
  static const Duration _initialFullscreenLoadingHold =
      Duration(milliseconds: 500);

  /// 底部菜单空闲自动隐藏时长。
  static const Duration _menuAutoHideDuration = Duration(seconds: 5);

  /// 全屏播放列表分组大小。
  ///
  /// 采用 20 集一组，减少长剧集的分组切换次数。
  static const int _episodeGroupSize = 20;

  /// 横向列表贴左时的轻微前靠偏移。
  ///
  /// 保持“焦点基本不动，列表自己滚”的观感，让当前项尽量贴在最左侧。
  static const double _menuListLeadingBias = 6;

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
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _bindTestHooks();
    _clockText = _formatClock(DateTime.now());
    _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
    _lastFocusedEpisodeIndex = _episodeIndex;
    _lastFocusedEpisodeGroupIndex = _episodeGroupIndex;
    _pendingInitialPlaybackPosition =
        _safeInitialPlaybackPosition(widget.initialPlaybackPosition);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _clockText = _formatClock(DateTime.now()));
    });
    unawaited(_loadSkipDurations());
    _loadCurrentEpisode(updateController: false);
  }

  @override
  void didUpdateWidget(covariant TvFullscreenPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.testHooks, widget.testHooks)) {
      oldWidget.testHooks?.onVideoCompleted = null;
      _bindTestHooks();
    }

    final sourceChanged =
        oldWidget.currentDetail?.source != widget.currentDetail?.source ||
            oldWidget.currentDetail?.id != widget.currentDetail?.id;
    final episodeChanged =
        oldWidget.initialEpisodeIndex != widget.initialEpisodeIndex;
    if (!widget.reuseExistingPlayer || (!sourceChanged && !episodeChanged)) {
      return;
    }

    final nextEpisodeIndex = _safeInitialEpisodeIndex();
    _currentDetail = widget.currentDetail;
    _episodeIndex = nextEpisodeIndex;
    _episodeGroupIndex = nextEpisodeIndex ~/ _episodeGroupSize;
    _lastFocusedEpisodeIndex = nextEpisodeIndex;
    _lastFocusedEpisodeGroupIndex = _episodeGroupIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureCurrentSelectionsVisible();
      }
    });
  }

  /// 加载播放器片头片尾配置。
  Future<void> _loadSkipDurations() async {
    final introSeconds = await UserDataService.getSkipIntroDuration();
    final outroSeconds = await UserDataService.getSkipOutroDuration();
    if (!mounted) {
      return;
    }
    setState(() {
      _skipIntroSeconds = introSeconds;
      _skipOutroSeconds = outroSeconds;
    });
  }

  /// 过滤非法初始续播位置。
  Duration? _safeInitialPlaybackPosition(Duration? position) {
    if (position == null || position <= Duration.zero) {
      return null;
    }
    return position;
  }

  @override
  void dispose() {
    widget.testHooks?.onVideoCompleted = null;
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _clockTimer?.cancel();
    _seekOverlayTimer?.cancel();
    _menuAutoHideTimer?.cancel();
    _fullscreenLoadingHoldTimer?.cancel();
    _playerController?.removeProgressListener(_onVideoProgressUpdate);
    if (!widget.reuseExistingPlayer) {
      _playerController?.dispose();
    }
    _rootFocusNode.dispose();
    for (final node in _menuFocusNodes) {
      node.dispose();
    }
    for (final node in _secondaryMenuFocusNodes.values) {
      node.dispose();
    }
    for (final node in _episodeGroupFocusNodes.values) {
      node.dispose();
    }
    _episodeListScrollController.dispose();
    _episodeGroupListScrollController.dispose();
    super.dispose();
  }

  /// 绑定测试钩子。
  void _bindTestHooks() {
    widget.testHooks?.onVideoCompleted = _handleVideoCompleted;
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

  /// 获取播放列表分组数量。
  int _episodeGroupCount(int total) {
    if (total <= _episodeGroupSize) {
      return 0;
    }
    return ((total - 1) ~/ _episodeGroupSize) + 1;
  }

  /// 获取播放列表分组标题。
  String _episodeGroupLabel(int groupIndex, int total) {
    final start = groupIndex * _episodeGroupSize + 1;
    final rawEnd = start + _episodeGroupSize - 1;
    final end = rawEnd > total ? total : rawEnd;
    return '${start.toString().padLeft(2, '0')}-${end.toString().padLeft(2, '0')}';
  }

  /// 获取当前分组内的选集下标。
  List<int> _episodeIndexesForGroup(int total, int groupIndex) {
    final start = groupIndex * _episodeGroupSize;
    final rawEnd = start + _episodeGroupSize;
    final end = rawEnd > total ? total : rawEnd;
    return List<int>.generate(end - start, (offset) => start + offset);
  }

  /// 判断指定选集是否属于某个分组。
  bool _episodeBelongsToGroup(int episodeIndex, int groupIndex) {
    if (episodeIndex < 0 || episodeIndex >= _episodes.length) {
      return false;
    }
    return episodeIndex ~/ _episodeGroupSize == groupIndex;
  }

  /// 获取选集定位 Key。
  GlobalKey _episodeTargetKeyFor(int index) {
    return _episodeTargetKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'tv-fullscreen-episode-$index'),
    );
  }

  /// 获取分组定位 Key。
  GlobalKey _episodeGroupTargetKeyFor(int index) {
    return _episodeGroupTargetKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'tv-fullscreen-episode-group-$index'),
    );
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

  /// 当前可直接操作的播放器控制器。
  ///
  /// 独立全屏页走 `_playerController`；详情页同页全屏覆盖层则通过
  /// `TvFullscreenVideoControllerProvider` 读取被复用的详情页播放器控制器。
  VideoPlayerWidgetController? get _effectiveVideoController {
    final localController = _playerController;
    if (localController != null) {
      return localController;
    }
    final playbackController = widget.playbackController;
    if (playbackController is TvFullscreenVideoControllerProvider) {
      return (playbackController as TvFullscreenVideoControllerProvider)
          .videoController;
    }
    return null;
  }

  /// 加载当前选集地址。
  Future<void> _loadCurrentEpisode({required bool updateController}) async {
    final token = ++_loadToken;
    if (_episodes.isEmpty) {
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

    // 首次进入全屏时接续详情页小播放器的当前进度，后续换源换集不复用。
    final startAt = updateController ? _takeInitialPlaybackPosition() : null;
    if (updateController) {
      _markFullscreenPlayerLoading();
      _scheduleChromeRefresh();
      await _effectiveVideoController?.updateDataSource(url, startAt: startAt);
      _fullscreenLoadingHoldTimer?.cancel();
      _fullscreenLoadingHoldTimer = Timer(_initialFullscreenLoadingHold, () {
        if (mounted &&
            token == _loadToken &&
            !(_effectiveVideoController?.isLoading ?? false)) {
          _finishFullscreenPlayerLoading();
        }
      });
    }
  }

  /// 标记全屏播放器开始加载。
  void _markFullscreenPlayerLoading() {
    _fullscreenPlayerLoading = true;
  }

  /// 结束全屏播放器加载态。
  void _finishFullscreenPlayerLoading() {
    if (!_fullscreenPlayerLoading) {
      return;
    }
    _fullscreenPlayerLoading = false;
    _scheduleChromeRefresh();
  }

  /// 取出一次性初始续播位置。
  Duration? _takeInitialPlaybackPosition() {
    if (_hasAppliedInitialPlaybackPosition) {
      return null;
    }
    _hasAppliedInitialPlaybackPosition = true;
    final position = _pendingInitialPlaybackPosition;
    _pendingInitialPlaybackPosition = null;
    return position;
  }

  /// 处理全屏播放器键盘和遥控器按键。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_isBackKey(event.logicalKey)) {
      _handleBackKey();
      return KeyEventResult.handled;
    }

    if (_menuVisible) {
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

  /// 处理全局遥控器按键。
  ///
  /// 共享播放器或平台视图可能不在根 Focus 下，因此全屏页额外监听全局按键。
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    // 根焦点可用时交给 Focus 正常派发，避免同一个遥控器按键被处理两次。
    if (_rootFocusNode.hasFocus) {
      return false;
    }

    final key = event.logicalKey;
    if (_isBackKey(key)) {
      _handleBackKey();
      return true;
    }

    // 菜单打开后，方向键交给菜单项自身处理，避免全局监听抢焦点。
    if (_menuVisible) {
      if (_isMenuInteractionKey(key)) {
        _scheduleMenuAutoHide();
      }
      return false;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _showMenu();
      return true;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      unawaited(_togglePlayPause());
      return true;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekByDirection(-1);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seekByDirection(1);
      return true;
    }

    return false;
  }

  /// 执行 TV 返回语义。
  void _handleBackKey() {
    if (_menuVisible) {
      _hideMenu();
      return;
    }
    final exitRequested = widget.onExitRequested;
    if (exitRequested != null) {
      exitRequested();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  /// 展示底部菜单。
  void _showMenu() {
    _resetSeekState();
    setState(() {
      _menuVisible = true;
      _seekOverlayVisible = false;
    });
    _scheduleMenuAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureCurrentSelectionsVisible();
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
      // 共享详情页播放器时，壳层不会自动收到本页控制器的播放态变更回调，
      // 这里需要主动刷新一次，确保暂停图标、顶部装饰和底部进度条稳定出现。
      _scheduleChromeRefresh();
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

  /// 当前播放器是否仍在加载或缓冲。
  bool get _isPlaybackLoading {
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      return injectedController.isLoading && !injectedController.isPlaying;
    }
    final controller = _playerController;
    if (controller?.isPlaying ?? false) {
      return false;
    }
    return _fullscreenPlayerLoading || (controller?.isLoading ?? false);
  }

  /// 是否显示暂停/拖动时的播放器信息壳层。
  bool get _shouldShowPlaybackChrome {
    return !_menuVisible &&
        !_isPlaybackLoading &&
        (_seekOverlayVisible || !_isPlaybackPlaying);
  }

  /// 是否显示顶部标题和说明装饰层。
  bool get _shouldShowTopDecorations {
    return _menuVisible || _shouldShowPlaybackChrome;
  }

  /// 是否显示中心播放按钮。
  bool get _shouldShowCenterPlayButton {
    return !_menuVisible && !_isPlaybackLoading && !_isPlaybackPlaying;
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

  /// 从菜单跳转到指定播放时间。
  void _seekFromMenu(Duration target) {
    final duration = _currentPlaybackDuration;
    final clampedTarget = duration > Duration.zero
        ? _clampDuration(target, Duration.zero, duration)
        : (target < Duration.zero ? Duration.zero : target);
    setState(() {
      _seekPreviewPosition = clampedTarget;
      _seekPreviewDuration = duration;
      _seekOverlayVisible = true;
    });
    unawaited(_seekTo(clampedTarget));
    _scheduleSeekOverlayHide();
  }

  /// 跳转到片头配置位置。
  void _seekToIntroPosition() {
    _seekFromMenu(Duration(seconds: _skipIntroSeconds));
  }

  /// 跳转到片尾配置位置。
  void _seekToOutroPosition() {
    final duration = _currentPlaybackDuration;
    if (duration <= Duration.zero) {
      return;
    }
    _seekFromMenu(duration - Duration(seconds: _skipOutroSeconds));
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
    _menuAutoHideTimer?.cancel();
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
    _scheduleMenuAutoHide();
    setState(() => _activeMenuIndex = index);
    if (_menuTabs[index] == '播放列表') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _ensureCurrentSelectionsVisible();
      });
    }
  }

  /// 记录普通二级菜单最近一次获焦项。
  void _rememberSecondaryFocus(String group, int index) {
    _scheduleMenuAutoHide();
    _lastFocusedSecondaryIndexes[group] = index;
  }

  /// 记录播放列表最近一次获焦选集。
  void _rememberEpisodeFocus(int index) {
    _scheduleMenuAutoHide();
    _lastFocusedPlaylistRow = _TvPlaylistSecondaryRow.episode;
    _lastFocusedEpisodeIndex = index;
    _schedulePinEpisodeNearLeadingEdge(index);
  }

  /// 记录播放列表最近一次获焦分组。
  ///
  /// 分组获焦时同步切换上方选集页，确保按上返回时能对上当前分组。
  void _rememberEpisodeGroupFocus(int index) {
    _scheduleMenuAutoHide();
    final cameFromGroupRow =
        _lastFocusedPlaylistRow == _TvPlaylistSecondaryRow.group;
    _lastFocusedPlaylistRow = _TvPlaylistSecondaryRow.group;
    _lastFocusedEpisodeGroupIndex = index;
    if (cameFromGroupRow) {
      _schedulePinEpisodeGroupNearLeadingEdge(index);
    }
    final groupEpisodeIndexes = _episodeIndexesForGroup(
      _episodes.length,
      index,
    );
    final hasRememberedEpisodeInGroup = _lastFocusedEpisodeIndex != null &&
        _episodeBelongsToGroup(_lastFocusedEpisodeIndex!, index);
    if (!hasRememberedEpisodeInGroup && groupEpisodeIndexes.isNotEmpty) {
      // 焦点移到新分组即切换选集页，上键回到该分组第一集。
      _lastFocusedEpisodeIndex = groupEpisodeIndexes.first;
    }
    if (_episodeGroupIndex == index) {
      return;
    }
    setState(() => _episodeGroupIndex = index);
  }

  /// 获取二级菜单稳定焦点节点。
  FocusNode _secondaryFocusNodeFor(String group, int index) {
    final key = '$group::$index';
    return _secondaryMenuFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'tv-player-secondary-$key'),
    );
  }

  /// 把焦点送到当前一级菜单对应的二级选项。
  void _focusCurrentSecondaryOption() {
    if (_menuTabs[_activeMenuIndex] == '播放列表') {
      _focusRememberedEpisodeGroupOrEpisodeOption();
      return;
    }

    switch (_menuTabs[_activeMenuIndex]) {
      case '播放线路':
        _focusRememberedSecondaryOption(
          group: 'source',
          fallbackIndex: _currentSourceIndex,
        );
        return;
      case '画面比例':
        _focusRememberedSecondaryOption(
          group: 'fit',
          fallbackIndex: _currentFitIndex,
        );
        return;
      case '倍速':
        _focusRememberedSecondaryOption(
          group: 'speed',
          fallbackIndex: _currentSpeedIndex,
        );
        return;
      case '其它':
        _focusRememberedSecondaryOption(
          group: 'other',
          fallbackIndex: 0,
        );
        return;
      case '播放列表':
      default:
        return;
    }
  }

  /// 把焦点送到当前一级菜单最近一次停留的二级项。
  void _focusRememberedSecondaryOption({
    required String group,
    required int fallbackIndex,
  }) {
    final rememberedIndex = _lastFocusedSecondaryIndexes[group];
    if (rememberedIndex != null &&
        _requestFocusIfMounted(
            _secondaryFocusNodeFor(group, rememberedIndex))) {
      return;
    }
    _requestFocusIfMounted(_secondaryFocusNodeFor(group, fallbackIndex));
  }

  /// 播放列表一级菜单上键优先回到最近一次停留的行。
  void _focusRememberedEpisodeGroupOrEpisodeOption() {
    if (_lastFocusedPlaylistRow == _TvPlaylistSecondaryRow.episode &&
        _lastFocusedEpisodeIndex != null) {
      _focusEpisodeOptionForGroup(
        _lastFocusedEpisodeIndex! ~/ _episodeGroupSize,
        preferredEpisodeIndex: _lastFocusedEpisodeIndex,
      );
      return;
    }

    if (_focusEpisodeGroupOption(
      _lastFocusedEpisodeGroupIndex ?? _episodeGroupIndex,
    )) {
      return;
    }

    _focusEpisodeOptionForGroup(
      _episodeGroupIndex,
      preferredEpisodeIndex: _episodeIndex,
    );
  }

  /// 当目标集数按钮还不在视口内时，回到当前已显示的第一项。
  ///
  /// 这样用户按上至少能稳定回到上面的集数列表，而不会因为目标项未挂载导致焦点丢失。
  bool _focusFirstVisibleEpisodeOption({int? groupIndex}) {
    final groupCount = _episodeGroupCount(_episodes.length);
    final targetGroupIndex = groupCount == 0
        ? 0
        : (groupIndex ?? _episodeGroupIndex).clamp(0, groupCount - 1).toInt();
    final visibleIndexes =
        _episodeIndexesForGroup(_episodes.length, targetGroupIndex);

    // 分组行上键只回到当前分组内的第一集，避免旧分组焦点节点抢焦点。
    for (final index in visibleIndexes) {
      if (_requestFocusIfMounted(_secondaryFocusNodeFor('episode', index))) {
        return true;
      }
    }
    return false;
  }

  /// 聚焦指定播放列表分组。
  bool _focusEpisodeGroupOption(int groupIndex) {
    final groupCount = _episodeGroupCount(_episodes.length);
    if (groupCount <= 1) {
      return false;
    }
    final normalizedGroupIndex = groupIndex.clamp(0, groupCount - 1).toInt();
    return _requestFocusIfMounted(
      _episodeGroupFocusNodeFor(normalizedGroupIndex),
    );
  }

  /// 选集行下键优先进入当前集数所属分组，没有分组时回到底部一级菜单。
  void _focusEpisodeGroupForEpisodeOrPrimaryMenu(int episodeIndex) {
    if (_focusEpisodeGroupOption(episodeIndex ~/ _episodeGroupSize)) {
      return;
    }
    _focusCurrentPrimaryMenu();
  }

  /// 保持当前焦点不跨出所在列表。
  void _keepMenuFocusInCurrentRow() {}

  /// 获取播放列表分组焦点节点。
  FocusNode _episodeGroupFocusNodeFor(int index) {
    return _episodeGroupFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'tv-fullscreen-episode-group-$index'),
    );
  }

  /// 当前分组真正获焦后，再把选集尽量推到左侧起点。
  void _schedulePinEpisodeNearLeadingEdge(int episodeIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pinEpisodeNearLeadingEdge(episodeIndex);
      }
    });
  }

  /// 当前分组真正获焦后，再把分组尽量推到左侧起点。
  void _schedulePinEpisodeGroupNearLeadingEdge(int groupIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pinEpisodeGroupNearLeadingEdge(groupIndex);
      }
    });
  }

  /// 让选集尽量贴到横向列表最左侧。
  void _pinEpisodeNearLeadingEdge(int episodeIndex) {
    if (_episodes.isEmpty) {
      return;
    }
    final groupCount = _episodeGroupCount(_episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes =
        _episodeIndexesForGroup(_episodes.length, groupIndex);
    final localIndex = visibleIndexes.indexOf(episodeIndex);
    if (localIndex < 0) {
      return;
    }
    if (_animateHorizontalListTargetNearLeadingEdge(
      controller: _episodeListScrollController,
      targetKey: _episodeTargetKeyFor(episodeIndex),
    )) {
      return;
    }
    _animateHorizontalListToLeadingIndex(
      controller: _episodeListScrollController,
      index: localIndex,
      itemCount: visibleIndexes.length,
      spacing: 10,
      fallbackItemExtent: 98,
    );
  }

  /// 让分组尽量贴到横向列表最左侧。
  void _pinEpisodeGroupNearLeadingEdge(int groupIndex) {
    final groupCount = _episodeGroupCount(_episodes.length);
    if (groupCount <= 1 || groupIndex < 0 || groupIndex >= groupCount) {
      return;
    }
    if (_animateHorizontalListTargetNearLeadingEdge(
      controller: _episodeGroupListScrollController,
      targetKey: _episodeGroupTargetKeyFor(groupIndex),
    )) {
      return;
    }
    _animateHorizontalListToLeadingIndex(
      controller: _episodeGroupListScrollController,
      index: groupIndex,
      itemCount: groupCount,
      spacing: 26,
      fallbackItemExtent: 110,
    );
  }

  /// 确保当前选中的集数和分组默认落在左侧可视区域。
  void _ensureCurrentSelectionsVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _episodes.isEmpty) {
        return;
      }
      final episodeGroupCount = _episodeGroupCount(_episodes.length);
      final selectedGroupIndex = episodeGroupCount == 0
          ? 0
          : _episodeGroupIndex.clamp(0, episodeGroupCount - 1).toInt();

      if (episodeGroupCount > 1) {
        _jumpHorizontalListToLeadingIndex(
          controller: _episodeGroupListScrollController,
          index: selectedGroupIndex,
          itemCount: episodeGroupCount,
          spacing: 26,
          fallbackItemExtent: 110,
        );
      }

      final visibleEpisodeIndexes = _episodeIndexesForGroup(
        _episodes.length,
        selectedGroupIndex,
      );
      final selectedEpisodeLocalIndex = visibleEpisodeIndexes.indexOf(
        _episodeIndex,
      );
      if (selectedEpisodeLocalIndex >= 0) {
        _jumpHorizontalListToLeadingIndex(
          controller: _episodeListScrollController,
          index: selectedEpisodeLocalIndex,
          itemCount: visibleEpisodeIndexes.length,
          spacing: 10,
          fallbackItemExtent: 98,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (episodeGroupCount > 1) {
          _ensureHorizontalTargetVisible(
            _episodeGroupTargetKeyFor(selectedGroupIndex),
          );
        }
        _ensureHorizontalTargetVisible(_episodeTargetKeyFor(_episodeIndex));
      });
    });
  }

  /// 按索引把横向列表先跳到目标附近，确保选中项默认就待在左边。
  void _jumpHorizontalListToLeadingIndex({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required double spacing,
    required double fallbackItemExtent,
  }) {
    if (!controller.hasClients || itemCount <= 0 || index < 0) {
      return;
    }
    final position = controller.position;
    final viewportExtent = position.viewportDimension;
    if (viewportExtent <= 0) {
      return;
    }
    final totalSpacing = math.max(0, itemCount - 1) * spacing;
    final estimatedItemExtent =
        ((position.maxScrollExtent + viewportExtent - totalSpacing) / itemCount)
            .clamp(fallbackItemExtent, double.infinity);
    final itemExtent = estimatedItemExtent.isFinite && estimatedItemExtent > 0
        ? estimatedItemExtent
        : fallbackItemExtent;
    final targetOffset =
        (index * (itemExtent + spacing) + _menuListLeadingBias).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() < 1) {
      return;
    }
    controller.jumpTo(targetOffset.toDouble());
  }

  /// 按索引把横向列表动画滚到左侧起点。
  void _animateHorizontalListToLeadingIndex({
    required ScrollController controller,
    required int index,
    required int itemCount,
    required double spacing,
    required double fallbackItemExtent,
  }) {
    if (!controller.hasClients || itemCount <= 0 || index < 0) {
      return;
    }
    final position = controller.position;
    final viewportExtent = position.viewportDimension;
    if (viewportExtent <= 0) {
      return;
    }
    final totalSpacing = math.max(0, itemCount - 1) * spacing;
    final estimatedItemExtent =
        ((position.maxScrollExtent + viewportExtent - totalSpacing) / itemCount)
            .clamp(fallbackItemExtent, double.infinity);
    final itemExtent = estimatedItemExtent.isFinite && estimatedItemExtent > 0
        ? estimatedItemExtent
        : fallbackItemExtent;
    final targetOffset =
        (index * (itemExtent + spacing) + _menuListLeadingBias).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() < 1) {
      return;
    }
    position.animateTo(
      targetOffset.toDouble(),
      duration: TvFocusScroll.duration,
      curve: TvFocusScroll.curve,
    );
  }

  /// 按真实组件位置把横向列表尽量推到左侧起点。
  bool _animateHorizontalListTargetNearLeadingEdge({
    required ScrollController controller,
    required GlobalKey targetKey,
  }) {
    if (!controller.hasClients) {
      return false;
    }
    final targetRect = _globalRectForKey(targetKey);
    if (targetRect == null) {
      return false;
    }

    final listContext = controller.position.context.notificationContext;
    if (listContext == null || !listContext.mounted) {
      return false;
    }
    final listRect = _globalRectForContext(listContext);
    if (listRect == null) {
      return false;
    }

    final position = controller.position;
    final deltaToLeadingEdge = targetRect.left - listRect.left;
    final targetOffset =
        (position.pixels + deltaToLeadingEdge + _menuListLeadingBias).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - targetOffset).abs() < 1) {
      return true;
    }
    position.animateTo(
      targetOffset.toDouble(),
      duration: TvFocusScroll.duration,
      curve: TvFocusScroll.curve,
    );
    return true;
  }

  /// 获取指定 Key 对应控件的全局矩形。
  Rect? _globalRectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    return _globalRectForContext(context);
  }

  /// 获取指定上下文对应控件的全局矩形。
  Rect? _globalRectForContext(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & size;
  }

  /// 使用真实组件上下文微调横向列表，让目标项保持可见。
  void _ensureHorizontalTargetVisible(GlobalKey targetKey) {
    final targetContext = targetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      return;
    }
    TvFocusScroll.ensureVisible(targetContext);
  }

  /// 获取一级菜单边界抖动 Key。
  GlobalKey<TvEdgeShakeState> _primaryMenuEdgeShakeKeyFor(int index) {
    return _primaryMenuEdgeShakeKeys.putIfAbsent(
      index,
      () => GlobalKey<TvEdgeShakeState>(
        debugLabel: 'tv-fullscreen-primary-edge-$index',
      ),
    );
  }

  /// 获取二级菜单边界抖动 Key。
  GlobalKey<TvEdgeShakeState> _secondaryEdgeShakeKeyFor(
    String group,
    int index,
  ) {
    final key = '$group-$index';
    return _secondaryEdgeShakeKeys.putIfAbsent(
      key,
      () => GlobalKey<TvEdgeShakeState>(
        debugLabel: 'tv-fullscreen-secondary-edge-$key',
      ),
    );
  }

  /// 把焦点送回当前一级菜单项。
  void _focusCurrentPrimaryMenu() {
    if (_menuFocusNodes.isEmpty ||
        _activeMenuIndex < 0 ||
        _activeMenuIndex >= _menuFocusNodes.length) {
      return;
    }
    _menuFocusNodes[_activeMenuIndex].requestFocus();
  }

  /// 获取当前选中的线路下标。
  int get _currentSourceIndex {
    final detail = _currentDetail;
    if (detail == null) {
      return 0;
    }
    final index = widget.sources.indexWhere(
      (source) => source.source == detail.source && source.id == detail.id,
    );
    return index < 0 ? 0 : index;
  }

  /// 获取当前画面比例下标。
  int get _currentFitIndex {
    final index = _fitOptions.indexWhere((item) => item.$1 == _fitType);
    return index < 0 ? 0 : index;
  }

  /// 获取当前倍速下标。
  int get _currentSpeedIndex {
    final index = _speedOptions.indexWhere(
      (speed) => (speed - _playbackSpeed).abs() < 0.01,
    );
    return index < 0 ? 0 : index;
  }

  /// 请求焦点前先确认目标节点已经挂载。
  bool _requestFocusIfMounted(FocusNode? focusNode) {
    if (focusNode?.context == null) {
      return false;
    }
    focusNode!.requestFocus();
    return true;
  }

  /// 回到指定分组对应的选集行。
  ///
  /// 优先命中当前分组里最近一次停留的集数，没有历史时再回到当前播放集数或第一集。
  void _focusEpisodeOptionForGroup(
    int groupIndex, {
    int? preferredEpisodeIndex,
  }) {
    final groupCount = _episodeGroupCount(_episodes.length);
    final normalizedGroupIndex =
        groupCount == 0 ? 0 : groupIndex.clamp(0, groupCount - 1).toInt();

    bool requestEpisodeFocus() {
      if (!mounted) {
        return false;
      }
      if (_focusEpisodeOptionInGroup(
        normalizedGroupIndex,
        preferredEpisodeIndex,
      )) {
        return true;
      }
      if (_focusEpisodeOptionInGroup(
        normalizedGroupIndex,
        _lastFocusedEpisodeIndex,
      )) {
        return true;
      }
      if (_focusEpisodeOptionInGroup(normalizedGroupIndex, _episodeIndex)) {
        return true;
      }
      return _focusFirstVisibleEpisodeOption(groupIndex: normalizedGroupIndex);
    }

    if (_episodeGroupIndex == normalizedGroupIndex) {
      if (requestEpisodeFocus()) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        requestEpisodeFocus();
      });
      return;
    }

    setState(() => _episodeGroupIndex = normalizedGroupIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestEpisodeFocus();
    });
  }

  /// 优先聚焦分组内指定集数。
  bool _focusEpisodeOptionInGroup(int groupIndex, int? episodeIndex) {
    if (episodeIndex == null ||
        !_episodeBelongsToGroup(episodeIndex, groupIndex)) {
      return false;
    }
    return _requestFocusIfMounted(
      _secondaryFocusNodeFor('episode', episodeIndex),
    );
  }

  /// 播放进度变化时按手机端节流策略保存。
  void _onVideoProgressUpdate() {
    _saveProgress(scene: '全屏定时保存');
  }

  /// 保存当前播放进度。
  void _saveProgress({bool force = false, required String scene}) {
    final detail = _currentDetail;
    final position = _currentPlaybackPosition;
    final duration = _currentPlaybackDuration;
    if (detail == null || position.inSeconds < 1 || duration <= Duration.zero) {
      return;
    }

    final playTime = position.inSeconds;
    if (!force) {
      final now = DateTime.now();
      if (_lastSaveTime != null &&
          now.difference(_lastSaveTime!) < _saveProgressInterval) {
        return;
      }
      if (_lastSavePosition != null && playTime == _lastSavePosition) {
        return;
      }
    }

    _lastSaveTime = DateTime.now();
    _lastSavePosition = playTime;

    final playRecord = TvPlayRecordService.buildRecord(
      videoInfo: widget.videoInfo,
      detail: detail,
      episodeIndex: _episodeIndex,
      playTime: playTime,
      totalTime: duration.inSeconds,
    );

    unawaited(
      TvPlayRecordService.saveRecord(context, playRecord).then((saved) {
        if (!saved) {
          debugPrint('TV 全屏保存播放进度失败 [场景: $scene]');
        }
      }),
    );
  }

  /// 保存换源后的新播放记录，成功后再清理旧源记录。
  Future<void> _saveSwitchedSourceRecord({
    required SearchResult source,
    required int switchSerial,
    required int episodeIndex,
    required int playTime,
    required int totalTime,
  }) async {
    if (playTime < 1) {
      return;
    }

    final playRecord = TvPlayRecordService.buildRecord(
      videoInfo: widget.videoInfo,
      detail: source,
      episodeIndex: episodeIndex,
      playTime: playTime,
      totalTime: totalTime,
    );
    _lastSaveTime = DateTime.now();
    _lastSavePosition = playTime;

    final saved = await TvPlayRecordService.saveRecord(context, playRecord);
    if (!saved) {
      debugPrint('TV 全屏换源记录保护：新记录保存失败，跳过旧记录清理');
      return;
    }

    if (!mounted ||
        switchSerial != _sourceSwitchRecordSerial ||
        _currentDetail?.source != source.source ||
        _currentDetail?.id != source.id) {
      debugPrint('TV 全屏换源记录保护：切源任务已过期，跳过旧记录清理');
      return;
    }

    await TvPlayRecordService.cleanupOtherSourceRecords(
      context: context,
      keepSource: source,
      searchTitle: TvPlayRecordService.resolveSearchTitle(widget.videoInfo),
    );
  }

  /// 切换选集。
  void _switchEpisode(int index) {
    _switchEpisodeWithScene(index, scene: '全屏切换选集前');
  }

  /// 按指定场景切换选集。
  void _switchEpisodeWithScene(int index, {required String scene}) {
    if (index < 0 || index >= _episodes.length) {
      return;
    }
    _saveProgress(force: true, scene: scene);
    final nextGroupIndex = index ~/ _episodeGroupSize;
    setState(() {
      _episodeIndex = index;
      _episodeGroupIndex = nextGroupIndex;
    });
    _lastFocusedEpisodeIndex = index;
    _lastFocusedEpisodeGroupIndex = nextGroupIndex;
    widget.onEpisodeChanged?.call(index);
    _loadCurrentEpisode(updateController: true);
    _ensureCurrentSelectionsVisible();
    _hideMenu();
  }

  /// 处理全屏播放器播放完成后的自动下一集。
  void _handleVideoCompleted() {
    if (_episodeIndex >= _episodes.length - 1) {
      return;
    }
    _switchEpisodeWithScene(
      _episodeIndex + 1,
      scene: '全屏自动播放下一集',
    );
  }

  /// 切换播放列表分组。
  void _switchEpisodeGroup(int index) {
    _scheduleMenuAutoHide();
    setState(() => _episodeGroupIndex = index);
    _lastFocusedEpisodeGroupIndex = index;
    if (!_episodeBelongsToGroup(_episodeIndex, index)) {
      final groupIndexes = _episodeIndexesForGroup(_episodes.length, index);
      _lastFocusedEpisodeIndex =
          groupIndexes.isEmpty ? null : groupIndexes.first;
    }
    _ensureCurrentSelectionsVisible();
  }

  /// 切换播放线路。
  void _switchSource(SearchResult source) {
    if (_currentDetail?.source == source.source &&
        _currentDetail?.id == source.id) {
      return;
    }
    final switchSerial = ++_sourceSwitchRecordSerial;
    final currentProgress = _currentPlaybackPosition.inSeconds > 0
        ? _currentPlaybackPosition.inSeconds
        : (_lastSavePosition ?? 0);
    final currentTotalDuration = _currentPlaybackDuration.inSeconds;
    final currentEpisode = _episodeIndex;

    setState(() {
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = currentEpisode.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
    });
    _lastFocusedEpisodeIndex = _episodeIndex;
    _lastFocusedEpisodeGroupIndex = _episodeGroupIndex;
    widget.onSourceChanged?.call(source);
    widget.onEpisodeChanged?.call(_episodeIndex);
    _loadCurrentEpisode(updateController: true);
    _ensureCurrentSelectionsVisible();
    _hideMenu();
    unawaited(
      _saveSwitchedSourceRecord(
        source: source,
        switchSerial: switchSerial,
        episodeIndex: _episodeIndex,
        playTime: currentProgress,
        totalTime: currentTotalDuration,
      ),
    );
  }

  /// 切换画面比例。
  void _switchFit(VideoFitType fitType) {
    setState(() => _fitType = fitType);
    _effectiveVideoController?.setVideoFit(fitType);
  }

  /// 切换播放倍速。
  Future<void> _switchSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _effectiveVideoController?.setSpeed(speed);
  }

  /// 判断是否属于菜单交互按键。
  bool _isMenuInteractionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space;
  }

  /// 刷新底部菜单的空闲自动隐藏计时。
  void _scheduleMenuAutoHide() {
    if (!_menuVisible) {
      return;
    }
    _menuAutoHideTimer?.cancel();
    _menuAutoHideTimer = Timer(_menuAutoHideDuration, () {
      if (!mounted || !_menuVisible) {
        return;
      }
      _hideMenu();
    });
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
              if (_shouldShowTopDecorations) _buildTopDecorations(),
              if (_shouldShowCenterPlayButton) _buildCenterPlayButton(),
              if (_shouldShowPlaybackChrome) _buildBottomProgressBar(),
              if (_isPlaybackLoading) _buildLoadingIndicator(),
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
          _handlePlayerControllerCreated,
        ) ??
        VideoPlayerWidget(
          surface: VideoPlayerSurface.desktop,
          // 全屏页需要带 `startAt` 续播，避免 `url` 自动加载路径从 0 秒起播。
          url: null,
          videoTitle: _title,
          videoYear: _year,
          currentEpisodeIndex: _episodeIndex,
          totalEpisodes: _episodes.length,
          episodesTitles: _episodeTitles,
          sourceName: _sourceName,
          initialFitType: _fitType,
          isShortDrama: false,
          showControls: false,
          enablePip: false,
          onControllerCreated: _handlePlayerControllerCreated,
          onReady: _finishFullscreenPlayerLoading,
          onPlay: () {
            _scheduleChromeRefresh();
          },
          onPause: () {
            _scheduleChromeRefresh();
          },
          onVideoCompleted: _handleVideoCompleted,
        );
  }

  /// 记录播放器控制器并执行一次首次续播加载。
  void _handlePlayerControllerCreated(VideoPlayerWidgetController controller) {
    if (!identical(_playerController, controller)) {
      _playerController?.removeProgressListener(_onVideoProgressUpdate);
      controller.addProgressListener(_onVideoProgressUpdate);
    }
    _playerController = controller;
    _scheduleChromeRefresh();
    if (_hasRequestedInitialControllerLoad) {
      return;
    }

    _hasRequestedInitialControllerLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (widget.reuseExistingPlayer) {
        if (!widget.initialPlaybackWasPlaying) {
          unawaited(controller.pause());
        }
        return;
      }
      unawaited(_loadCurrentEpisode(updateController: true));
      if (!widget.initialPlaybackWasPlaying) {
        unawaited(controller.pause());
      }
    });
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

  /// 构建播放器加载中转圈。
  Widget _buildLoadingIndicator() {
    return const Center(
      child: IgnorePointer(
        child: SizedBox(
          key: ValueKey('tv-fullscreen-loading'),
          width: 46,
          height: 46,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
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
            width: _seekOverlayWidth,
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
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
      width: double.infinity,
      height: 58,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var index = 0; index < _menuTabs.length; index++) ...[
              Builder(
                builder: (context) {
                  final edgeShakeKey = _primaryMenuEdgeShakeKeyFor(index);
                  final isFirstItem = index == 0;
                  final isLastItem = index == _menuTabs.length - 1;
                  return TvEdgeShake(
                    key: edgeShakeKey,
                    child: _TvPlayerMenuButton(
                      focusNode: _menuFocusNodes[index],
                      label: _menuTabs[index],
                      selected: _activeMenuIndex == index,
                      minWidth: 100,
                      onArrowLeft: isFirstItem
                          ? () => edgeShakeKey.currentState
                              ?.shake(AxisDirection.left)
                          : null,
                      onArrowRight: isLastItem
                          ? () => edgeShakeKey.currentState
                              ?.shake(AxisDirection.right)
                          : null,
                      onArrowUp: _focusCurrentSecondaryOption,
                      onArrowDown: _keepMenuFocusInCurrentRow,
                      onFocus: () => _switchPrimaryMenu(index),
                      onPressed: () => _switchPrimaryMenu(index),
                    ),
                  );
                },
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
    final groupCount = _episodeGroupCount(_episodes.length);
    final groupIndex = groupCount == 0
        ? 0
        : _episodeGroupIndex.clamp(0, groupCount - 1).toInt();
    final visibleIndexes =
        _episodeIndexesForGroup(_episodes.length, groupIndex);
    return Column(
      key: const ValueKey('tv-fullscreen-episode-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHorizontalChoices(
          key: const ValueKey('tv-fullscreen-episode-list'),
          controller: _episodeListScrollController,
          itemCount: visibleIndexes.length,
          itemBuilder: (itemIndex) {
            final index = visibleIndexes[itemIndex];
            final label = _episodeTitles.length == _episodes.length
                ? _episodeTitles[index]
                : '第${index + 1}集';
            final edgeShakeKey = _secondaryEdgeShakeKeyFor('episode', index);
            final isFirstItem = itemIndex == 0;
            final isLastItem = itemIndex == visibleIndexes.length - 1;
            return TvEdgeShake(
              key: edgeShakeKey,
              child: KeyedSubtree(
                key: _episodeTargetKeyFor(index),
                child: _TvPlayerMenuButton(
                  focusNode: _secondaryFocusNodeFor('episode', index),
                  label: label.isEmpty ? '第${index + 1}集' : label,
                  selected: index == _episodeIndex,
                  minWidth: 56,
                  autoScrollOnFocus: false,
                  onArrowLeft: isFirstItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right)
                      : null,
                  onArrowUp: _keepMenuFocusInCurrentRow,
                  onArrowDown: () =>
                      _focusEpisodeGroupForEpisodeOrPrimaryMenu(index),
                  onFocus: () => _rememberEpisodeFocus(index),
                  onPressed: () => _switchEpisode(index),
                ),
              ),
            );
          },
        ),
        if (groupCount > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  key: const ValueKey('tv-fullscreen-episode-group-list'),
                  controller: _episodeGroupListScrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  // 分组行需要把任意分组都推到左侧，尾部预留一屏宽度给末尾分组贴左。
                  child: Row(
                    children: [
                      for (var index = 0; index < groupCount; index++) ...[
                        KeyedSubtree(
                          key: _episodeGroupTargetKeyFor(index),
                          child: Builder(
                            builder: (context) {
                              final edgeShakeKey = _secondaryEdgeShakeKeyFor(
                                'episode-group',
                                index,
                              );
                              final isFirstItem = index == 0;
                              final isLastItem = index == groupCount - 1;
                              return TvEdgeShake(
                                key: edgeShakeKey,
                                child: _TvPlayerGroupLabel(
                                  label: _episodeGroupLabel(
                                    index,
                                    _episodes.length,
                                  ),
                                  selected: index == groupIndex,
                                  focusNode: _episodeGroupFocusNodeFor(index),
                                  autoScrollOnFocus: false,
                                  onArrowLeft: isFirstItem
                                      ? () => edgeShakeKey.currentState
                                          ?.shake(AxisDirection.left)
                                      : null,
                                  onArrowRight: isLastItem
                                      ? () => edgeShakeKey.currentState
                                          ?.shake(AxisDirection.right)
                                      : null,
                                  onArrowUp: () =>
                                      _focusEpisodeOptionForGroup(index),
                                  onArrowDown: _focusCurrentPrimaryMenu,
                                  onFocus: () =>
                                      _rememberEpisodeGroupFocus(index),
                                  onPressed: () => _switchEpisodeGroup(index),
                                ),
                              );
                            },
                          ),
                        ),
                        if (index != groupCount - 1) const SizedBox(width: 26),
                      ],
                      SizedBox(width: constraints.maxWidth),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
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
        final edgeShakeKey = _secondaryEdgeShakeKeyFor('source', index);
        final isFirstItem = index == 0;
        final isLastItem = index == widget.sources.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: _TvPlayerMenuButton(
            focusNode: _secondaryFocusNodeFor('source', index),
            label: source.sourceName,
            selected: selected,
            minWidth: 104,
            onArrowLeft: isFirstItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                : null,
            onArrowUp: _keepMenuFocusInCurrentRow,
            onArrowDown: _focusCurrentPrimaryMenu,
            onFocus: () => _rememberSecondaryFocus('source', index),
            onPressed: () => _switchSource(source),
          ),
        );
      },
    );
  }

  /// 构建画面比例二级菜单。
  Widget _buildFitChoices() {
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-fit-list'),
      itemCount: _fitOptions.length,
      itemBuilder: (index) {
        final item = _fitOptions[index];
        final edgeShakeKey = _secondaryEdgeShakeKeyFor('fit', index);
        final isFirstItem = index == 0;
        final isLastItem = index == _fitOptions.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: _TvPlayerMenuButton(
            focusNode: _secondaryFocusNodeFor('fit', index),
            label: item.$2,
            selected: item.$1 == _fitType,
            minWidth: 100,
            onArrowLeft: isFirstItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                : null,
            onArrowUp: _keepMenuFocusInCurrentRow,
            onArrowDown: _focusCurrentPrimaryMenu,
            onFocus: () => _rememberSecondaryFocus('fit', index),
            onPressed: () => _switchFit(item.$1),
          ),
        );
      },
    );
  }

  /// 构建倍速二级菜单。
  Widget _buildSpeedChoices() {
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-speed-list'),
      itemCount: _speedOptions.length,
      itemBuilder: (index) {
        final speed = _speedOptions[index];
        final edgeShakeKey = _secondaryEdgeShakeKeyFor('speed', index);
        final isFirstItem = index == 0;
        final isLastItem = index == _speedOptions.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: _TvPlayerMenuButton(
            focusNode: _secondaryFocusNodeFor('speed', index),
            label: '${speed}x',
            selected: (speed - _playbackSpeed).abs() < 0.01,
            minWidth: 92,
            onArrowLeft: isFirstItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                : null,
            onArrowUp: _keepMenuFocusInCurrentRow,
            onArrowDown: _focusCurrentPrimaryMenu,
            onFocus: () => _rememberSecondaryFocus('speed', index),
            onPressed: () => _switchSpeed(speed),
          ),
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
        final edgeShakeKey = _secondaryEdgeShakeKeyFor('other', index);
        final isFirstItem = index == 0;
        final isLastItem = index == 2;
        if (index == 0) {
          return TvEdgeShake(
            key: edgeShakeKey,
            child: _TvPlayerMenuButton(
              focusNode: _secondaryFocusNodeFor('other', index),
              label: '片头 ${_formatProgressBarDuration(
                Duration(seconds: _skipIntroSeconds),
              )}',
              selected: false,
              minWidth: 116,
              onArrowLeft: isFirstItem
                  ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                  : null,
              onArrowRight: isLastItem
                  ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                  : null,
              onArrowUp: _keepMenuFocusInCurrentRow,
              onArrowDown: _focusCurrentPrimaryMenu,
              onFocus: () => _rememberSecondaryFocus('other', index),
              onPressed: _seekToIntroPosition,
            ),
          );
        }
        if (index == 1) {
          return TvEdgeShake(
            key: edgeShakeKey,
            child: _TvPlayerMenuButton(
              focusNode: _secondaryFocusNodeFor('other', index),
              label: '片尾 ${_formatProgressBarDuration(
                Duration(seconds: _skipOutroSeconds),
              )}',
              selected: false,
              minWidth: 116,
              onArrowLeft: isFirstItem
                  ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                  : null,
              onArrowRight: isLastItem
                  ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                  : null,
              onArrowUp: _keepMenuFocusInCurrentRow,
              onArrowDown: _focusCurrentPrimaryMenu,
              onFocus: () => _rememberSecondaryFocus('other', index),
              onPressed: _seekToOutroPosition,
            ),
          );
        }
        return TvEdgeShake(
          key: edgeShakeKey,
          child: _TvPlayerMenuButton(
            focusNode: _secondaryFocusNodeFor('other', index),
            label: _danmakuEnabled ? '弹幕 开' : '弹幕 关',
            selected: _danmakuEnabled,
            minWidth: 116,
            onArrowLeft: isFirstItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                : null,
            onArrowRight: isLastItem
                ? () => edgeShakeKey.currentState?.shake(AxisDirection.right)
                : null,
            onArrowUp: _keepMenuFocusInCurrentRow,
            onArrowDown: _focusCurrentPrimaryMenu,
            onFocus: () => _rememberSecondaryFocus('other', index),
            onPressed: () {
              setState(() => _danmakuEnabled = !_danmakuEnabled);
            },
          ),
        );
      },
    );
  }

  /// 构建横向二级菜单列表。
  Widget _buildHorizontalChoices({
    required Key key,
    ScrollController? controller,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: SingleChildScrollView(
        key: key,
        controller: controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var index = 0; index < itemCount; index++) ...[
              itemBuilder(index),
              if (index != itemCount - 1) const SizedBox(width: 10),
            ],
          ],
        ),
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
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.minWidth = 118,
    this.autoScrollOnFocus = true,
  });

  /// 按钮文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 焦点节点。
  final FocusNode? focusNode;

  /// 焦点进入回调。
  final VoidCallback? onFocus;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 最小宽度。
  final double minWidth;

  /// 获焦时是否使用通用自动滚动。
  final bool autoScrollOnFocus;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      autoScrollOnFocus: autoScrollOnFocus,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
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

/// TV 播放列表分组文本标签。
class _TvPlayerGroupLabel extends StatelessWidget {
  /// 创建 TV 播放列表分组文本标签。
  const _TvPlayerGroupLabel({
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onPressed,
    this.onFocus,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.autoScrollOnFocus = true,
  });

  /// 标签文案。
  final String label;

  /// 是否选中。
  final bool selected;

  /// 焦点节点。
  final FocusNode focusNode;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 焦点进入回调。
  final VoidCallback? onFocus;

  /// 左方向键回调。
  final VoidCallback? onArrowLeft;

  /// 右方向键回调。
  final VoidCallback? onArrowRight;

  /// 上方向键回调。
  final VoidCallback? onArrowUp;

  /// 下方向键回调。
  final VoidCallback? onArrowDown;

  /// 获焦时是否使用通用自动滚动。
  final bool autoScrollOnFocus;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      autoScrollOnFocus: autoScrollOnFocus,
      onPressed: onPressed,
      onArrowLeft: onArrowLeft,
      onArrowRight: onArrowRight,
      onArrowUp: onArrowUp,
      onArrowDown: onArrowDown,
      onFocusChanged: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        }
      },
      builder: (context, hasFocus) {
        final active = selected || hasFocus;
        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 140),
          style: FontUtils.poppins(
            fontSize: 17,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? palette.accent : Colors.white,
          ),
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              border: active
                  ? Border(
                      bottom: BorderSide(
                        color: palette.accent,
                        width: 2,
                      ),
                    )
                  : null,
            ),
            child: Text(label),
          ),
        );
      },
    );
  }
}
