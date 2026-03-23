import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/video_card.dart';

void main() {
  group('video card source label visibility', () {
    test('keeps source labels for search cards', () {
      expect(shouldShowVideoCardSourceLabel('search'), isTrue);
    });

    test('hides source labels for source browser cards', () {
      expect(shouldShowVideoCardSourceLabel('source_browser'), isFalse);
    });
  });
}
