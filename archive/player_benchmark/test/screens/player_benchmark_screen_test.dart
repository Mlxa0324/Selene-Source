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

  testWidgets('supports manual slider seek and renders Chinese logs',
      (tester) async {
    final driver = _FakeBenchmarkPlayerDriver(
      initialPosition: const Duration(seconds: 30),
      initialDuration: const Duration(seconds: 240),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlayerBenchmarkScreen(
          driverFactory: (_) => driver,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('手动拖动测试'), findsOneWidget);
    expect(find.text('运行日志'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('播放器已就绪'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(240, 0));
    await tester.pumpAndSettle();

    expect(driver.seekCalls, hasLength(1));
    expect(driver.seekCalls.single, greaterThan(Duration.zero));
    expect(find.textContaining('已执行手动 seek'), findsOneWidget);
  });
}

class _FakeBenchmarkPlayerDriver implements BenchmarkPlayerDriver {
  _FakeBenchmarkPlayerDriver({
    this.initialPosition = Duration.zero,
    this.initialDuration = const Duration(minutes: 4),
  });

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _readyController =
      StreamController<bool>.broadcast();
  final List<Duration> seekCalls = <Duration>[];
  final Duration initialPosition;
  final Duration initialDuration;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  bool get isReady => true;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

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
    await _durationController.close();
    await _bufferingController.close();
    await _readyController.close();
  }

  @override
  Future<void> load(String url) async {
    _currentPosition = initialPosition;
    _currentDuration = initialDuration;
    _durationController.add(_currentDuration);
    _positionController.add(_currentPosition);
    _readyController.add(true);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    _currentPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> waitUntilReady(
      {Duration timeout = const Duration(seconds: 15)}) {
    return Future.value();
  }
}
