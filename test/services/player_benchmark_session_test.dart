import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/player_benchmark_models.dart';
import 'package:selene/services/player_benchmark_session.dart';

void main() {
  group('PlayerBenchmarkSession', () {
    test('records api_return_ms from t1 - t0', () {
      final session = PlayerBenchmarkSession(
        backend: BenchmarkPlayerBackend.webView,
        mode: BenchmarkRunMode.warm,
        scenario: BenchmarkSeekScenario.back10s,
      );

      session.onSeekStart(
        anchorPosition: BenchmarkSeekScenario.back10s.anchorPosition,
        targetPosition: BenchmarkSeekScenario.back10s.targetPosition,
        timestampMs: 1000,
      );
      session.onSeekReturned(timestampMs: 1230);
      session.onBufferingChanged(true, timestampMs: 1260);
      session.onPosition(
        const Duration(seconds: 229, milliseconds: 980),
        timestampMs: 1300,
      );
      session.onPosition(
        const Duration(seconds: 230, milliseconds: 20),
        timestampMs: 1520,
      );
      session.onBufferingChanged(false, timestampMs: 1800);
      final result = session.onPosition(
        const Duration(seconds: 230, milliseconds: 120),
        timestampMs: 1840,
      );

      expect(result, isNotNull);
      expect(result!.apiReturnMs, 230);
    });

    test('requires position to stay within tolerance for 200ms', () {
      final session = PlayerBenchmarkSession(
        backend: BenchmarkPlayerBackend.videoPlayer,
        mode: BenchmarkRunMode.warm,
        scenario: BenchmarkSeekScenario.back30s,
      );

      session.onSeekStart(
        anchorPosition: BenchmarkSeekScenario.back30s.anchorPosition,
        targetPosition: BenchmarkSeekScenario.back30s.targetPosition,
        timestampMs: 2000,
      );
      session.onSeekReturned(timestampMs: 2080);
      session.onBufferingChanged(true, timestampMs: 2100);

      expect(
        session.onPosition(const Duration(milliseconds: 20), timestampMs: 2120),
        isNull,
      );
      expect(
        session.onPosition(
          const Duration(seconds: 210, milliseconds: 250),
          timestampMs: 2300,
        ),
        isNull,
      );
      expect(
        session.onPosition(
          const Duration(seconds: 210, milliseconds: 300),
          timestampMs: 2500,
        ),
        isNull,
      );
      session.onBufferingChanged(false, timestampMs: 2600);

      final result = session.onPosition(
        const Duration(seconds: 210, milliseconds: 320),
        timestampMs: 2640,
      );

      expect(result, isNotNull);
      expect(result!.positionSettleMs, 500);
    });

    test(
        'waits for buffering false and forward position movement before finishing',
        () {
      final session = PlayerBenchmarkSession(
        backend: BenchmarkPlayerBackend.mediaKit,
        mode: BenchmarkRunMode.cold,
        scenario: BenchmarkSeekScenario.back90s,
      );

      session.onSeekStart(
        anchorPosition: BenchmarkSeekScenario.back90s.anchorPosition,
        targetPosition: BenchmarkSeekScenario.back90s.targetPosition,
        timestampMs: 3000,
      );
      session.onSeekReturned(timestampMs: 3090);
      session.onBufferingChanged(true, timestampMs: 3100);
      session.onPosition(
        const Duration(seconds: 150, milliseconds: 100),
        timestampMs: 3220,
      );
      session.onPosition(
        const Duration(seconds: 150, milliseconds: 120),
        timestampMs: 3450,
      );
      session.onBufferingChanged(false, timestampMs: 3500);

      expect(
        session.onPosition(
          const Duration(seconds: 150, milliseconds: 120),
          timestampMs: 3520,
        ),
        isNull,
      );

      final result = session.onPosition(
        const Duration(seconds: 150, milliseconds: 260),
        timestampMs: 3580,
      );

      expect(result, isNotNull);
      expect(result!.bufferingClearMs, 580);
    });

    test('returns timeout result after 15 seconds', () {
      final session = PlayerBenchmarkSession(
        backend: BenchmarkPlayerBackend.fvp,
        mode: BenchmarkRunMode.cold,
        scenario: BenchmarkSeekScenario.back180s,
      );

      session.onSeekStart(
        anchorPosition: BenchmarkSeekScenario.back180s.anchorPosition,
        targetPosition: BenchmarkSeekScenario.back180s.targetPosition,
        timestampMs: 5000,
      );
      session.onSeekReturned(timestampMs: 5060);

      final result = session.checkTimeout(timestampMs: 20001);

      expect(result, isNotNull);
      expect(result!.status, BenchmarkAttemptStatus.timeout);
      expect(result.errorMessage, contains('15s'));
    });
  });
}
