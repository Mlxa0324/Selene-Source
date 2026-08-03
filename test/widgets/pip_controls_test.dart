import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/video_player_widget.dart';

void main() {
  test('pip action state follows episode boundaries', () {
    final first = buildPipActionsState(
      isPlaying: true,
      currentEpisodeIndex: 0,
      totalEpisodes: 3,
    );
    final middle = buildPipActionsState(
      isPlaying: false,
      currentEpisodeIndex: 1,
      totalEpisodes: 3,
    );
    final last = buildPipActionsState(
      isPlaying: true,
      currentEpisodeIndex: 2,
      totalEpisodes: 3,
    );

    expect(first.hasPrevious, isFalse);
    expect(first.hasNext, isTrue);
    expect(middle.hasPrevious, isTrue);
    expect(middle.hasNext, isTrue);
    expect(last.hasPrevious, isTrue);
    expect(last.hasNext, isFalse);
    expect(middle.isPlaying, isFalse);
  });

  test('pip action availability uses the current episode state', () {
    final first = buildPipActionsState(
      isPlaying: true,
      currentEpisodeIndex: 0,
      totalEpisodes: 2,
    );

    expect(
      isPipActionAvailable(state: first, action: 'previous'),
      isFalse,
    );
    expect(
      isPipActionAvailable(state: first, action: 'toggle_play_pause'),
      isTrue,
    );
    expect(isPipActionAvailable(state: first, action: 'next'), isTrue);
    expect(isPipActionAvailable(state: first, action: 'unknown'), isFalse);
  });

  test('pip action sync queue serializes stale and current snapshots',
      () async {
    final queue = PipActionSyncQueue();
    final firstStarted = Completer<void>();
    final writes = <String>[];
    var snapshot = 'old';
    final firstSnapshot = snapshot;

    final firstWrite = queue.enqueue(() async {
      writes.add('$firstSnapshot-start');
      await firstStarted.future;
      writes.add('$snapshot-end');
    });

    snapshot = 'new';
    final secondWrite = queue.enqueue(() async {
      writes.add('$snapshot-write');
    });

    await Future<void>.delayed(Duration.zero);
    expect(writes, ['old-start']);
    firstStarted.complete();
    await firstWrite;
    await secondWrite;

    expect(writes, ['old-start', 'new-end', 'new-write']);
  });
}
