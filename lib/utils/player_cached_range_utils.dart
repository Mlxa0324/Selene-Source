import '../models/player_cached_range.dart';

List<PlayerCachedRange> accumulatePlayerCachedRanges({
  required List<PlayerCachedRange> existing,
  required List<PlayerCachedRange> incoming,
}) {
  if (existing.isEmpty) {
    return mergePlayerCachedRanges(incoming);
  }
  if (incoming.isEmpty) {
    return mergePlayerCachedRanges(existing);
  }
  return mergePlayerCachedRanges([
    ...existing,
    ...incoming,
  ]);
}

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

List<({double start, double end})> resolvePlayerCachedProgressSegments({
  required Duration duration,
  required List<PlayerCachedRange> cachedRanges,
}) {
  if (duration <= Duration.zero) {
    return const [];
  }

  final totalMilliseconds = duration.inMilliseconds;
  if (totalMilliseconds <= 0) {
    return const [];
  }

  return mergePlayerCachedRanges(cachedRanges)
      .map((range) {
        final start =
            (range.start.inMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
        final end =
            (range.end.inMilliseconds / totalMilliseconds).clamp(0.0, 1.0);
        return (start: start, end: end);
      })
      .where((segment) => segment.end > segment.start)
      .toList(growable: false);
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
