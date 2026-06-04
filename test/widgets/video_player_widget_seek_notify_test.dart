import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  test('notifies parent after the seek command completes', () async {
    final seekCompleter = Completer<void>();
    final player = _FakePlayerAdapter(seekCompleter: seekCompleter);
    addTearDown(player.dispose);

    final events = <String>[];

    final future = seekPlayerAndNotifyAsync(
      player: player,
      position: const Duration(seconds: 42),
      onSeek: (_) {
        events.add('notify');
      },
    );

    expect(events, isEmpty);
    expect(player.seekCalls, [const Duration(seconds: 42)]);

    seekCompleter.complete();
    await future;

    expect(events, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['notify']);
  });
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter({this.seekCompleter})
      : _stream = _FakePlayerStream(),
        _state = _FakePlayerState();

  final _FakePlayerStream _stream;
  final _FakePlayerState _state;
  final Completer<void>? seekCompleter;
  final List<Duration> seekCalls = <Duration>[];

  @override
  PlayerAdapterStream get stream => _stream;

  @override
  PlayerAdapterState get state => _state;

  @override
  Widget buildVideo(
    BuildContext context, {
    BoxFit fit = BoxFit.contain,
    Key? key,
    Widget Function(mkv.VideoState state)? controls,
  }) {
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    await _stream.dispose();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    _state.positionValue = position;
    _stream.positionController.add(position);
    if (seekCompleter != null) {
      await seekCompleter!.future;
    }
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> updateVideoFit(BoxFit fit) async {}
}

class _FakePlayerStream implements PlayerAdapterStream {
  final playingController = StreamController<bool>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final bufferController = StreamController<Duration>.broadcast();
  final cachedRangesController =
      StreamController<List<PlayerCachedRange>>.broadcast();
  final completedController = StreamController<bool>.broadcast();
  final volumeController = StreamController<double>.broadcast();
  final rateController = StreamController<double>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();
  final networkSpeedController = StreamController<int>.broadcast();

  @override
  Stream<Duration> get buffer => bufferController.stream;
  @override
  Stream<List<PlayerCachedRange>> get cachedRanges =>
      cachedRangesController.stream;

  @override
  Stream<bool> get buffering => bufferingController.stream;

  @override
  Stream<bool> get completed => completedController.stream;

  @override
  Stream<Duration> get duration => durationController.stream;

  @override
  Stream<int> get networkSpeedBytesPerSecond => networkSpeedController.stream;

  @override
  Stream<bool> get playing => playingController.stream;

  @override
  Stream<Duration> get position => positionController.stream;

  @override
  Stream<double> get rate => rateController.stream;

  @override
  Stream<double> get volume => volumeController.stream;

  Future<void> dispose() async {
    await playingController.close();
    await positionController.close();
    await durationController.close();
    await bufferController.close();
    await cachedRangesController.close();
    await completedController.close();
    await volumeController.close();
    await rateController.close();
    await bufferingController.close();
    await networkSpeedController.close();
  }
}

class _FakePlayerState implements PlayerAdapterState {
  Duration positionValue = Duration.zero;

  @override
  Duration get buffer => Duration.zero;
  @override
  List<PlayerCachedRange> get cachedRanges => const [];

  @override
  bool get buffering => false;

  @override
  Duration get duration => const Duration(minutes: 5);

  @override
  int get networkSpeedBytesPerSecond => 0;

  @override
  double get height => 0;

  @override
  bool get playing => false;

  @override
  Duration get position => positionValue;

  @override
  double get rate => 1.0;

  @override
  double get volume => 100;

  @override
  double get width => 0;
}
