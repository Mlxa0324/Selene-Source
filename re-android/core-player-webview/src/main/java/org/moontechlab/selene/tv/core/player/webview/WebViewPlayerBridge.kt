package org.moontechlab.selene.tv.core.player.webview

import com.google.gson.JsonObject
import com.google.gson.JsonParser

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
        // 播放页本身上报的是标准 JSON，这里直接按结构解析，避免 Android ICU 正则差异把桥接线程打崩。
        val payloadJson = JsonParser.parseString(payload).asJsonObject
        return WebViewPlaybackEvent(
            positionMs = payloadJson.readLongField("positionMs"),
            durationMs = payloadJson.readLongField("durationMs"),
            isPlaying = payloadJson.readBooleanField("isPlaying"),
            cachedRanges = payloadJson.readCachedRanges(),
            networkSpeedBytesPerSecond = payloadJson.readLongField("networkSpeedBytesPerSecond"),
        )
    }

    /**
     * 读取 Long 字段。
     *
     * @param name 字段名。
     * @return 字段数值；缺失时返回 0。
     */
    private fun JsonObject.readLongField(name: String): Long {
        return get(name)?.takeUnless { it.isJsonNull }?.asLong ?: 0L
    }

    /**
     * 读取 Boolean 字段。
     *
     * @param name 字段名。
     * @return 字段布尔值；缺失时返回 false。
     */
    private fun JsonObject.readBooleanField(name: String): Boolean {
        return get(name)?.takeUnless { it.isJsonNull }?.asBoolean ?: false
    }

    /**
     * 读取缓存区间列表。
     *
     * @return WebView 已缓存区间。
     */
    private fun JsonObject.readCachedRanges(): List<WebViewCachedRange> {
        val cachedRangesJson = getAsJsonArray("cachedRanges") ?: return emptyList()
        return buildList {
            for (index in 0 until cachedRangesJson.size()) {
                // 单个缓存片段字段缺失时只跳过当前片段，不能把整条播放事件直接判废。
                val rangeJson = cachedRangesJson.get(index)?.takeIf { it.isJsonObject }?.asJsonObject ?: continue
                val startMs = rangeJson.get("startMs")?.takeUnless { it.isJsonNull }?.asLong ?: -1L
                val endMs = rangeJson.get("endMs")?.takeUnless { it.isJsonNull }?.asLong ?: -1L
                if (startMs >= 0L && endMs > startMs) {
                    add(WebViewCachedRange(startMs = startMs, endMs = endMs))
                }
            }
        }
    }
}
