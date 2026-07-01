# 从 Flutter TV 端 1:1 还原非首页 Tab 页面到 Kotlin TV

## Goal

让 Kotlin TV 端的电影/剧集/动漫/综艺分类页、直播页、设置页的功能和体验与 Flutter TV 端一致，补齐真实数据加载、筛选交互、会话级缓存和设置持久化。

## 决议记录

| # | 决策 | 结论 |
|---|------|------|
| D1 | 分类页数据源 | 走豆瓣代理 API（`m.douban.cmliussss.net`），不走本地后台 |
| D2 | 设置页服务器配置 | 可编辑（用户可修改服务器地址/账号/密码，保存后重新登录） |
| D3 | 设置页播放内核 | 删除 WebView/Exo 切换，固定 Exo |
| D4 | 缓存策略 | 会话级内存缓存（API 响应 + 图片）；切换 tab 命中缓存不重复请求；app 启动时清 Coil 磁盘缓存 |

## 现状分析

| 页面 | Flutter TV | Kotlin TV 当前状态 |
|------|-----------|-------------------|
| 电影 | `DoubanService.getCategoryData` + `fetchDoubanRecommends`，筛选联动 | `api.search("电影")`，筛选只是 UI |
| 剧集 | 同上 | `api.search("剧集")`，同上 |
| 动漫 | 同上 | `api.search("动漫")`，同上 |
| 综艺 | 同上 | `api.search("综艺")`，同上 |
| 直播 | 占位页（"正在开发"） | 占位页 |
| 设置 | 完整持久化 + 缓存管理 | BuildConfig 只读，开关无持久化，缓存 "0 MB" 占位 |

## 架构决策

- **分类数据源**：直接调 Douban 代理 API，新增 `SeleneDoubanApi` + `DoubanRepository`
- **缓存层**：`DoubanRepository` 内部维护 `LruCache` 风格的内存缓存，key 由 `(kind, category, type, region, year, platform, sort, page)` 组成
- **Tab 切换优化**：ViewModel 存活策略改为 `remember(appContainer, categoryKey)` 保证同分类不重建，加上缓存后二次进入页面零网络请求
- **图片缓���**：app 启动时主动清一次 Coil `ImageLoader` 磁盘缓存
- **设置存储**：扩展 `TvPreferencesStore` 覆盖所有持久化字段
- **服务器配置**：设置页修改后保存到 `TvPreferencesStore`，触发 `TvAppContainer` 重新登录

## Requirements

### R1: 分类筛选页（电影/剧集/动漫/综艺）

1. 数据源改走 Douban 代理 API（`m.douban.cmliussss.net`）
2. 筛选项 1:1 对齐 Flutter TV `TvCategoryFilterOptions`
3. 筛选变更触发 API 刷新（带缓存：同参数命中缓存直接返回）
4. 分页加载（pageSize=25）
5. **缓存**：同一 session 内切换 tab 不重复请求

### R2: 直播页

保持占位状态，无需改动。

### R3: 设置页

1. **删除** WebView/Exo 播放内核切换
2. **服务器配置可编辑**：地址/账号/密码修改保存后触发重新登录
3. **补齐持久化**：主题色/背景色/焦点效果/去广告/图片代理/弹幕设置全部存入 `TvPreferencesStore`
4. **缓存管理**：真实计算缓存大小 + 一键清理
5. **启动清缓存**：app 进入时清 Coil 磁盘缓存

### R4: Douban 网络层 + 缓存

1. `SeleneDoubanApi` — Retrofit 接口
2. `DoubanRepository` — 封装分页/筛选 + 内存缓存
3. `DoubanMovie` — 豆瓣 API 响应模型

### R5: 启动清理

`TvApp` 启动时清 Coil `ImageLoader` 磁盘缓存

## Acceptance Criteria

- [ ] 电影/剧集/动漫/综艺分类页筛选变更触发 API 刷新，数据正确
- [ ] 同一 session 内切换 tab 不重复请求（缓存命中）
- [ ] 设置页不再展示播放内核切换
- [ ] 设置页开关和选项重启后保持
- [ ] 服务器配置修改后保存生效
- [ ] 缓存管理展示真实大小 + 可清理
- [ ] app 重启时 Coil 磁盘缓存被清除
- [ ] 直播页无变化

## Out of Scope

- 直播页真实数据（Flutter TV 也是占位）
- ExoPlayer 替换 WebView 的实际播放（播放器不变）
- 手机扫码配置（`TvMobileSettingsBridge`）
- 首页数据加载（另一个分支）