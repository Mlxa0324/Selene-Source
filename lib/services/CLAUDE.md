[根目录](../../CLAUDE.md) > [lib](../) > **services**

---

# Services 模块

## 模块职责

Services 模块是应用的业务逻辑层，负责数据获取、处理、缓存和状态管理。所有与外部 API、本地存储、数据转换相关的逻辑都封装在此模块中。

---

## 入口与启动

**核心服务：**
- `api_service.dart`：统一 API 调用封装
- `user_data_service.dart`：用户数据持久化
- `search_service.dart`：多源搜索聚合
- `theme_service.dart`：主题管理（Provider）

**服务初始化：**
- `DoubanCacheService` 在 `main.dart` 中初始化并启动定期清理
- `ThemeService` 通过 Provider 注入到 Widget 树
- 其他服务按需调用静态方法

---

## 对外接口

### ApiService

**核心方法：**
```dart
// 自动登录
static Future<ApiResponse<void>> autoLogin()

// 用户登录
static Future<ApiResponse<void>> login(String username, String password)

// 获取搜索源
static Future<ApiResponse<List<SearchResource>>> getSearchSources()

// 搜索视频
static Future<ApiResponse<List<SearchResult>>> search(String query, String source)

// 添加收藏
static Future<ApiResponse<void>> addFavorite(FavoriteItem item)

// 获取播放记录
static Future<ApiResponse<List<PlayRecord>>> getPlayRecords()
```

### SearchService

**核心方法：**
```dart
// 聚合搜索（多源并发）
static Future<List<AggregatedSearchResult>> aggregatedSearch(String query)

// 单源搜索
static Future<List<SearchResult>> searchFromSource(String query, String source)

// 获取搜索建议
static Future<List<SearchSuggestion>> getSearchSuggestions(String query)
```

### DoubanService

**核心方法：**
```dart
// 搜索豆瓣电影
static Future<List<DoubanMovie>> searchMovies(String query)

// 获取电影详情
static Future<DoubanMovieDetails?> getMovieDetails(int doubanId)
```

### UserDataService

**核心方法：**
```dart
// 保存/获取服务器地址
static Future<void> saveServerUrl(String url)
static Future<String?> getServerUrl()

// 保存/获取登录凭证
static Future<void> saveCookies(String cookies)
static Future<String?> getCookies()

// 本地模式管理
static Future<void> setIsLocalMode(bool isLocalMode)
static Future<bool> getIsLocalMode()
```

---

## 关键依赖与配置

### 外部依赖
- `http`：HTTP 请求
- `dio`：高级 HTTP 客户端
- `shared_preferences`：本地存储
- `path_provider`：文件路径
- `web_socket_channel`：WebSocket（SSE 搜索）

### 数据存储
- **SharedPreferences**：用户配置、登录凭证、主题设置
- **文件系统**：豆瓣缓存、页面缓存

### 缓存策略
- **DoubanCacheService**：
  - 缓存有效期：7 天
  - 定期清理：每 24 小时
  - 存储位置：应用文档目录
- **PageCacheService**：
  - 缓存页面数据（首页、分类页）
  - 缓存时间：可配置

---

## 数据模型

### 服务使用的模型
- `SearchResult`：搜索结果
- `SearchResource`：搜索源配置
- `AggregatedSearchResult`：聚合搜索结果
- `DoubanMovie`：豆瓣电影简要信息
- `DoubanMovieDetails`：豆瓣电影详情
- `FavoriteItem`：收藏项
- `PlayRecord`：播放记录
- `LiveSource`：直播源
- `LiveChannel`：直播频道
- `EpgProgram`：EPG 节目单

---

## 测试与质量

**当前状态：** 无测试覆盖

**建议测试：**
1. **单元测试**：
   - `ApiService` 的请求构建和错误处理
   - `SearchService` 的聚合逻辑
   - `DoubanCacheService` 的缓存过期和清理
2. **Mock 测试**：
   - 模拟 HTTP 响应测试 API 解析
   - 模拟本地存储测试数据持久化

---

## 常见问题 (FAQ)

### Q1: 如何添加新的 API 接口？
1. 在 `ApiService` 中添加新的静态方法
2. 使用 `_buildUrl` 和 `_buildHeaders` 构建请求
3. 使用 `ApiResponse` 封装返回结果
4. 处理异常并返回友好错误信息

### Q2: 如何切换本地模式和服务器模式？
- 通过 `UserDataService.setIsLocalMode(bool)` 切换
- 本地模式使用 `LocalModeStorageService` 管理数据
- 服务器模式使用 `ApiService` 调用远程 API

### Q3: 缓存如何清理？
- **手动清理**：调用 `DoubanCacheService.clearCache()`
- **自动清理**：`startPeriodicCleanup()` 每 24 小时清理过期缓存

---

## 相关文件清单

### API 与网络
- `api_service.dart` (统一 API 封装)
- `downstream_service.dart` (下游服务)
- `sse_search_service.dart` (SSE 搜索)

### 搜索相关
- `search_service.dart` (搜索聚合)
- `local_search_cache_service.dart` (本地搜索缓存)

### 数据服务
- `douban_service.dart` (豆瓣 API)
- `bangumi_service.dart` (番剧服务)
- `live_service.dart` (直播服务)
- `m3u8_service.dart` (M3U8 解析)

### 缓存管理
- `douban_cache_service.dart` (豆瓣缓存)
- `page_cache_service.dart` (页面缓存)

### 本地存储
- `user_data_service.dart` (用户数据)
- `local_mode_storage_service.dart` (本地模式存储)

### 其他服务
- `theme_service.dart` (主题管理)
- `version_service.dart` (版本检查)
- `subscription_service.dart` (订阅管理)
- `content_filter_service.dart` (内容过滤)

### 接口定义
- `data_operation_interface.dart` (数据操作接口)

### 文件统计
- 总文件数：17
- 代码行数：约 8,000+ 行（估算）
- 最复杂服务：`api_service.dart`、`search_service.dart`

---

## 变更记录 (Changelog)

### 2026-01-11
- 初始化模块文档
- 识别 17 个服务类
- 记录核心 API 和缓存策略

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11
