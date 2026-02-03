# 继续观看进入视频播放源减少的原因分析报告

## 1. 现象描述
- **场景 A**：从“继续观看”列表点击一个“很早之前”的视频进入播放页。
  - **结果**：换源列表里只有一个播放源。
- **场景 B**：回退到首页，搜索该视频或从首页入口点进去。
  - **结果**：换源列表里出现多个播放源。

## 2. 核心代码分析 (lib/services/api_service.dart)

### 2.1 接口调用的差异性
在 `ApiService` 中，存在两个获取视频数据的核心方法：

1. **`fetchSourceDetail(source, id)`** (用于“继续观看”等精准进入场景):
   ```dart
   static Future<List<SearchResult>> fetchSourceDetail(String source, String id) async {
     final response = await get<SearchResult>(
       '/api/detail',
       queryParameters: {'source': source, 'id': id}, // 💡 注意：这里只传了单一的 source
       // ...
     );
     if (response.success && response.data != null) {
       return [response.data!]; // 💡 重点：这里只返回了这一个源的数据
     }
     // ...
   }
   ```
   **原因**：该接口是面向“点”的，它只根据播放记录里存的 `source` ID 去服务器取那一个特定源的剧集信息。

2. **`fetchSourcesData(query)`** (用于首页搜索或点击卡片进入):
   ```dart
   static Future<List<SearchResult>> fetchSourcesData(String query) async {
     // 1. 检查缓存
     final cachedResults = await UserDataService.getSearchCache(query);
     if (cachedResults != null) return cachedResults; // 💡 返回全量源

     // 2. 缓存不存在时，进行流式搜索
     final results = await _fetchSourcesDataStreaming(query); // 💡 搜集所有源
     // ...
     return results;
   }
   ```
   **原因**：该接口是面向“面”的，它会触发全网搜索，并将搜集到的所有源合并返回。

### 2.2 搜索缓存失效 (针对“很早之前”的视频)
在 `fetchSourceDetail` 的逻辑中，有一行尝试补救的代码：
```dart
// 点击进入播放页时，尝试续约对应的搜索缓存时间
UserDataService.renewSearchCache(response.data!.title);
```
- **理想情况**：如果视频是最近看的，缓存还在，`renew` 会延长全量搜索结果的有效期。此时进入播放页，上层逻辑会优先合并缓存中的全量源，加上当前详情源。
- **现实情况 (问题所在)**：对于“很早之前”的视频，`UserDataService` 里的搜索缓存（通常只有 2 小时有效期）早已经消失了。此时执行 `renewSearchCache` 是无效的。因为没有全局搜索结果的支撑，应用只能展示 `fetchSourceDetail` 拿回来的那唯一一个源。

## 3. 结论
之所以出现这种差异，是因为：
1. **精准定位 vs 全网搜索**：“继续观看”是基于播放记录的精准定位，只加载了记录中的那个源以提高加载速度。
2. **缓存断档**：旧视频的搜索缓存已过期。在没有缓存的情况下，系统不会在 `fetchSourceDetail` 时自动触发耗时的全网流式搜索，因此换源列表显得“单薄”。
3. **首页触发重搜**：回到首页再次点击时，应用发现没有缓存，会重新触发 `fetchSourcesData` 里的全网搜索逻辑，从而找回了所有的源。

## 4. 改进建议
如果希望在“继续观看”进入时也看到多源，可以考虑：
- 在 `PlayerScreen` 初始化时，如果发现 `fetchSourceDetail` 返回的列表长度为 1 且没有可用缓存，自动在后台触发一次静默搜索（`fetchSourcesData`）来填充换源列表。

---
*分析完成 - Selene 优化小组*
