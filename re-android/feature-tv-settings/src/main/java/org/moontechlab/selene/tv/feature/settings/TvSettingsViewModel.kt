package org.moontechlab.selene.tv.feature.settings

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.network.TvMobileSettingsBridge
import org.moontechlab.selene.tv.core.network.TvMobileSettingsBridgeSession
import org.moontechlab.selene.tv.core.network.TvMobileSettingsDraft

/**
 * TV 设置界面状态。
 *
 * @property serverUrl 服务器地址。
 * @property account 账号。
 * @property password 密码。
 * @property themeKey 主题色标识。
 * @property backgroundKey 背景色标识。
 * @property focusEffectKey 焦点效果标识。
 * @property imageSourceKey 图片代理标识。
 * @property playerKernelKey 播放器内核标识。
 * @property adFilterEnabled 是否自动去广告。
 * @property danmakuApi 弹幕 API。
 * @property danmakuEnabled 是否开启弹幕。
 * @property danmakuOpacity 弹幕不透明度。
 * @property danmakuFontScale 弹幕字号比例。
 * @property danmakuDisplayArea 弹幕显示区域比例。
 * @property danmakuPreventOverlap 弹幕防重叠。
 * @property danmakuSyncVideoSpeed 弹幕是否同步播放倍速。
 * @property cacheSizeText 缓存体积展示文本。
 * @property qrData 二维码内容 URL。
 * @property qrShareAddress 扫码地址展示文案。
 * @property qrStatusText 二维码状态说明。
 * @property regeneratingQr 是否正在重新生成二维码。
 * @property savingServerConfig 是否正在保存服务器配置。
 * @property savingDanmaku 是否正在保存弹幕配置。
 * @property clearingCache 是否正在清理缓存。
 * @property noticeText 页内提示文案。
 * @property noticeVisible 是否展示页内提示。
 */
data class TvSettingsUiState(
    val serverUrl: String = "",
    val account: String = "",
    val password: String = "",
    val themeKey: String = "netflix_red",
    val backgroundKey: String = "deep_blue",
    val focusEffectKey: String = "magnifier",
    val imageSourceKey: String = "直连",
    // 设置页不再暴露内核选择；默认 Exo。
    val playerKernelKey: String = "exo",
    val adFilterEnabled: Boolean = true,
    val danmakuApi: String = "",
    val danmakuEnabled: Boolean = true,
    val danmakuOpacity: Float = 0.8f,
    val danmakuFontScale: Float = 1.0f,
    val danmakuDisplayArea: Float = 1.0f,
    val danmakuPreventOverlap: Boolean = true,
    val danmakuSyncVideoSpeed: Boolean = false,
    val cacheSizeText: String = "计算中...",
    val qrData: String? = null,
    val qrShareAddress: String? = null,
    val qrStatusText: String = "正在准备手机扫码配置…",
    val regeneratingQr: Boolean = false,
    val savingServerConfig: Boolean = false,
    val savingDanmaku: Boolean = false,
    val clearingCache: Boolean = false,
    val noticeText: String = "",
    val noticeVisible: Boolean = false,
)

/**
 * TV 设置 ViewModel。
 *
 * 负责表单状态、持久化回调，以及手机扫码桥接会话生命周期。
 *
 * @property initialState 初始界面状态。
 * @property saveServerConfig 保存服务器配置。
 * @property saveDanmaku 保存弹幕配置。
 * @property clearCache 清理缓存。
 * @property loadCacheSize 读取缓存体积文案。
 * @property saveDanmakuEnabled 保存弹幕开关。
 * @property saveDanmakuOpacity 保存弹幕不透明度。
 * @property saveDanmakuFontScale 保存弹幕字号。
 * @property saveDanmakuDisplayArea 保存弹幕显示区域。
 * @property saveDanmakuPreventOverlap 保存防重叠。
 * @property saveDanmakuSyncVideoSpeed 保存速度同步。
 * @property saveAdFilter 保存自动去广告。
 * @property saveImageSource 保存图片代理。
 * @property saveTheme 保存主题色。
 * @property saveBackground 保存背景色。
 * @property saveFocusEffect 保存焦点效果。
 * @property savePlayerKernel 保存播放内核，返回真实生效内核。
 * @property startMobileBridge 启动手机扫码桥接；单测可注入假实现。
 */
class TvSettingsViewModel(
    initialState: TvSettingsUiState = TvSettingsUiState(),
    private val saveServerConfig: suspend (String, String, String) -> Unit = { _, _, _ -> },
    private val saveDanmakuApi: suspend (String) -> Unit = {},
    private val clearCache: suspend () -> Unit = {},
    private val loadCacheSize: suspend () -> String = { "0 MB" },
    private val saveDanmakuEnabled: suspend (Boolean) -> Unit = {},
    private val saveDanmakuOpacity: suspend (Float) -> Unit = {},
    private val saveDanmakuFontScale: suspend (Float) -> Unit = {},
    private val saveDanmakuDisplayArea: suspend (Float) -> Unit = {},
    private val saveDanmakuPreventOverlap: suspend (Boolean) -> Unit = {},
    private val saveDanmakuSyncVideoSpeed: suspend (Boolean) -> Unit = {},
    private val saveAdFilter: suspend (Boolean) -> Unit = {},
    private val saveImageSource: suspend (String) -> Unit = {},
    private val saveTheme: suspend (String) -> Unit = {},
    private val saveBackground: suspend (String) -> Unit = {},
    private val saveFocusEffect: suspend (String) -> Unit = {},
    private val savePlayerKernel: suspend (String) -> String = { it },
    private val startMobileBridge: suspend (
        draft: TvMobileSettingsDraft,
        allocateNewPort: Boolean,
        onSubmitted: (TvMobileSettingsDraft) -> Unit,
    ) -> TvMobileSettingsBridgeSession = { draft, allocateNewPort, onSubmitted ->
        TvMobileSettingsBridge.startSession(
            initialDraft = draft,
            onDraftSubmitted = onSubmitted,
            allocateNewPort = allocateNewPort,
        )
    },
) {
    /** 设置页协程作用域。 */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** 可变状态。 */
    private val mutableState = MutableStateFlow(initialState)

    /** 对外只读状态。 */
    val state: StateFlow<TvSettingsUiState> = mutableState

    /** 当前手机扫码会话。 */
    private var bridgeSession: TvMobileSettingsBridgeSession? = null

    init {
        // 进入设置页后刷新缓存体积，并启动手机扫码桥接。
        refreshCacheSize()
        startMobileConfigBridge(allocateNewPort = false)
    }

    // ── 服务器 ──

    /**
     * 更新服务器地址。
     *
     * @param url 新地址。
     */
    fun updateServerUrl(url: String) {
        mutableState.value = mutableState.value.copy(serverUrl = url)
        syncMobileConfigDraft()
    }

    /**
     * 更新账号。
     *
     * @param account 新账号。
     */
    fun updateAccount(account: String) {
        mutableState.value = mutableState.value.copy(account = account)
        syncMobileConfigDraft()
    }

    /**
     * 更新密码。
     *
     * @param password 新密码。
     */
    fun updatePassword(password: String) {
        mutableState.value = mutableState.value.copy(password = password)
        syncMobileConfigDraft()
    }

    /**
     * 保存服务器配置。
     */
    suspend fun performSaveServerConfig() {
        mutableState.value = mutableState.value.copy(savingServerConfig = true)
        val current = mutableState.value
        saveServerConfig(current.serverUrl, current.account, current.password)
        mutableState.value = mutableState.value.copy(savingServerConfig = false)
        showNotice("服务器配置已保存")
    }

    // ── 外观 ──

    /**
     * 更新主题色。
     *
     * @param key 主题标识。
     */
    fun updateThemeKey(key: String) {
        mutableState.value = mutableState.value.copy(themeKey = key)
    }

    /**
     * 更新背景色。
     *
     * @param key 背景标识。
     */
    fun updateBackgroundKey(key: String) {
        mutableState.value = mutableState.value.copy(backgroundKey = key)
    }

    /**
     * 更新焦点效果。
     *
     * @param key 效果标识。
     */
    fun updateFocusEffectKey(key: String) {
        mutableState.value = mutableState.value.copy(focusEffectKey = key)
    }

    /**
     * 更新图片代理。
     *
     * @param key 代理标识。
     */
    fun updateImageSourceKey(key: String) {
        mutableState.value = mutableState.value.copy(imageSourceKey = key)
        syncMobileConfigDraft()
    }

    /**
     * 持久化主题色。
     */
    suspend fun performSaveTheme() {
        saveTheme(mutableState.value.themeKey)
        showNotice("主题色已更新")
    }

    /**
     * 持久化背景色。
     */
    suspend fun performSaveBackground() {
        saveBackground(mutableState.value.backgroundKey)
        showNotice("背景色已更新")
    }

    /**
     * 持久化焦点效果。
     */
    suspend fun performSaveFocusEffect() {
        saveFocusEffect(mutableState.value.focusEffectKey)
        showNotice("焦点效果已更新")
    }

    /**
     * 持久化图片代理。
     */
    suspend fun performSaveImageSource() {
        saveImageSource(mutableState.value.imageSourceKey)
        showNotice("图片代理已更新")
    }

    // ── 播放 ──

    /**
     * 更新播放器内核选择。
     *
     * @param key 内核标识。
     */
    fun updatePlayerKernelKey(key: String) {
        mutableState.value = mutableState.value.copy(playerKernelKey = key)
    }

    /**
     * 更新自动去广告开关。
     *
     * @param enabled 是否开启。
     */
    fun updateAdFilterEnabled(enabled: Boolean) {
        mutableState.value = mutableState.value.copy(adFilterEnabled = enabled)
        syncMobileConfigDraft()
        scope.launch {
            saveAdFilter(enabled)
            showNotice(if (enabled) "已开启自动去广告" else "已关闭自动去广告")
        }
    }

    /**
     * 持久化播放器内核，并把真实生效内核回灌到 UI。
     */
    suspend fun performSavePlayerKernel() {
        val requested = mutableState.value.playerKernelKey
        // 高风险环境下真实运行内核被强制收口后，立即把结果反馈给设置页。
        val effective = savePlayerKernel(requested)
        mutableState.value = mutableState.value.copy(playerKernelKey = effective)
        showNotice(
            if (effective == requested) {
                "播放器内核已切换为 $effective"
            } else {
                "当前环境实际生效内核：$effective"
            },
        )
    }

    // ── 弹幕 ──

    /**
     * 更新弹幕 API。
     *
     * @param api 新地址。
     */
    fun updateDanmakuApi(api: String) {
        mutableState.value = mutableState.value.copy(danmakuApi = api)
        syncMobileConfigDraft()
    }

    /**
     * 更新弹幕开关。
     *
     * @param enabled 是否开启。
     */
    fun updateDanmakuEnabled(enabled: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuEnabled = enabled)
    }

    /**
     * 更新弹幕不透明度。
     *
     * @param opacity 0..1。
     */
    fun updateDanmakuOpacity(opacity: Float) {
        mutableState.value = mutableState.value.copy(danmakuOpacity = opacity.coerceIn(0f, 1f))
    }

    /**
     * 更新弹幕字号比例。
     *
     * @param scale 比例。
     */
    fun updateDanmakuFontScale(scale: Float) {
        mutableState.value = mutableState.value.copy(danmakuFontScale = scale.coerceAtLeast(0.5f))
    }

    /**
     * 更新弹幕显示区域。
     *
     * @param area 0.25..1.0。
     */
    fun updateDanmakuDisplayArea(area: Float) {
        mutableState.value = mutableState.value.copy(danmakuDisplayArea = area.coerceIn(0.25f, 1f))
    }

    /**
     * 更新弹幕防重叠。
     *
     * @param prevent 是否防重叠。
     */
    fun updateDanmakuPreventOverlap(prevent: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuPreventOverlap = prevent)
    }

    /**
     * 更新弹幕速度同步。
     *
     * @param sync 是否同步。
     */
    fun updateDanmakuSyncVideoSpeed(sync: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuSyncVideoSpeed = sync)
    }

    /**
     * 保存弹幕相关设置。
     */
    suspend fun performSaveDanmaku() {
        mutableState.value = mutableState.value.copy(savingDanmaku = true)
        val current = mutableState.value
        saveDanmakuApi(current.danmakuApi)
        saveDanmakuEnabled(current.danmakuEnabled)
        saveDanmakuOpacity(current.danmakuOpacity)
        saveDanmakuFontScale(current.danmakuFontScale)
        saveDanmakuDisplayArea(current.danmakuDisplayArea)
        saveDanmakuPreventOverlap(current.danmakuPreventOverlap)
        saveDanmakuSyncVideoSpeed(current.danmakuSyncVideoSpeed)
        mutableState.value = mutableState.value.copy(savingDanmaku = false)
        showNotice("弹幕设置已保存")
    }

    // ── 缓存 ──

    /**
     * 刷新缓存体积展示。
     */
    fun refreshCacheSize() {
        scope.launch {
            val sizeText = runCatching { loadCacheSize() }.getOrDefault("未知")
            mutableState.value = mutableState.value.copy(cacheSizeText = sizeText)
        }
    }

    /**
     * 清理缓存。
     */
    suspend fun performClearCache() {
        mutableState.value = mutableState.value.copy(clearingCache = true)
        clearCache()
        mutableState.value = mutableState.value.copy(
            clearingCache = false,
            cacheSizeText = "0 MB",
        )
        showNotice("缓存已清理")
    }

    // ── 二维码桥接 ──

    /**
     * 启动手机扫码配置桥接。
     *
     * @param allocateNewPort 是否强制换新端口。
     */
    fun startMobileConfigBridge(allocateNewPort: Boolean) {
        scope.launch {
            mutableState.value = mutableState.value.copy(regeneratingQr = allocateNewPort)
            val previous = bridgeSession
            bridgeSession = null
            previous?.dispose?.invoke()

            val session = runCatching {
                startMobileBridge(
                    buildMobileSettingsDraft(),
                    allocateNewPort,
                ) { draft ->
                    // 手机提交后回填 TV 表单，用户再确认保存。
                    applyMobileSettingsDraft(draft)
                }
            }.getOrElse {
                TvMobileSettingsBridgeSession(
                    shareUri = null,
                    statusText = "手机扫码服务启动失败：${it.message ?: "未知错误"}",
                    updateDraft = {},
                    dispose = {},
                )
            }
            bridgeSession = session
            mutableState.value = mutableState.value.copy(
                qrData = session.shareUri,
                qrShareAddress = session.shareUri,
                qrStatusText = session.statusText,
                regeneratingQr = false,
            )
        }
    }

    /**
     * 重新生成二维码会话。
     */
    fun regenerateQrCode() {
        startMobileConfigBridge(allocateNewPort = true)
    }

    /**
     * 把 TV 当前草稿同步给手机网页。
     */
    private fun syncMobileConfigDraft() {
        bridgeSession?.updateDraft?.invoke(buildMobileSettingsDraft())
    }

    /**
     * 构建手机扫码草稿。
     *
     * @return 当前表单草稿。
     */
    private fun buildMobileSettingsDraft(): TvMobileSettingsDraft {
        val current = mutableState.value
        return TvMobileSettingsDraft(
            serverUrl = current.serverUrl,
            username = current.account,
            password = current.password,
            doubanImageSource = mapImageSourceToDisplay(current.imageSourceKey),
            adFilterEnabled = current.adFilterEnabled,
            danmakuBaseApi = current.danmakuApi,
        )
    }

    /**
     * 应用手机提交的草稿到 TV 表单。
     *
     * @param draft 手机端草稿。
     */
    private fun applyMobileSettingsDraft(draft: TvMobileSettingsDraft) {
        mutableState.value = mutableState.value.copy(
            serverUrl = draft.serverUrl,
            account = draft.username,
            password = draft.password,
            imageSourceKey = mapDisplayToImageSourceKey(draft.doubanImageSource),
            adFilterEnabled = draft.adFilterEnabled,
            danmakuApi = draft.danmakuBaseApi,
            qrStatusText = TvMobileSettingsBridge.APPLIED_STATUS,
        )
        showNotice("已从手机接收配置，请确认后保存")
    }

    /**
     * 设置内部 key 映射为手机端显示名。
     *
     * @param key 内部标识。
     * @return 显示名。
     */
    private fun mapImageSourceToDisplay(key: String): String {
        return when (key) {
            "direct", "直连" -> "直连"
            "tencent_cdn" -> "豆瓣 CDN By CMLiussss（腾讯云）"
            "alibaba_cdn" -> "豆瓣 CDN By CMLiussss（阿里云）"
            "official_cdn", "豆瓣官方精品 CDN" -> "豆瓣官方精品 CDN"
            else -> if (key in TvMobileSettingsDraft.availableDoubanImageSources) {
                key
            } else {
                "直连"
            }
        }
    }

    /**
     * 手机端显示名映射回设置页内部 key。
     *
     * @param display 显示名。
     * @return 内部标识。
     */
    private fun mapDisplayToImageSourceKey(display: String): String {
        return when (display) {
            "直连" -> "direct"
            "豆瓣 CDN By CMLiussss（腾讯云）" -> "tencent_cdn"
            "豆瓣 CDN By CMLiussss（阿里云）" -> "alibaba_cdn"
            "豆瓣官方精品 CDN" -> "official_cdn"
            else -> display
        }
    }

    // ── 通知 ──

    /**
     * 展示页内提示。
     *
     * @param text 提示文案。
     */
    fun showNotice(text: String) {
        mutableState.value = mutableState.value.copy(noticeText = text, noticeVisible = true)
    }

    /**
     * 关闭页内提示。
     */
    fun dismissNotice() {
        mutableState.value = mutableState.value.copy(noticeVisible = false)
    }

    /**
     * 释放扫码桥接会话。
     */
    fun dispose() {
        scope.launch {
            bridgeSession?.dispose?.invoke()
            bridgeSession = null
        }
    }
}
