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

void main() {
  testWidgets('renders outlined cancel button in light mode', (tester) async {
    await tester.pumpWidget(const _DialogHarness(brightness: Brightness.light));

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('renders outlined cancel button in dark mode', (tester) async {
    await tester.pumpWidget(const _DialogHarness(brightness: Brightness.dark));

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });
}
