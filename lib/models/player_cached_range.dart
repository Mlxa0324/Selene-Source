class PlayerCachedRange {
  final Duration start;
  final Duration end;

  const PlayerCachedRange({
    required this.start,
    required this.end,
  });

  PlayerCachedRange copyWith({
    Duration? start,
    Duration? end,
  }) {
    return PlayerCachedRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  bool contains(Duration position) {
    return position >= start && position <= end;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PlayerCachedRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() {
    return 'PlayerCachedRange(start: $start, end: $end)';
  }
}
