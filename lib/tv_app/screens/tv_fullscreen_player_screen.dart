import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/danmaku_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/screens/tv_danmaku_match_screen.dart';
import 'package:selene/tv_app/services/tv_danmaku_service.dart';
import 'package:selene/tv_app/services/tv_play_record_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_danmaku_overlay.dart';
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

/// TV 全屏播放器自动去广告开关读取函数。
typedef TvFullscreenAdFilterLoader = Future<bool> Function();

/// TV 全屏播放器 M3U8 代理地址读取函数。
typedef TvFullscreenProxyUrlLoader = Future<String> Function();

/// TV 全屏播放器测试钩子。
///
/// 仅测试场景使用，用于在占位播放器下模拟“视频播放完成”这类播放器事件。
class TvFullscreenPlayerScreenTestHooks {
  /// 视频播放完成回调。
  VoidCallback? onVideoCompleted;

  /// 默认播放器构建前最终使用的自动去广告开关。
  ValueChanged<bool>? onAdFilterResolved;
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

  /// 当前下载速度文案。
  String get networkSpeedText;

  /// 监听下载速度变化。
  void addNetworkSpeedListener(VoidCallback listener);

  /// 移除下载速度监听。
  void removeNetworkSpeedListener(VoidCallback listener);

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
/// 短按保持 10 秒跳转；长按前 5 秒保持每真实秒推进 30 秒视频，
/// 5 秒后切到每真实秒推进 120 秒视频，并减少页面刷新次数。
class TvFullscreenSeekStep {
  /// 私有构造，避免工具类被实例化。
  const TvFullscreenSeekStep._();

  /// 短按方向键时的 seek 秒数。
  static const int initialPressSeconds = 10;

  /// 长按第一档每个内部 tick 推进的视频秒数。
  static const int normalRepeatStepSeconds = 3;

  /// 长按第二档每个内部 tick 推进的视频秒数。
  static const int acceleratedRepeatStepSeconds = 6;

  /// 长按第一档每真实秒推进的视频秒数。
  static const int normalSeekSecondsPerSecond = 30;

  /// 长按第二档每真实秒推进的视频秒数。
  static const int acceleratedSeekSecondsPerSecond = 120;

  /// 长按切入第二段加速的持续时间阈值。
  static const Duration accelerationThreshold = Duration(seconds: 5);

  /// 短按和长按的分界时间。
  static const Duration longPressStartThreshold = Duration(milliseconds: 250);

  /// 长按第一档重复 seek 的名义最小间隔。
  static const int normalRepeatIntervalMicroseconds = 16667;

  /// 长按第二档重复 seek 的名义最小间隔。
  static const int acceleratedRepeatIntervalMicroseconds = 8333;

  /// 根据长按持续时间计算当前重复 seek 的触发间隔微秒数。
  static int repeatIntervalMicrosecondsForElapsed(Duration elapsed) {
    if (elapsed <= accelerationThreshold) {
      return normalRepeatIntervalMicroseconds;
    }
    return acceleratedRepeatIntervalMicroseconds;
  }

  /// 根据长按持续时间计算当前重复 seek 的触发间隔。
  static int repeatIntervalForElapsed(Duration elapsed) {
    return (repeatIntervalMicrosecondsForElapsed(elapsed) / 1000).round();
  }

  /// 根据长按持续时间计算当前重复 seek 的步进秒数。
  static int repeatStepForElapsed(Duration elapsed) {
    if (elapsed <= accelerationThreshold) {
      return normalRepeatStepSeconds;
    }
    return acceleratedRepeatStepSeconds;
  }

  /// 根据真实长按时长，换算当前应累计推进的视频秒数。
  static int totalSeekSecondsForElapsed(Duration elapsed) {
    final elapsedMicros = elapsed.inMicroseconds;
    if (elapsedMicros <= 0) {
      return 0;
    }

    final thresholdMicros = accelerationThreshold.inMicroseconds;
    if (elapsedMicros <= thresholdMicros) {
      return (elapsedMicros * normalSeekSecondsPerSecond) ~/
          Duration.microsecondsPerSecond;
    }

    final normalSeconds = (thresholdMicros * normalSeekSecondsPerSecond) ~/
        Duration.microsecondsPerSecond;
    final acceleratedMicros = elapsedMicros - thresholdMicros;
    final acceleratedSeconds =
        (acceleratedMicros * acceleratedSeekSecondsPerSecond) ~/
            Duration.microsecondsPerSecond;
    return normalSeconds + acceleratedSeconds;
  }

  /// 根据累计推进秒数，反推该秒应落到的真实长按时间点。
  static int elapsedMicrosecondsForTotalSeekSeconds(int totalSeekSeconds) {
    if (totalSeekSeconds <= 0) {
      return 0;
    }

    final thresholdMicros = accelerationThreshold.inMicroseconds;
    final normalPhaseSeekSeconds =
        (thresholdMicros * normalSeekSecondsPerSecond) ~/
            Duration.microsecondsPerSecond;

    if (totalSeekSeconds <= normalPhaseSeekSeconds) {
      return ((totalSeekSeconds * Duration.microsecondsPerSecond) +
              normalSeekSecondsPerSecond -
              1) ~/
          normalSeekSecondsPerSecond;
    }

    final acceleratedSeekSeconds = totalSeekSeconds - normalPhaseSeekSeconds;
    return thresholdMicros +
        (((acceleratedSeekSeconds * Duration.microsecondsPerSecond) +
                acceleratedSeekSecondsPerSecond -
                1) ~/
            acceleratedSeekSecondsPerSecond);
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
    this.initialPlaybackStarted = false,
    this.stype,
    this.playerBuilder,
    this.playbackController,
    this.onExitRequested,
    this.onEpisodeChanged,
    this.onSourceChanged,
    this.danmakuService,
    this.reuseExistingPlayer = false,
    this.loadAdFilterEnabled,
    this.loadM3u8ProxyUrl,
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

  /// 进入全屏前当前视频是否已经真正起播。
  ///
  /// 详情页正在首播加载时打开全屏，需要把“尚未起播”的状态一并带过来，
  /// 避免全屏页把 `ready` 误判成已开播，提前撤掉中心转圈。
  final bool initialPlaybackStarted;

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

  /// TV 专属弹幕服务。
  ///
  /// 默认复用共享数据层实现；测试时可注入假服务覆盖自动匹配结果。
  final TvDanmakuService? danmakuService;

  /// 自动去广告开关读取函数，测试时可注入。
  final TvFullscreenAdFilterLoader? loadAdFilterEnabled;

  /// M3U8 代理地址读取函数，测试时可注入。
  final TvFullscreenProxyUrlLoader? loadM3u8ProxyUrl;

  /// 测试钩子，允许 widget test 模拟播放器完成事件。
  final TvFullscreenPlayerScreenTestHooks? testHooks;

  @override
  State<TvFullscreenPlayerScreen> createState() =>
      _TvFullscreenPlayerScreenState();
}

/// 播放列表最近一次停留的二级菜单行。
enum _TvPlaylistSecondaryRow { episode, group }

class _TvFullscreenPlayerScreenState extends State<TvFullscreenPlayerScreen> {
  /// 标记当前是否运行在 `flutter test` 环境。
  ///
  /// widget test 中的 `pumpAndSettle` 会等待所有动画静止，loading 进度环需改为
  /// 静态值，避免测试因无限转圈动画超时。
  static bool get _isFlutterTestEnvironment {
    final flutterTest = Platform.environment['FLUTTER_TEST'];
    return flutterTest != null && flutterTest != 'false';
  }

  /// 底部进度条左右时间槽位宽度。
  static const double _progressTimeSlotWidth = 78;

  /// 选集卡片基础最小宽度。
  static const double _episodeCardBaseMinWidth = 190;

  /// 选集卡片基础最大宽度。
  static const double _episodeCardMaxWidth = 260;

  /// 选集卡片基础最小高度。
  static const double _episodeCardBaseMinHeight = 104;

  /// 选集卡片横向内边距总和。
  static const double _episodeCardHorizontalPadding = 28;

  /// 选集卡片纵向预留空间。
  static const double _episodeCardVerticalPadding = 24;

  /// 二级菜单卡片缩放比例。
  ///
  /// 一级菜单保持原尺寸，二级菜单整体缩小以减少底部遮挡。
  static const double _secondaryMenuScale = 2 / 3;

  /// 二级菜单文字字号。
  static const double _secondaryMenuFontSize = 16;

  /// 二级菜单按钮默认高度。
  static const double _secondaryMenuDefaultHeight = 56 * _secondaryMenuScale;

  /// 二级菜单按钮横向内边距。
  static const double _secondaryMenuHorizontalInset = 14 * _secondaryMenuScale;

  /// 二级菜单卡片横向内边距总和。
  static const double _secondaryMenuHorizontalPadding =
      _episodeCardHorizontalPadding * _secondaryMenuScale;

  /// 二级菜单卡片纵向预留空间。
  static const double _secondaryMenuVerticalPadding =
      _episodeCardVerticalPadding * _secondaryMenuScale;

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

  /// 选集卡片尺寸缓存。
  ///
  /// 底部菜单切换和焦点移动会频繁重建菜单层，长标题尺寸测量需要缓存，避免
  /// 每一帧都同步执行多次 `TextPainter.layout`。
  final Map<String, _TvPlayerMenuCardSize> _episodeCardSizeCache =
      <String, _TvPlayerMenuCardSize>{};

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

  /// 缓存后的播放器画面层。
  ///
  /// 底部菜单显示、焦点移动和自动隐藏都属于壳层 UI 状态，不应反复更新
  /// Android WebView/平台视图播放器子树，否则会放大模拟器和 TV 设备上的合成开销。
  Widget? _cachedPlayerLayer;

  /// 当前播放器画面层对应的业务签名。
  _TvFullscreenPlayerLayerSignature? _cachedPlayerLayerSignature;

  /// 当前自动去广告开关状态。
  bool _adFilterEnabled = true;

  /// 当前已预热完成的 M3U8 代理地址。
  ///
  /// 全屏壳切集、换源和首帧恢复时都直接复用当前缓存，不再为等待配置读取卡住播放。
  String _m3u8ProxyUrl = '';

  /// M3U8 代理地址是否已经完成过一次读取。
  bool _hasResolvedM3u8ProxyUrl = false;

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

  /// 下次选集获焦时是否跳过横向贴左动画。
  bool _suppressNextEpisodeFocusPin = false;

  /// 下次分组获焦时是否跳过横向贴左动画。
  bool _suppressNextEpisodeGroupFocusPin = false;

  /// 当前画面比例。
  VideoFitType _fitType = VideoFitType.contain;

  /// 当前播放倍速。
  double _playbackSpeed = 1.0;

  /// TV 菜单里的弹幕开关展示状态。
  bool _danmakuEnabled = true;

  /// TV 弹幕设置。
  DanmakuSettings _danmakuSettings = const DanmakuSettings();

  /// 当前弹幕列表。
  List<DanmakuComment> _danmakuList = const <DanmakuComment>[];

  /// 当前命中的弹幕剧集 ID。
  int? _currentDanmakuEpisodeId;

  /// 当前弹幕游标。
  int _danmakuIndex = 0;

  /// 上一次弹幕时间轴检查点。
  double _lastDanmakuCheckTime = -1;

  /// 当前弹幕控制器。
  DanmakuController? _danmakuController;

  /// 当前弹幕叠层版本。
  int _danmakuOverlayVersion = 0;

  /// 当前是否正在加载弹幕。
  bool _isDanmakuLoading = false;

  /// 弹幕加载任务序号，避免旧结果回写。
  int _danmakuLoadToken = 0;

  /// 当前活跃的弹幕加载请求标识。
  ///
  /// 首次进入全屏时设置加载和播放器地址加载会非常接近，
  /// 这里用请求标识避免同一集数被重复自动匹配。
  String? _activeDanmakuRequestKey;

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

  /// 顶部右侧当前时间。
  late String _clockText;

  /// 当前 seek 预览位置。
  Duration? _seekPreviewPosition;

  /// 当前 seek 提示总时长。
  Duration? _seekPreviewDuration;

  /// 当前 seek 方向，-1 为后退，1 为前进。
  int _seekDirection = 0;

  /// 当前正在驱动长按 seek 的方向键。
  LogicalKeyboardKey? _activeSeekKey;

  /// 当前长按 seek 已持续的真实时间。
  Duration _seekHoldElapsed = Duration.zero;

  /// 当前长按是否已经进入连续滚动阶段。
  bool _seekHoldHasRepeated = false;

  /// 当前长按 seek 已经累计下发的视频秒数。
  int _seekHoldAppliedSeconds = 0;

  /// 当前长按 seek 是否已经越过短按保护阈值。
  bool _seekHoldLongPressStarted = false;

  /// 当前长按 seek 的内部调度定时器。
  Timer? _seekHoldTimer;

  /// seek 中心提示是否展示。
  bool _seekOverlayVisible = false;

  /// 全屏播放器是否正在加载当前视频。
  bool _fullscreenPlayerLoading = false;

  /// 当前全屏播放是否已经由真实进度确认起播。
  bool _fullscreenPlaybackStarted = false;

  /// 本轮全屏 loading 开始时的播放位置。
  Duration? _fullscreenLoadingAnchorPosition;

  /// 当前已挂载网速监听的注入播放控制器。
  TvFullscreenPlaybackController? _networkSpeedPlaybackController;

  /// 当前已挂载进度监听的真实播放器控制器。
  VideoPlayerWidgetController? _observedVideoController;

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

  /// 等待真实进度信号确认的续播 seek 位置。
  Duration? _pendingResumeSeekPosition;

  /// 当前续播 seek 已重试次数。
  int _pendingResumeSeekRetryCount = 0;

  /// 是否已经应用过初始续播位置。
  bool _hasAppliedInitialPlaybackPosition = false;

  /// 最近一次下发给全屏播放器的地址。
  ///
  /// 同一地址且不带新的续播点时，直接跳过重复下发，避免无意义 reload。
  String? _lastRequestedPlaybackUrl;

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

  /// 续播 seek 被底层吞掉后的最大补偿次数。
  static const int _pendingResumeSeekRetryLimit = 5;

  /// 底部菜单空闲自动隐藏时长。
  static const Duration _menuAutoHideDuration = Duration(seconds: 5);

  /// 全屏播放列表分组大小。
  ///
  /// 采用 20 集一组，减少长剧集的分组切换次数。
  static const int _episodeGroupSize = 20;

  /// TV 端弹幕字号倍率。
  static const double _tvDanmakuFontMultiplier = 1.12;

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

  /// 绑定注入播放控制器的网速监听。
  void _attachPlaybackControllerNetworkSpeed(
    TvFullscreenPlaybackController? controller,
  ) {
    if (identical(_networkSpeedPlaybackController, controller)) {
      return;
    }
    _networkSpeedPlaybackController
        ?.removeNetworkSpeedListener(_onFullscreenNetworkSpeedUpdate);
    _networkSpeedPlaybackController = controller;
    controller?.addNetworkSpeedListener(_onFullscreenNetworkSpeedUpdate);
  }

  /// 网速变化时刷新全屏 loading 文案。
  void _onFullscreenNetworkSpeedUpdate() {
    _scheduleChromeRefresh();
  }

  /// 绑定真实播放器控制器的进度与网速监听。
  void _attachVideoControllerListeners(
      VideoPlayerWidgetController? controller) {
    if (identical(_observedVideoController, controller)) {
      return;
    }
    _observedVideoController?.removeProgressListener(_onVideoProgressUpdate);
    _observedVideoController
        ?.removeNetworkSpeedListener(_onFullscreenNetworkSpeedUpdate);
    _observedVideoController = controller;
    controller?.addProgressListener(_onVideoProgressUpdate);
    controller?.addNetworkSpeedListener(_onFullscreenNetworkSpeedUpdate);
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
    _fullscreenPlaybackStarted = widget.initialPlaybackStarted;
    _fullscreenPlayerLoading = !_hasFullscreenPlaybackStarted;
    _fullscreenLoadingAnchorPosition =
        _fullscreenPlayerLoading ? _currentPlaybackPosition : null;
    _attachPlaybackControllerNetworkSpeed(widget.playbackController);
    _attachVideoControllerListeners(_effectiveVideoController);
    _pendingInitialPlaybackPosition =
        _safeInitialPlaybackPosition(widget.initialPlaybackPosition);
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _clockText = _formatClock(DateTime.now()));
    });
    // 提前预热代理配置，但不让它阻塞全屏播放器首帧或换集动作。
    unawaited(_loadM3u8ProxyUrl());
    unawaited(_loadSkipDurations());
    unawaited(_loadDanmakuSettings());
    _loadAdFilterPreference();
  }

  @override
  void didUpdateWidget(covariant TvFullscreenPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.testHooks, widget.testHooks)) {
      oldWidget.testHooks?.onVideoCompleted = null;
      _bindTestHooks();
    }

    if (!identical(oldWidget.playerBuilder, widget.playerBuilder) ||
        !identical(oldWidget.playbackController, widget.playbackController) ||
        oldWidget.reuseExistingPlayer != widget.reuseExistingPlayer) {
      _invalidateCachedPlayerLayer();
    }

    if (!identical(oldWidget.playbackController, widget.playbackController)) {
      _attachPlaybackControllerNetworkSpeed(widget.playbackController);
      _attachVideoControllerListeners(_effectiveVideoController);
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
    _episodeCardSizeCache.clear();
    _invalidateCachedPlayerLayer();
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

  /// 加载 TV 全屏播放器自动去广告偏好。
  Future<void> _loadAdFilterPreference() async {
    final loader =
        widget.loadAdFilterEnabled ?? UserDataService.getAdFilterEnabled;
    final adFilterEnabled = await loader();
    if (!mounted) {
      return;
    }
    if (_adFilterEnabled == adFilterEnabled) {
      return;
    }
    _invalidateCachedPlayerLayer();
    setState(() {
      _adFilterEnabled = adFilterEnabled;
    });
  }

  /// 清理播放器画面层缓存。
  void _invalidateCachedPlayerLayer() {
    _cachedPlayerLayer = null;
    _cachedPlayerLayerSignature = null;
  }

  /// 当前播放器画面层签名。
  _TvFullscreenPlayerLayerSignature _playerLayerSignature() {
    final detail = _currentDetail;
    return _TvFullscreenPlayerLayerSignature(
      title: _title,
      year: _year,
      sourceName: _sourceName,
      source: detail?.source,
      sourceId: detail?.id,
      episodeIndex: _episodeIndex,
      episodeCount: _episodes.length,
      episodeTitles: _episodeTitles,
      fitType: _fitType,
      adFilterEnabled: _adFilterEnabled,
      playerBuilder: widget.playerBuilder,
    );
  }

  /// 后台预热 M3U8 代理地址。
  Future<void> _loadM3u8ProxyUrl() async {
    final loader = widget.loadM3u8ProxyUrl ?? UserDataService.getM3u8ProxyUrl;
    final proxyUrl = await loader();
    if (!mounted) {
      return;
    }

    _m3u8ProxyUrl = proxyUrl;
    _hasResolvedM3u8ProxyUrl = true;
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
    _seekHoldTimer?.cancel();
    _menuAutoHideTimer?.cancel();
    _detachDanmakuController();
    // 播放器壳销毁前兜底保存一次进度，避免系统返回直接销毁时漏记。
    unawaited(_saveProgress(force: true, scene: '全屏页销毁'));
    _attachVideoControllerListeners(null);
    _networkSpeedPlaybackController
        ?.removeNetworkSpeedListener(_onFullscreenNetworkSpeedUpdate);
    _networkSpeedPlaybackController = null;
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

  /// 读取 TV 弹幕设置并同步菜单状态。
  Future<void> _loadDanmakuSettings() async {
    final service = widget.danmakuService ?? TvDanmakuService();
    final settings = await service.getSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _danmakuSettings = settings;
      _danmakuEnabled = settings.enabled;
    });
    if (_danmakuEnabled) {
      unawaited(_loadDanmakuForCurrentEpisode(force: false));
    }
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
    if (!updateController) {
      return;
    }
    final token = ++_loadToken;
    if (_episodes.isEmpty) {
      return;
    }

    final index = _episodeIndex.clamp(0, _episodes.length - 1).toInt();
    final url = _resolvePlaybackUrl(_episodes[index]);

    if (!mounted || token != _loadToken) {
      return;
    }

    // 首次进入全屏时接续详情页小播放器的当前进度，后续换源换集不复用。
    final startAt = _takeInitialPlaybackPosition();
    if (_lastRequestedPlaybackUrl == url && startAt == null) {
      return;
    }
    _lastRequestedPlaybackUrl = url;
    _clearDanmakuState(clearList: true);
    _rememberPendingResumeSeek(startAt);
    _markFullscreenPlayerLoading(anchorPosition: startAt);
    _scheduleChromeRefresh();
    await _effectiveVideoController?.updateDataSource(url, startAt: startAt);
    await _seekToInitialPlaybackPositionIfNeeded(startAt);
    if (_danmakuEnabled) {
      unawaited(_loadDanmakuForCurrentEpisode(force: false));
    }
  }

  /// 在底层播放器忽略 `startAt` 时补一次 seek，和手机端 ready 后 seek 兜底一致。
  Future<void> _seekToInitialPlaybackPositionIfNeeded(Duration? startAt) async {
    if (startAt == null || startAt <= Duration.zero) {
      return;
    }

    final currentPosition = _effectiveVideoController?.currentPosition;
    final alreadyAtResumePosition = currentPosition != null &&
        (currentPosition - startAt).abs() <= const Duration(seconds: 1);
    if (alreadyAtResumePosition) {
      return;
    }

    try {
      await _seekTo(startAt);
    } catch (error) {
      debugPrint('TV 全屏续播 seek 兜底失败: $error');
    }
  }

  /// 记录需要等真实进度确认的续播 seek。
  void _rememberPendingResumeSeek(Duration? position) {
    if (position == null || position <= Duration.zero) {
      _clearPendingResumeSeek();
      return;
    }
    _pendingResumeSeekPosition = position;
    _pendingResumeSeekRetryCount = 0;
  }

  /// 清理续播 seek 确认状态。
  void _clearPendingResumeSeek() {
    _pendingResumeSeekPosition = null;
    _pendingResumeSeekRetryCount = 0;
  }

  /// 判断播放器真实进度是否已经到达续播点附近。
  bool _isAtResumePosition(Duration currentPosition, Duration resumePosition) {
    return currentPosition + const Duration(seconds: 1) >= resumePosition;
  }

  /// 真实进度仍停在续播点之前时，补一次 seek。
  Future<void> _retryPendingResumeSeekAfterProgress() async {
    final resumePosition = _pendingResumeSeekPosition;
    if (resumePosition == null) {
      return;
    }

    final currentPosition = _effectiveVideoController?.currentPosition;
    if (currentPosition != null &&
        _isAtResumePosition(currentPosition, resumePosition)) {
      _clearPendingResumeSeek();
      return;
    }

    if (_pendingResumeSeekRetryCount >= _pendingResumeSeekRetryLimit) {
      debugPrint(
        'TV 全屏续播 seek 重试达到上限: ${resumePosition.inSeconds}s',
      );
      _clearPendingResumeSeek();
      return;
    }

    _pendingResumeSeekRetryCount++;
    try {
      await _seekTo(resumePosition);
    } catch (error) {
      debugPrint('TV 全屏续播 seek 重试失败: $error');
    }
  }

  /// 解析当前可直接下发给播放器的播放地址。
  ///
  /// 代理配置属于增强能力，不反向阻塞全屏首播和换集响应。
  String _resolvePlaybackUrl(String url) {
    if (!_hasResolvedM3u8ProxyUrl ||
        _m3u8ProxyUrl.isEmpty ||
        !url.startsWith('http')) {
      return url;
    }
    return '$_m3u8ProxyUrl${Uri.encodeComponent(url)}';
  }

  /// 标记全屏播放器开始加载。
  void _markFullscreenPlayerLoading({Duration? anchorPosition}) {
    _fullscreenPlayerLoading = true;
    _fullscreenPlaybackStarted = false;
    _fullscreenLoadingAnchorPosition =
        anchorPosition ?? _currentPlaybackPosition;
  }

  /// 结束全屏播放器加载态，调用方必须先确认播放时间点已经前进。
  void _finishFullscreenPlayerLoading() {
    if (!_fullscreenPlayerLoading) {
      return;
    }
    _fullscreenPlayerLoading = false;
    _fullscreenLoadingAnchorPosition = null;
    _scheduleChromeRefresh();
  }

  /// 标记当前全屏视频已经真正起播。
  void _markFullscreenPlaybackStarted() {
    if (_fullscreenPlaybackStarted) {
      return;
    }
    _fullscreenPlaybackStarted = true;
    _finishFullscreenPlayerLoading();
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
    final key = event.logicalKey;

    // 左右方向键需要同时响应按下和抬起，短按与长按语义在这里统一分流。
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_menuVisible && !(event is KeyUpEvent && _activeSeekKey == key)) {
        return KeyEventResult.ignored;
      }
      return _handleSeekKeyEvent(event, direction: -1);
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_menuVisible && !(event is KeyUpEvent && _activeSeekKey == key)) {
        return KeyEventResult.ignored;
      }
      return _handleSeekKeyEvent(event, direction: 1);
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_isBackKey(key)) {
      _handleBackKey();
      return KeyEventResult.handled;
    }

    if (_menuVisible) {
      return KeyEventResult.ignored;
    }

    if (_isOpenMenuKey(key)) {
      _showMenu();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      unawaited(_togglePlayPause());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 判断是否为返回类按键。
  bool _isBackKey(LogicalKeyboardKey key) {
    return TvBackIntent.isBackKey(key);
  }

  /// 判断是否为打开底部菜单的遥控器按键。
  bool _isOpenMenuKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.mediaTopMenu;
  }

  /// 处理全局遥控器按键。
  ///
  /// 共享播放器或平台视图可能不在根 Focus 下，因此全屏页额外监听全局按键。
  bool _handleGlobalKeyEvent(KeyEvent event) {
    // 根焦点可用时交给 Focus 正常派发，避免同一个遥控器按键被处理两次。
    if (_rootFocusNode.hasFocus) {
      return false;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_menuVisible && !(event is KeyUpEvent && _activeSeekKey == key)) {
        return false;
      }
      _handleSeekKeyEvent(event, direction: -1);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_menuVisible && !(event is KeyUpEvent && _activeSeekKey == key)) {
        return false;
      }
      _handleSeekKeyEvent(event, direction: 1);
      return true;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

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

    if (_isOpenMenuKey(key)) {
      _showMenu();
      return true;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      unawaited(_togglePlayPause());
      return true;
    }

    return false;
  }

  /// 处理左右方向键的短按和长按 seek 语义。
  KeyEventResult _handleSeekKeyEvent(KeyEvent event, {required int direction}) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      _handleSeekKeyUp(key);
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _handleSeekKeyDown(key, direction);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// 执行 TV 返回语义。
  void _handleBackKey() {
    if (_menuVisible) {
      _hideMenu();
      return;
    }
    unawaited(_handleExitWithSave());
  }

  /// 退出全屏前先保存一次当前进度。
  ///
  /// 返回首页后可能立刻刷新“继续观看”，这里等待保存完成，减少新旧源记录并存窗口。
  Future<void> _handleExitWithSave() async {
    await _saveProgress(force: true, scene: '全屏返回');
    if (!mounted) {
      return;
    }
    final exitRequested = widget.onExitRequested;
    if (exitRequested != null) {
      exitRequested();
      return;
    }
    await Navigator.of(context).maybePop();
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
      _syncDanmakuPlaybackState(forcePlaying: !injectedController.isPlaying);
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
    _syncDanmakuPlaybackState(forcePlaying: !controller.isPlaying);
  }

  /// 处理 seek 方向键按下，启动内部长按调度。
  void _handleSeekKeyDown(LogicalKeyboardKey key, int direction) {
    final duration = _currentPlaybackDuration;
    if (duration <= Duration.zero) {
      return;
    }

    // 新一轮按压开始后先冻结提示隐藏，避免长按过程中提示层提前消失。
    _seekOverlayTimer?.cancel();
    _seekDirection = direction;
    _seekPreviewDuration = duration;
    _seekPreviewPosition ??= _currentPlaybackPosition;

    if (_activeSeekKey == key) {
      return;
    }

    _clearSeekHoldTracking();
    _activeSeekKey = key;
    _seekHoldElapsed = Duration.zero;
    _seekHoldHasRepeated = false;
    _seekHoldAppliedSeconds = 0;
    _seekHoldLongPressStarted = false;
    _scheduleNextSeekHoldTick();
  }

  /// 处理 seek 方向键抬起，区分短按与长按。
  void _handleSeekKeyUp(LogicalKeyboardKey key) {
    if (_activeSeekKey != key) {
      return;
    }

    final hadRepeated = _seekHoldHasRepeated;
    final direction = _seekDirection;
    _clearSeekHoldTracking();

    // 没有进入连续滚动时按短按处理，保持单次 10 秒跳转语义。
    if (!hadRepeated && direction != 0) {
      _applySeekDelta(direction, TvFullscreenSeekStep.initialPressSeconds);
      return;
    }

    final recoveryAnchor = _seekPreviewPosition ?? _currentPlaybackPosition;
    // 长按松手后如果视频仍在播放，则立即收起中心提示和底部进度壳层。
    if (mounted) {
      setState(() {
        _seekOverlayVisible = false;
      });
    }
    _markFullscreenPlayerLoading(anchorPosition: recoveryAnchor);
    _resetSeekState();
    _scheduleChromeRefresh();
  }

  /// 按当前长按阶段安排下一次 seek tick。
  void _scheduleNextSeekHoldTick() {
    _seekHoldTimer?.cancel();
    final activeKey = _activeSeekKey;
    if (activeKey == null) {
      return;
    }

    int intervalMicros;
    if (!_seekHoldLongPressStarted) {
      intervalMicros =
          TvFullscreenSeekStep.longPressStartThreshold.inMicroseconds -
              _seekHoldElapsed.inMicroseconds;
    } else {
      final longPressElapsedMicros = _seekHoldElapsed.inMicroseconds -
          TvFullscreenSeekStep.longPressStartThreshold.inMicroseconds;
      final nextStepSeconds = TvFullscreenSeekStep.repeatStepForElapsed(
        Duration(microseconds: longPressElapsedMicros),
      );
      final nextTargetSeconds = _seekHoldAppliedSeconds + nextStepSeconds;
      final targetElapsedMicros =
          TvFullscreenSeekStep.elapsedMicrosecondsForTotalSeekSeconds(
        nextTargetSeconds,
      );
      final remainingMicros = targetElapsedMicros - longPressElapsedMicros;
      final fallbackMicros =
          TvFullscreenSeekStep.repeatIntervalMicrosecondsForElapsed(
        Duration(microseconds: longPressElapsedMicros),
      );
      intervalMicros = remainingMicros > 0 ? remainingMicros : fallbackMicros;
    }
    if (intervalMicros <= 0) {
      intervalMicros = 1;
    }
    final interval = Duration(microseconds: intervalMicros);
    _seekHoldTimer = Timer(interval, () {
      if (!mounted || _activeSeekKey != activeKey) {
        return;
      }

      _seekHoldElapsed += interval;
      if (!_seekHoldLongPressStarted) {
        _seekHoldLongPressStarted = true;
        _scheduleNextSeekHoldTick();
        return;
      }

      final longPressElapsed =
          _seekHoldElapsed - TvFullscreenSeekStep.longPressStartThreshold;
      final targetSeconds =
          TvFullscreenSeekStep.totalSeekSecondsForElapsed(longPressElapsed);
      final deltaSeconds = targetSeconds - _seekHoldAppliedSeconds;
      if (deltaSeconds > 0) {
        _seekHoldHasRepeated = true;
        _seekHoldAppliedSeconds = targetSeconds;
        _applySeekDelta(
          _seekDirection,
          deltaSeconds,
          markRecoveryLoading: false,
        );
      }
      _scheduleNextSeekHoldTick();
    });
  }

  /// 执行一次实际 seek，并刷新中心时间提示。
  void _applySeekDelta(
    int direction,
    int seconds, {
    bool markRecoveryLoading = true,
  }) {
    final duration = _currentPlaybackDuration;
    if (duration <= Duration.zero) {
      return;
    }

    _seekDirection = direction;
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
    if (markRecoveryLoading) {
      _markFullscreenPlayerLoading(anchorPosition: target);
    }
    _resetDanmakuIndex(target, clearVisible: false);
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
    bool controllerLoading;
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      if (injectedController is TvFullscreenVideoControllerProvider &&
          (injectedController as TvFullscreenVideoControllerProvider)
                  .videoController ==
              null) {
        return false;
      }
      controllerLoading = injectedController.isLoading;
    } else {
      final controller = _playerController;
      if (controller == null) {
        return false;
      }
      controllerLoading = controller.isLoading;
    }
    return _fullscreenPlayerLoading ||
        (!_fullscreenPlaybackStarted && controllerLoading);
  }

  /// 当前播放器下载速度文案。
  String get _fullscreenNetworkSpeedText {
    final injectedController = widget.playbackController;
    if (injectedController != null) {
      if (injectedController is TvFullscreenVideoControllerProvider &&
          (injectedController as TvFullscreenVideoControllerProvider)
                  .videoController ==
              null) {
        return '0KB/s';
      }
      return injectedController.networkSpeedText;
    }
    return _playerController?.networkSpeedText ?? '0KB/s';
  }

  /// 当前全屏视频是否已经真正起播。
  bool get _hasFullscreenPlaybackStarted {
    return _fullscreenPlaybackStarted;
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
      if (mounted) {
        setState(() {});
      }
      return;
    }
    await _playerController?.seekTo(position);
    if (mounted) {
      setState(() {});
    }
  }

  /// 限制时间在合法播放区间内。
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    final milliseconds = value.inMilliseconds.clamp(
      min.inMilliseconds,
      max.inMilliseconds,
    );
    return Duration(milliseconds: milliseconds);
  }

  /// 将当前播放位置保存为片头跳过点。
  void _setIntroToCurrentPosition() {
    final duration = _currentPlaybackDuration;
    final position = _currentPlaybackPosition;
    final seconds = duration > Duration.zero
        ? _clampDuration(position, Duration.zero, duration).inSeconds
        : math.max(0, position.inSeconds);
    setState(() => _skipIntroSeconds = seconds);
    unawaited(UserDataService.saveSkipIntroDuration(seconds));
  }

  /// 清空片头跳过点。
  void _clearIntroPosition() {
    setState(() => _skipIntroSeconds = 0);
    unawaited(UserDataService.saveSkipIntroDuration(0));
  }

  /// 将当前播放位置保存为片尾跳过点。
  void _setOutroToCurrentPosition() {
    final duration = _currentPlaybackDuration;
    if (duration <= Duration.zero) {
      return;
    }
    final position = _clampDuration(
      _currentPlaybackPosition,
      Duration.zero,
      duration,
    );
    // 片尾配置沿用“距离结尾剩余秒数”的业务语义。
    final seconds = (duration - position).inSeconds;
    setState(() => _skipOutroSeconds = seconds);
    unawaited(UserDataService.saveSkipOutroDuration(seconds));
  }

  /// 清空片尾跳过点。
  void _clearOutroPosition() {
    setState(() => _skipOutroSeconds = 0);
    unawaited(UserDataService.saveSkipOutroDuration(0));
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

  /// 清理当前长按 seek 调度状态，但保留预览结果给提示层复用。
  void _clearSeekHoldTracking() {
    _seekHoldTimer?.cancel();
    _seekHoldTimer = null;
    _activeSeekKey = null;
    _seekHoldElapsed = Duration.zero;
    _seekHoldHasRepeated = false;
    _seekHoldAppliedSeconds = 0;
    _seekHoldLongPressStarted = false;
  }

  /// 重置连续 seek 状态。
  void _resetSeekState() {
    _seekOverlayTimer?.cancel();
    _clearSeekHoldTracking();
    _seekDirection = 0;
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
    if (didPop) {
      // 系统返回已完成路由退出时补一次兜底保存，覆盖手势返回等非按键路径。
      unawaited(_saveProgress(force: true, scene: '全屏系统返回'));
      return;
    }
    if (!_menuVisible) {
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
    if (_suppressNextEpisodeFocusPin) {
      _suppressNextEpisodeFocusPin = false;
      return;
    }
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
    if (_suppressNextEpisodeGroupFocusPin) {
      _suppressNextEpisodeGroupFocusPin = false;
      final groupEpisodeIndexes = _episodeIndexesForGroup(
        _episodes.length,
        index,
      );
      final hasRememberedEpisodeInGroup = _lastFocusedEpisodeIndex != null &&
          _episodeBelongsToGroup(_lastFocusedEpisodeIndex!, index);
      if (!hasRememberedEpisodeInGroup && groupEpisodeIndexes.isNotEmpty) {
        _lastFocusedEpisodeIndex = groupEpisodeIndexes.first;
      }
      if (_episodeGroupIndex != index) {
        setState(() => _episodeGroupIndex = index);
      }
      return;
    }
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
      _suppressNextEpisodeFocusPin = true;
      if (_requestFocusIfMounted(_secondaryFocusNodeFor('episode', index))) {
        return true;
      }
      _suppressNextEpisodeFocusPin = false;
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
    _suppressNextEpisodeGroupFocusPin = true;
    final focused = _requestFocusIfMounted(
      _episodeGroupFocusNodeFor(normalizedGroupIndex),
    );
    if (!focused) {
      _suppressNextEpisodeGroupFocusPin = false;
    }
    return focused;
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
    final index = _sourcesByEpisodeCountDesc.indexWhere(
      (source) => source.source == detail.source && source.id == detail.id,
    );
    return index < 0 ? 0 : index;
  }

  /// 获取按集数倒序展示的线路列表。
  ///
  /// 集数相同时保留原始传入顺序，避免同集数线路位置抖动。
  List<SearchResult> get _sourcesByEpisodeCountDesc {
    final indexedSources = List<({int index, SearchResult source})>.generate(
      widget.sources.length,
      (index) => (index: index, source: widget.sources[index]),
    );
    indexedSources.sort((a, b) {
      final countCompare =
          b.source.episodes.length.compareTo(a.source.episodes.length);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.index.compareTo(b.index);
    });
    return indexedSources.map((entry) => entry.source).toList();
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
    _suppressNextEpisodeFocusPin = true;
    final focused = _requestFocusIfMounted(
      _secondaryFocusNodeFor('episode', episodeIndex),
    );
    if (!focused) {
      _suppressNextEpisodeFocusPin = false;
    }
    return focused;
  }

  /// 播放进度变化时按手机端节流策略保存。
  void _onVideoProgressUpdate() {
    final position = _currentPlaybackPosition;
    if (_hasPlaybackPositionAdvanced(
      current: position,
      anchor: _fullscreenLoadingAnchorPosition,
    )) {
      _markFullscreenPlaybackStarted();
    }
    unawaited(_retryPendingResumeSeekAfterProgress());
    unawaited(_saveProgress(scene: '全屏定时保存'));
  }

  /// 判断播放时间是否已经从本轮 loading 起点向前推进。
  bool _hasPlaybackPositionAdvanced({
    required Duration? current,
    required Duration? anchor,
  }) {
    if (current == null) {
      return false;
    }
    final baseline = anchor ?? Duration.zero;
    return current > baseline;
  }

  /// 保存当前播放进度。
  Future<void> _saveProgress(
      {bool force = false, required String scene}) async {
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

    final saved = await TvPlayRecordService.saveRecordAndCleanupOtherSources(
      context: context,
      playRecord: playRecord,
      keepSource: detail,
      videoInfo: widget.videoInfo,
    );
    if (!saved) {
      debugPrint('TV 全屏保存播放进度失败 [场景: $scene]');
    }
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

    final saved = await TvPlayRecordService.saveRecordAndCleanupOtherSources(
      context: context,
      playRecord: playRecord,
      keepSource: source,
      videoInfo: widget.videoInfo,
    );
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
    if (index == _episodeIndex) {
      _lastFocusedEpisodeIndex = index;
      _lastFocusedEpisodeGroupIndex = index ~/ _episodeGroupSize;
      _ensureCurrentSelectionsVisible();
      _hideMenu();
      return;
    }
    unawaited(_saveProgress(force: true, scene: scene));
    final nextGroupIndex = index ~/ _episodeGroupSize;
    _invalidateCachedPlayerLayer();
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

    _episodeCardSizeCache.clear();
    _invalidateCachedPlayerLayer();
    setState(() {
      _currentDetail = source;
      final maxEpisodeIndex =
          source.episodes.isEmpty ? 0 : source.episodes.length - 1;
      _episodeIndex = currentEpisode.clamp(0, maxEpisodeIndex).toInt();
      _episodeGroupIndex = _episodeIndex ~/ _episodeGroupSize;
      _pendingInitialPlaybackPosition =
          currentProgress > 0 ? Duration(seconds: currentProgress) : null;
      _hasAppliedInitialPlaybackPosition =
          _pendingInitialPlaybackPosition == null;
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
    if (_fitType == fitType) {
      return;
    }
    _invalidateCachedPlayerLayer();
    setState(() => _fitType = fitType);
    _effectiveVideoController?.setVideoFit(fitType);
  }

  /// 切换播放倍速。
  Future<void> _switchSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _effectiveVideoController?.setSpeed(speed);
    _refreshDanmakuOption();
  }

  /// 释放已绑定的弹幕控制器。
  void _detachDanmakuController() {
    _danmakuController = null;
  }

  /// 根据当前播放上下文自动加载弹幕。
  Future<void> _loadDanmakuForCurrentEpisode({required bool force}) async {
    if (!_danmakuEnabled) {
      return;
    }

    final detail = _currentDetail;
    if (detail == null) {
      return;
    }

    final service = widget.danmakuService ?? TvDanmakuService();
    final token = ++_danmakuLoadToken;
    final requestKey =
        '${detail.source}::${detail.id}::$_episodeIndex::${detail.title}';

    if (!force && _isDanmakuLoading && _activeDanmakuRequestKey == requestKey) {
      return;
    }
    _activeDanmakuRequestKey = requestKey;

    setState(() {
      _isDanmakuLoading = true;
    });

    final result = await service.loadDanmaku(
      currentSource: detail.source,
      currentId: detail.id,
      episodeIndex: _episodeIndex,
      videoTitle: _title,
      sourceName: _sourceName,
      episodeTitle: _episodeIndex < _episodeTitles.length
          ? _episodeTitles[_episodeIndex]
          : null,
    );

    if (!mounted || token != _danmakuLoadToken) {
      return;
    }

    if (result == null) {
      setState(() {
        _isDanmakuLoading = false;
      });
      _activeDanmakuRequestKey = null;
      _clearDanmakuState(clearList: true);
      return;
    }

    if (!force &&
        _currentDanmakuEpisodeId == result.episodeId &&
        _danmakuList.isNotEmpty) {
      setState(() {
        _isDanmakuLoading = false;
      });
      _activeDanmakuRequestKey = null;
      return;
    }

    setState(() {
      _danmakuList = result.comments;
      _currentDanmakuEpisodeId = result.episodeId;
      _isDanmakuLoading = false;
      _danmakuOverlayVersion++;
    });
    _activeDanmakuRequestKey = null;
    _resetDanmakuIndex(_currentPlaybackPosition, clearVisible: true);
    _refreshDanmakuOption();
    _syncDanmakuPlaybackState();
    _sendDanmakuByPosition(_currentPlaybackPosition);
  }

  /// 手动加载指定弹幕剧集。
  Future<void> _loadManualDanmaku({
    required int episodeId,
    required String searchKeyword,
    required DanmakuSearchAnime anime,
    required int episodeOffset,
  }) async {
    final detail = _currentDetail;
    if (detail == null) {
      return;
    }

    final service = widget.danmakuService ?? TvDanmakuService();
    final comments = await service.loadDanmakuByEpisodeId(episodeId);
    if (!mounted) {
      return;
    }

    await service.saveManualSelection(
      currentSource: detail.source,
      currentId: detail.id,
      episodeIndex: _episodeIndex,
      episodeId: episodeId,
      searchKeyword: searchKeyword,
      fallbackTitle: _title,
      orderedEpisodes: anime.episodes,
      selectedEpisodeOffset: episodeOffset,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _danmakuList = comments;
      _currentDanmakuEpisodeId = episodeId;
      _danmakuOverlayVersion++;
    });
    _resetDanmakuIndex(_currentPlaybackPosition, clearVisible: true);
    _refreshDanmakuOption();
    _syncDanmakuPlaybackState();
    _sendDanmakuByPosition(_currentPlaybackPosition);
  }

  /// 切换弹幕开关并同步持久化配置。
  Future<void> _toggleDanmakuEnabled() async {
    final nextEnabled = !_danmakuEnabled;
    final nextSettings = _danmakuSettings.copyWith(enabled: nextEnabled);
    setState(() {
      _danmakuEnabled = nextEnabled;
      _danmakuSettings = nextSettings;
    });

    final service = widget.danmakuService ?? TvDanmakuService();
    await service.saveSettings(nextSettings);

    if (!nextEnabled) {
      _clearDanmakuState(clearList: true);
      return;
    }
    await _loadDanmakuForCurrentEpisode(force: true);
  }

  /// 清理当前弹幕时间轴与控制器内容。
  void _clearDanmakuState({required bool clearList}) {
    _danmakuIndex = 0;
    _lastDanmakuCheckTime = -1;
    _danmakuController?.clear();
    if (!clearList || !mounted) {
      return;
    }
    setState(() {
      _danmakuList = const <DanmakuComment>[];
      _currentDanmakuEpisodeId = null;
      _danmakuOverlayVersion++;
    });
  }

  /// 重新计算当前播放位置对应的弹幕游标。
  void _resetDanmakuIndex(
    Duration position, {
    required bool clearVisible,
  }) {
    _danmakuIndex = _findDanmakuIndex(position);
    _lastDanmakuCheckTime = -1;
    if (clearVisible) {
      _danmakuController?.clear();
    }
  }

  /// 二分定位当前时间应从哪条弹幕继续发送。
  int _findDanmakuIndex(Duration position) {
    if (_danmakuList.isEmpty) {
      return 0;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    var low = 0;
    var high = _danmakuList.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (_danmakuList[mid].time < currentSeconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// 按当前播放位置推送弹幕。
  void _sendDanmakuByPosition(Duration position) {
    if (!_danmakuEnabled ||
        _danmakuController == null ||
        _danmakuList.isEmpty ||
        _isPlaybackLoading) {
      return;
    }

    final currentSeconds = position.inMilliseconds / 1000.0;
    if ((currentSeconds - _lastDanmakuCheckTime).abs() < 0.15) {
      return;
    }
    _lastDanmakuCheckTime = currentSeconds;

    while (_danmakuIndex < _danmakuList.length) {
      final comment = _danmakuList[_danmakuIndex];
      if (comment.time > currentSeconds) {
        break;
      }
      if (_danmakuSettings.hideColor && comment.color != 16777215) {
        _danmakuIndex++;
        continue;
      }
      _danmakuController?.addDanmaku(
        DanmakuService.convertToDanmakuItem(comment),
      );
      _danmakuIndex++;
    }
  }

  /// 同步弹幕的播放和暂停状态。
  void _syncDanmakuPlaybackState({bool? forcePlaying}) {
    final controller = _danmakuController;
    if (!_danmakuEnabled || controller == null) {
      return;
    }
    final shouldPlay = forcePlaying ?? _isPlaybackPlaying;
    if (shouldPlay) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  /// 同步弹幕渲染参数。
  void _refreshDanmakuOption() {
    final controller = _danmakuController;
    if (!_danmakuEnabled || controller == null) {
      return;
    }
    controller.updateOption(
      TvDanmakuService.buildDanmakuOption(
        _resolvedDanmakuSettings,
        playbackSpeed: _playbackSpeed,
      ),
    );
  }

  /// 绑定底层弹幕控制器。
  void _handleDanmakuControllerCreated(DanmakuController controller) {
    _danmakuController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_danmakuController, controller)) {
        return;
      }
      _refreshDanmakuOption();
      _resetDanmakuIndex(_currentPlaybackPosition, clearVisible: true);
      _syncDanmakuPlaybackState();
      _sendDanmakuByPosition(_currentPlaybackPosition);
    });
  }

  /// 获取 TV 端实际渲染用弹幕设置。
  DanmakuSettings get _resolvedDanmakuSettings {
    return _danmakuSettings.copyWith(
      fontSize: _danmakuSettings.fontSize * _tvDanmakuFontMultiplier,
    );
  }

  /// 是否需要展示 TV 弹幕叠层。
  bool get _shouldShowDanmakuOverlay {
    return _danmakuEnabled &&
        !_isDanmakuLoading &&
        _currentDanmakuEpisodeId != null;
  }

  /// 打开 TV 手动匹配弹幕面板。
  Future<void> _showDanmakuMatchScreen() async {
    final service = widget.danmakuService ?? TvDanmakuService();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.56),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: SizedBox(
            width: 780,
            height: 720,
            child: TvDanmakuMatchScreen(
              initialQuery: _title,
              currentEpisodeId: _currentDanmakuEpisodeId,
              currentEpisodeCommentCount: _danmakuList.length,
              onSearch: service.searchEpisodes,
              onEpisodeSelected:
                  (episodeId, searchKeyword, anime, episodeOffset) {
                Navigator.of(dialogContext).pop();
                unawaited(
                  _loadManualDanmaku(
                    episodeId: episodeId,
                    searchKeyword: searchKeyword,
                    anime: anime,
                    episodeOffset: episodeOffset,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (mounted && _menuVisible) {
      _scheduleMenuAutoHide();
    }
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
              if (_shouldShowDanmakuOverlay)
                Positioned.fill(
                  child: TvDanmakuOverlay(
                    settings: _resolvedDanmakuSettings,
                    playbackSpeed: _playbackSpeed,
                    overlayVersion: _danmakuOverlayVersion,
                    currentEpisodeId: _currentDanmakuEpisodeId,
                    onControllerCreated: _handleDanmakuControllerCreated,
                  ),
                ),
              if (_shouldShowPlaybackChrome)
                Positioned.fill(child: _buildPlaybackChromeScrim()),
              if (_shouldShowTopDecorations) _buildTopDecorations(),
              if (_shouldShowCenterPlayButton) _buildCenterPlayButton(),
              if (_shouldShowPlaybackChrome) _buildBottomProgressBar(),
              if (_isPlaybackLoading) _buildFullscreenLoadingOverlay(),
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
    widget.testHooks?.onAdFilterResolved?.call(_adFilterEnabled);

    final signature = _playerLayerSignature();
    final cachedLayer = _cachedPlayerLayer;
    if (cachedLayer != null && _cachedPlayerLayerSignature == signature) {
      return cachedLayer;
    }

    final player = widget.playerBuilder?.call(
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
          adFilterEnabled: _adFilterEnabled,
          onControllerCreated: _handlePlayerControllerCreated,
          onReady: _handleFullscreenReadySignal,
          onPlay: _handleFullscreenPlaySignal,
          onPause: () {
            _scheduleChromeRefresh();
          },
          onVideoCompleted: _handleVideoCompleted,
        );

    _cachedPlayerLayerSignature = signature;
    _cachedPlayerLayer = RepaintBoundary(
      key: const ValueKey('tv-fullscreen-player-layer'),
      child: player,
    );
    return _cachedPlayerLayer!;
  }

  /// 构建全屏播放器 loading 转圈和网速提示。
  Widget _buildFullscreenLoadingOverlay() {
    final networkSpeedText = _fullscreenNetworkSpeedText;
    return Center(
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('tv-fullscreen-loading'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
                value: _isFlutterTestEnvironment ? 0.72 : null,
              ),
              const SizedBox(height: 12),
              Text(
                '加载中',
                style: FontUtils.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                networkSpeedText,
                style: FontUtils.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 记录播放器控制器并执行一次首次续播加载。
  void _handlePlayerControllerCreated(VideoPlayerWidgetController controller) {
    _playerController = controller;
    _attachVideoControllerListeners(controller);
    _lastRequestedPlaybackUrl = null;
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

  /// 处理底层播放器 ready 信号。
  void _handleFullscreenReadySignal() {
    _scheduleChromeRefresh();
  }

  /// 处理底层播放器 play 信号。
  void _handleFullscreenPlaySignal() {
    _scheduleChromeRefresh();
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
    final timeTextStyle = FontUtils.poppins(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.96),
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

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
              SizedBox(
                key: const ValueKey('tv-fullscreen-bottom-current-time-slot'),
                width: _progressTimeSlotWidth,
                child: Text(
                  _formatProgressBarDuration(clampedPosition),
                  style: timeTextStyle,
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
              SizedBox(
                width: _progressTimeSlotWidth,
                child: Text(
                  _formatProgressBarDuration(duration),
                  textAlign: TextAlign.right,
                  style: timeTextStyle,
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
      child: RepaintBoundary(
        key: const ValueKey('tv-fullscreen-menu-repaint-boundary'),
        child: Container(
          key: const ValueKey('tv-fullscreen-menu'),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF111822).withValues(alpha: 0.72),
                const Color(0xFF060A10).withValues(alpha: 0.78),
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
                      minWidth: 67,
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
          height: _secondaryMenuSize(_episodeCardBaseMinHeight),
          itemCount: visibleIndexes.length,
          itemBuilder: (itemIndex) {
            final index = visibleIndexes[itemIndex];
            final label = _episodeTitles.length == _episodes.length
                ? _episodeTitles[index]
                : '第${index + 1}集';
            final cardSize = _resolveEpisodeCardSize(label);
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
                  minWidth: cardSize.width,
                  maxWidth: cardSize.width,
                  minHeight: cardSize.height,
                  textFontSize: _secondaryMenuFontSize,
                  horizontalPadding: _secondaryMenuHorizontalInset,
                  maxLines: 4,
                  textOverflow: TextOverflow.clip,
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
    final sources = _sourcesByEpisodeCountDesc;
    return _buildHorizontalChoices(
      key: const ValueKey('tv-fullscreen-source-list'),
      height: _secondaryMenuSize(88),
      itemCount: sources.length,
      itemBuilder: (index) {
        final source = sources[index];
        final selected = source.source == _currentDetail?.source &&
            source.id == _currentDetail?.id;
        final edgeShakeKey = _secondaryEdgeShakeKeyFor('source', index);
        final isFirstItem = index == 0;
        final isLastItem = index == sources.length - 1;
        return TvEdgeShake(
          key: edgeShakeKey,
          child: _TvPlayerMenuButton(
            focusNode: _secondaryFocusNodeFor('source', index),
            label: source.sourceName,
            trailingText: '（${source.episodes.length}）',
            selected: selected,
            minWidth: _secondaryMenuSize(190),
            maxWidth: _secondaryMenuSize(260),
            minHeight: _secondaryMenuSize(88),
            textFontSize: _secondaryMenuFontSize,
            horizontalPadding: _secondaryMenuHorizontalInset,
            maxLines: 2,
            textOverflow: TextOverflow.clip,
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
            minWidth: _secondaryMenuSize(67),
            minHeight: _secondaryMenuDefaultHeight,
            textFontSize: _secondaryMenuFontSize,
            horizontalPadding: _secondaryMenuHorizontalInset,
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
            minWidth: _secondaryMenuSize(62),
            minHeight: _secondaryMenuDefaultHeight,
            textFontSize: _secondaryMenuFontSize,
            horizontalPadding: _secondaryMenuHorizontalInset,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '确认/空格/Enter 设置当前时间，长按清空',
          style: FontUtils.poppins(
            fontSize: 13,
            color: const Color(0xFF98A2A8),
          ),
        ),
        const SizedBox(height: 8),
        _buildHorizontalChoices(
          key: const ValueKey('tv-fullscreen-other-list'),
          itemCount: 4,
          itemBuilder: (index) {
            final edgeShakeKey = _secondaryEdgeShakeKeyFor('other', index);
            final isFirstItem = index == 0;
            final isLastItem = index == 3;
            if (index == 0) {
              return TvEdgeShake(
                key: edgeShakeKey,
                child: _TvPlayerMenuButton(
                  focusNode: _secondaryFocusNodeFor('other', index),
                  label: '片头 ${_formatProgressBarDuration(
                    Duration(seconds: _skipIntroSeconds),
                  )}',
                  selected: false,
                  minWidth: _secondaryMenuSize(78),
                  minHeight: _secondaryMenuDefaultHeight,
                  textFontSize: _secondaryMenuFontSize,
                  horizontalPadding: _secondaryMenuHorizontalInset,
                  onArrowLeft: isFirstItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right)
                      : null,
                  onArrowUp: _keepMenuFocusInCurrentRow,
                  onArrowDown: _focusCurrentPrimaryMenu,
                  onFocus: () => _rememberSecondaryFocus('other', index),
                  onPressed: _setIntroToCurrentPosition,
                  onLongPressed: _clearIntroPosition,
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
                  minWidth: _secondaryMenuSize(78),
                  minHeight: _secondaryMenuDefaultHeight,
                  textFontSize: _secondaryMenuFontSize,
                  horizontalPadding: _secondaryMenuHorizontalInset,
                  onArrowLeft: isFirstItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right)
                      : null,
                  onArrowUp: _keepMenuFocusInCurrentRow,
                  onArrowDown: _focusCurrentPrimaryMenu,
                  onFocus: () => _rememberSecondaryFocus('other', index),
                  onPressed: _setOutroToCurrentPosition,
                  onLongPressed: _clearOutroPosition,
                ),
              );
            }
            if (index == 2) {
              return TvEdgeShake(
                key: edgeShakeKey,
                child: _TvPlayerMenuButton(
                  focusNode: _secondaryFocusNodeFor('other', index),
                  label: _danmakuEnabled ? '弹幕 开' : '弹幕 关',
                  selected: _danmakuEnabled,
                  minWidth: _secondaryMenuSize(78),
                  minHeight: _secondaryMenuDefaultHeight,
                  textFontSize: _secondaryMenuFontSize,
                  horizontalPadding: _secondaryMenuHorizontalInset,
                  onArrowLeft: isFirstItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.left)
                      : null,
                  onArrowRight: isLastItem
                      ? () =>
                          edgeShakeKey.currentState?.shake(AxisDirection.right)
                      : null,
                  onArrowUp: _keepMenuFocusInCurrentRow,
                  onArrowDown: _focusCurrentPrimaryMenu,
                  onFocus: () => _rememberSecondaryFocus('other', index),
                  onPressed: () {
                    unawaited(_toggleDanmakuEnabled());
                  },
                ),
              );
            }
            return TvEdgeShake(
              key: edgeShakeKey,
              child: _TvPlayerMenuButton(
                focusNode: _secondaryFocusNodeFor('other', index),
                label: '手动匹配',
                selected: false,
                minWidth: _secondaryMenuSize(96),
                minHeight: _secondaryMenuDefaultHeight,
                textFontSize: _secondaryMenuFontSize,
                horizontalPadding: _secondaryMenuHorizontalInset,
                onArrowLeft: isFirstItem
                    ? () => edgeShakeKey.currentState?.shake(AxisDirection.left)
                    : null,
                onArrowRight: isLastItem
                    ? () =>
                        edgeShakeKey.currentState?.shake(AxisDirection.right)
                    : null,
                onArrowUp: _keepMenuFocusInCurrentRow,
                onArrowDown: _focusCurrentPrimaryMenu,
                onFocus: () => _rememberSecondaryFocus('other', index),
                onPressed: () {
                  unawaited(_showDanmakuMatchScreen());
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建横向二级菜单列表。
  Widget _buildHorizontalChoices({
    required Key key,
    ScrollController? controller,
    double height = _secondaryMenuDefaultHeight,
    required int itemCount,
    required Widget Function(int index) itemBuilder,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
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

  /// 按二级菜单比例缩放尺寸。
  static double _secondaryMenuSize(double value) {
    return value * _secondaryMenuScale;
  }

  /// 构建空提示。
  Widget _buildHint(String text) {
    return SizedBox(
      height: _secondaryMenuDefaultHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: FontUtils.poppins(
            fontSize: _secondaryMenuFontSize,
            color: const Color(0xFF98A2A8),
          ),
        ),
      ),
    );
  }

  /// 按片名文本测量选集卡片尺寸。
  ///
  /// 先根据单行标题宽度算出卡片宽度，再按该宽度测量折行后的高度。
  _TvPlayerMenuCardSize _resolveEpisodeCardSize(String label) {
    final safeLabel = label.trim().isEmpty ? '第${_episodeIndex + 1}集' : label;
    final cachedSize = _episodeCardSizeCache[safeLabel];
    if (cachedSize != null) {
      return cachedSize;
    }

    final textStyle = FontUtils.poppins(
      fontSize: _secondaryMenuFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );

    final widthPainter = TextPainter(
      text: TextSpan(text: safeLabel, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);

    final cardWidth = math
        .max(
          _secondaryMenuSize(_episodeCardBaseMinWidth),
          math.min(
            _secondaryMenuSize(_episodeCardMaxWidth),
            widthPainter.size.width + _secondaryMenuHorizontalPadding,
          ),
        )
        .ceilToDouble();

    final heightPainter = TextPainter(
      text: TextSpan(text: safeLabel, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 4,
      ellipsis: '…',
    )..layout(
        maxWidth: math.max(
          1,
          cardWidth - _secondaryMenuHorizontalPadding,
        ),
      );

    final cardHeight = math
        .max(
          _secondaryMenuSize(_episodeCardBaseMinHeight),
          heightPainter.height + _secondaryMenuVerticalPadding,
        )
        .ceilToDouble();

    final size = _TvPlayerMenuCardSize(
      width: cardWidth,
      height: cardHeight,
    );
    _episodeCardSizeCache[safeLabel] = size;
    return size;
  }
}

/// TV 全屏播放器画面层签名。
///
/// 只有这些字段变化才会影响底层播放器 Widget 配置；菜单显隐、焦点位置、
/// seek 提示和顶部时钟不进入签名，避免操作态反复更新 Android 平台视图。
class _TvFullscreenPlayerLayerSignature {
  /// 创建播放器画面层签名。
  const _TvFullscreenPlayerLayerSignature({
    required this.title,
    required this.year,
    required this.sourceName,
    required this.source,
    required this.sourceId,
    required this.episodeIndex,
    required this.episodeCount,
    required this.episodeTitles,
    required this.fitType,
    required this.adFilterEnabled,
    required this.playerBuilder,
  });

  /// 当前标题。
  final String title;

  /// 当前年份。
  final String year;

  /// 当前来源名称。
  final String sourceName;

  /// 当前来源标识。
  final String? source;

  /// 当前来源内视频 ID。
  final String? sourceId;

  /// 当前选集下标。
  final int episodeIndex;

  /// 当前选集总数。
  final int episodeCount;

  /// 当前选集标题列表。
  final List<String> episodeTitles;

  /// 当前画面比例。
  final VideoFitType fitType;

  /// 当前自动去广告开关。
  final bool adFilterEnabled;

  /// 当前测试或特殊播放器构建函数。
  final TvFullscreenPlayerBuilder? playerBuilder;

  @override
  bool operator ==(Object other) {
    return other is _TvFullscreenPlayerLayerSignature &&
        other.title == title &&
        other.year == year &&
        other.sourceName == sourceName &&
        other.source == source &&
        other.sourceId == sourceId &&
        other.episodeIndex == episodeIndex &&
        other.episodeCount == episodeCount &&
        other.fitType == fitType &&
        other.adFilterEnabled == adFilterEnabled &&
        identical(other.playerBuilder, playerBuilder) &&
        listEquals(other.episodeTitles, episodeTitles);
  }

  @override
  int get hashCode => Object.hash(
        title,
        year,
        sourceName,
        source,
        sourceId,
        episodeIndex,
        episodeCount,
        fitType,
        adFilterEnabled,
        identityHashCode(playerBuilder),
        Object.hashAll(episodeTitles),
      );
}

/// TV 播放器二级卡片尺寸。
class _TvPlayerMenuCardSize {
  /// 创建 TV 播放器二级卡片尺寸。
  const _TvPlayerMenuCardSize({
    required this.width,
    required this.height,
  });

  /// 卡片宽度。
  final double width;

  /// 卡片高度。
  final double height;
}

/// TV 播放器菜单按钮。
class _TvPlayerMenuButton extends StatelessWidget {
  /// 创建 TV 播放器菜单按钮。
  const _TvPlayerMenuButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.focusNode,
    this.trailingText,
    this.onLongPressed,
    this.onFocus,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
    this.minWidth = 118,
    this.maxWidth = 147,
    this.minHeight = 56,
    this.textFontSize = 18,
    this.horizontalPadding = 14,
    this.maxLines = 1,
    this.textOverflow = TextOverflow.ellipsis,
    this.autoScrollOnFocus = true,
  });

  /// 按钮文案。
  final String label;

  /// 按钮文案右侧补充信息。
  final String? trailingText;

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

  /// 确认键长按回调。
  final VoidCallback? onLongPressed;

  /// 最小宽度。
  final double minWidth;

  /// 最大宽度。
  final double maxWidth;

  /// 最小高度。
  final double minHeight;

  /// 文案字号。
  final double textFontSize;

  /// 横向内边距。
  final double horizontalPadding;

  /// 文案最大行数。
  final int maxLines;

  /// 文案溢出策略。
  final TextOverflow textOverflow;

  /// 获焦时是否使用通用自动滚动。
  final bool autoScrollOnFocus;

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    return TvFocusable(
      focusNode: focusNode,
      autoScrollOnFocus: autoScrollOnFocus,
      onPressed: onPressed,
      onLongPressed: onLongPressed,
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
          duration: Duration.zero,
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: selected ? palette.accent : const Color(0xFF303741),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: _buildLabelText(),
        );
      },
    );
  }

  /// 构建按钮主文案和右侧补充文案。
  Widget _buildLabelText() {
    final style = FontUtils.poppins(
      fontSize: textFontSize,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );
    final extraText = trailingText;
    if (extraText == null || extraText.isEmpty) {
      return Text(
        label,
        maxLines: maxLines,
        overflow: textOverflow,
        softWrap: maxLines > 1,
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: textOverflow,
            softWrap: maxLines > 1,
            style: style,
          ),
        ),
        Text(
          extraText,
          maxLines: maxLines,
          overflow: textOverflow,
          softWrap: false,
          style: style,
        ),
      ],
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
            fontSize: 15,
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
