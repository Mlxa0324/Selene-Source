import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/global_back_handler.dart';

void main() {
  test('global back handler leaves Android back-like keys to platform', () {
    expect(
      GlobalBackHandler.shouldHandleShortcut(
        LogicalKeyboardKey.goBack,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      GlobalBackHandler.shouldHandleShortcut(
        LogicalKeyboardKey.browserBack,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      GlobalBackHandler.shouldHandleShortcut(
        LogicalKeyboardKey.escape,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      GlobalBackHandler.shouldHandleShortcut(
        LogicalKeyboardKey.browserBack,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
  });

  testWidgets('global back handler pops current route with escape key',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) {
          return GlobalBackHandler(
            navigatorKey: navigatorKey,
            child: child!,
          );
        },
        home: const _NavigationHome(),
      ),
    );

    await tester.tap(find.text('打开二级页'));
    await tester.pumpAndSettle();

    expect(find.text('二级页'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('二级页'), findsNothing);
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('global back handler lets focused child consume escape key',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) {
          return GlobalBackHandler(
            navigatorKey: navigatorKey,
            child: child!,
          );
        },
        home: const _ChildConsumesEscapeHome(),
      ),
    );

    await tester.tap(find.text('打开二级页'));
    await tester.pumpAndSettle();

    expect(find.text('二级页'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('二级页'), findsOneWidget);
  });
}

class _NavigationHome extends StatelessWidget {
  const _NavigationHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('首页'),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('二级页')),
                    ),
                  ),
                );
              },
              child: const Text('打开二级页'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildConsumesEscapeHome extends StatelessWidget {
  const _ChildConsumesEscapeHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _EscapeConsumingPage(),
              ),
            );
          },
          child: const Text('打开二级页'),
        ),
      ),
    );
  }
}

class _EscapeConsumingPage extends StatelessWidget {
  const _EscapeConsumingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent ||
                event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: const Text('二级页'),
        ),
      ),
    );
  }
}
