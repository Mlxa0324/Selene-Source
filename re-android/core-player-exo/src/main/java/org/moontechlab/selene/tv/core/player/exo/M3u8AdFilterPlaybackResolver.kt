package org.moontechlab.selene.tv.core.player.exo

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * 自动去广告播放地址解析器。
 *
 * 开启去广告且地址像 M3U8 时：拉取清单 → 过滤广告 → 写本地缓存 → 返回 file URI。
 * 失败时回退原始地址，避免阻断起播。
 *
 * @property cacheDir 过滤后清单缓存目录；为空时使用系统临时目录。
 * @property openConnection 可注入的连接工厂，单测可替换。
 */
class M3u8AdFilterPlaybackResolver(
    private val cacheDir: File? = null,
    private val openConnection: (URL) -> HttpURLConnection = { url ->
        (url.openConnection() as HttpURLConnection)
    },
) {
    /**
     * 解析最终可播放地址。
     *
     * @param url 原始播放地址。
     * @param adFilterEnabled 是否开启自动去广告。
     * @return 过滤后的本地清单或原始地址。
     */
    suspend fun resolvePlaybackUrl(
        url: String,
        adFilterEnabled: Boolean,
    ): String = withContext(Dispatchers.IO) {
        val raw = url.trim()
        if (!adFilterEnabled || raw.isEmpty() || !M3u8AdFilter.looksLikeM3u8Url(raw)) {
            return@withContext raw
        }
        runCatching {
            val content = downloadText(raw)
            if (content.isBlank()) {
                return@runCatching raw
            }
            val filtered = M3u8AdFilter.filterAdsFromM3u8(content, raw)
            val dir = cacheDir ?: File(System.getProperty("java.io.tmpdir") ?: ".", "selene_m3u8")
            if (!dir.exists()) {
                dir.mkdirs()
            }
            val file = File(dir, "filtered_${sha1(raw)}.m3u8")
            file.writeText(filtered)
            file.toURI().toString()
        }.getOrDefault(raw)
    }

    /**
     * 拉取远端清单文本。
     */
    private fun downloadText(url: String): String {
        val connection = openConnection(URL(url))
        return try {
            connection.connectTimeout = 10_000
            connection.readTimeout = 30_000
            connection.instanceFollowRedirects = true
            connection.setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36",
            )
            connection.setRequestProperty("Accept", "*/*")
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    /**
     * 生成稳定短哈希，避免缓存文件名过长。
     */
    private fun sha1(value: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(value.toByteArray())
        return digest.joinToString("") { byte -> "%02x".format(byte) }.take(16)
    }
}
