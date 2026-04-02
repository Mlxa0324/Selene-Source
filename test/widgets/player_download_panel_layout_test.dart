import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/player_download_panel.dart';

void main() {
  test('uses wider taller three-line cards for mobile tablets with long titles',
      () {
    final layout = resolvePlayerDownloadGridLayout(
      gridWidth: 420,
      isTablet: true,
      isPC: false,
      isCompact: true,
      titles: const [
        '20260315魔力sir超会变团魂险拍舞台彩排完整版',
        '20260316魔法小切合萨返场特别纪录全片段',
        '20260317魔力小剧场真的很长真的很长真的很长',
      ],
      textDirection: TextDirection.ltr,
    );

    expect(layout.usesMainAxisExtent, isTrue);
    expect(layout.crossAxisCount, 3);
    expect(layout.mainAxisExtent, inInclusiveRange(80.0, 96.0));
    expect(layout.titleMaxLines, 3);
  });

  test('keeps the compact default grid for phones', () {
    final layout = resolvePlayerDownloadGridLayout(
      gridWidth: 360,
      isTablet: false,
      isPC: false,
      isCompact: true,
      titles: const ['第1集'],
      textDirection: TextDirection.ltr,
    );

    expect(layout.usesMainAxisExtent, isFalse);
    expect(layout.crossAxisCount, 4);
    expect(layout.childAspectRatio, 3.2);
    expect(layout.titleMaxLines, 2);
  });
}
