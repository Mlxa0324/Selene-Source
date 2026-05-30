package org.moontechlab.selene.tv.core.data.model

/**
 * TV 搜索聚合结果。
 *
 * @property query 搜索关键词。
 * @property results 搜索结果卡片。
 */
data class TvSearchPayload(
    val query: String,
    val results: List<TvVideoCard>,
)
