import 'package:flutter/material.dart';

class SourceBrowserGridMetrics {
  const SourceBrowserGridMetrics({
    required this.targetWidth,
    required this.crossAxisCount,
    required this.itemWidth,
    required this.itemHeight,
    required this.childAspectRatio,
  });

  final double targetWidth;
  final int crossAxisCount;
  final double itemWidth;
  final double itemHeight;
  final double childAspectRatio;
}

const String sourceBrowserRefreshTooltip = '刷新数据源';
const String sourceBrowserCategorySectionTitle = '分类';
const double sourceBrowserCardSpacing = 12.0;
const double sourceBrowserMinCardWidth = 120.0;
const double sourceBrowserMaxCardWidth = 170.0;

String formatSourceBrowserCategoryError(Object error) => '获取分类失败：$error';

String formatSourceBrowserContentError(Object error) => '获取内容失败：$error';

double calculateSourceBrowserCardWidth({
  required double availableWidth,
  required double visibleCards,
}) {
  final calculatedCardWidth =
      (availableWidth - (sourceBrowserCardSpacing * (visibleCards - 1))) /
          visibleCards;
  return calculatedCardWidth
      .clamp(sourceBrowserMinCardWidth, sourceBrowserMaxCardWidth)
      .toDouble();
}

double calculateSourceBrowserCardAspectRatio(double cardWidth) {
  final cardHeight = (cardWidth * 1.5) + 60;
  return cardWidth / cardHeight;
}

SourceBrowserGridMetrics calculateSourceBrowserGridMetrics({
  required double availableWidth,
  required double visibleCards,
}) {
  final targetWidth = calculateSourceBrowserCardWidth(
    availableWidth: availableWidth,
    visibleCards: visibleCards,
  );
  final crossAxisCount = ((availableWidth + sourceBrowserCardSpacing) /
          (targetWidth + sourceBrowserCardSpacing))
      .ceil()
      .clamp(1, 1000);
  final itemWidth =
      (availableWidth - (sourceBrowserCardSpacing * (crossAxisCount - 1))) /
          crossAxisCount;
  final itemHeight = (itemWidth * 1.5) + 60;

  return SourceBrowserGridMetrics(
    targetWidth: targetWidth,
    crossAxisCount: crossAxisCount,
    itemWidth: itemWidth,
    itemHeight: itemHeight,
    childAspectRatio: itemWidth / itemHeight,
  );
}

Color sourceBrowserSectionBackgroundColor({required bool isDarkMode}) {
  return isDarkMode ? const Color(0x1AFFFFFF) : const Color(0xCCFFFFFF);
}

BoxDecoration buildSourceBrowserSectionDecoration({
  required bool isDarkMode,
  double borderRadius = 24,
}) {
  return BoxDecoration(
    color: sourceBrowserSectionBackgroundColor(isDarkMode: isDarkMode),
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: const [],
  );
}
