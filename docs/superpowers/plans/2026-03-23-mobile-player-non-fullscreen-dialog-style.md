# Mobile Player Non-Fullscreen Dialog Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify iOS and Android non-fullscreen player dialogs so `选集`, `换源`, `定时关闭`, and `设置` all use solid barriers and opaque panel backgrounds in both standard and short-drama flows.

**Architecture:** Keep the existing dialog structure and patch the style decisions at the entry layer and panel layer. Reuse each panel widget's existing `backgroundOpacity` input instead of adding a new abstraction, and extend the settings panel so it can render either as a side sheet or a bottom sheet with the same opaque styling.

**Tech Stack:** Flutter, Dart, widget tests, `flutter_test`

---

### Task 1: Lock in panel expectations with tests

**Files:**
- Create: `test/widgets/mobile_player_panel_style_test.dart`
- Test: `test/widgets/mobile_player_panel_style_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('PlayerEpisodesPanel uses opaque white background when requested',
    (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PlayerEpisodesPanel(
        theme: ThemeData.light(),
        episodes: const ['1'],
        episodesTitles: const ['第1集'],
        currentEpisodeIndex: 0,
        isReversed: false,
        onEpisodeTap: (_) {},
        onToggleOrder: () {},
        backgroundOpacity: 1.0,
        isCompact: false,
      ),
    ),
  );

  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(PlayerEpisodesPanel),
      matching: find.byType(Container),
    ).first,
  );
  final decoration = container.decoration as BoxDecoration;
  expect(decoration.color, Colors.white);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: FAIL until the test reliably locates the decorated panel containers and the settings panel can be asserted in bottom-sheet mode.

- [ ] **Step 3: Write minimal implementation**

Add targeted assertions for `PlayerEpisodesPanel`, `PlayerSourcesPanel`, `PlayerSleepTimerPanel`, and `PlayerSettingsPanel` opaque-background behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: PASS

### Task 2: Unify standard-player non-fullscreen dialog styling

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/widgets/player_settings_panel.dart`

- [ ] **Step 1: Write the failing test**

Extend the widget test to cover the settings panel's new bottom-sheet presentation mode and opaque background.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: FAIL because the settings panel only renders as a side sheet today.

- [ ] **Step 3: Write minimal implementation**

```dart
final useSolidBackground = !DeviceUtils.isPC() &&
    !_isFullscreen &&
    !_isWebFullscreen &&
    !_isEnteringLandscapeFullscreen;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: PASS after `player_screen.dart` and `player_settings_panel.dart` agree on opaque non-fullscreen mobile/tablet styling.

### Task 3: Bring short-drama dialogs to parity

**Files:**
- Modify: `lib/widgets/short_drama_controls.dart`

- [ ] **Step 1: Write the failing test**

If panel tests do not already cover the needed widget behavior, add a focused expectation for the short-drama settings sheet background.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: FAIL if the short-drama settings sheet remains semi-transparent.

- [ ] **Step 3: Write minimal implementation**

Use `Theme.of(context).scaffoldBackgroundColor` for short-drama dialog barriers and make the settings sheet background fully opaque.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: PASS

### Task 4: Format and verify

**Files:**
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/widgets/player_episodes_panel.dart`
- Modify: `lib/widgets/player_sources_panel.dart`
- Modify: `lib/widgets/player_sleep_timer_panel.dart`
- Modify: `lib/widgets/player_settings_panel.dart`
- Modify: `lib/widgets/short_drama_controls.dart`
- Modify: `test/widgets/mobile_player_panel_style_test.dart`

- [ ] **Step 1: Format touched files**

Run: `dart format lib/screens/player_screen.dart lib/widgets/player_episodes_panel.dart lib/widgets/player_sources_panel.dart lib/widgets/player_sleep_timer_panel.dart lib/widgets/player_settings_panel.dart lib/widgets/short_drama_controls.dart test/widgets/mobile_player_panel_style_test.dart`
Expected: files formatted with no errors

- [ ] **Step 2: Run targeted test suite**

Run: `flutter test test/widgets/mobile_player_panel_style_test.dart`
Expected: PASS

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: exit 0, or only pre-existing unrelated issues that are documented before completion
