package org.moontechlab.selene.tv.core.design.layout

import java.util.concurrent.ConcurrentHashMap

/**
 * 按影片名精确匹配的封面 URL 缓存。
 *
 * 场景：同一片名在不同线路返回的 `posterUrl` 质量不一，部分线路图裂。
 * 某条线路成功加载后记下 URL；其它线路加载失败或无图时，用同名缓存 URL 回退。
 * Coil 磁盘缓存会按 URL 命中已下载图片，因此回退时通常无需重新拉网。
 *
 * 匹配规则：**片名精准匹配**（仅 trim 首尾空白，不折叠中间空白、不忽略大小写）。
 */
object TvPosterTitleUrlCache {
    /** title → 最近一次成功加载的封面 URL。 */
    private val titleToPosterUrl = ConcurrentHashMap<String, String>()

    /**
     * 记录一次成功加载的封面。
     *
     * @param title 影片名。
     * @param posterUrl 成功加载的封面地址。
     */
    fun putSuccess(title: String, posterUrl: String) {
        val key = normalizeTitleKey(title) ?: return
        val url = posterUrl.trim()
        if (url.isEmpty()) {
            return
        }
        titleToPosterUrl[key] = url
    }

    /**
     * 按影片名查找已成功加载过的封面 URL。
     *
     * @param title 影片名。
     * @return 缓存 URL；无命中时 null。
     */
    fun get(title: String): String? {
        val key = normalizeTitleKey(title) ?: return null
        return titleToPosterUrl[key]?.takeIf { url -> url.isNotBlank() }
    }

    /**
     * 解析实际用于请求的封面 URL。
     *
     * 优先用接口下发的 [posterUrl]；为空时回退同名缓存。
     *
     * @param title 影片名。
     * @param posterUrl 接口封面。
     * @return 首轮请求 URL；都没有时 null。
     */
    fun resolvePrimaryUrl(title: String, posterUrl: String): String? {
        val primary = posterUrl.trim().takeIf { it.isNotEmpty() }
        if (primary != null) {
            return primary
        }
        return get(title)
    }

    /**
     * 主 URL 失败后的同名回退 URL。
     *
     * @param title 影片名。
     * @param failedUrl 刚刚失败的 URL。
     * @return 与 failedUrl 不同的缓存 URL；没有则 null。
     */
    fun resolveFallbackUrl(title: String, failedUrl: String): String? {
        val cached = get(title) ?: return null
        val failed = failedUrl.trim()
        return cached.takeIf { it.isNotBlank() && it != failed }
    }

    /**
     * 测试用：清空缓存。
     */
    internal fun clearForTest() {
        titleToPosterUrl.clear()
    }

    /**
     * 测试用：当前缓存条数。
     */
    internal fun sizeForTest(): Int = titleToPosterUrl.size

    /**
     * 片名键：仅 trim，保持精准匹配。
     *
     * @param title 原始片名。
     * @return 非空键；空白返回 null。
     */
    private fun normalizeTitleKey(title: String): String? {
        return title.trim().takeIf { it.isNotEmpty() }
    }
}
