# Android TV 独立入口设计

**日期：** 2026-05-22

## 背景

Selene 当前是一套 Flutter 多端应用，普通 Android 手机、Android 平板、iOS、macOS、Windows 都共用现有启动、登录、首页和播放器逻辑。现在需要在同一套代码里增加 Android TV 版本：业务 API 能共用就共用，但页面和组件尽量独立，方便后续维护。

用户明确要求：

- 打包仍是一套 Android 包，由运行时判断当前 Android 设备是否为电视。
- 只有 Android TV 进入 TV 端逻辑，其他端全部保持现有逻辑。
- TV 端第一版不要求登录，启动后直接进入首页。
- TV 首页内容与手机 App 首页一致，但布局可以 TV 化。
- 可以多写文件，优先保证 TV 端与普通端解耦。

## 目标

- 新增 Android 原生设备形态判断能力，可靠识别 Android TV。
- Flutter 启动时按设备形态分流：
  - Android TV 进入独立 TV App Shell。
  - Android 手机/平板、iOS、macOS、Windows 保持现有 `AppWrapper` 登录和首页流程。
- 新增 `lib/tv_app/` 模块，TV 页面和组件统一放在该目录下。
- TV 第一版首页展示：
  - 继续观看
  - 热门电影
  - 热门剧集
  - 新番放送
  - 热门综艺
  - 播放历史
  - 收藏夹
- TV UI 使用大屏布局与遥控器焦点交互，不直接复用普通端触控页面组件。
- TV 数据层复用现有 service/model，避免重复实现 API。

## 非目标

- 不重做普通端首页、登录页或播放器。
- 不新增独立 TV API。
- 第一版不实现完整 TV 专属播放器控制层。
- 第一版不实现 TV 端复杂登录、扫码登录或账号管理。
- 不改变 iOS、macOS、Windows 的启动流程。

## 方案对比

### 方案 A：在现有普通端页面中添加 TV 分支

做法是在 `HomeScreen`、`MainLayout` 和现有组件中加入 `isTv` 判断。

优点是改动少、上线快。缺点是 TV 遥控器焦点、横向导航、播放器控制层会逐渐污染普通端代码，后续维护成本高。

### 方案 B：新增独立 TV 模块，数据层复用

做法是新增 `lib/tv_app/`，TV 页面和组件全部独立实现，直接复用 `PageCacheService`、`DoubanService`、`UserDataService`、现有模型和播放入口。

优点是边界清晰，普通端风险低，后续 TV 专属体验可以独立演进。缺点是第一版要多写一些组件。

### 方案 C：先抽公共首页数据层，再分别接普通端与 TV UI

做法是先把普通首页的数据加载抽成公共 view model/service，再让普通端和 TV 端共同使用。

优点是长期结构最好。缺点是第一版会改动普通首页，容易扩大风险。

## 推荐方案

采用方案 B。

TV 版本作为独立 App Shell 接入，只共享业务服务和数据模型。这样可以让第一版快速获得 TV 化首页，同时普通端启动、登录、布局、交互都不受影响。

## 详细设计

### 1. 设备形态判断

新增 `AppDeviceService`，统一提供设备形态判断。

Flutter 侧定义设备类型：

- `phone`
- `tablet`
- `tv`
- `desktop`
- `unknown`

Android 侧通过 `MethodChannel('selene/device')` 返回当前是否为 TV。判断依据包括：

- `UiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION`
- `PackageManager.FEATURE_LEANBACK`
- `PackageManager.FEATURE_TELEVISION`

只有 `Platform.isAndroid` 时调用原生 TV 判断；其他平台不走 TV 分支。

### 2. 启动分流

`SeleneApp` 的 `home` 从固定 `AppWrapper` 改为新的启动分流组件。

启动分流组件负责：

- 读取 `AppDeviceService.resolveDeviceType()`
- Android TV 返回 `TvAppShell`
- 其他平台返回现有 `AppWrapper`
- 判断失败时默认走现有普通端逻辑，避免启动阻塞

### 3. TV 模块边界

新增目录：

```text
lib/tv_app/
  tv_app_shell.dart
  screens/
    tv_home_screen.dart
  widgets/
    tv_focusable.dart
    tv_top_nav.dart
    tv_home_section.dart
    tv_video_card.dart
```

TV 模块可以 import 现有 `models/`、`services/`、`screens/player_screen.dart`，但普通端页面不要 import `tv_app/` 内部页面和组件。

### 4. TV 首页数据与布局

TV 首页第一版保留普通首页的信息架构，但重新组织为大屏遥控器友好的布局：

- 顶部为 TV 专属导航：`首页 / 播放历史 / 收藏夹`
- 首页 tab 使用纵向页面和横向内容区：
  - 继续观看
  - 热门电影
  - 热门剧集
  - 新番放送
  - 热门综艺
- 历史和收藏使用大屏网格。
- 卡片尺寸更大，焦点态明显。
- OK/Enter 打开播放页。

### 5. 数据复用

TV 第一版直接复用现有服务：

- 继续观看、历史、收藏：`PageCacheService`
- 热门电影/剧集/综艺：`DoubanService`
- 新番放送：`BangumiService`
- 播放入口：现有 `PlayerScreen`

如果 TV 端后续数据加载逻辑变复杂，再抽独立 `tv_home_repository.dart`，第一版先保持简单。

### 6. 错误与降级

- Android TV 判断失败时，默认进入普通端逻辑。
- TV 首页某个区块加载失败时，只显示该区块的错误或空态，不影响其他区块。
- 未登录时仍允许进入 TV 首页，依赖现有 service 的本地缓存与公开内容能力。

## 测试策略

- 为设备类型解析写单元测试。
- 为启动分流写 widget test，覆盖 Android TV 返回 TV Shell、非 TV 返回普通 AppWrapper。
- 为 TV 首页关键 UI 写 widget test，覆盖标题区块和焦点卡片存在。
- 运行 `flutter test` 与 `flutter analyze` 做回归。

