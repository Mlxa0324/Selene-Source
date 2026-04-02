# Confirm Dialog Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable confirmation dialog with visible outlined cancel actions in both light and dark themes, then migrate the key destructive flows to it.

**Architecture:** Introduce a single shared `AppConfirmDialog` widget plus a `showAppConfirmDialog(...)` helper in `lib/widgets/`. Keep business logic in existing screens/widgets and replace only the dialog presentation layer. Migrate the first batch of destructive confirmations in two passes: existing custom large-card dialogs first, then download-related `AlertDialog` usages.

**Tech Stack:** Flutter `showDialog`, Material widgets, Provider-backed screens/widgets, widget tests with `flutter_test`

---

### Task 1: Create Shared Confirm Dialog Component

**Files:**
- Create: `lib/widgets/app_confirm_dialog.dart`
- Create: `test/widgets/app_confirm_dialog_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets('renders outlined cancel button in light mode', (tester) async {
  await tester.pumpWidget(_DialogHarness(brightness: Brightness.light));

  expect(find.text('取消'), findsOneWidget);
  expect(find.text('删除'), findsOneWidget);
  expect(find.byIcon(Icons.delete_outline), findsOneWidget);
});

testWidgets('renders outlined cancel button in dark mode', (tester) async {
  await tester.pumpWidget(_DialogHarness(brightness: Brightness.dark));

  expect(find.text('取消'), findsOneWidget);
  expect(find.text('删除'), findsOneWidget);
});
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/widgets/app_confirm_dialog_test.dart`

Expected: FAIL because `AppConfirmDialog` and `showAppConfirmDialog` do not exist yet.

- [ ] **Step 3: Write the minimal shared dialog implementation**

```dart
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = '取消',
    this.icon = Icons.delete_outline,
    this.isDanger = true,
    this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool isDanger;
  final VoidCallback? onConfirm;
}

Future<void> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  IconData icon = Icons.delete_outline,
  bool isDanger = true,
  required FutureOr<void> Function() onConfirm,
});
```

Implementation notes:
- Use `Theme.of(context).brightness` instead of depending on `ThemeService`.
- Keep the current large-card confirmation visual language.
- Make the cancel button an explicit outline button with visible borders in both themes.
- Pop the dialog before awaiting `onConfirm`.

- [ ] **Step 4: Run the component tests to verify they pass**

Run: `flutter test test/widgets/app_confirm_dialog_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the shared dialog**

```bash
git add lib/widgets/app_confirm_dialog.dart test/widgets/app_confirm_dialog_test.dart
git commit -m "feat: add shared confirm dialog"
```

### Task 2: Migrate Existing Custom Danger Dialogs

**Files:**
- Modify: `lib/widgets/continue_watching_section.dart`
- Modify: `lib/screens/search_screen.dart`
- Modify: `test/widgets/app_confirm_dialog_test.dart`

- [ ] **Step 1: Extend the dialog tests with action-label variants**

```dart
testWidgets('supports clear-style labels with shared layout', (tester) async {
  await tester.pumpWidget(_DialogHarness(
    brightness: Brightness.light,
    title: '清空播放记录',
    message: '确定要清空所有播放记录吗？此操作无法撤销。',
    confirmLabel: '清空',
  ));

  expect(find.text('清空播放记录'), findsOneWidget);
  expect(find.text('清空'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify the new scenario fails**

Run: `flutter test test/widgets/app_confirm_dialog_test.dart`

Expected: FAIL until the harness and shared dialog support the migrated copy and button styles cleanly.

- [ ] **Step 3: Replace the inline AlertDialog UI in the two clear flows**

Implementation notes:
- Keep `_clearPlayRecords()` and `_clearSearchHistory()` behavior unchanged.
- Replace only the dialog-building code with `showAppConfirmDialog(...)`.
- Preserve current titles/messages/button labels.
- Remove duplicated icon/text/button styling from the two files.

- [ ] **Step 4: Re-run the shared dialog tests**

Run: `flutter test test/widgets/app_confirm_dialog_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the clear-flow migration**

```bash
git add lib/widgets/continue_watching_section.dart lib/screens/search_screen.dart test/widgets/app_confirm_dialog_test.dart
git commit -m "refactor: use shared confirm dialog for clear flows"
```

### Task 3: Migrate Download Confirmations

**Files:**
- Modify: `lib/screens/download_screen.dart`
- Modify: `lib/widgets/player_download_panel.dart`
- Create: `test/screens/download_screen_confirm_dialog_test.dart`
- Create: `test/widgets/player_download_panel_confirm_dialog_test.dart`

- [ ] **Step 1: Write the failing download confirmation tests**

```dart
testWidgets('download screen uses shared confirm dialog for single delete', (tester) async {
  await tester.pumpWidget(_DownloadScreenHarness.withCompletedTask());

  await tester.tap(find.byIcon(Icons.delete_outline).first);
  await tester.pumpAndSettle();

  expect(find.text('删除任务'), findsOneWidget);
  expect(find.text('取消'), findsOneWidget);
  expect(find.text('删除'), findsOneWidget);
});

testWidgets('player download panel uses shared confirm dialog for downloaded item', (tester) async {
  await tester.pumpWidget(_PlayerDownloadPanelHarness.withCompletedTask());

  await tester.tap(find.text('第1集'));
  await tester.pumpAndSettle();

  expect(find.text('删除缓存'), findsOneWidget);
  expect(find.text('取消'), findsOneWidget);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/screens/download_screen_confirm_dialog_test.dart test/widgets/player_download_panel_confirm_dialog_test.dart`

Expected: FAIL because these flows still render raw `AlertDialog`.

- [ ] **Step 3: Replace download-related AlertDialog usages**

Implementation notes:
- In `download_screen.dart`, migrate `_confirmDelete` and `_confirmBatchDelete`.
- In `player_download_panel.dart`, migrate `删除缓存` and `取消下载`.
- Keep deletion/cancellation side effects exactly as they are today.
- Use context-appropriate confirm labels: `删除`, `全部删除`, `取消下载`.

- [ ] **Step 4: Run the new download confirmation tests**

Run: `flutter test test/screens/download_screen_confirm_dialog_test.dart test/widgets/player_download_panel_confirm_dialog_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the download-flow migration**

```bash
git add lib/screens/download_screen.dart lib/widgets/player_download_panel.dart test/screens/download_screen_confirm_dialog_test.dart test/widgets/player_download_panel_confirm_dialog_test.dart
git commit -m "refactor: use shared confirm dialog for download flows"
```

### Task 4: Verify, Update Changelog, and Hand Off

**Files:**
- Modify: `AGENTS.md`
- Verify: `lib/widgets/app_confirm_dialog.dart`
- Verify: `lib/widgets/continue_watching_section.dart`
- Verify: `lib/screens/search_screen.dart`
- Verify: `lib/screens/download_screen.dart`
- Verify: `lib/widgets/player_download_panel.dart`
- Verify: `test/widgets/app_confirm_dialog_test.dart`
- Verify: `test/screens/download_screen_confirm_dialog_test.dart`
- Verify: `test/widgets/player_download_panel_confirm_dialog_test.dart`

- [ ] **Step 1: Add a changelog entry**

Update `AGENTS.md` with a new `2026-04-02` entry covering:
- shared confirmation dialog
- outlined cancel button visibility in both themes
- download-management confirmations migrated to the shared dialog

- [ ] **Step 2: Run the focused test suite**

Run:

```bash
flutter test test/widgets/app_confirm_dialog_test.dart test/screens/download_screen_confirm_dialog_test.dart test/widgets/player_download_panel_confirm_dialog_test.dart
```

Expected: PASS

- [ ] **Step 3: Run targeted analysis**

Run:

```bash
dart analyze lib/widgets/app_confirm_dialog.dart lib/widgets/continue_watching_section.dart lib/screens/search_screen.dart lib/screens/download_screen.dart lib/widgets/player_download_panel.dart test/widgets/app_confirm_dialog_test.dart test/screens/download_screen_confirm_dialog_test.dart test/widgets/player_download_panel_confirm_dialog_test.dart
```

Expected: no new errors; pre-existing info-level warnings may remain and should be called out explicitly.

- [ ] **Step 4: Manual verification**

Check these flows on device/emulator in both themes:
- Continue Watching -> clear play history
- Search -> clear search history
- Download management -> delete one task
- Download management -> batch delete
- Player download panel -> delete cached episode
- Player download panel -> cancel in-progress download

- [ ] **Step 5: Commit the verification/changelog pass**

```bash
git add AGENTS.md
git commit -m "docs: record confirm dialog unification"
```
