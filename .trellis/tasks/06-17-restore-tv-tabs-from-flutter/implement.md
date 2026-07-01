# 执行计划：从 Flutter TV 端 1:1 还原非首页 Tab

## 编号策略

所有步骤按依赖顺序排列。`[P]` 标记表示可并行执行。

## Step 1: Douban 网络层 [core-network]

### 1.1 创建 Douban 响应模型
**文件:** `core-network/.../network/model/DoubanResponse.kt` (新增)

- `DoubanCategoryResponse` — `items: List<DoubanMovieItem>?`
- `DoubanMovieItem` — `id, title, pic, rating, card_subtitle`
- `DoubanPic` — `normal, large`
- `DoubanRating` — `value: Double?`

**验证:** 编译通过

### 1.2 创建 SeleneDoubanApi
**文件:** `core-network/.../network/SeleneDoubanApi.kt` (新增)

- `getCategoryData(kind, start, limit, category, type)` → 调用 `/rexxar/api/v2/subject/recent_hot/{kind}`
- `getRecommends(kind, refresh, start, count, selectedCategories, uncollect, scoreRange, tags, sort)` → 调用 `/rexxar/api/v2/{kind}/recommend`

**验证:** 编译通过

### 1.3 添加 Douban API 工厂方法
**文件:** `core-network/.../network/SeleneTvNetworkClient.kt` (修改)

- 在 `SeleneTvNetworkFactory` 添加 `createDoubanApi(): SeleneDoubanApi`
- Base URL: `https://m.douban.cmliussss.net/`
- Headers: `User-Agent` + `Referer` (和 Flutter 一致)
- 直连无代理 `Proxy.NO_PROXY`

**验证:** 编译通过

---

## Step 2: 数据层 [core-data]

### 2.1 扩展 TvVideoCard
**文件:** `core-data/.../model/TvVideoCard.kt` (修改)

- 添加 `doubanRate: String = ""`

**验证:** 编译通过，所有引用 `TvVideoCard` 的文件无编译错误

### 2.2 创建 DoubanCategoryParams
**文件:** `core-data/.../repository/DoubanCategoryParams.kt` (新增)

- `kind: String` — movie/tv/anime/show
- `category: String` — 分类值
- `type: String` — 类型筛选
- `region: String` — 地区
- `year: String` — 年代
- `platform: String` — 平台
- `sort: String` — 排序
- `page: Int` — 页码
- `toCacheKey(): String` — 生成缓存 key
- `companion object`: `from(categoryKey, filters)` 工厂方法
- 内部封装 "用 `getCategoryData` 还是 `getRecommends`" 的判断逻辑

**验证:** 编译通过

### 2.3 创建 DoubanRepository
**文件:** `core-data/.../repository/DoubanRepository.kt` (新增)

- 构造函数: `DoubanRepository(api: SeleneDoubanApi)`
- `suspend fun loadCategory(params: DoubanCategoryParams): List<TvVideoCard>`
- `fun clearCache()`
- 内部 `LruCache<String, List<TvVideoCard>>(maxSize=50)`
- `DoubanMovieItem.toVideoCard()` 转换函数

**验证:** 编译通过

### 2.4 扩展 TvPreferencesStore
**文件:** `core-data/.../storage/TvPreferencesStore.kt` (修改)

添加以下字段 + accessor:
- `themeKey: String` (default: `TvTokens.AccentKey`)
- `backgroundKey: String`
- `focusEffectKey: String`
- `adFilterEnabled: Boolean` (default: `true`)
- `imageSource: String` (default: `"直连"`)
- `danmakuEnabled: Boolean` (default: `true`)
- `danmakuOpacity: Float` (default: `0.8f`)
- `danmakuFontSize: Float` (default: `1.0f`)
- `serverUrl: String`
- `account: String`
- `password: String`

**验证:** 编译通过

---

## Step 3: 分类筛选页改造 [feature-tv-home]

### 3.1 替换筛选选项定义
**文件:** `feature-tv-home/.../TvHomeViewModel.kt` (修改)

- 将 `classOptionsFor()` 等方法替换为 Flutter 1:1 对齐的选项
- 每个分类的 filter rows 独立定义（电影/剧集/动漫/综艺各有不同的分类和类型选项）
- 地区、年代、平台、排序 共用

**验证:** `TvHomeSectionPresentationTest`、`TvHomeViewModelTest` 通过

### 3.2 改造 TvVideoLibraryViewModel
**文件:** `feature-tv-home/.../TvHomeViewModel.kt` (修改)

- 添加 `onFilterChanged(filterKey, optionKey)` 方法
- 筛选变更后调用 `load()` 重新拉取数据

**验证:** `TvHomeViewModelTest` 通过

### 3.3 筛选面板 UI 绑定
**文件:** `feature-tv-home/.../TvHomeRoute.kt` (修改)

- `TvLibraryFilterPanel` 的 `onOptionSelected` 回调连接到 ViewModel 的 `onFilterChanged`
- 筛选后触发 reload

**验证:** 运行 app 肉眼验证

---

## Step 4: 设置页改造 [feature-tv-settings] [P]

### 4.1 删除播放内核切换
**文件:** `feature-tv-settings/.../TvSettingsViewModel.kt` (修改)
**文件:** `feature-tv-settings/.../TvSettingsRoute.kt` (修改)

- 删除 `TvPlayerKernel` 相关 state 和 UI
- 删除对应的 focus group 和键盘导航

**验证:** 设置页不再显示播放内核选项

### 4.2 补齐持久化
**文件:** `feature-tv-settings/.../TvSettingsViewModel.kt` (修改)

- 初始化时从 `TvPreferencesStore` 读取所有字段
- 每个 switch/chip 变更时同步保存
- 添加 `resetToDefaults()` 方法

**验证:** 修改设置 → 重启 app → 设置保持

### 4.3 服务器配置可编辑
**文件:** `feature-tv-settings/.../TvSettingsViewModel.kt` (修改)
**文件:** `feature-tv-settings/.../TvSettingsRoute.kt` (修改)

- 服务器地址/账号/密码 TextField 可编辑（当前是只读）
- 保存按钮写入 `TvPreferencesStore`
- 保存后触发 `onServerConfigChanged` 回调

### 4.4 缓存管理
**文件:** `feature-tv-settings/.../TvSettingsViewModel.kt` (修改)

- `loadCacheSize()` → 读 Coil diskCache size + Coil memoryCache size
- `clearAllCaches()` → 清除 Coil disk + memory + DoubanRepository

---

## Step 5: App 层改造 [app-tv] [P]

### 5.1 依赖注入 Douban
**文件:** `app-tv/.../TvAppContainer.kt` (修改)

- 新增 `doubanApi` + `doubanRepository` lazy 字段
- 在 `createVideoLibraryViewModel()` 中注入 Douban 而非 Search API
- 在 `createSettingsViewModel()` 中传入 `preferencesStore` + 回调

### 5.2 启动清缓存
**文件:** `app-tv/.../TvApp.kt` (修改)

- `LaunchedEffect(Unit)` → `withContext(Dispatchers.IO)` → clear Coil disk cache

### 5.3 NavGraph 设置页回调
**文件:** `app-tv/.../navigation/TvNavGraph.kt` (修改)

- 设置页服务器配置保存后触发 `appContainer` 重新登录

---

## Step 6: 测试

### 6.1 单元测试
- `DoubanRepositoryTest` — 缓存命中/未命中/清空
- `TvPreferencesStoreTest` — 新字段读写
- `DoubanCategoryParamsTest` — 筛选参数映射

### 6.2 集成测试
- Category 筛选变更 → API 调用 → 列表更新
- 设置持久化 → 重启保持

---

## 执行顺序

```
Step 1.1 → Step 1.2 → Step 1.3    (网络层，串行)
                ↓
Step 2.1 + Step 2.2 + Step 2.4    (数据层，可并行)
                ↓
           Step 2.3                (依赖 2.1+2.2)
                ↓
     Step 3.1 → 3.2 → 3.3         (分类页，串行)
                ↓
Step 4.1 + Step 4.2 + 4.3 + 4.4   (设置页，可并行)
                ↓
     Step 5.1 + 5.2 + 5.3          (App 层，可并行)
                ↓
           Step 6                  (测试)
```

## 回滚点

- 每个 Step 完成后 commit 一次
- Step 2 完成后网络层已稳定，可独立验证
- Step 3 是核心改动，出问题可单独回滚到 Step 2
