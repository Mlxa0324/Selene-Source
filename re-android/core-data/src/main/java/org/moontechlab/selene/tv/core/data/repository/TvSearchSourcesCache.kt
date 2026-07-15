package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * 详情页标题补源（SSE/批量搜索）结果缓存。
 *
 * 对齐 Flutter 手机端 [UserDataService] 的 `fetchSourcesData` 搜索缓存：
 * - TTL：**2 小时**（`Duration(seconds: 7200)`）
 * - 命中后**续约**（把时间戳刷新为当前时刻）
 * - 按清洗后的 query 作为键
 *
 * 进程内共享；同一搜索词在 TTL 内再次进入详情页不会重复打 SSE。
 *
 * @param ttlMs 缓存有效期毫秒。
 * @param maxEntries 最大条目数，超出按 LRU 淘汰。
 * @param nowMs 当前时间毫秒，便于单测注入。
 */
class TvSearchSourcesCache(
    private val ttlMs: Long = DEFAULT_TTL_MS,
    private val maxEntries: Int = DEFAULT_MAX_ENTRIES,
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) {
    /** query -> (线路列表, 写入/续约时间)。accessOrder=true 便于 LRU。 */
    private val entries = object : LinkedHashMap<String, CacheEntry>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, CacheEntry>?): Boolean {
            return size > maxEntries
        }
    }

    /**
     * 读取缓存；未命中或过期返回 null。
     * 命中时续约，对齐 Flutter `renewSearchCache`。
     *
     * @param query 搜索词。
     * @return 未过期的线路列表；否则 null。
     */
    @Synchronized
    fun get(query: String): List<TvVideoSource>? {
        val key = normalizeQuery(query) ?: return null
        val entry = entries[key] ?: return null
        val now = nowMs()
        if (now - entry.savedAtMs >= ttlMs) {
            entries.remove(key)
            return null
        }
        // 续约：延长有效期，与 Flutter 手机端一致。
        entries[key] = entry.copy(savedAtMs = now)
        return entry.sources
    }

    /**
     * 写入或覆盖缓存。
     *
     * @param query 搜索词。
     * @param sources 可播放线路；空列表不写入。
     */
    @Synchronized
    fun put(query: String, sources: List<TvVideoSource>) {
        val key = normalizeQuery(query) ?: return
        if (sources.isEmpty()) {
            return
        }
        entries[key] = CacheEntry(
            sources = sources.toList(),
            savedAtMs = nowMs(),
        )
    }

    /** 清空全部缓存（测试 / 登出）。 */
    @Synchronized
    fun clear() {
        entries.clear()
    }

    /** 当前条目数（测试用）。 */
    @Synchronized
    fun size(): Int = entries.size

    /**
     * 缓存条目。
     *
     * @property sources 线路列表快照。
     * @property savedAtMs 写入或续约时间。
     */
    private data class CacheEntry(
        val sources: List<TvVideoSource>,
        val savedAtMs: Long,
    )

    companion object {
        /**
         * 对齐 Flutter `UserDataService._sourcesDataCacheTtl = Duration(seconds: 7200)`。
         */
        const val DEFAULT_TTL_MS: Long = 7_200_000L

        /** 防止极端场景无限膨胀；远大于日常搜索词数量。 */
        const val DEFAULT_MAX_ENTRIES: Int = 200

        /**
         * 进程级共享实例：详情仓库每次请求会 new，必须共用缓存。
         */
        val shared: TvSearchSourcesCache by lazy { TvSearchSourcesCache() }

        /**
         * 清洗 query，与 Flutter `cleanQuery = query.trim()` 对齐。
         */
        fun normalizeQuery(query: String): String? {
            val cleaned = query.trim()
            return cleaned.takeIf { value -> value.isNotEmpty() }
        }
    }
}
