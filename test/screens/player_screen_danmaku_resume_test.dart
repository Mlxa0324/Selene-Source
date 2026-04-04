import 'package:flutter_test/flutter_test.dart';

import 'package:selene/screens/player_screen.dart';

void main() {
  test('normal play resume does not rebase danmaku cursor', () {
    expect(
      PlayerScreenDanmakuPolicy.shouldRebaseOnPlay(
        reason: 'player_on_play',
      ),
      isFalse,
    );
  });

  test('seek still requires danmaku reset and clear', () {
    expect(
      PlayerScreenDanmakuPolicy.shouldResetOnSeek(
        reason: 'player_on_seek_async',
      ),
      isTrue,
    );
  });
}
