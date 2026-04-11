import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/models/search_resource.dart';
import 'package:selene/screens/source_browser_screen.dart';
import 'package:selene/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile source picker opens site root in browser action',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Uri? openedUri;

    await _pumpSourceBrowserScreen(
      tester,
      size: const Size(390, 844),
      onOpenSourceSite: (uri) async {
        openedUri = uri;
      },
      useDesktopStyleOverride: false,
    );

    await tester.tap(find.byIcon(LucideIcons.panelBottomOpen));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('source-browser-open-site-wolong')),
    );
    await tester.pumpAndSettle();

    expect(openedUri?.toString(), 'https://wolongzyw.com');
  });

  testWidgets('tablet source section exposes browser open action per source',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Uri? openedUri;

    await _pumpSourceBrowserScreen(
      tester,
      size: const Size(900, 1200),
      onOpenSourceSite: (uri) async {
        openedUri = uri;
      },
      useDesktopStyleOverride: true,
    );

    await tester.tap(
      find.byKey(const ValueKey('source-browser-open-site-wolong')),
    );
    await tester.pumpAndSettle();

    expect(openedUri?.toString(), 'https://wolongzyw.com');
  });

  testWidgets('source browser uses 外部打开 copy for site action', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _pumpSourceBrowserScreen(
      tester,
      size: const Size(900, 1200),
      onOpenSourceSite: (_) async {},
      useDesktopStyleOverride: true,
    );

    expect(find.text('外部打开'), findsOneWidget);
    expect(find.text('浏览器打开'), findsNothing);
  });
}

Future<void> _pumpSourceBrowserScreen(
  WidgetTester tester, {
  required Size size,
  required Future<void> Function(Uri uri) onOpenSourceSite,
  bool? useDesktopStyleOverride,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SourceBrowserScreen(
              availableSourcesLoader: () async => [
                SearchResource(
                  key: 'wolong',
                  name: '卧龙资源',
                  api: 'https://wolongzyw.com/api.php/provide/vod',
                  detail: '',
                  from: 'test',
                  disabled: false,
                ),
              ],
              onOpenSourceSite: onOpenSourceSite,
              useDesktopStyleOverride: useDesktopStyleOverride,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
