import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// TV 性能探针。
///
/// 通过 `--dart-define=SELENE_TV_PERF_TRACE=true` 开启。默认关闭，
/// 避免普通运行和线上包产生额外日志或 Timeline 开销。
class TvPerfTrace {
  /// 创建 TV 性能探针工具。
  const TvPerfTrace._();

  /// 编译期性能探针开关。
  static const bool _envEnabled = bool.fromEnvironment(
    'SELENE_TV_PERF_TRACE',
    defaultValue: false,
  );

  /// 测试专用开关覆盖。
  @visibleForTesting
  static bool? debugEnabledOverride;

  /// 当前性能探针是否开启。
  static bool get isEnabled => debugEnabledOverride ?? _envEnabled;

  /// 记录一个瞬时性能事件。
  static void instant(
    String name, {
    Map<String, Object?>? arguments,
  }) {
    if (!isEnabled) {
      return;
    }
    developer.Timeline.instantSync(name, arguments: _timelineArgs(arguments));
    _log(name, arguments: arguments);
  }

  /// 记录同步阶段耗时。
  static T sync<T>(
    String name,
    T Function() action, {
    Map<String, Object?>? arguments,
  }) {
    if (!isEnabled) {
      return action();
    }

    final stopwatch = Stopwatch()..start();
    try {
      return developer.Timeline.timeSync<T>(
        name,
        action,
        arguments: _timelineArgs(arguments),
      );
    } finally {
      stopwatch.stop();
      _logDuration(name, stopwatch.elapsed, arguments);
    }
  }

  /// 记录异步阶段耗时。
  static Future<T> async<T>(
    String name,
    Future<T> Function() action, {
    Map<String, Object?>? arguments,
  }) async {
    if (!isEnabled) {
      return action();
    }

    final task = developer.TimelineTask();
    final stopwatch = Stopwatch()..start();
    task.start(name, arguments: _timelineArgs(arguments));
    try {
      return await action();
    } finally {
      stopwatch.stop();
      final elapsedArguments = <String, Object?>{
        if (arguments != null) ...arguments,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      };
      task.finish(arguments: _timelineArgs(elapsedArguments));
      _logDuration(name, stopwatch.elapsed, arguments);
    }
  }

  /// 转成 Timeline 可接受的参数，并去掉空值。
  static Map<String, Object>? _timelineArgs(Map<String, Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return null;
    }
    return <String, Object>{
      for (final entry in arguments.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  /// 打印耗时日志。
  static void _logDuration(
    String name,
    Duration elapsed,
    Map<String, Object?>? arguments,
  ) {
    _log(
      name,
      arguments: <String, Object?>{
        'elapsedMs': elapsed.inMilliseconds,
        if (arguments != null) ...arguments,
      },
    );
  }

  /// 打印统一格式日志。
  static void _log(
    String name, {
    Map<String, Object?>? arguments,
  }) {
    final suffix = _formatArguments(arguments);
    debugPrint('[TV PERF] $name$suffix');
  }

  /// 格式化性能日志参数。
  static String _formatArguments(Map<String, Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return '';
    }
    final parts = <String>[];
    for (final entry in arguments.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      parts.add('${entry.key}=$value');
    }
    return parts.isEmpty ? '' : ' ${parts.join(' ')}';
  }
}
