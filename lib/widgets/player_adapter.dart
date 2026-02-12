import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart' as vp;
import '../services/user_data_service.dart';

/// A bridge to provide a common interface between media_kit and video_player
abstract class PlayerAdapter {
  PlayerAdapterStream get stream;
  PlayerAdapterState get state;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> dispose();
  Future<void> updateVideoFit(BoxFit fit);
  
  Widget buildVideo(BuildContext context, {BoxFit fit, Key? key, Widget Function(mkv.VideoState state)? controls});
}

abstract class PlayerAdapterStream {
  Stream<bool> get playing;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get completed;
  Stream<double> get volume;
  Stream<double> get rate;
  Stream<bool> get buffering;
}

abstract class PlayerAdapterState {
  bool get playing;
  Duration get position;
  Duration get duration;
  double get volume;
  double get rate;
  bool get buffering;
  double get width;  // 💡 新增：视频原始宽度
  double get height; // 💡 新增：视频原始高度
}

/// media_kit implementation
class MediaKitAdapter implements PlayerAdapter {
  final mk.Player player;
  final mkv.VideoController videoController;
  
  @override
  late final PlayerAdapterStream stream;
  @override
  late final PlayerAdapterState state;

  MediaKitAdapter(this.player) : videoController = mkv.VideoController(player) {
    stream = _MediaKitStream(player);
    state = _MediaKitState(player);
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> setRate(double rate) => player.setRate(rate);
  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);
  @override
  Future<void> dispose() => player.dispose();

  @override
  Future<void> updateVideoFit(BoxFit fit) async {
    // MediaKitVideo handles this via the fit property in buildVideo
  }

  @override
  Widget buildVideo(BuildContext context, {BoxFit fit = BoxFit.contain, Key? key, Widget Function(mkv.VideoState state)? controls}) {
    return mkv.Video(controller: videoController, fit: fit, controls: controls, key: key);
  }
}

class _MediaKitStream implements PlayerAdapterStream {
  final mk.Player player;
  _MediaKitStream(this.player);

  @override
  Stream<bool> get playing => player.stream.playing;
  @override
  Stream<Duration> get position => player.stream.position;
  @override
  Stream<Duration> get duration => player.stream.duration;
  @override
  Stream<bool> get completed => player.stream.completed;
  @override
  Stream<double> get volume => player.stream.volume;
  @override
  Stream<double> get rate => player.stream.rate;
  @override
  Stream<bool> get buffering => player.stream.buffering;
}

class _MediaKitState implements PlayerAdapterState {
  final mk.Player player;
  _MediaKitState(this.player);

  @override
  bool get playing => player.state.playing;
  @override
  Duration get position => player.state.position;
  @override
  Duration get duration => player.state.duration;
  @override
  double get volume => player.state.volume;
  @override
  double get rate => player.state.rate;
  @override
  bool get buffering => player.state.buffering;
  @override
  double get width => player.state.width?.toDouble() ?? 0;
  @override
  double get height => player.state.height?.toDouble() ?? 0;
}

/// video_player implementation (for mobile)
class VideoPlayerAdapter implements PlayerAdapter {
  final vp.VideoPlayerController controller;
  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<bool> _completedController = StreamController<bool>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  final StreamController<double> _rateController = StreamController<double>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();

  @override
  late final PlayerAdapterStream stream;
  @override
  late final PlayerAdapterState state;

  VideoPlayerAdapter(this.controller) {
    stream = _VideoPlayerStream(this);
    state = _VideoPlayerState(this);
    
    controller.addListener(_onControllerChanged);
  }

  bool _lastPlaying = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  double _lastVolume = 1.0;
  double _lastRate = 1.0;
  bool _lastBuffering = false;

  void _onControllerChanged() {
    if (controller.value.isPlaying != _lastPlaying) {
      _lastPlaying = controller.value.isPlaying;
      _playingController.add(_lastPlaying);
    }
    if (controller.value.position != _lastPosition) {
      _lastPosition = controller.value.position;
      _positionController.add(_lastPosition);
      
      // Check for completion
      if (controller.value.duration != Duration.zero && _lastPosition >= controller.value.duration) {
        _completedController.add(true);
      }
    }
    if (controller.value.duration != _lastDuration) {
      _lastDuration = controller.value.duration;
      _durationController.add(_lastDuration);
    }
    if (controller.value.volume != _lastVolume) {
      _lastVolume = controller.value.volume;
      _volumeController.add(_lastVolume * 100); // Scale to 0-100 to match media_kit
    }
    if (controller.value.playbackSpeed != _lastRate) {
      _lastRate = controller.value.playbackSpeed;
      _rateController.add(_lastRate);
    }
    if (controller.value.isBuffering != _lastBuffering) {
      _lastBuffering = controller.value.isBuffering;
      _bufferingController.add(_lastBuffering);
    }
  }

  @override
  Future<void> play() => controller.play();
  @override
  Future<void> pause() => controller.pause();
  @override
  Future<void> seek(Duration position) => controller.seekTo(position);
  @override
  Future<void> setRate(double rate) => controller.setPlaybackSpeed(rate);
  @override
  Future<void> setVolume(double volume) => controller.setVolume(volume / 100);
  
  @override
  Future<void> updateVideoFit(BoxFit fit) async {
    // Handled in buildVideo via FittedBox
  }
  
  @override
  Future<void> dispose() async {
    controller.removeListener(_onControllerChanged);
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
    await _volumeController.close();
    await _rateController.close();
    await _bufferingController.close();
    await controller.dispose();
  }

  @override
  Widget buildVideo(BuildContext context, {BoxFit fit = BoxFit.contain, Key? key, Widget Function(mkv.VideoState state)? controls}) {
    return Center(
      key: key,
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: vp.VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _VideoPlayerStream implements PlayerAdapterStream {
  final VideoPlayerAdapter adapter;
  _VideoPlayerStream(this.adapter);

  @override
  Stream<bool> get playing => adapter._playingController.stream;
  @override
  Stream<Duration> get position => adapter._positionController.stream;
  @override
  Stream<Duration> get duration => adapter._durationController.stream;
  @override
  Stream<bool> get completed => adapter._completedController.stream;
  @override
  Stream<double> get volume => adapter._volumeController.stream;
  @override
  Stream<double> get rate => adapter._rateController.stream;
  @override
  Stream<bool> get buffering => adapter._bufferingController.stream;
}

class _VideoPlayerState implements PlayerAdapterState {
  final VideoPlayerAdapter adapter;
  _VideoPlayerState(this.adapter);

  @override
  bool get playing => adapter.controller.value.isPlaying;
  @override
  Duration get position => adapter.controller.value.position;
  @override
  Duration get duration => adapter.controller.value.duration;
  @override
  double get volume => adapter.controller.value.volume * 100;
  @override
  double get rate => adapter.controller.value.playbackSpeed;
  @override
  bool get buffering => adapter.controller.value.isBuffering;
  @override
  double get width => adapter.controller.value.size.width;
  @override
  double get height => adapter.controller.value.size.height;
}

/// WebView-based player adapter (mobile + desktop online streams)
class WebViewPlayerAdapter implements PlayerAdapter {
  InAppWebViewController? _controller;
  final String url;
  final Map<String, String>? headers;
  final Duration? startAt;
  final bool adFilterEnabled;
  final bool seekBoostEnabled;

  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<bool> _completedController = StreamController<bool>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  final StreamController<double> _rateController = StreamController<double>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _rate = 1.0;
  bool _buffering = false;
  double _videoWidth = 0;  // 💡 新增
  double _videoHeight = 0; // 💡 新增
  bool _isDisposed = false;
  String? _hlsJsContent; // 缓存的 hls.js 源码内容

  @override
  late final PlayerAdapterStream stream;
  @override
  late final PlayerAdapterState state;

  final VoidCallback? onReady;

  WebViewPlayerAdapter({
    required this.url,
    this.headers,
    this.startAt,
    this.onReady,
    this.adFilterEnabled = false,
    this.seekBoostEnabled = false,
  }) {
    stream = _WebViewPlayerStream(this);
    state = _WebViewPlayerState(this);
  }

  void _setController(InAppWebViewController controller) {
    _controller = controller;
    _controller!.addJavaScriptHandler(
      handlerName: 'onPlayerEvent',
      callback: (args) {
        if (args.isEmpty) return;
        final event = args[0] as Map<String, dynamic>;
        _handlePlayerEvent(event);
      },
    );
    // 新增：处理 JS 回传的 hls.js 源码并持久化
    _controller!.addJavaScriptHandler(
      handlerName: 'saveHlsJs',
      callback: (args) {
        if (args.isNotEmpty && args[0] is String) {
          final content = args[0] as String;
          if (content.length > 1000) { // 简单校验
             _hlsJsContent = content;
             UserDataService.saveHlsJsCache(content);
          }
        }
      },
    );
  }

  void _handlePlayerEvent(Map<String, dynamic> event) {
    if (_isDisposed) return;

    final type = event['type'] as String?;
    switch (type) {
      case 'ready':
        onReady?.call();
        break;
      case 'play':
        _playing = true;
        if (!_playingController.isClosed) _playingController.add(true);
        break;
      case 'pause':
        _playing = false;
        if (!_playingController.isClosed) _playingController.add(false);
        break;
      case 'timeupdate':
        final seconds = (event['currentTime'] as num?)?.toDouble() ?? 0;
        _position = Duration(milliseconds: (seconds * 1000).round());
        if (!_positionController.isClosed) _positionController.add(_position);
        break;
      case 'durationchange':
        final seconds = (event['duration'] as num?)?.toDouble() ?? 0;
        _duration = Duration(milliseconds: (seconds * 1000).round());
        if (!_durationController.isClosed) _durationController.add(_duration);
        break;
      case 'ended':
        if (!_completedController.isClosed) _completedController.add(true);
        break;
      case 'volumechange':
        _volume = ((event['volume'] as num?)?.toDouble() ?? 1.0) * 100;
        if (!_volumeController.isClosed) _volumeController.add(_volume);
        break;
      case 'ratechange':
        _rate = (event['rate'] as num?)?.toDouble() ?? 1.0;
        if (!_rateController.isClosed) _rateController.add(_rate);
        break;
      case 'buffering':
        _buffering = event['value'] as bool? ?? false;
        if (!_bufferingController.isClosed) _bufferingController.add(_buffering);
        break;
      // 💡 新增：处理视频尺寸变化
      case 'sizechange':
        _videoWidth = (event['width'] as num?)?.toDouble() ?? 0;
        _videoHeight = (event['height'] as num?)?.toDouble() ?? 0;
        break;
    }
  }

  @override
  Future<void> play() async {
    await _controller?.evaluateJavascript(source: 'player.play();');
  }

  @override
  Future<void> pause() async {
    await _controller?.evaluateJavascript(source: 'player.pause();');
  }

  @override
  Future<void> seek(Duration position) async {
    final safePosition = position < Duration.zero ? Duration.zero : position;
    final seconds = safePosition.inMilliseconds / 1000;

    // 先在 Flutter 侧立即更新，避免拖动后进度条“回弹”。
    _position = safePosition;
    if (!_positionController.isClosed) {
      _positionController.add(_position);
    }

    await _controller?.evaluateJavascript(
      source: '''
        (function(targetSeconds) {
          var p = window.player || document.getElementById('player');
          if (!p) return;
          var sec = Math.max(0, Number(targetSeconds) || 0);
          if (typeof window.fastSeekTo === 'function') {
            window.fastSeekTo(sec);
            return;
          }
          try {
            if (typeof p.fastSeek === 'function') {
              p.fastSeek(sec);
            } else {
              p.currentTime = sec;
            }
          } catch (_) {
            p.currentTime = sec;
          }
        })($seconds);
      ''',
    );
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _controller?.evaluateJavascript(
        source: 'player.playbackRate = $rate;');
  }

  @override
  Future<void> setVolume(double volume) async {
    final normalized = volume / 100;
    await _controller?.evaluateJavascript(source: 'player.volume = $normalized;');
  }

  @override
  Future<void> updateVideoFit(BoxFit fit) async {
    String styleChanges =
        "v.style.objectFit = 'contain'; v.style.width = '100%'; v.style.height = '100%';";

    if (fit == BoxFit.fill) {
      styleChanges =
          "v.style.objectFit = 'fill'; v.style.width = '100%'; v.style.height = '100%';";
    } else if (fit == BoxFit.fitWidth) {
      styleChanges =
          "v.style.objectFit = 'contain'; v.style.width = '100%'; v.style.height = 'auto';";
    } else if (fit == BoxFit.fitHeight) {
      styleChanges =
          "v.style.objectFit = 'contain'; v.style.width = 'auto'; v.style.height = '100%';";
    } else if (fit == BoxFit.cover) {
      styleChanges =
          "v.style.objectFit = 'cover'; v.style.width = '100%'; v.style.height = '100%';";
    }

    await _controller?.evaluateJavascript(
        source:
            "var v = document.getElementById('player'); if(v) { $styleChanges }");
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
    await _volumeController.close();
    await _rateController.close();
    await _bufferingController.close();
  }

  @override
  Widget buildVideo(BuildContext context,
      {BoxFit fit = BoxFit.contain, Key? key, Widget Function(mkv.VideoState state)? controls}) {
    return _WebViewPlayer(
      key: key,
      adapter: this,
      fit: fit,
    );
  }

  String _buildHtmlContent() {
    final startSeconds = startAt != null ? startAt!.inMilliseconds / 1000 : 0;
    final adFilterEnabledJs = adFilterEnabled ? 'true' : 'false';
    final seekBoostEnabledJs = seekBoostEnabled ? 'true' : 'false';

    // 如果有缓存内容，则注入内联脚本；否则使用 CDN 链接
    final hlsJsTag = (_hlsJsContent != null && _hlsJsContent!.isNotEmpty)
        ? '<script id="hls-script">$_hlsJsContent</script>'
        : '<script id="hls-script" src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #000; overflow: hidden; display: flex; align-items: center; justify-content: center; }
    video { width: 100%; height: 100%; object-fit: contain; }
  </style>
  $hlsJsTag
</head>
<body>
  <video id="player" playsinline></video>
  <script>
    var player = document.getElementById('player');
    window.player = player;
    window.hlsInstance = null;
    var lastFastSeekSec = -1;
    var lastFastSeekTs = 0;
    var videoUrl = '$url';
    var startTime = $startSeconds;
    var adFilterEnabled = $adFilterEnabledJs;
    var seekBoostEnabled = $seekBoostEnabledJs;

    // 如果是通过 CDN 加载的，尝试获取源码并回传给 Flutter 缓存
    var hlsScript = document.getElementById('hls-script');
    if (hlsScript && hlsScript.src && window.Hls) {
       fetch(hlsScript.src)
         .then(response => response.text())
         .then(code => {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('saveHlsJs', code);
            }
         }).catch(e => console.error('Cache HLS.js failed', e));
    }

    // 原始广告过滤逻辑（仅过滤不连续标记）
    function filterAdsFromM3U8(m3u8Content) {
      if (!m3u8Content) return '';
      var lines = m3u8Content.split('\\n');
      var filteredLines = [];
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (!line.includes('#EXT-X-DISCONTINUITY')) {
          filteredLines.push(line);
        }
      }
      return filteredLines.join('\\n');
    }

    // 增强型广告过滤逻辑（过滤多种已知广告标签）
    function filterAdsEnhanced(m3u8Content) {
      if (!m3u8Content) return '';
      var lines = m3u8Content.split('\\n');
      var filteredLines = [];
      var adPatterns = [
        '#EXT-X-DISCONTINUITY',
        '#EXT-X-CUE-OUT',
        '#EXT-X-CUE-IN',
        '#EXT-X-CUE-OUT-CONT',
        '#EXT-X-CUE',
        '#EXT-X-PLACEMENT-OPPORTUNITY',
        '#EXT-OATCLS-SCTE35',
        '#EXT-X-SCTE35',
        '#EXT-X-VERSION:AD',
        '#EXT-X-AD-STREAMING'
      ];

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var isAdLine = false;
        for (var j = 0; j < adPatterns.length; j++) {
          if (line.indexOf(adPatterns[j]) !== -1) {
            isAdLine = true;
            break;
          }
        }
        if (!isAdLine) {
          filteredLines.push(line);
        }
      }
      return filteredLines.join('\\n');
    }

    function sendEvent(type, data) {
      var event = Object.assign({ type: type }, data || {});
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onPlayerEvent', event);
      }
    }

    function fastSeekTo(targetSeconds) {
      if (!player) return;
      var sec = Math.max(0, Number(targetSeconds) || 0);
      var now = Date.now();
      if (Math.abs(lastFastSeekSec - sec) < 0.05 && (now - lastFastSeekTs) < 50) {
        return;
      }
      lastFastSeekSec = sec;
      lastFastSeekTs = now;

      try {
        if (typeof player.fastSeek === 'function') {
          player.fastSeek(sec);
        } else {
          player.currentTime = sec;
        }
      } catch (e) {
        player.currentTime = sec;
      }

      try {
        if (seekBoostEnabled && window.hlsInstance && typeof window.hlsInstance.startLoad === 'function') {
          window.hlsInstance.startLoad(sec);
        }
      } catch (e) {}

      sendEvent('timeupdate', { currentTime: sec });
    }

    window.fastSeekTo = fastSeekTo;

    if (player) {
      player.addEventListener('play', function() { sendEvent('play'); });
      player.addEventListener('pause', function() { sendEvent('pause'); });
      player.addEventListener('ended', function() { sendEvent('ended'); });
      player.addEventListener('volumechange', function() { sendEvent('volumechange', { volume: player.volume }); });
      player.addEventListener('ratechange', function() { sendEvent('ratechange', { rate: player.playbackRate }); });
      player.addEventListener('timeupdate', function() { sendEvent('timeupdate', { currentTime: player.currentTime }); });
      player.addEventListener('durationchange', function() { sendEvent('durationchange', { duration: player.duration }); });
      
      // 💡 新增：监听视频尺寸
      player.addEventListener('loadedmetadata', function() {
        if (startTime > 0) player.currentTime = startTime;
        sendEvent('ready');
        sendEvent('sizechange', { width: player.videoWidth, height: player.videoHeight });
      });

      player.addEventListener('resize', function() {
        sendEvent('sizechange', { width: player.videoWidth, height: player.videoHeight });
      });

      // Buffering events
      player.addEventListener('waiting', function() { sendEvent('buffering', { value: true }); });
      player.addEventListener('canplay', function() { sendEvent('buffering', { value: false }); });
      player.addEventListener('playing', function() { sendEvent('buffering', { value: false }); });
      player.addEventListener('seeking', function() { sendEvent('buffering', { value: true }); });
      player.addEventListener('seeked', function() {
        sendEvent('buffering', { value: false });
        sendEvent('timeupdate', { currentTime: player.currentTime });
      });

      player.addEventListener('loadedmetadata', function() {
        if (startTime > 0) player.currentTime = startTime;
        sendEvent('ready');
      });
    }

    var isM3u8 = videoUrl.includes('.m3u8') || videoUrl.includes('.M3U8') || videoUrl.startsWith('data:application/vnd.apple.mpegurl') || videoUrl.startsWith('data:application/x-mpegURL');

    if (isM3u8) {
      if (typeof Hls !== 'undefined' && Hls.isSupported()) {
        var config = { enableWorker: true, lowLatencyMode: true };
        if (seekBoostEnabled) {
          config.maxBufferLength = 8;
          config.maxMaxBufferLength = 16;
          config.backBufferLength = 30;
          config.nudgeMaxRetry = 1;
          config.maxFragLookUpTolerance = 0.1;
          config.maxBufferHole = 0.1;
        }
        
        if (adFilterEnabled) {
          class CustomHlsJsLoader extends Hls.DefaultConfig.loader {
            constructor(config) {
              super(config);
              var load = this.load.bind(this);
              this.load = function (context, config, callbacks) {
                if (context.type === 'manifest' || context.type === 'level') {
                  var onSuccess = callbacks.onSuccess;
                  callbacks.onSuccess = function (response, stats, context) {
                    if (response.data && typeof response.data === 'string') {
                      // 使用增强型过滤逻辑
                      response.data = filterAdsEnhanced(response.data);
                    }
                    return onSuccess(response, stats, context, null);
                  };
                }
                load(context, config, callbacks);
              };
            }
          }
          config.loader = CustomHlsJsLoader;
        }

        var hls = new Hls(config);
        window.hlsInstance = hls;
        hls.loadSource(videoUrl);
        if (player) {
          hls.attachMedia(player);
          hls.on(Hls.Events.MANIFEST_PARSED, function() { player.play(); });
        }
      } else if (player && player.canPlayType('application/vnd.apple.mpegurl')) {
        player.src = videoUrl;
        player.addEventListener('loadedmetadata', function() { player.play(); });
      }
    } else if (player) {
      player.src = videoUrl;
      player.play();
    }
  </script>
</body>
</html>
''';
  }
}

class _WebViewPlayer extends StatefulWidget {
  final WebViewPlayerAdapter adapter;
  final BoxFit fit;

  const _WebViewPlayer({super.key, required this.adapter, required this.fit});

  @override
  State<_WebViewPlayer> createState() => _WebViewPlayerState2();
}

class _WebViewPlayerState2 extends State<_WebViewPlayer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initHlsCache();
  }

  Future<void> _initHlsCache() async {
    final cached = await UserDataService.getHlsJsCache();
    if (mounted) {
      setState(() {
        widget.adapter._hlsJsContent = cached;
        _initialized = true;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _WebViewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adapter != oldWidget.adapter) {
      widget.adapter._controller?.loadData(
        data: widget.adapter._buildHtmlContent(),
        baseUrl: WebUri('https://localhost'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(color: Colors.black);
    }

    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useHybridComposition: true,
        transparentBackground: true,
      ),
      initialData: InAppWebViewInitialData(
        data: widget.adapter._buildHtmlContent(),
        baseUrl: WebUri('https://localhost'),
      ),
      onWebViewCreated: (controller) {
        widget.adapter._setController(controller);
      },
    );
  }
}

class _WebViewPlayerStream implements PlayerAdapterStream {
  final WebViewPlayerAdapter adapter;
  _WebViewPlayerStream(this.adapter);

  @override
  Stream<bool> get playing => adapter._playingController.stream;
  @override
  Stream<Duration> get position => adapter._positionController.stream;
  @override
  Stream<Duration> get duration => adapter._durationController.stream;
  @override
  Stream<bool> get completed => adapter._completedController.stream;
  @override
  Stream<double> get volume => adapter._volumeController.stream;
  @override
  Stream<double> get rate => adapter._rateController.stream;
  @override
  Stream<bool> get buffering => adapter._bufferingController.stream;
}

class _WebViewPlayerState implements PlayerAdapterState {
  final WebViewPlayerAdapter adapter;
  _WebViewPlayerState(this.adapter);

  @override
  bool get playing => adapter._playing;
  @override
  Duration get position => adapter._position;
  @override
  Duration get duration => adapter._duration;
  @override
  double get volume => adapter._volume;
  @override
  double get rate => adapter._rate;
  @override
  bool get buffering => adapter._buffering;
  @override
  double get width => adapter._videoWidth;
  @override
  double get height => adapter._videoHeight;
}
