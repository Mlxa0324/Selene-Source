package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.runtime.staticCompositionLocalOf

/**
 * 当前进程内生效的豆瓣图片代理标识。
 *
 * 默认直连；设置页切换后由应用壳写入。
 */
val LocalTvImageSourceKey = staticCompositionLocalOf { "direct" }

/**
 * 根据设置页图片代理规则改写豆瓣封面地址。
 *
 * 对齐 Flutter `getImageUrl`：
 * - official_cdn → img3.doubanio.com
 * - tencent_cdn → img.doubanio.cmliussss.net
 * - alibaba_cdn → img.doubanio.cmliussss.com
 * - direct → 原地址
 *
 * @param originalUrl 原始图片地址。
 * @param imageSourceKey 图片代理标识。
 * @return 可直接请求的图片地址。
 */
fun resolveDoubanImageUrl(
    originalUrl: String,
    imageSourceKey: String,
): String {
    val url = originalUrl.trim()
    if (url.isEmpty()) {
        return url
    }
    // 仅改写豆瓣图床；其它源保持原样。
    val isDoubanHost = url.contains("doubanio.com", ignoreCase = true) ||
        url.contains("doubanio.", ignoreCase = true)
    if (!isDoubanHost) {
        return url
    }
    val replacementHost = when (normalizeImageSourceKey(imageSourceKey)) {
        "official_cdn" -> "img3.doubanio.com"
        "tencent_cdn", "cdn_tencent" -> "img.doubanio.cmliussss.net"
        "alibaba_cdn", "cdn_aliyun" -> "img.doubanio.cmliussss.com"
        else -> return url
    }
    return url.replace(Regex("""img\d+\.doubanio\.com""", RegexOption.IGNORE_CASE), replacementHost)
}

/**
 * 规整图片代理 key，兼容历史中文值。
 *
 * @param raw 原始 key 或显示名。
 * @return 规范化 key。
 */
fun normalizeImageSourceKey(raw: String): String {
    return when (raw.trim()) {
        "直连", "direct" -> "direct"
        "官方精品", "豆瓣官方精品 CDN", "official_cdn" -> "official_cdn"
        "腾讯CDN", "豆瓣 CDN By CMLiussss（腾讯云）", "tencent_cdn", "cdn_tencent" -> "tencent_cdn"
        "阿里CDN", "豆瓣 CDN By CMLiussss（阿里云）", "alibaba_cdn", "cdn_aliyun" -> "alibaba_cdn"
        else -> raw.trim().ifBlank { "direct" }
    }
}
