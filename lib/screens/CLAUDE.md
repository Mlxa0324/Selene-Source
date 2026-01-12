[根目录](../../CLAUDE.md) > [lib](../) > **screens**

---

# Screens 模块

## 模块职责

Screens 模块包含应用的所有页面级组件，负责整体页面布局、路由导航和用户交互流程。每个 Screen 通常对应一个完整的应用页面。

---

## 入口与启动

**主要页面：**
- `login_screen.dart`：登录页面（应用启动入口之一）
- `home_screen.dart`：首页（主导航页面）
- `player_screen.dart`：视频播放页面（核心功能）

**启动流程：**
1. `main.dart` 中的 `AppWrapper` 检查登录状态
2. 本地模式 → 直接进入 `HomeScreen`
3. 服务器模式 → 自动登录成功 → `HomeScreen`，失败 → `LoginScreen`

---

## 对外接口

### 页面路由

所有页面通过 Flutter 的 `Navigator` 进行路由跳转：

```dart
// 跳转到播放器页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PlayerScreen(
      title: '电影名称',
      source: 'source_id',
      id: 'video_id',
    ),
  ),
);
```

### 页面参数

**PlayerScreen 参数：**
- `source`：视频源标识
- `id`：视频 ID
- `title`：视频标题
- `year`：年份（可选）
- `stitle`：子标题（可选）
- `stype`：类型（可选）
- `prefer`：偏好源（可选）

**SearchScreen 参数：**
- `initialQuery`：初始搜索关键词（可选）

---

## 关键依赖与配置

### 依赖的 Services
- `ApiService`：API 调用
- `UserDataService`：用户数据存储
- `SearchService`：搜索聚合
- `DoubanService`：豆瓣信息
- `M3u8Service`：M3U8 解析
- `LiveService`：直播频道
- `ThemeService`：主题管理

### 依赖的 Widgets
- `MainLayout`：主布局框架
- `VideoPlayerWidget`：视频播放器
- `VideoCard`：视频卡片
- `SearchResultsGrid`：搜索结果网格
- `WindowsTitleBar`：Windows 标题栏

### 状态管理
- 使用 `StatefulWidget` 管理页面内部状态
- 通过 `Provider` 访问全局状态（如 `ThemeService`）

---

## 数据模型

### 使用的模型
- `SearchResult`：搜索结果
- `DoubanMovieDetails`：豆瓣电影详情
- `PlayRecord`：播放记录
- `FavoriteItem`：收藏项
- `LiveChannel`：直播频道
- `EpgProgram`：EPG 节目单

---

## 测试与质量

**当前状态：** 无测试覆盖

**建议测试：**
1. **Widget 测试**：
   - 登录页面表单验证
   - 首页导航切换
   - 播放器控件交互
2. **集成测试**：
   - 完整登录流程
   - 搜索 → 播放流程
   - 收藏和历史记录

---

## 常见问题 (FAQ)

### Q1: 如何添加新页面？
1. 在 `lib/screens/` 创建新的 Dart 文件
2. 继承 `StatefulWidget` 或 `StatelessWidget`
3. 在需要的地方使用 `Navigator.push` 跳转

### Q2: 页面间如何传递数据？
- **正向传递**：通过构造函数参数
- **反向传递**：使用 `Navigator.pop(context, result)`
- **全局状态**：使用 Provider

### Q3: 如何处理页面生命周期？
- 使用 `WidgetsBindingObserver` 监听应用生命周期
- 在 `initState` 中初始化数据
- 在 `dispose` 中释放资源

---

## 相关文件清单

### 核心页面
- `login_screen.dart` (登录页)
- `home_screen.dart` (首页)
- `player_screen.dart` (播放器)
- `search_screen.dart` (搜索页)

### 内容页面
- `movie_screen.dart` (电影页)
- `show_screen.dart` (综艺页)
- `tv_screen.dart` (电视剧页)
- `anime_screen.dart` (动漫页)
- `live_screen.dart` (直播页)
- `live_player_screen.dart` (直播播放器)

### 文件统计
- 总文件数：11
- 代码行数：约 10,000+ 行（估算）
- 最复杂文件：`player_screen.dart`（约 2000+ 行）

---

## 变更记录 (Changelog)

### 2026-01-12 16:55:00
- 修复 `player_screen.dart` 全屏弹幕显示：通过 `danmakuLayer` 将弹幕注入 `VideoPlayerWidget`。
- 实现弹幕与视频播放速度同步逻辑。

### 2026-01-11
- 初始化模块文档
- 识别 11 个页面组件
- 记录核心依赖和数据流

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11
