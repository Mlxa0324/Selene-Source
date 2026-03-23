import 'package:flutter/material.dart';

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
