# 技术设计：从 Flutter TV 端 1:1 还原非首页 Tab

## 1. 架构总览

```
┌─────────────────────────────────────────────────────┐
│                    app-tv (TvApp)                    │
│  TvApp.kt: LaunchedEffect → clear Coil disk cache   │
│  TvAppContainer: +doubanRepository                  │
│    新的 createVideoLibraryViewModel() 注入 DoubanRepo │
│    settings 相关 save/load 走 TvPreferencesStore     │
├─────────────────────────────────────────────────────┤
│              feature-tv-home (Category)              │
│  TvVideoLibraryViewModel: 改用 DoubanRepository     │
│  TvLibraryFilter: 选项对齐 Flutter TV                │
│  筛选变更 → reload category data（带缓存）           │
├─────────────────────────────────────────────────────┤
│              feature-tv-settings                     │
│  删除 TvPlayerKernel 切换 UI                         │
│  所有开关/选项 → TvPreferencesStore 读写             │
│  服务器配置可编辑 + 保存后触发重新登录               │
│  缓存管理：真实大小 + 清理                           │
├──────────────────────┬──────────────────────────────┤
│     core-data         │       core-network           │
│  DoubanRepository     │  SeleneDoubanApi             │
│  + in-memory cache    │  + DoubanMovieResponse       │
│  TvPreferencesStore   │  + DoubanResponse models     │
│  + 设置持久化字段     │  + SeleneTvNetworkFactory    │
│                       │    .createDoubanApi()        │
└───────────────────────┴──────────────────────────────┘
```

## 2. 网络层设计

### 2.1 SeleneDoubanApi (core-network)

```kotlin
interface SeleneDoubanApi {
    @GET("rexxar/api/v2/subject/recent_hot/{kind}")
    suspend fun getCategoryData(
        @Path("kind") kind: String,
        @Query("start") start: Int,
        @Query("limit") limit: Int = 25,
        @Query("category") category: String,
        @Query("type") type: String = "全部",
    ): DoubanCategoryResponse

    @GET("rexxar/api/v2/{kind}/recommend")
    suspend fun getRecommends(
        @Path("kind") kind: String,
        @Query("refresh") refresh: Int = 0,
        @Query("start") start: Int,
        @Query("count") count: Int,
        @Query("selected_categories") selectedCategories: String,
        @Query("uncollect") uncollect: Boolean = false,
        @Query("score_range") scoreRange: String = "0,10",
        @Query("tags") tags: String = "",
        @Query("sort") sort: String = "T",
    ): DoubanCategoryResponse
}
```

Base URL: `https://m.douban.cmliussss.net/`

Headers: `User-Agent` (Chrome), `Referer` (`https://movie.douban.com/`)

### 2.2 响应模型 (core-network)

```kotlin
data class DoubanCategoryResponse(
    @SerializedName("items") val items: List<DoubanMovieItem>?,
)

data class DoubanMovieItem(
    @SerializedName("id") val id: String?,
    @SerializedName("title") val title: String?,
    @SerializedName("pic") val pic: DoubanPic?,
    @SerializedName("rating") val rating: DoubanRating?,
    @SerializedName("card_subtitle") val cardSubtitle: String?,
)

data class DoubanPic(
    @SerializedName("normal") val normal: String?,
    @SerializedName("large") val large: String?,
)

data class DoubanRating(
    @SerializedName("value") val value: Double?,
)
```

### 2.3 OkHttpClient 配置

独立于后端 API，无需 Cookie 认证。和 `createDanmakuApi()` 类似，直连无代理。

## 3. 数据层设计

### 3.1 DoubanRepository (core-data)

```kotlin
class DoubanRepository(private val api: SeleneDoubanApi) {
    // 内存缓存: key = CacheKey(kind, category, type, region, year, platform, sort, page)
    private val cache = LruCache<CacheKey, List<TvVideoCard>>(maxSize = 50)

    suspend fun loadCategory(params: DoubanCategoryParams): List<TvVideoCard> {
        cache.get(params.toCacheKey())?.let { return it }

        val response = if (needsRecommendApi(params)) {
            api.getRecommends(...)
        } else {
            api.getCategoryData(...)
        }

        val videos = response.items.orEmpty().map { it.toVideoCard() }
        cache.put(params.toCacheKey(), videos)
        return videos
    }

    fun clearCache() { cache.evictAll() }
}
```

缓存 key 由筛选参数构成，当筛选条件变化时自动 miss 缓存并发起新请求。同一 session 内切回相同筛选条件时命中缓存，不重复请求。

### 3.2 数据转换

```kotlin
fun DoubanMovieItem.toVideoCard(): TvVideoCard {
    return TvVideoCard(
        id = id.orEmpty(),
        source = "douban",
        title = title.orEmpty(),
        year = cardSubtitle?.let { Regex("""(\d{4})""").find(it)?.value }.orEmpty(),
        posterUrl = pic?.normal ?: pic?.large.orEmpty(),
        // rate 可在后续迭代中传入 TvVideoCard
    )
}
```

### 3.3 TvVideoCard 扩展

增加 `doubanRate: String?` 字段存放豆瓣评分，用于海报卡片展示评分徽标。

## 4. 筛选选项对齐

### 4.1 新 TvLibraryFilter 定义

替换当前的硬编码筛选选项，对齐 Flutter TV `TvCategoryFilterOptions`：

**电影：**
| 筛选行 | 选项 |
|--------|------|
| 分类 | 全部、热门、最新、豆瓣高分、冷门佳片 |
| 类型 | 全部、剧情、喜剧、动作、科幻、悬疑、犯罪、惊悚、冒险、音乐、历史、奇幻、恐怖、战争、传记、歌舞、武侠、情色、灾难、西部、纪录片、短片 |
| 地区 | 全部、中国大陆、美国、中国香港、中国台湾、日本、韩国、英国、法国、德国、意大利、西班牙、印度、泰国、俄罗斯、加拿大、澳大利亚、爱尔兰、瑞典、巴西、丹麦 |
| 年代 | 全部、2026、2025、2024、2023、2022、2021、2010年代、2000年代、1990年代、1980年代、1970年代、更早 |
| 平台 | 全部、腾讯、爱奇艺、优酷、芒果TV、Netflix、HBO、BBC、NHK、CBS、NBC、TVN |
| 排序 | 综合、热度、时间、评价 |

**剧集、动漫、综艺：** 各自有独立的分类和类型选项，详见 Flutter `TvCategoryFilterOptions._seriesRows()` / `_animeRows()` / `_varietyRows()`。

### 4.2 筛选到 API 参数映射

```
电影:
  分类="热门"  → getCategoryData(kind="movie", category="热门", type=地区值)
  分类="最新"  → fetchDoubanRecommends(kind="movie", sort="R", ...)
  分类="豆瓣高分" → fetchDoubanRecommends(kind="movie", sort="S", ...)
  分类="全部"  → fetchDoubanRecommends(kind="movie", tags=类型+地区+年代+平台, sort=排序)
  分类="冷门佳片" → fetchDoubanRecommends(kind="movie", sort="S", score_range="7,8", ...)
```

## 5. ViewModel 改造

### 5.1 TvVideoLibraryViewModel

```kotlin
class TvVideoLibraryViewModel(
    categoryKey: String,
    private val loadCategory: suspend (categoryKey: String, filters: List<TvLibraryFilter>) -> List<TvVideoCard>,
)
```

- `load()` → 读取当前 filters，调用 `loadCategory(categoryKey, filters)`
- `applyFilter(filterKey, optionKey)` → 更新 filters state，触发 `load()`
- 首次加载使用默认筛选（分类=热门，其余=全部）

### 5.2 ViewModel 存活

`TvNavGraph` 中 `remember(categoryKey, appContainer)` 已保证同 category 不重建 ViewModel。加上 `DoubanRepository` 的内存缓存，二次进入零网络请求。

## 6. 设置页改造

### 6.1 TvPreferencesStore 扩展

新增字段和 accessor：

| 字段 | 类型 | 存储 Key | getter | setter |
|------|------|---------|--------|--------|
| themeKey | String | `pref_theme` | `getThemeKey()` | `saveThemeKey()` |
| backgroundKey | String | `pref_background` | `getBackgroundKey()` | `saveBackgroundKey()` |
| focusEffectKey | String | `pref_focus_effect` | `getFocusEffectKey()` | `saveFocusEffectKey()` |
| adFilterEnabled | Boolean | `pref_ad_filter` | `getAdFilterEnabled()` | `saveAdFilterEnabled()` |
| imageSource | String | `pref_image_source` | `getImageSource()` | `saveImageSource()` |
| danmakuEnabled | Boolean | `pref_danmaku_enabled` | `getDanmakuEnabled()` | `saveDanmakuEnabled()` |
| danmakuOpacity | Float | `pref_danmaku_opacity` | `getDanmakuOpacity()` | `saveDanmakuOpacity()` |
| danmakuFontSize | Float | `pref_danmaku_font_size` | `getDanmakuFontSize()` | `saveDanmakuFontSize()` |
| serverUrl | String | `pref_server_url` | `getServerUrl()` | `saveServerUrl()` |
| account | String | `pref_account` | `getAccount()` | `saveAccount()` |
| password | String | `pref_password` | `getPassword()` | `savePassword()` |

### 6.2 TvSettingsViewModel 改造

- 初始化时从 `TvPreferencesStore` 加载所有持久化值
- 每个 switch/chip 变更时调用对应 `save*` 方法
- 服务器配置保存后回调 `TvAppContainer` 触发重新登录
- 删除 `playerKernel` 相关 state 和 UI

### 6.3 缓存管理

通过 `Coil.imageLoader(context).diskCache?.size` 获取磁盘缓存大小，通过 `Coil.imageLoader(context).diskCache?.clear()` + `DoubanRepository.clearCache()` 清理。

### 6.4 删除播放内核切换

从 `TvSettingsRoute` 的 UI 中删除 `TvPlayerKernel` chip option row。从 `TvSettingsViewModel` 中删除相关 state。

## 7. 启动清理

在 `TvApp.kt` 中添加：

```kotlin
LaunchedEffect(Unit) {
    withContext(Dispatchers.IO) {
        context.imageLoader.diskCache?.clear()
    }
}
```

## 8. Di 改造 (TvAppContainer)

```kotlin
// 新增
private val doubanApi: SeleneDoubanApi by lazy {
    SeleneTvNetworkFactory.createDoubanApi()
}
private val doubanRepository: DoubanRepository by lazy {
    DoubanRepository(api = doubanApi)
}

// 修改
fun createVideoLibraryViewModel(categoryKey: String): TvVideoLibraryViewModel {
    return TvVideoLibraryViewModel(
        categoryKey = categoryKey,
        loadCategory = { key, filters ->
            doubanRepository.loadCategory(
                DoubanCategoryParams.from(key, filters)
            )
        }
    )
}
```

## 9. 文件变更清单

| 模块 | 文件 | 操作 |
|------|------|------|
| core-network | `SeleneDoubanApi.kt` | **新增** |
| core-network | `DoubanCategoryResponse.kt` | **新增** |
| core-network | `SeleneTvNetworkClient.kt` | 修改（加 `createDoubanApi()`） |
| core-data | `TvVideoCard.kt` | 修改（加 `doubanRate` 字段） |
| core-data | `DoubanRepository.kt` | **新增** |
| core-data | `DoubanCategoryParams.kt` | **新增** |
| core-data | `TvPreferencesStore.kt` | 修改（扩展持久化字段） |
| feature-tv-home | `TvHomeViewModel.kt` | 修改（筛选选项 + ViewModel） |
| feature-tv-home | `TvHomeRoute.kt` | 修改（筛选 UI） |
| feature-tv-settings | `TvSettingsViewModel.kt` | 修改（持久化 + 删播放内核） |
| feature-tv-settings | `TvSettingsRoute.kt` | 修改（删播放内核 UI + 加缓存管理） |
| app-tv | `TvApp.kt` | 修改（启动清缓存） |
| app-tv | `TvAppContainer.kt` | 修改（Douban 依赖注入） |
