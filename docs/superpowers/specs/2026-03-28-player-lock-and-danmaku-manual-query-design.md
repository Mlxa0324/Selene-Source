# 播放器锁定方向与弹幕手动匹配搜索词缓存设计

**日期：** 2026-03-28

## 目标

修复两个移动端播放器问题：

1. 手动匹配弹幕后，缓存本次实际使用并成功选中弹幕的搜索词，下次再看同一剧集时优先复用该搜索词。
2. 播放器右侧锁定按钮处于锁定状态时，物理旋转设备不应再触发播放器方向变化；该规则对 Android/iOS、手机/平板统一生效。

## 范围

- `lib/services/danmaku_service.dart`
- `lib/widgets/danmaku_match_panel.dart`
- `lib/widgets/mobile_player_controls.dart`
- `lib/widgets/video_player_widget.dart`
- `lib/screens/player_screen.dart`
- `lib/screens/live_player_screen.dart`
- `lib/services/mobile_orientation_service.dart`
- `ios/Runner/AppDelegate.swift`
- 与上述逻辑对应的测试文件

## 非目标

- 不改桌面端和 Web 端方向行为
- 不改弹幕自动匹配规则
- 不新增用户可见的独立“屏幕旋转锁”设置项
- 不重构播放器整套全屏方向控制架构

## 问题一：弹幕手动匹配搜索词未缓存

### 现状

当前手动匹配仅保存了 `episodeId`，键为 `source + id + episodeIndex`。再次打开手动匹配弹框时，输入框仍使用 `videoTitle` 作为初始搜索词，用户上一次改过并成功使用的关键词不会被带回。

### 根因

- 持久化信息不完整：只有“选中了哪条弹幕”，没有“是用什么关键词搜到的”。
- 弹框初始值固定来自播放器标题，而不是来自历史手动匹配上下文。

### 设计

保留现有手动匹配键结构不变，但把值从单个 `episodeId` 扩展为结构化对象：

- `episodeId`
- `searchKeyword`

兼容策略：

- 读取时同时兼容旧格式（纯数字 `episodeId`）和新格式（对象）。
- 写入时统一写新格式。

交互策略：

- 用户在手动匹配面板中点选某个弹幕剧集时，保存当前最终搜索词。
- 下次再次打开同一剧集的手动匹配面板时，优先读取该搜索词作为 `initialQuery`。
- 若没有缓存搜索词，则回退到当前 `videoTitle`。

## 问题二：播放器锁定按钮未参与方向控制

### 现状

播放器右侧锁定按钮的状态只存在于 `mobile_player_controls.dart` 的本地变量 `_isLocked` 中，目前仅影响：

- 手势是否可用
- 控件是否显示
- 返回键/退出手势行为

它没有传递到 `player_screen.dart` / `live_player_screen.dart` 的方向控制链路，因此设备物理旋转后，系统仍可根据当前允许方向切换 `portraitUp/portraitDown/landscapeLeft/landscapeRight`。

### 根因

- “锁定控件交互”和“锁定屏幕方向”是两套割裂状态。
- Flutter 仅通过宽高比无法区分 180 度旋转前后的精确方向，无法满足“锁上后不允许左右/上下翻转”的需求。
- `MobileOrientationService` 当前仅在 Android 上读取当前界面方向，iOS 无法提供当前 `interfaceOrientation`。

### 设计

#### 锁定语义

当播放器右侧锁定按钮为锁定态时：

- 若当前为 `landscapeLeft`，则只允许 `landscapeLeft`
- 若当前为 `landscapeRight`，则只允许 `landscapeRight`
- 若当前为 `portraitUp`，则只允许 `portraitUp`
- 若当前为 `portraitDown`，则只允许 `portraitDown`

换句话说，锁定按钮表示“冻结当前播放器方向”，而不是“仅禁用触控”。

#### 状态传递

新增一条从控件层到页面层的回调链路：

- `MobilePlayerControls`
- `VideoPlayerWidget`
- `PlayerScreen` / `LivePlayerScreen`

页面层保存统一的 `playerRotationLocked` 状态，并在状态变化后重新应用方向约束。

#### 当前方向信号

继续复用 `MethodChannel('selene/orientation')`：

- Android 保持已有实现
- iOS 新增 `getCurrentInterfaceOrientation`

返回值统一为：

- `portraitUp`
- `portraitDown`
- `landscapeLeft`
- `landscapeRight`
- `unknown`

#### 锁定优先级

播放器锁定态优先于普通的全屏方向策略：

- 已锁定：直接锁定到当前精确方向
- 未锁定：恢复现有播放页/全屏方向策略

这样既能解决“锁上后 180 度旋转仍然翻转”的问题，也不会破坏未锁定时的现有体验。

## 风险

- iOS 若拿不到当前 `interfaceOrientation`，锁定时可能无法精确冻结方向，因此需要提供安全回退。
- 手动匹配数据结构升级后，必须兼容用户已有的旧缓存。
- 锁定状态从控件层上抬到页面层后，若回调链路不完整，可能出现 UI 已锁但页面方向未锁的半同步状态。

## 验证

- 为弹幕服务添加测试，覆盖：
  - 新格式保存后可同时读出 `episodeId` 和 `searchKeyword`
  - 旧格式缓存仍可读出 `episodeId`
  - 旧格式缓存没有 `searchKeyword` 时返回空
- 为方向锁定策略添加测试，覆盖：
  - 锁定时冻结 `landscapeLeft`
  - 锁定时冻结 `landscapeRight`
  - 锁定时冻结 `portraitUp`
  - 当前方向未知时回退到上次已知方向
- 为 `MobileOrientationService` 添加 iOS 方向读取测试
- 运行受影响测试、`dart format`，并在条件允许时运行 `flutter analyze`
