import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:video_player/video_player.dart' as vp;

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

  Widget buildVideo(BuildContext context,
      {BoxFit fit, Key? key, Widget Function(mkv.VideoState state)? controls});
}

Future<void> seekPlayerAndNotify({
  required PlayerAdapter player,
  required Duration position,
  ValueChanged<Duration>? onSeek,
  bool notifyBeforeSeek = false,
}) async {
  if (notifyBeforeSeek) {
    onSeek?.call(position);
  }
  await player.seek(position);
  if (!notifyBeforeSeek) {
    onSeek?.call(position);
  }
}

Future<void> seekPlayerAndNotifyAsync({
  required PlayerAdapter player,
  required Duration position,
  ValueChanged<Duration>? onSeek,
}) async {
  await player.seek(position);
  if (onSeek == null) {
    return;
  }
  Future<void>(() {
    try {
      onSeek(position);
    } catch (error, stackTrace) {
      debugPrint('seekPlayerAndNotifyAsync callback failed: $error');
      debugPrint('$stackTrace');
    }
  });
}

abstract class PlayerAdapterStream {
  Stream<bool> get playing;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<bool> get completed;
  Stream<double> get volume;
  Stream<double> get rate;
  Stream<bool> get buffering;
}

abstract class PlayerAdapterState {
  bool get playing;
  Duration get position;
  Duration get duration;
  Duration get buffer;
  double get volume;
  double get rate;
  bool get buffering;
  double get width; // 💡 新增：视频原始宽度
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
  Widget buildVideo(BuildContext context,
      {BoxFit fit = BoxFit.contain,
      Key? key,
      Widget Function(mkv.VideoState state)? controls}) {
    return mkv.Video(
        controller: videoController, fit: fit, controls: controls, key: key);
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
  Stream<Duration> get buffer => player.stream.buffer;
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
  Duration get buffer => player.state.buffer;
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
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  final StreamController<double> _rateController =
      StreamController<double>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();

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
      if (controller.value.duration != Duration.zero &&
          _lastPosition >= controller.value.duration) {
        _completedController.add(true);
      }
    }
    if (controller.value.duration != _lastDuration) {
      _lastDuration = controller.value.duration;
      _durationController.add(_lastDuration);
    }
    if (controller.value.volume != _lastVolume) {
      _lastVolume = controller.value.volume;
      _volumeController
          .add(_lastVolume * 100); // Scale to 0-100 to match media_kit
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
  Widget buildVideo(BuildContext context,
      {BoxFit fit = BoxFit.contain,
      Key? key,
      Widget Function(mkv.VideoState state)? controls}) {
    final videoSize = controller.value.size;
    final width = videoSize.width > 0 ? videoSize.width : 1.0;
    final height = videoSize.height > 0 ? videoSize.height : 1.0;

    return SizedBox.expand(
      key: key,
      child: FittedBox(
        fit: fit,
        alignment: Alignment.center,
        child: SizedBox(
          width: width,
          height: height,
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
  Stream<Duration> get buffer =>
      const Stream<Duration>.empty().asBroadcastStream();
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
  Duration get buffer => adapter.controller.value.duration;
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

  /// 进度拖放搜索预热并行性（代码可配置）
  static const int defaultSeekWarmupConcurrency = 2;
  static int seekWarmupConcurrency = defaultSeekWarmupConcurrency;

  /// 每次搜索需要预热多少个接近目标的片段
  static const int defaultSeekWarmupSegmentCount = 4;
  static int seekWarmupSegmentCount = defaultSeekWarmupSegmentCount;

  /// 每个预热请求的最大读取字节数
  static const int defaultSeekWarmupReadBytes = 256 * 1024;
  static int seekWarmupReadBytes = defaultSeekWarmupReadBytes;

  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  final StreamController<double> _rateController =
      StreamController<double>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _rate = 1.0;
  bool _buffering = false;
  double _videoWidth = 0; // 💡 新增
  double _videoHeight = 0; // 💡 新增
  bool _isDisposed = false;
  int _suppressTransientBufferingUntilMs = 0;

  @override
  late final PlayerAdapterStream stream;
  @override
  late final PlayerAdapterState state;

  final VoidCallback? onReady;
  final ValueChanged<String>? onDebugToast;
  String? _lastDebugToastMessage;
  int _lastDebugToastAtMs = 0;

  WebViewPlayerAdapter({
    required this.url,
    this.headers,
    this.startAt,
    this.onReady,
    this.onDebugToast,
    this.adFilterEnabled = false,
    this.seekBoostEnabled = false,
  }) {
    stream = _WebViewPlayerStream(this);
    state = _WebViewPlayerState(this);
  }

  void _suppressTransientBuffering(Duration duration) {
    final nextUntil =
        DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
    if (nextUntil > _suppressTransientBufferingUntilMs) {
      _suppressTransientBufferingUntilMs = nextUntil;
    }
  }

  bool get _isSuppressingTransientBuffering {
    return DateTime.now().millisecondsSinceEpoch <
        _suppressTransientBufferingUntilMs;
  }

  void _emitDebugToast(String message) {
    if (!Platform.isIOS || onDebugToast == null) {
      return;
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastDebugToastMessage == trimmed && now - _lastDebugToastAtMs < 1500) {
      return;
    }
    _lastDebugToastMessage = trimmed;
    _lastDebugToastAtMs = now;
    onDebugToast?.call(trimmed);
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
        if (!_durationController.isClosed) {
          _durationController.add(_duration);
        }
        break;
      case 'ended':
        if (!_completedController.isClosed) {
          _completedController.add(true);
        }
        break;
      case 'volumechange':
        _volume = ((event['volume'] as num?)?.toDouble() ?? 1.0) * 100;
        if (!_volumeController.isClosed) {
          _volumeController.add(_volume);
        }
        break;
      case 'ratechange':
        _rate = (event['rate'] as num?)?.toDouble() ?? 1.0;
        if (!_rateController.isClosed) {
          _rateController.add(_rate);
        }
        break;
      case 'debug':
        final message = (event['message'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          _emitDebugToast(message);
        }
        break;
      case 'buffering':
        final nextBuffering = event['value'] as bool? ?? false;
        if (nextBuffering && _isSuppressingTransientBuffering) {
          break;
        }
        _buffering = nextBuffering;
        if (!_bufferingController.isClosed) {
          _bufferingController.add(_buffering);
        }
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
    if (Platform.isIOS) {
      _suppressTransientBuffering(
        Duration(milliseconds: rate > 1.0 ? 420 : 320),
      );
    }
    await _controller?.evaluateJavascript(
      source: '''
        (function(nextRate) {
          var p = window.player || document.getElementById('player');
          if (!p) return;
          var targetRate = Number(nextRate) || 1.0;
          var previousRate = Number(p.playbackRate) || 1.0;
          var previousRequestedRate = Number(window.__lastRequestedRate);
          if (!(previousRequestedRate > 0)) {
            previousRequestedRate = previousRate;
          }
          var ua = navigator.userAgent || '';
          var isIOS = /iPad|iPhone|iPod/.test(ua);
          var anchorTime = Number(p.currentTime) || 0;
          var shouldStabilize = isIOS && !p.paused;
          var isSpeedingUp = targetRate > previousRequestedRate + 0.01;
          var isSlowingDown = targetRate + 0.01 < previousRequestedRate;
          var rateChangeKind = isSpeedingUp ? '按下' : (isSlowingDown ? '松开' : '切换');
          var commandId = (Number(window.__lastRateCommandId) || 0) + 1;
          window.__lastRateCommandId = commandId;
          window.__lastRequestedFromRate = previousRequestedRate;
          window.__lastRequestedRate = targetRate;
          window.__lastRateAction = rateChangeKind;
          window.__lastRateAnchorTime = anchorTime;
          window.__lastRateEventSeq = 0;
          window.__lastRateChangeAt = Date.now();
          window.__lastRateChangeDesc =
              previousRequestedRate.toFixed(2) + 'x->' + targetRate.toFixed(2) + 'x';
          var shouldStabilizeRollback =
              shouldStabilize &&
              isSlowingDown &&
              targetRate <= 1.01 &&
              previousRequestedRate >= 1.90;
          var suppressionMs = isIOS ? (targetRate > 1.0 ? 420 : 320) : 0;
          try {
            if (suppressionMs > 0 &&
                typeof window.beginRateChangeBufferingSuppression === 'function') {
              window.beginRateChangeBufferingSuppression(suppressionMs);
            }
          } catch (_) {}
          try {
            if (!isIOS) {
              p.defaultPlaybackRate = targetRate;
            }
          } catch (_) {}
          try {
            if (isIOS &&
                typeof window.setIOSPitchPreservation === 'function') {
              var beforePitchEnabled = window.__iosPitchEnabled !== false;
              var changedPitchState =
                  window.setIOSPitchPreservation(true, p) &&
                  beforePitchEnabled !== (window.__iosPitchEnabled !== false);
              if (changedPitchState &&
                  typeof window.emitPlayerDebug === 'function') {
                window.emitPlayerDebug(
                  '保音调' +
                  (window.__iosPitchEnabled !== false ? '恢复' : '关闭') +
                  ' req' + previousRequestedRate.toFixed(2) +
                  '->' + targetRate.toFixed(2)
                );
              }
            }
          } catch (_) {}
          try {
            p.playbackRate = targetRate;
          } catch (_) {}
          if (isIOS &&
              Math.abs(targetRate - previousRequestedRate) >= 0.01 &&
              typeof window.emitPlayerDebug === 'function') {
            window.emitPlayerDebug(
              '倍速请求#' + commandId +
              ' ' + rateChangeKind +
              ' req' + previousRequestedRate.toFixed(2) +
              '->' + targetRate.toFixed(2) +
              ' act' + previousRate.toFixed(2) +
              ' 锚' + anchorTime.toFixed(2) + 's'
            );
            if (typeof window.scheduleRateSamples === 'function') {
              window.scheduleRateSamples(rateChangeKind, anchorTime, p);
            }
            if (typeof window.scheduleSeekingRecovery === 'function') {
              window.scheduleSeekingRecovery(anchorTime, commandId, p);
            }
            if (typeof window.scheduleFrozenPlaybackWakeup === 'function') {
              window.scheduleFrozenPlaybackWakeup(anchorTime, commandId, p);
            }
          }

          if (!shouldStabilizeRollback) {
            return;
          }

          var stabilizationToken = (window.__rateStabilizationToken || 0) + 1;
          window.__rateStabilizationToken = stabilizationToken;

          var furthestTime = anchorTime;
          function observePlaybackProgress() {
            if (!p || window.__rateStabilizationToken !== stabilizationToken) {
              return;
            }
            var now = Number(p.currentTime) || 0;
            if (now > furthestTime) {
              furthestTime = now;
            }
          }

          function softlyRestoreProgress() {
            if (!p ||
                window.__rateStabilizationToken !== stabilizationToken ||
                p.paused) {
              return;
            }
            observePlaybackProgress();
            var readyState = Number(p.readyState) || 0;
            if (p.seeking || readyState < 4) {
              if (typeof window.emitPlayerDebug === 'function') {
                var recovered = tryRecoverStuckSeeking(
                  '校正前恢复',
                  p,
                  anchorTime,
                  260
                );
                emitRateState(
                  '校正前检查',
                  p,
                  anchorTime,
                  (recovered ? '已尝试恢复' : '未执行') +
                      ' ready=' + readyState +
                      ' seek=' + (p.seeking ? '1' : '0')
                );
              }
              return;
            }
            var now = Number(p.currentTime) || 0;
            var rollbackGap = anchorTime - now;
            if (rollbackGap >= 0.20 &&
                rollbackGap < 0.72 &&
                typeof window.emitPlayerDebug === 'function') {
              emitRateState(
                '轻微回退',
                p,
                anchorTime,
                'gap=' + rollbackGap.toFixed(2) + 's 未校正'
              );
              return;
            }
            if (rollbackGap < 0.72) {
              return;
            }
            if (furthestTime > anchorTime + 0.03) {
              if (typeof window.emitPlayerDebug === 'function') {
                emitRateState(
                  '回退跳过',
                  p,
                  anchorTime,
                  'gap=' + rollbackGap.toFixed(2) + 's furthest=' + furthestTime.toFixed(2)
                );
              }
              return;
            }
            var desired = Math.max(anchorTime + 0.012, now + 0.006);
            try {
              p.currentTime = desired;
              if (typeof window.emitPlayerDebug === 'function') {
                emitRateState(
                  '回退已校正',
                  p,
                  anchorTime,
                  'gap=' + rollbackGap.toFixed(2) + 's -> ' + desired.toFixed(2) + 's'
                );
              }
            } catch (_) {}
          }

          setTimeout(observePlaybackProgress, 260);
          setTimeout(observePlaybackProgress, 560);
          setTimeout(softlyRestoreProgress, 980);
        })($rate);
      ''',
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    final normalized = volume / 100;
    await _controller?.evaluateJavascript(
        source: 'player.volume = $normalized;');
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
      {BoxFit fit = BoxFit.contain,
      Key? key,
      Widget Function(mkv.VideoState state)? controls}) {
    return _WebViewPlayer(
      key: key,
      adapter: this,
      fit: fit,
    );
  }

  String _buildHtmlContent() {
    final startSeconds = startAt != null ? startAt!.inMilliseconds / 1000 : 0;
    final adFilterEnabledJs = adFilterEnabled ? 'true' : 'false';
    final seekBoostEnabledJs = seekBoostEnabled ? 'false' : 'false'; // 暂时先关闭该功能
    final seekWarmupConcurrencyJs =
        seekWarmupConcurrency < 1 ? 1 : seekWarmupConcurrency;
    final seekWarmupSegmentCountJs =
        seekWarmupSegmentCount < 1 ? 1 : seekWarmupSegmentCount;
    final seekWarmupReadBytesJs =
        seekWarmupReadBytes < 65536 ? 65536 : seekWarmupReadBytes;

    const hlsJsTag =
        '<script id="hls-script" src="selene-asset://assets/js/hls.min.js"></script>';

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
    var seekWarmupConcurrency = $seekWarmupConcurrencyJs;
    var seekWarmupSegmentCount = $seekWarmupSegmentCountJs;
    var seekWarmupReadBytes = $seekWarmupReadBytesJs;
    var seekWarmupControllers = [];
    var seekWarmupToken = 0;

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

    window.__lastPlayerDebugAt = 0;
    window.__lastPlayerDebugMessage = '';
    window.__lastRateChangeAt = 0;
    window.__lastRateChangeDesc = '';
    window.__lastRateCommandId = 0;
    window.__lastRequestedRate = 1.0;
    window.__lastRequestedFromRate = 1.0;
    window.__lastRateAction = '';
    window.__lastRateAnchorTime = 0;
    window.__lastRateEventSeq = 0;
    window.__rateDiagnosticToken = 0;

    function emitPlayerDebug(message) {
      var text = String(message || '').trim();
      if (!text) return;
      var now = Date.now();
      if (window.__lastPlayerDebugMessage === text &&
          now - (window.__lastPlayerDebugAt || 0) < 1200) {
        return;
      }
      window.__lastPlayerDebugMessage = text;
      window.__lastPlayerDebugAt = now;
      sendEvent('debug', { message: text });
    }
    window.emitPlayerDebug = emitPlayerDebug;

    function getRateDebugContext(currentPlayer, fallbackAnchorTime) {
      var p = currentPlayer || window.player || document.getElementById('player');
      var reqFrom = Number(window.__lastRequestedFromRate);
      if (!(reqFrom > 0)) {
        reqFrom = p ? (Number(p.playbackRate) || 1.0) : 1.0;
      }
      var reqTo = Number(window.__lastRequestedRate);
      if (!(reqTo > 0)) {
        reqTo = p ? (Number(p.playbackRate) || 1.0) : 1.0;
      }
      var anchorTime = Number(window.__lastRateAnchorTime);
      if (!(anchorTime >= 0)) {
        anchorTime = Number(fallbackAnchorTime) || 0;
      }
      return {
        player: p,
        commandId: Number(window.__lastRateCommandId) || 0,
        action: String(window.__lastRateAction || '切换'),
        reqFrom: reqFrom,
        reqTo: reqTo,
        anchorTime: anchorTime,
        now: p ? (Number(p.currentTime) || 0) : 0,
        readyState: p ? (Number(p.readyState) || 0) : 0,
        actualRate: p ? (Number(p.playbackRate) || 0) : 0,
        seeking: !!(p && p.seeking),
        paused: !!(p && p.paused),
        elapsedMs: Math.max(0, Date.now() - (window.__lastRateChangeAt || 0))
      };
    }

    function emitRateState(label, currentPlayer, fallbackAnchorTime, extraText) {
      if (typeof window.emitPlayerDebug !== 'function') {
        return;
      }
      var context = getRateDebugContext(currentPlayer, fallbackAnchorTime);
      var message =
        '#' + context.commandId +
        ' ' + context.action +
        ' ' + label +
        ' req' + context.reqFrom.toFixed(2) + '->' + context.reqTo.toFixed(2) +
        ' act' + context.actualRate.toFixed(2) +
        ' +' + context.elapsedMs + 'ms' +
        ' 当前' + context.now.toFixed(2) +
        ' 差' + (context.now - context.anchorTime).toFixed(2) +
        ' rs' + context.readyState +
        ' seek' + (context.seeking ? '1' : '0') +
        ' pause' + (context.paused ? '1' : '0');
      if (extraText) {
        message += ' ' + extraText;
      }
      window.emitPlayerDebug(message);
    }

    function emitRecentRateEvent(eventName, currentPlayer) {
      if ((Date.now() - (window.__lastRateChangeAt || 0)) >= 1600 ||
          typeof window.emitPlayerDebug !== 'function') {
        return;
      }
      var p = currentPlayer || window.player || document.getElementById('player');
      window.__lastRateEventSeq = (window.__lastRateEventSeq || 0) + 1;
      emitRateState(
        '事件' + window.__lastRateEventSeq + ':' + eventName,
        p
      );
    }

    function emitRateSample(label, anchorTime, currentPlayer) {
      var p = currentPlayer || window.player || document.getElementById('player');
      if (!p) {
        return;
      }
      emitRateState(label, p, anchorTime);
    }

    function tryRecoverStuckSeeking(label, currentPlayer, fallbackAnchorTime, minElapsedMs) {
      var context = getRateDebugContext(currentPlayer, fallbackAnchorTime);
      var p = context.player;
      if (!p || context.paused) {
        return false;
      }
      if (context.readyState < 4 || !context.seeking) {
        return false;
      }
      if (context.elapsedMs < minElapsedMs) {
        return false;
      }
      if (Math.abs(context.now - context.anchorTime) > 0.08) {
        return false;
      }
      var desired = Math.max(context.anchorTime + 0.01, context.now + 0.01);
      try {
        p.currentTime = desired;
        emitRateState(
          label,
          p,
          fallbackAnchorTime,
          '执行轻推 -> ' + desired.toFixed(2) + 's'
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    function tryWakeFrozenPlayback(
      label,
      currentPlayer,
      fallbackAnchorTime,
      minElapsedMs,
      minProgress
    ) {
      var context = getRateDebugContext(currentPlayer, fallbackAnchorTime);
      var p = context.player;
      if (!p || context.paused) {
        return false;
      }
      if (context.readyState < 4 || context.seeking) {
        return false;
      }
      if (context.elapsedMs < minElapsedMs) {
        return false;
      }
      var progress = context.now - context.anchorTime;
      if (progress >= minProgress) {
        return false;
      }
      try {
        var playResult = p.play();
        if (playResult && typeof playResult.catch === 'function') {
          playResult.catch(function() {});
        }
        emitRateState(
          label,
          p,
          fallbackAnchorTime,
          '补play progress=' + progress.toFixed(2) +
              ' < ' + minProgress.toFixed(2)
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    function scheduleRateSamples(kind, anchorTime, currentPlayer) {
      if (typeof window.emitPlayerDebug !== 'function') {
        return;
      }
      var token = (window.__rateDiagnosticToken || 0) + 1;
      window.__rateDiagnosticToken = token;
      var delays = [20, 60, 120, 220, 360, 520, 820, 1200];
      for (var i = 0; i < delays.length; i++) {
        (function(index, delay) {
          setTimeout(function() {
            if (token !== window.__rateDiagnosticToken) {
              return;
            }
            var p = currentPlayer || window.player || document.getElementById('player');
            if (!p) {
              return;
            }
            emitRateSample('采样' + (index + 1), anchorTime, p);
          }, delay);
        })(i, delays[i]);
      }
    }
    window.scheduleRateSamples = scheduleRateSamples;

    function scheduleSeekingRecovery(anchorTime, commandId, currentPlayer) {
      if (typeof window.emitPlayerDebug !== 'function') {
        return;
      }
      var delays = [140, 320, 620];
      for (var i = 0; i < delays.length; i++) {
        (function(index, delay) {
          setTimeout(function() {
            if ((Number(window.__lastRateCommandId) || 0) !== commandId) {
              return;
            }
            var p = currentPlayer || window.player || document.getElementById('player');
            if (!p) {
              return;
            }
            tryRecoverStuckSeeking(
              '卡住恢复' + (index + 1),
              p,
              anchorTime,
              delay - 20
            );
          }, delay);
        })(i, delays[i]);
      }
    }
    window.scheduleSeekingRecovery = scheduleSeekingRecovery;

    function scheduleFrozenPlaybackWakeup(anchorTime, commandId, currentPlayer) {
      var steps = [
        { delay: 80, minElapsedMs: 60, minProgress: 0.03 },
        { delay: 180, minElapsedMs: 140, minProgress: 0.08 },
        { delay: 320, minElapsedMs: 260, minProgress: 0.12 }
      ];
      for (var i = 0; i < steps.length; i++) {
        (function(index, step) {
          setTimeout(function() {
            if ((Number(window.__lastRateCommandId) || 0) !== commandId) {
              return;
            }
            var p = currentPlayer || window.player || document.getElementById('player');
            if (!p) {
              return;
            }
            tryWakeFrozenPlayback(
              '停表唤醒' + (index + 1),
              p,
              anchorTime,
              step.minElapsedMs,
              step.minProgress
            );
          }, step.delay);
        })(i, steps[i]);
      }
    }
    window.scheduleFrozenPlaybackWakeup = scheduleFrozenPlaybackWakeup;

    function removeWarmupController(controller) {
      if (!controller) return;
      var idx = seekWarmupControllers.indexOf(controller);
      if (idx >= 0) {
        seekWarmupControllers.splice(idx, 1);
      }
    }

    function cancelSeekWarmup() {
      seekWarmupToken++;
      for (var i = 0; i < seekWarmupControllers.length; i++) {
        try {
          seekWarmupControllers[i].abort();
        } catch (_) {}
      }
      seekWarmupControllers = [];
    }
    window.cancelSeekWarmup = cancelSeekWarmup;

    function getActiveLevelDetails() {
      if (!window.hlsInstance) return null;
      var hls = window.hlsInstance;
      var levelIndex = -1;

      if (typeof hls.currentLevel === 'number' && hls.currentLevel >= 0) {
        levelIndex = hls.currentLevel;
      } else if (typeof hls.nextAutoLevel === 'number' && hls.nextAutoLevel >= 0) {
        levelIndex = hls.nextAutoLevel;
      }

      if (levelIndex < 0 || !hls.levels || !hls.levels[levelIndex]) {
        return null;
      }

      var level = hls.levels[levelIndex];
      if (!level || !level.details || !level.details.fragments) {
        return null;
      }

      return level.details;
    }

    function collectWarmupUrls(targetSeconds) {
      var details = getActiveLevelDetails();
      if (!details || !details.fragments || details.fragments.length === 0) {
        return [];
      }

      var fragments = details.fragments;
      var startIndex = 0;
      for (var i = 0; i < fragments.length; i++) {
        var frag = fragments[i];
        var fragStart = Number(frag.start) || 0;
        var fragDuration = Number(frag.duration) || 0;
        var fragEnd = fragStart + Math.max(0.1, fragDuration);
        if (targetSeconds < fragEnd) {
          startIndex = i;
          break;
        }
        if (i === fragments.length - 1) {
          startIndex = i;
        }
      }

      var urls = [];
      var maxCount = Math.max(1, seekWarmupSegmentCount);
      for (var j = startIndex; j < fragments.length && urls.length < maxCount; j++) {
        var nextUrl = fragments[j] && fragments[j].url;
        if (nextUrl && urls.indexOf(nextUrl) < 0) {
          urls.push(nextUrl);
        }
      }
      return urls;
    }

    function warmupByConcurrentFetch(targetSeconds) {
      if (!seekBoostEnabled || !window.hlsInstance) return;

      var urls = collectWarmupUrls(targetSeconds);
      if (!urls.length) return;

      cancelSeekWarmup();
      var token = seekWarmupToken;
      var queue = urls.slice();
      var active = 0;
      var maxConcurrency = Math.max(1, seekWarmupConcurrency);
      var maxReadBytes = Math.max(65536, seekWarmupReadBytes);

      function runNext() {
        if (token !== seekWarmupToken) return;

        while (active < maxConcurrency && queue.length > 0) {
          let nextUrl = queue.shift();
          if (!nextUrl) {
            continue;
          }
          active++;

          let controller = null;
          try {
            if (typeof AbortController !== 'undefined') {
              controller = new AbortController();
              seekWarmupControllers.push(controller);
            }
          } catch (_) {}

          let options = {
            method: 'GET',
            cache: 'force-cache',
          };
          if (controller && controller.signal) {
            options.signal = controller.signal;
          }

          const task = fetch(nextUrl, options).then(function(response) {
            if (!response || !response.body || !response.body.getReader) {
              return;
            }

            var reader = response.body.getReader();
            var readBytes = 0;

            function readChunk() {
              return reader.read().then(function(result) {
                if (!result || result.done) {
                  return;
                }

                if (result.value && result.value.byteLength) {
                  readBytes += result.value.byteLength;
                }

                if (readBytes >= maxReadBytes) {
                  try {
                    reader.cancel();
                  } catch (_) {}
                  return;
                }

                return readChunk();
              });
            }

            return readChunk().catch(function() {});
          }).catch(function() {});

          task.then(function() {
            removeWarmupController(controller);
            active--;
            runNext();
          });
        }
      }

      runNext();
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

      warmupByConcurrentFetch(sec);

      sendEvent('timeupdate', { currentTime: sec });
    }

    window.fastSeekTo = fastSeekTo;
    window.__iosPitchConfigured = false;
    window.__iosPitchEnabled = true;
    window.__iosPitchBeforeBoost = true;

    function setIOSPitchPreservation(enabled, currentPlayer) {
      var p = currentPlayer || window.player || document.getElementById('player');
      if (!p) {
        return false;
      }
      var ua = navigator.userAgent || '';
      var isIOS = /iPad|iPhone|iPod/.test(ua);
      if (!isIOS) {
        return false;
      }
      var desired = enabled !== false;
      try {
        if ('preservesPitch' in p) {
          p.preservesPitch = desired;
        }
        if ('webkitPreservesPitch' in p) {
          p.webkitPreservesPitch = desired;
        }
        window.__iosPitchConfigured = true;
        window.__iosPitchEnabled = desired;
        return true;
      } catch (_) {
        return false;
      }
    }
    window.setIOSPitchPreservation = setIOSPitchPreservation;

    function configureIOSPlaybackDefaults() {
      if (!player || (window.__iosPitchConfigured && window.__iosPitchEnabled !== false)) {
        return;
      }
      setIOSPitchPreservation(true, player);
    }

    window.__rateChangeBufferingSuppressedUntil = 0;
    window.__bufferingFallbackTimer = null;

    function clearBufferingFallbackTimer() {
      if (window.__bufferingFallbackTimer) {
        clearTimeout(window.__bufferingFallbackTimer);
        window.__bufferingFallbackTimer = null;
      }
    }

    function beginRateChangeBufferingSuppression(durationMs) {
      var ms = Math.max(0, Number(durationMs) || 0);
      var nextUntil = Date.now() + ms;
      window.__rateChangeBufferingSuppressedUntil = Math.max(
        window.__rateChangeBufferingSuppressedUntil || 0,
        nextUntil
      );
    }

    function shouldSuppressTransientBuffering() {
      return Date.now() < (window.__rateChangeBufferingSuppressedUntil || 0);
    }

    function emitBufferingTrue() {
      if (!shouldSuppressTransientBuffering()) {
        sendEvent('buffering', { value: true });
        return;
      }

      clearBufferingFallbackTimer();
      var remaining = Math.max(
        0,
        (window.__rateChangeBufferingSuppressedUntil || 0) - Date.now()
      );
      window.__bufferingFallbackTimer = setTimeout(function() {
        window.__bufferingFallbackTimer = null;
        if (!player || player.paused) {
          return;
        }
        var readyState = Number(player.readyState) || 0;
        if (player.seeking || readyState < 3) {
          sendEvent('buffering', { value: true });
        }
      }, remaining + 16);
    }

    window.beginRateChangeBufferingSuppression = beginRateChangeBufferingSuppression;

    if (player) {
      configureIOSPlaybackDefaults();
      player.addEventListener('play', function() { sendEvent('play'); });
      player.addEventListener('pause', function() { sendEvent('pause'); });
      player.addEventListener('ended', function() { sendEvent('ended'); });
      player.addEventListener('volumechange', function() { sendEvent('volumechange', { volume: player.volume }); });
      player.addEventListener('ratechange', function() {
        emitRecentRateEvent('ratechange', player);
        sendEvent('ratechange', { rate: player.playbackRate });
      });
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
      player.addEventListener('waiting', function() {
        emitRecentRateEvent('waiting', player);
        try { cancelSeekWarmup(); } catch (_) {}
        emitBufferingTrue();
      });
      player.addEventListener('canplay', function() {
        emitRecentRateEvent('canplay', player);
        clearBufferingFallbackTimer();
        sendEvent('buffering', { value: false });
      });
      player.addEventListener('playing', function() {
        emitRecentRateEvent('playing', player);
        clearBufferingFallbackTimer();
        sendEvent('buffering', { value: false });
      });
      player.addEventListener('seeking', function() {
        emitRecentRateEvent('seeking', player);
        emitBufferingTrue();
      });
      player.addEventListener('seeked', function() {
        emitRecentRateEvent('seeked', player);
        clearBufferingFallbackTimer();
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
  static const String _localHlsAssetPath = 'assets/js/hls.min.js';

  Future<CustomSchemeResponse?> _handleCustomSchemeRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    try {
      final uri = request.url;
      if (uri.scheme != 'selene-asset') {
        return null;
      }

      final joined = '${uri.host}${uri.path}';
      final normalized = joined.startsWith('/') ? joined.substring(1) : joined;
      if (normalized != _localHlsAssetPath) {
        debugPrint('[播放器] 未匹配到本地资源: $normalized');
        return null;
      }

      final bytes =
          (await rootBundle.load(_localHlsAssetPath)).buffer.asUint8List();
      return CustomSchemeResponse(
        data: bytes,
        contentType: 'application/javascript',
        contentEncoding: 'utf-8',
      );
    } catch (e) {
      debugPrint('[播放器] 读取本地 hls.js 失败: $e');
      return null;
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
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        useHybridComposition: true,
        transparentBackground: true,
        resourceCustomSchemes: ['selene-asset'],
      ),
      initialData: InAppWebViewInitialData(
        data: widget.adapter._buildHtmlContent(),
        baseUrl: WebUri('https://localhost'),
      ),
      onLoadResourceWithCustomScheme: _handleCustomSchemeRequest,
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
  Stream<Duration> get buffer =>
      const Stream<Duration>.empty().asBroadcastStream();
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
  Duration get buffer => adapter._duration;
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
