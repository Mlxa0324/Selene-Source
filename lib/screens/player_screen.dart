import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/video_info.dart';
import '../widgets/video_menu_bottom_sheet.dart';
import '../widgets/video_player_surface.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/video_card.dart';
import '../services/api_service.dart';
import '../services/m3u8_service.dart';
import '../services/douban_service.dart';
import '../services/user_data_service.dart';
import '../services/search_service.dart';
import '../models/search_result.dart';
import '../models/douban_movie.dart';
import '../models/play_record.dart';
import '../services/page_cache_service.dart';
import '../services/local_mode_storage_service.dart';
import '../services/download_service.dart';
import '../services/fullscreen_orientation_controller.dart';
import '../widgets/switch_loading_overlay.dart';
import '../widgets/dlna_player.dart';
import '../widgets/dlna_device_dialog.dart';
import '../services/mobile_orientation_service.dart';
import '../utils/device_utils.dart';
import '../utils/fullscreen_orientation_policy.dart';
import '../utils/player_rotation_lock_policy.dart';
import '../widgets/player_details_panel.dart';
import '../widgets/player_episodes_panel.dart';
import '../widgets/player_sources_panel.dart';
import '../widgets/player_settings_panel.dart';
import '../widgets/player_sleep_timer_panel.dart';
import '../widgets/danmaku_settings_panel.dart';
import '../widgets/danmaku_match_panel.dart';
import '../widgets/player_download_panel.dart';
import '../widgets/windows_title_bar.dart';
import '../services/danmaku_service.dart';
import '../services/sleep_timer_service.dart';
import '../models/danmaku_model.dart';
import '../utils/font_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';

@visibleForTesting
int findDanmakuSeekIndex(
  List<DanmakuComment> comments,
  Duration position,
) {
  if (comments.isEmpty) {
    return 0;
  }

  final targetTime = position.inMilliseconds / 1000.0;
  var low = 0;
  var high = comments.length;

  while (low < high) {
    final mid = low + ((high - low) >> 1);
    if (comments[mid].time <= targetTime) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }

  return low;
}

@visibleForTesting
void runDanmakuResumeCallbacks({
  required void Function() sync,
}) {
  sync();
}

@visibleForTesting
void runDanmakuSeekCallbacks({
  required void Function() resetIndex,
  required void Function() clearVisible,
}) {
  resetIndex();
}

class PlayerScreen extends StatefulWidget {
  final String? source;
  final String? id;
  final String title;
  final String? year;
  final String? stitle;
  final String? stype;
  final String? prefer;
  final String? localPath; // 本地播放路径
  final SearchResult? initialVideoDetail; // 初始详情（用于离线播放）
  final int initialEpisodeIndex; // 初始集数索引
  final List<String>? localEpisodeIds; // 离线播放时每集对应的任务 ID
  final List<int>? localEpisodeNumbers; // 离线播放时每集对应的原始集序（1 开始）

  const PlayerScreen({
    super.key,
    this.source,
    this.id,
    required this.title,
    this.year,
    this.stitle,
    this.stype,
    this.prefer,
    this.localPath,
    this.initialVideoDetail,
    this.initialEpisodeIndex = 0,
    this.localEpisodeIds,
    this.localEpisodeNumbers,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 记录活跃实例，防止声音重叠
  static final List<_PlayerScreenState> _instances = [];

  // 强制关闭旧实例
  void _forceClose() {
    if (mounted) {
      debugPrint('检测到新播放器实例，正在释放旧实例资源防止声音重叠');
      try {
        // 销毁控制器释放资源，这是解决声音重叠的关键
        _videoPlayerController?.dispose();
        _videoPlayerController = null;
        // 重置状态
        if (mounted) {
          setState(() {
            _isCasting = false;
          });
        }
      } catch (e) {
        debugPrint('释放旧实例资源失败: $e');
      }
    }
  }

  late SystemUiOverlayStyle _originalStyle;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _showError = false;

  // 缓存设备类型，避免分辨率变化时改变布局
  late bool _isTablet;
  late bool _isPortraitTablet;

  // 加载状态
  bool _isLoading = true;
  String _loadingMessage = '正在搜索播放源...';
  String _loadingEmoji = '🔍'; // 加载图标 emoji
  double _loadingProgress = 0.0; // 加载进度百分比 (0.0 - 1.0)
  late AnimationController _loadingAnimationController;
  late AnimationController _textAnimationController;

  // 播放信息
  SearchResult? currentDetail;
  String searchTitle = '';
  late String videoTitle;
  String videoDesc = '';
  String videoYear = '';
  String videoCover = '';
  int videoDoubanID = 0;
  String currentSource = '';
  String currentID = '';
  bool needPrefer = false;
  int totalEpisodes = 0;
  late int currentEpisodeIndex;

  // 豆瓣详情数据
  DoubanMovieDetails? doubanDetails;

  // 所有源信息
  List<SearchResult> allSources = [];
  // 所有源测速结果
  Map<String, SourceSpeed> allSourcesSpeed = {};

  // VideoPlayerWidget 的控制器
  VideoPlayerWidgetController? _videoPlayerController;

  // 收藏状态
  bool _isFavorite = false;

  // 切换播放源/集数时的加载蒙版状态
  bool _showSwitchLoadingOverlay = false;
  String _switchLoadingMessage = '切换播放源...';
  Timer? _loadingTimeoutTimer;
  late AnimationController _switchLoadingAnimationController;

  // 投屏状态
  bool _isCasting = false;
  dynamic _dlnaDevice;
  Duration? _castStartPosition;
  Duration? _dlnaCurrentPosition; // DLNA 当前播放位置
  Duration? _dlnaCurrentDuration; // DLNA 视频总时长
  DLNAPlayerController? _dlnaPlayerController;

  // 选集相关状态
  bool _isEpisodesReversed = false;
  final ScrollController _episodesScrollController = ScrollController();
  final Map<int, GlobalKey> _episodeCardKeys = {};
  bool _isHoveringEpisodesPager = false;
  static const double _maxEpisodeCardWidth = 170.0;

  // 换源相关状态
  final ScrollController _sourcesScrollController = ScrollController();
  bool _isHoveringSourcesPager = false;
  static const double _maxSourceCardWidth = 170.0;

  // 是否正在关闭页面（用于立即隐藏播放器）
  bool _isClosing = false;

  // 刷新相关状态
  bool _isRefreshing = false;
  late AnimationController _refreshAnimationController;

  // 保存进度相关状态
  DateTime? _lastSaveTime;
  int? _lastSavePosition; // 上次保存的播放位置（秒）
  static const Duration _saveProgressInterval = Duration(seconds: 10);
  Duration? _resumeStartAt;

  // 网页全屏状态
  bool _isWebFullscreen = false;
  // 真全屏状态
  bool _isFullscreen = false;
  bool _isEnteringLandscapeFullscreen = false;
  List<DeviceOrientation>? _lastAppliedFullscreenOrientations;
  late final FullscreenOrientationController _fullscreenOrientationController =
      FullscreenOrientationController(
    orientationService: const MobileOrientationService(),
  );
  int _fullscreenTransitionSerial = 0;
  int _sourceSwitchRecordSerial = 0;
  int _sourceSpeedHydrationSerial = 0;
  bool _playerRotationLocked = false;
  List<DeviceOrientation>? _lockedPlayerOrientations;
  MobileInterfaceOrientation? _lastKnownPlayerInterfaceOrientation;

  // 侧边面板显示状态
  bool _isEpisodesPanelVisible = false;
  bool _isSourcesPanelVisible = false;
  bool _isShortDrama = false; // 💡 新增：是否为短剧模式
  bool _forcePcControlsVisible = false;

  // 播放设置状态
  VideoFitType _currentFitType = VideoFitType.contain;
  double _longPressSpeed = 2.0;
  bool _showPlaybackTime = true;
  ProgressDisplayMode _progressMode = ProgressDisplayMode.none;
  bool _showSystemTime = false; // 是否在右下角显示系统时间
  bool _hideCenterControlsWithBars = true; // 中间按钮是否跟随顶部/底部一起隐藏
  bool _adFilterEnabled = false; // 是否开启自动去广告
  bool _mediaKitPreloadEnabled = Platform.isMacOS;
  int _skipIntroDuration = 0;
  int _skipOutroDuration = 0;
  bool _isSeeking = false; // 是否正在执行跳转操作
  Timer? _sleepTimer;
  DateTime? _sleepTimerDeadline;
  bool _isHandlingSleepTimer = false;

  // 弹幕相关状态
  DanmakuController? _danmakuController;
  List<DanmakuComment> _danmakuList = [];
  int _danmakuIndex = 0;
  DanmakuSettings _danmakuSettings = const DanmakuSettings();
  int? _currentDanmakuEpisodeId;
  bool _isDanmakuLoading = false;
  bool _danmakuShouldPlay = false;
  bool _hasExplicitDanmakuState = false;
  int _danmakuControllerCreateCount = 0;
  int _danmakuViewportVersion = 0;
  String _lastDanmakuLayerLayoutTrace = '';
  Timer? _danmakuSeekCompletionTimer;
  int _danmakuSeekSerial = 0;

  static const Duration _asyncDanmakuSeekDelay = Duration(milliseconds: 350);

  bool get _isOfflinePlayback {
    return widget.initialVideoDetail?.source == 'local' ||
        widget.localPath != null;
  }

  // 播放器的 GlobalKey，用于保持播放器状态
  // final GlobalKey _playerKey = GlobalKey();

  // 💡 关键：为 VideoPlayerWidget 增加专门的全局 Key，确保其在层级移动时不会销毁重建
  final GlobalKey _videoPlayerWidgetKey = GlobalKey();

  int? get _currentDanmakuCommentCount {
    if (_currentDanmakuEpisodeId == null || _danmakuList.isEmpty) {
      return null;
    }
    return _danmakuList.length;
  }

  String _getLocalRecordId(int episodeIndex) {
    final ids = widget.localEpisodeIds;
    if (ids != null && episodeIndex >= 0 && episodeIndex < ids.length) {
      return ids[episodeIndex];
    }
    return currentID;
  }

  int _getLocalRecordEpisodeNumber(int episodeIndex) {
    final numbers = widget.localEpisodeNumbers;
    if (numbers != null &&
        episodeIndex >= 0 &&
        episodeIndex < numbers.length &&
        numbers[episodeIndex] > 0) {
      return numbers[episodeIndex];
    }
    return episodeIndex + 1;
  }

  int _getLocalEpisodeListIndexByNumber(int episodeNumber) {
    final numbers = widget.localEpisodeNumbers;
    if (numbers != null && numbers.isNotEmpty) {
      final mappedIndex = numbers.indexOf(episodeNumber);
      if (mappedIndex >= 0) {
        return mappedIndex;
      }
    }
    return episodeNumber - 1;
  }

  String? _getCurrentEpisodeTitleForDanmaku() {
    final titles = currentDetail?.episodesTitles;
    if (titles == null ||
        currentEpisodeIndex < 0 ||
        currentEpisodeIndex >= titles.length) {
      return null;
    }
    final text = titles[currentEpisodeIndex].trim();
    return text.isEmpty ? null : text;
  }

  int? _extractEpisodeNumberFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final patterns = <RegExp>[
      RegExp(r'[第EPep]\s*(\d{1,4})'),
      RegExp(r'(\d{1,4})\s*[集话期回]'),
      RegExp(r'S\d{1,2}\s*E(\d{1,4})', caseSensitive: false),
      RegExp(r'^\s*(\d{1,4})\s*$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) {
          return value;
        }
      }
    }
    return null;
  }

  int _getDanmakuMatchEpisodeIndex() {
    if (currentSource != 'local') {
      return currentEpisodeIndex;
    }

    final mappedByNumber = _getLocalRecordEpisodeNumber(currentEpisodeIndex);
    if (mappedByNumber > 0) {
      return mappedByNumber - 1;
    }

    final parsed =
        _extractEpisodeNumberFromText(_getCurrentEpisodeTitleForDanmaku());
    if (parsed != null && parsed > 0) {
      return parsed - 1;
    }

    return currentEpisodeIndex;
  }

  List<String> _buildDanmakuMatchFileNames() {
    final sourceName = currentDetail?.sourceName ?? currentSource;
    final episodeTitle = _getCurrentEpisodeTitleForDanmaku();
    final matchEpisodeIndex = _getDanmakuMatchEpisodeIndex();
    final candidates = <String>[];

    void addCandidate(String value) {
      if (!candidates.contains(value)) {
        candidates.add(value);
      }
    }

    addCandidate(DanmakuService.buildFileName(
      videoTitle,
      matchEpisodeIndex,
      sourceName,
    ));

    if (episodeTitle != null) {
      addCandidate(DanmakuService.buildFileName(
        '$videoTitle $episodeTitle',
        null,
        sourceName,
      ));

      final parsedEpisode = _extractEpisodeNumberFromText(episodeTitle);
      if (parsedEpisode != null && parsedEpisode > 0) {
        addCandidate(DanmakuService.buildFileName(
          videoTitle,
          parsedEpisode - 1,
          sourceName,
        ));
      }
    }

    return candidates;
  }

  @override
  void initState() {
    super.initState();

    // 强制清理之前的播放器页面，解决声音重叠和内存占用
    if (_instances.isNotEmpty) {
      final oldInstances = List<_PlayerScreenState>.from(_instances);
      _instances.clear();
      for (var instance in oldInstances) {
        instance._forceClose();
      }
    }
    _instances.add(this);

    videoTitle = widget.title;
    currentEpisodeIndex = widget.initialEpisodeIndex;
    // 这是我手动加的，暂时不知道有啥影响
    videoYear = widget.year ?? '';

    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _switchLoadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    // 添加应用生命周期监听器
    WidgetsBinding.instance.addObserver(this);
    // 加载弹幕设置
    _loadDanmakuSettings();
    // 加载跳过设置
    _loadSkipSettings();
    // 加载通用播放设置
    _loadPlayerGeneralSettings();
    _setKeepScreenOn(true);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosing) return;
      if (_playerRotationLocked) {
        final cachedTarget = PlayerRotationLockPolicy.resolveCachedLockTarget(
          currentLockedOrientations: _lockedPlayerOrientations,
          lastKnownInterfaceOrientation: _lastKnownPlayerInterfaceOrientation,
          lastAppliedOrientations: _lastAppliedFullscreenOrientations,
        );
        if (cachedTarget != null) {
          _lockedPlayerOrientations = cachedTarget;
          unawaited(SystemChrome.setPreferredOrientations(cachedTarget));
          _lastAppliedFullscreenOrientations = cachedTarget;
        } else {
          unawaited(_applyPlayerRotationLock(readCurrentOrientation: true));
        }
      } else if (Platform.isIOS) {
        unawaited(_refreshLastKnownPlayerInterfaceOrientation());
      }
      _refreshDanmakuOptionForPlayback(reason: 'metrics_changed');
    });
  }

  /// 加载通用播放设置
  Future<void> _loadPlayerGeneralSettings() async {
    final speed = await UserDataService.getLongPressSpeed();
    final fitIndex = await UserDataService.getVideoFitType();
    final progressIndex = await UserDataService.getProgressDisplayMode();
    final showSystemTime = await UserDataService.getShowSystemTime();
    final hideCenterControlsWithBars =
        await UserDataService.getHideCenterControlsWithBars();
    final adFilterEnabled = await UserDataService.getAdFilterEnabled();
    final mediaKitPreloadEnabled =
        await UserDataService.getMediaKitPreloadEnabled(
      defaultValue: Platform.isMacOS,
    );

    if (mounted) {
      setState(() {
        _longPressSpeed = speed;
        _currentFitType = VideoFitType
            .values[fitIndex.clamp(0, VideoFitType.values.length - 1)];
        _progressMode = ProgressDisplayMode.values[
            progressIndex.clamp(0, ProgressDisplayMode.values.length - 1)];
        _showSystemTime = showSystemTime;
        _hideCenterControlsWithBars = hideCenterControlsWithBars;
        _adFilterEnabled = adFilterEnabled;
        _mediaKitPreloadEnabled = mediaKitPreloadEnabled;
      });
    }
  }

  /// 加载跳过设置
  Future<void> _loadSkipSettings() async {
    // 1. 优先尝试加载针对当前视频标题和年份的特定设置
    final videoSettings =
        await UserDataService.getVideoSkipSettings(videoTitle, videoYear);

    int intro = 0;
    int outro = 0;

    if (videoSettings != null) {
      intro = videoSettings['intro']!;
      outro = videoSettings['outro']!;
      debugPrint('已加载视频特定跳过设置: $videoTitle ($videoYear) -> $intro/$outro');
    }

    if (mounted) {
      setState(() {
        _skipIntroDuration = intro;
        _skipOutroDuration = outro;
      });
    }
  }

  /// 加载弹幕设置
  Future<void> _loadDanmakuSettings() async {
    final settings = await DanmakuService().getSettings();
    if (mounted) {
      setState(() {
        _danmakuSettings = settings;
      });
    }
  }

  Future<void> _toggleDanmakuEnabled(bool enabled) async {
    if (_danmakuSettings.enabled == enabled) return;

    final newSettings = _danmakuSettings.copyWith(enabled: enabled);
    if (mounted) {
      setState(() {
        _danmakuSettings = newSettings;
      });
    } else {
      _danmakuSettings = newSettings;
    }

    await DanmakuService().saveSettings(newSettings);

    if (!enabled) {
      _runWithDanmakuController(
        'clear_toggle_disabled',
        (controller) => controller.clear(),
      );
      return;
    }

    _lastDanmakuCheckTime = -1;
    _resetDanmakuIndex(currentPosition ?? Duration.zero);
    _loadDanmaku();
  }

  static const double _portraitDanmakuFontMultiplier = 0.86;
  static const double _landscapeDanmakuFontMultiplier = 1.0;

  bool _isDanmakuPortraitViewport() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    if (view == null) return true;

    final size = view.physicalSize;
    if (size.isEmpty) return true;

    return size.height >= size.width;
  }

  DanmakuSettings _resolveRenderDanmakuSettings([DanmakuSettings? settings]) {
    final baseSettings = settings ?? _danmakuSettings;
    final orientationMultiplier = _isDanmakuPortraitViewport()
        ? _portraitDanmakuFontMultiplier
        : _landscapeDanmakuFontMultiplier;

    return baseSettings.copyWith(
      fontSize: baseSettings.fontSize * orientationMultiplier,
    );
  }

  Future<void> _applyDanmakuSettings(DanmakuSettings settings) async {
    if (mounted) {
      setState(() => _danmakuSettings = settings);
    } else {
      _danmakuSettings = settings;
    }

    await DanmakuService().saveSettings(settings);

    _refreshDanmakuOptionForPlayback(
        reason: 'settings_changed', settings: settings);
  }

  double _resolvePlaybackSpeedForDanmaku([double? speed]) {
    final raw = speed ?? _videoPlayerController?.playbackSpeed ?? 1.0;
    if (!raw.isFinite || raw <= 0) return 1.0;
    return raw;
  }

  DanmakuOption _buildDanmakuOption(
    DanmakuSettings settings, {
    double? playbackSpeed,
  }) {
    final speed = _resolvePlaybackSpeedForDanmaku(playbackSpeed);
    final duration = settings.syncVideoSpeed
        ? (settings.duration / speed)
        : settings.duration;
    return DanmakuOption(
      fontSize: settings.fontSize * settings.scale,
      opacity: settings.opacity,
      duration: duration,
      hideScroll: settings.hideScroll,
      hideTop: settings.hideTop,
      hideBottom: settings.hideBottom,
      lineHeight: settings.lineSpacing,
      fontWeight: (settings.fontWeight * 4).round().clamp(1, 9),
      massiveMode: !settings.preventOverlap,
    );
  }

  bool _isDisposedDanmakuControllerError(Object error) {
    final message = error.toString();
    return message.contains('used after being disposed') &&
        message.contains('ListValueNotifier');
  }

  void _detachDanmakuController({
    required String reason,
    DanmakuController? expected,
  }) {
    final controller = _danmakuController;
    if (controller == null) return;
    if (expected != null && !identical(controller, expected)) return;

    debugPrint(
        '[DanmakuLayer] controller_detached: reason=$reason, hash=${identityHashCode(controller)}, ep=$_currentDanmakuEpisodeId, list=${_danmakuList.length}');
    _danmakuController = null;
  }

  T? _runWithDanmakuController<T>(
    String reason,
    T Function(DanmakuController controller) action,
  ) {
    final controller = _danmakuController;
    if (_isClosing || controller == null) return null;

    try {
      return action(controller);
    } catch (error) {
      if (_isDisposedDanmakuControllerError(error)) {
        _detachDanmakuController(
            reason: '${reason}_disposed', expected: controller);
        return null;
      }
      rethrow;
    }
  }

  void _beginClosingDanmakuLifecycle(String reason) {
    _isClosing = true;
    _detachDanmakuController(reason: reason);
  }

  void _refreshDanmakuOptionForPlayback({
    required String reason,
    DanmakuSettings? settings,
    double? playbackSpeed,
  }) {
    final baseSettings = settings ?? _danmakuSettings;
    final effectiveSettings = _resolveRenderDanmakuSettings(baseSettings);
    if (_isClosing || !baseSettings.enabled || _danmakuController == null) {
      return;
    }

    final speed = _resolvePlaybackSpeedForDanmaku(playbackSpeed);
    final option =
        _buildDanmakuOption(effectiveSettings, playbackSpeed: playbackSpeed);
    _runWithDanmakuController(
      'update_option_$reason',
      (controller) => controller.updateOption(option),
    );

    if (baseSettings.syncVideoSpeed) {
      final duration = baseSettings.duration / speed;
      debugPrint(
          '弹幕速度已同步视频倍速: 原因=$reason, 视频倍速=${speed.toStringAsFixed(2)}x, 弹幕时长=${duration.toStringAsFixed(2)}s');
    }
  }

  void _onPlaybackSpeedChanged(double speed) {
    _refreshDanmakuOptionForPlayback(
      reason: 'playback_speed_changed',
      playbackSpeed: speed,
    );
  }

  Color _macOSTopBarColor(ThemeData theme) {
    if (!DeviceUtils.isMacOS()) {
      return Colors.black;
    }

    if (theme.brightness == Brightness.dark) {
      return theme.scaffoldBackgroundColor;
    }

    return const Color(0xFFe6f3fb);
  }

  /// 加载弹幕数据

  void _traceDanmakuLayerLayout(BoxConstraints constraints) {
    final baseHeight = constraints.maxHeight;
    final layerHeight = baseHeight * _danmakuSettings.displayArea;
    final trace =
        'w=${constraints.maxWidth.toStringAsFixed(2)},h=${baseHeight.toStringAsFixed(2)},layer=${layerHeight.toStringAsFixed(2)},ep=$_currentDanmakuEpisodeId,full=$_isFullscreen,web=$_isWebFullscreen';

    if (trace == _lastDanmakuLayerLayoutTrace) return;
    _lastDanmakuLayerLayoutTrace = trace;

    // debugPrint('[DanmakuLayer] layout: $trace');
  }

  void _syncDanmakuPlaybackState({
    required String reason,
    bool? forcePlaying,
  }) {
    if (_isClosing || !_danmakuSettings.enabled || _danmakuController == null) {
      return;
    }

    if (forcePlaying != null) {
      _hasExplicitDanmakuState = true;
      _danmakuShouldPlay = forcePlaying;
    }

    final playerPlaying = _videoPlayerController?.isPlaying;
    final shouldPlay = forcePlaying ??
        (_hasExplicitDanmakuState
            ? _danmakuShouldPlay
            : (playerPlaying ?? false));

    _danmakuShouldPlay = shouldPlay;

    if (shouldPlay) {
      _runWithDanmakuController(
        'resume_$reason',
        (controller) => controller.resume(),
      );
    } else {
      _runWithDanmakuController(
        'pause_$reason',
        (controller) => controller.pause(),
      );
    }

    final controllerHash = _danmakuController == null
        ? 'null'
        : identityHashCode(_danmakuController);
    debugPrint(
        '[DanmakuSync] reason=$reason, force=$forcePlaying, player=$playerPlaying, applied=$shouldPlay, controller=$controllerHash, list=${_danmakuList.length}, ep=$_currentDanmakuEpisodeId, full=$_isFullscreen, web=$_isWebFullscreen');
  }

  void _rebaseDanmakuCursorToCurrentPosition({
    required String reason,
    bool triggerNow = false,
  }) {
    if (_isClosing || !_danmakuSettings.enabled || _danmakuController == null) {
      return;
    }
    if (_danmakuList.isEmpty) return;

    final pos = _videoPlayerController?.currentPosition;
    if (pos == null) return;

    _lastDanmakuCheckTime = -1;
    _resetDanmakuIndex(pos);

    final controllerHash = _danmakuController == null
        ? 'null'
        : identityHashCode(_danmakuController);
    debugPrint(
        '[DanmakuSync] rebase: reason=$reason, position=${pos.inMilliseconds}ms, index=$_danmakuIndex, controller=$controllerHash, list=${_danmakuList.length}, ep=$_currentDanmakuEpisodeId, full=$_isFullscreen, web=$_isWebFullscreen');

    if (!triggerNow) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosing || _isSeeking) return;
      if (!_danmakuSettings.enabled || _danmakuController == null) return;
      _sendDanmakuByPosition(pos);
    });
  }

  void _handleDanmakuControllerCreated(DanmakuController controller) {
    if (_isClosing) {
      return;
    }

    final prevHash = _danmakuController == null
        ? 'null'
        : identityHashCode(_danmakuController);
    final nextHash = identityHashCode(controller);
    _danmakuController = controller;
    _danmakuControllerCreateCount++;

    debugPrint(
        '[DanmakuLayer] controller_created: count=$_danmakuControllerCreateCount, prev=$prevHash, next=$nextHash, ep=$_currentDanmakuEpisodeId, list=${_danmakuList.length}, full=$_isFullscreen, web=$_isWebFullscreen');

    // Avoid pause/resume during DanmakuScreen init build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosing) {
        debugPrint(
            '[DanmakuLayer] controller_postframe_skip: not_mounted, next=$nextHash');
        return;
      }
      if (!identical(_danmakuController, controller)) {
        debugPrint(
            '[DanmakuLayer] controller_postframe_skip: stale_controller, next=$nextHash, current=${identityHashCode(_danmakuController)}');
        return;
      }

      _refreshDanmakuOptionForPlayback(reason: 'controller_created');
      _rebaseDanmakuCursorToCurrentPosition(
          reason: 'controller_created', triggerNow: true);
      _syncDanmakuPlaybackState(reason: 'controller_created');
    });
  }

  Future<void> _loadDanmaku() async {
    if (!_danmakuSettings.enabled) return;

    final baseApi = await DanmakuService().getBaseApi();
    if (baseApi == null || baseApi.isEmpty) return;

    setState(() => _isDanmakuLoading = true);

    try {
      int? episodeId;

      final danmakuMatchEpisodeIndex = _getDanmakuMatchEpisodeIndex();

      // 1. 优先尝试获取手动匹配的 ID
      if (currentSource.isNotEmpty && currentID.isNotEmpty) {
        episodeId = await DanmakuService().getManualMatch(
          currentSource,
          currentID,
          danmakuMatchEpisodeIndex,
        );
      }

      // 2. 如果没有手动匹配，则进行自动匹配
      if (episodeId == null) {
        final fileNames = _buildDanmakuMatchFileNames();
        for (final fileName in fileNames) {
          final matchResult = await DanmakuService().matchDanmaku(fileName);
          if (matchResult != null &&
              matchResult.isMatched &&
              matchResult.matches.isNotEmpty) {
            episodeId = matchResult.matches.first.episodeId;
            break;
          }
        }
      }

      if (episodeId == null) {
        debugPrint('弹幕匹配失败或无匹配结果');
        if (mounted && _danmakuSettings.enabled) {
          // _showToast('自动匹配弹幕失败，可尝试手动匹配');
        }
        setState(() => _isDanmakuLoading = false);
        return;
      }

      // 如果是同一个 episodeId，不重复加载
      if (_currentDanmakuEpisodeId == episodeId && _danmakuList.isNotEmpty) {
        setState(() => _isDanmakuLoading = false);
        return;
      }

      // 获取弹幕列表
      final comments = await DanmakuService().getDanmakuList(episodeId);

      if (mounted) {
        setState(() {
          _danmakuList = comments;
          _currentDanmakuEpisodeId = episodeId;
          _isDanmakuLoading = false;

          // 根据当前位置或待跳转位置初始化索引，防止从0秒开始喷发弹幕
          final pos = _resumeStartAt ?? currentPosition ?? Duration.zero;
          _resetDanmakuIndex(pos);
        });
        if (comments.isEmpty && _danmakuSettings.enabled) {
          // _showToast('匹配成功，但该剧集暂无弹幕');
        }
        debugPrint('弹幕加载成功: ${comments.length} 条');
      }
    } catch (e) {
      debugPrint('弹幕加载失败: $e');
      if (mounted) {
        setState(() => _isDanmakuLoading = false);
      }
    }
  }

  double _lastDanmakuCheckTime = -1;

  /// 根据播放进度发送弹幕
  void _sendDanmakuByPosition(Duration position) {
    if (_isClosing ||
        _danmakuController == null ||
        _danmakuList.isEmpty ||
        !_danmakuSettings.enabled ||
        _isSeeking) {
      return;
    }

    final currentTime = position.inMilliseconds / 1000.0;

    // 节流：每 150ms 检查一次逻辑，极大减少循环次数
    if ((currentTime - _lastDanmakuCheckTime).abs() < 0.15) return;
    _lastDanmakuCheckTime = currentTime;

    // 发送当前时间点之前的所有未发送弹幕
    while (_danmakuIndex < _danmakuList.length) {
      final comment = _danmakuList[_danmakuIndex];
      if (comment.time <= currentTime) {
        // 如果开启了彩色屏蔽且弹幕不是白色/浅色，则跳过
        if (_danmakuSettings.hideColor && comment.color != 16777215) {
          _danmakuIndex++;
          continue;
        }

        _runWithDanmakuController(
          'add_danmaku',
          (controller) => controller.addDanmaku(
            DanmakuService.convertToDanmakuItem(comment),
          ),
        );
        _danmakuIndex++;
      } else {
        break;
      }
    }
  }

  void _updateDanmakuIndex(Duration position) {
    if (_danmakuList.isEmpty) return;

    _danmakuIndex = findDanmakuSeekIndex(_danmakuList, position);
  }

  /// 重置弹幕索引（用于 seek 操作）
  void _resetDanmakuIndex(Duration position, {bool clearVisible = true}) {
    _updateDanmakuIndex(position);
    if (!clearVisible) return;

    // 清空当前显示的弹幕
    _runWithDanmakuController(
      'clear_reset_index',
      (controller) => controller.clear(),
    );
  }

  /// 设置竖屏方向
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<MobileInterfaceOrientation> _readCurrentInterfaceOrientation() async {
    final orientation =
        await const MobileOrientationService().getCurrentInterfaceOrientation();
    if (orientation != MobileInterfaceOrientation.unknown) {
      _lastKnownPlayerInterfaceOrientation = orientation;
    }
    return orientation;
  }

  Future<void> _refreshLastKnownPlayerInterfaceOrientation() async {
    if (DeviceUtils.isPC() || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }
    await _readCurrentInterfaceOrientation();
  }

  Future<void> _applyPlayerRotationLock({
    bool readCurrentOrientation = false,
    bool preferCurrentObservedOrientation = false,
  }) async {
    if (DeviceUtils.isPC() || !_playerRotationLocked) return;

    MobileInterfaceOrientation observed = MobileInterfaceOrientation.unknown;
    if (readCurrentOrientation) {
      observed = await _readCurrentInterfaceOrientation();
      if (preferCurrentObservedOrientation) {
        final targetOrientations =
            PlayerRotationLockPolicy.resolveInitialLockTarget(
          observedInterfaceOrientation: observed,
          lastKnownInterfaceOrientation: _lastKnownPlayerInterfaceOrientation,
          lastAppliedOrientations: _lastAppliedFullscreenOrientations,
        );
        if (targetOrientations != null) {
          _lockedPlayerOrientations = targetOrientations;
          await SystemChrome.setPreferredOrientations(targetOrientations);
          _lastAppliedFullscreenOrientations = targetOrientations;
          return;
        }
      }
    }

    final cachedTarget = PlayerRotationLockPolicy.resolveCachedLockTarget(
      currentLockedOrientations: _lockedPlayerOrientations,
      lastKnownInterfaceOrientation: _lastKnownPlayerInterfaceOrientation,
      lastAppliedOrientations: _lastAppliedFullscreenOrientations,
    );
    if (cachedTarget != null) {
      if (!listEquals(_lockedPlayerOrientations, cachedTarget)) {
        _lockedPlayerOrientations = cachedTarget;
      }
      await SystemChrome.setPreferredOrientations(cachedTarget);
      _lastAppliedFullscreenOrientations = cachedTarget;
      return;
    }

    if (!readCurrentOrientation) return;

    final targetOrientations = PlayerRotationLockPolicy.resolve(
      isLocked: true,
      observedInterfaceOrientation: observed,
      lastKnownInterfaceOrientation: _lastKnownPlayerInterfaceOrientation,
    );
    if (targetOrientations == null) return;

    _lockedPlayerOrientations = targetOrientations;
    await SystemChrome.setPreferredOrientations(targetOrientations);
    _lastAppliedFullscreenOrientations = targetOrientations;
  }

  Future<void> _restoreUnlockedPlayerOrientations() async {
    if (DeviceUtils.isPC()) return;

    _lockedPlayerOrientations = null;

    if (_isFullscreen && !_isEnteringLandscapeFullscreen) {
      if (_isShortDrama) {
        const targetOrientations = [DeviceOrientation.portraitUp];
        await SystemChrome.setPreferredOrientations(targetOrientations);
        _lastAppliedFullscreenOrientations = targetOrientations;
        return;
      }

      final targetOrientations =
          await _fullscreenOrientationController.resolveAfterFullscreenEntry(
        platform: defaultTargetPlatform,
        isShortDramaPortraitFlow: _isShortDrama,
        lastAppliedOrientations: _lastAppliedFullscreenOrientations,
      );
      if (targetOrientations != null) {
        await SystemChrome.setPreferredOrientations(targetOrientations);
        _lastAppliedFullscreenOrientations = targetOrientations;
      }
      return;
    }

    if (_isTablet) {
      _restoreOrientation();
    } else {
      _setPortraitOrientation();
    }
  }

  Future<void> _handlePlayerLockChanged(bool isLocked) async {
    if (_playerRotationLocked == isLocked) return;

    if (mounted) {
      setState(() {
        _playerRotationLocked = isLocked;
      });
    }

    if (isLocked) {
      _lockedPlayerOrientations = null;
      await _applyPlayerRotationLock(
        readCurrentOrientation: true,
        preferCurrentObservedOrientation: true,
      );
    } else {
      _lockedPlayerOrientations = null;
      await _restoreUnlockedPlayerOrientations();
    }
  }

  /// 恢复所有方向
  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void initParam({bool? isInit}) {
    // 如果继续观看里的节点，失效了，需要重新获取数据。
    if (isInit == true) {
      currentSource = '';
      currentID = '';
    } else {
      currentSource = widget.source ?? '';
      currentID = widget.id ?? '';
    }
    videoTitle = widget.title;
    videoYear = widget.year ?? '';
    needPrefer = widget.prefer != null && widget.prefer == 'true';
    searchTitle = widget.stitle ?? '';

    print('=== PlayerScreen 初始化参数 ===');
    print('currentSource: $currentSource');
    print('currentID: $currentID');
    print('videoTitle: $videoTitle');
    print('videoYear: $videoYear');
    print('needPrefer: $needPrefer');
    print('stitle: ${widget.stitle}');
    print('stype: ${widget.stype}');
    print('prefer: ${widget.prefer}');
  }

  void initVideoData({bool? isInit}) async {
    // 初始化参数
    initParam(isInit: isInit);
    _sourceSpeedHydrationSerial++;
    allSourcesSpeed.clear();

    // 💡 优化：如果是换源、选集或离线播放（已有明确目标），则不显示大加载搜源页，直接进入播放逻辑
    // if (currentSource.isNotEmpty && currentID.isNotEmpty || widget.localPath != null) {
    //   if (mounted) {
    //     setState(() {
    //       _isLoading = false;
    //     });
    //   }
    // }

    // 统一获取播放记录（离线在线都需要）
    int playEpisodeIndex = widget.initialEpisodeIndex;
    int playTime = 0;
    if (_isOfflinePlayback && widget.initialVideoDetail != null) {
      final localDetail = widget.initialVideoDetail!;
      currentSource = localDetail.source;
      currentID = localDetail.id;

      final localPlayRecords = await LocalModeStorageService.getPlayRecords();
      PlayRecord? matchedRecord;
      final targetRecordId = _getLocalRecordId(widget.initialEpisodeIndex);
      final targetEpisodeNumber =
          _getLocalRecordEpisodeNumber(widget.initialEpisodeIndex);
      for (final record in localPlayRecords) {
        if (record.id == targetRecordId && record.source == currentSource) {
          matchedRecord = record;
          break;
        }
      }

      if (matchedRecord == null) {
        for (final record in localPlayRecords) {
          if (record.source == currentSource &&
              record.title == localDetail.title &&
              record.index == targetEpisodeNumber) {
            matchedRecord = record;
            break;
          }
        }
      }

      if (matchedRecord != null) {
        if (widget.initialEpisodeIndex == 0) {
          final resumeIndex =
              _getLocalEpisodeListIndexByNumber(matchedRecord.index);
          if (resumeIndex >= 0 && resumeIndex < localDetail.episodes.length) {
            playEpisodeIndex = resumeIndex;
          }
        }
        playTime = matchedRecord.playTime;
      }
    } else if (mounted) {
      final allPlayRecords = await PageCacheService().getPlayRecords(context);
      if (allPlayRecords.success && allPlayRecords.data != null) {
        final matchingRecords = allPlayRecords.data!.where((record) =>
            record.id == currentID && record.source == currentSource);
        if (matchingRecords.isNotEmpty) {
          // 如果没有通过 widget 强制指定集数，则使用历史进度
          if (widget.initialEpisodeIndex == 0) {
            playEpisodeIndex = matchingRecords.first.index - 1;
          }
          playTime = matchingRecords.first.playTime;
        }
      }
    }

    // 如果是离线播放模式
    if (_isOfflinePlayback && widget.initialVideoDetail != null) {
      updateLoadingMessage('正在加载本地缓存...');
      updateLoadingProgress(0.9);

      currentDetail = widget.initialVideoDetail;
      allSources = [currentDetail!];

      setInfosByDetail(currentDetail!);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 直接播放
      startPlay(playEpisodeIndex, playTime);
      return;
    }

    if (widget.source == null &&
        widget.id == null &&
        widget.title.isEmpty &&
        widget.stitle == null) {
      showError('缺少必要参数');
      return;
    }

    if (widget.source == null &&
        widget.id == null &&
        widget.title.isEmpty &&
        widget.stitle == null) {
      showError('缺少必要参数');
      return;
    }

    final preferSpeedTest = await UserDataService.getPreferSpeedTest();
    final resumePreferredSource = currentSource;
    final resumePreferredId = currentID;
    final shouldTryResumeSourceFirst = widget.prefer == 'continue';
    final shouldWaitForResumeTarget = shouldTryResumeSourceFirst &&
        resumePreferredSource.isNotEmpty &&
        resumePreferredId.isNotEmpty;
    final allowEnterPlayerBeforeSearchComplete =
        !preferSpeedTest && !shouldWaitForResumeTarget;
    final searchKeyword = (searchTitle.isNotEmpty) ? searchTitle : videoTitle;
    final initFlowStart = DateTime.now();
    var hasStartedPlayback = false;
    var matchedResumeTargetInIncremental = false;
    debugPrint(
        '[续播恢复] 初始化开始: 标题=$videoTitle, 关键词=$searchKeyword, 继续观看入口=$shouldTryResumeSourceFirst, 等待历史源=$shouldWaitForResumeTarget, 历史源=${resumePreferredSource.isEmpty ? '无' : '$resumePreferredSource+$resumePreferredId'}, 初始集=${playEpisodeIndex + 1}, 初始进度=${playTime}s, 优选测速=$preferSpeedTest, 强制优选=$needPrefer');

    // 1. 启动全网搜源任务
    // 继续观看入口：禁用 early return，保证换源列表最终完整，并在增量结果命中历史源后立即起播。
    if (!shouldTryResumeSourceFirst) {
      debugPrint('[续播恢复] 非继续观看入口，直接全网搜源');
    }
    updateLoadingMessage('正在为您搜索最佳播放源...');
    updateLoadingProgress(0.3);
    var hasPrimedDetail = false;
    final searchStart = DateTime.now();
    debugPrint(
        '[续播恢复] 开始全网搜源: 关键词=$searchKeyword, allowEarlyReturn=${shouldWaitForResumeTarget ? false : !preferSpeedTest}');

    final searchJob = fetchSourcesData(
      searchKeyword,
      onIncrementalResults: (newResults) {
        if (mounted) {
          setState(() => allSources = newResults);
        } else {
          allSources = newResults;
        }

        // 继续观看入口：仅在命中历史源后才开始播放。
        if (shouldWaitForResumeTarget &&
            !matchedResumeTargetInIncremental &&
            resumePreferredSource.isNotEmpty &&
            resumePreferredId.isNotEmpty) {
          final target = newResults.where((source) =>
              source.source == resumePreferredSource &&
              source.id == resumePreferredId);
          if (target.isNotEmpty) {
            matchedResumeTargetInIncremental = true;
            currentDetail = target.first;
            setInfosByDetail(currentDetail!);
            debugPrint(
                '[续播恢复] 增量结果命中历史源，立即起播: source=${currentDetail!.source}, id=${currentDetail!.id}, 源名=${currentDetail!.sourceName}, 当前候选数=${newResults.length}');

            if (mounted && _isLoading) {
              _showVideoStartupLoadingOverlay();
            }
            _checkFavoriteStatus();
            startPlay(playEpisodeIndex, playTime);
            hasStartedPlayback = true;
          }
        }

        // 仅在“未开启优选测速”且“不需要等待历史源”时，允许提前进入播放页。
        if (!hasPrimedDetail &&
            newResults.isNotEmpty &&
            allowEnterPlayerBeforeSearchComplete) {
          hasPrimedDetail = true;
          currentDetail = newResults.first;
          setInfosByDetail(currentDetail!);
          debugPrint(
              '[续播恢复] 增量首个候选源: source=${currentDetail!.source}, id=${currentDetail!.id}, 源名=${currentDetail!.sourceName}, 当前候选数=${newResults.length}');

          if (mounted && _isLoading) {
            _showVideoStartupLoadingOverlay();
          }
        }
      },
      allowEarlyReturn: shouldWaitForResumeTarget ? false : !preferSpeedTest,
    );

    // 2. 💡 强制等待 2 秒搜源窗口，确保获取足够多的候选源
    await Future.any([
      searchJob,
      Future.delayed(const Duration(seconds: 4)),
    ]);

    // 获取当前已搜到的所有结果
    allSources = await searchJob;
    final searchCostMs = DateTime.now().difference(searchStart).inMilliseconds;
    debugPrint('[续播恢复] 全网搜源完成: 结果数=${allSources.length}, 耗时=${searchCostMs}ms');

    if (allSources.isEmpty) {
      debugPrint('[续播恢复] 未找到任何候选源，终止播放初始化');
      showError('未找到匹配结果');
      return;
    }

    // 3. 💡 核心筛选逻辑
    // 优先尝试匹配继续观看的特定源
    var matchedResumeTarget = false;
    if (resumePreferredSource.isNotEmpty && resumePreferredId.isNotEmpty) {
      final target = allSources.where((source) =>
          source.source == resumePreferredSource &&
          source.id == resumePreferredId);
      if (target.isNotEmpty) {
        matchedResumeTarget = true;
        currentDetail = target.first;
        debugPrint(
            '[续播恢复] 在全网结果中匹配到历史源: source=${currentDetail!.source}, id=${currentDetail!.id}, 源名=${currentDetail!.sourceName}');
      } else {
        debugPrint(
            '[续播恢复] 全网结果未匹配到历史源: source=$resumePreferredSource, id=$resumePreferredId');
      }
    }

    // 4. 💡 兜底与优选逻辑
    // 如果没有找到历史源，或者当前是直接搜索进入，或者需要强制优选
    if (currentDetail == null || needPrefer || !matchedResumeTarget) {
      if (preferSpeedTest) {
        updateLoadingMessage('正在优选最佳播放源...');
        updateLoadingProgress(0.66);
        updateLoadingEmoji('⚡');
        currentDetail = await preferBestSource();
        debugPrint(
            '[续播恢复] 优选测速已启用，采用优选源: source=${currentDetail!.source}, id=${currentDetail!.id}, 源名=${currentDetail!.sourceName}');
      } else {
        // 如果没开启优选，默认选第一个
        currentDetail = allSources.first;
        debugPrint(
            '[续播恢复] 优选测速未启用，采用首个候选源: source=${currentDetail!.source}, id=${currentDetail!.id}, 源名=${currentDetail!.sourceName}');
      }
    }

    setInfosByDetail(currentDetail!);

    // 💡 优化：设置完详情后，立即关闭全局加载状态，避免闪烁
    if (mounted) {
      if (!hasStartedPlayback) {
        _showVideoStartupLoadingOverlay();
      } else {
        setState(() {
          if (_isEnteringLandscapeFullscreen) {
            _isLoading = true;
            _showSwitchLoadingOverlay = false;
            _loadingMessage = '视频加载中...';
          } else {
            _isLoading = false;
            _showSwitchLoadingOverlay = false;
          }
        });
      }
    }

    // 检查收藏状态
    _checkFavoriteStatus();

    // 设置进度为 100%
    updateLoadingProgress(1.0);
    updateLoadingMessage('准备就绪，即将开始播放...');
    updateLoadingEmoji('✨');

    // 设置播放
    final totalCostMs = DateTime.now().difference(initFlowStart).inMilliseconds;
    debugPrint(
        '[续播恢复] 初始化完成(全网路径): 最终源=${currentDetail!.source}+${currentDetail!.id}, 集=${playEpisodeIndex + 1}, 时间=${playTime}s, 总耗时=${totalCostMs}ms');
    if (!hasStartedPlayback) {
      startPlay(playEpisodeIndex, playTime);
    }

    // 开启优选测速时：进入播放后后台补全全量源测速结果，用于换源卡片完整展示。
    if (preferSpeedTest) {
      _startBackgroundSourceSpeedHydration();
    }
  }

  void startPlay(int targetIndex, int playTime) {
    if (targetIndex >= currentDetail!.episodes.length) {
      targetIndex = 0;
      return;
    }
    if (mounted) {
      setState(() {
        currentEpisodeIndex = targetIndex;
      });
    }
    // 重置上次保存的位置，因为切换了集数
    _lastSavePosition = null;
    // 将 playTime 转换为 Duration 并传递给 updateVideoUrl
    final startAt = playTime > 0 ? Duration(seconds: playTime) : null;
    _resumeStartAt = startAt;
    final episodeUrl = currentDetail!.episodes[targetIndex];
    updateVideoUrl(episodeUrl, startAt: null);
    _scrollToCurrentEpisode();
  }

  void setInfosByDetail(SearchResult detail) {
    videoTitle = detail.title;
    videoDesc = detail.desc ?? '';
    videoYear = detail.year;
    videoCover = detail.poster;
    currentSource = detail.source;
    currentID = detail.id;
    totalEpisodes = detail.episodes.length;

    // 保存旧的豆瓣ID用于比较
    int oldVideoDoubanID = videoDoubanID;

    // 设置当前豆瓣 ID
    if (detail.doubanId != null && detail.doubanId! > 0) {
      // 如果当前 searchResult 有有效的 doubanID，直接使用
      videoDoubanID = detail.doubanId!;
    } else {
      // 否则统计出现次数最多的 doubanID
      Map<int, int> doubanIDCount = {};
      for (var result in allSources) {
        int? tmpDoubanID = result.doubanId;
        if (tmpDoubanID == null || tmpDoubanID == 0) {
          continue;
        }
        doubanIDCount[tmpDoubanID] = (doubanIDCount[tmpDoubanID] ?? 0) + 1;
      }
      videoDoubanID = doubanIDCount.entries.isEmpty
          ? 0
          : doubanIDCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
    }

    // 如果豆瓣ID发生变化且有效，获取豆瓣详情
    if (videoDoubanID != oldVideoDoubanID && videoDoubanID > 0) {
      _fetchDoubanDetails();
    }

    // 延迟调用自动滚动，确保UI已更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentEpisode();
      _scrollToCurrentSource();
    });
  }

  /// 获取豆瓣详情数据
  Future<void> _fetchDoubanDetails() async {
    if (videoDoubanID <= 0) {
      doubanDetails = null;
      return;
    }

    // 💡 优化：如果已经成功加载过豆瓣详情（包含推荐），则不再重复加载
    // 这保证了在换源和切集时，相关推荐区域保持稳定，不闪烁
    if (doubanDetails != null && doubanDetails!.recommends.isNotEmpty) {
      debugPrint('豆瓣详情已存在，跳过重复加载');
      return;
    }

    try {
      final response = await DoubanService.getDoubanDetails(
        context,
        doubanId: videoDoubanID.toString(),
      );

      if (response.success && response.data != null && mounted) {
        setState(() {
          doubanDetails = response.data;
          // 如果当前视频描述为空或是"暂无简介"，使用豆瓣的描述
          if ((videoDesc.isEmpty || videoDesc == '暂无简介') &&
              response.data!.summary != null &&
              response.data!.summary!.isNotEmpty) {
            videoDesc = response.data!.summary!;
          }
        });
      } else {
        print('获取豆瓣详情失败: ${response.message}');
      }
    } catch (e) {
      print('获取豆瓣详情异常: $e');
    }
  }

  Future<SearchResult> preferBestSource() async {
    final m3u8Service = M3U8Service();
    final result = await m3u8Service.preferBestSource(allSources);

    // 更新测速结果
    final speedResults = result['allSourcesSpeed'] as Map<String, dynamic>;
    for (final entry in speedResults.entries) {
      final speedData = entry.value as Map<String, dynamic>;
      allSourcesSpeed[entry.key] = SourceSpeed(
        quality: speedData['quality'] as String,
        loadSpeed: speedData['loadSpeed'] as String,
        pingTime: speedData['pingTime'] as String,
      );
    }

    return result['bestSource'] as SearchResult;
  }

  void _startBackgroundSourceSpeedHydration() {
    if (allSources.isEmpty) return;
    final serial = ++_sourceSpeedHydrationSerial;
    final sourcesSnapshot = List<SearchResult>.from(allSources);
    debugPrint(
        '[续播恢复] 开始后台补全全量测速: 源数量=${sourcesSnapshot.length}, serial=$serial');
    unawaited(_hydrateSourceSpeeds(serial, sourcesSnapshot));
  }

  Future<void> _hydrateSourceSpeeds(
      int serial, List<SearchResult> sources) async {
    final m3u8Service = M3U8Service();
    try {
      await m3u8Service.testSourcesWithCallback(
        sources,
        (String sourceId, Map<String, dynamic> speedData) {
          if (serial != _sourceSpeedHydrationSerial) return;
          final parsed = SourceSpeed(
            quality: speedData['quality'] as String,
            loadSpeed: speedData['loadSpeed'] as String,
            pingTime: speedData['pingTime'] as String,
          );
          if (mounted) {
            setState(() {
              allSourcesSpeed[sourceId] = parsed;
            });
          } else {
            allSourcesSpeed[sourceId] = parsed;
          }
        },
        timeout: const Duration(seconds: 10),
      );
      if (serial != _sourceSpeedHydrationSerial) return;
      debugPrint(
          '[续播恢复] 后台全量测速完成: 结果数=${allSourcesSpeed.length}, serial=$serial');
    } catch (e) {
      debugPrint('[续播恢复] 后台全量测速失败: $e, serial=$serial');
    }
  }

  // 处理返回按钮点击
  void _onBackPressed() async {
    // 1. 立即标记关闭并断开弹幕 controller，避免回退动画期间继续访问已释放的 notifier
    _beginClosingDanmakuLifecycle('back_pressed');
    // 2. 停止播放，提升视觉响应速度，减少声音残留感
    _videoPlayerController?.pause();
    setState(() {
      _isClosing = true;
    });

    // 如果正在投屏，停止投屏
    if (_isCasting && _dlnaDevice != null) {
      try {
        // 显示弹窗让用户选择
        final shouldStop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('停止投屏'),
            content: const Text('DLNA 设备可继续保持播放，是否需要停止？\n\n（保持播放时无法同步进度和播放记录）'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('保持'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('停止'),
              ),
            ],
          ),
        );

        // 如果用户选择停止，才调用 stop
        if (shouldStop == true) {
          try {
            _dlnaDevice.stop();
            debugPrint('用户选择停止投屏');
          } catch (e) {
            debugPrint('停止投屏失败: $e');
          }
        } else {
          debugPrint('用户选择保持播放');
        }
      } catch (e) {
        debugPrint('停止投屏失败: $e');
      }
    }

    // 关闭页面前保存进度
    _saveProgress(force: true, scene: '返回按钮');
    Navigator.of(context).pop();
  }

  void _onSystemGesturePop() {
    _beginClosingDanmakuLifecycle('system_gesture_pop');
    _videoPlayerController?.pause();
  }

  // 退出网页全屏
  void _exitWebFullscreen() {
    if (!DeviceUtils.isPC()) {
      return;
    }
    // 通知播放器控件退出网页全屏
    // 播放器控件会通过 onWebFullscreenChanged 回调来更新 _isWebFullscreen 状态
    if (_videoPlayerController != null) {
      _videoPlayerController!.exitWebFullscreen();
    }
  }

  /// 保存播放进度（同步函数，提前获取参数避免异步问题）
  void _saveProgress({bool force = false, required String scene}) {
    try {
      if (currentDetail == null) return;

      // 获取当前播放位置和总时长
      Duration? currentPosition;
      Duration? duration;

      if (_isCasting) {
        // 投屏状态：从 DLNA 播放器获取
        currentPosition = _dlnaCurrentPosition;
        duration = _dlnaCurrentDuration;
      } else {
        // 本地播放：根据设备类型从对应播放器获取
        if (_videoPlayerController == null) return;
        currentPosition = _videoPlayerController!.currentPosition;
        duration = _videoPlayerController!.duration;
      }

      if (currentPosition == null || duration == null) return;

      // 如果播放进度小于 1 s，则不保存
      if (currentPosition.inSeconds < 1) {
        return;
      }

      final playTime = currentPosition.inSeconds;
      final totalTime = duration.inSeconds;
      // 如果不是强制保存，检查时间间隔和进度变化
      if (!force) {
        final now = DateTime.now();
        // 检查时间间隔
        if (_lastSaveTime != null &&
            now.difference(_lastSaveTime!) < _saveProgressInterval) {
          return; // 时间间隔不够，跳过保存
        }
        // 检查进度是否发生变化（允许1秒的误差）
        if (_lastSavePosition != null && playTime == _lastSavePosition!) {
          return; // 进度没有明显变化，跳过保存
        }
      }

      // 更新最后保存时间和位置
      _lastSaveTime = DateTime.now();
      _lastSavePosition = playTime;

      // 提前获取所有需要的参数，避免异步执行时参数被改变
      final currentIDSnapshot = currentID;
      final currentSourceSnapshot = currentSource;
      final videoTitleSnapshot = videoTitle;
      final videoYearSnapshot = videoYear;
      final videoCoverSnapshot = videoCover;
      final currentEpisodeIndexSnapshot = currentEpisodeIndex;
      final totalEpisodesSnapshot = totalEpisodes;
      final searchTitleSnapshot = searchTitle;
      final sourceNameSnapshot = currentDetail?.sourceName ?? currentSource;
      final recordIDSnapshot = _isOfflinePlayback
          ? _getLocalRecordId(currentEpisodeIndexSnapshot)
          : currentIDSnapshot;
      final recordEpisodeNumber = _isOfflinePlayback
          ? _getLocalRecordEpisodeNumber(currentEpisodeIndexSnapshot)
          : currentEpisodeIndexSnapshot + 1;

      // 创建播放记录对象
      final playRecord = PlayRecord(
        id: recordIDSnapshot,
        source: currentSourceSnapshot,
        title: videoTitleSnapshot,
        sourceName: sourceNameSnapshot,
        year: videoYearSnapshot,
        cover: videoCoverSnapshot,
        index: recordEpisodeNumber,
        totalEpisodes: totalEpisodesSnapshot,
        playTime: playTime,
        totalTime: totalTime,
        saveTime: DateTime.now().millisecondsSinceEpoch, // 当前时间戳（毫秒）
        searchTitle: searchTitleSnapshot,
      );

      // 如果是本地播放：只保存到本地，不上传云端
      if (_isOfflinePlayback) {
        LocalModeStorageService.savePlayRecord(playRecord).then((_) {
          debugPrint(
              '保存本地播放进度 [场景: $scene]: source: $currentSourceSnapshot, id: $recordIDSnapshot, 第$recordEpisodeNumber集, 时间: ${playTime}秒');
        }).catchError((e) {
          debugPrint('保存本地播放进度失败 [场景: $scene]: $e');
        });
      } else {
        // 正常保存（根据模式决定是否上传）
        PageCacheService().savePlayRecord(playRecord, context).then((_) {
          debugPrint(
              '保存播放进度 [场景: $scene]: source: $currentSourceSnapshot, id: $currentIDSnapshot, 第${currentEpisodeIndexSnapshot + 1}集, 时间: ${playTime}秒');
        }).catchError((e) {
          debugPrint('保存播放进度失败 [场景: $scene]: $e');
        });
      }
    } catch (e) {
      debugPrint('保存播放进度失败: $e');
    }
  }

  /// 检查并保存进度（基于时间间隔）
  void _checkAndSaveProgress() {
    _saveProgress(scene: '定时保存');
  }

  Future<void> _setKeepScreenOn(bool enabled) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('设置常亮失败: $e');
    }
  }

  /// 应用生命周期状态变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _setKeepScreenOn(false);
        if (DeviceUtils.isPC()) {
          break;
        }
        // 应用进入后台前保存进度
        _saveProgress(force: true, scene: '应用进入后台');
        break;
      case AppLifecycleState.resumed:
        _setKeepScreenOn(true);
        if (DeviceUtils.isPC()) {
          break;
        }
        _lastSaveTime = null;
        _lastSavePosition = null;
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// 显示错误信息
  void showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _showError = true;
        _isLoading = false;
      });
    }
  }

  /// 隐藏错误信息
  void hideError() {
    if (mounted) {
      setState(() {
        _showError = false;
        _errorMessage = null;
      });
    }
  }

  void updateLoadingMessage(String message) {
    if (mounted) {
      setState(() {
        _loadingMessage = message;
      });
    }
  }

  /// 更新加载进度
  void updateLoadingProgress(double progress) {
    if (mounted) {
      setState(() {
        _loadingProgress = progress.clamp(0.0, 1.0);
      });
    }
  }

  /// 更新加载 emoji
  void updateLoadingEmoji(String emoji) {
    if (mounted) {
      setState(() {
        _loadingEmoji = emoji;
      });
    }
  }

  void _showVideoStartupLoadingOverlay() {
    if (!mounted) return;

    setState(() {
      _loadingMessage = '视频加载中...';
      _loadingProgress = _loadingProgress < 0.85 ? 0.85 : _loadingProgress;
      _loadingEmoji = '🎬';

      if (_isEnteringLandscapeFullscreen) {
        _isLoading = true;
        _showSwitchLoadingOverlay = false;
      } else {
        _isLoading = false;
        _showSwitchLoadingOverlay = true;
        _switchLoadingMessage = '视频加载中...';
      }
    });
  }

  Future<VideoPlayerWidgetController?> _waitForVideoPlayerController({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted &&
        _videoPlayerController == null &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 16));
    }
    return _videoPlayerController;
  }

  String _formatPlaybackError(Object error) {
    if (error is TimeoutException) {
      return '播放器加载超时';
    }

    var message = error.toString().trim();
    message = message.replaceFirst(RegExp(r'^[A-Za-z_<>]+:?\s*'), '');
    message = message.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (message.isEmpty) {
      message = '未知异常';
    }

    const maxLength = 72;
    if (message.length > maxLength) {
      message = '${message.substring(0, maxLength)}...';
    }
    return message;
  }

  /// 动态更新视频数据源
  Future<void> updateVideoUrl(String newUrl, {Duration? startAt}) async {
    debugPrint("updateVideoUrl start: $newUrl, startAt: $startAt");

    // 取消之前的计时器
    _loadingTimeoutTimer?.cancel();

    // 设置一个新的超时计时器，如果 20 秒后还没 Ready，强制关闭
    _loadingTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && (_showSwitchLoadingOverlay || _isLoading)) {
        debugPrint("播放器准备超时，强制关闭加载蒙版");
        setState(() {
          _showSwitchLoadingOverlay = false;
          _isLoading = false;
        });
        _showToast('加载超时，请尝试换源或重新播放');
      }
    });

    try {
      String finalUrl = newUrl;
      final bool isLocal = !newUrl.startsWith('http');
      if (_isOfflinePlayback && isLocal) {
        final optimizedPath =
            await DownloadService().resolveOptimizedLocalPlaybackPath(newUrl);
        if (optimizedPath != newUrl) {
          debugPrint("本地缓存已切换到更适合 seek 的文件: $optimizedPath");
        }
        finalUrl = optimizedPath;
      }
      // 1. 如果是网络请求，才执行去广告和代理逻辑
      if (!isLocal) {
        // 获取 M3U8 代理 URL (如果没被 Data URI 替换)
        final m3u8ProxyUrl = await UserDataService.getM3u8ProxyUrl();
        if (m3u8ProxyUrl.isNotEmpty) {
          final encodedUrl = Uri.encodeComponent(newUrl);
          finalUrl = '$m3u8ProxyUrl$encodedUrl';
          debugPrint("使用 M3U8 代理: $finalUrl");
        }
      }

      debugPrint("最终播放 URL: $finalUrl");

      if (_isCasting) {
        final sourceName = currentDetail?.sourceName ?? currentSource;
        String formattedTitle;
        if (totalEpisodes > 1) {
          final episodeNumber = currentEpisodeIndex + 1;
          formattedTitle = '$videoTitle - 第 $episodeNumber 集 - $sourceName';
        } else {
          formattedTitle = '$videoTitle - $sourceName';
        }
        _dlnaPlayerController?.updateVideoUrl(finalUrl, formattedTitle,
            startAt: startAt);

        if (mounted) {
          setState(() {
            _showSwitchLoadingOverlay = false;
          });
          _loadingTimeoutTimer?.cancel();
        }
      } else {
        // 本地播放
        debugPrint("调用播放器 updateDataSource");
        final playerController =
            _videoPlayerController ?? await _waitForVideoPlayerController();
        if (playerController == null) {
          throw StateError('video controller not ready');
        }
        // 增加超时保护，防止 updateDataSource 内部卡死
        await playerController
            .updateDataSource(finalUrl, startAt: startAt)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () =>
                  throw TimeoutException('updateDataSource timeout'),
            );
      }
    } catch (e, stackTrace) {
      debugPrint('updateVideoUrl 发生异常: $e');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() {
          _showSwitchLoadingOverlay = false;
        });
        _loadingTimeoutTimer?.cancel();
      }
      _showToast('播放失败: ${_formatPlaybackError(e)}');
    }
  }

  /// 跳转到指定进度
  Future<void> seekToProgress(Duration position) async {
    final controller = _videoPlayerController;
    if (controller == null) {
      _isSeeking = false;
      return;
    }

    try {
      _isSeeking = true;
      await controller.seekTo(position);
    } catch (e) {
      _danmakuSeekCompletionTimer?.cancel();
      _danmakuSeekSerial++;
      _isSeeking = false;
    }
  }

  void _handlePlayerSeek(Duration position) {
    final seekSerial = ++_danmakuSeekSerial;
    _danmakuSeekCompletionTimer?.cancel();

    _isSeeking = true;
    _lastDanmakuCheckTime = -1;

    Future<void>(() {
      if (!mounted || _isClosing || seekSerial != _danmakuSeekSerial) {
        return;
      }
      runDanmakuSeekCallbacks(
        resetIndex: () => _resetDanmakuIndex(position, clearVisible: false),
        clearVisible: () {},
      );
    });

    final shouldRenderImmediately = _hasExplicitDanmakuState
        ? _danmakuShouldPlay
        : (_videoPlayerController?.isPlaying ?? false);

    _danmakuSeekCompletionTimer = Timer(_asyncDanmakuSeekDelay, () {
      if (!mounted || _isClosing || seekSerial != _danmakuSeekSerial) {
        return;
      }

      _isSeeking = false;
      _syncDanmakuPlaybackState(reason: 'player_on_seek_async');

      if (shouldRenderImmediately) {
        _sendDanmakuByPosition(position);
      }
    });
  }

  /// 跳转到指定秒数
  Future<void> seekToSeconds(double seconds) async {
    await seekToProgress(Duration(seconds: seconds.round()));
  }

  /// 获取当前播放位置
  Duration? get currentPosition {
    if (_isCasting) {
      // 投屏状态：从 DLNA 播放器获取
      return _dlnaCurrentPosition;
    } else {
      return _videoPlayerController?.currentPosition;
    }
  }

  /// 获取视频总时长
  Duration? get duration {
    if (_isCasting) {
      return _dlnaCurrentDuration;
    } else {
      return _videoPlayerController?.duration;
    }
  }

  /// 处理视频播放器 ready 事件
  void _onVideoPlayerReady() {
    // 视频播放器准备就绪时的处理逻辑
    debugPrint('Video player is ready!');

    // 💡 新增：通过视频尺寸动态判断是否为短剧（竖屏视频）
    final videoSize = _videoPlayerController?.videoSize;
    if (videoSize != null && videoSize.width > 0 && videoSize.height > 0) {
      final bool isVertical = videoSize.height > videoSize.width;
      if (isVertical != _isShortDrama) {
        debugPrint(
            '检测到视频尺寸变化，更新短剧模式: $isVertical (${videoSize.width}x${videoSize.height})');
        if (mounted) {
          setState(() {
            _isShortDrama = isVertical;
          });
        }
      }
    }

    // 取消超时计时器
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;

    if (mounted) {
      setState(() {
        // 隐藏切换加载蒙版
        _showSwitchLoadingOverlay = false;
        _isLoading = false; // 确保主加载也重置
      });
    }

    // 重置最后保存时间，允许立即保存
    _lastSaveTime = null;

    // 添加视频播放状态监听器来触发保存检查
    _addVideoProgressListener();

    // 如果有待跳转的位置，立即进入锁定状态，防止在跳转完成前弹出 0s 开始的弹幕
    if (_resumeStartAt != null) {
      _isSeeking = true;
    }

    // 加载弹幕
    _loadDanmaku();

    // 延时 seek 到 _resumeStartAt
    if (_resumeStartAt != null) {
      final tmpStartAt = _resumeStartAt;
      _resumeStartAt = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (tmpStartAt != null) {
          seekToProgress(tmpStartAt);
        }
      });
    }
  }

  Future<void> _waitForLandscapeMetrics({
    Duration timeout = const Duration(milliseconds: 850),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final view = views.isNotEmpty ? views.first : null;
      if (view != null) {
        final size = view.physicalSize;
        if (size.width > size.height) {
          return;
        }
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  bool _isPhysicalLandscapeNow() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    if (view == null) return !_isPortraitTablet;
    final size = view.physicalSize;
    return size.width >= size.height;
  }

  void _onFullscreenChanged(bool isFullscreen) async {
    final requestId = ++_fullscreenTransitionSerial;
    final prev = _isFullscreen;
    final changed = prev != isFullscreen;
    debugPrint(
        '[FullscreenTrace] source=player_screen, event=onFullscreenChanged, prev=$prev, next=$isFullscreen, web=$_isWebFullscreen, entering=$_isEnteringLandscapeFullscreen, ep=$_currentDanmakuEpisodeId, list=${_danmakuList.length}');

    if (DeviceUtils.isPC()) {
      setState(() {
        _isFullscreen = isFullscreen;
        if (changed) {
          _danmakuViewportVersion++;
        }
      });
      if (changed) {
        debugPrint(
            '[DanmakuLayer] viewport_reset: full=$isFullscreen, version=$_danmakuViewportVersion, ep=$_currentDanmakuEpisodeId');
      }
      _scrollToCurrentEpisode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rebaseDanmakuCursorToCurrentPosition(
            reason: 'fullscreen_changed', triggerNow: true);
        _syncDanmakuPlaybackState(reason: 'fullscreen_changed');
        _refreshDanmakuOptionForPlayback(reason: 'fullscreen_changed');
      });
      return;
    }

    if (isFullscreen) {
      if (_isShortDrama) {
        setState(() {
          _isFullscreen = true;
          _isEnteringLandscapeFullscreen = false;
        });
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        debugPrint(
            '\u5168\u5c4f\u6a21\u5f0f\uff1a\u77ed\u5267/\u7ad6\u5c4f (\u4fdd\u6301\u7ad6\u5c4f\uff0c\u4fdd\u7559\u72b6\u6001\u680f)');
      } else {
        if (!_isEnteringLandscapeFullscreen) {
          setState(() {
            _isEnteringLandscapeFullscreen = true;
          });
        }

        final fullscreenOrientations = Platform.isIOS && !_isTablet
            ? const [
                DeviceOrientation.landscapeRight,
              ]
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ];

        SystemChrome.setPreferredOrientations(fullscreenOrientations);
        _lastAppliedFullscreenOrientations = fullscreenOrientations;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        await _waitForLandscapeMetrics();
        if (!mounted || requestId != _fullscreenTransitionSerial) return;
        if (Platform.isIOS) {
          await _refreshLastKnownPlayerInterfaceOrientation();
        }
        if (!mounted || requestId != _fullscreenTransitionSerial) return;

        final targetOrientations =
            await _fullscreenOrientationController.resolveAfterFullscreenEntry(
          platform: defaultTargetPlatform,
          isShortDramaPortraitFlow: _isShortDrama,
          lastAppliedOrientations: _lastAppliedFullscreenOrientations,
        );
        if (!mounted || requestId != _fullscreenTransitionSerial) return;

        if (targetOrientations != null) {
          await SystemChrome.setPreferredOrientations(targetOrientations);
          _lastAppliedFullscreenOrientations = targetOrientations;
        }

        setState(() {
          _isFullscreen = true;
          _isEnteringLandscapeFullscreen = false;
        });
        debugPrint(
            '\u5168\u5c4f\u6a21\u5f0f\uff1a\u666e\u901a\u5267/\u6a2a\u5c4f (\u65cb\u8f6c\u7a33\u5b9a\u540e\u5207\u6362\u5168\u5c4f\u5e03\u5c40)');
      }
    } else {
      setState(() {
        _isFullscreen = false;
        _isEnteringLandscapeFullscreen = false;
        _lastAppliedFullscreenOrientations = null;
        _playerRotationLocked = false;
        _lockedPlayerOrientations = null;
      });
      if (_isTablet) {
        // 平板退出全屏时，按当前物理方向优先恢复，避免被强制切到竖屏。
        final isLandscapeNow = _isPhysicalLandscapeNow();
        final orientations = isLandscapeNow
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]
            : const [
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ];
        SystemChrome.setPreferredOrientations(orientations);
        debugPrint('退出全屏：平板按设备方向恢复自动旋转，当前方向=${isLandscapeNow ? '横屏' : '竖屏'}');
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _scrollToCurrentEpisode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshDanmakuOptionForPlayback(reason: 'fullscreen_changed');
    });
  }

  void _addVideoProgressListener() {
    if (_videoPlayerController != null) {
      // 添加进度监听器
      _videoPlayerController!.addProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 移除视频播放进度监听器
  void _removeVideoProgressListener() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.removeProgressListener(_onVideoProgressUpdate);
    }
  }

  /// 视频播放进度更新回调
  void _onVideoProgressUpdate() {
    // 检查并保存进度（基于时间间隔）
    _checkAndSaveProgress();

    final position = _videoPlayerController?.currentPosition;
    final duration = _videoPlayerController?.duration;

    if (position != null) {
      // 自动跳过片头
      if (_skipIntroDuration > 0 &&
          position.inSeconds < _skipIntroDuration &&
          !_isRefreshing) {
        // 避免刷新时跳转
        _videoPlayerController?.seekTo(Duration(seconds: _skipIntroDuration));
        _showToast('已自动跳过片头');
      }

      // 自动跳过片尾
      if (_skipOutroDuration > 0 && duration != null) {
        final remainingSeconds = duration.inSeconds - position.inSeconds;
        if (remainingSeconds <= _skipOutroDuration && remainingSeconds > 0) {
          if (currentEpisodeIndex < totalEpisodes - 1) {
            _showToast('已自动跳过片尾，播放下一集');
            _onNextEpisode();
          }
        }
      }

      _sendDanmakuByPosition(position);
    }
  }

  /// 处理下一集按钮点击
  void _onNextEpisode() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      _showToast('已经是最后一集了');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换选集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '下一集按钮');

    // 播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 处理视频播放完成
  void _onVideoCompleted() {
    if (currentDetail == null) return;

    // 检查是否为最后一集
    if (currentEpisodeIndex >= currentDetail!.episodes.length - 1) {
      // _showToast('播放完成');
      return;
    }

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '自动播放下一集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '自动播放下一集');

    // 自动播放下一集
    final nextIndex = currentEpisodeIndex + 1;
    startPlay(nextIndex, 0);
  }

  /// 处理上一集按钮点击
  void _onPreviousEpisode() {
    if (currentDetail == null || currentEpisodeIndex <= 0) return;

    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换上一集...';
    });

    _saveProgress(force: true, scene: '上一集按钮');

    final prevIndex = currentEpisodeIndex - 1;
    startPlay(prevIndex, 0);
  }

  /// 显示Toast消息
  void _showToast(String message) {
    if (!mounted) return;

    // 获取屏幕宽度用于精确居中计算
    final screenWidth = MediaQuery.of(context).size.width;
    const toastWidth = 260.0;
    final horizontalMargin = (screenWidth - toastWidth) / 2;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        // 使用 margin 代替 width 可以更精确地控制左右间距，确保在各种异形屏下视觉居中
        margin: EdgeInsets.only(
          bottom: _isFullscreen ? 40 : 20,
          left: horizontalMargin,
          right: horizontalMargin,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
      ),
    );
  }

  String _formatSleepTimerClock(DateTime deadline) {
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatSleepTimerMessage(DateTime deadline) {
    final now = DateTime.now();
    final isSameDay = now.year == deadline.year &&
        now.month == deadline.month &&
        now.day == deadline.day;
    final prefix = isSameDay ? '' : '明天 ';
    return '$prefix${_formatSleepTimerClock(deadline)} ${SleepTimerService.timeoutActionLabel}';
  }

  void _scheduleSleepTimer(DateTime deadline) {
    _sleepTimer?.cancel();
    final delay = deadline.difference(DateTime.now());

    setState(() {
      _sleepTimerDeadline = deadline;
    });

    _sleepTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _handleSleepTimerTriggered,
    );
  }

  Future<bool> _setSleepTimerByMinutes(int minutes) async {
    if (minutes <= 0) {
      return false;
    }

    final deadline = DateTime.now().add(Duration(minutes: minutes));
    _scheduleSleepTimer(deadline);
    _showToast('设置成功，预计 ${_formatSleepTimerMessage(deadline)}');
    return true;
  }

  Future<bool> _setSleepTimerByTimeOfDay(TimeOfDay time) async {
    final now = DateTime.now();
    var deadline = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (!deadline.isAfter(now.add(const Duration(seconds: 30)))) {
      deadline = deadline.add(const Duration(days: 1));
    }

    _scheduleSleepTimer(deadline);
    _showToast('设置成功，预计 ${_formatSleepTimerMessage(deadline)}');
    return true;
  }

  Future<bool> _cancelSleepTimer({bool showToast = true}) async {
    if (_sleepTimer == null && _sleepTimerDeadline == null) {
      return false;
    }

    _sleepTimer?.cancel();
    _sleepTimer = null;

    if (mounted) {
      setState(() {
        _sleepTimerDeadline = null;
      });
    } else {
      _sleepTimerDeadline = null;
    }

    if (showToast) {
      _showToast('已取消定时关闭');
    }
    return true;
  }

  Future<void> _handleSleepTimerTriggered() async {
    if (_isHandlingSleepTimer) {
      return;
    }

    _isHandlingSleepTimer = true;
    await _cancelSleepTimer(showToast: false);

    try {
      await _setKeepScreenOn(false);
      _saveProgress(force: true, scene: '定时关闭');

      if (_isCasting && _dlnaDevice != null) {
        try {
          _dlnaDevice.stop();
        } catch (e) {
          debugPrint('定时关闭时停止投屏失败: $e');
        }
      }

      await _videoPlayerController?.pause();

      if (Platform.isAndroid) {
        final closed = await SleepTimerService.closeApp();
        if (!closed) {
          await SystemNavigator.pop();
        }
      } else if (mounted) {
        _showToast('已按计划停止播放');
      }
    } catch (e) {
      debugPrint('执行定时关闭失败: $e');
    } finally {
      _isHandlingSleepTimer = false;
    }
  }

  void _showSleepTimerPanel(BuildContext panelContext) {
    final theme = Theme.of(panelContext);
    final size = MediaQuery.of(panelContext).size;
    final isLandscape = size.width > size.height;
    final useSolidBackground = !DeviceUtils.isPC() &&
        !_isFullscreen &&
        !_isWebFullscreen &&
        !_isEnteringLandscapeFullscreen;
    final useInlineTimerPickers = !DeviceUtils.isPC();
    final useSideSheet = isLandscape ||
        (DeviceUtils.isTablet(panelContext) &&
            !DeviceUtils.isPortraitTablet(panelContext));

    final panel = PlayerSleepTimerPanel(
      theme: theme,
      sideSheet: useSideSheet,
      scheduledAt: _sleepTimerDeadline,
      canExitApp: SleepTimerService.supportsAppExit,
      backgroundOpacity: useSolidBackground ? 1.0 : null,
      onSetMinutes: _setSleepTimerByMinutes,
      onSetTimeOfDay: _setSleepTimerByTimeOfDay,
      onCancelTimer: () => _cancelSleepTimer(),
    );

    if (useSideSheet) {
      final panelWidth = math.min(size.width * 0.42, 340.0);
      final panelHeight = size.height;

      showGeneralDialog(
        context: panelContext,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: useSolidBackground
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: dialogContext,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            alignment: Alignment.centerRight,
            slideBegin: const Offset(1, 0),
            animation: animation,
            child: panel,
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: panelContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) {
        final height = useInlineTimerPickers
            ? math.min(size.height * 0.78, 620.0)
            : math.min(size.height * 0.62, 440.0);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: panel,
        );
      },
    );
  }

  /// 检查收藏状态
  void _checkFavoriteStatus() {
    if (currentSource.isNotEmpty && currentID.isNotEmpty) {
      final cacheService = PageCacheService();
      final isFavorited =
          cacheService.isFavoritedSync(currentSource, currentID);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorited;
        });
      }
    }
  }

  /// 切换收藏状态
  void _toggleFavorite() async {
    if (currentSource.isEmpty || currentID.isEmpty) return;

    final cacheService = PageCacheService();

    if (_isFavorite) {
      // 取消收藏
      final result =
          await cacheService.removeFavorite(currentSource, currentID, context);
      if (result.success) {
        setState(() {
          _isFavorite = false;
        });
      }
    } else {
      // 添加收藏
      final favoriteData = {
        'cover': videoCover,
        'save_time': DateTime.now().millisecondsSinceEpoch,
        'source_name': currentDetail?.sourceName ?? '',
        'title': videoTitle,
        'total_episodes': totalEpisodes,
        'year': videoYear,
      };

      final result = await cacheService.addFavorite(
          currentSource, currentID, favoriteData, context);
      if (result.success) {
        setState(() {
          _isFavorite = true;
        });
      }
    }
  }

  /// 切换选集排序
  void _toggleEpisodesOrder() {
    setState(() {
      _isEpisodesReversed = !_isEpisodesReversed;
    });
    // 切换排序后自动滚动到当前集数
    _scrollToCurrentEpisode();
  }

  /// 处理选集点击
  void _onEpisodeTap(int index) {
    if (currentDetail == null) return;

    // 显示切换加载蒙版
    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换选集...';
    });

    // 集数切换前保存进度
    _saveProgress(force: true, scene: '选集切换');

    // 播放指定集数
    startPlay(index, 0);
  }

  /// 处理换源点击
  void _onSourceTap(SearchResult source) {
    _switchSource(source);
  }

  String _normalizeRecordKey(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  bool _isUnknownYear(String year) {
    final normalized = year.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'unknown' || normalized == '未知';
  }

  bool _isSameVideoForPlayRecord(PlayRecord record, SearchResult targetSource) {
    final targetTitle = _normalizeRecordKey(targetSource.title);
    final recordTitle = _normalizeRecordKey(record.title);
    final targetSearchTitle = _normalizeRecordKey(searchTitle);
    final recordSearchTitle = _normalizeRecordKey(record.searchTitle);

    final titleMatched = targetTitle.isNotEmpty && recordTitle == targetTitle;
    final searchTitleMatched =
        targetSearchTitle.isNotEmpty && recordSearchTitle == targetSearchTitle;

    if (!titleMatched && !searchTitleMatched) {
      return false;
    }

    if (_isUnknownYear(targetSource.year) || _isUnknownYear(record.year)) {
      return true;
    }

    return targetSource.year.trim().toLowerCase() ==
        record.year.trim().toLowerCase();
  }

  Future<void> _cleanupOtherSourcePlayRecords(SearchResult keepSource) async {
    if (_isOfflinePlayback || !mounted) {
      return;
    }

    try {
      final cacheService = PageCacheService();
      final recordsResult = await cacheService.getPlayRecords(context);
      final records = recordsResult.data;
      if (!recordsResult.success || records == null || records.isEmpty) {
        return;
      }

      final toDelete = records
          .where((record) =>
              !(record.source == keepSource.source &&
                  record.id == keepSource.id) &&
              _isSameVideoForPlayRecord(record, keepSource))
          .toList();

      if (toDelete.isEmpty) {
        return;
      }

      debugPrint('换源后开始清理其他播放记录，待清理 ${toDelete.length} 条');

      for (final record in toDelete) {
        if (!mounted) break;
        final result = await cacheService.deletePlayRecord(
            record.source, record.id, context);
        if (!result.success) {
          debugPrint('清理播放记录失败: ${record.source}+${record.id}');
        }
      }

      debugPrint('换源后已清理其他源播放记录');
    } catch (e) {
      debugPrint('换源后清理其他源播放记录异常: $e');
    }
  }

  /// 刷新源列表
  Future<bool> _saveProgressForSwitchedSource({
    required SearchResult newSource,
    required int episodeIndex,
    required int playTime,
    required int totalTime,
  }) async {
    if (playTime < 1) {
      return false;
    }

    final safeEpisodeNumber = episodeIndex + 1;
    final safeTotalEpisodes =
        newSource.episodes.isEmpty ? totalEpisodes : newSource.episodes.length;
    final safeTotalTime = totalTime > playTime ? totalTime : playTime + 1;
    final now = DateTime.now();

    final playRecord = PlayRecord(
      id: newSource.id,
      source: newSource.source,
      title: newSource.title,
      sourceName: newSource.sourceName,
      year: newSource.year,
      cover: newSource.poster,
      index: safeEpisodeNumber,
      totalEpisodes: safeTotalEpisodes,
      playTime: playTime,
      totalTime: safeTotalTime,
      saveTime: now.millisecondsSinceEpoch,
      searchTitle: searchTitle,
    );

    _lastSaveTime = now;
    _lastSavePosition = playTime;

    if (_isOfflinePlayback) {
      try {
        await LocalModeStorageService.savePlayRecord(playRecord);
        debugPrint(
            '换源后立即保存本地播放记录: source=${newSource.source}, id=${newSource.id}, 第${safeEpisodeNumber}集, 时间=${playTime}秒');
        return true;
      } catch (e) {
        debugPrint('换源后立即保存本地播放记录失败: $e');
        return false;
      }
    }

    try {
      final r = await PageCacheService().savePlayRecord(playRecord, context);
      if (!r.success) {
        debugPrint('换源后立即保存播放记录失败: ${r.errorMessage ?? 'unknown'}');
        return false;
      }
      debugPrint(
          '换源后立即保存播放记录: source=${newSource.source}, id=${newSource.id}, 第${safeEpisodeNumber}集, 时间=${playTime}秒');
      return true;
    } catch (e) {
      debugPrint('换源后立即保存播放记录异常: $e');
      return false;
    }
  }

  Future<void> _refreshSources() async {
    await _refreshSourcesSpeed();
  }

  /// 滚动到当前源
  void _scrollToCurrentSource() {
    if (currentDetail == null) return;

    // 换源已收起，直接执行滚动
    _performScrollToCurrentSource();
  }

  /// 执行滚动到当前源的具体逻辑
  void _performScrollToCurrentSource() {
    if (currentDetail == null || !_sourcesScrollController.hasClients) return;

    // 找到当前源在allSources中的索引
    final currentSourceIndex = allSources.indexWhere(
        (source) => source.source == currentSource && source.id == currentID);

    if (currentSourceIndex == -1) return;

    // 动态计算卡片宽度
    // 在平板横屏模式下，需要考虑左侧区域只占65%的宽度
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveWidth = (_isTablet && !_isPortraitTablet)
        ? screenWidth * 0.65 // 平板横屏：只使用左侧65%的宽度
        : screenWidth; // 其他情况：使用全屏宽度

    const listViewPadding = 16.0; // ListView的左右padding
    const itemMargin = 6.0; // 每个item的右边距
    final availableWidth =
        effectiveWidth - (listViewPadding * 2); // 减去左右padding
    final cardsPerView = _isTablet ? 6.2 : 3.2;
    final cardWidth = (availableWidth / cardsPerView) - itemMargin; // 减去右边距

    // 计算选中项在可视区域中央的偏移量
    // 可视区域中心 = (有效宽度 - ListView左右padding) / 2
    // 选中项应该位于这个中心位置
    final visibleAreaWidth = effectiveWidth - (listViewPadding * 2);
    final visibleCenter = visibleAreaWidth / 2;
    final itemCenter = cardWidth / 2;

    // 计算需要滚动的距离，使选中项的中心对准可视区域的中心
    // 注意：要减去第一个item的左边距（因为ListView有左padding）
    final targetOffset = (currentSourceIndex * (cardWidth + itemMargin)) -
        (visibleCenter - itemCenter - listViewPadding);

    // 确保不滚动到负值或超出范围
    final maxScrollExtent = _sourcesScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScrollExtent);

    _sourcesScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 切换视频源
  void _switchSource(SearchResult newSource) async {
    // 如果是同一个源，则不重复处理
    if (currentSource == newSource.source && currentID == newSource.id) {
      return;
    }
    final switchSerial = ++_sourceSwitchRecordSerial;

    // 保存当前播放进度
    final currentProgress =
        currentPosition?.inSeconds ?? _lastSavePosition ?? 0;
    final currentTotalDuration = duration?.inSeconds ?? 0;
    final currentEpisode = currentEpisodeIndex;

    setState(() {
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '切换播放源...';

      currentDetail = newSource;
      currentSource = newSource.source;
      currentID = newSource.id;
      currentEpisodeIndex = currentEpisode; // 保持当前集数
      totalEpisodes = newSource.episodes.length;
      _isEpisodesReversed = false;

      // 同步更新视频信息，避免 UI 显示旧数据
      videoTitle = newSource.title;
      videoDesc = newSource.desc ?? '';
      videoYear = newSource.year;
      videoCover = newSource.poster;
    });

    // 处理豆瓣 ID 变化逻辑
    int oldVideoDoubanID = videoDoubanID;
    if (newSource.doubanId != null && newSource.doubanId! > 0) {
      videoDoubanID = newSource.doubanId!;
    } else {
      Map<int, int> doubanIDCount = {};
      for (var result in allSources) {
        int? tmpDoubanID = result.doubanId;
        if (tmpDoubanID != null && tmpDoubanID != 0) {
          doubanIDCount[tmpDoubanID] = (doubanIDCount[tmpDoubanID] ?? 0) + 1;
        }
      }
      videoDoubanID = doubanIDCount.entries.isEmpty
          ? 0
          : doubanIDCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
    }

    if (videoDoubanID != oldVideoDoubanID && videoDoubanID > 0) {
      _fetchDoubanDetails();
    }

    // 重新检查收藏状态
    _checkFavoriteStatus();

    // 先启动新源播放，记录保存与清理在后台串行处理，避免阻塞切源。
    startPlay(currentEpisode, currentProgress);

    unawaited(() async {
      final saved = await _saveProgressForSwitchedSource(
        newSource: newSource,
        episodeIndex: currentEpisode,
        playTime: currentProgress,
        totalTime: currentTotalDuration,
      );

      if (!saved) {
        debugPrint('换源记录保护：新记录保存失败，跳过旧记录清理，避免记录丢失');
        return;
      }

      // 只允许最新一次切源执行清理，防止快速切源时旧任务误删。
      if (!mounted ||
          switchSerial != _sourceSwitchRecordSerial ||
          currentSource != newSource.source ||
          currentID != newSource.id) {
        debugPrint('换源记录保护：检测到切源任务已过期，跳过旧记录清理');
        return;
      }

      await _cleanupOtherSourcePlayRecords(newSource);
    }());

    // 延迟滚动到当前源
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentSource();
    });
  }

  /// 自动滚动到当前集数
  void _scrollToCurrentEpisode() {
    if (currentDetail == null) return;

    // 如果选集展开，先收起选集，然后滚动到当前集数
    _performScrollToCurrentEpisode();
  }

  /// 执行滚动到当前集数的具体逻辑
  void _performScrollToCurrentEpisode() {
    if (currentDetail == null || !_episodesScrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_episodesScrollController.hasClients) return;

      final totalEpisodes = currentDetail!.episodes.length;
      final targetPhysicalIndex = _isEpisodesReversed
          ? totalEpisodes - 1 - currentEpisodeIndex
          : currentEpisodeIndex;

      debugPrint(
          '[EpisodeLocate] begin: total=$totalEpisodes, current=$currentEpisodeIndex, target=$targetPhysicalIndex, reversed=$_isEpisodesReversed');

      if (targetPhysicalIndex < 0 || targetPhysicalIndex >= totalEpisodes) {
        debugPrint(
            '[EpisodeLocate] index_out_of_range: target=$targetPhysicalIndex, total=$totalEpisodes, current=$currentEpisodeIndex');
        return;
      }

      final position = _episodesScrollController.position;
      final viewportWidth = position.viewportDimension;
      if (viewportWidth <= 0) {
        debugPrint(
            '[EpisodeLocate] invalid_viewport_width: viewportWidth=$viewportWidth');
        return;
      }

      double estimateOffsetByProgress() {
        final maxScrollExtent = position.maxScrollExtent;
        if (totalEpisodes <= 1 || maxScrollExtent <= 0) {
          debugPrint(
              '[EpisodeLocate] estimate_progress: fallback_zero, max=${maxScrollExtent.toStringAsFixed(2)}');
          return 0;
        }

        final ratio = targetPhysicalIndex / (totalEpisodes - 1);
        final rawOffset = ratio * maxScrollExtent;
        debugPrint(
            '[EpisodeLocate] estimate_progress: ratio=${ratio.toStringAsFixed(4)}, raw=${rawOffset.toStringAsFixed(2)}, max=${maxScrollExtent.toStringAsFixed(2)}');
        return rawOffset;
      }

      double estimateOffsetByItemSize() {
        const itemMargin = 6.0;
        const cardsPerViewTablet = 6.2;
        const cardsPerViewPhone = 3.2;
        final cardsPerView = _isTablet ? cardsPerViewTablet : cardsPerViewPhone;

        double? measuredCardWidth;
        for (final key in _episodeCardKeys.values) {
          final cardContext = key.currentContext;
          if (cardContext == null) continue;
          final renderObject = cardContext.findRenderObject();
          if (renderObject is RenderBox &&
              renderObject.attached &&
              renderObject.hasSize &&
              renderObject.size.width > 0) {
            measuredCardWidth = renderObject.size.width;
            break;
          }
        }

        final cardWidth =
            measuredCardWidth ?? (viewportWidth / cardsPerView) - itemMargin;
        final itemExtent = cardWidth + itemMargin;
        final rawOffset = (targetPhysicalIndex * itemExtent) -
            ((viewportWidth - cardWidth) / 2);

        debugPrint(
            '[EpisodeLocate] estimate_formula: viewport=${viewportWidth.toStringAsFixed(2)}, card=${cardWidth.toStringAsFixed(2)}, itemExtent=${itemExtent.toStringAsFixed(2)}, raw=${rawOffset.toStringAsFixed(2)}');

        return rawOffset;
      }

      double? estimateOffsetByVisibleItems() {
        final viewportContext =
            _episodesScrollController.position.context.notificationContext;
        final viewportObject = viewportContext?.findRenderObject();
        if (viewportObject is! RenderBox ||
            !viewportObject.attached ||
            !viewportObject.hasSize) {
          // debugPrint('[EpisodeLocate] estimate_visible_skip: no_viewport');
          return null;
        }

        final viewportLeft = viewportObject.localToGlobal(Offset.zero).dx;
        final List<Map<String, double>> visibleItems = [];

        for (final entry in _episodeCardKeys.entries) {
          final cardContext = entry.value.currentContext;
          if (cardContext == null) continue;

          final scrollable = Scrollable.maybeOf(cardContext);
          if (scrollable == null ||
              scrollable.widget.controller != _episodesScrollController) {
            continue;
          }

          final renderObject = cardContext.findRenderObject();
          if (renderObject is! RenderBox ||
              !renderObject.attached ||
              !renderObject.hasSize) {
            continue;
          }

          final width = renderObject.size.width;
          if (width <= 0) continue;

          final localLeft =
              renderObject.localToGlobal(Offset.zero).dx - viewportLeft;
          if (localLeft > viewportWidth + 1 || localLeft + width < -1) {
            continue;
          }

          visibleItems.add({
            'index': entry.key.toDouble(),
            'leading': position.pixels + localLeft,
            'width': width,
          });
        }

        if (visibleItems.length < 2) {
          debugPrint(
              '[EpisodeLocate] estimate_visible_skip: not_enough_items=${visibleItems.length}');
          return null;
        }

        visibleItems.sort((a, b) => a['index']!.compareTo(b['index']!));

        final first = visibleItems.first;
        final last = visibleItems.last;
        final firstIndex = first['index']!;
        final lastIndex = last['index']!;
        final firstLeading = first['leading']!;
        final lastLeading = last['leading']!;
        final indexSpan = lastIndex - firstIndex;

        if (indexSpan.abs() < 0.5) {
          debugPrint(
              '[EpisodeLocate] estimate_visible_skip: index_span_too_small=$indexSpan');
          return null;
        }

        final itemExtent = (lastLeading - firstLeading) / indexSpan;
        if (itemExtent.abs() < 1) {
          debugPrint(
              '[EpisodeLocate] estimate_visible_skip: invalid_item_extent=$itemExtent');
          return null;
        }

        final totalWidth =
            visibleItems.fold<double>(0, (sum, item) => sum + item['width']!);
        final cardWidth = totalWidth / visibleItems.length;
        final targetLeading =
            firstLeading + ((targetPhysicalIndex - firstIndex) * itemExtent);
        final rawOffset = targetLeading - ((viewportWidth - cardWidth) / 2);

        debugPrint(
            '[EpisodeLocate] estimate_visible: first=${firstIndex.toStringAsFixed(0)}, last=${lastIndex.toStringAsFixed(0)}, itemExtent=${itemExtent.toStringAsFixed(2)}, card=${cardWidth.toStringAsFixed(2)}, raw=${rawOffset.toStringAsFixed(2)}');

        return rawOffset;
      }

      Future<void> animateTo(double offset, String mode) async {
        final maxScrollExtent = position.maxScrollExtent;
        final currentOffset = position.pixels;
        final clampedOffset = offset.clamp(0.0, maxScrollExtent).toDouble();

        debugPrint(
            '[EpisodeLocate] $mode: current=${currentOffset.toStringAsFixed(2)}, target=${clampedOffset.toStringAsFixed(2)}, max=${maxScrollExtent.toStringAsFixed(2)}');

        await _episodesScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        if (!mounted || !_episodesScrollController.hasClients) return;
        final afterOffset = _episodesScrollController.position.pixels;
        debugPrint(
            '[EpisodeLocate] ${mode}_end: after=${afterOffset.toStringAsFixed(2)}, diff=${(afterOffset - clampedOffset).toStringAsFixed(2)}');
      }

      double? tryGetRevealOffset(String stage) {
        final targetKey = _episodeCardKeys[currentEpisodeIndex];
        final cardContext = targetKey?.currentContext;

        if (cardContext == null) {
          // debugPrint('[EpisodeLocate] reveal_skip($stage): no_context');
          return null;
        }

        final scrollable = Scrollable.maybeOf(cardContext);
        if (scrollable == null ||
            scrollable.widget.controller != _episodesScrollController) {
          // debugPrint('[EpisodeLocate] reveal_skip($stage): wrong_scrollable');
          return null;
        }

        final renderObject = cardContext.findRenderObject();
        if (renderObject == null || !renderObject.attached) {
          // debugPrint(
          // '[EpisodeLocate] reveal_skip($stage): detached_render_object');
          return null;
        }

        final viewport = RenderAbstractViewport.of(renderObject);
        final revealOffset =
            viewport.getOffsetToReveal(renderObject, 0.5).offset;

        debugPrint(
            '[EpisodeLocate] reveal($stage): offset=${revealOffset.toStringAsFixed(2)}');
        return revealOffset;
      }

      Future<void> tryVisualCorrection() async {
        if (!mounted || !_episodesScrollController.hasClients) return;

        final targetKey = _episodeCardKeys[currentEpisodeIndex];
        final cardContext = targetKey?.currentContext;
        final cardObject = cardContext?.findRenderObject();
        final viewportContext =
            _episodesScrollController.position.context.notificationContext;
        final viewportObject = viewportContext?.findRenderObject();

        if (cardObject is! RenderBox ||
            viewportObject is! RenderBox ||
            !cardObject.attached ||
            !viewportObject.attached ||
            !cardObject.hasSize ||
            !viewportObject.hasSize) {
          debugPrint(
              '[EpisodeLocate] visual_skip: card_or_viewport_unavailable');
          return;
        }

        final cardLeft = cardObject.localToGlobal(Offset.zero).dx;
        final viewportLeft = viewportObject.localToGlobal(Offset.zero).dx;
        final cardCenter = cardLeft + (cardObject.size.width / 2);
        final viewportCenter = viewportLeft + (viewportObject.size.width / 2);
        final delta = cardCenter - viewportCenter;

        debugPrint(
            '[EpisodeLocate] visual: viewportLeft=${viewportLeft.toStringAsFixed(2)}, viewportWidth=${viewportObject.size.width.toStringAsFixed(2)}, cardLeft=${cardLeft.toStringAsFixed(2)}, cardWidth=${cardObject.size.width.toStringAsFixed(2)}, delta=${delta.toStringAsFixed(2)}');

        if (delta.abs() < 1.0) {
          return;
        }

        await animateTo(position.pixels + delta, 'correct');
      }

      Future<bool> revealAndCorrect(String stage,
          {String mode = 'reveal'}) async {
        final revealOffset = tryGetRevealOffset(stage);
        if (revealOffset == null) return false;
        await animateTo(revealOffset, mode);
        await tryVisualCorrection();
        return true;
      }

      Future<void> runLocate() async {
        if (!mounted || !_episodesScrollController.hasClients) return;

        if (await revealAndCorrect('initial')) return;

        final visibleOffset = estimateOffsetByVisibleItems();
        if (visibleOffset != null) {
          await animateTo(visibleOffset, 'estimate_visible');
          await Future<void>.delayed(const Duration(milliseconds: 16));
          if (!mounted || !_episodesScrollController.hasClients) return;
          if (await revealAndCorrect('after_visible')) return;
        }

        await animateTo(estimateOffsetByProgress(), 'estimate_progress');
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!mounted || !_episodesScrollController.hasClients) return;
        if (await revealAndCorrect('after_progress')) return;

        await animateTo(estimateOffsetByItemSize(), 'estimate_formula');

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted || !_episodesScrollController.hasClients) return;
          if (await revealAndCorrect('after_formula', mode: 'reveal_retry')) {
            return;
          }
          await tryVisualCorrection();
        });
      }

      runLocate().catchError((error) {
        debugPrint('[EpisodeLocate] locate_error: $error');
      });
    });
  }

  /// Build player widget
  Widget _buildPlayerWidget() {
    final isPC = DeviceUtils.isPC();

    return Stack(
      children: [
        if (!_isCasting)
          VideoPlayerWidget(
            key: _videoPlayerWidgetKey,
            surface:
                isPC ? VideoPlayerSurface.desktop : VideoPlayerSurface.mobile,
            url: null,
            initialFitType: _currentFitType,
            onBackPressed: _onBackPressed,
            onControllerCreated: (controller) {
              _videoPlayerController = controller;
            },
            onReady: _onVideoPlayerReady,
            onNextEpisode: _onNextEpisode,
            onPreviousEpisode: _onPreviousEpisode,
            onEpisodeChanged: (index) {
              startPlay(index, 0);
            },
            onVideoCompleted: _onVideoCompleted,
            onSeek: _handlePlayerSeek,
            onPlay: () {
              runDanmakuResumeCallbacks(
                sync: () => _syncDanmakuPlaybackState(
                    reason: 'player_on_play', forcePlaying: true),
              );
            },
            onPause: () {
              // 暂停时保存进度
              _saveProgress(force: true, scene: '暂停');
              _syncDanmakuPlaybackState(
                  reason: 'player_on_pause', forcePlaying: false);
            },
            isLastEpisode: currentDetail != null &&
                currentEpisodeIndex >= currentDetail!.episodes.length - 1,
            onCastStarted: _onCastStarted,
            videoTitle: videoTitle,
            videoYear: videoYear,
            videoCover: videoCover, // 💡 新增
            currentEpisodeIndex: currentEpisodeIndex,
            totalEpisodes: totalEpisodes,
            episodesTitles: currentDetail?.episodesTitles,
            sourceName: currentDetail?.sourceName ?? currentSource,
            currentSource: currentSource,
            currentId: currentID,
            allSources: allSources,
            allSourcesSpeed: allSourcesSpeed,
            isShortDrama: _isShortDrama,
            isLocal: _isOfflinePlayback,
            onWebFullscreenChanged: (isWebFullscreen) {
              final prevWeb = _isWebFullscreen;
              debugPrint(
                  '[FullscreenTrace] source=player_screen, event=onWebFullscreenChanged, prev=$prevWeb, next=$isWebFullscreen, full=$_isFullscreen, ep=$_currentDanmakuEpisodeId');
              setState(() {
                _isWebFullscreen = isWebFullscreen;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _rebaseDanmakuCursorToCurrentPosition(
                    reason: 'web_fullscreen_changed', triggerNow: true);
                _syncDanmakuPlaybackState(reason: 'web_fullscreen_changed');
                _refreshDanmakuOptionForPlayback(
                    reason: 'web_fullscreen_changed');
              });
            },
            onFullscreenChanged: _onFullscreenChanged,
            onPlayerLockChanged: _handlePlayerLockChanged,
            onEpisodesButtonPressed: (fullscreenContext) {
              // 在全屏模式下，使用传入的 context 显示选集面板
              _showEpisodesPanelInFullscreen(fullscreenContext);
            },
            onSourcesButtonPressed: (fullscreenContext) {
              // 在全屏模式下，使用传入的 context 显示换源面板
              _showSourcesPanelInFullscreen(fullscreenContext);
            },
            onSettingsButtonPressed: (fullscreenContext) {
              // 在全屏模式下，使用传入的 context 显示设置面板
              _showSettingsPanelInFullscreen(fullscreenContext);
            },
            onSleepTimerButtonPressed: (playerContext) {
              _showSleepTimerPanel(playerContext);
            },
            onDanmakuButtonPressed: (fullscreenContext) {
              // 在全屏模式下，使用传入的 context 显示弹幕设置面板
              _showDanmakuPanelInFullscreen(fullscreenContext);
            },
            onDanmakuMatchButtonPressed: (fullscreenContext) {
              // 在全屏模式下，使用传入的 context 显示弹幕手动匹配面板
              _showDanmakuMatchPanelInFullscreen(fullscreenContext);
            },
            isDanmakuEnabled: _danmakuSettings.enabled,
            onDanmakuToggle: _toggleDanmakuEnabled,
            danmakuSettings: _danmakuSettings,
            onDanmakuSettingsChanged: _applyDanmakuSettings,
            onPlaybackSpeedChanged: _onPlaybackSpeedChanged,
            forceControlsVisible: _forcePcControlsVisible,
            onSourceChanged: (source) {
              _switchSource(source);
            },
            isFavorite: _isFavorite,
            onFavoriteToggle: _toggleFavorite,
            onCastButtonPressed: () {
              _showCastDeviceDialog();
            },
            longPressSpeed: _longPressSpeed,
            progressMode: _progressMode,
            showSystemTime: _showSystemTime,
            hideCenterControlsWithBars: _hideCenterControlsWithBars,
            hasActiveSleepTimer: _sleepTimerDeadline != null,
            mediaKitPreloadEnabled: _mediaKitPreloadEnabled,
            adFilterEnabled: _adFilterEnabled,
            danmakuLayer: _danmakuSettings.enabled && !_isClosing
                ? IgnorePointer(
                    child: LayoutBuilder(builder: (context, constraints) {
                      // 💡 统一按播放器真实高度比例裁剪显示区域
                      final baseHeight = constraints.maxHeight;
                      _traceDanmakuLayerLayout(constraints);

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: baseHeight * _danmakuSettings.displayArea,
                          child: DanmakuScreen(
                            key: ValueKey(
                                'danmaku_${_currentDanmakuEpisodeId}_v$_danmakuViewportVersion'),
                            createdController: (controller) {
                              _handleDanmakuControllerCreated(controller);
                            },
                            option: _buildDanmakuOption(
                              _resolveRenderDanmakuSettings(),
                            ),
                          ),
                        ),
                      );
                    }),
                  )
                : null,
          ),
        if (_isCasting && _dlnaDevice != null)
          DLNAPlayer(
            device: _dlnaDevice,
            onBackPressed: _onBackPressed,
            onNextEpisode: _onNextEpisode,
            onVideoCompleted: _onVideoCompleted,
            isLastEpisode: currentDetail != null &&
                currentEpisodeIndex >= currentDetail!.episodes.length - 1,
            onChangeDevice: _onChangeDevice,
            resumePosition: _castStartPosition,
            onStopCasting: _onStopCasting,
            onProgressUpdate: _onDLNAProgressUpdate,
            onPause: () {
              // 暂停时保存进度
              _saveProgress(force: true, scene: 'DLNA暂停');
            },
            onReady: _onVideoPlayerReady,
            onControllerCreated: (controller) {
              _dlnaPlayerController = controller;
            },
          ),
        // 切换播放源/集数时的加载蒙版（只遮挡播放器）
        SwitchLoadingOverlay(
          isVisible: _showSwitchLoadingOverlay,
          message: _switchLoadingMessage,
          animationController: _switchLoadingAnimationController,
          onBackPressed: _isWebFullscreen ? _exitWebFullscreen : _onBackPressed,
          isFullscreen: _isFullscreen,
        ),
      ],
    );
  }

  /// 弹出投屏设备选择对话框
  void _showCastDeviceDialog() async {
    if (currentDetail == null) return;

    // 获取当前播放的 URL
    final currentUrl = currentDetail!.episodes[currentEpisodeIndex];
    // 获取当前播放位置
    final currentPos = _videoPlayerController?.currentPosition;

    // 显示设备选择对话框
    await showDialog(
      context: context,
      builder: (context) => DLNADeviceDialog(
        currentUrl: currentUrl,
        currentDevice: _dlnaDevice,
        resumePosition: currentPos,
        videoTitle: videoTitle,
        currentEpisodeIndex: currentEpisodeIndex,
        totalEpisodes: totalEpisodes,
        sourceName: currentDetail?.sourceName ?? currentSource,
        onCastStarted: _onCastStarted,
      ),
    );
  }

  /// 投屏开始回调
  void _onCastStarted(dynamic device) {
    // 保存当前播放位置
    final currentPos = _videoPlayerController?.currentPosition;

    setState(() {
      _isCasting = true;
      _dlnaDevice = device;
      _castStartPosition = currentPos;
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
    });
  }

  /// DLNA 进度更新回调
  void _onDLNAProgressUpdate(Duration position, Duration duration) {
    _dlnaCurrentPosition = position;
    _dlnaCurrentDuration = duration;
    // 检查并保存进度
    _checkAndSaveProgress();
  }

  /// 停止投屏回调
  void _onStopCasting(Duration currentPosition) async {
    // 显示弹窗让用户选择
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('停止投屏'),
        content: const Text('DLNA 设备可继续保持播放，是否需要停止？\n\n（保持播放时无法同步进度和播放记录）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保持'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('停止'),
          ),
        ],
      ),
    );

    // 如果用户选择停止，才调用 stop
    if (shouldStop == true) {
      try {
        _dlnaDevice.stop();
        debugPrint('用户选择停止投屏');
      } catch (e) {
        debugPrint('停止投屏失败: $e');
      }
    } else {
      debugPrint('用户选择保持播放');
    }

    debugPrint('停止投屏，当前位置: ${currentPosition.inSeconds}秒');

    // 先保存需要恢复的位置和集数，避免异步回调中值丢失
    final resumeSeconds = currentPosition.inSeconds;
    final resumeEpisodeIndex = currentEpisodeIndex;

    setState(() {
      _isCasting = false;
      _dlnaDevice = null;
      _castStartPosition = null;
      _dlnaCurrentPosition = null;
      _dlnaCurrentDuration = null;
      _showSwitchLoadingOverlay = true;
      _switchLoadingMessage = '视频加载中...';
    });

    // 等待下一帧，确保 MobileVideoPlayerWidget 已经重新创建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentDetail != null) {
        debugPrint('恢复播放: 第${resumeEpisodeIndex + 1}集, ${resumeSeconds}秒');
        // 调用 startPlay 重新初始化播放器
        startPlay(resumeEpisodeIndex, resumeSeconds);
      }
    });
  }

  /// 换设备回调
  void _onChangeDevice() async {
    if (currentDetail == null) return;

    // 获取当前播放的 URL
    final currentUrl = currentDetail!.episodes[currentEpisodeIndex];

    // 显示设备选择对话框
    await showDialog(
      context: context,
      builder: (context) => DLNADeviceDialog(
        currentUrl: currentUrl,
        currentDevice: _dlnaDevice,
        resumePosition: _castStartPosition,
        videoTitle: videoTitle,
        currentEpisodeIndex: currentEpisodeIndex,
        totalEpisodes: totalEpisodes,
        sourceName: currentDetail?.sourceName ?? currentSource,
        onCastStarted: (device) {
          setState(() {
            _dlnaDevice = device;
          });
        },
      ),
    );
  }

  Widget _wrapCompactActionTapTarget(
    BuildContext context,
    Widget child, {
    VoidCallback? onTap,
    double width = 72,
    AlignmentGeometry alignment = Alignment.centerRight,
  }) {
    // final bool shouldExpandTapWidth =
    //     Platform.isIOS && !DeviceUtils.isTablet(context);
    final bool shouldExpandTapWidth = !DeviceUtils.isTablet(context);
    if (!shouldExpandTapWidth) {
      return child;
    }

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Align(
          alignment: alignment,
          child: IgnorePointer(
            child: child,
          ),
        ),
      ),
    );
  }

  /// 构建视频详情展示区域
  Widget _buildVideoDetailSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    if (currentDetail == null) {
      return Container(
        color: Colors.transparent,
        child: const Center(
          child: Text('加载中...'),
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 标题和收藏按钮行
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      videoTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 下载按钮 (本地播放时隐藏)
                  if (!_isOfflinePlayback)
                    GestureDetector(
                      onTap: _showDownloadPanel,
                      child: Icon(
                        LucideIcons.folderDown,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        size: 26,
                      ),
                    ),
                  if (!_isOfflinePlayback) const SizedBox(width: 16),
                  // 收藏按钮 (本地播放时隐藏)
                  if (!_isOfflinePlayback)
                    GestureDetector(
                      onTap: _toggleFavorite,
                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite
                            ? const Color(0xFFe74c3c)
                            : (isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                        size: 28,
                      ),
                    ),
                ],
              ),
            ),

            // 源名称、年份和分类信息行
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 12, bottom: 16),
              child: Row(
                children: [
                  // 源名称（带边框样式）
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentDetail!.sourceName,
                      style: FontUtils.poppins(
                        fontSize: theme.textTheme.bodySmall?.fontSize,
                        fontWeight: theme.textTheme.bodySmall?.fontWeight ??
                            FontWeight.w400,
                        color: isDarkMode ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 年份
                  if (videoYear.isNotEmpty && videoYear != 'unknown')
                    Text(
                      videoYear,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[300] : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  if (videoYear.isNotEmpty && videoYear != 'unknown')
                    const SizedBox(width: 12),

                  // 分类信息（绿色文字样式，充满可用空间但不与详情按钮重叠）
                  if (currentDetail!.class_ != null &&
                      currentDetail!.class_!.isNotEmpty)
                    Expanded(
                      child: Text(
                        currentDetail!.class_!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2ecc71),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  if (currentDetail!.class_ == null ||
                      currentDetail!.class_!.isEmpty)
                    const Spacer(),

                  const SizedBox(width: 12),

                  // 详情按钮（平板横屏模式下不显示）
                  if (!(_isTablet && !_isPortraitTablet))
                    _wrapCompactActionTapTarget(
                      context,
                      onTap: _showDetailsPanel,
                      width: 72,
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _showDetailsPanel();
                        },
                        child: Stack(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '详情',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                const SizedBox(width: 18),
                              ],
                            ),
                            Positioned(
                              right: 0,
                              top: 4,
                              child: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 视频描述行
            if (videoDesc.isNotEmpty ||
                (doubanDetails?.summary != null &&
                    doubanDetails!.summary!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 0, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    (videoDesc.isNotEmpty && videoDesc != '暂无简介')
                        ? videoDesc
                        : (doubanDetails?.summary ?? '暂无简介'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            // 选集区域
            _buildEpisodesSection(theme),

            const SizedBox(height: 16),

            // 换源区域 (本地播放时隐藏)
            if (!_isOfflinePlayback) _buildSourcesSection(theme),

            if (!_isOfflinePlayback) const SizedBox(height: 16),

            // 相关推荐区域
            _buildRecommendsSection(theme),
          ],
        ),
      ),
    );
  }

  /// 构建相关推荐区域
  Widget _buildRecommendsSection(ThemeData theme) {
    // 如果没有豆瓣详情或推荐列表为空，不显示此区域
    if (doubanDetails == null || doubanDetails!.recommends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 推荐标题行
        Padding(
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '相关推荐',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // 推荐卡片网格
        _buildRecommendsGrid(theme)
      ],
    );
  }

  /// 构建推荐卡片网格
  Widget _buildRecommendsGrid(ThemeData theme) {
    final recommends = doubanDetails!.recommends;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double padding = 16.0;
        final double spacing = 12.0;
        final baseCrossAxisCount = _isTablet ? 6 : 3;
        const maxItemWidth = 170.0;
        const minItemWidth = 80.0;
        final dynamicCrossAxisCount =
            ((screenWidth - (padding * 2) + spacing) / (maxItemWidth + spacing))
                .floor();
        final crossAxisCount = math.max(
          baseCrossAxisCount,
          math.max(1, dynamicCrossAxisCount),
        );
        final double availableWidth =
            screenWidth - (padding * 2) - (spacing * (crossAxisCount - 1));
        final double itemWidth =
            (availableWidth / crossAxisCount).clamp(minItemWidth, maxItemWidth);
        final double itemHeight = itemWidth * 2.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: itemWidth / itemHeight,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 4,
            ),
            itemCount: recommends.length,
            itemBuilder: (context, index) {
              final recommend = recommends[index];
              final videoInfo = recommend.toVideoInfo();

              return VideoCard(
                videoInfo: videoInfo,
                from: 'douban',
                cardWidth: itemWidth,
                isFavorited: PageCacheService().isFavoritedSync(
                    videoInfo.source, videoInfo.id), // 💡 实时检查收藏状态
                onTap: () => _onRecommendTap(recommend),
                onGlobalMenuAction: (action) {
                  // 💡 复用已有的菜单处理逻辑
                  _onGlobalMenuActionFromVideoInfo(videoInfo, action);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// 处理推荐卡片点击
  void _onRecommendTap(DoubanRecommendItem recommend) {
    // 投屏状态下，弹窗提示用户先关闭投屏
    if (_isCasting) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('请先关闭投屏后再切换视频'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 本地播放：根据设备类型暂停对应播放器
    if (_videoPlayerController?.isPlaying == true) {
      _videoPlayerController?.pause();
    }

    // 💡 优化：使用 pushReplacement 代替 push
    // 这样点击推荐视频时，会销毁当前播放页，返回时直接跳过这一页回到之前的列表页
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: recommend.title,
        ),
      ),
    );
  }

  /// 💡 新增：处理来自VideoInfo的全局菜单操作 (用于修复报错)
  void _onGlobalMenuActionFromVideoInfo(
      VideoInfo videoInfo, VideoMenuAction action) {
    // 将VideoInfo转换为PlayRecord用于统一处理
    final playRecord = PlayRecord(
      id: videoInfo.id,
      source: videoInfo.source,
      title: videoInfo.title,
      sourceName: videoInfo.sourceName,
      year: videoInfo.year,
      cover: videoInfo.cover,
      index: videoInfo.index,
      totalEpisodes: videoInfo.totalEpisodes,
      playTime: videoInfo.playTime,
      totalTime: videoInfo.totalTime,
      saveTime: videoInfo.saveTime,
      searchTitle: videoInfo.searchTitle,
    );
    _onGlobalMenuAction(playRecord, action);
  }

  /// 💡 新增：处理视频菜单具体逻辑 (用于修复报错)
  void _onGlobalMenuAction(PlayRecord playRecord, VideoMenuAction action) {
    switch (action) {
      case VideoMenuAction.play:
        // 跳转到新播放页
        _navigateToNewVideo(playRecord);
        break;
      case VideoMenuAction.favorite:
        _handleMenuFavorite(playRecord);
        break;
      case VideoMenuAction.unfavorite:
        _handleMenuUnfavorite(playRecord);
        break;
      case VideoMenuAction.deleteRecord:
        _handleMenuDeleteRecord(playRecord);
        break;
      case VideoMenuAction.doubanDetail:
      case VideoMenuAction.bangumiDetail:
        // 详情已在组件内部处理
        break;
    }
  }

  /// 辅助方法：跳转到新视频并替换当前页
  void _navigateToNewVideo(PlayRecord playRecord) {
    if (_videoPlayerController?.isPlaying == true) {
      _videoPlayerController?.pause();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          source: playRecord.source,
          id: playRecord.id,
          title: playRecord.title,
          year: playRecord.year,
        ),
      ),
    );
  }

  /// 辅助处理：菜单收藏
  void _handleMenuFavorite(PlayRecord playRecord) async {
    final favoriteData = {
      'cover': playRecord.cover,
      'save_time': DateTime.now().millisecondsSinceEpoch,
      'source_name': playRecord.sourceName,
      'title': playRecord.title,
      'total_episodes': playRecord.totalEpisodes,
      'year': playRecord.year,
    };
    final result = await PageCacheService()
        .addFavorite(playRecord.source, playRecord.id, favoriteData, context);
    if (result.success && mounted) {
      setState(() {}); // 刷新当前页显示状态
    }
  }

  /// 辅助处理：菜单取消收藏
  void _handleMenuUnfavorite(PlayRecord playRecord) async {
    final result = await PageCacheService()
        .removeFavorite(playRecord.source, playRecord.id, context);
    if (result.success && mounted) {
      setState(() {});
    }
  }

  /// 辅助处理：删除记录
  void _handleMenuDeleteRecord(PlayRecord playRecord) async {
    await PageCacheService()
        .deletePlayRecord(playRecord.source, playRecord.id, context);
    if (mounted) setState(() {});
  }

  /// 构建选集区域
  Widget _buildEpisodesSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    // 如果总集数只有一集，则不展示选集区域
    if (totalEpisodes <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 选集标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '选集',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),

              // 正序/倒序按钮
              _HoverButton(
                onTap: _toggleEpisodesOrder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _isEpisodesReversed ? '倒序' : '正序',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Transform.translate(
                      offset: const Offset(0, 3),
                      child: Icon(
                        _isEpisodesReversed
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 滚动到当前集数按钮
              Transform.translate(
                offset: const Offset(0, 3.5),
                child: _HoverButton(
                  onTap: _scrollToCurrentEpisode,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 21,
                        color:
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 展开按钮
              _wrapCompactActionTapTarget(
                context,
                onTap: _showEpisodesPanel,
                width: 50,
                alignment: Alignment.centerLeft,
                _HoverButton(
                  onTap: _showEpisodesPanel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 0),
                        child: Text(
                          '展开',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // 集数卡片横向滚动区域
        LayoutBuilder(
          builder: (context, constraints) {
            // 计算按钮宽度：根据设备类型调整
            final screenWidth = constraints.maxWidth;
            final horizontalPadding = 32.0; // 左右各16
            final availableWidth = screenWidth - horizontalPadding;
            final cardsPerView = _isTablet ? 6.2 : 3.2;
            final rawButtonWidth =
                (availableWidth / cardsPerView) - 6; // 减去右边距6
            final buttonWidth =
                rawButtonWidth.clamp(110.0, _maxEpisodeCardWidth).toDouble();
            final buttonHeight = buttonWidth * 1.8 / 3; // 稍微减少高度

            return SizedBox(
              height: buttonHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MouseRegion(
                  onEnter: (_) {
                    if (DeviceUtils.isPC()) {
                      setState(() => _isHoveringEpisodesPager = true);
                    }
                  },
                  onExit: (_) {
                    if (DeviceUtils.isPC()) {
                      setState(() => _isHoveringEpisodesPager = false);
                    }
                  },
                  child: Stack(
                    children: [
                      ListView.builder(
                        // 💡 关键：使用 Key 强制在方向或顺序变化时重建列表，解决位置错乱问题
                        key: ValueKey(
                            'episodes_list_${MediaQuery.of(context).orientation}_$_isEpisodesReversed'),
                        controller: _episodesScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: currentDetail!.episodes.length,
                        itemBuilder: (context, index) {
                          final episodeIndex = _isEpisodesReversed
                              ? currentDetail!.episodes.length - 1 - index
                              : index;
                          final isCurrentEpisode =
                              episodeIndex == currentEpisodeIndex;

                          // 获取集数名称，如果episodesTitles为空或长度不够，则使用默认格式
                          String episodeTitle = '';
                          if (currentDetail!.episodesTitles.isNotEmpty &&
                              episodeIndex <
                                  currentDetail!.episodesTitles.length) {
                            episodeTitle =
                                currentDetail!.episodesTitles[episodeIndex];
                          } else {
                            episodeTitle = '第${episodeIndex + 1}集';
                          }

                          final episodeCardKey = _episodeCardKeys.putIfAbsent(
                            episodeIndex,
                            () => GlobalKey(),
                          );

                          return Container(
                            key: episodeCardKey,
                            width: buttonWidth,
                            margin: const EdgeInsets.only(right: 6),
                            child: AspectRatio(
                              aspectRatio: 3 / 2, // 严格保持3:2宽高比
                              child: _EpisodeCardWithHover(
                                isCurrentEpisode: isCurrentEpisode,
                                isDarkMode: isDarkMode,
                                episodeIndex: episodeIndex,
                                episodeTitle: episodeTitle,
                                onTap: isCurrentEpisode
                                    ? null
                                    : () {
                                        // 显示切换加载蒙版
                                        setState(() {
                                          _showSwitchLoadingOverlay = true;
                                          _switchLoadingMessage = '切换选集...';
                                        });

                                        // 集数切换前保存进度
                                        _saveProgress(
                                            force: true, scene: '选集列表点击');

                                        startPlay(episodeIndex, 0);
                                      },
                              ),
                            ),
                          );
                        },
                      ),
                      if (DeviceUtils.isPC() &&
                          _isHoveringEpisodesPager &&
                          _episodesScrollController.hasClients &&
                          _episodesScrollController.position.maxScrollExtent >
                              0)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildPagerButton(
                                  isLeft: true,
                                  isDarkMode: isDarkMode,
                                  onTap: () => _pageScrollHorizontal(
                                      _episodesScrollController, false),
                                ),
                                _buildPagerButton(
                                  isLeft: false,
                                  isDarkMode: isDarkMode,
                                  onTap: () => _pageScrollHorizontal(
                                      _episodesScrollController, true),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 构建选集底部滑出面板
  void _showEpisodesPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 作为最大列数提示，实际列数在面板内部会根据标题长度和面板宽度自适应。
    final crossAxisCount = _isPortraitTablet ? 5 : 4;

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: context,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            alignment: alignment,
            slideBegin: slideBegin,
            animation: animation,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return PlayerEpisodesPanel(
                  theme: theme,
                  episodes: currentDetail!.episodes,
                  episodesTitles: currentDetail!.episodesTitles,
                  currentEpisodeIndex: currentEpisodeIndex,
                  isReversed: _isEpisodesReversed,
                  crossAxisCount: crossAxisCount,
                  backgroundOpacity: 1.0,
                  isCompact: true, // 横屏使用紧凑模式
                  onEpisodeTap: (index) {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      this.setState(() {
                        _showSwitchLoadingOverlay = true;
                        _switchLoadingMessage = '切换选集...';
                      });
                    });
                    _saveProgress(force: true, scene: '选集面板点击');
                    startPlay(index, 0);
                  },
                  onToggleOrder: () {
                    setState(() {
                      _isEpisodesReversed = !_isEpisodesReversed;
                    });
                    // this.setState(() {
                    //   _isEpisodesReversed = !_isEpisodesReversed;
                    // });
                    // setState(() {}); // 同步弹窗内部状态
                  },
                );
              },
            ),
          );
        },
      );
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerEpisodesPanel(
                theme: theme,
                episodes: currentDetail!.episodes,
                episodesTitles: currentDetail!.episodesTitles,
                currentEpisodeIndex: currentEpisodeIndex,
                isReversed: _isEpisodesReversed,
                crossAxisCount: crossAxisCount,
                backgroundOpacity: 1.0, // 竖屏不透明
                isCompact: false, // 竖屏宽松模式
                onEpisodeTap: (index) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    this.setState(() {
                      _showSwitchLoadingOverlay = true;
                      _switchLoadingMessage = '切换选集...';
                    });
                  });
                  _saveProgress(force: true, scene: '选集面板点击');
                  startPlay(index, 0);
                },
                onToggleOrder: () {
                  setState(() {
                    _isEpisodesReversed = !_isEpisodesReversed;
                  });
                  // this.setState(() {
                  //   _isEpisodesReversed = !_isEpisodesReversed;
                  // });
                  // setState(() {}); // 同步弹窗内部状态
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 构建详情底部滑出面板
  void _showDetailsPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: context,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            alignment: alignment,
            slideBegin: slideBegin,
            animation: animation,
            child: PlayerDetailsPanel(
              theme: theme,
              doubanDetails: doubanDetails,
              currentDetail: currentDetail,
            ),
          );
        },
      );
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerDetailsPanel(
                theme: theme,
                doubanDetails: doubanDetails,
                currentDetail: currentDetail,
              ),
            );
          },
        );
      },
    );
  }

  /// 构建换源区域
  Widget _buildSourcesSection(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 换源标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '换源',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),

              // 刷新按钮
              Transform.translate(
                offset: const Offset(0, 4),
                child: _HoverButton(
                  onTap: _isRefreshing ? null : _refreshSourcesSpeed,
                  enabled: !_isRefreshing,
                  child: RotationTransition(
                    turns: _refreshAnimationController,
                    child: Icon(
                      Icons.refresh,
                      size: 22,
                      color: _isRefreshing
                          ? Colors.green
                          : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 滚动到当前源按钮
              Transform.translate(
                offset: const Offset(0, 3.5),
                child: _HoverButton(
                  onTap: _scrollToCurrentSource,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 21,
                        color:
                            isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 展开按钮
              _wrapCompactActionTapTarget(
                context,
                onTap: _showSourcesPanel,
                width: 50,
                alignment: Alignment.centerLeft,
                _HoverButton(
                  onTap: _showSourcesPanel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 0),
                        child: Text(
                          '展开',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // 源卡片横向滚动区域
        _buildSourcesHorizontalScroll(theme),
      ],
    );
  }

  /// 构建源卡片横向滚动区域
  Widget _buildSourcesHorizontalScroll(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算卡片宽度：根据设备类型调整
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = 32.0; // 左右各16
        final availableWidth = screenWidth - horizontalPadding;
        final cardsPerView = _isTablet ? 6.2 : 3.2;
        final rawCardWidth = (availableWidth / cardsPerView) - 6; // 减去右边距6
        final cardWidth =
            rawCardWidth.clamp(110.0, _maxSourceCardWidth).toDouble();
        final cardHeight = cardWidth * 1.8 / 3; // 稍微减少高度

        return SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MouseRegion(
              onEnter: (_) {
                if (DeviceUtils.isPC()) {
                  setState(() => _isHoveringSourcesPager = true);
                }
              },
              onExit: (_) {
                if (DeviceUtils.isPC()) {
                  setState(() => _isHoveringSourcesPager = false);
                }
              },
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _sourcesScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: allSources.length,
                    itemBuilder: (context, index) {
                      final source = allSources[index];
                      final isCurrentSource = source.source == currentSource &&
                          source.id == currentID;
                      final sourceKey = '${source.source}_${source.id}';
                      final speedInfo = allSourcesSpeed[sourceKey];

                      return Container(
                        width: cardWidth,
                        margin: const EdgeInsets.only(right: 6),
                        child: AspectRatio(
                          aspectRatio: 3 / 2, // 严格保持3:2宽高比
                          child: _SourceCardWithHover(
                            isCurrentSource: isCurrentSource,
                            isDarkMode: isDarkMode,
                            source: source,
                            speedInfo: speedInfo,
                            onTap: isCurrentSource
                                ? null
                                : () => _switchSource(source),
                          ),
                        ),
                      );
                    },
                  ),
                  if (DeviceUtils.isPC() &&
                      _isHoveringSourcesPager &&
                      _sourcesScrollController.hasClients &&
                      _sourcesScrollController.position.maxScrollExtent > 0)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPagerButton(
                              isLeft: true,
                              isDarkMode: isDarkMode,
                              onTap: () => _pageScrollHorizontal(
                                  _sourcesScrollController, false),
                            ),
                            _buildPagerButton(
                              isLeft: false,
                              isDarkMode: isDarkMode,
                              onTap: () => _pageScrollHorizontal(
                                  _sourcesScrollController, true),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _getPcRightPanelTopInset(Alignment alignment) {
    if (!Platform.isWindows) return 0;
    if (alignment != Alignment.centerRight) return 0;
    return 40;
  }

  Widget _buildSidePanel({
    required BuildContext context,
    required double panelWidth,
    required double panelHeight,
    required Alignment alignment,
    required Offset slideBegin,
    required Animation<double> animation,
    required Widget child,
  }) {
    final topInset = _getPcRightPanelTopInset(alignment);
    final effectiveHeight = math.max(0, panelHeight - topInset);
    final effectiveAlignment = topInset > 0 ? Alignment.topRight : alignment;

    return Align(
      alignment: effectiveAlignment,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: panelWidth,
            height: effectiveHeight.toDouble(),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: slideBegin,
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Rect? _getPlayerGlobalRect() {
    final ctx = _videoPlayerWidgetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _pageScrollHorizontal(ScrollController controller, bool forward) {
    if (!controller.hasClients) return;

    final position = controller.position;
    final page = position.viewportDimension * 0.9;
    final target = (position.pixels + (forward ? page : -page))
        .clamp(0.0, position.maxScrollExtent);

    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Widget _buildPagerButton({
    required bool isLeft,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    final bgColor = isDarkMode
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.9);
    final borderColor = isDarkMode ? Colors.white24 : Colors.black12;
    final iconColor = isDarkMode ? Colors.white : Colors.black87;

    return MouseRegion(
      cursor: DeviceUtils.isPC() ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            isLeft ? Icons.chevron_left : Icons.chevron_right,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  /// 构建换源列表
  void _showSourcesPanel() {
    // 如果是本地播放，不显示换源面板
    if (_isOfflinePlayback) return;

    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 平板模式：使用 showGeneralDialog
    if (_isTablet) {
      final panelWidth = _isPortraitTablet ? screenWidth : screenWidth * 0.35;
      final panelHeight = _isPortraitTablet
          ? (screenHeight - statusBarHeight) * 0.5
          : screenHeight;
      final alignment =
          _isPortraitTablet ? Alignment.bottomCenter : Alignment.centerRight;
      final slideBegin =
          _isPortraitTablet ? const Offset(0, 1) : const Offset(1, 0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: context,
            panelWidth: panelWidth,
            panelHeight: panelHeight,
            alignment: alignment,
            slideBegin: slideBegin,
            animation: animation,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return PlayerSourcesPanel(
                  theme: theme,
                  sources: allSources,
                  currentSource: currentSource,
                  currentId: currentID,
                  sourcesSpeed: allSourcesSpeed,
                  backgroundOpacity: 1.0,
                  isCompact: true, // 横屏紧凑模式
                  onSourceTap: (source) {
                    this.setState(() {
                      _switchSource(source);
                    });
                    Navigator.pop(context);
                  },
                  onRefresh: () async {
                    await _refreshSourcesSpeed(setState);
                  },
                  videoCover: videoCover,
                  videoTitle: videoTitle,
                );
              },
            ),
          );
        },
      ).then((_) {
        setState(() {});
      });
      return;
    }

    // 手机模式：从底部弹出
    final playerHeight = screenWidth / (16 / 9);
    final panelHeight = screenHeight - statusBarHeight - playerHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              height: panelHeight,
              width: double.infinity,
              child: PlayerSourcesPanel(
                theme: theme,
                sources: allSources,
                currentSource: currentSource,
                currentId: currentID,
                sourcesSpeed: allSourcesSpeed,
                backgroundOpacity: 1.0, // 竖屏不透明
                isCompact: false, // 竖屏宽松模式
                onSourceTap: (source) {
                  this.setState(() {
                    _switchSource(source);
                  });
                  Navigator.pop(context);
                },
                onRefresh: () async {
                  await _refreshSourcesSpeed(setState);
                },
                videoCover: videoCover,
                videoTitle: videoTitle,
              ),
            );
          },
        );
      },
    ).then((_) {
      // 面板关闭后强制更新主界面的源卡片显示
      // 这样测速信息就能立即显示在主界面的源卡片上
      setState(() {});
    });
  }

  /// 在全屏模式下显示换源面板（使用传入的 context）
  void _showSourcesPanelInFullscreen(BuildContext fullscreenContext) {
    final theme = Theme.of(fullscreenContext);
    final screenHeight = MediaQuery.of(fullscreenContext).size.height;
    final screenWidth = MediaQuery.of(fullscreenContext).size.width;

    // 全屏模式下从右侧滑入
    final panelWidth = screenWidth * 0.4;
    final panelHeight = screenHeight;

    showGeneralDialog(
      context: fullscreenContext,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _buildSidePanel(
          context: dialogContext,
          panelWidth: panelWidth,
          panelHeight: panelHeight,
          alignment: Alignment.centerRight,
          slideBegin: const Offset(1, 0),
          animation: animation,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return PlayerSourcesPanel(
                theme: theme,
                sources: allSources,
                currentSource: currentSource,
                currentId: currentID,
                sourcesSpeed: allSourcesSpeed,
                onSourceTap: (source) {
                  setState(() {
                    _switchSource(source);
                  });
                  Navigator.pop(dialogContext);
                },
                onRefresh: () async {
                  await _refreshSourcesSpeed(dialogSetState);
                },
                videoCover: videoCover,
                videoTitle: videoTitle,
              );
            },
          ),
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  /// 手动加载指定 episodeId 的弹幕
  Future<String> _resolveInitialDanmakuMatchQuery() async {
    if (currentSource.isNotEmpty && currentID.isNotEmpty) {
      final query = await DanmakuService().getManualMatchQuery(
        currentSource,
        currentID,
        _getDanmakuMatchEpisodeIndex(),
      );
      if (query != null && query.isNotEmpty) {
        return query;
      }
    }
    return videoTitle;
  }

  Future<void> _cacheManualDanmakuSearchQuery(String query) async {
    if (currentSource.isEmpty || currentID.isEmpty) {
      return;
    }

    await DanmakuService().saveManualMatchQuery(
      currentSource,
      currentID,
      _getDanmakuMatchEpisodeIndex(),
      query,
    );
  }

  Future<void> _loadDanmakuById(int episodeId, {String? searchKeyword}) async {
    setState(() => _isDanmakuLoading = true);
    try {
      final comments = await DanmakuService().getDanmakuList(episodeId);
      if (mounted) {
        setState(() {
          _danmakuList = comments;
          _danmakuIndex = 0;
          _currentDanmakuEpisodeId = episodeId;
          _isDanmakuLoading = false;
        });
        _runWithDanmakuController(
          'clear_manual_load',
          (controller) => controller.clear(),
        );

        // 保存手动匹配关系
        if (currentSource.isNotEmpty && currentID.isNotEmpty) {
          final danmakuMatchEpisodeIndex = _getDanmakuMatchEpisodeIndex();
          await DanmakuService().saveManualMatch(
            currentSource,
            currentID,
            danmakuMatchEpisodeIndex,
            episodeId,
            searchKeyword: searchKeyword,
          );
        }

        if (comments.isEmpty) {
          _showToast('手动匹配成功，但该剧集暂无弹幕');
        } else {
          _showToast('已加载 ${comments.length} 条弹幕');
        }
        debugPrint('手动加载弹幕成功: ${comments.length} 条');
      }
    } catch (e) {
      debugPrint('手动加载弹幕失败: $e');
      if (mounted) {
        setState(() => _isDanmakuLoading = false);
      }
    }
  }

  /// 在全屏模式下显示弹幕匹配面板（使用传入的 context）
  Future<void> _showDanmakuMatchPanelInFullscreen(
      BuildContext fullscreenContext) async {
    final theme = Theme.of(fullscreenContext);
    final screenHeight = MediaQuery.of(fullscreenContext).size.height;
    final screenWidth = MediaQuery.of(fullscreenContext).size.width;
    final isPortrait =
        MediaQuery.of(fullscreenContext).orientation == Orientation.portrait;
    final initialQuery = await _resolveInitialDanmakuMatchQuery();
    if (!mounted) return;

    if (isPortrait) {
      // 💡 竖屏/短剧模式：从底部弹出
      showModalBottomSheet(
        context: fullscreenContext,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: false, // 💡 顶到两边
        builder: (context) {
          return Container(
            margin: EdgeInsets.zero,
            height: screenHeight * 0.7,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DanmakuMatchPanel(
              theme: theme,
              initialQuery: initialQuery,
              currentEpisodeId: _currentDanmakuEpisodeId,
              currentEpisodeCommentCount: _currentDanmakuCommentCount,
              onSearchSubmitted: _cacheManualDanmakuSearchQuery,
              onEpisodeSelected: (episodeId, searchKeyword) {
                Navigator.pop(context);
                _loadDanmakuById(episodeId, searchKeyword: searchKeyword);
              },
            ),
          );
        },
      );
    } else {
      // 横屏模式：PC 端使用小弹框，其余保持右侧滑动弹出
      if (DeviceUtils.isPC()) {
        final topInset = Platform.isWindows ? 40.0 : 0.0;
        final availableHeight = screenHeight - topInset;
        final panelHeight = math.min(availableHeight * 0.6, 620.0);
        final panelWidth = math.min(screenWidth * 0.6, 560.0);

        setState(() => _forcePcControlsVisible = true);
        showGeneralDialog(
          context: fullscreenContext,
          barrierDismissible: true,
          barrierLabel: '',
          barrierColor: Colors.black.withValues(alpha: 0.35),
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (dialogContext, animation, secondaryAnimation) {
            return Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Center(
                child: SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: DanmakuMatchPanel(
                    theme: theme,
                    initialQuery: initialQuery,
                    currentEpisodeId: _currentDanmakuEpisodeId,
                    currentEpisodeCommentCount: _currentDanmakuCommentCount,
                    onSearchSubmitted: _cacheManualDanmakuSearchQuery,
                    onEpisodeSelected: (episodeId, searchKeyword) {
                      Navigator.pop(dialogContext);
                      _loadDanmakuById(
                        episodeId,
                        searchKeyword: searchKeyword,
                      );
                    },
                    borderRadiusOverride: BorderRadius.circular(10),
                  ),
                ),
              ),
            );
          },
        ).whenComplete(() {
          if (mounted) {
            setState(() => _forcePcControlsVisible = false);
          }
        });
        return;
      }

      // 其他横屏模式：保持右侧滑动弹出
      final panelWidth = screenWidth * 0.4;
      showGeneralDialog(
        context: fullscreenContext,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: dialogContext,
            panelWidth: panelWidth,
            panelHeight: screenHeight,
            alignment: Alignment.centerRight,
            slideBegin: const Offset(1, 0),
            animation: animation,
            child: DanmakuMatchPanel(
              theme: theme,
              initialQuery: initialQuery,
              currentEpisodeId: _currentDanmakuEpisodeId,
              currentEpisodeCommentCount: _currentDanmakuCommentCount,
              onSearchSubmitted: _cacheManualDanmakuSearchQuery,
              onEpisodeSelected: (episodeId, searchKeyword) {
                Navigator.pop(dialogContext);
                _loadDanmakuById(episodeId, searchKeyword: searchKeyword);
              },
            ),
          );
        },
      );
    }
  }

  /// 显示下载面板
  void _showDownloadPanel() {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // 统一使用全屏侧边面板的宽度逻辑 (40% 屏幕宽度)
    final panelWidth = screenWidth * 0.4;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 如果是平板或横屏，使用侧边滑出逻辑
    if (_isTablet ||
        MediaQuery.of(context).orientation == Orientation.landscape) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          final alignment = (_isTablet && _isPortraitTablet)
              ? Alignment.bottomCenter
              : Alignment.centerRight;
          final panelHeight = (_isTablet && _isPortraitTablet)
              ? (screenHeight - statusBarHeight) * 0.5
              : screenHeight;
          final slideBegin = (_isTablet && _isPortraitTablet)
              ? const Offset(0, 1)
              : const Offset(1, 0);

          return _buildSidePanel(
            context: context,
            panelWidth:
                (_isTablet && _isPortraitTablet) ? screenWidth : panelWidth,
            panelHeight: panelHeight,
            alignment: alignment,
            slideBegin: slideBegin,
            animation: animation,
            child: PlayerDownloadPanel(
              theme: theme,
              title: videoTitle,
              cover: videoCover,
              episodes: currentDetail!.episodes,
              episodesTitles: currentDetail!.episodesTitles,
              currentEpisodeIndex: currentEpisodeIndex, // 💡 传给面板
              isCompact: true,
            ),
          );
        },
      );
    } else {
      // 手机竖屏模式：从底部弹出，高度与选集面板一致
      final playerHeight = screenWidth / (16 / 9);
      final panelHeight = screenHeight - statusBarHeight - playerHeight;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        enableDrag: false,
        builder: (context) {
          return SizedBox(
            height: panelHeight,
            width: double.infinity,
            child: PlayerDownloadPanel(
              theme: theme,
              title: videoTitle,
              cover: videoCover,
              episodes: currentDetail!.episodes,
              episodesTitles: currentDetail!.episodesTitles,
              currentEpisodeIndex: currentEpisodeIndex, // 💡 传给面板
              isCompact: false,
            ),
          );
        },
      );
    }
  }

  /// 在全屏模式下显示设置面板（使用传入的 context）
  void _showSettingsPanelInFullscreen(BuildContext fullscreenContext) {
    final theme = Theme.of(fullscreenContext);
    final screenHeight = MediaQuery.of(fullscreenContext).size.height;
    final screenWidth = MediaQuery.of(fullscreenContext).size.width;
    final useSolidBackground = !DeviceUtils.isPC() &&
        !_isFullscreen &&
        !_isWebFullscreen &&
        !_isEnteringLandscapeFullscreen;

    final panelWidth = screenWidth * 0.4;
    final panelHeight = screenHeight;

    showGeneralDialog(
      context: fullscreenContext,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: useSolidBackground
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _buildSidePanel(
          context: dialogContext,
          panelWidth: panelWidth,
          panelHeight: panelHeight,
          alignment: Alignment.centerRight,
          slideBegin: const Offset(1, 0),
          animation: animation,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return PlayerSettingsPanel(
                theme: theme,
                backgroundOpacity: useSolidBackground ? 1.0 : null,
                currentFitType: _currentFitType,
                currentLongPressSpeed: _longPressSpeed,
                progressMode: _progressMode,
                showSystemTime: _showSystemTime,
                hideCenterControlsWithBars: _hideCenterControlsWithBars,
                skipIntro: _skipIntroDuration,
                skipOutro: _skipOutroDuration,
                videoPosition: currentPosition?.inSeconds ?? 0,
                videoDuration: duration?.inSeconds ?? 0,
                onFitTypeChanged: (type) {
                  setState(() => _currentFitType = type);
                  dialogSetState(() {});
                  _videoPlayerController?.setVideoFit(type);
                  UserDataService.saveVideoFitType(type.index);
                },
                onLongPressSpeedChanged: (speed) {
                  setState(() => _longPressSpeed = speed);
                  dialogSetState(() {});
                  UserDataService.saveLongPressSpeed(speed);
                },
                onProgressModeChanged: (mode) {
                  setState(() => _progressMode = mode);
                  dialogSetState(() {});
                  UserDataService.saveProgressDisplayMode(mode.index);
                },
                onShowSystemTimeChanged: (show) {
                  setState(() => _showSystemTime = show);
                  dialogSetState(() {});
                  UserDataService.saveShowSystemTime(show);
                },
                onHideCenterControlsWithBarsChanged: (hide) {
                  setState(() => _hideCenterControlsWithBars = hide);
                  dialogSetState(() {});
                  UserDataService.saveHideCenterControlsWithBars(hide);
                },
                onSkipIntroChanged: (v) {
                  setState(() => _skipIntroDuration = v);
                  dialogSetState(() {});
                  // 仅保存针对当前视频的特定设置，不修改全局默认设置
                  UserDataService.saveVideoSkipSettings(
                      videoTitle, videoYear, v, _skipOutroDuration);
                },
                onSkipOutroChanged: (v) {
                  setState(() => _skipOutroDuration = v);
                  dialogSetState(() {});
                  // 仅保存针对当前视频的特定设置，不修改全局默认设置
                  UserDataService.saveVideoSkipSettings(
                      videoTitle, videoYear, _skipIntroDuration, v);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// 在全屏模式下显示弹幕设置面板（使用传入的 context）
  void _showDanmakuPanelInFullscreen(BuildContext fullscreenContext) {
    final theme = Theme.of(fullscreenContext);
    final screenHeight = MediaQuery.of(fullscreenContext).size.height;
    final screenWidth = MediaQuery.of(fullscreenContext).size.width;
    final isPortrait =
        MediaQuery.of(fullscreenContext).orientation == Orientation.portrait;

    if (isPortrait) {
      // 💡 短剧/竖屏模式：从底部弹出
      showModalBottomSheet(
        context: fullscreenContext,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: false, // 💡 禁用安全区域以确保顶到两边
        builder: (context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor, // 💡 确保背景色正确
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)), // 💡 添加一致的顶部圆角
            ),
            margin: EdgeInsets.zero,
            height: screenHeight * 0.6,
            width: double.infinity,
            clipBehavior: Clip.antiAlias, // 💡 确保子元素不超出圆角
            child: DanmakuSettingsPanel(
              theme: theme,
              settings: _danmakuSettings,
              onSettingsChanged: (settings) {
                _applyDanmakuSettings(settings);
                dialogSetState(() {});
              },
            ),
          );
        }),
      );
    } else {
      // 横屏模式：保持右侧滑动弹出
      final panelWidth = screenWidth * 0.4;
      showGeneralDialog(
        context: fullscreenContext,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withValues(alpha: 0.3),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return _buildSidePanel(
            context: dialogContext,
            panelWidth: panelWidth,
            panelHeight: screenHeight,
            alignment: Alignment.centerRight,
            slideBegin: const Offset(1, 0),
            animation: animation,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter dialogSetState) {
                return DanmakuSettingsPanel(
                  theme: theme,
                  settings: _danmakuSettings,
                  onSettingsChanged: (settings) {
                    _applyDanmakuSettings(settings);
                    dialogSetState(() {});
                  },
                );
              },
            ),
          );
        },
      );
    }
  }

  /// 在全屏模式下显示选集面板（使用传入的 context）
  void _showEpisodesPanelInFullscreen(BuildContext fullscreenContext) {
    if (currentDetail == null) return;

    final theme = Theme.of(fullscreenContext);
    final screenHeight = MediaQuery.of(fullscreenContext).size.height;
    final screenWidth = MediaQuery.of(fullscreenContext).size.width;

    // 全屏模式下从右侧滑入
    final panelWidth = screenWidth * 0.4;
    final panelHeight = screenHeight;

    showGeneralDialog(
      context: fullscreenContext,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _buildSidePanel(
          context: dialogContext,
          panelWidth: panelWidth,
          panelHeight: panelHeight,
          alignment: Alignment.centerRight,
          slideBegin: const Offset(1, 0),
          animation: animation,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter dialogSetState) {
              return PlayerEpisodesPanel(
                theme: theme,
                episodes: currentDetail!.episodes,
                episodesTitles: currentDetail!.episodesTitles,
                currentEpisodeIndex: currentEpisodeIndex,
                isReversed: _isEpisodesReversed,
                crossAxisCount: 4,
                onEpisodeTap: (index) {
                  Navigator.pop(dialogContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _showSwitchLoadingOverlay = true;
                      _switchLoadingMessage = '切换选集...';
                    });
                  });
                  _saveProgress(force: true, scene: '选集面板点击');
                  startPlay(index, 0);
                },
                onToggleOrder: () {
                  dialogSetState(() {
                    _isEpisodesReversed = !_isEpisodesReversed;
                  });
                  // this.setState(() {
                  //   _isEpisodesReversed = !_isEpisodesReversed;
                  // });
                  // dialogSetState(() {}); // 同步弹窗内部状态
                },
              );
            },
          ),
        );
      },
    ).then((_) {
      setState(() {});
    });
  }

  /// 刷新所有源的测速结果
  Future<void> _refreshSourcesSpeed([StateSetter? stateSetter]) async {
    if (allSources.isEmpty) return;

    final aSetState = stateSetter ?? setState;

    // 如果是从外部调用（非面板），设置刷新状态
    if (stateSetter == null) {
      setState(() {
        _isRefreshing = true;
      });
      _refreshAnimationController.repeat();
    }

    try {
      // 清空之前的测速结果
      allSourcesSpeed.clear();

      // 立即更新UI显示，让用户看到测速信息被清空
      aSetState(() {});

      // 使用新的实时测速方法
      final m3u8Service = M3U8Service();
      await m3u8Service.testSourcesWithCallback(
        allSources,
        (String sourceId, Map<String, dynamic> speedData) {
          // 每个源测速完成后立即更新
          allSourcesSpeed[sourceId] = SourceSpeed(
            quality: speedData['quality'] as String,
            loadSpeed: speedData['loadSpeed'] as String,
            pingTime: speedData['pingTime'] as String,
          );

          // 立即更新UI显示
          aSetState(() {});
        },
        timeout: const Duration(seconds: 10), // 自定义超时时间
      );
    } catch (e) {
      // 静默处理错误
    } finally {
      // 如果是从外部调用（非面板），停止刷新状态
      if (stateSetter == null) {
        setState(() {
          _isRefreshing = false;
        });
        _refreshAnimationController.stop();
        _refreshAnimationController.reset();
      }
    }
  }

  /// 构建错误覆盖层
  Widget _buildErrorOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFe6f3fb),
                  Color(0xFFeaf3f7),
                  Color(0xFFf7f7f3),
                  Color(0xFFe9ecef),
                  Color(0xFFdbe3ea),
                  Color(0xFFd3dde6),
                ],
                stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
              ),
        color: isDarkMode ? Colors.black : null,
      ),
      child: Stack(
        children: [
          // 装饰性圆点
          Positioned(
            top: 100,
            left: 40,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 50,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 错误图标
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF8C42), Color(0xFFE74C3C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '😵',
                      style: TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 错误标题
                Text(
                  '哎呀, 出现了一些问题',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // 错误信息框
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B4513).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // 提示文字
                Text(
                  '请检查网络连接或尝试刷新页面',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // 按钮组
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // 返回按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            hideError();
                            _onBackPressed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Text(
                            '返回上页',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 重试按钮
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            hideError();
                            initVideoData(isInit: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFE2E8F0),
                            foregroundColor: isDarkMode
                                ? Colors.white
                                : const Color(0xFF3182CE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: Text(
                            '重新尝试',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF3182CE),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索视频源数据（带过滤）
  Future<List<SearchResult>> fetchSourcesData(String query,
      {void Function(List<SearchResult>)? onIncrementalResults,
      bool allowEarlyReturn = true}) async {
    // 检查是否启用本地搜索
    final isLocalSearch = await UserDataService.getLocalSearch();
    final isLocalMode = await UserDataService.getIsLocalMode();

    List<SearchResult> results;
    if (isLocalSearch || isLocalMode) {
      // 使用本地搜索
      results = await SearchService.searchSync(query);
    } else {
      // 使用服务器搜索
      results = await ApiService.fetchSourcesData(query,
          onIncrementalResults: (incrementalResults) {
        if (onIncrementalResults != null) {
          final filtered = _filterSearchResults(incrementalResults);
          onIncrementalResults(filtered);
        }
      },
          earlyReturnMatcher: _matchesSearchResult,
          allowEarlyReturn: allowEarlyReturn);
    }

    // 返回最终过滤后的全量结果
    return _filterSearchResults(results);
  }

  bool _matchesSearchResult(SearchResult result) {
    // 标题匹配检查
    final titleMatch = result.title.replaceAll(' ', '').toLowerCase() ==
        (videoTitle.replaceAll(' ', '').toLowerCase());

    // 年份匹配检查
    final yearMatch = videoYear.isEmpty ||
        videoYear == 'unknown' ||
        result.year.toLowerCase() == videoYear.toLowerCase();

    // 类型匹配检查
    bool typeMatch = true;
    if (widget.stype != null) {
      if (widget.stype == 'tv') {
        typeMatch = result.episodes.length > 1;
      } else if (widget.stype == 'movie') {
        typeMatch = result.episodes.length == 1;
      }
    }

    return titleMatch && typeMatch && yearMatch;
  }

  /// 提取的统一过滤逻辑
  List<SearchResult> _filterSearchResults(List<SearchResult> results) {
    return results.where(_matchesSearchResult).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 💡 关键修复：每次依赖变化时都更新平板竖屏状态，确保计算滚动位置时使用的是正确的布局参数
    _isPortraitTablet = DeviceUtils.isPortraitTablet(context);

    if (!_isInitialized) {
      // 缓存设备类型，避免分辨率变化时改变布局
      _isTablet = DeviceUtils.isTablet(context);
      // _isPortraitTablet = DeviceUtils.isPortraitTablet(context); // 移到外面

      // 设置屏幕方向（平板除外）
      // 如果是平板，不强制竖屏
      if (!_isTablet) {
        _setPortraitOrientation();
      }
      // 保存当前的系统UI样式
      final theme = Theme.of(context);
      final isDarkMode = theme.brightness == Brightness.dark;
      _originalStyle = SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
      );
      _isInitialized = true;

      // 初始化视频数据
      initVideoData();
    }

    // 💡 关键修复：当物理旋转屏幕导致布局变化时，自动定位当前集
    _scrollToCurrentEpisode();
  }

  @override
  void dispose() {
    // 从活跃实例列表中移除
    _instances.remove(this);
    _beginClosingDanmakuLifecycle('dispose');
    _setKeepScreenOn(false);
    _sleepTimer?.cancel();
    _danmakuSeekCompletionTimer?.cancel();
    // 保存进度
    _saveProgress(force: true, scene: '页面销毁');
    // 取消超时计时器
    _loadingTimeoutTimer?.cancel();
    // 移除视频进度监听器
    _removeVideoProgressListener();
    // 移除应用生命周期监听器
    WidgetsBinding.instance.removeObserver(this);
    // 恢复屏幕方向
    _restoreOrientation();
    // 恢复原始的系统UI样式
    SystemChrome.setSystemUIOverlayStyle(_originalStyle);
    // 销毁播放器
    _videoPlayerController?.dispose();
    // 释放滚动控制器
    _episodesScrollController.dispose();
    _sourcesScrollController.dispose();
    // 释放动画控制器
    _refreshAnimationController.dispose();
    _loadingAnimationController.dispose();
    _textAnimationController.dispose();
    _switchLoadingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: Platform.isIOS && !_isCasting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _onSystemGesturePop();
          return;
        }
        _onBackPressed();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor:
              isDarkMode ? Colors.black : theme.scaffoldBackgroundColor,
          systemNavigationBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false, // 💡 关键：防止键盘弹出时顶起或压缩背景视频
          body: Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFe6f3fb),
                        Color(0xFFeaf3f7),
                        Color(0xFFf7f7f3),
                        Color(0xFFe9ecef),
                        Color(0xFFdbe3ea),
                        Color(0xFFd3dde6),
                      ],
                      stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
                    ),
              color: isDarkMode ? theme.scaffoldBackgroundColor : null,
            ),
            child: Column(
              children: [
                // Windows 自定义标题栏
                if (Platform.isWindows) const WindowsTitleBar(),
                // 主要内容
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, stackConstraints) {
                      return Stack(
                        children: [
                          // Main content (without player).
                          if (!_isWebFullscreen &&
                              !_isFullscreen &&
                              !_isEnteringLandscapeFullscreen)
                            if (_isTablet && !_isPortraitTablet)
                              // Tablet landscape layout.
                              _buildTabletLandscapeLayout(
                                  theme, stackConstraints)
                            else if (_isPortraitTablet)
                              // Tablet portrait layout, player takes 50% height.
                              _buildPortraitTabletLayout(theme)
                            else
                              // Phone layout.
                              _buildPhoneLayout(theme),
                          // Player layer positioned over the content stack.
                          _buildPlayerLayer(theme, stackConstraints),
                          // Episode panel (slide in from right, phone landscape only).
                          if (!_isTablet)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              top: 0,
                              bottom: 0,
                              right: _isEpisodesPanelVisible ? 0 : -400,
                              width: 400,
                              child: PlayerEpisodesPanel(
                                theme: theme,
                                episodes: currentDetail?.episodes ?? [],
                                episodesTitles:
                                    currentDetail?.episodesTitles ?? [],
                                currentEpisodeIndex: currentEpisodeIndex,
                                isReversed: _isEpisodesReversed,
                                onEpisodeTap: (index) {
                                  setState(() {
                                    _isEpisodesPanelVisible = false;
                                  });
                                  _onEpisodeTap(index);
                                },
                                onToggleOrder: () {
                                  setState(() {
                                    _isEpisodesReversed = !_isEpisodesReversed;
                                  });
                                },
                                crossAxisCount: 4,
                              ),
                            ),
                          // Source panel (slide in from right, phone landscape only).
                          if (!_isTablet)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              top: 0,
                              bottom: 0,
                              right: _isSourcesPanelVisible ? 0 : -400,
                              width: 400,
                              child: PlayerSourcesPanel(
                                theme: theme,
                                sources: allSources,
                                currentSource: currentSource,
                                currentId: currentID,
                                sourcesSpeed: allSourcesSpeed,
                                onSourceTap: (source) {
                                  setState(() {
                                    _isSourcesPanelVisible = false;
                                  });
                                  _onSourceTap(source);
                                },
                                onRefresh: _refreshSources,
                                videoCover: videoCover,
                                videoTitle: videoTitle,
                              ),
                            ),
                          // Error overlay.
                          if (_showError && _errorMessage != null)
                            _buildErrorOverlay(theme),
                          // Loading overlay.
                          if (_isLoading) _buildLoadingOverlay(theme),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建播放器层（使用 Positioned 控制位置和大小）
  double _computeTabletLandscapePlayerHeight({
    required double stackWidth,
    required double stackHeight,
    required double topOffset,
  }) {
    final availableHeight = math.max(0.0, stackHeight - topOffset);
    final leftWidth = stackWidth * 0.65;
    final playerHeightByAspect = leftWidth / (16 / 9);
    const minDetailHeight = 220.0;
    final maxPlayerHeight = math.max(0.0, availableHeight - minDetailHeight);
    return maxPlayerHeight <= 0
        ? (availableHeight * 0.5)
        : math.min(playerHeightByAspect, maxPlayerHeight);
  }

  Widget _buildPlayerLayer(
    ThemeData theme,
    BoxConstraints? stackConstraints,
  ) {
    if (_isClosing) return const SizedBox.shrink();

    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    // 如果是真全屏模式，不预留状态栏高度
    final topOffset = (_isFullscreen || _isEnteringLandscapeFullscreen)
        ? 0.0
        : (statusBarHeight + macOSPadding);

    if (_isWebFullscreen) {
      // 网页全屏模式：播放器占据整个屏幕（保留顶部安全区域）
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: Column(
          children: [
            // 顶部安全区域
            Container(
              height: topOffset,
              color: Colors.black,
            ),
            // 播放器
            Expanded(
              child: Container(
                // key: _playerKey,
                color: Colors.black,
                child: _buildPlayerWidget(),
              ),
            ),
          ],
        ),
      );
    } else {
      // 非网页全屏模式：根据不同布局计算播放器位置
      if (_isFullscreen || _isEnteringLandscapeFullscreen) {
        return Positioned.fill(
          top: 0,
          child: Container(
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      }
      if (_isTablet && !_isPortraitTablet) {
        // 平板横屏模式：播放器在左侧65%区域
        final screenWidth =
            stackConstraints?.maxWidth ?? MediaQuery.of(context).size.width;
        final stackHeight =
            stackConstraints?.maxHeight ?? MediaQuery.of(context).size.height;
        final leftWidth = screenWidth * 0.65;
        final playerHeight = _computeTabletLandscapePlayerHeight(
          stackWidth: screenWidth,
          stackHeight: stackHeight,
          topOffset: topOffset,
        );

        return Positioned(
          top: topOffset,
          left: 0,
          width: leftWidth,
          height: playerHeight,
          child: Container(
            // key: _playerKey,
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      } else if (_isPortraitTablet) {
        // 平板竖屏模式：播放器占50%高度
        final screenHeight = MediaQuery.of(context).size.height;
        final playerHeight = (screenHeight - topOffset) * 0.5;

        return Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          height: playerHeight,
          child: Container(
            // key: _playerKey,
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      } else {
        // 手机模式
        // 💡 优化：全屏时直接 fill，避免依赖 MediaQuery 的高度计算延迟导致跳变
        if (_isFullscreen || _isEnteringLandscapeFullscreen) {
          return Positioned.fill(
            top: 0,
            child: Container(
              color: Colors.black,
              child: _buildPlayerWidget(),
            ),
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final playerHeight = screenWidth / (16 / 9);

        return Positioned(
          top: topOffset,
          left: 0,
          right: 0,
          height: playerHeight,
          child: Container(
            color: Colors.black,
            child: _buildPlayerWidget(),
          ),
        );
      }
    }
  }

  /// 构建手机模式布局（不包含播放器）
  Widget _buildPhoneLayout(ThemeData theme) {
    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final playerHeight = screenWidth / (16 / 9);

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: _macOSTopBarColor(theme),
        ),
        // 播放器占位空间
        SizedBox(height: playerHeight),
        Expanded(
          child: _buildVideoDetailSection(theme),
        ),
      ],
    );
  }

  /// 构建平板竖屏模式布局（不包含播放器）
  Widget _buildPortraitTabletLayout(ThemeData theme) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final playerHeight = (screenHeight - statusBarHeight - macOSPadding) * 0.5;

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: _macOSTopBarColor(theme),
        ),
        // 播放器占位空间
        SizedBox(height: playerHeight),
        Expanded(
          child: _buildVideoDetailSection(theme),
        ),
      ],
    );
  }

  /// 构建平板横屏模式布局（不包含播放器）
  Widget _buildTabletLandscapeLayout(
      ThemeData theme, BoxConstraints stackConstraints) {
    final statusBarHeight = MediaQuery.maybeOf(context)?.padding.top ?? 0;
    final macOSPadding = DeviceUtils.isMacOS() ? 32.0 : 0.0;
    final stackWidth =
        stackConstraints.maxWidth.isFinite ? stackConstraints.maxWidth : 0.0;
    final stackHeight =
        stackConstraints.maxHeight.isFinite ? stackConstraints.maxHeight : 0.0;
    final topOffset = statusBarHeight + macOSPadding;
    final playerHeight = _computeTabletLandscapePlayerHeight(
      stackWidth: stackWidth,
      stackHeight: stackHeight,
      topOffset: topOffset,
    );

    return Column(
      children: [
        Container(
          height: statusBarHeight + macOSPadding,
          color: _macOSTopBarColor(theme),
        ),
        Expanded(
          child: Row(
            children: [
              // Left side: player and detail (65%).
              Expanded(
                flex: 65,
                child: Column(
                  children: [
                    // Player placeholder area.
                    SizedBox(height: playerHeight),
                    Expanded(
                      child: _buildVideoDetailSection(theme),
                    ),
                  ],
                ),
              ),
              // Right side: detail panel (35%).
              Expanded(
                flex: 35,
                child: Container(
                  color: Colors.transparent,
                  child: PlayerDetailsPanel(
                    theme: theme,
                    doubanDetails: doubanDetails,
                    currentDetail: currentDetail,
                    showCloseButton: false,
                    showTitle: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建加载覆盖层
  Widget _buildLoadingOverlay(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;

    // macOS 下需要额外的顶部 padding 来避免与透明标题栏重叠
    final topPadding = DeviceUtils.isMacOS()
        ? MediaQuery.of(context).padding.top + 32
        : MediaQuery.of(context).padding.top + 8;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFe6f3fb),
                  Color(0xFFeaf3f7),
                  Color(0xFFf7f7f3),
                  Color(0xFFe9ecef),
                  Color(0xFFdbe3ea),
                  Color(0xFFd3dde6),
                ],
                stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
              ),
        color: isDarkMode ? Colors.black : null,
      ),
      child: Stack(
        children: [
          // PC 端左上角返回按钮
          if (DeviceUtils.isPC())
            Positioned(
              top: topPadding + 4,
              left: 16,
              child: _HoverBackButton(
                onTap: _onBackPressed,
                iconColor: isDarkMode
                    ? const Color(0xFFffffff)
                    : const Color(0xFF2c3e50),
              ),
            ),
          // 中心加载内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // 旋转的背景方块（半透明绿色）
                    RotationTransition(
                      turns: _loadingAnimationController,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ecc71).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // 中间的图标容器（减小尺寸，删除阴影）
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          _loadingEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // 进度条
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ecc71),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 加载文案
                AnimatedBuilder(
                  animation: _textAnimationController,
                  builder: (context, child) {
                    return Text(
                      _loadingMessage,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: (isDarkMode ? Colors.white70 : Colors.black54)
                            .withOpacity(
                          0.3 + (_textAnimationController.value * 0.7),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带 hover 效果的返回按钮（PC 端专用）
class _HoverBackButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color iconColor;

  const _HoverBackButton({
    required this.onTap,
    required this.iconColor,
  });

  @override
  State<_HoverBackButton> createState() => _HoverBackButtonState();
}

class _HoverBackButtonState extends State<_HoverBackButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: _isHovering
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.5),
                )
              : null,
          child: Icon(
            Icons.arrow_back,
            color: widget.iconColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的选集卡片（PC 端专用）
class _EpisodeCardWithHover extends StatefulWidget {
  final bool isCurrentEpisode;
  final bool isDarkMode;
  final int episodeIndex;
  final String episodeTitle;
  final VoidCallback? onTap;

  const _EpisodeCardWithHover({
    required this.isCurrentEpisode,
    required this.isDarkMode,
    required this.episodeIndex,
    required this.episodeTitle,
    this.onTap,
  });

  @override
  State<_EpisodeCardWithHover> createState() => _EpisodeCardWithHoverState();
}

class _EpisodeCardWithHoverState extends State<_EpisodeCardWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrentEpisode)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrentEpisode) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentEpisode
                ? Colors.green.withOpacity(0.1)
                : (widget.isDarkMode
                    ? (_isHovering
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08))
                    : Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isCurrentEpisode
                  ? Colors.green
                  : (widget.isDarkMode
                      ? Colors.white.withOpacity(0.15)
                      : const Color(0xFFE5E7EB)),
              width: widget.isCurrentEpisode ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              // 左上角集数
              Positioned(
                top: 4,
                left: 6,
                child: Text(
                  '${widget.episodeIndex + 1}',
                  style: TextStyle(
                    color: widget.isCurrentEpisode
                        ? Colors.green
                        : (widget.isDarkMode ? Colors.white70 : Colors.black45),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              // 中间集数名称
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Text(
                    widget.episodeTitle,
                    style: TextStyle(
                      color: widget.isCurrentEpisode
                          ? Colors.green
                          : (widget.isDarkMode ? Colors.white : Colors.black87),
                      fontSize: 14,
                      fontWeight: widget.isCurrentEpisode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的换源卡片（PC 端专用）
class _SourceCardWithHover extends StatefulWidget {
  final bool isCurrentSource;
  final bool isDarkMode;
  final SearchResult source;
  final SourceSpeed? speedInfo;
  final VoidCallback? onTap;

  const _SourceCardWithHover({
    required this.isCurrentSource,
    required this.isDarkMode,
    required this.source,
    this.speedInfo,
    this.onTap,
  });

  @override
  State<_SourceCardWithHover> createState() => _SourceCardWithHoverState();
}

class _SourceCardWithHoverState extends State<_SourceCardWithHover> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (DeviceUtils.isPC() && !widget.isCurrentSource)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (DeviceUtils.isPC() && !widget.isCurrentSource) {
          setState(() => _isHovering = true);
        }
      },
      onExit: (_) {
        if (DeviceUtils.isPC()) {
          setState(() => _isHovering = false);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentSource
                ? Colors.green.withOpacity(0.1)
                : (widget.isDarkMode
                    ? (_isHovering
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08))
                    : Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isCurrentSource
                  ? Colors.green
                  : (widget.isDarkMode
                      ? Colors.white.withOpacity(0.15)
                      : const Color(0xFFE5E7EB)),
              width: widget.isCurrentSource ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              // 右上角集数信息
              if (widget.source.episodes.length > 1)
                Positioned(
                  top: 4,
                  right: 6,
                  child: Text(
                    '${widget.source.episodes.length}集',
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[500]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

              // 中间源名称
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    widget.source.sourceName,
                    style: FontUtils.poppins(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode ? Colors.white : Colors.black87),
                      fontSize: 13,
                      fontWeight: widget.isCurrentSource
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 左下角分辨率信息
              if (widget.speedInfo != null &&
                  widget.speedInfo!.quality.toLowerCase() != '未知')
                Positioned(
                  bottom: 4,
                  left: 6,
                  child: Text(
                    widget.speedInfo!.quality,
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[500]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

              // 右下角速率信息
              if (widget.speedInfo != null &&
                  widget.speedInfo!.loadSpeed.isNotEmpty &&
                  !widget.speedInfo!.loadSpeed.toLowerCase().contains('超时'))
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: Text(
                    widget.speedInfo!.loadSpeed,
                    style: TextStyle(
                      color: widget.isCurrentSource
                          ? Colors.green
                          : (widget.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[500]),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 带 hover 效果的按钮组件（PC 端专用）
class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const _HoverButton({
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPC = DeviceUtils.isPC();

    return MouseRegion(
      cursor: (isPC && widget.enabled && widget.onTap != null)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: isPC ? (_) => setState(() => _isHovered = true) : null,
      onExit: isPC ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ColorFiltered(
            colorFilter: (isPC && _isHovered && widget.enabled)
                ? const ColorFilter.mode(
                    Colors.green,
                    BlendMode.modulate,
                  )
                : const ColorFilter.mode(
                    Colors.white,
                    BlendMode.modulate,
                  ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
