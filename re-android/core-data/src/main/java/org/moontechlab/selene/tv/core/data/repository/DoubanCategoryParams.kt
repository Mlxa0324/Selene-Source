package org.moontechlab.selene.tv.core.data.repository

/**
 * 豆瓣分类查询参数。
 *
 * @property kind 影视类型（movie / tv）。
 * @property category 分类（热门 / 最近热门 / 全部 等）。
 * @property type 类型筛选。
 * @property format 形式筛选（电视剧 / 综艺 / all 等），仅推荐接口使用。
 * @property label 额外标签（动漫类型走 label 而非 category）。
 * @property region 地区。
 * @property year 年代。
 * @property platform 平台。
 * @property sort 排序（T 综合 / U 热度 / R 时间 / S 评分）。
 * @property page 页码。
 */
data class DoubanCategoryParams(
    val kind: String,
    val category: String = "热门",
    val type: String = "全部",
    val format: String = "",
    val label: String = "",
    val region: String = "全部",
    val year: String = "全部",
    val platform: String = "全部",
    val sort: String = "T",
    val page: Int = 0,
) {
    /** 生成内存缓存键。 */
    fun toCacheKey(): String {
        return "$kind|$category|$type|$format|$label|$region|$year|$platform|$sort|$page"
    }

    /** 是否需要走豆瓣推荐接口（高级筛选），热门/最近热门走分类接口。 */
    val useRecommendsApi: Boolean
        get() = category == "全部" || category == "最新" ||
            category == "豆瓣高分" || category == "冷门佳片"

    /** 类型/地区等字段是否可视为"未筛选"（全部 / all / 空）。 */
    private fun String.isAllFilter(): Boolean {
        return this == "全部" || this == "all" || this.isEmpty()
    }

    /** 类型筛选是否为有效筛选值。 */
    val hasTypeFilter: Boolean get() = !type.isAllFilter()

    /** 地区筛选是否为有效筛选值。 */
    val hasRegionFilter: Boolean get() = !region.isAllFilter()

    /** 年代筛选是否为有效筛选值。 */
    val hasYearFilter: Boolean get() = !year.isAllFilter()

    /** 平台筛选是否为有效筛选值。 */
    val hasPlatformFilter: Boolean get() = !platform.isAllFilter()

    /** 形式筛选是否为有效筛选值。 */
    val hasFormatFilter: Boolean get() = !format.isAllFilter()

    /** 标签是否为有效筛选值。 */
    val hasLabelFilter: Boolean get() = !label.isAllFilter()

    companion object {
        /** 每页条数。 */
        const val PAGE_LIMIT = 25

        /** 推荐页固定条数。 */
        const val RECOMMENDS_PAGE_LIMIT = 20

        /**
         * 从分类标识创建默认查询参数（分类=热门，其余=全部）。
         *
         * @param categoryKey 分类标识（movie / tv / anime / show）。
         * @return 默认筛选参数。
         */
        fun defaultFor(categoryKey: String): DoubanCategoryParams {
            return DoubanCategoryParams(kind = categoryKey.toDoubanKind())
        }

        /**
         * 从筛选行键值对创建查询参数。
         *
         * 期望 filterSelections 的值已经是 apiValue（即豆瓣 API 可识别的格式），
         * 不再需要 toDoubanSort 等二次转换。
         *
         * @param categoryKey 分类标识。
         * @param filterSelections 筛选行 key → apiValue 的映射。
         * @return 封装筛选值的查询参数。
         */
        fun fromSelections(
            categoryKey: String,
            filterSelections: Map<String, String>,
        ): DoubanCategoryParams {
            return DoubanCategoryParams(
                kind = categoryKey.toDoubanKind(),
                category = filterSelections["分类"] ?: "热门",
                type = filterSelections["类型"] ?: "全部",
                region = filterSelections["地区"] ?: "全部",
                year = filterSelections["年代"] ?: "全部",
                platform = filterSelections["平台"] ?: "全部",
                sort = filterSelections["排序"] ?: "T",
            )
        }
    }
}

/**
 * 将分类标识转为豆瓣 API 的 kind 参数。
 */
private fun String.toDoubanKind(): String {
    return when (this) {
        "movie" -> "movie"
        // 豆瓣代理 API 中动漫和综艺都归类在 tv 下，通过 category 参数区分。
        "anime", "show", "tv" -> "tv"
        else -> "tv"
    }
}
