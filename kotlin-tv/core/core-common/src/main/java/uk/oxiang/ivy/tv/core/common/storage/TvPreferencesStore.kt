package uk.oxiang.ivy.tv.core.common.storage

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

/**
 * TV 服务器会话配置（登录后持久化，供重启后自动恢复会话）。
 *
 * @property baseUrl 服务器基础地址。
 * @property account 当前账号。
 * @property cookie 当前会话 Cookie。
 */
data class TvServerConfig(
    val baseUrl: String,
    val account: String,
    val cookie: String,
)

/**
 * TV 弹幕手动匹配记录。
 *
 * @property source 播放来源标识。
 * @property videoId 视频 ID。
 * @property episodeIndex 剧集下标，从 0 开始。
 * @property episodeId 弹幕服务剧集 ID。
 * @property searchKeyword 手动匹配时使用的搜索词。
 */
data class TvDanmakuManualMatchRecord(
    val source: String,
    val videoId: String,
    val episodeIndex: Int,
    val episodeId: Int,
    val searchKeyword: String,
) {
    /** 记录在存储表中的唯一 key，对齐 `source_videoId_episodeIndex` 格式。 */
    val storageKey: String
        get() = "${source}_${videoId}_$episodeIndex"
}

/**
 * DataStore 版 TV 偏好存储。
 *
 * 承载三维独立主题 key（主题色/背景色/焦点效果模式）+ 服务器会话 + 弹幕手动匹配记录，
 * 冻结为 core-common 对外契约。其余字段（图片代理/去广告/弹幕地址等）按 feature-settings
 * 消费需要逐步补充 key，不在骨架阶段抢先落地。
 *
 * @property dataStore Jetpack Preferences DataStore 实例，由 `app-tv` 的
 * `Context.dataStore` 扩展属性单例创建并注入。
 */
class TvPreferencesStore(
    private val dataStore: DataStore<Preferences>,
) {
    private val gson = Gson()

    // ── 服务器会话 ──

    /**
     * 保存服务器会话。
     *
     * @param baseUrl 服务器基础地址。
     * @param account 当前账号。
     * @param cookie 当前会话 Cookie。
     */
    suspend fun saveSession(
        baseUrl: String,
        account: String,
        cookie: String,
    ) {
        dataStore.edit { prefs ->
            prefs[KEY_SESSION_BASE_URL] = baseUrl
            prefs[KEY_SESSION_ACCOUNT] = account
            prefs[KEY_SESSION_COOKIE] = cookie
        }
    }

    /**
     * 读取当前服务器会话。
     *
     * @return 当前会话；未保存或字段不完整时返回 null。
     */
    suspend fun loadSession(): TvServerConfig? {
        val prefs = dataStore.data.first()
        val baseUrl = prefs[KEY_SESSION_BASE_URL] ?: return null
        val account = prefs[KEY_SESSION_ACCOUNT] ?: return null
        val cookie = prefs[KEY_SESSION_COOKIE] ?: return null
        return TvServerConfig(baseUrl = baseUrl, account = account, cookie = cookie)
    }

    // ── 弹幕手动匹配 ──

    /**
     * 保存弹幕手动匹配记录。
     *
     * @param record 手动匹配记录，内部按 [TvDanmakuManualMatchRecord.storageKey] 定位单集。
     */
    suspend fun saveDanmakuManualMatch(record: TvDanmakuManualMatchRecord) {
        dataStore.edit { prefs ->
            val current = decodeManualMatches(prefs[KEY_DANMAKU_MANUAL_MATCHES])
            val updated = current + (record.storageKey to record)
            prefs[KEY_DANMAKU_MANUAL_MATCHES] = gson.toJson(updated)
        }
    }

    /**
     * 读取全部弹幕手动匹配记录。
     *
     * @return 以 [TvDanmakuManualMatchRecord.storageKey] 为 key 的匹配记录表。
     */
    suspend fun loadDanmakuManualMatches(): Map<String, TvDanmakuManualMatchRecord> {
        val prefs = dataStore.data.first()
        return decodeManualMatches(prefs[KEY_DANMAKU_MANUAL_MATCHES])
    }

    /**
     * 读取单集弹幕手动匹配记录。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 剧集下标，从 0 开始。
     * @return 手动匹配记录；未匹配时返回 null。
     */
    suspend fun getDanmakuManualMatch(
        source: String,
        videoId: String,
        episodeIndex: Int,
    ): TvDanmakuManualMatchRecord? {
        val key = "${source}_${videoId}_$episodeIndex"
        return loadDanmakuManualMatches()[key]
    }

    /**
     * 保存同标题最近一次弹幕手动匹配搜索词。
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
        dataStore.edit { prefs ->
            val current = decodeTitleQueries(prefs[KEY_DANMAKU_TITLE_QUERIES])
            val updated = current + (cleanTitle to cleanKeyword)
            prefs[KEY_DANMAKU_TITLE_QUERIES] = gson.toJson(updated)
        }
    }

    /**
     * 读取同标题最近一次弹幕手动匹配搜索词。
     *
     * @param title 视频标题。
     * @return 最近搜索词；未记录时返回 null。
     */
    suspend fun getLastDanmakuManualMatchQueryForTitle(title: String): String? {
        val prefs = dataStore.data.first()
        return decodeTitleQueries(prefs[KEY_DANMAKU_TITLE_QUERIES])[danmakuTitleKey(title)]
    }

    /**
     * 解析标题搜索词表 JSON。
     *
     * @param raw 原始 JSON 字符串。
     * @return 解析后的标题搜索词表；解析失败时返回空表。
     */
    private fun decodeTitleQueries(raw: String?): Map<String, String> {
        if (raw.isNullOrBlank()) {
            return emptyMap()
        }
        val type = object : TypeToken<Map<String, String>>() {}.type
        return runCatching {
            gson.fromJson<Map<String, String>>(raw, type)
        }.getOrDefault(emptyMap())
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
     * 解析弹幕手动匹配记录表 JSON。
     *
     * @param raw 原始 JSON 字符串。
     * @return 解析后的匹配记录表；解析失败时返回空表。
     */
    private fun decodeManualMatches(raw: String?): Map<String, TvDanmakuManualMatchRecord> {
        if (raw.isNullOrBlank()) {
            return emptyMap()
        }
        val type = object : TypeToken<Map<String, TvDanmakuManualMatchRecord>>() {}.type
        return runCatching {
            gson.fromJson<Map<String, TvDanmakuManualMatchRecord>>(raw, type)
        }.getOrDefault(emptyMap())
    }

    // ── 三维独立主题体系 ──

    /**
     * 保存主题色维度。
     *
     * @param key 主题色 storageKey（对齐 `TvThemePaletteKey`）。
     */
    suspend fun saveThemePaletteKey(key: String) {
        dataStore.edit { prefs -> prefs[KEY_THEME_PALETTE] = key }
    }

    /**
     * 主题色维度持续读取流。
     *
     * @return 当前主题色 storageKey，未配置时回退 Flutter 对齐默认值奈飞红。
     */
    fun themePaletteKeyFlow(): Flow<String> {
        return dataStore.data.map { prefs -> prefs[KEY_THEME_PALETTE] ?: DEFAULT_THEME_PALETTE_KEY }
    }

    /**
     * 保存页面背景色维度。
     *
     * @param key 背景色 storageKey（对齐 `TvThemeBackgroundKey`）。
     */
    suspend fun saveThemeBackgroundKey(key: String) {
        dataStore.edit { prefs -> prefs[KEY_THEME_BACKGROUND] = key }
    }

    /**
     * 页面背景色维度持续读取流。
     *
     * @return 当前背景色 storageKey，未配置时回退 Flutter 对齐默认值深蓝灰。
     */
    fun themeBackgroundKeyFlow(): Flow<String> {
        return dataStore.data.map { prefs -> prefs[KEY_THEME_BACKGROUND] ?: DEFAULT_THEME_BACKGROUND_KEY }
    }

    /**
     * 保存卡片焦点效果模式维度。
     *
     * @param key 焦点效果模式 storageKey（对齐 `TvFocusEffectMode`）。
     */
    suspend fun saveFocusEffectModeKey(key: String) {
        dataStore.edit { prefs -> prefs[KEY_FOCUS_EFFECT_MODE] = key }
    }

    /**
     * 卡片焦点效果模式维度持续读取流。
     *
     * @return 当前焦点效果模式 storageKey，未配置时回退 Flutter 对齐默认值放大镜。
     */
    fun focusEffectModeKeyFlow(): Flow<String> {
        return dataStore.data.map { prefs -> prefs[KEY_FOCUS_EFFECT_MODE] ?: DEFAULT_FOCUS_EFFECT_MODE_KEY }
    }

    private companion object {
        val KEY_SESSION_BASE_URL = stringPreferencesKey("session_base_url")
        val KEY_SESSION_ACCOUNT = stringPreferencesKey("session_account")
        val KEY_SESSION_COOKIE = stringPreferencesKey("session_cookie")
        val KEY_DANMAKU_MANUAL_MATCHES = stringPreferencesKey("danmaku_manual_matches")
        val KEY_DANMAKU_TITLE_QUERIES = stringPreferencesKey("danmaku_title_queries")
        val KEY_THEME_PALETTE = stringPreferencesKey("theme_palette_key")
        val KEY_THEME_BACKGROUND = stringPreferencesKey("theme_background_key")
        val KEY_FOCUS_EFFECT_MODE = stringPreferencesKey("focus_effect_mode_key")

        // 默认值对齐 Flutter TvThemeService：奈飞红 + 深蓝灰 + 放大镜模式。
        // 不沿用 re-android 的 "teal"/"smooth_border" 占位默认值。
        const val DEFAULT_THEME_PALETTE_KEY = "netflix_red"
        const val DEFAULT_THEME_BACKGROUND_KEY = "deep_blue"
        const val DEFAULT_FOCUS_EFFECT_MODE_KEY = "magnifier"
    }
}
