package org.moontechlab.selene.tv.core.player.webview

/**
 * WebView 播放事件状态。
 *
 * @property positionMs 当前播放位置，单位毫秒。
 * @property durationMs 当前视频时长，单位毫秒。
 * @property isPlaying 是否正在播放。
 */
data class WebViewPlaybackEvent(
    val positionMs: Long,
    val durationMs: Long,
    val isPlaying: Boolean,
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
}
