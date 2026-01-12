[根目录](../../CLAUDE.md) > [lib](../) > **models**

---

# Models 模块

## 模块职责

Models 模块定义应用的所有数据结构，提供数据的序列化/反序列化、验证和转换功能。这些模型被 Services 和 Screens 模块广泛使用。

---

## 入口与启动

**核心模型：**
- `search_result.dart`：搜索结果（最常用）
- `video_info.dart`：视频详细信息
- `douban_movie.dart`：豆瓣电影数据
- `play_record.dart`：播放记录

**模型特点：**
- 使用 `fromJson` 和 `toJson` 进行 JSON 序列化
- 部分模型包含业务逻辑方法（如数据验证）
- 支持可空字段以适应不同数据源

---

## 对外接口

### SearchResult

**字段：**
```dart
class SearchResult {
  final String source;        // 视频源标识
  final String id;            // 视频 ID
  final String title;         // 标题
  final String? year;         // 年份
  final String? cover;        // 封面图
  final String? desc;         // 描述
  final String? type;         // 类型（电影/电视剧/综艺）
  final List<Episode>? episodes;  // 集数列表

  factory SearchResult.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### DoubanMovie

**字段：**
```dart
class DoubanMovie {
  final int id;               // 豆瓣 ID
  final String title;         // 标题
  final String? cover;        // 封面
  final double? rating;       // 评分
  final String? year;         // 年份

  factory DoubanMovie.fromJson(Map<String, dynamic> json);
}

class DoubanMovieDetails extends DoubanMovie {
  final String? summary;      // 简介
  final List<String>? directors;  // 导演
  final List<String>? actors;     // 演员
  final List<String>? genres;     // 类型

  factory DoubanMovieDetails.fromJson(Map<String, dynamic> json);
}
```

### PlayRecord

**字段：**
```dart
class PlayRecord {
  final String source;        // 视频源
  final String id;            // 视频 ID
  final String title;         // 标题
  final String? cover;        // 封面
  final int episodeIndex;     // 当前集数
  final Duration position;    // 播放位置
  final DateTime lastPlayed;  // 最后播放时间

  factory PlayRecord.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### LiveChannel

**字段：**
```dart
class LiveChannel {
  final String name;          // 频道名称
  final String url;           // 播放 URL
  final String? logo;         // 频道 Logo
  final String? group;        // 分组
  final List<EpgProgram>? programs;  // EPG 节目单

  factory LiveChannel.fromJson(Map<String, dynamic> json);
}
```

---

## 关键依赖与配置

### 外部依赖
- 无外部依赖（纯数据模型）

### 内部依赖
- 模型之间存在引用关系（如 `SearchResult` 包含 `Episode` 列表）

### 序列化约定
- 使用 `factory` 构造函数实现 `fromJson`
- 使用实例方法实现 `toJson`
- 可空字段使用 `?` 标记
- 日期时间使用 `DateTime` 类型，序列化为 ISO 8601 字符串

---

## 数据模型

### 模型列表

**搜索相关：**
- `search_result.dart`：搜索结果
- `search_resource.dart`：搜索源配置
- `search_suggestion.dart`：搜索建议
- `aggregated_search_result.dart`：聚合搜索结果

**视频相关：**
- `video_info.dart`：视频详细信息
- `bangumi.dart`：番剧数据
- `douban_movie.dart`：豆瓣电影

**直播相关：**
- `live_source.dart`：直播源
- `live_channel.dart`：直播频道
- `epg_program.dart`：EPG 节目单
- `m3u_content.dart`：M3U 内容

**用户数据：**
- `favorite_item.dart`：收藏项
- `play_record.dart`：播放记录

---

## 测试与质量

**当前状态：** 无测试覆盖

**建议测试：**
1. **单元测试**：
   - JSON 序列化/反序列化正确性
   - 边界情况处理（空值、异常数据）
   - 数据验证逻辑
2. **测试用例示例**：
   ```dart
   test('SearchResult fromJson should parse correctly', () {
     final json = {'source': 'test', 'id': '123', 'title': 'Test'};
     final result = SearchResult.fromJson(json);
     expect(result.title, 'Test');
   });
   ```

---

## 常见问题 (FAQ)

### Q1: 如何添加新的数据模型？
1. 在 `lib/models/` 创建新文件
2. 定义类和字段
3. 实现 `fromJson` 和 `toJson` 方法
4. 在需要的 Service 中引用

### Q2: 如何处理 API 返回的不一致数据？
- 使用可空字段 `?` 标记可选数据
- 在 `fromJson` 中使用 `??` 提供默认值
- 添加数据验证方法

### Q3: 模型如何支持多个数据源？
- 使用 `source` 字段标识数据来源
- 在 `fromJson` 中根据 `source` 进行不同解析
- 使用工厂模式创建不同子类

---

## 相关文件清单

### 搜索模型
- `search_result.dart` (搜索结果)
- `search_resource.dart` (搜索源)
- `search_suggestion.dart` (搜索建议)
- `aggregated_search_result.dart` (聚合结果)

### 视频模型
- `video_info.dart` (视频信息)
- `bangumi.dart` (番剧)
- `douban_movie.dart` (豆瓣电影)

### 直播模型
- `live_source.dart` (直播源)
- `live_channel.dart` (直播频道)
- `epg_program.dart` (EPG 节目单)
- `m3u_content.dart` (M3U 内容)

### 用户数据模型
- `favorite_item.dart` (收藏)
- `play_record.dart` (播放记录)

### 文件统计
- 总文件数：14
- 代码行数：约 2,000+ 行（估算）
- 平均每个模型：约 150 行

---

## 变更记录 (Changelog)

### 2026-01-12 17:35:00
- 优化 `DanmakuSearchAnime` 模型：增加 `year` 字段及其自动从标题提取逻辑，支持结果按年份排序。
- 增强 `DanmakuSettings` 模型：新增 `scale`, `lineSpacing`, `fontWeight`, `displayArea`, `preventOverlap`, `syncVideoSpeed` 等字段，支持更精细的弹幕控制。

### 2026-01-11
- 初始化模块文档
- 识别 14 个数据模型
- 记录序列化约定

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11
