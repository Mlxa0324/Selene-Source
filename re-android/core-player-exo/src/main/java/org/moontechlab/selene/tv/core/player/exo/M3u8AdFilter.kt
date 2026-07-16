package org.moontechlab.selene.tv.core.player.exo

/**
 * M3U8 广告片段过滤，对齐 Flutter `M3U8Service.filterAdsFromM3U8` 的核心策略。
 *
 * 过滤广告标签与显式广告块，并把相对路径改写为基于清单地址的绝对 URL，
 * 以便写入本地缓存后仍能被 Exo 正常拉流。
 */
object M3u8AdFilter {
    /** 广告标签关键字。 */
    private val adMarkerPatterns = listOf(
        "#EXT-X-DISCONTINUITY",
        "#EXT-X-CUE-OUT",
        "#EXT-X-CUE-IN",
        "#EXT-X-CUE-OUT-CONT",
        "#EXT-X-CUE",
        "#EXT-X-PLACEMENT-OPPORTUNITY",
        "#EXT-OATCLS-SCTE35",
        "#EXT-X-SCTE35",
        "#EXT-X-VERSION:AD",
        "#EXT-X-AD-STREAMING",
    )

    /**
     * 判断地址是否像 M3U8 清单。
     *
     * @param url 播放地址。
     * @return 像清单时返回 true。
     */
    fun looksLikeM3u8Url(url: String): Boolean {
        val lower = url.trim().lowercase()
        return lower.contains(".m3u8") || lower.contains("m3u8")
    }

    /**
     * 过滤 M3U8 内容中的广告标识，并将相对路径转换为绝对路径。
     *
     * @param content 原始清单文本。
     * @param baseUrl 清单自身 URL，用于解析相对路径。
     * @return 过滤后的清单；输入为空时返回空串。
     */
    fun filterAdsFromM3u8(content: String, baseUrl: String): String {
        if (content.isEmpty()) {
            return ""
        }
        val lines = content.split('\n')
        val filtered = ArrayList<String>(lines.size)
        var skippingAdBlock = false

        for (rawLine in lines) {
            val trimmed = rawLine.trim()
            if (trimmed.isEmpty()) {
                if (!skippingAdBlock) {
                    filtered.add(rawLine)
                }
                continue
            }

            // 显式广告块结束。
            if (trimmed.contains("#EXT-X-CUE-IN")) {
                skippingAdBlock = false
                continue
            }

            // 显式广告块开始：跳过块内分片与时长标签。
            if (isAdBlockStart(trimmed)) {
                skippingAdBlock = true
                continue
            }

            if (skippingAdBlock) {
                continue
            }

            // 孤立广告标签行直接丢弃。
            if (isAdMarkerLine(trimmed)) {
                continue
            }

            filtered.add(rewriteRelativeUri(rawLine, trimmed, baseUrl))
        }
        return filtered.joinToString("\n")
    }

    /**
     * 是否广告块起始标签。
     */
    private fun isAdBlockStart(line: String): Boolean {
        return line.contains("#EXT-X-CUE-OUT") ||
            line.contains("#EXT-X-PLACEMENT-OPPORTUNITY") ||
            line.contains("#EXT-X-AD-STREAMING")
    }

    /**
     * 是否整行广告标记。
     */
    private fun isAdMarkerLine(line: String): Boolean {
        return adMarkerPatterns.any { marker -> line.contains(marker) }
    }

    /**
     * 把相对 URI 改写为绝对地址。
     */
    private fun rewriteRelativeUri(rawLine: String, trimmed: String, baseUrl: String): String {
        // 媒体分片或子清单：非标签行。
        if (!trimmed.startsWith("#")) {
            return resolveAgainstBase(trimmed, baseUrl)
        }
        // 带 URI="..." 属性的标签（KEY / MAP / MEDIA 等）。
        val uriMatch = Regex("""URI=["']([^"']+)["']""").find(trimmed) ?: return rawLine
        val relative = uriMatch.groupValues[1]
        val absolute = resolveAgainstBase(relative, baseUrl)
        return rawLine.replace(relative, absolute)
    }

    /**
     * 相对路径解析为绝对 URL。
     */
    private fun resolveAgainstBase(path: String, baseUrl: String): String {
        val candidate = path.trim()
        if (candidate.startsWith("http://", ignoreCase = true) ||
            candidate.startsWith("https://", ignoreCase = true) ||
            candidate.startsWith("file:", ignoreCase = true)
        ) {
            return candidate
        }
        return runCatching {
            java.net.URI(baseUrl).resolve(candidate).toString()
        }.getOrDefault(candidate)
    }
}
