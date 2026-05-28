import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/widgets/tv_design_canvas.dart';

void main() {
  test('resolves fixed TV design presets', () {
    expect(TvDesignPreset.hd720.designSize, const Size(1280, 720));
    expect(TvDesignPreset.fullHd1080.designSize, const Size(1920, 1080));
    expect(TvDesignPreset.qhd1440.designSize, const Size(2560, 1440));
  });

  test('auto preset resolves 1080p viewport to full HD preset', () {
    expect(
      TvDesignPreset.auto.resolve(const Size(1920, 1080)),
      TvDesignPreset.fullHd1080,
    );
  });

  test('auto preset resolves 720p viewport to HD preset', () {
    expect(
      TvDesignPreset.auto.resolve(const Size(1280, 720)),
      TvDesignPreset.hd720,
    );
  });

  testWidgets('keeps 1080p viewport at TV design canvas size', (tester) async {
    _setTvViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: TvDesignCanvas(
          preset: TvDesignPreset.fullHd1080,
          child: _TvDesignProbe(
            scaleKey: ValueKey('tv-design-scale'),
            sizeKey: ValueKey('tv-design-size'),
          ),
        ),
      ),
    );

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('1920x1080'), findsOneWidget);
  });

  testWidgets('keeps design canvas when pushing TV themed routes',
      (tester) async {
    _setTvViewport(tester);

    final themeService = TvThemeService();

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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TvTheme.wrapScope(
                          context: context,
                          child: const _TvDesignProbe(
                            scaleKey: ValueKey('tv-route-scale'),
                            sizeKey: ValueKey('tv-route-size'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('打开路由'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开路由'));
    await tester.pumpAndSettle();

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('1920x1080'), findsOneWidget);
  });

  testWidgets('keeps auto preset when pushing TV themed routes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeService = TvThemeService();

    await tester.pumpWidget(
      MaterialApp(
        home: TvDesignCanvas(
          preset: TvDesignPreset.auto,
          child: TvTheme(
            service: themeService,
            child: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TvTheme.wrapScope(
                          context: context,
                          child: const _TvDesignProbe(
                            scaleKey: ValueKey('tv-auto-route-scale'),
                            sizeKey: ValueKey('tv-auto-route-size'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('打开自动路由'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开自动路由'));
    await tester.pumpAndSettle();

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('1280x720'), findsOneWidget);
  });

  testWidgets('auto preset keeps 720p viewport at HD canvas size',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: TvDesignCanvas(
          preset: TvDesignPreset.auto,
          child: _TvDesignProbe(
            scaleKey: ValueKey('tv-auto-scale'),
            sizeKey: ValueKey('tv-auto-size'),
          ),
        ),
      ),
    );

    expect(find.text('1.00'), findsOneWidget);
    expect(find.text('1280x720'), findsOneWidget);
  });
}

/// 配置 TV 测试视口。
///
/// 使用 1080p 视口验证 TV 设计画布行为。
void _setTvViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// TV 设计视口探针。
///
/// 用于测试设计缩放后的比例和逻辑画布尺寸。
class _TvDesignProbe extends StatelessWidget {
  /// 创建设计视口探针。
  const _TvDesignProbe({
    required this.scaleKey,
    required this.sizeKey,
  });

  /// 缩放文本 Key。
  final Key scaleKey;

  /// 尺寸文本 Key。
  final Key sizeKey;

  @override
  Widget build(BuildContext context) {
    final metrics = TvDesignCanvas.of(context);
    final size = MediaQuery.sizeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metrics.scale.toStringAsFixed(2),
          key: scaleKey,
        ),
        Text(
          '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
          key: sizeKey,
        ),
      ],
    );
  }
}
