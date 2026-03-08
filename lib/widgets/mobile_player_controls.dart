import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dlna_device_dialog.dart';
import 'danmaku_control_icons.dart';
import 'player_settings_panel.dart';
import 'player_adapter.dart';

class MobilePlayerControls extends StatefulWidget {
  final PlayerAdapter player;
  final VideoState?
      state; // Now optional because we might not have media_kit VideoState
  final Function(bool) onControlsVisibilityChanged;
  final VoidCallback? onBackPressed;
  final Function(bool) onFullscreenChange;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPause;
  final String videoUrl;
  final bool isLastEpisode;
  final bool isLoadingVideo;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final String? videoYear;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final List<String>? episodesTitles;
  final String? sourceName;
  final bool isLocal;
  final VoidCallback? onExitFullScreen;
  final bool live;
  final ValueNotifier<double> playbackSpeedListenable;
  final Future<void> Function(double speed) onSetSpeed;
  final Future<void> Function() onEnterPipMode;
  final bool isPipMode;
  final void Function(BuildContext context)? onEpisodesButtonPressed;
  final void Function(BuildContext context)? onSourcesButtonPressed;
  final void Function(BuildContext context)? onSettingsButtonPressed;
  final void Function(BuildContext context)? onDanmakuButtonPressed;
  final void Function(BuildContext context)? onDanmakuMatchButtonPressed;
  final bool isDanmakuEnabled;
  final void Function(bool enabled)? onDanmakuToggle;
  final double longPressSpeed;
  final ProgressDisplayMode progressMode;
  final bool showSystemTime;

  const MobilePlayerControls({
    super.key,
    required this.player,
    this.state,
    required this.onControlsVisibilityChanged,
    this.onBackPressed,
    required this.onFullscreenChange,
    this.onNextEpisode,
    this.onPause,
    required this.videoUrl,
    this.isLastEpisode = false,
    this.isLoadingVideo = false,
    this.onCastStarted,
    this.videoTitle,
    this.videoYear,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.episodesTitles,
    this.sourceName,
    this.isLocal = false,
    this.onExitFullScreen,
    this.live = false,
    required this.playbackSpeedListenable,
    required this.onSetSpeed,
    required this.onEnterPipMode,
    required this.isPipMode,
    this.onEpisodesButtonPressed,
    this.onSourcesButtonPressed,
    this.onSettingsButtonPressed,
    this.onDanmakuButtonPressed,
    this.onDanmakuMatchButtonPressed,
    this.isDanmakuEnabled = false,
    this.onDanmakuToggle,
    this.longPressSpeed = 2.0,
    this.progressMode = ProgressDisplayMode.time,
    this.showSystemTime = true,
  });

  @override
  State<MobilePlayerControls> createState() => _MobilePlayerControlsState();
}

class _MobilePlayerControlsState extends State<MobilePlayerControls> {
  final List<StreamSubscription> _subscriptions = [];
  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _isLongPressing = false;
  double _originalPlaybackSpeed = 1.0;
  Duration? _dragPosition;
  bool _isSeekingViaSwipe = false;
  bool _isDraggingProgressBar = false; // 是否正在通过进度条拖动
  double _swipeStartX = 0;
  Duration _swipeStartPosition = Duration.zero;
  Size? _screenSize;
  bool _isLocked = false;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  Timer? _volumeHideTimer;
  Timer? _brightnessHideTimer;
  Timer? _timeUpdateTimer;
  String _currentTime = '';

  // 💡 优化：将 _isEffectiveFullscreen 改为动态 Getter，实时根据屏幕宽高比判断
  // 这样无论是手动旋转还是点击全屏按钮，UI 都能自动适配正确的布局模式
  bool get _isEffectiveFullscreen {
    final size = MediaQuery.maybeOf(context)?.size ?? Size.zero;
    return size.width > size.height || _isFullscreen;
  }

  bool _isFullscreen = false;

  // 💡 电池电量相关状态
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _batteryTimer;

  @override
  void initState() {
    super.initState();
    _initSystemControls();
    _listenPlayerStreams();
    _updateCurrentTime();
    _startTimeUpdateTimer();
    _initBattery(); // 💡 初始化电池监测
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _forceStartHideTimer();
      widget.onControlsVisibilityChanged(true);
    });
  }

  void _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (level >= 0 && level <= 100) {
        _batteryLevel = level;
      }
      _batteryState = await _battery.batteryState;
      if (mounted) setState(() {});

      // 监听充电状态变化
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
        if (mounted) {
          setState(() => _batteryState = state);
          _updateBatteryLevel();
        }
      });

      // 每5分钟刷新一次电量
      _batteryTimer = Timer.periodic(const Duration(seconds: 60 * 5), (_) {
        _updateBatteryLevel();
      });
    } catch (_) {}
  }

  void _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < 0 || level > 100) {
        return;
      }
      if (mounted && level != _batteryLevel) {
        setState(() => _batteryLevel = level);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant MobilePlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isPipMode && widget.isPipMode) {
      _hideTimer?.cancel();
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
      return;
    }

    // 退出 PIP 模式时，恢复显示控制栏
    if (oldWidget.isPipMode && !widget.isPipMode) {
      setState(() => _controlsVisible = true);
      widget.onControlsVisibilityChanged(true);
      _startHideTimer();
    }
  }

  void _initSystemControls() {
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((value) {
      if (mounted) {
        setState(() => _currentVolume = value);
      }
    }).catchError((_) {});
    ScreenBrightness().application.then((value) {
      if (mounted) {
        setState(() => _currentBrightness = value);
      }
    }).catchError((_) {});
  }

  void _listenPlayerStreams() {
    _subscriptions.add(widget.player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (widget.isPipMode) {
        _hideTimer?.cancel();
        if (_controlsVisible) {
          setState(() => _controlsVisible = false);
          widget.onControlsVisibilityChanged(false);
        }
        return;
      }
      if (playing && _controlsVisible) {
        _startHideTimer();
      }
      if (!playing) {
        _hideTimer?.cancel();
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
          widget.onControlsVisibilityChanged(true);
        }
      }
    }));

    _subscriptions.add(widget.player.stream.position.listen((pos) {
      if (!mounted) return;

      // 💡 核心修复：拖动/滑动结束后，等待播放器进度同步后再清除 _dragPosition
      // 这样可以实现“固定跳转点，加载完后继续走”的效果
      if (!_isSeekingViaSwipe &&
          !_isDraggingProgressBar &&
          _dragPosition != null) {
        final diff = (pos.inMilliseconds - _dragPosition!.inMilliseconds).abs();
        // 如果实际进度跟跳转点的差距缩小到 1.2 秒内（留一点容错），说明跳转成功且视频已开始在该点播放
        if (diff < 1200) {
          setState(() => _dragPosition = null);
        }
      }

      if (_controlsVisible && !_isSeekingViaSwipe) {
        setState(() {});
      }
    }));

    _subscriptions.add(widget.player.stream.completed.listen((_) {
      if (!mounted) return;
      setState(() {});
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _batterySubscription?.cancel(); // 💡 清理电池监听

    // 移除系统监听
    VolumeController.instance.removeListener();

    _hideTimer?.cancel();
    _batteryTimer?.cancel(); // 💡 清理电池计时器
    _volumeHideTimer?.cancel();
    _brightnessHideTimer?.cancel();
    _timeUpdateTimer?.cancel();
    VolumeController.instance.showSystemUI = true;
    super.dispose();
  }

  bool get _isPlaying => widget.player.state.playing;

  Duration get _position => widget.player.state.position;

  Duration get _duration => widget.player.state.duration;

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.isPipMode) {
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
      return;
    }
    if (_isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _controlsVisible = false);
          widget.onControlsVisibilityChanged(false);
        }
      });
    }
  }

  void _forceStartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
    });
  }

  void _onUserInteraction() {
    if (widget.isPipMode) {
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
      _hideTimer?.cancel();
      return;
    }
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      widget.onControlsVisibilityChanged(true);
    }
    _startHideTimer();
  }

  void _toggleControlsVisibility() {
    if (widget.isPipMode) {
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
      _hideTimer?.cancel();
      return;
    }
    if (_isLocked) {
      setState(() => _controlsVisible = !_controlsVisible);
      if (_controlsVisible) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
    widget.onControlsVisibilityChanged(_controlsVisible);
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.live || !_isPlaying) return;
    setState(() {
      _isLongPressing = true;
      _originalPlaybackSpeed = widget.playbackSpeedListenable.value;
    });
    widget.onSetSpeed(widget.longPressSpeed);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing || widget.live) return;
    widget.onSetSpeed(_originalPlaybackSpeed);
    setState(() => _isLongPressing = false);
  }

  void _onSwipeStart(DragStartDetails details) {
    if (_isLocked || widget.live) return;
    _screenSize ??= MediaQuery.of(context).size;

    // 💡 优化：横屏全屏时，如果触摸起点在屏幕顶部或底部 40 像素内，视为系统导航操作，直接拦截进度调节
    if (_isEffectiveFullscreen &&
        (details.globalPosition.dy < 40 ||
            details.globalPosition.dy > (_screenSize!.height - 40))) {
      return;
    }

    setState(() {
      _isSeekingViaSwipe = true;
      _swipeStartX = details.globalPosition.dx;
      _swipeStartPosition = _position;
      _dragPosition = null;
    });
    // 同步给父组件但不立即开启 timer，由 _onSwipeEnd 处理
    widget.onControlsVisibilityChanged(_controlsVisible);
    _hideTimer?.cancel();
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (_isLocked || !_isSeekingViaSwipe || widget.live || _screenSize == null)
      return;

    // 💡 优化：横屏全屏时，如果向上或向下滑动的趋势明显（dy 绝对值较大），视为尝试拉出系统栏或进入小窗，停止进度调节
    if (_isEffectiveFullscreen &&
        details.delta.dy.abs() > 5 &&
        details.delta.dy.abs() > details.delta.dx.abs()) {
      _onSwipeEnd(DragEndDetails());
      return;
    }

    final screenWidth = _screenSize!.width;
    final swipeDistance = details.globalPosition.dx - _swipeStartX;
    final swipeRatio = swipeDistance / (screenWidth * 0.5);
    final duration = _duration;
    if (duration == Duration.zero) return;
    final targetPosition = _swipeStartPosition +
        Duration(
          milliseconds: (duration.inMilliseconds * swipeRatio * 0.1).round(),
        );
    final clamped = Duration(
      milliseconds:
          targetPosition.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    setState(() => _dragPosition = clamped);
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (_isLocked || !_isSeekingViaSwipe || widget.live) return;
    if (_dragPosition != null) {
      widget.player.seek(_dragPosition!);
    }
    setState(() {
      _isSeekingViaSwipe = false;
      // 💡 优化：这里不再立即设为 null，由进度监听器同步后清除，或 2秒后强制清除
    });

    // 保险机制：2秒后强制清除，防止因为进度同步失败导致进度条一直卡住
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted &&
          _dragPosition != null &&
          !_isSeekingViaSwipe &&
          !_isDraggingProgressBar) {
        setState(() => _dragPosition = null);
      }
    });

    // 同步状态给父组件
    widget.onControlsVisibilityChanged(_controlsVisible);
    _startHideTimer();
  }

  void _onVolumeSwipeStart(DragStartDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    _volumeHideTimer?.cancel();
    // 仅当按钮组已显示时，才取消自动隐藏定时器（防止滑动时突然消失）
    if (_controlsVisible) {
      _hideTimer?.cancel();
    }
  }

  void _onVolumeSwipeUpdate(DragUpdateDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final volumeChange = -(details.delta.dy / screenHeight) * 2;
    setState(() {
      _currentVolume = (_currentVolume + volumeChange).clamp(0.0, 1.0);
      _showVolumeIndicator = true;
    });
    VolumeController.instance.setVolume(_currentVolume);
    _startVolumeHideTimer();
  }

  void _onVolumeSwipeEnd(DragEndDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    _startVolumeHideTimer();
    // 仅当按钮组已显示时，才重新开始自动隐藏计时
    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  void _startVolumeHideTimer() {
    _volumeHideTimer?.cancel();
    _volumeHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showVolumeIndicator = false);
      }
    });
  }

  void _onBrightnessSwipeStart(DragStartDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    _brightnessHideTimer?.cancel();
    // 仅当按钮组已显示时，才取消自动隐藏定时器
    if (_controlsVisible) {
      _hideTimer?.cancel();
    }
  }

  void _onBrightnessSwipeUpdate(DragUpdateDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final brightnessChange = -(details.delta.dy / screenHeight) * 2;
    setState(() {
      _currentBrightness =
          (_currentBrightness + brightnessChange).clamp(0.0, 1.0);
      _showBrightnessIndicator = true;
    });
    ScreenBrightness().setApplicationScreenBrightness(_currentBrightness);
    _startBrightnessHideTimer();
  }

  void _onBrightnessSwipeEnd(DragEndDetails details) {
    if (!_isEffectiveFullscreen || _isLocked) return;
    _startBrightnessHideTimer();
    // 仅当按钮组已显示时，才重新开始自动隐藏计时
    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  void _startBrightnessHideTimer() {
    _brightnessHideTimer?.cancel();
    _brightnessHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showBrightnessIndicator = false);
      }
    });
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm').format(now);
    });
  }

  void _startTimeUpdateTimer() {
    _timeUpdateTimer?.cancel();
    _timeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateCurrentTime();
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      // 播放中 -> 暂停：显示按钮组
      _onUserInteraction();
      await widget.player.pause();
      widget.onPause?.call();
      setState(() => _controlsVisible = true);
      widget.onControlsVisibilityChanged(true);
      _hideTimer?.cancel(); // 暂停状态不自动隐藏
    } else {
      // 暂停中 -> 播放
      // 💡 严格判断：记录操作前的可见性，如果本就是隐藏的，直接播放，不触碰 UI 状态以避免闪烁
      final bool wasVisible = _controlsVisible;

      await widget.player.play();

      if (wasVisible) {
        setState(() => _controlsVisible = false);
        widget.onControlsVisibilityChanged(false);
      }
      _hideTimer?.cancel();
    }
  }

  void _enterFullscreen() {
    // 💡 优化：移除 media_kit 内部的全屏逻辑，避免与 PlayerScreen 的自定义旋转逻辑竞争导致跳变
    // if (widget.state != null) {
    //   widget.state!.enterFullscreen();
    // }
    widget.onFullscreenChange(true);
    setState(() => _isFullscreen = true);
    _onUserInteraction();
  }

  void _exitFullscreen() {
    // 💡 优化：同上
    // if (widget.state != null) {
    //   widget.state!.exitFullscreen();
    // }
    widget.onFullscreenChange(false);
    // 触发退出全屏回调
    widget.onExitFullScreen?.call();
    // 确保控制栏可见并重新启动隐藏计时器
    setState(() {
      _controlsVisible = true;
      _isLocked = false;
      _isFullscreen = false;
    });
    widget.onControlsVisibilityChanged(true);
    _startHideTimer();
  }

  Future<void> _showDLNADialog() async {
    if (_isPlaying) {
      await widget.player.pause();
      widget.onPause?.call();
    }
    if (_isFullscreen) {
      _exitFullscreen();
      await Future.delayed(const Duration(milliseconds: 250));
    }
    final resumePos = widget.player.state.position;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => DLNADeviceDialog(
        currentUrl: widget.videoUrl,
        resumePosition: resumePos,
        videoTitle: widget.videoTitle,
        currentEpisodeIndex: widget.currentEpisodeIndex,
        totalEpisodes: widget.totalEpisodes,
        sourceName: widget.sourceName,
        onCastStarted: widget.onCastStarted,
      ),
    );
  }

  Future<void> _showSpeedDialog() async {
    final speeds = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0];
    final currentSpeed = widget.playbackSpeedListenable.value;
    final screenHeight = MediaQuery.of(context).size.height;
    final result = await showModalBottomSheet<double>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: speeds.map((speed) {
                  final selected = (speed - currentSpeed).abs() < 0.01;
                  return ListTile(
                    title: Text(
                      '${speed}x',
                      style: TextStyle(
                        color: selected
                            ? Colors.red
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(speed),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
    if (result != null) {
      await widget.onSetSpeed(result);
    }
  }

  Future<void> _enterPipMode() async {
    debugPrint('_enterPipMode');
    // 隐藏控制栏
    setState(() => _controlsVisible = false);
    widget.onControlsVisibilityChanged(false);
    _hideTimer?.cancel();
    // 调用父层的 PIP 逻辑
    await widget.onEnterPipMode();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    // 💡 优化：只有在加载中，且当前没有在滑动调整进度时，才显示黑色遮罩加载层
    // 这样可以避免滑动屏幕调进度时突然跳出黑屏挡住进度提示
    if (widget.isLoadingVideo && !_isSeekingViaSwipe) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ],
          ),
        ),
      );
    }

    Widget content = Stack(
      children: [
        _buildGestureLayer(),
        _buildTopGradient(),
        _buildBottomGradient(),
        if (_isEffectiveFullscreen) _buildCurrentTime(),
        if (_isEffectiveFullscreen) _buildCurrentPlayTime(),
        if (_isEffectiveFullscreen) _buildMiniProgressBar(),
        _buildBackButton(),
        _buildCastButton(),
        _buildCenterPlayPause(),
        _buildProgressBar(),
        _buildBottomControls(),
        if (_isLongPressing) _buildLongPressIndicator(), // 锁定状态下也显示倍速指示器
        if (_isSeekingViaSwipe || _isDraggingProgressBar)
          _buildProgressIndicator(), // 💡 新增：拖动进度时显示中心提示
        if (_isEffectiveFullscreen && _showBrightnessIndicator && !_isLocked)
          _buildBrightnessIndicator(),
        if (_isEffectiveFullscreen) _buildRightOverlay(),
      ],
    );

    if (_isEffectiveFullscreen) {
      content = PopScope(
        canPop: !_isLocked,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && _isLocked) {
            setState(() {
              _isLocked = false;
              _controlsVisible = true;
            });
            _startHideTimer();
          }
        },
        child: content,
      );
    }

    return content;
  }

  // 💡 新增：构建拖动进度时的中心提示框
  Widget _buildProgressIndicator() {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fast_forward_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                currentPlayTime(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestureLayer() {
    return Positioned.fill(
      child: Row(
        children: [
          if (_isEffectiveFullscreen)
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: _toggleControlsVisibility,
                onDoubleTap: _togglePlayPause,
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
                onLongPressCancel: () {
                  if (_isLongPressing) {
                    _onLongPressEnd(const LongPressEndDetails());
                  }
                },
                onHorizontalDragStart: _onSwipeStart,
                onHorizontalDragUpdate: _onSwipeUpdate,
                onHorizontalDragEnd: _onSwipeEnd,
                onVerticalDragStart: _onBrightnessSwipeStart,
                onVerticalDragUpdate: _onBrightnessSwipeUpdate,
                onVerticalDragEnd: _onBrightnessSwipeEnd,
                behavior: HitTestBehavior.opaque,
              ),
            ),
          Expanded(
            flex: _isEffectiveFullscreen ? 2 : 1,
            child: GestureDetector(
              onTap: _toggleControlsVisibility,
              onDoubleTap: _togglePlayPause,
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
              onLongPressCancel: () {
                if (_isLongPressing) {
                  _onLongPressEnd(const LongPressEndDetails());
                }
              },
              onHorizontalDragStart: _onSwipeStart,
              onHorizontalDragUpdate: _onSwipeUpdate,
              onHorizontalDragEnd: _onSwipeEnd,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          if (_isEffectiveFullscreen)
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: _toggleControlsVisibility,
                onDoubleTap: _togglePlayPause,
                onLongPressStart: _onLongPressStart,
                onLongPressEnd: _onLongPressEnd,
                onLongPressCancel: () {
                  if (_isLongPressing) {
                    _onLongPressEnd(const LongPressEndDetails());
                  }
                },
                onHorizontalDragStart: _onSwipeStart,
                onHorizontalDragUpdate: _onSwipeUpdate,
                onHorizontalDragEnd: _onSwipeEnd,
                onVerticalDragStart: _onVolumeSwipeStart,
                onVerticalDragUpdate: _onVolumeSwipeUpdate,
                onVerticalDragEnd: _onVolumeSwipeEnd,
                behavior: HitTestBehavior.opaque,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          child: Container(
            height: _isEffectiveFullscreen ? 120 : 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTime() {
    return Positioned(
      right: 20,
      bottom: 15,
      child: AnimatedOpacity(
        opacity: ((!_controlsVisible && widget.showSystemTime) && !_isLocked)
            ? 1.0
            : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          child: Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlayTime() {
    return Positioned(
      left: 20,
      bottom: 15,
      child: AnimatedOpacity(
        opacity: ((!_controlsVisible &&
                    widget.progressMode == ProgressDisplayMode.time) &&
                !_isLocked)
            ? 1.0
            : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          child: Center(
            child: Text(
              currentPlayTime(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgressBar() {
    final double value = widget.player.state.duration.inMilliseconds > 0
        ? widget.player.state.position.inMilliseconds /
            widget.player.state.duration.inMilliseconds
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: ((!_controlsVisible &&
                    widget.progressMode == ProgressDisplayMode.bar) &&
                !_isLocked)
            ? 1.0
            : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          child: Container(
            height: 3,
            width: double.infinity,
            alignment: Alignment.centerLeft,
            color: Colors.white12,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                color: Colors.green.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          child: Container(
            height: _isEffectiveFullscreen ? 140 : 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: _isEffectiveFullscreen ? 8 : 4,
      left: _isEffectiveFullscreen ? 16.0 : 8.0,
      right: _isEffectiveFullscreen ? 64.0 : null, // 核心修复：全屏时始终限制右侧空间
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize:
                  _isEffectiveFullscreen ? MainAxisSize.max : MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    _onUserInteraction();
                    // 平板横屏普通布局也会命中 _isEffectiveFullscreen，
                    // 这里必须仅在真实全屏时才执行退出全屏。
                    if (_isFullscreen) {
                      _exitFullscreen();
                    } else {
                      debugPrint('播放器返回：非全屏状态，执行页面返回');
                      widget.onBackPressed?.call();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: _isEffectiveFullscreen ? 24 : 20,
                    ),
                  ),
                ),
                if (_isEffectiveFullscreen) ...[
                  const SizedBox(width: 8),
                  _buildVideoInfo(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo() {
    final title = widget.videoTitle ?? '';

    String episodeText = '';
    if (widget.currentEpisodeIndex != null &&
        widget.totalEpisodes != null &&
        widget.totalEpisodes! > 1) {
      if (widget.episodesTitles != null &&
          widget.currentEpisodeIndex! < widget.episodesTitles!.length) {
        episodeText = widget.episodesTitles![widget.currentEpisodeIndex!];
      } else {
        episodeText = '第${widget.currentEpisodeIndex! + 1}集';
      }
    }

    final year = widget.videoYear ?? '';

    final parts = <String>[];
    if (title.isNotEmpty) parts.add(title);
    if (episodeText.isNotEmpty) parts.add(episodeText);
    if (year.isNotEmpty && year != 'unknown') parts.add(year);

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.maybeOf(context)?.size.width ?? 300,
      ),
      child: Text(
        parts.join(' · '),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCastButton() {
    final iconSize = _isEffectiveFullscreen ? 24.0 : 20.0;

    return Positioned(
      top: _isEffectiveFullscreen ? 8 : 4,
      right: _isEffectiveFullscreen ? 16.0 : 8.0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  _onUserInteraction();
                  if (!widget.live) {
                    widget.player.pause();
                  }
                  await _showDLNADialog();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.cast,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
              if (_isEffectiveFullscreen &&
                  widget.onSettingsButtonPressed != null)
                GestureDetector(
                  onTap: () {
                    _onUserInteraction();
                    widget.onSettingsButtonPressed?.call(context);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
              if (_isEffectiveFullscreen) ...[
                const SizedBox(width: 4),
                _buildBatteryAndTimeInfo(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryAndTimeInfo() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildBatteryBox(),
          const SizedBox(height: 2),
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryBox() {
    final isCharging = _batteryState == BatteryState.charging ||
        _batteryState == BatteryState.full;
    final safeBatteryLevel = _batteryLevel.clamp(0, 100).toDouble();
    final safeWidthFactor = safeBatteryLevel / 100.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 27,
          height: 12,
          padding: const EdgeInsets.all(1.0),
          decoration: BoxDecoration(
            border: Border.all(
                color: isCharging
                    ? Colors.green.withOpacity(0.7)
                    : Colors.white.withOpacity(0.4),
                width: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              // 背景微弱填充
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(0.5),
                ),
              ),
              // 💡 电池进度条
              FractionallySizedBox(
                widthFactor: safeWidthFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: isCharging
                        ? Colors.green
                        : (safeBatteryLevel <= 20 ? Colors.red : Colors.white),
                    borderRadius: BorderRadius.circular(0.5),
                  ),
                ),
              ),
              // 仅在充电时显示充电标识（bolt）
              if (isCharging)
                const Center(
                  child: Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
            ],
          ),
        ),
        // 电池正极头
        Container(
          width: 1.2,
          height: 4,
          decoration: BoxDecoration(
            color: isCharging
                ? Colors.green.withOpacity(0.7)
                : Colors.white.withOpacity(0.4),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(1),
              bottomRight: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getBatteryIcon() {
    if (_batteryState == BatteryState.charging)
      return Icons.battery_charging_full;
    if (_batteryLevel <= 10) return Icons.battery_0_bar;
    if (_batteryLevel <= 20) return Icons.battery_1_bar;
    if (_batteryLevel <= 30) return Icons.battery_2_bar;
    if (_batteryLevel <= 50) return Icons.battery_3_bar;
    if (_batteryLevel <= 70) return Icons.battery_4_bar;
    if (_batteryLevel <= 80) return Icons.battery_5_bar;
    if (_batteryLevel <= 90) return Icons.battery_6_bar;
    return Icons.battery_full;
  }

  Widget _buildCenterPlayPause() {
    return Positioned.fill(
      child: Center(
        child: AnimatedOpacity(
          opacity:
              (!_isLocked && (!_isPlaying || _controlsVisible)) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: _isLocked || (_isPlaying && !_controlsVisible),
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: _isEffectiveFullscreen ? 64 : 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: _isEffectiveFullscreen ? 58.0 : 42.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: Container(
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: _MobileVideoProgressBar(
              player: widget.player,
              live: widget.live,
              onDragStart: () {
                setState(() {
                  _isDraggingProgressBar = true;
                });
                _hideTimer?.cancel();
              },
              onDragEnd: () {
                setState(() {
                  _isDraggingProgressBar = false;
                  // 💡 优化：这里不再立即设为 null，由进度监听器同步后清除
                });

                // 保险机制：2秒后强制清除
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted &&
                      _dragPosition != null &&
                      !_isSeekingViaSwipe &&
                      !_isDraggingProgressBar) {
                    setState(() => _dragPosition = null);
                  }
                });

                _startHideTimer();
              },
              onDragUpdate: () {
                _hideTimer?.cancel();
              },
              onPositionUpdate: (duration) {
                setState(() => _dragPosition = duration);
              },
              dragPosition: _dragPosition,
              isSeekingViaSwipe: _isSeekingViaSwipe,
            ),
          ),
        ),
      ),
    );
  }

  String currentPlayTime() {
    final position = _dragPosition ?? _position;
    final duration = _duration;
    return '${_formatDuration(position)} / ${_formatDuration(duration)}';
  }

  Widget _buildDanmakuToggleButton(EdgeInsets padding) {
    final buttonSize = _isEffectiveFullscreen ? 26.0 : 22.0;

    return GestureDetector(
      onTap: () {
        _onUserInteraction();
        widget.onDanmakuToggle?.call(!widget.isDanmakuEnabled);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: padding,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: DanmakuToggleIcon(
            enabled: widget.isDanmakuEnabled,
            size: buttonSize,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final iconSize = _isEffectiveFullscreen ? 26.0 : 24.0;

    final iconPadding = EdgeInsets.only(
        left: _isEffectiveFullscreen ? 10 : 8,
        right: _isEffectiveFullscreen ? 10 : 8);

    return Positioned(
      bottom: _isEffectiveFullscreen ? 4.0 : -6.0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.maybeOf(context)?.size.width ??
                  constraints.maxWidth;

              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _isEffectiveFullscreen
                      ? (screenWidth < 750 ? 750 : screenWidth)
                      : screenWidth,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: _isEffectiveFullscreen ? 16.0 : 8.0,
                      right: _isEffectiveFullscreen ? 16.0 : 8.0,
                      bottom: _isEffectiveFullscreen ? 8.0 : 8.0,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _togglePlayPause,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: iconSize,
                            ),
                          ),
                        ),
                        if (!widget.isLastEpisode && !widget.live)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();

                              widget.onNextEpisode?.call();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.skip_next,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),

                        if (!widget.live)
                          Expanded(
                            child: Padding(
                              padding: iconPadding,
                              child: Text(
                                currentPlayTime(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ),

                        if (widget.live) const Spacer(),

                        // 手动匹配弹幕按钮（仅在横屏时显示）：

                        if (_isEffectiveFullscreen &&
                            widget.onDanmakuMatchButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();

                              widget.onDanmakuMatchButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.search,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),

                        if (_isEffectiveFullscreen &&
                            widget.onDanmakuToggle != null)
                          _buildDanmakuToggleButton(iconPadding),

                        // 弹幕设置按钮（仅在横屏时显示）：

                        if (_isEffectiveFullscreen &&
                            widget.onDanmakuButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();

                              widget.onDanmakuButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: DanmakuSettingsIcon(
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),

                        // 选集按钮（仅在横屏且集数大于1时显示）

                        if (_isEffectiveFullscreen &&
                            widget.totalEpisodes != null &&
                            widget.totalEpisodes! > 1 &&
                            widget.onEpisodesButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();

                              widget.onEpisodesButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.list,
                                color: Colors.white,
                                size: _isEffectiveFullscreen ? 32.0 : 24.0,
                              ),
                            ),
                          ),

                        // 换源按钮（仅在横屏且非本地播放时显示）：

                        if (_isEffectiveFullscreen &&
                            !widget.isLocal &&
                            widget.onSourcesButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();

                              widget.onSourcesButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.sync_alt,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),

                        if (!widget.live)
                          if (!_isEffectiveFullscreen &&
                              widget.onDanmakuToggle != null)
                            _buildDanmakuToggleButton(iconPadding),

                        if (!widget.live)
                          GestureDetector(
                            onTap: () async {
                              _onUserInteraction();

                              await _showSpeedDialog();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: _isEffectiveFullscreen ? 30.0 : 24.0,
                              ),
                            ),
                          ),

                        if (Platform.isAndroid)
                          GestureDetector(
                            onTap: () async {
                              debugPrint('点击小窗按钮，准备进入画中画');

                              _onUserInteraction();

                              await _enterPipMode();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.picture_in_picture_alt,
                                color: Colors.white,
                                size: _isEffectiveFullscreen ? 26.0 : 22.0,
                              ),
                            ),
                          ),

                        GestureDetector(
                          onTap: () {
                            _onUserInteraction();

                            if (_isFullscreen) {
                              _exitFullscreen();
                            } else {
                              _enterFullscreen();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: iconPadding,
                            child: Icon(
                              _isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                              size: _isEffectiveFullscreen ? 32.0 : 26.0,
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
        ),
      ),
    );
  }

  Widget _buildLongPressIndicator() {
    return Positioned(
      top: 10, // 往下移动一点，避免挡住刘海或状态栏
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20), // 圆角药丸形状
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fast_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.longPressSpeed}x 播放中',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrightnessIndicator() {
    return Positioned(
      left: 16.0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _currentBrightness < 0.5
                    ? Icons.brightness_low
                    : Icons.brightness_high,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                width: 4,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: _currentBrightness,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_currentBrightness * 100).round()}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightOverlay() {
    if (_showVolumeIndicator && !_isLocked) {
      return Positioned(
        right: 16.0,
        top: 0,
        bottom: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentVolume == 0
                      ? Icons.volume_off
                      : _currentVolume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  width: 4,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: _currentVolume,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_currentVolume * 100).round()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      right: 16.0,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_controlsVisible,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isLocked = !_isLocked;
                  _controlsVisible = true;
                });
                _startHideTimer();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(12),
                // decoration: BoxDecoration(
                //   color: Colors.black.withValues(alpha: 0.5),
                //   borderRadius: BorderRadius.circular(24),
                // ),
                child: Icon(
                  _isLocked ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileVideoProgressBar extends StatefulWidget {
  final PlayerAdapter player;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragUpdate;
  final Function(Duration)? onPositionUpdate;
  final Duration? dragPosition;
  final bool isSeekingViaSwipe;
  final bool live;

  const _MobileVideoProgressBar({
    required this.player,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.onPositionUpdate,
    this.dragPosition,
    this.isSeekingViaSwipe = false,
    this.live = false,
  });

  @override
  State<_MobileVideoProgressBar> createState() =>
      _MobileVideoProgressBarState();
}

class _MobileVideoProgressBarState extends State<_MobileVideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isSeeking = false; // 鏂板锛氭爣璁版槸鍚︽鍦?seek
  StreamSubscription<Duration>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.player.stream.position.listen((_) {
      if (mounted && !_isDragging && !_isSeeking) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.player.state.duration;
    final position = widget.dragPosition ?? widget.player.state.position;

    double value = 0.0;
    if (duration.inMilliseconds > 0) {
      if (widget.live) {
        value = 1.0;
      } else {
        value = position.inMilliseconds / duration.inMilliseconds;
      }
    }

    if ((_isDragging || _isSeeking) && !widget.live) {
      value = _dragValue;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.live
          ? null
          : (details) {
              // 💡 优化：横屏全屏时，如果触摸点在进度条容器的最顶部或最底部边缘（dy 极小或极大），
              // 说明可能是想滑出系统栏，此时忽略拖动起手。
              if (details.localPosition.dy < 4 || details.localPosition.dy > 20)
                return;

              _isDragging = true;
              widget.onDragStart?.call();
              _updateDrag(details.localPosition.dx, context);
            },
      onHorizontalDragUpdate: widget.live
          ? null
          : (details) {
              if (_isDragging) {
                widget.onDragUpdate?.call();
                _updateDrag(details.localPosition.dx, context);
              }
            },
      onHorizontalDragEnd: widget.live
          ? null
          : (details) async {
              if (_isDragging) {
                final seekPosition = Duration(
                  milliseconds: (_dragValue * duration.inMilliseconds).round(),
                );

                setState(() {
                  _isDragging = false;
                  _isSeeking = true;
                });

                // 💡 优化：跳转后锁定 800ms
                widget.player.seek(seekPosition).then((_) async {
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) {
                    setState(() {
                      _isSeeking = false;
                    });
                  }
                });

                widget.onDragEnd?.call();
              }
            },
      onTapDown: widget.live
          ? null
          : (details) async {
              widget.onDragStart?.call();
              _updateDrag(details.localPosition.dx, context);
              final seekPosition = Duration(
                milliseconds: (_dragValue * duration.inMilliseconds).round(),
              );

              setState(() {
                _isSeeking = true; // 鏍囪寮€濮?seek
              });

              // 💡 优化：跳转后锁定 800ms
              widget.player.seek(seekPosition).then((_) async {
                await Future.delayed(const Duration(milliseconds: 800));
                if (mounted) {
                  setState(() {
                    _isSeeking = false; // 鏍囪 seek 瀹屾垚
                  });
                }
              });

              widget.onDragEnd?.call();
            },
      child: Container(
        height: 24,
        color: Colors.transparent,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progressWidth = constraints.maxWidth;
              final progressValue = value.clamp(0.0, 1.0);
              final thumbMin = progressWidth <= 16 ? progressWidth / 2 : 8.0;
              final thumbMax = progressWidth <= 16 ? thumbMin : progressWidth - 8.0;
              final thumbPosition =
                  (progressValue * progressWidth).clamp(thumbMin, thumbMax);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 9,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 9,
                    child: Container(
                      width: progressValue * progressWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.red,
                      ),
                    ),
                  ),
                  if (!widget.live)
                    Positioned(
                      left: thumbPosition - 8,
                      top: 4,
                      child: AnimatedScale(
                        scale: widget.isSeekingViaSwipe ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateDrag(double dx, BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final width = box.size.width;
    if (width <= 0) return;

    final value = (dx / width).clamp(0.0, 1.0);

    if ((value - _dragValue).abs() < 0.001) return;

    setState(() => _dragValue = value);

    if (!widget.live) {
      final duration = widget.player.state.duration;
      final position =
          Duration(milliseconds: (value * duration.inMilliseconds).round());
      widget.onPositionUpdate?.call(position);
    }
  }
}
