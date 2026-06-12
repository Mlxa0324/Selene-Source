/// 播放时间相关工具函数。
///
/// 提供播放时长格式化与区间钳制等通用工具。
library playback_time_utils;

/// 限制时间在合法播放区间内。
Duration clampDuration(Duration value, Duration min, Duration max) {
  final milliseconds = value.inMilliseconds.clamp(
    min.inMilliseconds,
    max.inMilliseconds,
  );
  return Duration(milliseconds: milliseconds);
}

/// 格式化播放时长展示为 `mm:ss` 或 `h:mm:ss`。
String formatPlaybackDuration(Duration duration) {
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
