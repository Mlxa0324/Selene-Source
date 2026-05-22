# TV 模式前端实现规格

## 1. Scope / Trigger

当需求涉及 Android TV、BlueStacks TV 调试、TV 首页、TV 设置页、TV 详情页、TV 卡片、遥控器焦点行为时，必须遵守本文档。

本规格覆盖：

- Android TV 启动分流。
- TV 专属页面和组件边界。
- TV 首页内容和焦点交互。
- TV 详情页数据流和播放器入口。
- TV 设置页复用普通端配置。
- TV 端测试与验证要求。

## 2. 文件边界

### 2.1 TV 专属代码

TV 端新增页面、组件和服务优先放在：

```text
lib/tv_app/
├── screens/
├── services/
└── widgets/
```

当前核心文件：

| 文件 | 职责 |
|------|------|
| `lib/tv_app/tv_app_shell.dart` | TV 端 App Shell |
| `lib/tv_app/screens/tv_home_screen.dart` | TV 首页、播放历史、收藏夹、设置入口 |
| `lib/tv_app/screens/tv_settings_screen.dart` | TV 设置页 |
| `lib/tv_app/screens/tv_search_screen.dart` | TV 搜索页 |
| `lib/tv_app/screens/tv_video_detail_screen.dart` | TV 影视详情页 |
| `lib/tv_app/screens/tv_fullscreen_player_screen.dart` | TV 专属全屏播放器壳与遥控器菜单 |
| `lib/tv_app/widgets/tv_top_nav.dart` | TV 顶部导航 |
| `lib/tv_app/widgets/tv_focusable.dart` | TV 遥控器焦点封装 |
| `lib/tv_app/widgets/tv_home_section.dart` | TV 首页横向内容区 |
| `lib/tv_app/widgets/tv_video_card.dart` | TV 影视卡片 |
| `lib/tv_app/widgets/tv_video_grid.dart` | TV 纵向影视网格 |
| `lib/tv_app/services/tv_account_config_service.dart` | TV 账号配置适配 |

### 2.2 跨端启动与配置

| 文件 | 职责 |
|------|------|
| `lib/app_bootstrap.dart` | 根据设备类型选择普通 App 或 TV App |
| `lib/services/app_device_service.dart` | 解析当前设备类型 |
| `lib/models/app_device_type.dart` | 设备类型枚举 |
| `lib/config/device_mode_config.dart` | 调试强制 TV 模式配置 |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Android 原生 TV 能力判断 |

## 3. Signatures

### 3.1 强制 TV 模式配置

```dart
class DeviceModeConfig {
  static const bool forceTvMode = bool.fromEnvironment(
    'SELENE_FORCE_TV_MODE',
    defaultValue: kDebugMode,
  );
}
```

约定：

- Debug 默认强制 TV，方便 BlueStacks 和平板调试。
- Release 默认不强制 TV。
- 命令行可通过 `--dart-define=SELENE_FORCE_TV_MODE=true` 覆盖。

### 3.2 TV 首页数据加载

```dart
typedef TvHomeDataLoader = Future<TvHomeData> Function(BuildContext context);

class TvHomeData {
  final List<VideoInfo> continueWatching;
  final List<VideoInfo> hotMovies;
  final List<VideoInfo> hotTvShows;
  final List<VideoInfo> bangumiCalendar;
  final List<VideoInfo> hotShows;
  final List<VideoInfo> history;
  final List<VideoInfo> favorites;
}
```

实现要求：

- `TvHomeScreen.defaultLoadHomeData` 负责聚合首页数据。
- `TvHomeScreen` 可注入 `loadHomeData` 以支持测试。
- 首页卡片点击进入 TV 详情页，不进入普通播放器页。

### 3.3 TV 详情页数据加载

```dart
typedef TvVideoDetailLoader = Future<TvVideoDetailData> Function(
  BuildContext context,
  VideoInfo videoInfo,
);

class TvVideoDetailData {
  final SearchResult? currentDetail;
  final List<SearchResult> sources;
  final List<VideoInfo> recommends;
}
```

实现要求：

- `currentDetail` 是当前播放源。
- `sources` 是可切换播放源。
- `recommends` 是相关推荐卡片数据。
- 详情页可注入 `loadDetail` 和 `playerBuilder` 以支持测试。

### 3.4 TV 焦点封装

```dart
class TvFocusable extends StatefulWidget {
  final TvFocusableBuilder builder;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onFocusChanged;
  final bool autofocus;
}
```

实现要求：

- `onPressed` 处理确认键和鼠标点击。
- `onFocusChanged` 处理焦点进入和离开。
- 顶部导航通过 `onFocusChanged(true)` 直接切换标签页。
- 顶部导航需要为每个菜单项持有独立 `FocusNode`，用于外部焦点进入时重定向到当前选中项。
- 顶部导航左侧主菜单承载「首页、电影、剧集、动漫、综艺、直播」；其中「直播」是右上角快捷区的焦点过渡按钮，不呼出分类筛选。右侧「搜索、播放历史、收藏夹、设置」属于快捷按钮区，使用图标加文字按钮展示。快捷按钮与 `IvyTV` Logo 同处顶部第一行并靠右展示，主分类菜单在下一行，二者上下错开，右侧同时展示当前时间。

## 4. Contracts

### 4.1 启动分流契约

| 场景 | 预期 |
|------|------|
| Android TV 真机 | 进入 TV App Shell |
| Android 手机 | 进入普通 App |
| Android 平板 | 默认进入普通 App |
| BlueStacks Debug | 因 `forceTvMode=true` 进入 TV App |
| iOS、macOS、Windows | 进入普通 App |
| 原生 TV 判断失败 | 回退普通 App，不崩溃 |

### 4.2 首页内容契约

| 分区 | 数据来源 | 布局 |
|------|----------|------|
| 继续观看 | `PageCacheService.getPlayRecords` | 横向列表 |
| 热门电影 | `PageCacheService.getHotMovies` | 横向列表 |
| 热门剧集 | `PageCacheService.getHotTvShows` | 横向列表 |
| 新番放送 | `BangumiService.getTodayCalendar` | 横向列表 |
| 热门综艺 | `PageCacheService.getHotShows` | 横向列表 |
| 电影标签 | `TvHomeData.hotMovies` | 纵向 Grid |
| 剧集标签 | `TvHomeData.hotTvShows` | 纵向 Grid |
| 动漫标签 | `TvHomeData.bangumiCalendar` | 纵向 Grid |
| 综艺标签 | `TvHomeData.hotShows` | 纵向 Grid |
| 播放历史 | `PageCacheService.getPlayRecords` | 纵向 Grid |
| 收藏夹 | `PageCacheService.getFavorites` | 纵向 Grid |

首页横向列表每个分区最多展示 15 个影视卡片。分区数据超过 15 个时，第 16 个位置展示“查看更多”卡片，宽度等于 `TvVideoCard.width`，高度等于 `TvVideoCard.coverHeight`，点击后切换到对应顶部分类页或播放历史页。

首页横向列表与纵向 Grid 到达边界时，当前卡片播放轻微边界抖动。横向列表在首尾卡片按边界方向键时，必须先滚动到真实 `minScrollExtent/maxScrollExtent`，让首尾 padding 安全留白完整露出；只有已经到达真实边界后才触发抖动。长按方向键时抖动必须有冷却间隔，避免持续重启动画。纵向 Grid 的上方向不做边界拦截，必须允许焦点继续回到顶部导航。

纵向 Grid 页必须使用同一个滚动容器承载二级标题和卡片列表。顶部导航固定在 `TvHomeScreen` 外层，二级标题（例如「电影」「播放历史」「收藏夹」）不能固定在 Grid 外部。Grid 滚动视口必须允许焦点绘制外溢，并在首尾列预留安全边距，避免卡片放大和封面焦点边框被左右裁剪；但 Grid 外层必须被页面内容区域裁剪，避免卡片向上绘制到顶部导航或筛选面板文字上。二级标题、空状态与首列卡片封面左边缘必须保持对齐，不能因为安全边距产生明显错位。

TV 页面左右统一边距当前收敛为 `36px`，供顶部导航、首页横向分区、分类筛选区、纵向 Grid、设置页和详情页共用。纵向 Grid 在 1080p 主场景下固定为 `7` 列，避免不同页面因为可用宽度变化出现列数抖动。

TV 焦点控件进入纵向滚动视口时，必须自动触发平滑滚动，把当前焦点移动到视口偏上的稳定浏览位置。首页横向分区卡片获焦时按区块整体滚动，形成更明显的整行上移效果；播放历史、收藏夹、电影、剧集、动漫、综艺等纵向 Grid，以及详情页、搜索页、设置页中的上下滚动内容，复用 `TvFocusable` 的自动滚动能力。设置页输入框因直接使用 `TextField`，需要单独接入同一套滚动辅助。

纯文字型焦点列表（例如分类筛选项、搜索历史/热词、设置页文字选项）在长按方向键时，必须保留逐项经过的中间选中态，不能直接跳过中间项。实现上允许 `TvFocusable` 对同一文字列表分组启用重复方向键冷却，吞掉过密的 `KeyRepeatEvent`；海报卡片、顶部主导航、播放器菜单等非文字列表保持原有焦点节奏，不强制复用该节流。

电影、剧集、动漫、综艺四个分类页只有在顶部导航对应菜单项已获得焦点时，继续按上方向键才呼出 TV 分类筛选面板。直播菜单项不呼出筛选面板，按上方向键进入右上角搜索快捷入口；搜索快捷入口按下方向键回到直播菜单项，左右方向键不负责主菜单和快捷区的跨区跳转。内容区卡片或 Grid 按上方向键必须先按正常焦点逻辑回到顶部导航，不能直接呼出筛选面板。筛选面板包含排序、类型、地区、年份四行，每行第一个选项必须是「全部」，后续选项使用横向列表展示。每一行横向列表必须裁剪到选项视口内，避免横向滚动时覆盖左侧「排序:」「类型:」等行标题；首尾选项继续按左右方向键必须触发边界抖动并保持当前行焦点，长按左右键不能跳到其它筛选行。确认键选中筛选项后，必须记录当前分类的筛选条件，立即执行对应豆瓣推荐查询，并用查询结果刷新下方 Grid；请求中展示 Grid 骨架，不再继续显示旧列表。面板呼出时顶部导航淡出并收起，筛选面板从顶部缓慢下滑展开，Grid 留在正常布局流中被面板向下顶开，不能遮住卡片。筛选面板必须使用半透黑色背景遮罩，避免滚动卡片和筛选项文字重叠。面板呼出后焦点默认落到第一行「全部」，便于继续用左右方向键选择筛选项。返回键必须先关闭筛选面板并恢复顶部导航。播放历史和收藏夹不接入该筛选面板，继续保持原有纵向 Grid 行为。

分类筛选面板需要支持两种展示态：焦点停留在顶部筛选区时展示完整四行展开态；焦点下移到分类 Grid 浏览内容时，同一块区域自动切换成更紧凑的一行摘要态，仅保留当前排序、类型、地区、年份结果，给下方列表释放更多高度。摘要态下 Grid 首行卡片继续按上方向键时，必须先把筛选区恢复为完整展开态，再按既有焦点逻辑回到顶部。展开态的行高、按钮高度、字号和间距需要比初版更紧凑，保证筛选区整体高度收敛。

展开态筛选项需要明显收窄，单个按钮宽度控制在约 `56~96px`，让同一行首屏内露出更多选项。每一行右侧还要贴边提供一个浅色箭头和渐变遮罩提示，视觉上暗示后方还有更多可横向浏览的选项，箭头尽量贴近列表可视区域的最右侧边缘。

除首页外，顶部固定导航区域必须使用半透黑色背景遮罩，且内容区域外层需要裁剪滚动内容，避免 Grid 向上滚动时海报覆盖顶部菜单文字。首页保持透明顶部导航效果。

### 4.3 TV 卡片契约

| 字段 | 当前值 |
|------|--------|
| `TvVideoCard.width` | `158` |
| `TvVideoCard.height` | `296` |
| `TvVideoCard.coverHeight` | `237` |
| `TvVideoCard.focusedScale` | `1.08` |
| 标题行数 | `1` |
| 焦点边框范围 | 仅封面 |
| 焦点放大范围 | 整张卡片 |
| 封面加载骨架 | 图片首次加载和网络加载中展示 |
| 骨架雨刷方向 | `Alignment.topLeft` 到 `Alignment.bottomRight` |
| 多集进度徽章 | `totalEpisodes > 1` 且 `index > 0` 时在封面右上角展示 `index/totalEpisodes` |
| 播放进度条 | `progressPercentage > 0` 时在封面底部展示播放进度条 |

### 4.4 TV 详情页契约

| 操作 | 预期 |
|------|------|
| 卡片点击 | 打开 `TvVideoDetailScreen` |
| 详情加载 | 先精确源详情，再按标题补源 |
| 换源 | 切换 `currentDetail`，选集重置为 0 |
| 选集 | 更新 `_episodeIndex` 并刷新内嵌播放器 |
| 换源布局 | 单行横向列表，不使用多行换行布局 |
| 选集布局 | 分组标签加单行横向列表，长剧集按固定区间切换 |
| 内嵌播放器 | 关闭播放器控制层，焦点确认只用于进入全屏 |
| 全屏 | push `TvFullscreenPlayerScreen`，携带当前详情、线路列表和集下标 |
| 收藏 | 使用 `PageCacheService.addFavorite/removeFavorite` |
| 推荐点击 | `pushReplacement` 到新的 TV 详情页 |
| 回到顶部 | 当前详情页滚动到顶部 |
| 返回上一级 | 不显示页面级按钮，直接依赖遥控器返回键 |

### 4.9 TV 全屏播放器契约

| 操作 | 预期 |
|------|------|
| 顶部左侧 | 只展示返回图标、标题和当前集信息，不可点击 |
| 顶部右侧 | 只展示装饰图标，不可点击 |
| 下方向键 | 当前无菜单时弹出底部一二级菜单 |
| 一级菜单 | 焦点移入即切换二级菜单，不需要按确认 |
| 二级菜单 | 只有二级菜单按钮执行实际操作 |
| 禁用菜单 | 不展示「清晰度」和「内核」 |
| 播放列表 | 横向展示当前源选集，确认后切换选集 |
| 播放线路 | 横向展示可用线路，确认后切换线路并重置到第 1 集 |
| 画面比例 | 选项文案与手机端播放器设置一致：适应、填充、宽度、高度 |
| 倍速 | 提供常用倍速，确认后调用播放器倍速切换 |
| 其它 | 展示片头、片尾和弹幕开关入口 |
| 菜单未弹出时确认键 | 切换播放和暂停，不弹出底部菜单 |
| 菜单未弹出时左右键 | 执行进度跳转，从 5 秒逐步加速到 29 秒 |
| 左右键进度提示 | 屏幕中心展示浅灰圆角时间提示，格式为 `当前时间 / 总时长` |
| 底部提醒 | 菜单未弹出时展示返回键、下键和安全提醒文案 |
| 返回键 | 菜单已弹出时先关闭菜单；无菜单时退出全屏回到详情页 |

### 4.5 TV 设置输入框契约

| 状态 | 预期 |
|------|------|
| 焦点移入 | 输入框保持 `readOnly=true`，不弹系统键盘 |
| 按确认键 | 输入框进入编辑态，`readOnly=false`，主动显示键盘 |
| 鼠标点击输入框 | 进入编辑态，用于桌面调试 |
| 编辑完成 | 退出编辑态并隐藏键盘 |
| 焦点离开 | 退出编辑态，避免下次移入直接弹键盘 |

### 4.6 TV 图片代理契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `图片代理` |
| 存储复用 | `UserDataService.saveDoubanImageSource` |
| 读取复用 | `UserDataService.getDoubanImageSourceDisplayName` |
| 生效链路 | `getImageUrl` 根据 `getDoubanImageSourceKey` 替换豆瓣图片域名 |
| 可选项 | `直连`、`豆瓣官方精品 CDN`、`豆瓣 CDN By CMLiussss（腾讯云）`、`豆瓣 CDN By CMLiussss（阿里云）` |
| 交互 | 选中后立即保存，并显示 `图片代理已保存` |

### 4.7 TV 缓存管理契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `缓存管理` |
| 缓存大小 | 设置页展示图片、临时目录与豆瓣业务缓存合计占用 |
| 手动清理 | `清除所有缓存` 清理业务运行缓存、图片磁盘缓存、临时目录和 HLS 脚本缓存 |
| 配置保留 | 不清理服务器地址、账号、密码、主题色、弹幕设置和图片代理设置 |
| 启动清理 | 每次进入 App 前清理非配置类运行缓存和内存图片缓存 |
| 图片默认缓存 | TV 影视封面默认使用 `CachedNetworkImage` 写入磁盘缓存，减少重复请求 |
| 低空间策略 | Android 可用空间低于 500MB 时清理图片磁盘缓存，并暂时不再写入新的图片磁盘缓存 |

### 4.8 TV 主题色契约

| 项目 | 预期 |
|------|------|
| 设置项标题 | `主题色` |
| 存储 | `TvThemeService.storageKey` |
| 默认主题 | `Ivy 绿` |
| 新增主题 | `奈飞红`，主色 `#E50914` |
| 生效范围 | TV 顶部导航、卡片焦点、详情页按钮、设置页选中态、开关和滑杆 |
| 普通端影响 | 不影响普通端 `ThemeService` |

## 5. Validation & Error Matrix

| 风险 | 处理方式 | 测试点 |
|------|----------|--------|
| 非 TV 端被误导到 TV App | `DeviceModeConfig` 和原生判断分层 | `app_device_service_test.dart` |
| TV 首页数据加载失败 | 单个分区 catch 后返回空列表 | 首页空数据测试 |
| 首页横向分区无限展示 | `TvHomeSection.maxVisibleVideos=15`，超出后展示封面高度“查看更多”卡片 | `tv_home_section_test.dart` / `tv_home_screen_test.dart` |
| 历史或收藏无数据 | 展示空状态 | `tv_home_screen_test.dart` |
| 详情页无可用源 | 展示「暂无可用源」 | `tv_video_detail_screen_test.dart` 可扩展 |
| 详情页无选集 | 展示「暂无选集」 | `tv_video_detail_screen_test.dart` 可扩展 |
| 详情页无推荐 | 展示「暂无推荐」 | `tv_video_detail_screen_test.dart` 可扩展 |
| 详情页换源或选集换行 | 使用横向 `ListView`，选集长列表先按分组切换 | `tv_video_detail_screen_test.dart` |
| 详情页显示返回按钮 | 不展示“返回上一级”，保留系统/遥控器返回 | `tv_video_detail_screen_test.dart` |
| 详情页播放器出现控制按钮组 | `VideoPlayerWidget.showControls=false`，播放器焦点确认只进全屏 | `tv_video_detail_screen_test.dart` / `video_player_widget_preload_config_test.dart` |
| 分类页上键无筛选面板 | `TvTopNav.onTabArrowUp` 仅在电影、剧集、动漫、综艺菜单获焦时展示筛选面板，内容区上键不直接呼出 | `tv_home_screen_test.dart`, `tv_top_nav_test.dart` |
| 筛选面板遮挡卡片或顶部导航仍占位 | 顶部导航用收起动画让出空间，筛选面板用尺寸动画下滑展开并顶开 Grid | `tv_home_screen_test.dart` |
| 筛选项横向滚动盖住行标题或左右边界跳行 | 筛选行 `ListView` 使用视口裁剪，首尾选项复用 `TvEdgeShake` 拦截左右边界方向键 | `tv_home_screen_test.dart` |
| 筛选项确认后 Grid 不刷新 | `TvHomeScreen.loadCategoryData` 执行筛选查询，`FutureBuilder` 用筛选结果替换当前分类 Grid | `tv_home_screen_test.dart` |
| 卡片焦点边框包住文字 | 边框只放在封面 `AnimatedContainer` | `tv_video_card_test.dart` |
| 纵向 Grid 首尾列焦点被裁剪 | `TvVideoGrid` 使用 `Clip.none` 并预留 `focusSafePadding` | `tv_home_screen_test.dart` |
| 纵向 Grid 标题和首列卡片错位 | 标题和空状态使用同一份 `focusSafePadding` 缩进 | `tv_home_screen_test.dart` |
| TV 主题色没有持久化或未覆盖奈飞红 | `TvThemeService` 负责保存主题色并解析调色板 | `tv_theme_service_test.dart` |
| TV 设置页主题色切换无反馈 | 设置页提供 `主题色` 选项并保存 `netflix_red` | `tv_settings_screen_test.dart` |
| 图片首次加载空白或闪烁 | 封面加载中显示左上到右下雨刷骨架 | `tv_video_card_test.dart` |
| 横向列表保留旧滚动位置 | 分区失焦时 `jumpTo(0)` | `tv_home_section_test.dart` |
| 列表边界长按方向键狂抖 | `TvEdgeShake` 使用冷却间隔控制重复触发 | `tv_edge_shake_test.dart` |
| 横向列表遥控器无法显示首尾留白 | 首尾方向键先滚到真实滚动边界，再触发边界抖动 | `tv_home_section_test.dart` |
| 纵向 Grid 上方向被拦截 | Grid 不设置上边界抖动，焦点可回顶部导航 | `tv_home_screen_test.dart` |
| Grid 海报滚到顶部后盖住菜单或筛选面板 | 内容区和分类 Grid 外层使用 `ClipRect`，顶部导航与筛选面板提供半透黑色遮罩 | `tv_home_screen_test.dart` |
| 纵向滚动页焦点移动没有平滑滚动 | `TvFocusable` 获焦后调用 `TvFocusScroll`，首页分区使用更明显的区块滚动对齐 | `tv_focusable_test.dart`, `tv_home_section_test.dart` |
| TV 卡片缺少继续观看进度 | 多集徽章和封面底部播放进度条复用 `VideoInfo` 进度字段 | `tv_video_card_test.dart` |
| 顶部导航需要按确认才切换 | 菜单项获得焦点时触发 `onChanged` | `tv_top_nav_test.dart` |
| 从内容区回顶部时误切到就近菜单 | 导航栏外部进入时先请求当前选中项焦点 | `tv_top_nav_test.dart` |
| TV 顶部缺少快捷入口 | `TvTopNav` 右侧快捷区提供搜索、播放历史、收藏夹、设置四个图标文字按钮 | `tv_home_screen_test.dart`, `tv_top_nav_test.dart` |
| 全屏播放器菜单未弹出时缺少遥控器播放控制 | 确认键切换播放暂停，左右键按加速步长 seek，并显示中心时间提示 | `tv_fullscreen_player_screen_test.dart` |
| TV 搜索页缺少历史和热词 | 搜索历史使用纯文字 Grid，搜索热词使用本地 mock Grid | `tv_search_screen_test.dart` |
| TV 搜索页推荐列表无边界反馈或放大不明显 | 推荐列表卡片复用 `TvVideoCard.focusedScale`，首尾方向键复用 `TvEdgeShake` 边界抖动 | `tv_search_screen_test.dart` |
| 设置输入框移入就弹键盘 | 输入框默认浏览态，确认后进入编辑态 | `tv_settings_screen_test.dart` |
| TV 封面图无法切换代理 | 设置页复用普通端豆瓣图片源保存逻辑 | `tv_settings_screen_test.dart` |
| TV 缺少缓存大小和清理入口 | 设置页展示缓存大小并提供 `清除所有缓存` 操作 | `tv_settings_screen_test.dart` |
| 低空间仍继续写图片磁盘缓存 | `AppCacheService` 低于 500MB 返回不使用图片磁盘缓存 | `app_cache_service_test.dart` |
| 二级标题固定不动 | `TvVideoGrid` 使用 `CustomScrollView`，标题作为首个 sliver | `tv_home_screen_test.dart` |

## 6. Good / Base / Bad Cases

### 6.1 Good Case

用户在 BlueStacks Debug 环境启动 App，直接进入 `IvyTV` 顶部导航的 TV 首页。用户在「继续观看」中向右浏览，再按下方向键进入「热门电影」，「继续观看」横向列表自动回到开头。用户选择影片卡片后进入详情页，在详情页内完成换源、选集、收藏，点击全屏进入普通播放器页。

用户也可以在顶部导航切到「电影」「剧集」「动漫」「综艺」大类。焦点移动到对应菜单后页面立即切换，并使用纵向 Grid 展示该大类内容。

顶部导航第一行左侧展示 `IvyTV` Logo，右上角提供「搜索、播放历史、收藏夹、设置」四个快捷按钮，并在最右侧展示当前时间。播放历史、收藏夹和设置不再出现在左侧主分类菜单中，快捷入口必须与 Logo 同行、靠右展示，主分类菜单独立放在下一行，确认快捷按钮后进入对应页面。

### 6.2 Base Case

用户在普通 Android 手机启动 App。由于不是 TV 设备，且 Release 不强制 TV，应用进入原有登录、本地模式和普通首页流程。

### 6.3 Bad Case

用户在 TV 首页横向列表移动很远后离开分区，返回该分区时列表仍停留在旧位置。该行为不符合 TV 浏览习惯，必须由 `TvHomeSection` 的失焦复位逻辑修正。

用户在 TV 搜索页「影片推荐」移动到最右侧后继续按右键没有任何反馈，或推荐卡片获焦放大比例小于首页卡片。该行为会让搜索页和首页的遥控器手感不一致，必须复用 `TvEdgeShake` 与 `TvVideoCard.focusedScale`。

## 7. Tests Required

新增或修改 TV 功能时，根据触达范围选择测试：

```bash
flutter test test/services/app_device_service_test.dart
flutter test test/app_bootstrap_test.dart
flutter test test/tv_app/tv_home_screen_test.dart
flutter test test/tv_app/tv_search_screen_test.dart
flutter test test/tv_app/tv_home_section_test.dart
flutter test test/tv_app/tv_top_nav_test.dart
flutter test test/tv_app/tv_video_card_test.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/tv_settings_screen_test.dart
```

针对性分析：

```bash
flutter analyze lib/tv_app test/tv_app
```

构建验证：

```bash
flutter build apk --debug
```

提交前空白检查：

```bash
git diff --check
```

## 8. Wrong vs Correct

### 8.1 TV 页面边界

#### Wrong

```dart
// 在普通首页里塞 TV 判断和 TV 布局分支。
if (isTv) {
  return TvLayoutInsideNormalHome();
}
```

#### Correct

```dart
// 启动阶段分流，TV 页面放入 lib/tv_app/。
return isTv ? const TvAppShell() : const SeleneApp();
```

### 8.2 卡片焦点样式

#### Wrong

```dart
// 整张卡片都画焦点边框，标题和年份也被包住。
Container(
  decoration: focusedBorder,
  child: Column(children: [cover, title, subtitle]),
);
```

#### Correct

```dart
// 整张卡片做轻微缩放，焦点边框只画在封面上。
AnimatedScale(
  scale: hasFocus ? TvVideoCard.focusedScale : 1,
  child: Column(children: [coverWithBorder, title, subtitle]),
);
```

### 8.3 顶部导航切换

#### Wrong

```dart
// 焦点移动到菜单后还要按确认键才切换。
TvFocusable(onPressed: () => onChanged(index));
```

#### Correct

```dart
// 焦点进入菜单项就切换，确认键只作为兼容输入。
TvFocusable(
  onFocusChanged: (hasFocus) {
    if (hasFocus && !selected) {
      onChanged(index);
    }
  },
  onPressed: () => onChanged(index),
);
```

顶部导航还有一个特殊规则：当焦点从内容区进入顶部导航时，不允许按空间距离直接落到就近菜单项。必须先请求 `selectedIndex` 对应菜单项的焦点；只有导航栏内部左右移动时，才能焦点到哪就切到哪。

顶部导航右上角必须提供搜索、播放历史、收藏夹、设置四个图标文字快捷入口，且快捷入口与 `IvyTV` Logo 同行、与左侧主分类菜单上下错开，不放在同一行。快捷入口属于顶部导航内部焦点成员：从内容区回到顶部导航时仍先回当前选中菜单项或当前选中快捷入口。直播菜单项作为快捷区过渡：直播按上方向键进入搜索快捷入口，搜索快捷入口按下方向键回到直播菜单项；首页菜单项也可按上方向键进入右上快捷按钮区。电影、剧集、动漫、综艺菜单项按上方向键仍只呼出分类筛选面板，不跳到快捷入口。筛选面板展开时顶部导航整体收起，快捷入口和当前时间也随顶部导航隐藏。

TV 搜索页必须使用 `lib/tv_app/screens/tv_search_screen.dart`，不要直接打开普通端 `SearchScreen`。页面左侧提供搜索输入展示、字母数字遥控器键盘、清空和删除按钮；右侧顶部展示搜索历史纯文字 Grid，下面展示搜索热词纯文字 Grid。搜索页左侧搜索标题和右侧搜索历史标题必须使用统一顶部留白，首屏默认状态不能明显偏下。搜索历史复用 `PageCacheService.getSearchHistory`，搜索热词当前使用本地 mock 列表，后续有接口后再替换。右侧下方可展示影片推荐横向列表，推荐点击进入 `TvVideoDetailScreen`。影片推荐列表的焦点放大比例必须与首页 `TvVideoCard.focusedScale` 一致，到达左右边界时必须复用 `TvEdgeShake` 给出边界抖动反馈。

### 8.4 横向分区滚动复位

#### Wrong

```dart
// 横向列表滚动状态完全留给 ListView，离开分区后不复位。
ListView.separated(scrollDirection: Axis.horizontal);
```

#### Correct

```dart
// 分区失去焦点时复位自己的横向列表。
Focus(
  onFocusChange: (hasFocus) {
    if (!hasFocus && controller.hasClients) {
      controller.jumpTo(0);
    }
  },
  child: ListView.separated(
    controller: controller,
    scrollDirection: Axis.horizontal,
  ),
);
```

## 9. Development Notes

- TV 端可以多写小文件，优先保持边界清晰。
- API 和 service 能复用就复用，但不要让普通端页面承担 TV 逻辑。
- Widget test 中需要避免真实网络加载，使用注入的 loader 或 builder。
- `TvHomeScreen` 的 `buildDetailPage` 用于测试替换真实详情页，避免卡片跳转测试触发详情页网络请求。
- `TvVideoDetailScreen` 的 `loadDetail` 和 `playerBuilder` 用于隔离详情数据和播放器。
- 新增 TV 焦点行为时，优先在 `TvFocusable` 或具体 TV 组件内封装，不要在页面里散落键盘事件。
