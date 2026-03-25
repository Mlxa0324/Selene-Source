import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AndroidMediaSessionActionType {
  play,
  pause,
  togglePlayPause,
  previous,
  next,
  seek,
}

class AndroidMediaSessionAction {
  const AndroidMediaSessionAction({
    required this.type,
    this.position,
  });

  final AndroidMediaSessionActionType type;
  final Duration? position;
}

class AndroidMediaSessionState {
  const AndroidMediaSessionState({
    required this.title,
    required this.subtitle,
    this.artworkUrl,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.hasPrevious,
    required this.hasNext,
  });

  final String title;
  final String subtitle;
  final String? artworkUrl;
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final bool hasPrevious;
  final bool hasNext;

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'artworkUrl': artworkUrl,
      'durationMs': duration.inMilliseconds,
      'positionMs': position.inMilliseconds,
      'isPlaying': isPlaying,
      'hasPrevious': hasPrevious,
      'hasNext': hasNext,
    };
  }
}

class AndroidBackgroundPlaybackRequest {
  const AndroidBackgroundPlaybackRequest({
    required this.title,
    required this.subtitle,
    this.artworkUrl,
    required this.url,
    this.headers = const <String, String>{},
    required this.duration,
    required this.position,
    required this.speed,
  });

  final String title;
  final String subtitle;
  final String? artworkUrl;
  final String url;
  final Map<String, String> headers;
  final Duration duration;
  final Duration position;
  final double speed;

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'artworkUrl': artworkUrl,
      'url': url,
      'headers': headers,
      'durationMs': duration.inMilliseconds,
      'positionMs': position.inMilliseconds,
      'speed': speed,
    };
  }
}

class AndroidBackgroundPlaybackState {
  const AndroidBackgroundPlaybackState({
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  final bool isActive;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
}

class AndroidMediaSessionBridge {
  AndroidMediaSessionBridge({bool? platformOverride})
      : _platformOverride = platformOverride;

  static const String channelName = 'org.moontechlab.selene/media_session';
  static const String _syncMethod = 'syncMediaSession';
  static const String _stopMethod = 'stopMediaSession';
  static const String _startBackgroundPlaybackMethod =
      'startBackgroundPlayback';
  static const String _stopBackgroundPlaybackMethod = 'stopBackgroundPlayback';
  static const String _getBackgroundPlaybackStateMethod =
      'getBackgroundPlaybackState';
  static const String _callbackMethod = 'onMediaSessionAction';
  static const MethodChannel _channel = MethodChannel(channelName);

  final bool? _platformOverride;

  bool get _isSupported {
    if (_platformOverride != null) {
      return _platformOverride;
    }
    return !kIsWeb && Platform.isAndroid;
  }

  Future<void> syncSession(AndroidMediaSessionState state) async {
    if (!_isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_syncMethod, state.toMap());
    } catch (e) {
      debugPrint('同步 Android 媒体会话失败: $e');
    }
  }

  Future<void> stopSession() async {
    if (!_isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_stopMethod);
    } catch (e) {
      debugPrint('停止 Android 媒体会话失败: $e');
    }
  }

  Future<bool> startBackgroundPlayback(
    AndroidBackgroundPlaybackRequest request,
  ) async {
    if (!_isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            _startBackgroundPlaybackMethod,
            request.toMap(),
          ) ??
          false;
    } catch (e) {
      debugPrint('启动 Android 后台音频播放失败: $e');
      return false;
    }
  }

  Future<void> stopBackgroundPlayback() async {
    if (!_isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_stopBackgroundPlaybackMethod);
    } catch (e) {
      debugPrint('停止 Android 后台音频播放失败: $e');
    }
  }

  Future<AndroidBackgroundPlaybackState?> getBackgroundPlaybackState() async {
    if (!_isSupported) {
      return null;
    }
    try {
      final result = await _channel
          .invokeMethod<Object?>(_getBackgroundPlaybackStateMethod);
      return parseBackgroundPlaybackState(result);
    } catch (e) {
      debugPrint('获取 Android 后台音频播放状态失败: $e');
      return null;
    }
  }

  static bool shouldStopSession({
    required bool wantsMediaSession,
    required bool hasSyncedSession,
  }) {
    return !wantsMediaSession && hasSyncedSession;
  }

  static AndroidMediaSessionState buildPlaybackState({
    required String title,
    String? sourceName,
    int? currentEpisodeIndex,
    int? totalEpisodes,
    String? artworkUrl,
    required Duration duration,
    required Duration position,
    required bool isPlaying,
    required bool hasPrevious,
    required bool hasNext,
  }) {
    return AndroidMediaSessionState(
      title: title.trim(),
      subtitle: _buildSubtitle(
        sourceName: sourceName,
        currentEpisodeIndex: currentEpisodeIndex,
        totalEpisodes: totalEpisodes,
      ),
      artworkUrl: _normalizeArtworkUrl(artworkUrl),
      duration: duration < Duration.zero ? Duration.zero : duration,
      position: position < Duration.zero ? Duration.zero : position,
      isPlaying: isPlaying,
      hasPrevious: hasPrevious,
      hasNext: hasNext,
    );
  }

  static AndroidMediaSessionAction? parseAction(MethodCall call) {
    if (call.method != _callbackMethod) {
      return null;
    }
    final arguments = call.arguments;
    if (arguments is! Map) {
      return null;
    }
    final action = arguments['action']?.toString() ?? '';
    final positionMs = (arguments['positionMs'] as num?)?.toInt();
    switch (action) {
      case 'play':
        return const AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.play,
        );
      case 'pause':
        return const AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.pause,
        );
      case 'toggle_play_pause':
        return const AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.togglePlayPause,
        );
      case 'previous':
        return const AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.previous,
        );
      case 'next':
        return const AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.next,
        );
      case 'seek':
        return AndroidMediaSessionAction(
          type: AndroidMediaSessionActionType.seek,
          position:
              positionMs == null ? null : Duration(milliseconds: positionMs),
        );
      default:
        return null;
    }
  }

  static AndroidBackgroundPlaybackState? parseBackgroundPlaybackState(
    Object? raw,
  ) {
    if (raw is! Map) {
      return null;
    }
    return AndroidBackgroundPlaybackState(
      isActive: raw['isActive'] as bool? ?? false,
      isPlaying: raw['isPlaying'] as bool? ?? false,
      position: Duration(
        milliseconds: (raw['positionMs'] as num?)?.toInt() ?? 0,
      ),
      duration: Duration(
        milliseconds: (raw['durationMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  static String _buildSubtitle({
    String? sourceName,
    int? currentEpisodeIndex,
    int? totalEpisodes,
  }) {
    final parts = <String>[];
    if (currentEpisodeIndex != null && currentEpisodeIndex >= 0) {
      final episodeNumber = currentEpisodeIndex + 1;
      if (totalEpisodes != null && totalEpisodes > 0) {
        parts.add('第$episodeNumber/$totalEpisodes集');
      } else {
        parts.add('第$episodeNumber集');
      }
    }
    final normalizedSource = sourceName?.trim();
    if (normalizedSource != null && normalizedSource.isNotEmpty) {
      parts.add(normalizedSource);
    }
    return parts.join(' · ');
  }

  static String? _normalizeArtworkUrl(String? artworkUrl) {
    final trimmed = artworkUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
