package org.moontechlab.selene.tv.core.benchmark

/**
 * 播放器 benchmark 事件。
 *
 * @property name 事件名称。
 * @property costMs 耗时，单位毫秒。
 * @property metadata 额外元数据。
 */
data class PlayerBenchmarkEvent(
    val name: String,
    val costMs: Long,
    val metadata: Map<String, String> = emptyMap(),
)

/**
 * 播放器 benchmark 记录器。
 */
class PlayerBenchmarkRecorder {
    /** 已记录事件。 */
    private val events = mutableListOf<PlayerBenchmarkEvent>()

    /**
     * 记录一次 benchmark 事件。
     *
     * @param event benchmark 事件。
     */
    fun record(event: PlayerBenchmarkEvent) {
        // 记录 seek、切源、切内核耗时，为后续缩减 WebView 使用范围提供依据。
        events += event
    }

    /**
     * 读取全部 benchmark 事件。
     *
     * @return 当前已记录事件列表。
     */
    fun readAll(): List<PlayerBenchmarkEvent> = events.toList()
}
