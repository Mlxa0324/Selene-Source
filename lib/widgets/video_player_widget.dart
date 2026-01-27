import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart' as vp;
import 'package:pip/pip.dart';
import 'mobile_player_controls.dart';
import 'pc_player_controls.dart';
import 'video_player_surface.dart';
import 'player_settings_panel.dart';
import 'player_adapter.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoPlayerSurface surface;
  final String? url;
  final Map<String, String>? headers;
  final VoidCallback? onBackPressed;
  final Function(VideoPlayerWidgetController)? onControllerCreated;
  final VoidCallback? onReady;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final bool isLastEpisode;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final String? videoYear;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final List<String>? episodesTitles;
  final String? subtitleUrl;
  final String? sourceName;
  final bool isLocal; // 是否是本地播放
  final Function(bool isWebFullscreen)? onWebFullscreenChanged;
  final Function(bool isFullscreen)? onFullscreenChanged;
  final VoidCallback? onExitFullScreen;
  final bool live;
  final Function(bool isPipMode)? onPipModeChanged;
  final void Function(BuildContext context)? onEpisodesButtonPressed;
  final void Function(BuildContext context)? onSourcesButtonPressed;
  final void Function(BuildContext context)? onSettingsButtonPressed;
  final void Function(BuildContext context)? onDanmakuButtonPressed;
  final void Function(BuildContext context)? onDanmakuMatchButtonPressed;
  final double longPressSpeed;
  final ProgressDisplayMode progressMode;
  final bool showSystemTime;
  final Widget? danmakuLayer;

  const VideoPlayerWidget({
    super.key,
    this.surface = VideoPlayerSurface.mobile,
    this.url,
    this.headers,
    this.onBackPressed,
    this.onControllerCreated,
    this.onReady,
    this.onNextEpisode,
    this.onVideoCompleted,
    this.onPlay,
    this.onPause,
    this.isLastEpisode = false,
    this.onCastStarted,
    this.videoTitle,
    this.videoYear,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.episodesTitles,
    this.subtitleUrl,
    this.sourceName,
    this.isLocal = false,
    this.onWebFullscreenChanged,
    this.onFullscreenChanged,
    this.onExitFullScreen,
    this.live = false,
    this.onPipModeChanged,
    this.onEpisodesButtonPressed,
    this.onSourcesButtonPressed,
    this.onSettingsButtonPressed,
    this.onDanmakuButtonPressed,
    this.onDanmakuMatchButtonPressed,
    this.longPressSpeed = 2.0,
    this.progressMode = ProgressDisplayMode.none,
    this.showSystemTime = false,
    this.danmakuLayer,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class VideoPlayerWidgetController {
  VideoPlayerWidgetController._(this._state);
  final _VideoPlayerWidgetState _state;

  Future<void> updateDataSource(
      String url, {
        Duration? startAt,
        Map<String, String>? headers,
      }) async {
    await _state._updateDataSource(
      url,
      startAt: startAt,
      headers: headers,
    );
  }

  Future<void> seekTo(Duration position) async {
    await _state._adapter?.seek(position);
  }

  Duration? get currentPosition => _state._adapter?.state.position;

  Duration? get duration => _state._adapter?.state.duration;

  bool get isPlaying => _state._adapter?.state.playing ?? false;

  Future<void> pause() async {
    await _state._adapter?.pause();
  }

  Future<void> play() async {
    await _state._adapter?.play();
  }

  void addProgressListener(VoidCallback listener) {
    _state._addProgressListener(listener);
  }

  void removeProgressListener(VoidCallback listener) {
    _state._removeProgressListener(listener);
  }

  Future<void> setSpeed(double speed) async {
    await _state._setPlaybackSpeed(speed);
  }

  double get playbackSpeed => _state._playbackSpeed.value;

  Future<void> setVolume(double volume) async {
    await _state._adapter?.setVolume(volume);
  }

  double? get volume => _state._adapter?.state.volume;

  void exitWebFullscreen() {
    _state._exitWebFullscreen();
  }

  Future<void> dispose() async {
    await _state._externalDispose();
  }

  bool get isPipMode => _state._isPipMode;

  void setVideoFit(VideoFitType fitType) {
    _state._setVideoFit(fitType);
  }
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver {
  PlayerAdapter? _adapter;
  bool _isInitialized = false;
  bool _hasCompleted = false;
  bool _isLoadingVideo = false;
  String? _currentUrl;
  Map<String, String>? _currentHeaders;
  final List<VoidCallback> _progressListeners = [];
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _bufferingSubscription;
  final ValueNotifier<double> _playbackSpeed = ValueNotifier<double>(1.0);
  bool _playerDisposed = false;
  bool _isBuffering = false;
  VoidCallback? _exitWebFullscreenCallback;
  final Pip _pip = Pip();
  bool _isPipMode = false;
  VideoFitType _currentFitType = VideoFitType.contain;
  bool _controlsVisible = true;
  final GlobalKey<mkv.VideoState> _videoKey = GlobalKey<mkv.VideoState>();

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    // 如果当前正在构建过程中，则推迟到下一帧执行
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUrl = widget.url;
    _currentHeaders = widget.headers;
    _initializePlayer();
    _setupPip();
    _registerPipObserver();
    widget.onControllerCreated?.call(VideoPlayerWidgetController._(this));
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.headers != oldWidget.headers && widget.headers != null) {
      _currentHeaders = widget.headers;
    }
    if (widget.url != oldWidget.url && widget.url != null) {
      unawaited(_updateDataSource(widget.url!));
    }
  }

  Future<void> _initializePlayer() async {
    if (_playerDisposed) {
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // 本地播放使用原生适配器，在线播放使用 WebView 适配器
      if (_currentUrl != null) {
        if (widget.isLocal) {
          debugPrint('VideoPlayerWidget: 使用 VideoPlayerAdapter 播放本地文件');
          final controller = vp.VideoPlayerController.file(
            File(_currentUrl!),
          );
          _adapter = VideoPlayerAdapter(controller);
          controller.initialize().then((_) {
            if (mounted) {
              _safeSetState(() {
                _isLoadingVideo = false;
              });
              widget.onReady?.call();
              _adapter!.play();
            }
          });
        } else {
          debugPrint('VideoPlayerWidget: 使用 WebViewPlayerAdapter 播放网络流');
          _adapter = WebViewPlayerAdapter(
            url: _currentUrl!,
            headers: _currentHeaders,
            onReady: () {
              debugPrint('VideoPlayerWidget: WebView ready (init)');
              if (mounted) {
                _safeSetState(() {
                  _isLoadingVideo = false;
                });
                widget.onReady?.call();
              }
            },
          );
        }
        _setupPlayerListeners();
        _adapter?.updateVideoFit(_getBoxFit());
      }
      _safeSetState(() {
        _isInitialized = true;
      });
    } else {
      // Use media_kit on desktop
      final player = mk.Player(
        configuration: const mk.PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024,
          ready: null,
        ),
      );
      _adapter = MediaKitAdapter(player);
      _setupPlayerListeners();
      if (_currentUrl != null) {
        await _openCurrentMedia();
      }
      _safeSetState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _openCurrentMedia({Duration? startAt}) async {
    if (_playerDisposed || _adapter == null || _currentUrl == null) {
      return;
    }
    _safeSetState(() {
      _isLoadingVideo = true;
    });
    try {
      if (_adapter is MediaKitAdapter) {
        final player = (_adapter as MediaKitAdapter).player;
        await player.open(
          mk.Media(
            _currentUrl!,
            start: startAt,
            httpHeaders: _currentHeaders ?? const <String, String>{},
          ),
          play: true,
        );
      } else if (_adapter is VideoPlayerAdapter) {
        // Handled in initialization or _updateDataSource for mobile
      }

      await _adapter!.setRate(_playbackSpeed.value);
      _safeSetState(() {
        _hasCompleted = false;
      });
    } catch (error) {
      debugPrint('VideoPlayerWidget: failed to open media $error');
      if (mounted) {
        _safeSetState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _setupPlayerListeners() {
    if (_adapter == null) {
      return;
    }
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferingSubscription?.cancel();

    _positionSubscription = _adapter!.stream.position.listen((_) {
      for (final listener in List<VoidCallback>.from(_progressListeners)) {
        try {
          listener();
        } catch (error) {
          debugPrint('VideoPlayerWidget: progress listener error $error');
        }
      }
    });

    _playingSubscription = _adapter!.stream.playing.listen((playing) {
      if (!mounted) return;
      if (!playing) {
        widget.onPause?.call();
        _safeSetState(() {
          _hasCompleted = false;
        });
        _pip.setup(const PipOptions(
          autoEnterEnabled: false,
          aspectRatioX: 16,
          aspectRatioY: 9,
          preferredContentWidth: 480,
          preferredContentHeight: 270,
          controlStyle: 2,
        ));
      } else {
        widget.onPlay?.call();
        _pip.setup(const PipOptions(
          autoEnterEnabled: true,
          aspectRatioX: 16,
          aspectRatioY: 9,
          preferredContentWidth: 480,
          preferredContentHeight: 270,
          controlStyle: 2,
        ));
      }
    });

    if (!widget.live) {
      _completedSubscription = _adapter!.stream.completed.listen((completed) {
        if (!mounted) return;
        if (completed && !_hasCompleted) {
          _hasCompleted = true;
          widget.onVideoCompleted?.call();
        }
      });
    }

    _durationSubscription = _adapter!.stream.duration.listen((duration) {
      if (!mounted) return;
      if (duration != Duration.zero) {
        debugPrint('VideoPlayerWidget: duration changed to $duration');
        if (_isLoadingVideo) {
          _safeSetState(() {
            _isLoadingVideo = false;
          });
        }
        widget.onReady?.call();
      }
    });

    _bufferingSubscription = _adapter!.stream.buffering.listen((buffering) {
      if (!mounted) return;
      _safeSetState(() {
        _isBuffering = buffering;
      });
    });

    // 立即检查一次当前状态 ，防止错过已经准备好的状态
    final currentDuration = _adapter!.state.duration;
    if (currentDuration != Duration.zero) {
      debugPrint('VideoPlayerWidget: proactive ready check - duration is $currentDuration');
      if (_isLoadingVideo) {
        _safeSetState(() {
          _isLoadingVideo = false;
        });
      }
      widget.onReady?.call();
    }
  }

  Future<void> _updateDataSource(
      String url, {
        Duration? startAt,
        Map<String, String>? headers,
      }) async {
    if (_playerDisposed) {
      return;
    }
    _currentUrl = url;
    if (headers != null) {
      _currentHeaders = headers;
    }

    if (_adapter == null) {
      await _initializePlayer();
      return;
    }

    _safeSetState(() {
      _isLoadingVideo = true;
    });

    try {
      final currentSpeed = _adapter!.state.rate;

      if (_adapter is MediaKitAdapter) {
        final player = (_adapter as MediaKitAdapter).player;
        await player.open(
          mk.Media(
            url,
            start: startAt,
            httpHeaders: _currentHeaders ?? const <String, String>{},
          ),
          play: true,
        );
      } else if (widget.isLocal) {
        // 处理本地文件切换
        final oldAdapter = _adapter;
        final newController = vp.VideoPlayerController.file(
          File(url),
        );
        await newController.initialize();
        if (startAt != null) {
          await newController.seekTo(startAt);
        }

        _adapter = VideoPlayerAdapter(newController);
        _setupPlayerListeners();
        await _adapter!.play();

        if (mounted) {
          _safeSetState(() {
            _isLoadingVideo = false;
          });
          widget.onReady?.call();
        }

        // 异步清理旧适配器
        unawaited(oldAdapter?.dispose());
      } else if (_adapter is VideoPlayerAdapter) {
        final oldController = (_adapter as VideoPlayerAdapter).controller;
        await oldController.pause();

        final newController = vp.VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: _currentHeaders ?? const {},
        );
        await newController.initialize();
        if (startAt != null) {
          await newController.seekTo(startAt);
        }

        final oldAdapter = _adapter;
        _adapter = VideoPlayerAdapter(newController);
        _setupPlayerListeners();
        _adapter?.updateVideoFit(_getBoxFit());
        await _adapter!.play();

        // Clean up old one after switching to minimize gap
        unawaited(oldAdapter?.dispose());
      } else if (_adapter is WebViewPlayerAdapter) {
        // For WebView player, recreate with new URL
        final oldAdapter = _adapter;
        _adapter = WebViewPlayerAdapter(
          url: url,
          headers: _currentHeaders,
          startAt: startAt,
          onReady: () {
            debugPrint('VideoPlayerWidget: WebView ready (update)');
            if (mounted) {
              _safeSetState(() {
                _isLoadingVideo = false;
              });
              widget.onReady?.call();
            }
          },
        );
        _setupPlayerListeners();
        _adapter?.updateVideoFit(_getBoxFit());
        unawaited(oldAdapter?.dispose());
      }

      _playbackSpeed.value = currentSpeed;
      await _adapter!.setRate(currentSpeed);

      if (mounted) {
        _safeSetState(() {
          _hasCompleted = false;
        });
      }
    } catch (error) {
      debugPrint('VideoPlayerWidget: error while changing source $error');
      if (mounted) {
        _safeSetState(() {
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  void _removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed.value = speed;
    await _adapter?.setRate(speed);
  }

  void _setVideoFit(VideoFitType fitType) {
    _safeSetState(() {
      _currentFitType = fitType;
    });
    _adapter?.updateVideoFit(_getBoxFit());
  }

  BoxFit _getBoxFit() {
    switch (_currentFitType) {
      case VideoFitType.contain:
        return BoxFit.contain;
      case VideoFitType.fill:
        return BoxFit.fill;
      case VideoFitType.fitWidth:
        return BoxFit.fitWidth;
      case VideoFitType.fitHeight:
        return BoxFit.fitHeight;
    }
  }

  void _exitWebFullscreen() {
    _exitWebFullscreenCallback?.call();
  }

  void _setupPip() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    _pip.setup(const PipOptions(
      autoEnterEnabled: true,
      aspectRatioX: 16,
      aspectRatioY: 9,
      preferredContentWidth: 480,
      preferredContentHeight: 270,
      controlStyle: 2,
    ));
  }

  void _registerPipObserver() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    _pip.registerStateChangedObserver(PipStateChangedObserver(
      onPipStateChanged: (state, error) {
        if (!mounted) return;
        switch (state) {
          case PipState.pipStateStarted:
            debugPrint('PiP started successfully');
            if (mounted) {
              _safeSetState(() => _isPipMode = true);
              widget.onPipModeChanged?.call(true);
            }
            break;
          case PipState.pipStateStopped:
            debugPrint('PiP stopped');
            if (mounted) {
              _safeSetState(() {
                _isPipMode = false;
              });
              widget.onPipModeChanged?.call(false);
            }
            break;
          case PipState.pipStateFailed:
            debugPrint('PiP failed: $error');
            if (mounted) {
              _safeSetState(() => _isPipMode = false);
              widget.onPipModeChanged?.call(false);
            }
            break;
        }
      },
    ));
  }

  Future<void> _enterPipMode() async {
    debugPrint('_enterPipMode');
    try {
      var support = await _pip.isSupported();
      if (!support) {
        debugPrint('Device does not support PiP!');
        return;
      }
      await _adapter?.play();
      await _pip.start();
    } catch (e) {
      debugPrint('Failed to enter PiP mode: $e');
      _setupPip();
    }
  }

  Future<void> _externalDispose() async {
    if (!mounted || _playerDisposed) {
      return;
    }
    await _disposePlayer();
  }

  Future<void> _disposePlayer() async {
    if (_playerDisposed) {
      return;
    }

    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _durationSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _positionSubscription = null;
    _playingSubscription = null;
    _completedSubscription = null;
    _durationSubscription = null;

    _progressListeners.clear();
    _playerDisposed = true;

    try {
      await _adapter?.pause();
      await _adapter?.dispose();
    } catch (e) {
      debugPrint('VideoPlayerWidget: Error during player dispose: $e');
    } finally {
      _adapter = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_adapter == null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (Platform.isAndroid || Platform.isIOS) {
      _pip.unregisterStateChangedObserver();
      _pip.dispose();
    }
    _disposePlayer();
    _playbackSpeed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: _isInitialized && _adapter != null
          ? Stack(
        children: [
          _buildVideoSurface(),
          if (widget.danmakuLayer != null)
            RepaintBoundary(child: widget.danmakuLayer!),
          if ((_isBuffering || _isLoadingVideo) && !_controlsVisible)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          _buildControls(),
        ],
      )
          : const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVideoSurface() {
    Widget videoWidget = _adapter!.buildVideo(
      context,
      fit: _getBoxFit(),
      key: _adapter is MediaKitAdapter
          ? _videoKey
          : ValueKey('video_${_currentUrl}_${_adapter.runtimeType}'),
    );

    // 始终包裹 Center 层级
    return Center(
      child: videoWidget,
    );
  }

  Widget _buildControls() {
    if (_adapter == null) return const SizedBox.shrink();

    if (widget.surface == VideoPlayerSurface.desktop) {
      if (_adapter is! MediaKitAdapter) return const SizedBox.shrink();

      final mkAdapter = _adapter as MediaKitAdapter;
      return PCPlayerControls(
        state: _videoKey.currentState!,
        player: mkAdapter.player,
        onBackPressed: widget.onBackPressed,
        onNextEpisode: widget.onNextEpisode,
        onPause: widget.onPause,
        videoUrl: _currentUrl ?? '',
        isLastEpisode: widget.isLastEpisode,
        isLoadingVideo: _isLoadingVideo,
        onCastStarted: widget.onCastStarted,
        videoTitle: widget.videoTitle,
        videoYear: widget.videoYear,
        currentEpisodeIndex: widget.currentEpisodeIndex,
        totalEpisodes: widget.totalEpisodes,
        episodesTitles: widget.episodesTitles,
        sourceName: widget.sourceName,
        isLocal: widget.isLocal,
        onWebFullscreenChanged: widget.onWebFullscreenChanged,
        onExitWebFullscreenCallbackReady: (callback) {
          _exitWebFullscreenCallback = callback;
        },
        onExitFullScreen: widget.onExitFullScreen,
        live: widget.live,
        playbackSpeedListenable: _playbackSpeed,
        onSetSpeed: _setPlaybackSpeed,
        onControlsVisibilityChanged: (visible) {
          _safeSetState(() => _controlsVisible = visible);
        },
      );
    } else {
      return MobilePlayerControls(
        player: _adapter!,
        state: _videoKey.currentState,
        onControlsVisibilityChanged: (visible) {
          _safeSetState(() => _controlsVisible = visible);
        },
        onBackPressed: widget.onBackPressed,
        onFullscreenChange: (isFullscreen) {
          widget.onFullscreenChanged?.call(isFullscreen);
        },
        onNextEpisode: widget.onNextEpisode,
        onPause: widget.onPause,
        videoUrl: _currentUrl ?? '',
        isLastEpisode: widget.isLastEpisode,
        isLoadingVideo: _isLoadingVideo,
        onCastStarted: widget.onCastStarted,
        videoTitle: widget.videoTitle,
        videoYear: widget.videoYear,
        currentEpisodeIndex: widget.currentEpisodeIndex,
        totalEpisodes: widget.totalEpisodes,
        episodesTitles: widget.episodesTitles,
        sourceName: widget.sourceName,
        isLocal: widget.isLocal,
        onExitFullScreen: widget.onExitFullScreen,
        live: widget.live,
        playbackSpeedListenable: _playbackSpeed,
        onSetSpeed: _setPlaybackSpeed,
        onEnterPipMode: _enterPipMode,
        isPipMode: _isPipMode,
        onEpisodesButtonPressed: widget.onEpisodesButtonPressed,
        onSourcesButtonPressed: widget.onSourcesButtonPressed,
        onSettingsButtonPressed: widget.onSettingsButtonPressed,
        onDanmakuButtonPressed: widget.onDanmakuButtonPressed,
        onDanmakuMatchButtonPressed:
        widget.onDanmakuMatchButtonPressed,
        longPressSpeed: widget.longPressSpeed,
        progressMode: widget.progressMode,
        showSystemTime: widget.showSystemTime,
      );
    }
  }
}
