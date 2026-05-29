import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_design_canvas.dart';
import 'package:selene/tv_app/widgets/tv_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('TV route page keeps zero-duration transitions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final route = TvRoute.page<void>(
      context: pageContext,
      child: const SizedBox.shrink(),
    );

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('TV route push keeps theme scope and design canvas',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final themeService = TvThemeService();
    await themeService.setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvDesignCanvas(
          preset: TvDesignPreset.fullHd1080,
          child: TvTheme(
            service: themeService,
            child: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    TvRoute.push<void>(
                      context,
                      const _TvRouteProbe(),
                    );
                  },
                  child: const Text('打开 TV 路由'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开 TV 路由'));
    await tester.pumpAndSettle();

    expect(find.text('奈飞红'), findsOneWidget);
    expect(find.text('1920x1080'), findsOneWidget);
  });
}

/// TV 路由上下文探针。
///
/// 用于验证新路由是否继承了主题作用域和设计画布上下文。
class _TvRouteProbe extends StatelessWidget {
  /// 创建 TV 路由上下文探针。
  const _TvRouteProbe();

  @override
  Widget build(BuildContext context) {
    final palette = TvTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(palette.label),
        Text(
          '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
        ),
      ],
    );
  }
}
