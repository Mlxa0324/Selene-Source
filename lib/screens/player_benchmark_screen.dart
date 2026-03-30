import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/player_benchmark_models.dart';
import '../services/player_benchmark_session.dart';
import '../services/player_benchmark_video_platform_registry.dart';
import '../widgets/benchmark/benchmark_player_driver.dart';
import '../widgets/benchmark/benchmark_player_host.dart';

class PlayerBenchmarkScreen extends StatefulWidget {
  const PlayerBenchmarkScreen({
    super.key,
    this.driverFactory,
    this.videoPlatformRegistry,
    this.initialResults = const [],
    this.initialUrl = _defaultBenchmarkUrl,
  });

  static const String _defaultBenchmarkUrl =
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  final BenchmarkPlayerDriverFactory? driverFactory;
  final PlayerBenchmarkVideoPlatformRegistry? videoPlatformRegistry;
  final List<BenchmarkAttemptResult> initialResults;
  final String initialUrl;

  @override
  State<PlayerBenchmarkScreen> createState() => _PlayerBenchmarkScreenState();
}

class _PlayerBenchmarkScreenState extends State<PlayerBenchmarkScreen> {
  late final TextEditingController _urlController;
  late final PlayerBenchmarkVideoPlatformRegistry _videoPlatformRegistry;
  late List<BenchmarkAttemptResult> _results;

  BenchmarkPlayerBackend _selectedBackend = BenchmarkPlayerBackend.webView;
  BenchmarkPlayerDriver? _activeDriver;
  bool _isRunning = false;
  int _hostGeneration = 0;
  Completer<BenchmarkPlayerDriver>? _driverAwaiter;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _videoPlatformRegistry =
        widget.videoPlatformRegistry ?? PlayerBenchmarkVideoPlatformRegistry();
    _results = List<BenchmarkAttemptResult>.of(widget.initialResults);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runMode(BenchmarkRunMode mode) async {
    if (_isRunning) return;
    setState(() => _isRunning = true);

    try {
      for (final scenario in BenchmarkSeekScenario.values) {
        for (var i = 0; i < 5; i++) {
          final driver = mode == BenchmarkRunMode.cold
              ? await _recreateDriver()
              : await _waitForActiveDriver();
          final result = await _runSingleAttempt(
            driver: driver,
            mode: mode,
            scenario: scenario,
          );
          if (!mounted) return;
          setState(() => _results.add(result));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  Future<BenchmarkPlayerDriver> _waitForActiveDriver() async {
    final activeDriver = _activeDriver;
    if (activeDriver != null) {
      await activeDriver.waitUntilReady();
      return activeDriver;
    }

    final completer = Completer<BenchmarkPlayerDriver>();
    _driverAwaiter = completer;
    final driver = await completer.future;
    await driver.waitUntilReady();
    return driver;
  }

  Future<BenchmarkPlayerDriver> _recreateDriver() async {
    final completer = Completer<BenchmarkPlayerDriver>();
    _driverAwaiter = completer;
    if (mounted) {
      setState(() => _hostGeneration++);
    }
    final driver = await completer.future;
    await driver.waitUntilReady();
    return driver;
  }

  void _handleDriverChanged(BenchmarkPlayerDriver driver) {
    _activeDriver = driver;
    final completer = _driverAwaiter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(driver);
    }
  }

  Future<BenchmarkAttemptResult> _runSingleAttempt({
    required BenchmarkPlayerDriver driver,
    required BenchmarkRunMode mode,
    required BenchmarkSeekScenario scenario,
  }) async {
    await driver.waitUntilReady();
    await driver.play();
    await _seekDriverNear(driver, scenario.anchorPosition);

    final stopwatch = Stopwatch()..start();
    final session = PlayerBenchmarkSession(
      backend: _selectedBackend,
      mode: mode,
      scenario: scenario,
    );
    final resultCompleter = Completer<BenchmarkAttemptResult>();
    var latestBuffering = false;

    late final StreamSubscription<Duration> positionSubscription;
    late final StreamSubscription<bool> bufferingSubscription;
    late final Timer timeoutTicker;

    void completeIfNeeded(BenchmarkAttemptResult? result) {
      if (result == null || resultCompleter.isCompleted) {
        return;
      }
      resultCompleter.complete(result);
    }

    positionSubscription = driver.positionStream.listen((position) {
      completeIfNeeded(
        session.onPosition(
          position,
          timestampMs: stopwatch.elapsedMilliseconds,
        ),
      );
    });

    bufferingSubscription = driver.bufferingStream.listen((buffering) {
      latestBuffering = buffering;
      session.onBufferingChanged(
        buffering,
        timestampMs: stopwatch.elapsedMilliseconds,
      );
    });

    timeoutTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      completeIfNeeded(
        session.checkTimeout(
          timestampMs: stopwatch.elapsedMilliseconds,
        ),
      );
    });

    try {
      session.onSeekStart(
        anchorPosition: scenario.anchorPosition,
        targetPosition: scenario.targetPosition,
        timestampMs: stopwatch.elapsedMilliseconds,
      );
      await driver.seek(scenario.targetPosition);
      session.onSeekReturned(timestampMs: stopwatch.elapsedMilliseconds);
      if (!latestBuffering) {
        session.onBufferingChanged(
          false,
          timestampMs: stopwatch.elapsedMilliseconds,
        );
      }
      return await resultCompleter.future;
    } finally {
      timeoutTicker.cancel();
      await positionSubscription.cancel();
      await bufferingSubscription.cancel();
      stopwatch.stop();
    }
  }

  Future<void> _seekDriverNear(
    BenchmarkPlayerDriver driver,
    Duration target,
  ) async {
    await driver.seek(target);
    await _waitForPositionNear(driver, target);
  }

  Future<void> _waitForPositionNear(
    BenchmarkPlayerDriver driver,
    Duration target,
  ) async {
    const toleranceMs = PlayerBenchmarkSession.settleToleranceMs;
    final currentDelta = (driver.currentPosition - target).inMilliseconds.abs();
    if (currentDelta <= toleranceMs) {
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<Duration> subscription;
    subscription = driver.positionStream.listen((position) {
      final deltaMs = (position - target).inMilliseconds.abs();
      if (deltaMs <= toleranceMs && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } finally {
      await subscription.cancel();
    }
  }

  void _resetUrl() {
    _urlController.text = PlayerBenchmarkScreen._defaultBenchmarkUrl;
    setState(() => _hostGeneration++);
  }

  void _clearResults() {
    setState(() => _results = <BenchmarkAttemptResult>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Benchmark'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final previewHeight = math.min(
              constraints.maxWidth * 9 / 16,
              240.0,
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BenchmarkPlayerBackend.values.map((backend) {
                      return ChoiceChip(
                        label: Text(_backendLabel(backend)),
                        selected: _selectedBackend == backend,
                        onSelected: (_) {
                          setState(() {
                            _selectedBackend = backend;
                            _hostGeneration++;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'HLS URL',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            setState(() => _hostGeneration++);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isRunning ? null : _resetUrl,
                        child: const Text('恢复默认测试源'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: previewHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BenchmarkPlayerHost(
                          key: ValueKey(
                            'benchmark-host-${_selectedBackend.name}-$_hostGeneration',
                          ),
                          backend: _selectedBackend,
                          url: _urlController.text.trim(),
                          generation: _hostGeneration,
                          videoPlatformRegistry: _videoPlatformRegistry,
                          driverFactory: widget.driverFactory,
                          onDriverChanged: _handleDriverChanged,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _isRunning
                            ? null
                            : () => _runMode(BenchmarkRunMode.warm),
                        child: const Text('Run Warm'),
                      ),
                      FilledButton(
                        onPressed: _isRunning
                            ? null
                            : () => _runMode(BenchmarkRunMode.cold),
                        child: const Text('Run Cold'),
                      ),
                      OutlinedButton(
                        onPressed: _isRunning ? null : _clearResults,
                        child: const Text('Clear Results'),
                      ),
                    ],
                  ),
                  if (_isRunning) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: _results.isEmpty
                        ? const Center(child: Text('No benchmark results yet'))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              return Card(
                                child: ListTile(
                                  leading: Text(result.scenario.label),
                                  title: Text(
                                    '${_backendLabel(result.backend)} ${result.mode.name}',
                                  ),
                                  subtitle: Text(
                                    'api=${result.apiReturnMs ?? '-'}ms  '
                                    'settle=${result.positionSettleMs ?? '-'}ms  '
                                    'buffer=${result.bufferingClearMs ?? '-'}ms  '
                                    'delta=${result.deltaMs ?? '-'}ms',
                                  ),
                                  trailing: Text(result.status.name),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _backendLabel(BenchmarkPlayerBackend backend) {
    switch (backend) {
      case BenchmarkPlayerBackend.webView:
        return 'WebView';
      case BenchmarkPlayerBackend.videoPlayer:
        return 'video_player';
      case BenchmarkPlayerBackend.mediaKit:
        return 'media_kit';
      case BenchmarkPlayerBackend.fvp:
        return 'fvp';
    }
  }
}
