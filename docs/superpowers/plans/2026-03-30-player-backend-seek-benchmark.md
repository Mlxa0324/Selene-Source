# 播放器后端 Seek Benchmark 隐藏实验页实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增一个隐藏的 benchmark 实验页，在同一台真机上对比 `WebView / video_player / media_kit / fvp` 四套播放后端的 HLS 左向 seek 表现。

**Architecture:** 先把 benchmark 的计时与结果模型独立出来，用纯 Dart 测试锁定 `t0/t1/t2/t3` 采样和稳定判定；再用独立的 driver 层分别封装四个后端，避免把正式播放器业务逻辑带进实验页。`fvp` 不全局接管正式播放器，而是在 benchmark 范围内通过单独的平台实例切换层临时启用，保证它可以和官方 `video_player` 在同一 App 会话中逐项对比。

**Tech Stack:** Flutter, Dart, flutter_test, video_player, video_player_platform_interface, media_kit, flutter_inappwebview, fvp

---

## 文件地图

- 参考：`docs/superpowers/specs/2026-03-30-player-backend-seek-benchmark-design.md`
- 修改：`pubspec.yaml`
- 修改：`lib/widgets/user_menu.dart`
- 新增：`lib/screens/player_benchmark_screen.dart`
- 新增：`lib/models/player_benchmark_models.dart`
- 新增：`lib/services/player_benchmark_session.dart`
- 新增：`lib/services/player_benchmark_video_platform_registry.dart`
- 新增：`lib/widgets/benchmark/benchmark_player_driver.dart`
- 新增：`lib/widgets/benchmark/benchmark_player_host.dart`
- 新增：`lib/widgets/benchmark/drivers/webview_benchmark_driver.dart`
- 新增：`lib/widgets/benchmark/drivers/video_player_benchmark_driver.dart`
- 新增：`lib/widgets/benchmark/drivers/media_kit_benchmark_driver.dart`
- 新增：`lib/widgets/benchmark/drivers/fvp_benchmark_driver.dart`
- 新增：`test/services/player_benchmark_session_test.dart`
- 新增：`test/services/player_benchmark_video_platform_registry_test.dart`
- 新增：`test/screens/player_benchmark_screen_test.dart`
- 新增：`test/widgets/user_menu_benchmark_entry_test.dart`

## 任务 1：先锁定 benchmark 计时与结果模型

**Files:**
- Create: `lib/models/player_benchmark_models.dart`
- Create: `lib/services/player_benchmark_session.dart`
- Test: `test/services/player_benchmark_session_test.dart`

- [ ] **Step 1: 写失败测试，锁定四个关键指标的采样规则**

在 `test/services/player_benchmark_session_test.dart` 覆盖：
- `api_return_ms` 取 `t1 - t0`
- “位置稳定”需要进入目标 `±500ms` 且持续 `200ms`
- buffering 结束必须满足“`buffering=false` 且位置重新推进”
- 超时 `15s` 会产出失败结果

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/player_benchmark_session_test.dart`
Expected: FAIL，提示 `PlayerBenchmarkSession` 或相关模型/方法不存在

- [ ] **Step 3: 最小实现 benchmark 结果模型**

在 `lib/models/player_benchmark_models.dart` 定义：
- 后端枚举
- 测试模式枚举
- 场景枚举（`10s / 30s / 90s / 180s`）
- 单次结果模型
- 聚合结果模型

要求：
- 字段直接覆盖 spec 中的 `api_return_ms / position_settle_ms / buffering_clear_ms / delta_ms / status / error`
- 锚点 `240s` 与 4 个左跳目标位置写成集中常量，避免页面硬编码

- [ ] **Step 4: 最小实现 benchmark 会话采样器**

在 `lib/services/player_benchmark_session.dart` 实现一个纯 Dart 会话对象，负责：
- 接收 `onSeekStart / onSeekReturned / onPosition / onBuffering` 事件
- 计算 `t0/t1/t2/t3`
- 生成单次结果
- 输出超时失败

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/services/player_benchmark_session_test.dart`
Expected: PASS，覆盖计时、稳定判定和超时逻辑

- [ ] **Step 6: 提交这一层**

```bash
git add lib/models/player_benchmark_models.dart lib/services/player_benchmark_session.dart test/services/player_benchmark_session_test.dart
git commit -m "test: add player benchmark timing session"
```

## 任务 2：实现四个 benchmark 后端驱动与 fvp 平台切换层

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/services/player_benchmark_video_platform_registry.dart`
- Create: `lib/widgets/benchmark/benchmark_player_driver.dart`
- Create: `lib/widgets/benchmark/benchmark_player_host.dart`
- Create: `lib/widgets/benchmark/drivers/webview_benchmark_driver.dart`
- Create: `lib/widgets/benchmark/drivers/video_player_benchmark_driver.dart`
- Create: `lib/widgets/benchmark/drivers/media_kit_benchmark_driver.dart`
- Create: `lib/widgets/benchmark/drivers/fvp_benchmark_driver.dart`
- Test: `test/services/player_benchmark_video_platform_registry_test.dart`

- [ ] **Step 1: 写失败测试，锁定官方 video_player 与 fvp 的平台实例切换规则**

在 `test/services/player_benchmark_video_platform_registry_test.dart` 覆盖：
- 首次保存官方 `VideoPlayerPlatform.instance`
- 临时注册 `fvp` 后可以切换到 fvp 实现
- 退出 fvp 测试后能恢复官方实现
- 重复切换不会丢失原始实例

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/services/player_benchmark_video_platform_registry_test.dart`
Expected: FAIL，提示 registry 未实现

- [ ] **Step 3: 增加依赖并显式引入视频平台接口**

在 `pubspec.yaml` 中：
- 添加 `fvp`
- 添加 `video_player_platform_interface`

说明：
- `fvp` 需要作为直接依赖
- `video_player_platform_interface` 作为显式接口依赖，避免在 app 代码里隐式依赖传递包

- [ ] **Step 4: 安装依赖并确认锁文件更新**

Run: `flutter pub get`
Expected: `pubspec.lock` 更新，`fvp` 与 `video_player_platform_interface` 可解析

- [ ] **Step 5: 实现视频平台切换层**

在 `lib/services/player_benchmark_video_platform_registry.dart` 实现：
- 保存首次官方 `VideoPlayerPlatform.instance`
- 提供 `useOfficialVideoPlayer()` 恢复官方实现
- 提供 `useFvpVideoPlayer()` 临时切到 fvp

实现要求：
- 不在 `main()` 全局 `registerWith()`
- `fvp` 仅在 benchmark driver 创建前切换
- driver dispose 后必须允许恢复官方实现

- [ ] **Step 6: 定义 benchmark driver 抽象**

在 `lib/widgets/benchmark/benchmark_player_driver.dart` 定义统一接口：
- `Future<void> load(String url)`
- `Future<void> play()`
- `Future<void> pause()`
- `Future<void> seek(Duration position)`
- `Future<void> dispose()`
- `Stream<Duration> position`
- `Stream<bool> buffering`
- `Duration get currentPosition`
- `bool get isReady`
- `Widget buildView()`

- [ ] **Step 7: 实现 WebView driver**

在 `lib/widgets/benchmark/drivers/webview_benchmark_driver.dart`：
- 尽量复用现有 `WebViewPlayerAdapter` 的事件能力
- 保留 `fastSeekTo` 与当前 HLS.js 路径
- 暴露统一 `position / buffering / ready` 信号

- [ ] **Step 8: 实现官方 video_player driver**

在 `lib/widgets/benchmark/drivers/video_player_benchmark_driver.dart`：
- 创建 `VideoPlayerController.networkUrl`
- 在创建前显式恢复官方 `VideoPlayerPlatform.instance`
- 监听 `value.position / value.isBuffering / value.isInitialized`

- [ ] **Step 9: 实现 media_kit driver**

在 `lib/widgets/benchmark/drivers/media_kit_benchmark_driver.dart`：
- 使用 `mk.Player + mkv.VideoController`
- 统一转成 benchmark 所需的 `position / buffering / ready` 信号

- [ ] **Step 10: 实现 fvp driver**

在 `lib/widgets/benchmark/drivers/fvp_benchmark_driver.dart`：
- driver 初始化前通过 registry 切到 fvp
- 使用 `VideoPlayerController.networkUrl`
- 如需要更贴近 seek 性能，对同一 controller 在 benchmark 范围内调用 `FVPControllerExtensions.fastSeekTo()`
- dispose 后允许切回官方实现

- [ ] **Step 11: 增加统一播放器宿主组件**

在 `lib/widgets/benchmark/benchmark_player_host.dart`：
- 根据选中后端持有单个 driver
- 负责 driver 生命周期切换
- 避免页面层直接管理四套播放器初始化与销毁细节

- [ ] **Step 12: 运行测试确认通过**

Run: `flutter test test/services/player_benchmark_video_platform_registry_test.dart`
Expected: PASS，平台实例切换与恢复行为稳定

- [ ] **Step 13: 提交这一层**

```bash
git add pubspec.yaml lib/services/player_benchmark_video_platform_registry.dart lib/widgets/benchmark/benchmark_player_driver.dart lib/widgets/benchmark/benchmark_player_host.dart lib/widgets/benchmark/drivers/webview_benchmark_driver.dart lib/widgets/benchmark/drivers/video_player_benchmark_driver.dart lib/widgets/benchmark/drivers/media_kit_benchmark_driver.dart lib/widgets/benchmark/drivers/fvp_benchmark_driver.dart test/services/player_benchmark_video_platform_registry_test.dart
git commit -m "feat: add benchmark player drivers"
```

## 任务 3：实现隐藏 benchmark 页面与版本号入口

**Files:**
- Modify: `lib/widgets/user_menu.dart`
- Create: `lib/screens/player_benchmark_screen.dart`
- Test: `test/screens/player_benchmark_screen_test.dart`
- Test: `test/widgets/user_menu_benchmark_entry_test.dart`

- [ ] **Step 1: 写失败测试，锁定实验页的基础交互**

在 `test/screens/player_benchmark_screen_test.dart` 覆盖：
- 顶部后端切换栏存在 4 个选项
- `Run Warm / Run Cold / Clear Results` 三个按钮存在
- 清空结果会清掉现有列表
- 后端切换会请求宿主组件重建对应 driver

在 `test/widgets/user_menu_benchmark_entry_test.dart` 覆盖：
- 长按版本号区域会 push 到 `PlayerBenchmarkScreen`
- 普通点击版本号仍保持现有 GitHub 打开逻辑入口，不改交互语义

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/screens/player_benchmark_screen_test.dart`
Expected: FAIL，提示 `PlayerBenchmarkScreen`、隐藏入口或页面元素不存在

- [ ] **Step 3: 实现实验页 UI 骨架**

在 `lib/screens/player_benchmark_screen.dart` 实现：
- 顶部分段切换
- URL 输入框与“恢复默认测试源”
- 播放器预览区域
- `Run Warm / Run Cold / Clear Results`
- 结果列表

实现要求：
- 页面只消费 benchmark driver 与 benchmark session
- 不引入弹幕、选集、PiP、定时器等正式播放器功能
- 为测试保留 driver factory 注入点，避免 widget test 依赖真实播放器内核

- [ ] **Step 4: 把 Warm/Cold 流程接到页面状态机**

页面流程需要明确：
- `Warm`：同一实例下每轮先回锚点 `240s` 再做左跳
- `Cold`：每个场景重建播放器，加载后先回锚点 `240s`
- 每个场景执行 5 次
- 结果列表按后端/模式/场景/次数追加

- [ ] **Step 5: 在 UserMenu 的版本号区域添加长按入口**

修改 `lib/widgets/user_menu.dart`：
- 保持现有点击版本号打开 GitHub 行为不变
- 新增长按版本号 push 到 `PlayerBenchmarkScreen`
- 只新增隐藏手势，不增加可见菜单项

- [ ] **Step 6: 运行测试确认通过**

Run: `flutter test test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart`
Expected: PASS，页面基础交互和隐藏入口行为稳定

- [ ] **Step 7: 提交这一层**

```bash
git add lib/widgets/user_menu.dart lib/screens/player_benchmark_screen.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart
git commit -m "feat: add hidden player benchmark screen"
```

## 任务 4：完整验证与真机检查

**Files:**
- Modify: `docs/superpowers/plans/2026-03-30-player-backend-seek-benchmark.md`

- [ ] **Step 1: 运行 benchmark 相关测试**

Run: `flutter test test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart`
Expected: PASS

- [ ] **Step 2: 运行格式化**

Run: `dart format lib/screens/player_benchmark_screen.dart lib/models/player_benchmark_models.dart lib/services/player_benchmark_session.dart lib/services/player_benchmark_video_platform_registry.dart lib/widgets/benchmark test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart lib/widgets/user_menu.dart`
Expected: 所有相关文件格式化完成

- [ ] **Step 3: 运行静态分析**

Run: `dart analyze lib/screens/player_benchmark_screen.dart lib/models/player_benchmark_models.dart lib/services/player_benchmark_session.dart lib/services/player_benchmark_video_platform_registry.dart lib/widgets/benchmark lib/widgets/user_menu.dart test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart`
Expected: 没有新增 error；如有历史 warning，单独记录

- [ ] **Step 4: 真机手动检查 Android/iOS**

手动验证：
- 从 `用户菜单 -> 应用设置 -> 长按版本号` 能进入实验页
- 四个后端都能加载默认 HLS 测试源
- `Run Warm / Run Cold` 能产出结果
- 切换后端不会把上一个 driver 残留到当前页面
- `fvp` 与官方 `video_player` 可在同一 App 会话中切换对比

- [ ] **Step 5: 记录验证结果与剩余风险**

至少记录：
- 默认测试流是否足够长
- `fvp` 在 Android/iOS 的初始化是否需要额外平台处理
- 四个后端里是否存在个别 buffering 信号无法完全归一的问题

## 执行记录（2026-03-30）

- `flutter test test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart`
  - 结果：PASS
- `dart format lib/screens/player_benchmark_screen.dart lib/models/player_benchmark_models.dart lib/services/player_benchmark_session.dart lib/services/player_benchmark_video_platform_registry.dart lib/widgets/benchmark test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart lib/widgets/user_menu.dart`
  - 结果：已完成
- `dart analyze lib/screens/player_benchmark_screen.dart lib/models/player_benchmark_models.dart lib/services/player_benchmark_session.dart lib/services/player_benchmark_video_platform_registry.dart lib/widgets/benchmark lib/widgets/user_menu.dart test/services/player_benchmark_session_test.dart test/services/player_benchmark_video_platform_registry_test.dart test/screens/player_benchmark_screen_test.dart test/widgets/user_menu_benchmark_entry_test.dart`
  - 结果：无新增 error；存在 `lib/widgets/user_menu.dart` 两条既有 `withOpacity` deprecation info

## 剩余风险

- 默认测试流当前使用 `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`，理论上满足 `240s` 锚点要求，但仍需真机确认不同平台是否都能稳定拖到该位置。
- `fvp` 当前通过 benchmark 内部的平台注册切换启用，尚未做 Android/iOS 真机初始化验证；如平台侧缺少额外配置，可能只会在真机阶段暴露。
- 四个后端的 buffering 信号来源并不完全一致，当前已统一成同一套会话采样规则，但最终对比时仍需结合真机转圈体感一起看。
