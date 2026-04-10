import '../models/player_cached_range.dart';

List<PlayerCachedRange> mergePlayerCachedRanges(List<PlayerCachedRange> ranges) {
  if (ranges.isEmpty) {
    return const [];
  }

  final sorted = List<PlayerCachedRange>.from(ranges)
    ..sort((a, b) => a.start.compareTo(b.start));

  final merged = <PlayerCachedRange>[sorted.first];
  for (final next in sorted.skip(1)) {
    final current = merged.last;
    if (next.start <= current.end) {
      merged[merged.length - 1] = current.copyWith(
        end: next.end > current.end ? next.end : current.end,
      );
      continue;
    }

    if (next.start == current.end) {
      merged[merged.length - 1] = current.copyWith(end: next.end);
      continue;
    }

    merged.add(next);
  }

  return merged;
}

PlayerCachedRange? findContainingPlayerCachedRange(
  Duration position,
  List<PlayerCachedRange> ranges,
) {
  for (final range in mergePlayerCachedRanges(ranges)) {
    if (range.contains(position)) {
      return range;
    }
  }
  return null;
}

PlayerCachedRange? findPrimaryPlayerCachedRange(
  Duration position,
  List<PlayerCachedRange> ranges,
) {
  final merged = mergePlayerCachedRanges(ranges);
  final containing = findContainingPlayerCachedRange(position, merged);
  if (containing != null) {
    return containing;
  }
  if (merged.isEmpty) {
    return null;
  }
  return merged.first;
}
