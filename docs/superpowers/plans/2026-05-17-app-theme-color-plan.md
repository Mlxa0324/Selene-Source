# App Theme Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fixed global app theme color selector in app settings with five curated video-app color schemes, persisted across launches.

**Architecture:** Introduce a small theme-scheme model owned by `ThemeService`, persist the selected scheme through `UserDataService`, and expose a new selector inside `UserMenu`. Then route the most visible hard-coded green accent surfaces through the shared theme accent so the change is obvious across the app.

**Tech Stack:** Flutter, Provider, SharedPreferences, flutter_test

---

### Task 1: Lock behavior with tests

**Files:**
- Modify: `test/services/user_data_service_preload_test.dart`
- Modify: `test/widgets/user_menu_preload_setting_test.dart`
- Create: `test/services/theme_service_test.dart`

- [ ] **Step 1: Write failing persistence tests**
- [ ] **Step 2: Run targeted tests and confirm failures**
- [ ] **Step 3: Write failing settings UI tests for theme color selector**
- [ ] **Step 4: Run targeted widget tests and confirm failures**

### Task 2: Implement theme scheme persistence

**Files:**
- Create: `lib/models/app_theme_scheme.dart`
- Modify: `lib/services/user_data_service.dart`
- Modify: `lib/services/theme_service.dart`

- [ ] **Step 1: Add fixed theme scheme enum/model**
- [ ] **Step 2: Add save/get helpers in `UserDataService`**
- [ ] **Step 3: Load selected scheme in `ThemeService` and notify listeners**
- [ ] **Step 4: Re-run targeted persistence tests**

### Task 3: Add settings entry and wire app accents

**Files:**
- Modify: `lib/widgets/user_menu.dart`
- Modify: `lib/widgets/custom_refresh_indicator.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/movie_screen.dart`
- Modify: `lib/screens/tv_screen.dart`
- Modify: `lib/screens/anime_screen.dart`
- Modify: `lib/screens/show_screen.dart`
- Modify: `lib/screens/source_browser_screen.dart`
- Modify: `lib/widgets/top_tab_switcher.dart`
- Modify: `lib/widgets/capsule_tab_switcher.dart`
- Modify: `lib/widgets/simple_tab_switcher.dart`
- Modify: `lib/widgets/filter_pill_hover.dart`

- [ ] **Step 1: Add “主题色” selector in app settings**
- [ ] **Step 2: Connect user selection to `ThemeService`**
- [ ] **Step 3: Replace the highest-visibility green accents with shared theme accent**
- [ ] **Step 4: Re-run targeted widget tests**

### Task 4: Verify and document

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Run focused test suite for touched behavior**
- [ ] **Step 2: Update changelog with the new theme color setting**
- [ ] **Step 3: Review diff for unintended theme regressions**
