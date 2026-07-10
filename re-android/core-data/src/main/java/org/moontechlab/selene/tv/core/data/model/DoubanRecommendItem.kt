package org.moontechlab.selene.tv.core.data.model

/**
 * 豆瓣详情页解析出的推荐条目。
 *
 * @property id 豆瓣条目 ID。
 * @property title 标题。
 * @property poster 海报地址。
 * @property rate 评分（可能为空）。
 */
data class DoubanRecommendItem(
    val id: String,
    val title: String,
    val poster: String,
    val rate: String?,
)
