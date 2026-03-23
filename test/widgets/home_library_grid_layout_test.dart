import 'package:flutter_test/flutter_test.dart';

import 'package:selene/utils/home_library_grid_layout.dart';

void main() {
  group('home library grid layout', () {
    test('keeps extra vertical spacing on tablets', () {
      expect(homeLibraryGridMainAxisSpacing(isTablet: true), equals(14.0));
      expect(homeLibraryGridMainAxisSpacing(isTablet: false), equals(16.0));
    });

    test('gives tablet cards a little more height headroom', () {
      expect(
        homeLibraryGridItemHeight(itemWidth: 120, isTablet: true),
        closeTo(254.4, 0.001),
      );
      expect(
        homeLibraryGridItemHeight(itemWidth: 120, isTablet: false),
        equals(240.0),
      );
    });
  });
}
