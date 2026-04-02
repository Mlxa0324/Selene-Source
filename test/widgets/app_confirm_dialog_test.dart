import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/app_confirm_dialog.dart';

class _DialogHarness extends StatelessWidget {
  const _DialogHarness({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        useMaterial3: false,
      ),
      home: Scaffold(
        body: Center(
          child: AppConfirmDialog(
            title: '删除任务',
            message: '确定要删除这个任务吗？',
            confirmLabel: '删除',
          ),
        ),
      ),
    );
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  _RecordingNavigatorObserver(this.events);

  final List<String> events;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add('dialog-popped');
    super.didPop(route, previousRoute);
  }
}

class _ShowDialogHarness extends StatelessWidget {
  const _ShowDialogHarness({
    required this.brightness,
    required this.events,
    required this.confirmGate,
    required this.observer,
  });

  final Brightness brightness;
  final List<String> events;
  final Completer<void> confirmGate;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        useMaterial3: false,
      ),
      navigatorObservers: [observer],
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    showAppConfirmDialog(
                      context: context,
                      title: '删除任务',
                      message: '确定要删除这个任务吗？',
                      confirmLabel: '删除',
                      onConfirm: () async {
                        events.add('confirm-start');
                        await confirmGate.future;
                        events.add('confirm-end');
                      },
                    ),
                  );
                },
                child: const Text('打开确认框'),
              );
            },
          ),
        ),
      ),
    );
  }
}

void _expectOutlinedCancelButton(WidgetTester tester) {
  final outlinedButton =
      tester.widget<OutlinedButton>(find.byType(OutlinedButton));
  final side = outlinedButton.style?.side?.resolve(<MaterialState>{});

  expect(side, isNotNull);
  expect(side!.width, greaterThan(0));
}

void main() {
  testWidgets('renders outlined cancel button in light mode', (tester) async {
    await tester.pumpWidget(const _DialogHarness(brightness: Brightness.light));

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    _expectOutlinedCancelButton(tester);
  });

  testWidgets('renders outlined cancel button in dark mode', (tester) async {
    await tester.pumpWidget(const _DialogHarness(brightness: Brightness.dark));

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    _expectOutlinedCancelButton(tester);
  });

  testWidgets('runs async confirm only after the dialog closes',
      (tester) async {
    final events = <String>[];
    final confirmGate = Completer<void>();
    final observer = _RecordingNavigatorObserver(events);

    await tester.pumpWidget(
      _ShowDialogHarness(
        brightness: Brightness.light,
        events: events,
        confirmGate: confirmGate,
        observer: observer,
      ),
    );

    await tester.tap(find.text('打开确认框'));
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmDialog), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmDialog), findsNothing);
    expect(
        events, containsAllInOrder(<String>['dialog-popped', 'confirm-start']));
    expect(events, isNot(contains('confirm-end')));

    confirmGate.complete();
    await tester.pumpAndSettle();

    expect(events, contains('confirm-end'));
  });
}
