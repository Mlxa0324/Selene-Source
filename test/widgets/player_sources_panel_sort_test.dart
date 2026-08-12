import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/search_result.dart';
import 'package:selene/widgets/player_sources_panel.dart';

SearchResult _src({
  required String id,
  required String source,
  required String title,
  required int episodeCount,
}) {
  return SearchResult(
    id: id,
    title: title,
    poster: '',
    episodes: List<String>.filled(episodeCount, 'http://example.com/$id.m3u8'),
    episodesTitles: const [],
    source: source,
    sourceName: source,
    year: '2024',
  );
}

void main() {
  group('PlayerSourcesPanel sort by episode count', () {
    test('multi-episode sources are ordered by episode count descending', () {
      final input = [
        _src(id: 'a', source: 's1', title: 'A', episodeCount: 4),
        _src(id: 'b', source: 's2', title: 'B', episodeCount: 24),
        _src(id: 'c', source: 's3', title: 'C', episodeCount: 12),
      ];

      final result = PlayerSourcesPanel.computeSortedSourcesForTest(input);

      expect(result.map((e) => e.id).toList(), ['b', 'c', 'a']);
    });

    test('ties preserve the original relative order (stable)', () {
      final input = [
        _src(id: 'first', source: 's1', title: 'A', episodeCount: 12),
        _src(id: 'second', source: 's2', title: 'B', episodeCount: 24),
        _src(id: 'third', source: 's3', title: 'C', episodeCount: 24),
        _src(id: 'fourth', source: 's4', title: 'D', episodeCount: 12),
      ];

      final result = PlayerSourcesPanel.computeSortedSourcesForTest(input);

      // 同集数保持原顺序:24s -> second, third;12s -> first, fourth。
      expect(
        result.map((e) => e.id).toList(),
        ['second', 'third', 'first', 'fourth'],
      );
    });

    test('all-single-episode movie list keeps the original order', () {
      final input = [
        _src(id: 'a', source: 's1', title: 'A', episodeCount: 1),
        _src(id: 'b', source: 's2', title: 'B', episodeCount: 1),
        _src(id: 'c', source: 's3', title: 'C', episodeCount: 1),
      ];

      final result = PlayerSourcesPanel.computeSortedSourcesForTest(input);

      expect(result.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('mixed single and multi episode sources are ordered by absolute count',
        () {
      final input = [
        _src(id: 'single', source: 's1', title: 'A', episodeCount: 1),
        _src(id: 'multi', source: 's2', title: 'B', episodeCount: 12),
        _src(id: 'tiny', source: 's3', title: 'C', episodeCount: 2),
      ];

      final result = PlayerSourcesPanel.computeSortedSourcesForTest(input);

      // 按集数绝对值倒序,不做单集 / 多集分组。
      expect(result.map((e) => e.id).toList(), ['multi', 'tiny', 'single']);
    });

    test('empty list returns empty list', () {
      final result = PlayerSourcesPanel.computeSortedSourcesForTest(const []);
      expect(result, isEmpty);
    });

    test('original list is not mutated', () {
      final input = [
        _src(id: 'a', source: 's1', title: 'A', episodeCount: 4),
        _src(id: 'b', source: 's2', title: 'B', episodeCount: 24),
      ];
      final originalOrder = input.map((e) => e.id).toList();

      PlayerSourcesPanel.computeSortedSourcesForTest(input);

      expect(input.map((e) => e.id).toList(), originalOrder);
    });
  });
}
