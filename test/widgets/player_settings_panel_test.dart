import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selene/widgets/player_episodes_panel.dart';
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

  test('compact episode panel padding is reduced and stays centered friendly',
      () {
    final compactSingle =
        resolveEpisodeItemPadding(isCompact: true, lineCount: 1);
    final compactMulti =
        resolveEpisodeItemPadding(isCompact: true, lineCount: 3);
    final regularSingle =
        resolveEpisodeItemPadding(isCompact: false, lineCount: 1);
    final regularMulti =
        resolveEpisodeItemPadding(isCompact: false, lineCount: 3);

    expect(compactSingle.horizontal, 6);
    expect(compactSingle.vertical, 6);
    expect(compactMulti.vertical, 4);
    expect(regularSingle.horizontal, 6);
    expect(regularSingle.vertical, 8);
    expect(regularMulti.vertical, 5);
  });

  test('episode panel defaults to three columns', () {
    final panel = PlayerEpisodesPanel(
      theme: ThemeData.dark(),
      episodes: ['1', '2', '3'],
      episodesTitles: ['第1集', '第2集', '第3集'],
      currentEpisodeIndex: 0,
      isReversed: false,
      onEpisodeTap: _noopEpisodeTap,
      onToggleOrder: _noop,
    );

    expect(panel.crossAxisCount, 3);
  });
}

void _noopEpisodeTap(int _) {}

void _noop() {}
