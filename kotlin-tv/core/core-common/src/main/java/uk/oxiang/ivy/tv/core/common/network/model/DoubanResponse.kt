package uk.oxiang.ivy.tv.core.common.network.model

import com.google.gson.annotations.SerializedName

/**
 * 豆瓣代理 API 分类数据响应。
 *
 * @property items 影视条目列表。
 */
data class DoubanCategoryResponse(
    @SerializedName("items") val items: List<DoubanMovieItem>?,
)

/**
 * 豆瓣影视条目。
 *
 * @property id 豆瓣条目 ID。
 * @property title 中文标题。
 * @property pic 封面图 (pic.normal / pic.large)。
 * @property cover 封面图回退字段（部分代理 API 用 cover 代替 pic）。
 * @property rating 豆瓣评分。
 * @property cardSubtitle 卡片副标题（含年份等信息）。
 */
data class DoubanMovieItem(
    @SerializedName("id") val id: String?,
    @SerializedName("title") val title: String?,
    @SerializedName("pic") val pic: DoubanPic?,
    @SerializedName("cover") val cover: String? = null,
    @SerializedName("rating") val rating: DoubanRating?,
    @SerializedName("card_subtitle") val cardSubtitle: String?,
)

/**
 * 豆瓣封面图。
 *
 * @property normal 常规尺寸。
 * @property large 大尺寸。
 */
data class DoubanPic(
    @SerializedName("normal") val normal: String?,
    @SerializedName("large") val large: String?,
)

/**
 * 豆瓣评分。
 *
 * @property value 评分值（0-10）。
 */
data class DoubanRating(
    @SerializedName("value") val value: Double?,
)
