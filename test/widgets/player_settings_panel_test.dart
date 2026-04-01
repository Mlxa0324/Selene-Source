import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/player_settings_panel.dart';

void main() {
  testWidgets('shows center control linked hiding switch with default on state',
      (tester) async {
    bool? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerSettingsPanel(
            theme: ThemeData.dark(),
            currentFitType: VideoFitType.contain,
            currentLongPressSpeed: 2.0,
            progressMode: ProgressDisplayMode.none,
            showSystemTime: false,
            hideCenterControlsWithBars: true,
            skipIntro: 0,
            skipOutro: 0,
            videoPosition: 0,
            videoDuration: 0,
            onFitTypeChanged: (_) {},
            onLongPressSpeedChanged: (_) {},
            onProgressModeChanged: (_) {},
            onShowSystemTimeChanged: (_) {},
            onHideCenterControlsWithBarsChanged: (value) {
              changedValue = value;
            },
            onSkipIntroChanged: (_) {},
            onSkipOutroChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('中间按钮跟随隐藏'), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(changedValue, isFalse);
  });
}
