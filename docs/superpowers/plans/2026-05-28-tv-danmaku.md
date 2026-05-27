# TV 弹幕功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 TV 端在不依赖手机/PC 弹幕 UI 文件的前提下，复用同一套弹幕数据与渲染内核，支持自动匹配优先、手动匹配兜底、以及 TV 设置页的弹幕参数配置。

**Architecture:** TV 端保留 `DanmakuService`、`DanmakuSettings` 和 `canvas_danmaku` 作为共享内核，但所有 UI 和入口都放进 `lib/tv_app/` 下的新文件。TV 全屏播放器先自动匹配弹幕并渲染，只有自动失败或用户主动进入时才打开 TV 专属手动匹配面板；设置页则继续复用同一份持久化配置，只是用 TV 专属界面编辑。

**Tech Stack:** Flutter, `canvas_danmaku`, `SharedPreferences`, `Dio`, TV focus widgets, widget tests.

---

### Task 1: 补 TV 弹幕内核与测试

**Files:**
- Create: `lib/tv_app/services/tv_danmaku_service.dart`
- Create: `lib/tv_app/widgets/tv_danmaku_overlay.dart`
- Create: `test/tv_app/tv_danmaku_service_test.dart`
- Create: `test/tv_app/tv_danmaku_overlay_test.dart`
- Modify: `lib/services/danmaku_service.dart`
- Modify: `lib/models/danmaku_model.dart`

- [ ] **Step 1: Write the failing test**

```dart
// 期望 TV 专属服务能复用同一套 baseApi、settings、match、list 数据。
// 期望 overlay 能接收 DanmakuComment 并渲染为可测试的 canvas_danmaku 层。
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tv_app/tv_danmaku_service_test.dart test/tv_app/tv_danmaku_overlay_test.dart`
Expected: FAIL because TV 专属服务/overlay 还不存在。

- [ ] **Step 3: Write minimal implementation**

```dart
// TV 服务只做轻薄封装：复用 DanmakuService，补 TV 端需要的自动匹配、手动匹配、搜索框默认值和渲染帮助方法。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tv_app/tv_danmaku_service_test.dart test/tv_app/tv_danmaku_overlay_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/tv_app/services/tv_danmaku_service.dart lib/tv_app/widgets/tv_danmaku_overlay.dart lib/services/danmaku_service.dart lib/models/danmaku_model.dart test/tv_app/tv_danmaku_service_test.dart test/tv_app/tv_danmaku_overlay_test.dart
git commit -m "feat: add tv danmaku core"
```

### Task 2: 接入 TV 全屏播放器自动优先与手动兜底

**Files:**
- Modify: `lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- Modify: `lib/tv_app/screens/tv_video_detail_screen.dart`
- Create: `lib/tv_app/screens/tv_danmaku_match_screen.dart`
- Create: `lib/tv_app/screens/tv_danmaku_settings_screen.dart`
- Create: `test/tv_app/tv_fullscreen_player_danmaku_test.dart`
- Create: `test/tv_app/tv_danmaku_match_screen_test.dart`
- Create: `test/tv_app/tv_danmaku_settings_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// 期望 TV 全屏播放器先自动匹配弹幕。
// 期望自动失败后，菜单入口能打开 TV 专属手动匹配面板。
// 期望搜索框默认带入片名，且只支持删除/清空/确认。
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tv_app/tv_fullscreen_player_danmaku_test.dart test/tv_app/tv_danmaku_match_screen_test.dart test/tv_app/tv_danmaku_settings_screen_test.dart`
Expected: FAIL because TV 端还没接入弹幕自动匹配和专属面板。

- [ ] **Step 3: Write minimal implementation**

```dart
// TV 全屏播放器只在自己的菜单里增加弹幕入口，并把自动匹配/手动匹配/参数保存都接到 TV 专属文件。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tv_app/tv_fullscreen_player_danmaku_test.dart test/tv_app/tv_danmaku_match_screen_test.dart test/tv_app/tv_danmaku_settings_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/tv_app/screens/tv_fullscreen_player_screen.dart lib/tv_app/screens/tv_video_detail_screen.dart lib/tv_app/screens/tv_danmaku_match_screen.dart lib/tv_app/screens/tv_danmaku_settings_screen.dart test/tv_app/tv_fullscreen_player_danmaku_test.dart test/tv_app/tv_danmaku_match_screen_test.dart test/tv_app/tv_danmaku_settings_screen_test.dart
git commit -m "feat: tv fullscreen danmaku flow"
```

### Task 3: 接入 TV 设置页弹幕参数与回归验证

**Files:**
- Modify: `lib/tv_app/screens/tv_settings_screen.dart`
- Modify: `lib/tv_app/screens/tv_home_screen.dart`
- Modify: `test/tv_app/tv_home_screen_test.dart`
- Modify: `test/tv_app/tv_fullscreen_player_screen_test.dart`
- Modify: `test/tv_app/tv_video_library_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// 期望 TV 设置页可以编辑弹幕服务器地址和参数。
// 期望首页和视频库的返回/刷新行为不被弹幕改动破坏。
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tv_app/tv_home_screen_test.dart test/tv_app/tv_fullscreen_player_screen_test.dart test/tv_app/tv_video_library_screen_test.dart`
Expected: FAIL because TV 弹幕设置页和回归断言还没补齐。

- [ ] **Step 3: Write minimal implementation**

```dart
// TV 设置页继续复用同一份存储，但 UI 改为 TV 专属布局，确保弹幕参数能保存到 DanmakuService。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tv_app/tv_home_screen_test.dart test/tv_app/tv_fullscreen_player_screen_test.dart test/tv_app/tv_video_library_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/tv_app/screens/tv_settings_screen.dart lib/tv_app/screens/tv_home_screen.dart test/tv_app/tv_home_screen_test.dart test/tv_app/tv_fullscreen_player_screen_test.dart test/tv_app/tv_video_library_screen_test.dart
git commit -m "feat: tv danmaku settings"
```
