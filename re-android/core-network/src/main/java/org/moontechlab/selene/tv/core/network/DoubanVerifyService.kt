package org.moontechlab.selene.tv.core.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.security.MessageDigest
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

/**
 * 豆瓣 PoW 验证绕过服务。
 *
 * 镜像 Flutter `douban_verify_service_with_expir.dart`：
 * - 首次请求豆瓣页面时可能遇到 `id="sec"` 验证页；
 * - 自动求解 SHA-512 PoW 难题并提交验证；
 * - 使用带过期管理的 Cookie 缓存维持验证会话。
 *
 * @property client 专用于豆瓣直连的 OkHttp 客户端（不走代理）。
 */
class DoubanVerifyService(
    private val client: OkHttpClient,
) {
    /** Cookie 值缓存。 */
    private val cookieCache = ConcurrentHashMap<String, String>()

    /** Cookie 过期时间戳（毫秒）。 */
    private val cookieExpiries = ConcurrentHashMap<String, Long>()

    /**
     * 带 PoW 验证的页面抓取。
     *
     * @param targetUrl 豆瓣页面地址。
     * @return HTML 正文。
     */
    suspend fun fetchWithVerify(targetUrl: String): String = withContext(Dispatchers.IO) {
        cleanupExpiredCookies()
        val response = get(targetUrl)
        val body = response.use { resp ->
            if (!resp.isSuccessful) {
                throw IOException("HTTP ${resp.code} fetching $targetUrl")
            }
            resp.body?.string().orEmpty()
        }

        // 没有触发验证页则直接返回。
        if (!body.contains("id=\"sec\"")) {
            return@withContext body
        }

        val tok = extractValue(body, "tok")
        val cha = extractValue(body, "cha")
        val red = extractValue(body, "red")
        if (tok == null || cha == null || red == null) {
            return@withContext body
        }

        val sol = solvePoW(cha)
        postVerify(tok, cha, sol, red, targetUrl)

        val retryResponse = get(targetUrl)
        return@withContext retryResponse.use { resp ->
            if (!resp.isSuccessful) {
                throw IOException("HTTP ${resp.code} fetching $targetUrl after PoW verify")
            }
            resp.body?.string().orEmpty()
        }
    }

    // ---- PoW ----

    /**
     * SHA-512 暴力求解 nonce，使 `sha512(cha + nonce)` 以 `difficulty` 个零开头。
     */
    private suspend fun solvePoW(cha: String, difficulty: Int = 4): Int = withContext(Dispatchers.Default) {
        solvePoWInternal(cha, difficulty)
    }

    private fun solvePoWInternal(cha: String, difficulty: Int): Int {
        val targetPrefix = "0".repeat(difficulty)
        val digest = MessageDigest.getInstance("SHA-512")
        var nonce = 0
        while (true) {
            nonce++
            val input = cha + nonce.toString()
            val hash = digest.digest(input.toByteArray(Charsets.UTF_8)).toHexString()
            if (hash.startsWith(targetPrefix)) {
                return nonce
            }
            if (nonce % 10000 == 0) {
                Thread.yield()
            }
        }
    }

    // ---- Cookie ----

    /** 清理过期 Cookie。 */
    private fun cleanupExpiredCookies() {
        val now = System.currentTimeMillis()
        val expiredKeys = cookieExpiries.entries
            .filter { (_, expiry) -> now > expiry }
            .map { it.key }
        for (key in expiredKeys) {
            cookieCache.remove(key)
            cookieExpiries.remove(key)
        }
    }

    /** 从响应 Set-Cookie 头更新缓存。 */
    private fun updateCookies(response: Response) {
        val setCookieHeaders = response.headers("Set-Cookie")
        for (header in setCookieHeaders) {
            // Set-Cookie 可能逗号分隔多条，但值里也可能含逗号（如 expires）。
            // 这里用简单分号拆分 name=value 部分。
            val parts = header.split(";")
            val firstPart = parts.firstOrNull() ?: continue
            val separatorIndex = firstPart.indexOf('=')
            if (separatorIndex == -1) continue
            val name = firstPart.substring(0, separatorIndex).trim()
            val value = firstPart.substring(separatorIndex + 1).trim()
            if (name.isEmpty()) continue

            cookieCache[name] = value

            var expiry: Long? = null
            for (i in 1 until parts.size) {
                val attr = parts[i].trim()
                if (attr.startsWith("max-age=", ignoreCase = true)) {
                    val seconds = attr.substring(8).trim().toLongOrNull()
                    if (seconds != null) {
                        expiry = System.currentTimeMillis() + seconds * 1000
                    }
                }
            }
            // dbsawcv1 无显式过期时默认 300 秒。
            if (name == "dbsawcv1" && expiry == null) {
                expiry = System.currentTimeMillis() + DBSAWCV1_DEFAULT_TTL_MS
            }
            if (expiry != null) {
                cookieExpiries[name] = expiry
            } else {
                cookieExpiries.remove(name)
            }
        }
    }

    /** 构建 Cookie 请求头字符串。 */
    private fun getCookieString(): String {
        cleanupExpiredCookies()
        // dbsawcv1 每次读取续期 300 秒（滑动过期）。
        if (cookieCache.containsKey("dbsawcv1")) {
            cookieExpiries["dbsawcv1"] = System.currentTimeMillis() + DBSAWCV1_DEFAULT_TTL_MS
        }
        return cookieCache.entries.joinToString("; ") { "${it.key}=${it.value}" }
    }

    // ---- HTTP ----

    private fun get(url: String): Response {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", USER_AGENT)
            .header("Referer", REFERER)
            .header("Accept", ACCEPT_HTML)
            .header("Cookie", getCookieString())
            .build()
        val response = client.newCall(request).execute()
        updateCookies(response)
        return response
    }

    private fun postVerify(tok: String, cha: String, sol: Int, red: String, referer: String) {
        val body = FormBody.Builder()
            .add("tok", tok)
            .add("cha", cha)
            .add("sol", sol.toString())
            .add("red", red)
            .build()
        val request = Request.Builder()
            .url(VERIFY_URL)
            .header("User-Agent", USER_AGENT)
            .header("Referer", referer)
            .header("Cookie", getCookieString())
            .header("Content-Type", "application/x-www-form-urlencoded")
            .post(body)
            .build()
        val response = client.newCall(request).execute()
        response.use { updateCookies(it) }
    }

    // ---- HTML 提取 ----

    companion object {
        private const val USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/120.0.0.0 Safari/537.36"
        private const val REFERER = "https://movie.douban.com/"
        private const val ACCEPT_HTML =
            "text/html,application/xhtml+xml,application/xml;" +
            "q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
        private const val VERIFY_URL = "https://sec.douban.com/c"
        private const val DBSAWCV1_DEFAULT_TTL_MS = 300_000L

        /**
         * 从 HTML 中提取隐藏字段值。
         *
         * @param html 页面 HTML。
         * @param name 字段名。
         * @return 字段值，找不到返回 null。
         */
        fun extractValue(html: String, name: String): String? {
            val regex = Regex("""id="$name"\s+name="$name"\s+value="(.*?)"""")
            return regex.find(html)?.groupValues?.getOrNull(1)
        }

        /** SHA-512 字节数组转十六进制小写字符串。 */
        private fun ByteArray.toHexString(): String {
            return joinToString("") { "%02x".format(it) }
        }
    }
}
