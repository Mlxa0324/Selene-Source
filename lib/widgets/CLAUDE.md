[根目录](../../CLAUDE.md) > [lib](../) > **widgets**

---

# Widgets 模块

## 变更记录 (Changelog)

### 2026-01-12 16:55:00
- 重构 `danmaku_settings_panel.dart`：支持中文屏蔽按钮、行间距范围扩展、功能开关。
- 更新 `video_player_widget.dart`：新增 `danmakuLayer` 参数，支持在全屏 Overlay 中渲染弹幕。

### 2026-01-11 13:45:58
- 新增 `player_settings_panel.dart`：播放器设置面板（倍速、画面比例）
- 更新文件统计：40 个组件

### 2026-01-11 00:42:13
- 初始化模块文档
- 识别可复用组件
- 按功能分类整理

---

## 模块职责

Widgets 模块包含应用的所有可复用 UI 组件，提供从基础控件到复杂交互组件的完整封装。这些组件被 Screens 模块引用，实现 UI 的模块化和复用。

---

## 入口与启动

**核心组件：**
- `video_player_widget.dart`：视频播放器核心组件
- `main_layout.dart`：应用主布局框架
- `pc_player_controls.dart` / `mobile_player_controls.dart`：播放器控件

**组件分类：**
1. **播放器相关**：视频播放、控制、投屏、设置
2. **内容展示**：卡片、网格、列表
3. **交互控件**：开关、选择器、对话框
4. **布局组件**：标题栏、导航、面板

---

## 对外接口

### 主要组件 API

**VideoPlayerWidget**
```dart
VideoPlayerWidget({
  required String url,              // 视频 URL
  VideoPlayerWidgetController? controller,  // 控制器
  Function(Duration)? onPositionChanged,    // 进度回调
  Function()? onCompleted,                  // 完成回调
})
```

**VideoCard**
```dart
VideoCard({
  required String title,            // 标题
  required String imageUrl,         // 封面图
  String? subtitle,                 // 副标题
  VoidCallback? onTap,              // 点击回调
  double? progress,                 // 播放进度
})
```

**PlayerSettingsPanel** (新增)
```dart
PlayerSettingsPanel({
  required ThemeData theme,                    // 主题数据
  required VideoFitType currentFitType,        // 当前画面比例
  required double currentPlaybackSpeed,        // 当前播放速度
  required Function(VideoFitType) onFitTypeChanged,      // 比例变更回调
  required Function(double) onPlaybackSpeedChanged,      // 速度变更回调
})
```

**DlnaPlayer**
```dart
DlnaPlayer({
  required String videoUrl,         // 视频 URL
  required String videoTitle,       // 视频标题
  Function(String)? onDeviceSelected,  // 设备选择回调
})
```

---

## 关键依赖与配置

### 外部依赖
- `media_kit`：桌面端视频播放
- `media_kit_video`：视频渲染
- `dlna_dart`：DLNA 投屏
- `pip`：画中画模式
- `cached_network_image`：图片缓存
- `lucide_icons_flutter`：图标库

### 内部依赖
- `services/theme_service.dart`：主题管理
- `services/user_data_service.dart`：用户数据
- `models/*`：数据模型

### 平台特定配置
- **Windows**：使用 `bitsdojo_window` 自定义标题栏
- **macOS**：使用 `macos_window_utils` 透明标题栏
- **移动端**：使用原生播放器控件

---

## 数据模型

### 使用的模型
- `SearchResult`：搜索结果（用于视频卡片）
- `DoubanMovieDetails`：豆瓣详情（用于详情面板）
- `FavoriteItem`：收藏项（用于收藏网格）
- `PlayRecord`：播放记录（用于历史网格）
- `LiveChannel`：直播频道（用于直播卡片）
- `VideoFitType`：画面比例枚举（用于设置面板）

---

## 测试与质量

**当前状态：** 无测试覆盖

**建议测试：**
1. **Widget 测试**：
   - `VideoCard` 点击和显示
   - `CustomSwitch` 状态切换
   - `FilterOptionsSelector` 选项选择
   - `PlayerSettingsPanel` 设置选择
2. **Golden 测试**：
   - 播放器控件在不同状态下的截图对比
   - 主题切换后的 UI 一致性

---

## 常见问题 (FAQ)

### Q1: 如何创建新的可复用组件？
1. 在 `lib/widgets/` 创建新文件
2. 继承 `StatelessWidget` 或 `StatefulWidget`
3. 定义清晰的构造函数参数
4. 在需要的 Screen 中引用

### Q2: 播放器如何切换桌面/移动端实现？
- 通过 `Platform.isAndroid || Platform.isIOS` 判断
- 移动端使用原生播放器
- 桌面端使用 `media_kit`

### Q3: 如何实现 DLNA 投屏？
1. 使用 `DlnaDeviceDialog` 选择设备
2. 调用 `DlnaPlayer` 推送视频 URL
3. 使用 `DlnaPlayerControls` 控制播放

### Q4: 如何使用播放器设置面板？
1. 导入 `player_settings_panel.dart`
2. 使用 `showModalBottomSheet` 显示面板
3. 处理 `onFitTypeChanged` 和 `onPlaybackSpeedChanged` 回调

---

## 相关文件清单

### 播放器组件
- `video_player_widget.dart` (播放器核心)
- `video_player_surface.dart` (播放器渲染层)
- `pc_player_controls.dart` (桌面端控件)
- `mobile_player_controls.dart` (移动端控件)
- `player_details_panel.dart` (详情面板)
- `player_episodes_panel.dart` (集数面板)
- `player_sources_panel.dart` (源选择面板)
- `player_settings_panel.dart` (设置面板 - 倍速/画面比例)

### DLNA 组件
- `dlna_player.dart` (DLNA 播放器)
- `dlna_player_controls.dart` (DLNA 控制)
- `dlna_device_dialog.dart` (设备选择对话框)

### 内容展示组件
- `video_card.dart` (视频卡片)
- `bangumi_grid.dart` (番剧网格)
- `bangumi_section.dart` (番剧区块)
- `douban_movies_grid.dart` (豆瓣电影网格)
- `favorites_grid.dart` (收藏网格)
- `history_grid.dart` (历史网格)
- `search_results_grid.dart` (搜索结果网格)
- `search_result_agg_grid.dart` (聚合搜索网格)

### 交互控件
- `custom_switch.dart` (自定义开关)
- `filter_options_selector.dart` (筛选选择器)
- `filter_pill_hover.dart` (筛选标签)
- `capsule_tab_switcher.dart` (胶囊标签切换)
- `simple_tab_switcher.dart` (简单标签切换)
- `top_tab_switcher.dart` (顶部标签切换)
- `update_dialog.dart` (更新对话框)
- `video_menu_bottom_sheet.dart` (视频菜单)

### 布局组件
- `main_layout.dart` (主布局)
- `windows_title_bar.dart` (Windows 标题栏)
- `user_menu.dart` (用户菜单)

### 特效组件
- `shimmer_effect.dart` (骨架屏效果)
- `pulsing_dots_indicator.dart` (脉冲加载指示器)
- `switch_loading_overlay.dart` (切换加载蒙版)
- `custom_refresh_indicator.dart` (自定义刷新指示器)
- `fullscreen_image_viewer.dart` (全屏图片查看器)

### 推荐组件
- `continue_watching_section.dart` (继续观看)
- `recommendation_section.dart` (推荐区块)
- `hot_movies_section.dart` (热门电影)
- `hot_show_section.dart` (热门综艺)
- `hot_tv_section.dart` (热门电视剧)

### 文件统计
- 总文件数：40
- 代码行数：约 15,000+ 行（估算）
- 最复杂组件：`video_player_widget.dart`、`pc_player_controls.dart`

---

**模块版本：** 1.1.0
**最后更新：** 2026-01-11
