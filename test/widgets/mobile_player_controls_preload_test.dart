import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/mobile_player_controls.dart';

void main() {
  test('resolveMobileCachedProgressSegment returns the primary confirmed range',
      () {
    final segment = resolveMobileCachedProgressSegment(
      duration: const Duration(minutes: 30),
      position: const Duration(minutes: 8),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 10),
        ),
      ],
    );

    expect(segment, isNotNull);
    expect(segment!.start, closeTo(0.2, 0.0001));
    expect(segment.end, closeTo(0.3333, 0.0001));
  });

  test('resolveMobileCachedProgressSegment returns null without confirmed range',
      () {
    final segment = resolveMobileCachedProgressSegment(
      duration: const Duration(minutes: 30),
      position: const Duration(minutes: 8),
      cachedRanges: const [],
    );

    expect(segment, isNull);
  });
}
