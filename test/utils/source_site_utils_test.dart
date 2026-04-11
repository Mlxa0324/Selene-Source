import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/search_resource.dart';
import 'package:selene/utils/source_site_utils.dart';

void main() {
  test('resolveSourceSiteRootUri strips api path and query', () {
    final uri = resolveSourceSiteRootUri(
      'https://wolongzyw.com/api.php/provide/vod?ac=detail&wd=test',
    );

    expect(uri, isNotNull);
    expect(uri.toString(), 'https://wolongzyw.com');
  });

  test('resolveSearchResourceSiteRootUri falls back to detail', () {
    final uri = resolveSearchResourceSiteRootUri(
      SearchResource(
        key: 'wolong',
        name: '卧龙',
        api: '',
        detail: 'https://wolongzyw.com/detail.php',
        from: 'test',
        disabled: false,
      ),
    );

    expect(uri, isNotNull);
    expect(uri.toString(), 'https://wolongzyw.com');
  });
}
