# 播放器锁定方向与弹幕手动匹配搜索词缓存实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复移动端播放器的两个回归问题：手动匹配弹幕时记住成功使用过的搜索词，以及播放器锁定按钮真正冻结当前播放方向。

**Architecture:** 先通过单元测试锁定两类目标行为，再对弹幕持久化结构做兼容升级，并把播放器锁定态从控件层透传到页面层方向策略。方向冻结继续依赖统一的 `selene/orientation` 通道，其中 iOS 补充当前界面方向读取能力。

**Tech Stack:** Flutter, Dart, SharedPreferences, MethodChannel, Swift, flutter_test

---

## 文件地图

- 新增：`docs/superpowers/specs/2026-03-28-player-lock-and-danmaku-manual-query-design.md`
- 修改：`lib/services/danmaku_service.dart`
- 修改：`lib/widgets/danmaku_match_panel.dart`
- 修改：`lib/widgets/mobile_player_controls.dart`
- 修改：`lib/widgets/video_player_widget.dart`
- 修改：`lib/screens/player_screen.dart`
- 修改：`lib/screens/live_player_screen.dart`
- 修改：`lib/services/mobile_orientation_service.dart`
- 修改：`ios/Runner/AppDelegate.swift`
- 新增：`test/services/danmaku_service_test.dart`
- 新增：`test/utils/player_rotation_lock_policy_test.dart`
- 修改：`test/services/mobile_orientation_service_test.dart`

### 任务 1：先锁定弹幕手动匹配搜索词缓存行为

**Files:**
- Modify: `lib/services/danmaku_service.dart`
- Modify: `lib/widgets/danmaku_match_panel.dart`
- Modify: `lib/screens/player_screen.dart`
- Test: `test/services/danmaku_service_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 最小实现结构化手动匹配缓存**
- [ ] **Step 4: 将弹框初始搜索词切到历史缓存优先**
- [ ] **Step 5: 运行测试确认通过**

### 任务 2：锁定播放器右侧锁按钮对应的方向冻结行为

**Files:**
- Create: `test/utils/player_rotation_lock_policy_test.dart`
- Modify: `lib/widgets/mobile_player_controls.dart`
- Modify: `lib/widgets/video_player_widget.dart`
- Modify: `lib/screens/player_screen.dart`
- Modify: `lib/screens/live_player_screen.dart`
- Modify: `lib/services/mobile_orientation_service.dart`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 增加播放器锁定态透传回调**
- [ ] **Step 4: 在页面层应用方向冻结策略**
- [ ] **Step 5: 为 iOS 补充当前界面方向读取**
- [ ] **Step 6: 运行测试确认通过**

### 任务 3：回归验证与整理

**Files:**
- Modify: `docs/superpowers/plans/2026-03-28-player-lock-and-danmaku-manual-query.md`

- [ ] **Step 1: 运行相关测试集**
- [ ] **Step 2: 运行格式化**
- [ ] **Step 3: 在可行范围内运行 analyze**
- [ ] **Step 4: 记录验证结果和剩余风险**
