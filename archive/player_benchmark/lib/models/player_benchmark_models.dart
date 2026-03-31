enum BenchmarkPlayerBackend {
  webView,
  videoPlayer,
  mediaKit,
  fvp,
}

enum BenchmarkRunMode {
  warm,
  cold,
}

enum BenchmarkAttemptStatus {
  success,
  timeout,
  failed,
}

enum BenchmarkSeekScenario {
  back10s,
  back30s,
  back90s,
  back180s,
}

extension BenchmarkSeekScenarioValues on BenchmarkSeekScenario {
  static const Duration defaultAnchorPosition = Duration(seconds: 240);

  Duration get anchorPosition => defaultAnchorPosition;

  Duration get targetPosition {
    switch (this) {
      case BenchmarkSeekScenario.back10s:
        return const Duration(seconds: 230);
      case BenchmarkSeekScenario.back30s:
        return const Duration(seconds: 210);
      case BenchmarkSeekScenario.back90s:
        return const Duration(seconds: 150);
      case BenchmarkSeekScenario.back180s:
        return const Duration(seconds: 60);
    }
  }

  String get label {
    switch (this) {
      case BenchmarkSeekScenario.back10s:
        return '10s';
      case BenchmarkSeekScenario.back30s:
        return '30s';
      case BenchmarkSeekScenario.back90s:
        return '90s';
      case BenchmarkSeekScenario.back180s:
        return '180s';
    }
  }
}

class BenchmarkAttemptResult {
  const BenchmarkAttemptResult({
    required this.backend,
    required this.mode,
    required this.scenario,
    required this.anchorPosition,
    required this.targetPosition,
    required this.status,
    this.apiReturnMs,
    this.positionSettleMs,
    this.bufferingClearMs,
    this.deltaMs,
    this.errorMessage,
  });

  final BenchmarkPlayerBackend backend;
  final BenchmarkRunMode mode;
  final BenchmarkSeekScenario scenario;
  final Duration anchorPosition;
  final Duration targetPosition;
  final BenchmarkAttemptStatus status;
  final int? apiReturnMs;
  final int? positionSettleMs;
  final int? bufferingClearMs;
  final int? deltaMs;
  final String? errorMessage;
}

class BenchmarkAttemptSummary {
  const BenchmarkAttemptSummary({
    required this.count,
    this.averageApiReturnMs,
    this.averagePositionSettleMs,
    this.averageBufferingClearMs,
  });

  final int count;
  final double? averageApiReturnMs;
  final double? averagePositionSettleMs;
  final double? averageBufferingClearMs;
}
