package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.DoubanSubjectHtmlSource
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.model.DoubanMovieItem
import java.util.logging.Logger

/**
 * 豆瓣分类数据仓库。
 *
 * 提供会话级内存 LRU 缓存，同一 session 内相同筛选参数不重复请求。
 * 详情「相关推荐」额外带 **1 天 TTL**，命中期内不重复抓 HTML / PoW。
 *
 * @property api 豆瓣代理 API 接口。
 * @property htmlSource 豆瓣详情页 HTML 数据源。
 * @property recommendTtlMs 相关推荐缓存有效期（默认 1 天）。
 * @property nowMs 当前时间毫秒，便于单测注入。
 */
class DoubanRepository(
    private val api: SeleneDoubanApi,
    private val htmlSource: DoubanSubjectHtmlSource? = null,
    private val recommendTtlMs: Long = RECOMMEND_CACHE_TTL_MS,
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) {
    /** 会话级 LRU 缓存，最多保留 [MAX_CACHE_ENTRIES] 组查询结果。 */
    private val cache = object : LinkedHashMap<String, List<TvVideoCard>>(
        MAX_CACHE_ENTRIES, 0.75f, /* accessOrder = */ true,
    ) {
        override fun removeEldestEntry(
            eldest: MutableMap.MutableEntry<String, List<TvVideoCard>>?,
        ): Boolean = size > MAX_CACHE_ENTRIES
    }

    /**
     * 详情相关推荐 LRU：按 doubanId 缓存卡片 + 写入时间。
     * accessOrder=true 便于容量淘汰；读取时校验 [recommendTtlMs]。
     */
    private val recommendCache = object : LinkedHashMap<String, RecommendCacheEntry>(
        MAX_RECOMMEND_CACHE_ENTRIES, 0.75f, /* accessOrder = */ true,
    ) {
        override fun removeEldestEntry(
            eldest: MutableMap.MutableEntry<String, RecommendCacheEntry>?,
        ): Boolean = size > MAX_RECOMMEND_CACHE_ENTRIES
    }

    /**
     * 加载分类数据。
     *
     * @param params 查询参数。
     * @return 豆瓣影视卡片列表。
     */
    suspend fun loadCategory(params: DoubanCategoryParams): List<TvVideoCard> {
        cache[params.toCacheKey()]?.let { return it }

        val items = if (params.useRecommendsApi) {
            loadRecommends(params)
        } else {
            loadCategoryData(params)
        }

        cache[params.toCacheKey()] = items
        return items
    }

    /**
     * 清除全部缓存。
     */
    fun clearCache() {
        cache.clear()
        recommendCache.clear()
    }

    /**
     * 从豆瓣详情页抓取并解析「相关推荐」。
     *
     * 同一 doubanId 在 [recommendTtlMs]（默认 1 天）内命中内存缓存，跳过 HTML 与 PoW。
     *
     * @param doubanId 豆瓣条目 ID。
     * @return 推荐影视卡片列表；未注入 HTML 数据源时返回空列表。
     */
    suspend fun loadDetailRecommends(doubanId: String): List<TvVideoCard> {
        val cleanId = doubanId.trim()
        if (cleanId.isEmpty()) {
            return emptyList()
        }
        // 同 id 且未过期：直接复用，跳过 HTML 与 PoW。
        getValidRecommendCache(cleanId)?.let { cached ->
            LOGGER.info(
                "loadDetailRecommends id=$cleanId cacheHit count=${cached.size} ttlMs=$recommendTtlMs",
            )
            return cached
        }
        val source = htmlSource ?: return emptyList()
        val html = source.fetchSubjectHtml(cleanId)
        val cards = DoubanDetailsParser.parseRecommends(html)
        // 设备侧排查：确认验证后 HTML 是否真有推荐容器，避免再次误判为 UI 问题。
        val hasSec = html.contains("id=\"sec\"")
        val hasRecommendations = html.contains("id=\"recommendations\"")
        LOGGER.info(
            "loadDetailRecommends id=$cleanId htmlLen=${html.length} hasSec=$hasSec hasRecommendations=$hasRecommendations count=${cards.size}",
        )
        if (cards.isNotEmpty()) {
            recommendCache[cleanId] = RecommendCacheEntry(
                cards = cards,
                savedAtMs = nowMs(),
            )
        }
        return cards
    }

    /**
     * 读取未过期的相关推荐缓存；过期则移除并返回 null。
     *
     * @param cleanId 已 trim 的豆瓣 ID。
     * @return 有效卡片列表；未命中或过期为 null。
     */
    private fun getValidRecommendCache(cleanId: String): List<TvVideoCard>? {
        val entry = recommendCache[cleanId] ?: return null
        val ageMs = nowMs() - entry.savedAtMs
        if (ageMs >= recommendTtlMs) {
            recommendCache.remove(cleanId)
            LOGGER.info("loadDetailRecommends id=$cleanId cacheExpired ageMs=$ageMs ttlMs=$recommendTtlMs")
            return null
        }
        return entry.cards
    }

    /**
     * 通过豆瓣分类接口加载数据（simple mode）。
     */
    private suspend fun loadCategoryData(params: DoubanCategoryParams): List<TvVideoCard> {
        val response = api.getCategoryData(
            kind = params.kind,
            start = params.page * DoubanCategoryParams.PAGE_LIMIT,
            limit = DoubanCategoryParams.PAGE_LIMIT,
            category = params.category,
            type = params.type,
        )
        return response.items.orEmpty().map { it.toVideoCard() }
    }

    /**
     * 通过豆瓣推荐接口加载数据（advanced mode，对齐 Flutter fetchDoubanRecommends）。
     */
    private suspend fun loadRecommends(params: DoubanCategoryParams): List<TvVideoCard> {
        val categoryJson = buildSelectedCategoriesJson(params)
        val tags = buildTagsString(params)
        val effectiveSort = when (params.category) {
            "最新" -> "R"
            "豆瓣高分", "冷门佳片" -> "S"
            else -> params.sort
        }
        val response = api.getRecommends(
            kind = params.kind,
            start = params.page * DoubanCategoryParams.RECOMMENDS_PAGE_LIMIT,
            count = DoubanCategoryParams.RECOMMENDS_PAGE_LIMIT,
            selectedCategories = categoryJson,
            tags = tags,
            sort = effectiveSort,
        )
        return response.items.orEmpty().map { it.toVideoCard() }
    }

    /**
     * 构建 selected_categories JSON（对齐 Flutter）。
     *
     * Flutter 格式：
     * - "类型" → category
     * - "形式" → format（仅当非空）
     * - "地区" → region（仅当非空）
     */
    private fun buildSelectedCategoriesJson(params: DoubanCategoryParams): String {
        // Flutter 将 'all' 转换为空字符串后才构建 JSON
        val category = if (params.type.isAllFilter()) "" else params.type
        val format = if (params.format.isAllFilter()) "" else params.format
        val region = if (params.region.isAllFilter()) "" else params.region

        val entries = linkedMapOf<String, String>()
        entries["类型"] = category
        if (format.isNotEmpty()) {
            entries["形式"] = format
        }
        if (region.isNotEmpty()) {
            entries["地区"] = region
        }
        return if (entries.all { it.value.isEmpty() }) {
            ""
        } else {
            entries.entries.joinToString(",", "{", "}") { (k, v) ->
                """"$k":"$v""""
            }
        }
    }

    /**
     * 构建标签字符串（对齐 Flutter tags 构建逻辑）。
     *
     * Flutter tags 顺序：
     * 1. category（非空时）
     * 2. format（category 为空且 format 非空时）
     * 3. label（非空时）
     * 4. region（非空时）
     * 5. year（非空时）
     * 6. platform（非空时）
     */
    private fun buildTagsString(params: DoubanCategoryParams): String {
        val category = if (params.type.isAllFilter()) "" else params.type
        val format = if (params.format.isAllFilter()) "" else params.format
        val label = if (params.label.isAllFilter()) "" else params.label
        val region = if (params.region.isAllFilter()) "" else params.region
        val year = if (params.year.isAllFilter()) "" else params.year
        val platform = if (params.platform.isAllFilter()) "" else params.platform

        val tags = mutableListOf<String>()
        if (category.isNotEmpty()) {
            tags.add(category)
        }
        if (category.isEmpty() && format.isNotEmpty()) {
            tags.add(format)
        }
        if (label.isNotEmpty()) {
            tags.add(label)
        }
        if (region.isNotEmpty()) {
            tags.add(region)
        }
        if (year.isNotEmpty()) {
            tags.add(year)
        }
        if (platform.isNotEmpty()) {
            tags.add(platform)
        }
        return tags.joinToString(",")
    }

    /**
     * 相关推荐缓存条目。
     *
     * @property cards 解析后的推荐卡片快照。
     * @property savedAtMs 写入时间毫秒。
     */
    private data class RecommendCacheEntry(
        val cards: List<TvVideoCard>,
        val savedAtMs: Long,
    )

    companion object {
        private const val MAX_CACHE_ENTRIES = 50

        /** 详情相关推荐缓存条数（按 doubanId）。 */
        private const val MAX_RECOMMEND_CACHE_ENTRIES = 40

        /**
         * 相关推荐缓存 TTL：1 天。
         * 对齐 Flutter 豆瓣成功结果「缓存时间为 1 天」的产品预期。
         */
        const val RECOMMEND_CACHE_TTL_MS: Long = 86_400_000L

        private val LOGGER: Logger = Logger.getLogger("TvDetailRecommend")
    }
}

/**
 * 将豆瓣 API 条目转为 TV 业务卡片。
 */
internal fun DoubanMovieItem.toVideoCard(): TvVideoCard {
    val subtitle = cardSubtitle
    val yearValue = if (subtitle.isNullOrBlank()) {
        ""
    } else {
        Regex("""(?<year>\d{4})""").find(subtitle)?.groups?.get("year")?.value.orEmpty()
    }
    val rateValue = rating?.value?.let { "%.1f".format(it) }.orEmpty()
    return TvVideoCard(
        id = id.orEmpty(),
        source = "douban",
        title = title.orEmpty(),
        year = yearValue,
        posterUrl = pic?.normal ?: pic?.large ?: cover.orEmpty(),
        doubanRate = rateValue,
    )
}

/**
 * 判断筛选值是否为"全部"类（对齐 Flutter 的 all/全部/空 判断）。
 */
private fun String.isAllFilter(): Boolean {
    return this == "全部" || this == "all" || this.isEmpty()
}
