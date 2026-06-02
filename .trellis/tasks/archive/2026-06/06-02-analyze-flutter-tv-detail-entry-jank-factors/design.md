# 设计说明

## Scope

本任务只做“进入详情页卡顿因素分析”，不直接进入实现修复。重点是为后续优化任务建立一个可执行的判断框架，而不是再次做泛泛的性能猜测。

分析边界：

1. `TvVideoDetailScreen` 进入时的异步启动链路
2. 详情页首进时的播放器初始化链路
3. WebView 路径在 2GB 电视端的资源压力
4. 页面首屏 UI、图片、焦点与推荐区对首段卡顿的叠加影响

## Known Flow

### 1. 详情页进入时的异步任务

- `initState()` 即刻启动：
  - 续播记录读取
  - M3U8 代理预热
  - 收藏态读取
  - 广告偏好读取
- 续播记录处理完成后才触发 `_startDetailLoading()`
- `_startDetailLoading()` 生产路径会并发拉：
  - 精确源
  - 后台补源

### 2. 首播链路

- 控制器挂载后，`_playCurrentEpisode()` 会调用 `controller.updateDataSource(url, startAt: startAt)`
- 对 WebView 路径而言，首进时如果播放器 adapter 还没建好，需要先初始化播放器
- 首播后，相关推荐延后加载，但首屏仍要承载相关 UI 容器
- 详情页会先通过 `_buildSharedPlayer()` 创建一个 `url: null` 的 `VideoPlayerWidget`，也就是播放器壳会先挂在树上，再等待首个可播源回填

### 3. WebView 路径

- 当前 TV 主链路不是纯 media_kit，而是 `WebViewPlayerAdapter`
- `WebViewPlayerAdapter` 底层使用 `InAppWebView`
- WebView 初始化不仅包含视图创建，还包含：
  - HTML 数据装载
  - JS 桥建立
  - 播放器 ready 事件监听
  - 页面内 seek / timeupdate / buffering 等事件回流
- `updateSource()` 不是轻量字段切换，而是再次 `loadData(_buildHtmlContent())`
- `_buildHtmlContent()` 本身承载了较多脚本：`hls.js`、debug bridge、rate 诊断、seek recovery、warmup fetch、buffering 抑制等

这意味着它可能同时在内存、CPU、主线程调度和首个可播 ready 时间上施压。

### 4. 状态波动密度

- `_loadResumeRecordThenStartDetailLoading()` 结束前，详情页不会真正进入源加载
- `_mergeSources()` 命中首个可播源会 `setState()` 并立即安排 `_playCurrentEpisode()`
- `_markInitialSourcesLoaded()` / `_markMoreSourcesLoaded()` 会继续刷新 loading 态
- `VideoPlayerWidget` 在 `ready / durationchange / buffering / playing` 回流时还会更新自身状态

因此详情页进入早期存在一段“短时间内多次状态切换”的窗口，这对 2GB 设备更敏感。

## Analysis Strategy

### A. 先拆“关键链路”和“次要链路”

使用 performance playbook 的原则，把详情页进入瞬间拆成：

- 关键链路：
  - 入口基础 UI 可见
  - 首个可交互状态
  - 首个可播放状态
- 次要链路：
  - 全量补源
  - 推荐区
  - 收藏态补齐
  - 广告偏好
  - 代理配置补齐

如果某个次要链路还在阻塞关键链路，它就应该被列为高优先级嫌疑点。

### B. WebView 不单独背锅，按“四类成本”评估

分析 WebView 的时候，不只问“它重不重”，而要拆成：

1. 视图初始化成本
2. 页面脚本与播放器 boot 成本
3. 内存占用与 GC 压力
4. 与页面其它异步任务叠加时的放大效应

这样可以避免把所有卡顿都粗暴归因给 WebView。

补充一个实际判断原则：

- 如果某项成本只在模拟器上轻微可见、但在 2GB 真机上明显放大，它更可能是“中等 CPU/内存成本 + 时序叠加”问题，而不是单点逻辑 bug。
- 当前详情页更符合这个特征，因此设计上应优先做“关键链路瘦身”和“状态波动收敛”，再考虑更重的底层替换。

### C. 对照已有 2GB 低内存任务，找证据闭环

之前的归档任务已经提出几个强嫌疑：

- setState 风暴
- 图片解码
- 推荐区过早参与
- WebView 首屏初始化重

这次分析要做的是把这些嫌疑重新按“进入详情页那一下”的实际链路排序，而不是重复罗列。

## Expected Output Shape

本任务最终应输出三类结论：

1. **主因排序**
   - 例如：WebView 初始化 > 并行补源回调 > 推荐区图片
2. **可直接优化项**
   - 例如：延后某段初始化、拆等待链、缩减首屏 UI 工作量
3. **仍需真机验证项**
   - 例如：某些 WebView/系统 WebView 版本差异，只靠代码阅读无法定论

## Analysis Summary 2026-06-02

### 结论框架

1. `WebView + loadData(HTML/JS)` 是最重共因
2. 续播记录门闩 + 多异步回调 + 多次 `setState` 是第二层放大器
3. 详情页较重的 UI / 焦点树让前两者体感更明显
4. 图片与推荐区已经后移，不再是首嫌疑

### 对后续优化任务的启发

- 第一优先级不是“重写全部播放器”，而是把详情页进入时真正必须完成的动作压到最少
- 第二优先级是减少 WebView 首建时一次性装载的内容
- 第三优先级是降低首几秒内页面和播放器之间的状态回流密度

## Risk Notes

- 如果只看代码不结合现有测试和历史任务，很容易重复已有结论。
- 如果只盯 WebView，会漏掉“多个中等成本叠加成卡顿”的可能性。
- 如果把“进入详情页卡顿”和“进入全屏卡顿”混在一起，结论会失焦。
