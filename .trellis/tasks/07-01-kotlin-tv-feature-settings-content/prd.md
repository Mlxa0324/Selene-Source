# Kotlin TV 设置与历史收藏直播

## Goal

在 `kotlin-tv/feature/feature-settings` 落地设置页全部分区（服务器配置、图片与弹幕/弹幕手动匹配、缓存管理、手机扫码配置桥接），在 `kotlin-tv/feature/feature-content` 落地历史、收藏纵向 Grid 列表页和直播占位页，行为对齐 Flutter `tv_settings_screen.dart` / `tv_danmaku_match_screen.dart` / `tv_history_screen.dart` / `tv_favorites_screen.dart` / `tv_live_screen.dart`。

## Dependency

依赖 `07-01-kotlin-tv-scaffold-core` 先完成并冻结 `core-common`（网络/数据仓库）、`core-design`（TV 主题/复用组件）对外契约。本任务的实现不得早于 scaffold-core 验收通过。

## Confirmed Facts

- 设置页共 4 个分区，来自 Flutter `tv_settings_screen.dart` 实测代码结构：
  1. **服务器配置**（`_buildAccountSection`）：服务器地址/账号/密码三个字段，浏览态默认只读、确认键进入编辑态，保存按钮触发登录/校验。
  2. **图片与弹幕**（`_buildDanmakuSection`）：豆瓣图片代理选择（4 个选项：豆瓣官方精品 CDN / 直连 / 豆瓣 CDN By CMLiussss(腾讯云) / 豆瓣 CDN By CMLiussss(阿里云)）、自动去广告开关、弹幕服务器地址、弹幕手动匹配入口（跳转 `TvDanmakuMatchScreen`）。
  3. **缓存管理**（`_buildCacheSection`）：展示当前缓存占用（`AppCacheService.formatBytes`），说明"空间低于 500MB 自动清理图片缓存"，提供"清除所有缓存"按钮。
  4. **手机扫码配置**（`_buildMobileConfigSection`）：TV 启动一个局域网 HTTP 服务（Flutter 用 `dart:io HttpServer.bind`，起始端口 `18321`，端口被占用则递增重试），生成二维码分享链接，手机同局域网扫码后打开网页表单（服务器地址/账号/密码/图片代理/去广告/弹幕地址），提交后自动回填到 TV 表单草稿，用户在 TV 上确认保存。
- 外观主题色（`TvThemeService`）当前是 3 个可选主题：Ivy 绿(`ivy_green`，默认)/奈飞红(`netflix_red`)/柔和蓝(`soft_blue`)，各含 accent/focus/focusFill/disabledFill/selectedText 5 个色值；不是独立分区，是嵌在页面中的选项组。
- `tv-mode.md` 契约要求设置页展示"服务器配置、弹幕匹配、播放媒体、外观焦点"四组入口，弹幕手动匹配需显式回调暴露给宿主——对照 Flutter 实测代码，"播放媒体"对应缓存管理分区，"外观焦点"对应主题色选项，契约文案和实测代码分区叫法不完全一致，以 Flutter 实测代码结构为准。
- 弹幕手动匹配面板（`TvDanmakuMatchScreen`）：遥控器不适合输入中文，交互设计为"默认带入当前片名 -> 删一字/清空/恢复片名四个操作按钮微调 -> 确认键搜索"，结果列表展示动画标题、类型/年份、分集按钮（点击即选中并回调 `onEpisodeSelected`）。
- 历史页（`TvHistoryScreen`）和收藏页（`TvFavoritesScreen`）都是对 `TvVideoLibraryScreen` 的薄包装：传入标题、加载函数（`TvVideoLibraryService.loadHistory`/`loadFavorites`）、删除单项回调、清空回调，`popResultOnBack=true`（返回时告知上级页面列表发生过变化，用于首页/详情页局部刷新）。
- 直播页（`TvLiveScreen`）当前是"正在开发"占位页，Kotlin 端同样只做占位，不实现真实直播功能。
- `re-android/core-design` 已有的 `TvQrCodeSection.kt` 是纯 UI 占位（渲染 `[QR]` 文字），没有真实二维码生成能力，可作为组件签名参考但不复用其占位逻辑。
- Flutter 使用 `qr_flutter` 生成真实二维码图片；Kotlin 端使用 **ZXing**（`com.google.zxing:core`）生成二维码 Bitmap，这是 Android 生态标准选择。
- Kotlin 端起局域网 HTTP 服务使用 **NanoHTTPD**（`org.nanohttpd:nanohttpd:2.3.1`），替代 Flutter `dart:io HttpServer` 的能力，用户已确认选型。

## Requirements

### 设置页（feature-settings）

- 四个分区（服务器配置、图片与弹幕、缓存管理、手机扫码配置）均需实现，UI 结构和交互对齐 Flutter 实测代码。
- 服务器配置字段浏览态/编辑态切换、保存后触发后续登录校验（复用 `core-common` 已有的会话/仓库能力）。
- 图片代理 4 选项 + 去广告开关 + 弹幕地址字段 + 弹幕手动匹配入口按钮。
- 弹幕手动匹配使用独立路由/弹层承载，遵循"默认带入当前片名 -> 删字/清空/恢复微调 -> 确认搜索"交互，结果分集按钮点击即选中。
- 缓存管理展示占用大小、清除按钮，清除逻辑接入 Kotlin 端等效缓存服务（复用 core-common 或按需新增）。
- 手机扫码配置：
  - 使用 NanoHTTPD 在局域网起服务，端口从 `18321` 开始递增探测可用端口。
  - 使用 ZXing 生成二维码 Bitmap 展示分享链接。
  - 手机端提交表单后，TV 端接收并回填草稿到本地表单（不自动保存，需用户在 TV 上确认）。
  - "重新生成"按钮关闭旧会话、分配新端口、重新生成二维码。
  - 状态文案覆盖：就绪待扫码 / 已接收待确认 / 局域网地址不可用三种态。
- 外观主题色选项（Ivy 绿默认/奈飞红/柔和蓝）作为页面内选项组，切换后立即预览并可保存。
- 设置项持久化读写接入 `core-common`（或 scaffold-core 冻结的等效仓库层），不在 feature 层直接读写 SharedPreferences。

### 历史/收藏/直播（feature-content）

- 历史页和收藏页复用同一个纵向 Grid 列表组件（对齐 Flutter `TvVideoLibraryScreen` 的薄包装模式），只在标题、数据源、删除/清空回调上区分。
- 删除单项、清空列表操作要有确认交互（沿用 `tv-mode.md` 已有的确认弹层契约），操作成功后同步刷新当前列表。
- 空态、加载态需要提供真实 focusable 目标，接收顶部导航下探的 `contentFocusRequester`。
- 直播页保持"正在开发"占位文案，不实现真实频道/节目单数据。

## Acceptance Criteria

- [ ] 设置页四个分区全部实现，字段/按钮/交互对齐 Flutter 实测代码结构。
- [ ] 手机扫码配置桥接功能可用：TV 生成二维码，手机同局域网扫码打开表单，提交后 TV 表单草稿自动回填。
- [ ] 弹幕手动匹配面板交互（删字/清空/恢复/搜索/分集选中）与 Flutter 端一致。
- [ ] 缓存管理展示真实占用并可清除。
- [ ] 外观主题色三选项可切换并生效。
- [ ] 历史页、收藏页基于同一套列表组件实现，删除/清空操作闭环且列表实时同步。
- [ ] 直播页为占位页，文案与 Flutter 端一致。
- [ ] 遥控器方向键路径覆盖：顶部导航下探到各页面内容入口、空态/加载态/列表态都有可聚焦目标。
- [ ] 单元测试覆盖：设置 ViewModel 各分区状态变更、手机配置桥接会话生命周期（启动/重生成/关闭）、历史/收藏 ViewModel 的 load/delete/clear 三类动作。
- [ ] `./gradlew -p kotlin-tv :feature:feature-settings:testDebugUnitTest :feature:feature-content:testDebugUnitTest` 通过。

## Out of Scope

- 真实直播频道/EPG 节目单功能。
- 重新设计主题色方案（沿用现有 3 个主题定义）。
- 手机端配置网页本身的样式重做（复用 Flutter 端已验证的表单字段集合即可，Kotlin 端负责服务端生成 HTML 表单）。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Complex task: `design.md` 和 `implement.md` 已同步补充。
