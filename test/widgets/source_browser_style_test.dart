import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selene/screens/source_browser_style.dart';

void main() {
  group('source browser copy', () {
    test('uses readable localized labels instead of placeholder marks', () {
      expect(sourceBrowserRefreshTooltip, equals('刷新数据源'));
      expect(sourceBrowserCategorySectionTitle, equals('分类'));
      expect(
        formatSourceBrowserCategoryError('boom'),
        equals('获取分类失败：boom'),
      );
      expect(
        formatSourceBrowserContentError('boom'),
        equals('获取内容失败：boom'),
      );

      expect(sourceBrowserRefreshTooltip.contains('?'), isFalse);
      expect(sourceBrowserCategorySectionTitle.contains('?'), isFalse);
      expect(formatSourceBrowserCategoryError('boom').contains('?'), isFalse);
      expect(formatSourceBrowserContentError('boom').contains('?'), isFalse);
    });
  });

  group('source browser section card style', () {
    test('matches show screen filter card background on light theme', () {
      final decoration = buildSourceBrowserSectionDecoration(
        isDarkMode: false,
        borderRadius: 24,
      );

      expect(decoration.color, equals(const Color(0xCCFFFFFF)));
      expect(decoration.boxShadow, isEmpty);
    });

    test('matches show screen filter card background on dark theme', () {
      final decoration = buildSourceBrowserSectionDecoration(
        isDarkMode: true,
        borderRadius: 24,
      );

      expect(decoration.color, equals(const Color(0x1AFFFFFF)));
      expect(decoration.boxShadow, isEmpty);
    });
  });

  group('source browser grid sizing', () {
    test('matches continue watching card width logic on phones', () {
      expect(
        calculateSourceBrowserCardWidth(
          availableWidth: 420,
          visibleCards: 2.75,
        ),
        closeTo(145.09, 0.01),
      );
    });

    test('caps card width like continue watching on wide tablets', () {
      expect(
        calculateSourceBrowserCardWidth(
          availableWidth: 1900,
          visibleCards: 7.75,
        ),
        equals(170),
      );
    });

    test('derives a concrete grid width that never exceeds the target width',
        () {
      final metrics = calculateSourceBrowserGridMetrics(
        availableWidth: 760,
        visibleCards: 5.75,
      );

      expect(metrics.crossAxisCount, equals(6));
      expect(metrics.itemWidth, closeTo(116.67, 0.01));
      expect(metrics.itemWidth <= metrics.targetWidth, isTrue);
    });
  });
}
