import 'package:flutter_test/flutter_test.dart';

import 'package:selene/screens/player_screen.dart';

void main() {
  test('normal play resume does not rebase danmaku cursor', () {
    expect(shouldRebaseDanmakuOnResume(), isFalse);
  });

  test('seek still requires danmaku reset and clear', () {
    expect(shouldResetDanmakuOnSeek(), isTrue);
  });
}
