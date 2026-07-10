package org.moontechlab.selene.tv.feature.settings

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * TV 设置界面状态。
 */
data class TvSettingsUiState(
    // 服务器
    val serverUrl: String = "",
    val account: String = "",
    val password: String = "",
    val savingServerConfig: Boolean = false,
    // 外观 (key 对齐 Flutter)
    val themeKey: String = "netflix_red",
    val backgroundKey: String = "deep_blue",
    val focusEffectKey: String = "magnifier",
    val imageSourceKey: String = "direct",
    // 播放
    val adFilterEnabled: Boolean = true,
    val playerKernelKey: String = "webview",
    // 弹幕
    val danmakuApi: String = "",
    val danmakuEnabled: Boolean = true,
    val danmakuOpacity: Float = 0.8f,
    val danmakuFontScale: Float = 1.0f,
    val danmakuDisplayArea: Float = 1.0f,
    val danmakuPreventOverlap: Boolean = true,
    val danmakuSyncVideoSpeed: Boolean = false,
    val savingDanmaku: Boolean = false,
    // 缓存
    val cacheSizeText: String = "0 MB",
    val clearingCache: Boolean = false,
    // 二维码
    val qrData: String? = null,
    val qrStatusText: String = "手机配置暂不可用",
    // 通知
    val noticeText: String = "",
    val noticeVisible: Boolean = false,
)

/**
 * TV 设置 ViewModel。
 */
class TvSettingsViewModel(
    initialState: TvSettingsUiState = TvSettingsUiState(),
    private val loadCacheSize: suspend () -> String = { "0 MB" },
    private val clearCache: suspend () -> Unit = {},
    private val saveServerConfig: suspend (serverUrl: String, account: String, password: String) -> Unit = { _, _, _ -> },
    private val saveDanmakuApi: suspend (api: String) -> Unit = {},
    private val saveDanmakuEnabled: suspend (enabled: Boolean) -> Unit = {},
    private val saveDanmakuOpacity: suspend (opacity: Float) -> Unit = {},
    private val saveDanmakuFontScale: suspend (scale: Float) -> Unit = {},
    private val saveDanmakuDisplayArea: suspend (area: Float) -> Unit = {},
    private val saveDanmakuPreventOverlap: suspend (prevent: Boolean) -> Unit = {},
    private val saveDanmakuSyncVideoSpeed: suspend (sync: Boolean) -> Unit = {},
    private val saveAdFilter: suspend (enabled: Boolean) -> Unit = {},
    private val saveImageSource: suspend (source: String) -> Unit = {},
    private val saveTheme: suspend (themeKey: String) -> Unit = {},
    private val saveBackground: suspend (backgroundKey: String) -> Unit = {},
    private val saveFocusEffect: suspend (effectKey: String) -> Unit = {},
    private val savePlayerKernel: suspend (kernel: String) -> String = { it },
) {
    private val mutableState = MutableStateFlow(initialState)
    val state: StateFlow<TvSettingsUiState> = mutableState

    // ── 服务器 ──

    fun updateServerUrl(serverUrl: String) {
        mutableState.value = mutableState.value.copy(serverUrl = serverUrl)
    }

    fun updateAccount(account: String) {
        mutableState.value = mutableState.value.copy(account = account)
    }

    fun updatePassword(password: String) {
        mutableState.value = mutableState.value.copy(password = password)
    }

    suspend fun performSaveServerConfig() {
        val s = mutableState.value
        mutableState.value = s.copy(savingServerConfig = true)
        saveServerConfig(s.serverUrl, s.account, s.password)
        mutableState.value = s.copy(savingServerConfig = false)
        showNotice("服务器配置已保存")
    }

    // ── 外观 ──

    fun updateThemeKey(key: String) {
        mutableState.value = mutableState.value.copy(themeKey = key)
    }

    fun updateBackgroundKey(key: String) {
        mutableState.value = mutableState.value.copy(backgroundKey = key)
    }

    fun updateFocusEffectKey(key: String) {
        mutableState.value = mutableState.value.copy(focusEffectKey = key)
    }

    fun updateImageSourceKey(key: String) {
        mutableState.value = mutableState.value.copy(imageSourceKey = key)
    }

    suspend fun performSaveTheme() {
        saveTheme(mutableState.value.themeKey)
    }

    suspend fun performSaveBackground() {
        saveBackground(mutableState.value.backgroundKey)
    }

    suspend fun performSaveFocusEffect() {
        saveFocusEffect(mutableState.value.focusEffectKey)
    }

    suspend fun performSaveImageSource() {
        saveImageSource(mutableState.value.imageSourceKey)
    }

    // ── 播放 ──

    fun updateAdFilterEnabled(enabled: Boolean) {
        mutableState.value = mutableState.value.copy(adFilterEnabled = enabled)
    }

    fun updatePlayerKernelKey(key: String) {
        mutableState.value = mutableState.value.copy(playerKernelKey = key)
    }

    suspend fun performSaveAdFilter() {
        saveAdFilter(mutableState.value.adFilterEnabled)
    }

    suspend fun performSavePlayerKernel() {
        val requestedKernel = mutableState.value.playerKernelKey
        val effectiveKernel = savePlayerKernel(requestedKernel)
        mutableState.value = mutableState.value.copy(playerKernelKey = effectiveKernel)
        if (effectiveKernel != requestedKernel) {
            // 高风险环境下真实运行内核被强制收口后，立即把结果反馈给设置页，避免用户误以为仍在走 WebView。
            showNotice("当前环境下 WebView 可能黑屏，已自动切换为 ExoPlayer")
        }
    }

    // ── 弹幕 ──

    fun updateDanmakuApi(api: String) {
        mutableState.value = mutableState.value.copy(danmakuApi = api)
    }

    fun updateDanmakuEnabled(enabled: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuEnabled = enabled)
    }

    fun updateDanmakuOpacity(opacity: Float) {
        mutableState.value = mutableState.value.copy(danmakuOpacity = opacity)
    }

    fun updateDanmakuFontScale(scale: Float) {
        mutableState.value = mutableState.value.copy(danmakuFontScale = scale)
    }

    fun updateDanmakuDisplayArea(area: Float) {
        mutableState.value = mutableState.value.copy(danmakuDisplayArea = area)
    }

    fun updateDanmakuPreventOverlap(prevent: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuPreventOverlap = prevent)
    }

    fun updateDanmakuSyncVideoSpeed(sync: Boolean) {
        mutableState.value = mutableState.value.copy(danmakuSyncVideoSpeed = sync)
    }

    suspend fun performSaveDanmaku() {
        val s = mutableState.value
        mutableState.value = s.copy(savingDanmaku = true)
        saveDanmakuApi(s.danmakuApi)
        saveDanmakuEnabled(s.danmakuEnabled)
        saveDanmakuOpacity(s.danmakuOpacity)
        saveDanmakuFontScale(s.danmakuFontScale)
        saveDanmakuDisplayArea(s.danmakuDisplayArea)
        saveDanmakuPreventOverlap(s.danmakuPreventOverlap)
        saveDanmakuSyncVideoSpeed(s.danmakuSyncVideoSpeed)
        mutableState.value = mutableState.value.copy(savingDanmaku = false)
        showNotice("弹幕配置已保存")
    }

    // ── 缓存 ──

    suspend fun refreshCacheSize() {
        mutableState.value = mutableState.value.copy(cacheSizeText = loadCacheSize())
    }

    suspend fun performClearCache() {
        mutableState.value = mutableState.value.copy(clearingCache = true)
        clearCache()
        mutableState.value = mutableState.value.copy(
            clearingCache = false,
            cacheSizeText = "0 MB",
        )
        showNotice("缓存已清理")
    }

    // ── 通知 ──

    fun showNotice(text: String) {
        mutableState.value = mutableState.value.copy(noticeText = text, noticeVisible = true)
    }

    fun dismissNotice() {
        mutableState.value = mutableState.value.copy(noticeVisible = false)
    }
}
