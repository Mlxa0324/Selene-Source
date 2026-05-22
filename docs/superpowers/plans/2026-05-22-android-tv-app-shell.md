# Android TV App Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在同一套 Flutter 代码中新增 Android TV 独立入口，让 Android TV 跳过登录直接进入 TV 化首页，其他端保持现有启动逻辑。

**Architecture:** Android 原生层通过 `selene/device` MethodChannel 判断 TV 设备，Flutter 侧新增 `AppDeviceService` 与启动分流组件。TV 页面和组件放入 `lib/tv_app/`，数据层复用现有 services/models，普通端页面不依赖 TV 模块。

**Tech Stack:** Flutter, Dart, Kotlin, MethodChannel, Provider, flutter_test

---

## File Map

- Create: `lib/models/app_device_type.dart`
  - 定义应用设备形态枚举。
- Create: `lib/services/app_device_service.dart`
  - 封装 Android TV 原生判断和非 Android 平台降级逻辑。
- Modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`
  - 新增 `selene/device` MethodChannel，返回 `isAndroidTv`。
- Create: `lib/app_bootstrap.dart`
  - 根据设备类型选择 `TvAppShell` 或现有 `AppWrapper`。
- Modify: `lib/main.dart`
  - `MaterialApp.home` 改为 `AppBootstrap`。
- Create: `lib/tv_app/tv_app_shell.dart`
  - TV 根壳，承载 TV 首页和基础背景。
- Create: `lib/tv_app/screens/tv_home_screen.dart`
  - TV 首页，内容对齐普通首页但布局 TV 化。
- Create: `lib/tv_app/widgets/tv_focusable.dart`
  - TV 焦点封装，统一焦点态样式。
- Create: `lib/tv_app/widgets/tv_top_nav.dart`
  - TV 顶部 tab 导航。
- Create: `lib/tv_app/widgets/tv_home_section.dart`
  - TV 首页横向内容区。
- Create: `lib/tv_app/widgets/tv_video_card.dart`
  - TV 大屏视频卡片。
- Create: `test/services/app_device_service_test.dart`
  - 覆盖设备类型解析与平台降级。
- Create: `test/app_bootstrap_test.dart`
  - 覆盖 TV/非 TV 启动分流。
- Create: `test/tv_app/tv_home_screen_test.dart`
  - 覆盖 TV 首页基础渲染。
- Modify: `AGENTS.md`
  - 更新变更记录。

## Task 1: 设备类型服务

**Files:**
- Create: `lib/models/app_device_type.dart`
- Create: `lib/services/app_device_service.dart`
- Create: `test/services/app_device_service_test.dart`

- [ ] **Step 1: 写设备类型解析测试**

新增测试覆盖：

- `true` 解析为 `AppDeviceType.tv`
- `false` 在 Android 语义下解析为 `AppDeviceType.phone`
- 原生调用异常时返回 `AppDeviceType.unknown`

Run: `flutter test test/services/app_device_service_test.dart`

Expected: FAIL，接口尚未实现。

- [ ] **Step 2: 实现设备类型枚举和服务**

实现要求：

- 枚举字段带注释。
- `AppDeviceService` 通过构造参数接收可替换的 native checker，便于测试。
- 非 Android 平台不调用原生 TV 判断。
- Android TV 判断失败返回 `unknown`，启动分流负责降级。

- [ ] **Step 3: 运行设备类型测试**

Run: `flutter test test/services/app_device_service_test.dart`

Expected: PASS。

## Task 2: Android 原生 TV 判断通道

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/selene/MainActivity.kt`

- [ ] **Step 1: 新增 `selene/device` MethodChannel**

在 `MainActivity.configureFlutterEngine` 中注册新通道，方法名为 `isAndroidTv`。

- [ ] **Step 2: 实现原生判断方法**

判断条件：

- `UiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION`
- `packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)`
- `packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)`

任一命中即返回 `true`。

- [ ] **Step 3: 运行静态检查**

Run: `flutter analyze`

Expected: PASS 或只剩项目既有无关提示。

## Task 3: 启动分流

**Files:**
- Create: `lib/app_bootstrap.dart`
- Modify: `lib/main.dart`
- Create: `test/app_bootstrap_test.dart`

- [ ] **Step 1: 写启动分流测试**

测试覆盖：

- 注入 TV 设备类型时显示 `TvAppShell`
- 注入非 TV/unknown 时显示现有 `AppWrapper`

Run: `flutter test test/app_bootstrap_test.dart`

Expected: FAIL，启动分流尚未实现。

- [ ] **Step 2: 实现 `AppBootstrap`**

实现要求：

- 使用 `FutureBuilder` 等待设备类型。
- 加载中显示现有风格的轻量启动页。
- `AppDeviceType.tv` 返回 `TvAppShell`。
- 其他设备返回 `AppWrapper`。

- [ ] **Step 3: 接入 `main.dart`**

把 `MaterialApp.home` 从 `const AppWrapper()` 改为 `const AppBootstrap()`。

- [ ] **Step 4: 运行启动分流测试**

Run: `flutter test test/app_bootstrap_test.dart`

Expected: PASS。

## Task 4: TV 基础组件

**Files:**
- Create: `lib/tv_app/widgets/tv_focusable.dart`
- Create: `lib/tv_app/widgets/tv_video_card.dart`
- Create: `lib/tv_app/widgets/tv_home_section.dart`
- Create: `lib/tv_app/widgets/tv_top_nav.dart`

- [ ] **Step 1: 实现 TV 焦点封装**

`TvFocusable` 使用 `Focus`、`FocusableActionDetector` 或同类 Flutter 原生能力，统一提供：

- 获焦回调
- OK/Enter 点击
- 高亮边框或放大效果

- [ ] **Step 2: 实现 TV 视频卡片**

`TvVideoCard` 接收 `VideoInfo`、点击回调、是否加载中，展示封面、标题、年份/来源等基础信息。

- [ ] **Step 3: 实现 TV 首页区块**

`TvHomeSection` 接收标题、视频列表、加载状态、错误状态、点击回调，渲染横向大卡片列表。

- [ ] **Step 4: 实现 TV 顶部导航**

`TvTopNav` 展示 `首页 / 播放历史 / 收藏夹`，使用焦点态区分当前选中项。

## Task 5: TV 首页和 Shell

**Files:**
- Create: `lib/tv_app/tv_app_shell.dart`
- Create: `lib/tv_app/screens/tv_home_screen.dart`
- Create: `test/tv_app/tv_home_screen_test.dart`

- [ ] **Step 1: 写 TV 首页基础渲染测试**

断言能看到：

- `首页`
- `播放历史`
- `收藏夹`
- `继续观看`
- `热门电影`
- `热门剧集`
- `新番放送`
- `热门综艺`

Run: `flutter test test/tv_app/tv_home_screen_test.dart`

Expected: FAIL，页面尚未实现。

- [ ] **Step 2: 实现 `TvAppShell`**

提供 TV 专用背景、SafeArea 和 `TvHomeScreen` 入口。

- [ ] **Step 3: 实现 `TvHomeScreen`**

数据来源：

- 继续观看、播放历史、收藏夹：`PageCacheService`
- 热门电影、热门剧集、热门综艺：`DoubanService`
- 新番放送：`BangumiService`

交互要求：

- 第一版点击卡片进入现有 `PlayerScreen`。
- 加载失败只影响当前区块。
- 不触发现有登录页。

- [ ] **Step 4: 运行 TV 首页测试**

Run: `flutter test test/tv_app/tv_home_screen_test.dart`

Expected: PASS。

## Task 6: 文档与回归

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: 更新变更记录**

在 2026-05-22 变更记录中追加 Android TV 独立入口说明。

- [ ] **Step 2: 运行重点测试**

Run:

```bash
flutter test test/services/app_device_service_test.dart test/app_bootstrap_test.dart test/tv_app/tv_home_screen_test.dart
```

Expected: PASS。

- [ ] **Step 3: 运行静态检查**

Run: `flutter analyze`

Expected: PASS 或仅存在项目既有无关提示。

