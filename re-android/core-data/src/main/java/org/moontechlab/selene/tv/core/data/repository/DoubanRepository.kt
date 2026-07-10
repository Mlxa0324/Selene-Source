package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.DoubanSubjectHtmlSource
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.model.DoubanMovieItem

/**
 * 豆瓣分类数据仓库。
 *
 * 提供会话级内存 LRU 缓存，同一 session 内相同筛选参数不重复请求。
 *
 * @property api 豆瓣代理 API 接口。
 * @property htmlSource 豆瓣详情页 HTML 数据源。
 */
class DoubanRepository(
    private val api: SeleneDoubanApi,
    private val htmlSource: DoubanSubjectHtmlSource? = null,
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
    }

    /**
     * 从豆瓣详情页抓取并解析「相关推荐」。
     *
     * @param doubanId 豆瓣条目 ID。
     * @return 推荐影视卡片列表；未注入 HTML 数据源时返回空列表。
     */
    suspend fun loadDetailRecommends(doubanId: String): List<TvVideoCard> {
        val source = htmlSource ?: return emptyList()
        val html = source.fetchSubjectHtml(doubanId)
        return DoubanDetailsParser.parseRecommends(html)
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

    companion object {
        private const val MAX_CACHE_ENTRIES = 50
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
