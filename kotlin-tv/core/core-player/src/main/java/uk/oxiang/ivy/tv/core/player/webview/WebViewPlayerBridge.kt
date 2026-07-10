package uk.oxiang.ivy.tv.core.player.webview

/**
 * WebView 播放事件状态。
 *
 * @property positionMs 当前播放位置，单位毫秒。
 * @property durationMs 当前视频时长，单位毫秒。
 * @property isPlaying 是否正在播放。
 * @property cachedRanges 当前 WebView 已缓存区间。
 * @property networkSpeedBytesPerSecond 当前 WebView 下载网速，单位 B/s。
 */
data class WebViewPlaybackEvent(
    val positionMs: Long,
    val durationMs: Long,
    val isPlaying: Boolean,
    val cachedRanges: List<WebViewCachedRange> = emptyList(),
    val networkSpeedBytesPerSecond: Long = 0L,
)

/**
 * WebView 已缓存区间。
 *
 * @property startMs 缓存起点，单位毫秒。
 * @property endMs 缓存终点，单位毫秒。
 */
data class WebViewCachedRange(
    val startMs: Long,
    val endMs: Long,
)

/**
 * WebView 播放事件桥接器。
 */
class WebViewPlayerBridge {
    /**
     * 将 JS 上报 JSON 映射为原生播放事件。
     *
     * @param payload JS 上报的 JSON 字符串。
     * @return 原生播放事件。
     */
    fun mapEvent(payload: String): WebViewPlaybackEvent {
        // 首期只解析播放器核心字段，避免为简单桥接引入额外 JSON 依赖。
        return WebViewPlaybackEvent(
            positionMs = payload.readLongField("positionMs"),
            durationMs = payload.readLongField("durationMs"),
            isPlaying = payload.readBooleanField("isPlaying"),
            cachedRanges = payload.readCachedRanges(),
            networkSpeedBytesPerSecond = payload.readLongField("networkSpeedBytesPerSecond"),
        )
    }

    /**
     * 读取 Long 字段。
     *
     * @param name 字段名。
     * @return 字段数值；缺失时返回 0。
     */
    private fun String.readLongField(name: String): Long {
        val regex = Regex("\\\"$name\\\"\\s*:\\s*(\\d+)")
        return regex.find(this)?.groupValues?.getOrNull(1)?.toLongOrNull() ?: 0L
    }

    /**
     * 读取 Boolean 字段。
     *
     * @param name 字段名。
     * @return 字段布尔值；缺失时返回 false。
     */
    private fun String.readBooleanField(name: String): Boolean {
        val regex = Regex("\\\"$name\\\"\\s*:\\s*(true|false)")
        return regex.find(this)?.groupValues?.getOrNull(1)?.toBooleanStrictOrNull() ?: false
    }

    /**
     * 读取缓存区间列表。
     *
     * @return WebView 已缓存区间。
     */
    private fun String.readCachedRanges(): List<WebViewCachedRange> {
        val rangeRegex = Regex(
            "\\{\\s*\\\"startMs\\\"\\s*:\\s*(\\d+)\\s*,\\s*\\\"endMs\\\"\\s*:\\s*(\\d+)\\s*}",
        )
        return rangeRegex.findAll(this)
            .mapNotNull { match ->
                val startMs = match.groupValues.getOrNull(1)?.toLongOrNull()
                val endMs = match.groupValues.getOrNull(2)?.toLongOrNull()
                if (startMs == null || endMs == null || endMs <= startMs) {
                    null
                } else {
                    WebViewCachedRange(startMs = startMs, endMs = endMs)
                }
            }
            .toList()
    }
}
