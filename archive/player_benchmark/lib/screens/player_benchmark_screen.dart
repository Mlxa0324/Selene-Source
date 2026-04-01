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

  final List<StreamSubscription<dynamic>> _driverSubscriptions =
      <StreamSubscription<dynamic>>[];
  final List<String> _logs = <String>[];

  BenchmarkPlayerBackend _selectedBackend = BenchmarkPlayerBackend.webView;
  BenchmarkPlayerDriver? _activeDriver;
  bool _isRunning = false;
  int _hostGeneration = 0;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  Duration? _manualPreviewPosition;
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
    for (final subscription in _driverSubscriptions) {
      unawaited(subscription.cancel());
    }
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runMode(BenchmarkRunMode mode) async {
    if (_isRunning) return;
    _addLog('开始执行${_runModeLabel(mode)}批量测试');
    setState(() => _isRunning = true);

    try {
      for (final scenario in BenchmarkSeekScenario.values) {
        for (var i = 0; i < 5; i++) {
          _addLog('开始场景：左跳 ${scenario.label}，第 ${i + 1}/5 次');
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
          _addLog(
            '场景 ${scenario.label} 第 ${i + 1}/5 次完成，'
            '状态：${_statusLabel(result.status)}，'
            'API ${_metricLabel(result.apiReturnMs)}，'
            '稳定 ${_metricLabel(result.positionSettleMs)}，'
            '缓冲 ${_metricLabel(result.bufferingClearMs)}',
          );
        }
      }
      _addLog('${_runModeLabel(mode)}批量测试完成');
    } catch (error) {
      _addLog('${_runModeLabel(mode)}批量测试异常终止：$error');
      rethrow;
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
    for (final subscription in _driverSubscriptions) {
      unawaited(subscription.cancel());
    }
    _driverSubscriptions.clear();

    _activeDriver = driver;
    _currentPosition = driver.currentPosition;
    _currentDuration = driver.currentDuration;
    _manualPreviewPosition = null;

    _driverSubscriptions.add(
      driver.positionStream.listen((position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = position;
        });
      }),
    );
    _driverSubscriptions.add(
      driver.durationStream.listen((duration) {
        if (!mounted) return;
        setState(() {
          _currentDuration = duration;
        });
      }),
    );
    _driverSubscriptions.add(
      driver.bufferingStream.listen((buffering) {
        if (buffering) {
          _addLog('播放器缓冲中');
          return;
        }
        _addLog('播放器缓冲结束，当前位置：${_formatDuration(_currentPosition)}');
      }),
    );
    _driverSubscriptions.add(
      driver.readyStream.listen((_) {
        final duration = driver.currentDuration > Duration.zero
            ? driver.currentDuration
            : _currentDuration;
        if (mounted) {
          setState(() {
            _currentDuration = duration;
          });
        }
        _addLog('播放器已就绪，总时长：${_formatDuration(duration)}');
      }),
    );

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
    _addLog('已恢复默认测试源');
    setState(() => _hostGeneration++);
  }

  void _clearResults() {
    _addLog('已清空测试结果');
    setState(() => _results = <BenchmarkAttemptResult>[]);
  }

  void _addLog(String message) {
    final line = '${_formatClock(DateTime.now())} $message';
    debugPrint('[播放器基准测试] $line');
    if (!mounted) return;
    setState(() {
      _logs.insert(0, line);
      if (_logs.length > 200) {
        _logs.removeLast();
      }
    });
  }

  void _handleManualSeekStart(double value) {
    final target = Duration(milliseconds: value.round());
    setState(() => _manualPreviewPosition = target);
    _addLog('开始手动拖动，目标位置：${_formatDuration(target)}');
  }

  void _handleManualSeekChanged(double value) {
    setState(() {
      _manualPreviewPosition = Duration(milliseconds: value.round());
    });
  }

  Future<void> _handleManualSeekEnd(double value) async {
    final driver = _activeDriver;
    if (driver == null) {
      return;
    }

    final target = Duration(milliseconds: value.round());
    setState(() => _manualPreviewPosition = target);
    _addLog('已执行手动 seek，目标位置：${_formatDuration(target)}');
    try {
      await driver.seek(target);
      _addLog('手动 seek 调用已返回');
    } catch (error) {
      _addLog('手动 seek 失败：$error');
    } finally {
      if (mounted) {
        setState(() => _manualPreviewPosition = null);
      }
    }
  }

  Duration get _displayPosition => _manualPreviewPosition ?? _currentPosition;

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _formatClock(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '[$hour:$minute:$second]';
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
              math.max(120.0, constraints.maxHeight * 0.25),
            );
            final tabSectionHeight =
                math.max(220.0, constraints.maxHeight * 0.42);
            final sliderMax = _currentDuration > Duration.zero
                ? _currentDuration.inMilliseconds.toDouble()
                : 1.0;
            final sliderValue = _displayPosition.inMilliseconds
                .clamp(0, sliderMax.round())
                .toDouble();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BenchmarkPlayerBackend.values.map((backend) {
                      return ChoiceChip(
                        label: Text(_backendLabel(backend)),
                        selected: _selectedBackend == backend,
                        onSelected: (_) {
                          _addLog('已切换后端：${_backendLabel(backend)}');
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
                            _addLog('已更新测试源：${_urlController.text.trim()}');
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '手动拖动测试',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDuration(_displayPosition)} / '
                            '${_formatDuration(_currentDuration)}',
                          ),
                          Slider(
                            value: sliderValue,
                            max: sliderMax,
                            onChangeStart: (_currentDuration > Duration.zero &&
                                    !_isRunning)
                                ? _handleManualSeekStart
                                : null,
                            onChanged: (_currentDuration > Duration.zero &&
                                    !_isRunning)
                                ? _handleManualSeekChanged
                                : null,
                            onChangeEnd: (_currentDuration > Duration.zero &&
                                    !_isRunning)
                                ? (value) {
                                    unawaited(_handleManualSeekEnd(value));
                                  }
                                : null,
                          ),
                          const Text('拖动滑块后，松手才会触发 seek。'),
                        ],
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
                  SizedBox(
                    height: tabSectionHeight,
                    child: DefaultTabController(
                      initialIndex: _results.isEmpty ? 1 : 0,
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: '测试结果'),
                              Tab(text: '运行日志'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _results.isEmpty
                                    ? const Center(
                                        child: Text('暂无 benchmark 结果'))
                                    : ListView.separated(
                                        itemCount: _results.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) {
                                          final result = _results[index];
                                          return Card(
                                            child: ListTile(
                                              leading:
                                                  Text(result.scenario.label),
                                              title: Text(
                                                '${_backendLabel(result.backend)} ${result.mode.name}',
                                              ),
                                              subtitle: Text(
                                                'api=${result.apiReturnMs ?? '-'}ms  '
                                                'settle=${result.positionSettleMs ?? '-'}ms  '
                                                'buffer=${result.bufferingClearMs ?? '-'}ms  '
                                                'delta=${result.deltaMs ?? '-'}ms',
                                              ),
                                              trailing: Text(
                                                _statusLabel(result.status),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                _logs.isEmpty
                                    ? const Center(child: Text('暂无运行日志'))
                                    : ListView.separated(
                                        itemCount: _logs.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          return ListTile(
                                            dense: true,
                                            title: Text(_logs[index]),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  String _runModeLabel(BenchmarkRunMode mode) {
    switch (mode) {
      case BenchmarkRunMode.warm:
        return '热启动';
      case BenchmarkRunMode.cold:
        return '冷启动';
    }
  }

  String _statusLabel(BenchmarkAttemptStatus status) {
    switch (status) {
      case BenchmarkAttemptStatus.success:
        return '成功';
      case BenchmarkAttemptStatus.timeout:
        return '超时';
      case BenchmarkAttemptStatus.failed:
        return '失败';
    }
  }

  String _metricLabel(int? value) {
    if (value == null) {
      return '-';
    }
    return '${value}ms';
  }
}
