import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/player_benchmark_models.dart';
import 'package:selene/screens/player_benchmark_screen.dart';
import 'package:selene/widgets/benchmark/benchmark_player_driver.dart';

void main() {
  testWidgets('renders backend tabs and benchmark actions', (tester) async {
    final requestedBackends = <BenchmarkPlayerBackend>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerBenchmarkScreen(
          driverFactory: (backend) {
            requestedBackends.add(backend);
            return _FakeBenchmarkPlayerDriver();
          },
          initialResults: const [
            BenchmarkAttemptResult(
              backend: BenchmarkPlayerBackend.webView,
              mode: BenchmarkRunMode.warm,
              scenario: BenchmarkSeekScenario.back10s,
              anchorPosition: Duration(seconds: 240),
              targetPosition: Duration(seconds: 230),
              status: BenchmarkAttemptStatus.success,
              apiReturnMs: 120,
              positionSettleMs: 320,
              bufferingClearMs: 420,
              deltaMs: 30,
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('WebView'), findsOneWidget);
    expect(find.text('video_player'), findsOneWidget);
    expect(find.text('media_kit'), findsOneWidget);
    expect(find.text('fvp'), findsOneWidget);
    expect(find.text('Run Warm'), findsOneWidget);
    expect(find.text('Run Cold'), findsOneWidget);
    expect(find.text('Clear Results'), findsOneWidget);
    expect(find.text('10s'), findsWidgets);

    await tester.tap(find.text('media_kit'));
    await tester.pumpAndSettle();

    expect(requestedBackends, contains(BenchmarkPlayerBackend.mediaKit));

    await tester.tap(find.text('Clear Results'));
    await tester.pumpAndSettle();

    expect(find.text('10s'), findsNothing);
  });
}

class _FakeBenchmarkPlayerDriver implements BenchmarkPlayerDriver {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _readyController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  bool get isReady => true;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get readyStream => _readyController.stream;

  @override
  Widget buildView(BuildContext context, {Key? key}) {
    return Container(key: key, color: Colors.black);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _bufferingController.close();
    await _readyController.close();
  }

  @override
  Future<void> load(String url) async {
    _readyController.add(true);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> waitUntilReady(
      {Duration timeout = const Duration(seconds: 15)}) {
    return Future.value();
  }
}
