import 'dart:async';

import 'package:flutter/material.dart';

abstract class BenchmarkPlayerDriver {
  Stream<Duration> get positionStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get readyStream;

  Duration get currentPosition;
  bool get isReady;

  Future<void> load(String url);
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 15),
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Widget buildView(BuildContext context, {Key? key});
  Future<void> dispose();
}

abstract class BaseBenchmarkPlayerDriver implements BenchmarkPlayerDriver {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _readyController =
      StreamController<bool>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Completer<void> _readyCompleter = Completer<void>();
  Duration _currentPosition = Duration.zero;
  bool _isReady = false;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get readyStream => _readyController.stream;

  @override
  Duration get currentPosition => _currentPosition;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 15),
  }) {
    if (_isReady) {
      return Future.value();
    }
    return _readyCompleter.future.timeout(timeout);
  }

  @protected
  void resetReadyState() {
    _isReady = false;
    if (_readyCompleter.isCompleted) {
      _readyCompleter = Completer<void>();
    }
  }

  @protected
  void markReady() {
    if (_isReady) return;
    _isReady = true;
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
    if (!_readyController.isClosed) {
      _readyController.add(true);
    }
  }

  @protected
  void emitPosition(Duration position) {
    _currentPosition = position;
    if (!_positionController.isClosed) {
      _positionController.add(position);
    }
  }

  @protected
  void emitBuffering(bool buffering) {
    if (!_bufferingController.isClosed) {
      _bufferingController.add(buffering);
    }
  }

  @protected
  void addSubscription(StreamSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  @protected
  Future<void> disposeBase() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _positionController.close();
    await _bufferingController.close();
    await _readyController.close();
  }
}
