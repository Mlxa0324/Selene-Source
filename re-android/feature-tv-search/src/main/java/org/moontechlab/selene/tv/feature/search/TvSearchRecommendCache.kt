package org.moontechlab.selene.tv.feature.search

import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 搜索页「影片推荐」缓存。
 *
 * 对齐 Flutter [TvSearchRecommendService]：
 * - **不**主动查用户收藏/喜好接口；
 * - 被动复用最近打开过的详情页底部「相关推荐」；
 * - 最多保留两组详情推荐，新开详情插到顶部并淘汰最老一组；
 * - 搜索页读取时优先合并这两组；若还没有任何沉淀，再走兜底热门列表。
 *
 * 因此展示结果会随用户近期浏览内容变化，体感上接近“按喜好推荐”，
 * 本质是详情相关推荐的会话级复用，而非独立推荐算法。
 */
class TvSearchRecommendCache(
    private val maxCachedGroups: Int = DEFAULT_MAX_CACHED_GROUPS,
) {
    /** 最近详情页推荐分组（新在前）。 */
    private val groups = mutableListOf<RecommendGroup>()

    /**
     * 记录某次详情页相关推荐。
     *
     * @param source 详情来源标识。
     * @param videoId 详情视频 ID。
     * @param title 详情标题。
     * @param recommends 该详情底部相关推荐。
     */
    @Synchronized
    fun recordDetailRecommends(
        source: String,
        videoId: String,
        title: String,
        recommends: List<TvVideoCard>,
    ) {
        val normalized = dedupeVideos(recommends)
        if (normalized.isEmpty()) {
            return
        }
        val groupKey = buildGroupKey(source = source, videoId = videoId, title = title)
        groups.removeAll { group -> group.key == groupKey }
        groups.add(0, RecommendGroup(key = groupKey, videos = normalized))
        if (groups.size > maxCachedGroups) {
            groups.subList(maxCachedGroups, groups.size).clear()
        }
    }

    /**
     * 加载搜索页推荐列表。
     *
     * 优先返回最近两组详情推荐的合并结果；缓存为空时调用 [fallbackLoader]。
     *
     * @param fallbackLoader 无详情沉淀时的兜底加载（Flutter：热门剧集+热门综艺各 10）。
     * @return 去重后的推荐卡片。
     */
    suspend fun loadSearchRecommends(
        fallbackLoader: suspend () -> List<TvVideoCard>,
    ): List<TvVideoCard> {
        val cached = mergeCachedRecommendGroups()
        if (cached.isNotEmpty()) {
            return cached
        }
        return dedupeVideos(fallbackLoader())
    }

    /**
     * 仅读取当前内存缓存（不触发兜底），便于测试与诊断。
     *
     * @return 合并去重后的缓存列表。
     */
    @Synchronized
    fun peekCachedRecommends(): List<TvVideoCard> = mergeCachedRecommendGroups()

    /**
     * 清空内存缓存（测试或登出时可调用）。
     */
    @Synchronized
    fun clear() {
        groups.clear()
    }

    /**
     * 合并最近两组详情推荐：新组在前，跨组按标题去重。
     */
    @Synchronized
    private fun mergeCachedRecommendGroups(): List<TvVideoCard> {
        val merged = ArrayList<TvVideoCard>()
        val seenKeys = LinkedHashSet<String>()
        for (group in groups) {
            for (video in group.videos) {
                val key = buildVideoKey(video)
                if (key.isEmpty() || !seenKeys.add(key)) {
                    continue
                }
                merged += video
            }
        }
        return merged
    }

    /**
     * 稳定去重：优先归一化标题，标题空时回退 source+id。
     *
     * @param videos 原始列表。
     * @return 去重后的列表。
     */
    fun dedupeVideos(videos: List<TvVideoCard>): List<TvVideoCard> {
        val deduped = ArrayList<TvVideoCard>()
        val seenKeys = LinkedHashSet<String>()
        for (video in videos) {
            val key = buildVideoKey(video)
            if (key.isEmpty() || !seenKeys.add(key)) {
                continue
            }
            deduped += video
        }
        return deduped
    }

    /**
     * 详情推荐分组 Key。
     */
    private fun buildGroupKey(source: String, videoId: String, title: String): String {
        return "$source::$videoId::${normalizeTitle(title)}"
    }

    /**
     * 推荐卡片去重 Key。
     */
    private fun buildVideoKey(video: TvVideoCard): String {
        val normalizedTitle = normalizeTitle(video.title)
        if (normalizedTitle.isNotEmpty()) {
            return normalizedTitle
        }
        if (video.source.isNotBlank() && video.id.isNotBlank()) {
            return "${video.source}::${video.id}"
        }
        return ""
    }

    /**
     * 归一化标题：去空白并小写。
     */
    private fun normalizeTitle(title: String): String {
        return title.replace(Regex("\\s+"), "").trim().lowercase()
    }

    /**
     * 一组详情页相关推荐。
     *
     * @property key 分组键。
     * @property videos 组内卡片。
     */
    private data class RecommendGroup(
        val key: String,
        val videos: List<TvVideoCard>,
    )

    companion object {
        /** 最多缓存两组详情推荐，对齐 Flutter `_maxCachedGroups`。 */
        const val DEFAULT_MAX_CACHED_GROUPS: Int = 2
    }
}
