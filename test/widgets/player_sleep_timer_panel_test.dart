import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:selene/models/app_theme_scheme.dart';
import 'package:selene/services/theme_service.dart';
import 'package:selene/widgets/player_sleep_timer_panel.dart';

void main() {
  group('PlayerSleepTimerPanel', () {
    testWidgets('keeps inline pickers collapsed by default on mobile platforms',
        (tester) async {
      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
        ),
      );

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('调整分钟数'), findsOneWidget);
      expect(find.text('调整时间'), findsOneWidget);
      expect(find.text('设置时间'), findsOneWidget);
      expect(find.text('设置分钟数'), findsOneWidget);
    });

    testWidgets('expands only the requested inline picker on mobile platforms',
        (tester) async {
      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.text('调整分钟数'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoPicker), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);

      await tester.tap(find.text('调整时间'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
    });

    testWidgets('keeps existing manual inputs on desktop platforms',
        (tester) async {
      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.macOS,
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('选择关闭时间点'), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.byType(CupertinoPicker), findsNothing);
    });

    testWidgets('shows custom minutes before clock time on mobile platforms',
        (tester) async {
      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
        ),
      );

      final customMinutesLabel = tester.getTopLeft(find.text('自定义分钟数'));
      final clockTimeLabel = tester.getTopLeft(find.text('指定时间'));

      expect(customMinutesLabel.dy, lessThan(clockTimeLabel.dy));
    });

    testWidgets('allows scrolling from the inline summary area on mobile',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(900, 520));

      final theme = ThemeData(
        brightness: Brightness.light,
        platform: TargetPlatform.android,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox.expand(
              child: PlayerSleepTimerPanel(
                theme: theme,
                sideSheet: false,
                canExitApp: true,
                scheduledAt: DateTime(2026, 3, 25, 22, 30),
                onSetMinutes: (_) async => false,
                onSetTimeOfDay: (_) async => false,
                onCancelTimer: () async => false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final before = tester.getTopLeft(find.text('指定时间')).dy;
      await tester.drag(
        find.byKey(const Key('sleep-timer-minutes-summary')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text('指定时间')).dy;

      expect(after, lessThan(before));
    });

    testWidgets('submits the selected inline time on mobile platforms',
        (tester) async {
      TimeOfDay? submittedTime;

      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
        ),
        scheduledAt: DateTime(2026, 3, 25, 22, 30),
        onSetTimeOfDay: (time) async {
          submittedTime = time;
          return false;
        },
      );

      await tester.tap(find.text('设置时间'));
      await tester.pumpAndSettle();

      expect(submittedTime, const TimeOfDay(hour: 22, minute: 30));
    });

    testWidgets('submits the selected inline minutes on mobile platforms',
        (tester) async {
      int? submittedMinutes;

      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
        ),
        onSetMinutes: (minutes) async {
          submittedMinutes = minutes;
          return false;
        },
      );

      await tester.tap(find.text('设置分钟数'));
      await tester.pumpAndSettle();

      expect(submittedMinutes, 45);
    });

    testWidgets('uses the active theme color for quick action surfaces',
        (tester) async {
      final accent = ColorScheme.fromSeed(
        seedColor: const Color(0xFF0393E7),
        brightness: Brightness.light,
      ).primary;

      await _pumpPanel(
        tester,
        theme: ThemeData(
          brightness: Brightness.light,
          platform: TargetPlatform.android,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0393E7),
            brightness: Brightness.light,
          ),
        ),
      );

      final quickButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '设置分钟数'),
      );
      final quickStyle =
          quickButton.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(quickStyle, equals(accent));

      final outlineButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '调整分钟数'),
      );
      final outlineColor =
          outlineButton.style!.foregroundColor!.resolve(<WidgetState>{});
      expect(outlineColor, equals(accent));
    });
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required ThemeData theme,
  DateTime? scheduledAt,
  Future<bool> Function(int minutes)? onSetMinutes,
  Future<bool> Function(TimeOfDay time)? onSetTimeOfDay,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(900, 1200));

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox.expand(
            child: PlayerSleepTimerPanel(
              theme: theme,
              sideSheet: false,
              canExitApp: true,
              scheduledAt: scheduledAt,
              onSetMinutes: onSetMinutes ?? (_) async => false,
              onSetTimeOfDay: onSetTimeOfDay ?? (_) async => false,
              onCancelTimer: () async => false,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
