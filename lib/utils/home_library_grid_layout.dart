const double _tabletMainAxisSpacing = 14.0;
const double _mobileMainAxisSpacing = 16.0;
const double _tabletItemHeightRatio = 2.12;
const double _mobileItemHeightRatio = 2.0;

double homeLibraryGridMainAxisSpacing({required bool isTablet}) {
  return isTablet ? _tabletMainAxisSpacing : _mobileMainAxisSpacing;
}

double homeLibraryGridItemHeight({
  required double itemWidth,
  required bool isTablet,
}) {
  final ratio = isTablet ? _tabletItemHeightRatio : _mobileItemHeightRatio;
  return itemWidth * ratio;
}
