package org.moontechlab.selene.tv.core.data.storage

import android.content.Context

/**
 * TV 服务器配置。
 *
 * @property baseUrl 服务器地址。
 * @property account 账号。
 * @property password 密码。
 */
data class TvServerConfig(
    val baseUrl: String,
    val account: String,
    val password: String,
)

/**
 * TV 弹幕手动匹配记录。
 *
 * @property episodeId 弹幕服务剧集 ID。
 * @property searchKeyword 手动匹配时使用的搜索词。
 */
data class TvDanmakuManualMatchRecord(
    val episodeId: Int,
    val searchKeyword: String,
)

/**
 * TV 偏好存储。
 *
 * 关键播放配置优先落到 SharedPreferences，避免安装新包或进程重启后丢失；
 * 当没有 Android Context 时回退到内存实现，供 JVM 单测和纯源码契约测试复用。
 */
class TvPreferencesStore(
    private val appContext: Context? = null,
) {
    /** 持久化偏好句柄；纯 JVM 场景允许为空并退回内存值。 */
    private val sharedPreferences by lazy {
        appContext?.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    /** 当前服务器配置。 */
    private var serverConfig: TvServerConfig? = null

    /** 弹幕手动匹配记录表。 */
    private val danmakuManualMatches = mutableMapOf<String, TvDanmakuManualMatchRecord>()

    /** 同标题最近一次弹幕搜索词。 */
    private val danmakuTitleQueries = mutableMapOf<String, String>()

    /** 全屏播放器片头跳过秒数。 */
    private var skipIntroSeconds: Int = 0

    /** 全屏播放器片尾跳过剩余秒数。 */
    private var skipOutroSeconds: Int = 0

    /**
     * 保存服务器配置。
     *
     * @param baseUrl 服务器地址。
     * @param account 账号。
     * @param password 密码。
     */
    suspend fun saveServerConfig(
        baseUrl: String,
        account: String,
        password: String,
    ) {
        // 首期使用内存存储，替换为 DataStore 时保持同名契约。
        serverConfig = TvServerConfig(
            baseUrl = baseUrl,
            account = account,
            password = password,
        )
    }

    /**
     * 读取服务器配置。
     *
     * @return 当前服务器配置；未保存时返回 null。
     */
    suspend fun readServerConfig(): TvServerConfig? = serverConfig

    /**
     * 保存全屏播放器片头跳过秒数。
     *
     * @param seconds 片头跳过秒数。
     */
    suspend fun saveSkipIntroSeconds(seconds: Int) {
        // 秒数配置沿用 Flutter TV 的全局偏好语义，负数统一归零。
        skipIntroSeconds = seconds.coerceAtLeast(0)
    }

    /**
     * 读取全屏播放器片头跳过秒数。
     *
     * @return 当前片头跳过秒数。
     */
    suspend fun getSkipIntroSeconds(): Int = skipIntroSeconds

    /**
     * 保存全屏播放器片尾跳过剩余秒数。
     *
     * @param seconds 片尾跳过剩余秒数。
     */
    suspend fun saveSkipOutroSeconds(seconds: Int) {
        // 秒数配置沿用 Flutter TV 的全局偏好语义，负数统一归零。
        skipOutroSeconds = seconds.coerceAtLeast(0)
    }

    /**
     * 读取全屏播放器片尾跳过剩余秒数。
     *
     * @return 当前片尾跳过剩余秒数。
     */
    suspend fun getSkipOutroSeconds(): Int = skipOutroSeconds

    /**
     * 保存弹幕手动匹配记录。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 剧集下标，从 0 开始。
     * @param episodeId 弹幕服务剧集 ID。
     * @param searchKeyword 手动匹配搜索词。
     */
    suspend fun saveDanmakuManualMatch(
        source: String,
        videoId: String,
        episodeIndex: Int,
        episodeId: Int,
        searchKeyword: String,
    ) {
        // 与 Flutter 端同样按 source + id + episodeIndex 定位单集匹配。
        danmakuManualMatches[danmakuManualMatchKey(source, videoId, episodeIndex)] =
            TvDanmakuManualMatchRecord(
                episodeId = episodeId,
                searchKeyword = searchKeyword.trim(),
            )
    }

    /**
     * 读取弹幕手动匹配记录。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 剧集下标，从 0 开始。
     * @return 手动匹配记录。
     */
    suspend fun getDanmakuManualMatch(
        source: String,
        videoId: String,
        episodeIndex: Int,
    ): TvDanmakuManualMatchRecord? {
        return danmakuManualMatches[danmakuManualMatchKey(source, videoId, episodeIndex)]
    }

    /**
     * 保存同标题最近一次弹幕搜索词。
     *
     * @param title 视频标题。
     * @param searchKeyword 搜索词。
     */
    suspend fun saveLastDanmakuManualMatchQueryForTitle(
        title: String,
        searchKeyword: String,
    ) {
        val cleanTitle = danmakuTitleKey(title)
        val cleanKeyword = searchKeyword.trim()
        if (cleanTitle.isBlank() || cleanKeyword.isBlank()) {
            return
        }
        danmakuTitleQueries[cleanTitle] = cleanKeyword
    }

    /**
     * 读取同标题最近一次弹幕搜索词。
     *
     * @param title 视频标题。
     * @return 最近搜索词。
     */
    suspend fun getLastDanmakuManualMatchQueryForTitle(title: String): String? {
        return danmakuTitleQueries[danmakuTitleKey(title)]
    }

    // ── 设置页持久化字段 ──

    /** 主题色标识。 */
    private var themeKey: String = DEFAULT_THEME_KEY

    /** 背景色标识。 */
    private var backgroundKey: String = sharedPreferences
        ?.getString(KEY_BACKGROUND_KEY, DEFAULT_BACKGROUND_KEY)
        ?: DEFAULT_BACKGROUND_KEY

    /** 焦点效果标识。 */
    private var focusEffectKey: String = DEFAULT_FOCUS_EFFECT_KEY

    /** 自动去广告开关。 */
    private var adFilterEnabled: Boolean = true

    /** 图片代理源。 */
    private var imageSource: String = DEFAULT_IMAGE_SOURCE

    /** 弹幕开关。 */
    private var danmakuEnabled: Boolean = true

    /** 弹幕 API 地址。 */
    private var danmakuApi: String = ""

    /** 弹幕不透明度。 */
    private var danmakuOpacity: Float = DEFAULT_DANMAKU_OPACITY

    /** 弹幕字号比例。 */
    private var danmakuFontScale: Float = DEFAULT_DANMAKU_FONT_SCALE

    /** 弹幕显示区域比例 (0.25..1.0)。 */
    private var danmakuDisplayArea: Float = DEFAULT_DANMAKU_DISPLAY_AREA

    /** 弹幕防重叠开关。 */
    private var danmakuPreventOverlap: Boolean = true

    /** 弹幕速度同步开关。 */
    private var danmakuSyncVideoSpeed: Boolean = false

    /** 播放器内核标识（exo / webview）。启动时先从持久化恢复，保证导航首次组合不误判。 */
    private var playerKernel: String = normalizePlayerKernel(
        sharedPreferences?.getString(KEY_PLAYER_KERNEL, DEFAULT_PLAYER_KERNEL),
    )

    suspend fun getPlayerKernel(): String = playerKernel
    fun peekPlayerKernel(): String = playerKernel

    /**
     * 保存播放器内核设置。
     *
     * @param kernel 播放器内核标识。
     */
    suspend fun savePlayerKernel(kernel: String) {
        val normalizedKernel = normalizePlayerKernel(kernel)
        // 先更新内存快照，确保当前进程内的同步 peek 能立刻拿到最新值。
        playerKernel = normalizedKernel
        // 再写入 SharedPreferences，让重启后的首次组合也拿到同一内核。
        sharedPreferences
            ?.edit()
            ?.putString(KEY_PLAYER_KERNEL, normalizedKernel)
            ?.apply()
    }

    suspend fun getThemeKey(): String = themeKey
    suspend fun saveThemeKey(key: String) { themeKey = key }

    /**
     * 读取当前进程内的背景色同步快照。
     *
     * 导航组合详情页时不能等待异步读取，因此使用这份设置页刚保存后的内存值。
     *
     * @return 当前背景色标识。
     */
    fun peekBackgroundKey(): String = backgroundKey

    suspend fun getBackgroundKey(): String = backgroundKey

    /**
     * 保存背景色标识。
     *
     * @param key 设置页选中的背景标识。
     */
    suspend fun saveBackgroundKey(key: String) {
        // 先更新内存快照，让当前详情页导航立即读取到新设置。
        backgroundKey = key
        // 再写入本地偏好，确保应用重启后仍沿用相同背景。
        sharedPreferences
            ?.edit()
            ?.putString(KEY_BACKGROUND_KEY, key)
            ?.apply()
    }

    suspend fun getFocusEffectKey(): String = focusEffectKey
    suspend fun saveFocusEffectKey(key: String) { focusEffectKey = key }

    suspend fun getAdFilterEnabled(): Boolean = adFilterEnabled
    suspend fun saveAdFilterEnabled(enabled: Boolean) { adFilterEnabled = enabled }

    suspend fun getImageSource(): String = imageSource
    suspend fun saveImageSource(source: String) { imageSource = source }

    suspend fun getDanmakuEnabled(): Boolean = danmakuEnabled
    suspend fun saveDanmakuEnabled(enabled: Boolean) { danmakuEnabled = enabled }

    suspend fun getDanmakuApi(): String = danmakuApi
    suspend fun saveDanmakuApi(api: String) { danmakuApi = api }

    suspend fun getDanmakuOpacity(): Float = danmakuOpacity
    suspend fun saveDanmakuOpacity(opacity: Float) { danmakuOpacity = opacity.coerceIn(0f, 1f) }

    suspend fun getDanmakuFontScale(): Float = danmakuFontScale
    suspend fun saveDanmakuFontScale(scale: Float) { danmakuFontScale = scale.coerceAtLeast(0.5f) }

    suspend fun getDanmakuDisplayArea(): Float = danmakuDisplayArea
    suspend fun saveDanmakuDisplayArea(area: Float) { danmakuDisplayArea = area.coerceIn(0.25f, 1f) }

    suspend fun getDanmakuPreventOverlap(): Boolean = danmakuPreventOverlap
    suspend fun saveDanmakuPreventOverlap(prevent: Boolean) { danmakuPreventOverlap = prevent }

    suspend fun getDanmakuSyncVideoSpeed(): Boolean = danmakuSyncVideoSpeed
    suspend fun saveDanmakuSyncVideoSpeed(sync: Boolean) { danmakuSyncVideoSpeed = sync }

    /**
     * 生成弹幕手动匹配键。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 剧集下标。
     * @return 手动匹配键。
     */
    private fun danmakuManualMatchKey(
        source: String,
        videoId: String,
        episodeIndex: Int,
    ): String {
        return "${source}_${videoId}_$episodeIndex"
    }

    /**
     * 生成标题搜索词键。
     *
     * @param title 视频标题。
     * @return 规整后的标题键。
     */
    private fun danmakuTitleKey(title: String): String {
        return title.trim().lowercase().replace(Regex("\\s+"), " ")
    }

    /**
     * 规整播放器内核标识。
     *
     * @param kernel 原始内核值。
     * @return 规整后的受支持内核。
     */
    private fun normalizePlayerKernel(kernel: String?): String {
        return when (kernel?.trim()?.lowercase()) {
            PLAYER_KERNEL_EXO -> PLAYER_KERNEL_EXO
            PLAYER_KERNEL_WEBVIEW -> PLAYER_KERNEL_WEBVIEW
            else -> DEFAULT_PLAYER_KERNEL
        }
    }

    companion object {
        /** SharedPreferences 文件名。 */
        private const val PREFERENCES_NAME = "selene_tv_preferences"

        /** 播放器内核持久化键。 */
        private const val KEY_PLAYER_KERNEL = "player_kernel"

        /** 详情等页面背景色持久化键。 */
        private const val KEY_BACKGROUND_KEY = "background_key"

        /** ExoPlayer 内核标识。 */
        private const val PLAYER_KERNEL_EXO = "exo"

        /** WebView 内核标识。 */
        private const val PLAYER_KERNEL_WEBVIEW = "webview"

        private const val DEFAULT_THEME_KEY = "teal"
        private const val DEFAULT_BACKGROUND_KEY = "deep_blue"
        private const val DEFAULT_FOCUS_EFFECT_KEY = "smooth_border"
        private const val DEFAULT_IMAGE_SOURCE = "直连"
        private const val DEFAULT_DANMAKU_OPACITY = 0.8f
        private const val DEFAULT_DANMAKU_FONT_SCALE = 1.0f
        private const val DEFAULT_DANMAKU_DISPLAY_AREA = 1.0f
        /** 默认播放内核：ExoPlayer（设置页已隐藏切换入口）。 */
        private const val DEFAULT_PLAYER_KERNEL = "exo"
    }
}
