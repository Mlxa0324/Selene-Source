import 'package:flutter_test/flutter_test.dart';

import 'package:selene/screens/player_screen.dart';

void main() {
  test('normal play resume only syncs danmaku playback state', () {
    var syncCalls = 0;

    runDanmakuResumeCallbacks(
      sync: () => syncCalls++,
    );

    expect(syncCalls, 1);
  });

  test('seek still requires danmaku reset and clear', () {
    var resetCalls = 0;

    runDanmakuSeekReset(
      reset: () => resetCalls++,
    );

    expect(resetCalls, 1);
  });
}
