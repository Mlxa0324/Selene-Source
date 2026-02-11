# Selene - Flutter Video Player

基于 MoonTV 的跨平台视频播放应用，支持弹幕、下载、广告过滤等多种高级功能。

## 项目概览

- **核心技术栈**: Flutter (Dart), Provider (状态管理), Dio/Http (网络请求), media_kit (PC 播放引擎), video_player (移动端播放引擎)。
- **主要功能**:
  - **视频播放**: 支持多格式视频播放，支持倍速调整、画面比例切换。
  - **M3U8 下载**: 支持分片并行下载、断点续传，自动生成本地索引。
  - **弹幕系统**: 集成 `canvas_danmaku`，支持弹幕搜索、屏蔽、性能优化及设置持久化。
  - **广告过滤**: 自动过滤 M3U8 中的广告片段。
  - **多平台支持**: 适配 Android, iOS, macOS, Windows 等平台。
  - **本地/服务器模式**: 支持订阅源解析和服务器同步。

## 目录结构

- `lib/`: 核心源代码目录
  - `models/`: **数据模型层** (POJO/Entity)
    - `aggregated_search_result.dart`: 聚合多源搜索结果的容器。
    - `bangumi.dart` & `douban_movie.dart`: 针对番剧和豆瓣电影数据的特定元数据模型。
    - `danmaku_model.dart`: 弹幕内容模型（含位置、颜色、时间等）。
    - `download_task.dart`: M3U8 下载任务状态模型（含进度、分片列表）。
    - `live_channel.dart` & `live_source.dart`: 直播频道及其物理源模型。
    - `play_record.dart`: 本地/云端同步的视频播放进度记录。
    - `search_resource.dart`: 搜索源配置（如资源站 API 配置）。
  - `services/`: **核心业务服务层** (Logic & Data Storage)
    - `api_service.dart`: 封装基于 http/dio 的 RESTful 请求与 SSE 流式搜索处理。
    - `user_data_service.dart`: 管理用户偏好、服务器地址、Cookie 及登录凭证。
    - `local_mode_storage_service.dart`: 针对“本地模式”（无服务器依赖，通过 M3U 订阅）的存储逻辑。
    - `download_service.dart`: M3U8 下载调度中心，负责并行下载、队列管理及本地 .m3u8 生成。
    - `danmaku_service.dart`: 弹幕协议对接（支持搜索、匹配、过滤逻辑）。
    - `douban_cache_service.dart`: 豆瓣元数据本地缓存，减少第三方 API 请求频率。
    - `theme_service.dart`: 响应式主题切换（明亮/深色模式及自定义配色方案）。
  - `screens/`: **展示层** (UI Pages)
    - `home_screen.dart`: 应用导航中枢，包含分类导航和快速入口。
    - `player_screen.dart`: 全功能播放器页面，高度集成了控制面板、弹幕、设置、选集等功能。
    - `search_screen.dart`: 聚合搜索入口，支持实时增量显示搜索结果。
    - `live_screen.dart` & `live_player_screen.dart`: 直播频道浏览与专用流媒体播放环境。
    - `download_screen.dart`: 下载任务管理器。
    - `anime_screen.dart`, `movie_screen.dart`, `tv_screen.dart`: 按媒体类型组织的专题页面。
  - `widgets/`: **组件层** (Reusable Widgets)
    - `player_settings_panel.dart`: 播放倍速、比例等高级设置面板。
    - `danmaku_settings_panel.dart`: 弹幕大小、速度、屏蔽过滤等细粒度控制。
    - 各种自定义 Button、Card 和 Layout 辅助组件。
  - `utils/`: 通用工具类，如日期格式化、文本处理等。
- `需求/`: **产品路线图**。包含功能原型描述、历史优化记录（如弹幕性能优化、M3U8 去广告分析）。
- `分析/`: **技术方案与排错**。包含全屏延迟、播放源失效、下载协议分析等深度技术文档。
- `.spec-workflow/`: **研发工作流**。项目特有的任务分发、审批与设计规范模板。
- `android/`, `ios/`, `macos/`, `windows/`: 平台原生配置文件与集成代码。
- `dist/`: 构建产物目录，存放 `build.sh` 生成的各平台安装包 (APK, IPA, DMG)。

## 构建与运行

### 环境要求
- Flutter SDK: `>=3.4.3 <4.0.0`
- 对应平台的开发环境 (Android SDK, Xcode, Visual Studio 等)

### 常用命令
- **获取依赖**: `flutter pub get`
- **运行应用**: `flutter run`
- **清理构建**: `flutter clean`
- **通用构建脚本**:
  ```bash
  # 构建所有平台 (Android, iOS, macOS)
  ./build.sh
  
  # 仅构建 Android
  ./build.sh --android-only
  
  # 仅构建 macOS
  ./build.sh --macos-only
  ```

## 开发约定

- **变更记录**: 所有重大更新请记录在 `CLAUDE.md` 中。
- **状态管理**: 使用 `Provider` 进行全局和局部状态管理。
- **网络请求**:
  - 使用 `http` 或 `dio` 库进行 API 交互。
  - **API 模式**: 采用 REST API 处理常规数据，搜索功能支持 SSE (Server-Sent Events) 流式返回。
  - **认证机制**: 基于 Cookie 的认证，相关逻辑在 `ApiService` 和 `UserDataService` 中处理。
- **代码规范**: 遵循 `analysis_options.yaml` 中的 Flutter 推荐 Lint 规则。
- **平台适配**: 
  - PC 端使用 `media_kit` 以获得更好的格式支持。
  - 移动端优先使用 `video_player` 以优化性能 and 能耗。
  - 窗口管理在 macOS 使用 `WindowManipulator`，Windows 使用 `bitsdojo_window`。
- **性能优化**: 
  - 弹幕渲染需使用 `RepaintBoundary` 进行隔离。
  - 网络请求需设置合理的超时控制，防止启动阻塞。
