import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/danmaku_model.dart';
import 'package:selene/screens/player_screen.dart';

void main() {
  test('finds danmaku seek index with binary-search semantics', () {
    final comments = <DanmakuComment>[
      _comment(1.0),
      _comment(3.5),
      _comment(7.0),
      _comment(12.2),
    ];

    expect(
      findDanmakuSeekIndex(
        comments,
        const Duration(milliseconds: 0),
      ),
      0,
    );
    expect(
      findDanmakuSeekIndex(
        comments,
        const Duration(milliseconds: 3500),
      ),
      2,
    );
    expect(
      findDanmakuSeekIndex(
        comments,
        const Duration(milliseconds: 8000),
      ),
      3,
    );
    expect(
      findDanmakuSeekIndex(
        comments,
        const Duration(milliseconds: 20000),
      ),
      4,
    );
  });
}

DanmakuComment _comment(double seconds) {
  return DanmakuComment(
    cid: seconds.toInt(),
    p: '$seconds,1,16777215',
    m: 'comment-$seconds',
    t: 0,
  );
}
