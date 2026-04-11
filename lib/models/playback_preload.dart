enum PlaybackPreloadLevel {
  off,
  low,
  medium,
  high,
}

const PlaybackPreloadLevel kDefaultPlaybackPreloadLevel =
    PlaybackPreloadLevel.high;

extension PlaybackPreloadLevelX on PlaybackPreloadLevel {
  String get storageValue => name;

  String get label {
    switch (this) {
      case PlaybackPreloadLevel.off:
        return '关';
      case PlaybackPreloadLevel.low:
        return '低';
      case PlaybackPreloadLevel.medium:
        return '中';
      case PlaybackPreloadLevel.high:
        return '高';
    }
  }

  bool get isEnabled => this != PlaybackPreloadLevel.off;

  Duration? get targetForwardBuffer {
    switch (this) {
      case PlaybackPreloadLevel.off:
        return null;
      case PlaybackPreloadLevel.low:
        return const Duration(minutes: 1);
      case PlaybackPreloadLevel.medium:
        return const Duration(minutes: 3);
      case PlaybackPreloadLevel.high:
        return const Duration(minutes: 5);
    }
  }

  Duration? get backBufferRetention {
    if (!isEnabled) {
      return null;
    }
    // 保持已看过片段的后向缓存，避免左拖回看时频繁回源。
    return const Duration(minutes: 15);
  }
}

PlaybackPreloadLevel playbackPreloadLevelFromStorage(String? value) {
  for (final level in PlaybackPreloadLevel.values) {
    if (level.storageValue == value) {
      return level;
    }
  }
  return kDefaultPlaybackPreloadLevel;
}

PlaybackPreloadLevel playbackPreloadLevelFromLegacyEnabled(bool enabled) {
  return enabled ? PlaybackPreloadLevel.high : PlaybackPreloadLevel.off;
}
