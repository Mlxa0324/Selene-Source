import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dlna_device_dialog.dart';
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
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initSystemControls();
    _listenPlayerStreams();
    _updateCurrentTime();
    _startTimeUpdateTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _forceStartHideTimer();
      widget.onControlsVisibilityChanged(true);
    });
  }

  @override
  void didUpdateWidget(covariant MobilePlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 褰?PIP 妯″紡鍋滄鏃讹紝鏄剧ず鎺у埗鏍?
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

    _subscriptions.add(widget.player.stream.position.listen((_) {
      if (!mounted) return;
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

    // 绉婚櫎绯荤粺鐩戝惉
    VolumeController.instance.removeListener();

    _hideTimer?.cancel();
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
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      widget.onControlsVisibilityChanged(true);
    }
    _startHideTimer();
  }

  void _toggleControlsVisibility() {
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
    if (widget.live || !_isPlaying) return; // 閿佸畾鐘舵€佷笅涔熷厑璁搁暱鎸夊€嶉€?
    setState(() {
      _isLongPressing = true;
      _originalPlaybackSpeed = widget.playbackSpeedListenable.value;
    });
    widget.onSetSpeed(widget.longPressSpeed);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing || widget.live) return; // 閿佸畾鐘舵€佷笅涔熷厑璁?
    widget.onSetSpeed(_originalPlaybackSpeed);
    setState(() => _isLongPressing = false);
  }

  void _onSwipeStart(DragStartDetails details) {
    if (_isLocked || widget.live) return;
    _screenSize ??= MediaQuery.of(context).size;
    setState(() {
      _isSeekingViaSwipe = true;
      _swipeStartX = details.globalPosition.dx;
      _swipeStartPosition = _position;
      _dragPosition = null;
      _controlsVisible = true;
    });
    _hideTimer?.cancel();
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (_isLocked || !_isSeekingViaSwipe || widget.live || _screenSize == null)
      return;
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
      _dragPosition = null;
    });
    _startHideTimer();
  }

  void _onVolumeSwipeStart(DragStartDetails details) {
    if (!_isFullscreen || _isLocked) return;
    _volumeHideTimer?.cancel();
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
  }

  void _onVolumeSwipeUpdate(DragUpdateDetails details) {
    if (!_isFullscreen || _isLocked) return;
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
    if (!_isFullscreen || _isLocked) return;
    _startVolumeHideTimer();
    _startHideTimer();
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
    if (!_isFullscreen || _isLocked) return;
    _brightnessHideTimer?.cancel();
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
  }

  void _onBrightnessSwipeUpdate(DragUpdateDetails details) {
    if (!_isFullscreen || _isLocked) return;
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
    if (!_isFullscreen || _isLocked) return;
    _startBrightnessHideTimer();
    _startHideTimer();
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
    _onUserInteraction();
    if (_isPlaying) {
      await widget.player.pause();
      widget.onPause?.call();
    } else {
      await widget.player.play();
    }
  }

  void _enterFullscreen() {
    if (widget.state != null) {
      widget.state!.enterFullscreen();
    }
    widget.onFullscreenChange(true);
    setState(() => _isFullscreen = true);
    _onUserInteraction();
  }

  void _exitFullscreen() {
    if (widget.state != null) {
      widget.state!.exitFullscreen();
    }
    widget.onFullscreenChange(false);
    // 瑙﹀彂閫€鍑哄叏灞忓洖璋?
    widget.onExitFullScreen?.call();
    // 纭繚鎺у埗鏍忓彲瑙佸苟閲嶆柊鍚姩闅愯棌璁℃椂鍣?
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
    final speeds = [0.5, 0.75, 1.0, 1.5, 2.0];
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
    // 闅愯棌鎺у埗鏍?
    setState(() => _controlsVisible = false);
    widget.onControlsVisibilityChanged(false);
    _hideTimer?.cancel();
    // 璋冪敤鐖跺眰鐨?PIP 閫昏緫
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
    if (widget.isLoadingVideo) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              // SizedBox(height: 16),
              // Text('加载中..',
              //     style: TextStyle(color: Colors.white, fontSize: 14)),
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
        if (_isFullscreen) _buildCurrentTime(),
        if (_isFullscreen) _buildCurrentPlayTime(),
        if (_isFullscreen) _buildMiniProgressBar(),
        _buildBackButton(),
        _buildCastButton(),
        _buildCenterPlayPause(),
        _buildProgressBar(),
        _buildBottomControls(),
        if (_isLongPressing)
          _buildLongPressIndicator(), // 閿佸畾鐘舵€佷笅涔熸樉绀哄€嶉€熸寚绀哄櫒
        if (_isFullscreen && _showBrightnessIndicator && !_isLocked)
          _buildBrightnessIndicator(),
        if (_isFullscreen) _buildRightOverlay(),
      ],
    );

    if (_isFullscreen) {
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

  Widget _buildGestureLayer() {
    return Positioned.fill(
      child: Row(
        children: [
          if (_isFullscreen)
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
            flex: _isFullscreen ? 2 : 1,
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
          if (_isFullscreen)
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
            height: _isFullscreen ? 120 : 80,
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
            height: _isFullscreen ? 140 : 100,
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
      top: _isFullscreen ? 8 : 4,
      left: _isFullscreen ? 16.0 : 8.0,
      right: _isFullscreen ? 64.0 : null, // 鏍稿績淇锛氬叏灞忔椂濮嬬粓闄愬埗鍙充晶绌洪棿
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: _isFullscreen ? MainAxisSize.max : MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    _onUserInteraction();
                    if (_isFullscreen) {
                      _exitFullscreen();
                    } else {
                      widget.onBackPressed?.call();
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: _isFullscreen ? 24 : 20,
                    ),
                  ),
                ),
                if (_isFullscreen) ...[
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
    
    // 鑾峰彇闆嗘暟鏄剧ず鏂囨湰锛氫紭鍏堜娇鐢ㄦ爣棰樺垪琛ㄤ腑鐨勫悕绉帮紝濡傛灉娌℃湁鍒欎娇鐢?绗琗闆?
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
    return Positioned(
      top: _isFullscreen ? 8 : 4,
      right: _isFullscreen ? 16.0 : 8.0,
      child: AnimatedOpacity(
        opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !_controlsVisible || _isLocked,
          child: GestureDetector(
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
                size: _isFullscreen ? 24 : 20,
              ),
            ),
          ),
        ),
      ),
    );
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
                size: _isFullscreen ? 64 : 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Positioned(
      bottom: _isFullscreen ? 58.0 : 42.0,
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
                setState(() => _controlsVisible = true);
                _hideTimer?.cancel();
              },
              onDragEnd: () {
                setState(() => _dragPosition = null);
                _startHideTimer();
              },
              onDragUpdate: () {
                if (!_controlsVisible) {
                  setState(() => _controlsVisible = true);
                }
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

    Widget _buildBottomControls() {
      final iconSize = _isFullscreen ? 28.0 : 24.0;
      final iconPadding = EdgeInsets.only(
          left: _isFullscreen ? 10 : 8, right: _isFullscreen ? 10 : 8);
  
      return Positioned(
        bottom: _isFullscreen ? 4.0 : -6.0,
        left: 0,
        right: 0,
        child: AnimatedOpacity(
          opacity: (_controlsVisible && !_isLocked) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_controlsVisible || _isLocked,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth =
                    MediaQuery.maybeOf(context)?.size.width ?? constraints.maxWidth;
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: _isFullscreen
                        ? (screenWidth < 750 ? 750 : screenWidth)
                        : screenWidth,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: _isFullscreen ? 16.0 : 8.0,
                        right: _isFullscreen ? 16.0 : 8.0,
                        bottom: _isFullscreen ? 8.0 : 8.0,
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
                          ),                        if (!widget.isLastEpisode && !widget.live)
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
                        // 鎵嬪姩鍖归厤寮瑰箷鎸夐挳锛堜粎鍦ㄦí灞忔椂鏄剧ず锛?
                        if (_isFullscreen &&
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
                        // 寮瑰箷璁剧疆鎸夐挳锛堜粎鍦ㄦí灞忔椂鏄剧ず锛?
                        if (_isFullscreen &&
                            widget.onDanmakuButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              widget.onDanmakuButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.subtitles,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),
                        // 閫夐泦鎸夐挳锛堜粎鍦ㄦí灞忎笖闆嗘暟澶т簬1鏃舵樉绀猴級
                        if (_isFullscreen &&
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
                                size: _isFullscreen ? 32.0 : 24.0,
                              ),
                            ),
                          ),
                        // 鎹㈡簮鎸夐挳锛堜粎鍦ㄦí灞忎笖闈炴湰鍦版挱鏀炬椂鏄剧ず锛?
                        if (_isFullscreen &&
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
                        // 璁剧疆鎸夐挳锛堜粎鍦ㄦí灞忔椂鏄剧ず锛?
                        if (_isFullscreen &&
                            widget.onSettingsButtonPressed != null)
                          GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              widget.onSettingsButtonPressed?.call(context);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ),
                          ),
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
                                size: _isFullscreen ? 30.0 : 24.0,
                              ),
                            ),
                          ),
                        if (Platform.isAndroid)
                          GestureDetector(
                            onTap: () async {
                              print('PIP button clicked!');
                              _onUserInteraction();
                              await _enterPipMode();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: iconPadding,
                              child: Icon(
                                Icons.picture_in_picture_alt,
                                color: Colors.white,
                                size: _isFullscreen ? 26.0 : 22.0,
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
                              size: _isFullscreen ? 32.0 : 26.0,
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
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        // 娣诲姞 Center 浣挎暣涓寚绀哄櫒灞呬腑
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4), // 娣诲姞鍨傜洿 padding
            decoration: BoxDecoration(
              color: widget.progressMode == ProgressDisplayMode.none
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.7), // 淇涓?withOpacity
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, // 纭繚 Row 鍙崰鐢ㄦ墍闇€绌洪棿
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.longPressSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.fast_forward, color: Colors.white, size: 26),
              ],
            ),
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

    if (_isDragging && !widget.live) {
      value = _dragValue;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.live
          ? null
          : (details) {
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

                // 寮傛 Seek
                widget.player.seek(seekPosition).then((_) async {
                  await Future.delayed(const Duration(milliseconds: 100));
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

              // 寮傛鎵ц seek
              widget.player.seek(seekPosition).then((_) async {
                await Future.delayed(const Duration(milliseconds: 100));
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
              final thumbPosition = (progressValue * progressWidth)
                  .clamp(8.0, progressWidth - 8.0);
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
    // 鑾峰彇缁勪欢瀹藉害锛岀敤浜庤绠楄繘搴︽瘮渚?
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    
    final width = box.size.width;
    if (width <= 0) return;
    
    final value = (dx / width).clamp(0.0, 1.0);
    
    // 濡傛灉鍊兼病鏈夋樉钁楀彉鍖栵紝璺宠繃 setState 浠ヨ妭鐪佹€ц兘
    if ((value - _dragValue).abs() < 0.001) return;
    
    setState(() => _dragValue = value);
    
    if (!widget.live) {
      final duration = widget.player.state.duration;
      final position = Duration(milliseconds: (value * duration.inMilliseconds).round());
      widget.onPositionUpdate?.call(position);
    }
  }
}
