import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/pc_player_controls.dart';

void main() {
  test('resolvePcCachedProgressSegment returns a full left segment when cached',
      () {
    final segment = resolvePcCachedProgressSegment(
      duration: const Duration(minutes: 20),
      position: const Duration(minutes: 5),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 12),
        ),
      ],
    );

    expect(segment, isNotNull);
    expect(segment!.start, 0);
    expect(segment.end, closeTo(0.6, 0.0001));
  });

  test('resolvePcCachedProgressSegment ignores invalid durations', () {
    final segment = resolvePcCachedProgressSegment(
      duration: Duration.zero,
      position: const Duration(minutes: 5),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 12),
        ),
      ],
    );

    expect(segment, isNull);
  });
}
