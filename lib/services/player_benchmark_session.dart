import '../models/player_benchmark_models.dart';

class PlayerBenchmarkSession {
  PlayerBenchmarkSession({
    required this.backend,
    required this.mode,
    required this.scenario,
  });

  static const int settleToleranceMs = 500;
  static const int settleWindowMs = 200;
  static const int timeoutMs = 15000;

  final BenchmarkPlayerBackend backend;
  final BenchmarkRunMode mode;
  final BenchmarkSeekScenario scenario;

  BenchmarkAttemptResult? _result;
  Duration? _anchorPosition;
  Duration? _targetPosition;
  int? _seekStartedAtMs;
  int? _seekReturnedAtMs;
  int? _positionSettledAtMs;
  int? _withinToleranceSinceMs;
  int? _bufferingClearedAtMs;
  Duration? _positionWhenBufferingCleared;
  Duration? _lastPosition;
  bool _isBuffering = false;

  void onSeekStart({
    required Duration anchorPosition,
    required Duration targetPosition,
    required int timestampMs,
  }) {
    _result = null;
    _anchorPosition = anchorPosition;
    _targetPosition = targetPosition;
    _seekStartedAtMs = timestampMs;
    _seekReturnedAtMs = null;
    _positionSettledAtMs = null;
    _withinToleranceSinceMs = null;
    _bufferingClearedAtMs = null;
    _positionWhenBufferingCleared = null;
    _lastPosition = anchorPosition;
    _isBuffering = false;
  }

  void onSeekReturned({
    required int timestampMs,
  }) {
    if (_result != null) return;
    _seekReturnedAtMs ??= timestampMs;
  }

  void onBufferingChanged(
    bool isBuffering, {
    required int timestampMs,
  }) {
    if (_result != null) return;

    _isBuffering = isBuffering;
    if (!isBuffering) {
      _bufferingClearedAtMs = timestampMs;
      _positionWhenBufferingCleared = _lastPosition;
    }
  }

  BenchmarkAttemptResult? onPosition(
    Duration position, {
    required int timestampMs,
  }) {
    if (_result != null) return _result;

    _lastPosition = position;
    _updateSettledState(position, timestampMs: timestampMs);

    if (_positionSettledAtMs != null &&
        _bufferingClearedAtMs != null &&
        !_isBuffering &&
        _hasPlaybackResumed(position)) {
      _result = _buildSuccessResult(
        finalPosition: position,
        bufferingClearAtMs: timestampMs,
      );
    }

    return _result;
  }

  BenchmarkAttemptResult? checkTimeout({
    required int timestampMs,
  }) {
    if (_result != null || _seekStartedAtMs == null) {
      return _result;
    }

    if (timestampMs - _seekStartedAtMs! < timeoutMs) {
      return null;
    }

    _result = BenchmarkAttemptResult(
      backend: backend,
      mode: mode,
      scenario: scenario,
      anchorPosition: _anchorPosition ?? scenario.anchorPosition,
      targetPosition: _targetPosition ?? scenario.targetPosition,
      status: BenchmarkAttemptStatus.timeout,
      apiReturnMs: _elapsedOrNull(_seekReturnedAtMs),
      positionSettleMs: _elapsedOrNull(_positionSettledAtMs),
      bufferingClearMs: null,
      deltaMs: _lastPosition == null || _targetPosition == null
          ? null
          : (_lastPosition! - _targetPosition!).inMilliseconds.abs(),
      errorMessage: 'Seek timed out after 15s',
    );
    return _result;
  }

  void _updateSettledState(
    Duration position, {
    required int timestampMs,
  }) {
    final targetPosition = _targetPosition;
    if (targetPosition == null || _positionSettledAtMs != null) {
      return;
    }

    final deltaMs = (position - targetPosition).inMilliseconds.abs();
    if (deltaMs > settleToleranceMs) {
      _withinToleranceSinceMs = null;
      return;
    }

    _withinToleranceSinceMs ??= timestampMs;
    if (timestampMs - _withinToleranceSinceMs! >= settleWindowMs) {
      _positionSettledAtMs = timestampMs;
    }
  }

  bool _hasPlaybackResumed(Duration position) {
    final positionWhenBufferingCleared = _positionWhenBufferingCleared;
    if (positionWhenBufferingCleared == null) {
      return false;
    }
    return position > positionWhenBufferingCleared;
  }

  BenchmarkAttemptResult _buildSuccessResult({
    required Duration finalPosition,
    required int bufferingClearAtMs,
  }) {
    return BenchmarkAttemptResult(
      backend: backend,
      mode: mode,
      scenario: scenario,
      anchorPosition: _anchorPosition ?? scenario.anchorPosition,
      targetPosition: _targetPosition ?? scenario.targetPosition,
      status: BenchmarkAttemptStatus.success,
      apiReturnMs: _elapsedOrNull(_seekReturnedAtMs),
      positionSettleMs: _elapsedOrNull(_positionSettledAtMs),
      bufferingClearMs: _elapsedFromStart(bufferingClearAtMs),
      deltaMs: _targetPosition == null
          ? null
          : (finalPosition - _targetPosition!).inMilliseconds.abs(),
    );
  }

  int? _elapsedOrNull(int? timestampMs) {
    if (timestampMs == null) return null;
    return _elapsedFromStart(timestampMs);
  }

  int? _elapsedFromStart(int timestampMs) {
    final seekStartedAtMs = _seekStartedAtMs;
    if (seekStartedAtMs == null) {
      return null;
    }
    return timestampMs - seekStartedAtMs;
  }
}
