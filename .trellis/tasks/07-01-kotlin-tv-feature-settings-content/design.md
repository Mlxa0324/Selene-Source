# 设计：Kotlin TV 设置与历史收藏直播

## Module Layout

```
kotlin-tv/feature/feature-settings/
├── TvSettingsRoute.kt            # 四分区 Compose UI
├── TvSettingsViewModel.kt         # 状态 + 动作（账号/图片弹幕/缓存/外观）
├── TvDanmakuMatchRoute.kt         # 手动匹配弹层 UI
├── TvDanmakuMatchViewModel.kt     # 搜索词微调 + 搜索 + 选集回调
├── mobilebridge/
│   ├── TvMobileSettingsDraft.kt          # 草稿数据类 + 表单编解码
│   ├── TvMobileSettingsBridgeServer.kt    # NanoHTTPD 服务实现
│   └── TvMobileSettingsBridgeSession.kt   # 会话生命周期（启动/重生成/关闭）

kotlin-tv/feature/feature-content/
├── TvVideoLibraryRoute.kt        # 历史/收藏共用纵向 Grid 列表 UI
├── TvHistoryRoute.kt              # 薄包装：标题+loadHistory+deleteHistoryItem+clearHistory
├── TvFavoritesRoute.kt            # 薄包装：标题+loadFavorites+deleteFavoriteItem+clearFavorites
└── TvLiveRoute.kt                 # 占位页
```

## Mobile Config Bridge (NanoHTTPD + ZXing)

```kotlin
class TvMobileSettingsBridgeServer(
    private val onDraftSubmitted: (TvMobileSettingsDraft) -> Unit,
    private var currentDraft: TvMobileSettingsDraft,
) : NanoHTTPD(0) {  // 0 = 由 start() 时指定端口
    override fun serve(session: IHTTPSession): Response {
        return when {
            session.method == Method.GET -> newFixedLengthResponse(renderFormHtml(currentDraft))
            session.method == Method.POST -> {
                val files = mutableMapOf<String, String>()
                session.parseBody(files)
                val submitted = TvMobileSettingsDraft.fromFormFields(session.parms)
                onDraftSubmitted(submitted)
                newFixedLengthResponse("已提交，请返回电视端确认保存")
            }
            else -> newFixedLengthResponse(Response.Status.METHOD_NOT_ALLOWED, MIME_PLAINTEXT, "")
        }
    }
}

class TvMobileSettingsBridgeSession private constructor(
    private val server: TvMobileSettingsBridgeServer,
    val shareUri: Uri?,
    val statusFlow: MutableStateFlow<BridgeStatus>,
) {
    companion object {
        const val INITIAL_PORT = 18321
        suspend fun start(
            initialDraft: TvMobileSettingsDraft,
            onDraftSubmitted: (TvMobileSettingsDraft) -> Unit,
            allocateNewPort: Boolean = false,
        ): TvMobileSettingsBridgeSession {
            // 探测可用端口：从 INITIAL_PORT（或递增）开始尝试 server.start()，
            // 端口被占用则 candidatePort++ 重试，直到绑定成功或达到重试上限。
        }
    }
    suspend fun regenerate(): TvMobileSettingsBridgeSession  // 关闭旧 server，端口 +1，重新 start
    fun dispose()  // server.stop()
}

enum class BridgeStatus { READY, APPLIED, UNAVAILABLE }
```

QR 生成使用 ZXing：

```kotlin
fun generateQrBitmap(content: String, sizePx: Int = 320): Bitmap {
    val bitMatrix = QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, sizePx, sizePx)
    // BitMatrix -> Bitmap 像素填充
}
```

网络地址解析：使用 `NetworkInterface.getNetworkInterfaces()` 遍历取局域网 IPv4 地址（对齐 Flutter `_resolveShareHost` 语义），非 loopback、非 IPv6，优先返回第一个可用地址。

## Settings ViewModel State

```kotlin
data class TvSettingsUiState(
    // 服务器配置
    val serverUrl: String = "",
    val username: String = "",
    val password: String = "",
    val savingAccount: Boolean = false,
    // 图片与弹幕
    val imageSourceKey: String = "direct",
    val adFilterEnabled: Boolean = true,
    val danmakuBaseApi: String = "",
    // 缓存
    val cacheSizeText: String = "计算中...",
    val clearingCache: Boolean = false,
    // 外观
    val themeKey: String = "ivy_green",
    // 手机扫码桥接
    val bridgeShareUri: Uri? = null,
    val bridgeStatus: BridgeStatus = BridgeStatus.UNAVAILABLE,
)
```

沿用 `re-android` `TvSettingsViewModel` 已有的分区状态划分（服务器/图片弹幕/缓存/外观四组独立字段 + 独立保存函数），新增手机扫码桥接部分。

## Video Library Shared Route

```kotlin
@Composable
fun TvVideoLibraryRoute(
    title: String,
    state: TvVideoLibraryUiState,
    onVideoClick: (TvVideoCard) -> Unit,
    onDeleteVideo: (TvVideoCard) -> Unit,
    onClearVideos: () -> Unit,
    contentFocusRequester: FocusRequester,
)

@Composable
fun TvHistoryRoute(...) = TvVideoLibraryRoute(title = "播放历史", ...)

@Composable
fun TvFavoritesRoute(...) = TvVideoLibraryRoute(title = "收藏夹", ...)
```

## Dependencies to Add

```toml
# gradle/libs.versions.toml 新增
nanohttpd = "2.3.1"
zxing-core = "3.5.3"

nanohttpd = { group = "org.nanohttpd", name = "nanohttpd", version.ref = "nanohttpd" }
zxing-core = { group = "com.google.zxing", name = "core", version.ref = "zxing-core" }
```

`feature-settings/build.gradle.kts` 引入以上两个依赖；其余模块不需要。

## Testing Strategy

- `TvSettingsViewModelTest`：覆盖四分区状态变更 + 保存动作。
- `TvMobileSettingsBridgeSessionTest`：覆盖端口探测重试、regenerate 关闭旧会话再起新会话、草稿编解码往返。
- `TvDanmakuMatchViewModelTest`：覆盖删字/清空/恢复/搜索/选集回调。
- `TvVideoLibraryViewModelTest`（历史/收藏共用逻辑）：覆盖 load/delete/clear 三类动作与列表同步。
- 焦点契约沿用 `06-24-govern-kotlin-tv-focus-navigation` 已确立的"历史、收藏、直播和设置页必须接收 contentFocusRequester，并在空态、加载态、列表态都有真实 focusable 目标"规则，用契约测试锁定。

## Rollback

- 手机扫码桥接是独立子模块（`mobilebridge/`），如果验证周期内跑不通，可先落地设置页其余三个分区，桥接分区展示"暂不可用"占位状态（复用 `BridgeStatus.UNAVAILABLE`），不阻塞整体验收。
