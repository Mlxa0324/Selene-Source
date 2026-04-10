import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  test('preload tuning enables a five-minute forward buffer target', () {
    final tuning = resolveWebViewPreloadTuning(preloadEnabled: true);

    expect(tuning.targetForwardBuffer, const Duration(minutes: 5));
    expect(tuning.backBufferRetention, const Duration(minutes: 15));
    expect(tuning.preloadAttribute, 'auto');
  });

  test('preload tuning falls back to metadata when preload is disabled', () {
    final tuning = resolveWebViewPreloadTuning(preloadEnabled: false);

    expect(tuning.targetForwardBuffer, isNull);
    expect(tuning.backBufferRetention, isNull);
    expect(tuning.preloadAttribute, 'metadata');
  });

  test('decodeWebViewCachedRanges parses confirmed buffered ranges', () {
    final ranges = decodeWebViewCachedRanges([
      {
        'startMs': 0,
        'endMs': 180000,
      },
      {
        'startMs': 240000,
        'endMs': 360000,
      },
    ]);

    expect(
      ranges,
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 3),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 4),
          end: Duration(minutes: 6),
        ),
      ],
    );
  });

  test('decodeWebViewCachedRanges ignores invalid or empty ranges', () {
    final ranges = decodeWebViewCachedRanges([
      {
        'startMs': 120000,
        'endMs': 120000,
      },
      {
        'startMs': 'bad',
        'endMs': 180000,
      },
      'bad',
    ]);

    expect(ranges, isEmpty);
  });
}
