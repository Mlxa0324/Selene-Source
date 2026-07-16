package org.moontechlab.selene.tv.core.network

import android.content.Context

/**
 * 豆瓣 PoW 会话 Cookie 持久化项。
 *
 * @property name Cookie 名。
 * @property value Cookie 值。
 * @property expiryEpochMs 过期时间戳（毫秒）；null 表示会话级不过期。
 */
data class DoubanPersistedCookie(
    val name: String,
    val value: String,
    val expiryEpochMs: Long? = null,
)

/**
 * 豆瓣验证 Cookie 持久化接口。
 *
 * 用于跨进程重启复用 `dbsawcv1` 等会话，避免每次详情都重新算 PoW。
 */
interface DoubanCookieStore {
    /**
     * 读取已持久化的 Cookie。
     *
     * @return Cookie 列表。
     */
    fun load(): List<DoubanPersistedCookie>

    /**
     * 覆盖写入当前 Cookie 快照。
     *
     * @param cookies 待持久化 Cookie。
     */
    fun save(cookies: List<DoubanPersistedCookie>)
}

/**
 * 基于 SharedPreferences 的豆瓣 Cookie 存储。
 *
 * 文本格式：`name=value@expiry|name2=value2@expiry2`
 *
 * @property appContext 应用上下文。
 */
class SharedPreferencesDoubanCookieStore(
    appContext: Context,
) : DoubanCookieStore {
    private val preferences = appContext.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun load(): List<DoubanPersistedCookie> {
        val raw = preferences.getString(KEY_COOKIES, null).orEmpty()
        if (raw.isBlank()) {
            return emptyList()
        }
        return raw.split("|").mapNotNull { segment ->
            val at = segment.lastIndexOf('@')
            val nv = if (at > 0) segment.substring(0, at) else segment
            val expiryText = if (at > 0) segment.substring(at + 1) else ""
            val eq = nv.indexOf('=')
            if (eq <= 0) {
                return@mapNotNull null
            }
            val name = nv.substring(0, eq).trim()
            val value = nv.substring(eq + 1).trim()
            if (name.isEmpty() || value.isEmpty()) {
                return@mapNotNull null
            }
            val expiry = expiryText.toLongOrNull()
            DoubanPersistedCookie(name = name, value = value, expiryEpochMs = expiry)
        }
    }

    override fun save(cookies: List<DoubanPersistedCookie>) {
        val encoded = cookies.joinToString("|") { cookie ->
            val expiry = cookie.expiryEpochMs?.toString().orEmpty()
            "${cookie.name}=${cookie.value}@$expiry"
        }
        preferences.edit().putString(KEY_COOKIES, encoded).apply()
    }

    private companion object {
        private const val PREFS_NAME = "selene_douban_verify"
        private const val KEY_COOKIES = "cookies_v1"
    }
}
