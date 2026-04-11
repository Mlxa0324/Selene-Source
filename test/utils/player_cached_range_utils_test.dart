import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/utils/player_cached_range_utils.dart';

void main() {
  test('accumulatePlayerCachedRanges keeps previous and new cached segments', () {
    final merged = accumulatePlayerCachedRanges(
      existing: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 3),
        ),
      ],
      incoming: const [
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 8),
        ),
      ],
    );

    expect(
      merged,
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 3),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 8),
        ),
      ],
    );
  });

  test('resolvePlayerCachedProgressSegments preserves disconnected segments', () {
    final segments = resolvePlayerCachedProgressSegments(
      duration: const Duration(minutes: 10),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 2),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 8),
        ),
      ],
    );

    expect(segments, hasLength(2));
    expect(segments[0].start, 0);
    expect(segments[0].end, closeTo(0.2, 0.0001));
    expect(segments[1].start, closeTo(0.6, 0.0001));
    expect(segments[1].end, closeTo(0.8, 0.0001));
  });

  test('mergePlayerCachedRanges merges overlapping and adjacent ranges', () {
    final merged = mergePlayerCachedRanges([
      const PlayerCachedRange(
        start: Duration.zero,
        end: Duration(minutes: 2),
      ),
      const PlayerCachedRange(
        start: Duration(minutes: 2),
        end: Duration(minutes: 4),
      ),
      const PlayerCachedRange(
        start: Duration(minutes: 6),
        end: Duration(minutes: 7),
      ),
    ]);

    expect(
      merged,
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 4),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 7),
        ),
      ],
    );
  });

  test('findContainingPlayerCachedRange only returns confirmed range hits', () {
    final hit = findContainingPlayerCachedRange(
      const Duration(minutes: 3),
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 5),
        ),
      ],
    );

    expect(hit, isNotNull);
    expect(
      hit,
      const PlayerCachedRange(
        start: Duration.zero,
        end: Duration(minutes: 5),
      ),
    );

    final miss = findContainingPlayerCachedRange(
      const Duration(minutes: 18),
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 5),
        ),
      ],
    );

    expect(miss, isNull);
  });

  test('findPrimaryPlayerCachedRange prefers the range containing position', () {
    final primary = findPrimaryPlayerCachedRange(
      const Duration(minutes: 8),
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 3),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 10),
        ),
      ],
    );

    expect(
      primary,
      const PlayerCachedRange(
        start: Duration(minutes: 6),
        end: Duration(minutes: 10),
      ),
    );
  });
}
