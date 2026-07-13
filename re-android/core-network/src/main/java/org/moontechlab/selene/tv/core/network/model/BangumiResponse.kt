package org.moontechlab.selene.tv.core.network.model

import com.google.gson.annotations.SerializedName

/**
 * Bangumi 日历某一天响应。
 *
 * @property weekday 星期信息。
 * @property items 当日放送条目。
 */
data class BangumiCalendarDayResponse(
    val weekday: BangumiWeekdayResponse? = null,
    val items: List<BangumiItemResponse>? = null,
)

/**
 * Bangumi 星期字段。
 *
 * @property en 英文简称。
 * @property cn 中文文案。
 * @property ja 日文文案。
 * @property id 星期 ID，1=周一 ... 7=周日。
 */
data class BangumiWeekdayResponse(
    val en: String? = null,
    val cn: String? = null,
    val ja: String? = null,
    val id: Int? = null,
)

/**
 * Bangumi 日历条目。
 *
 * @property id 条目 ID。
 * @property url 详情页地址。
 * @property type 条目类型。
 * @property name 原名。
 * @property nameCn 中文名。
 * @property summary 简介。
 * @property airDate 放送日期。
 * @property airWeekday 放送星期。
 * @property rating 评分。
 * @property rank 排名。
 * @property images 封面图。
 */
data class BangumiItemResponse(
    val id: Int? = null,
    val url: String? = null,
    val type: Int? = null,
    val name: String? = null,
    @SerializedName("name_cn")
    val nameCn: String? = null,
    val summary: String? = null,
    @SerializedName("air_date")
    val airDate: String? = null,
    @SerializedName("air_weekday")
    val airWeekday: Int? = null,
    val rating: BangumiRatingResponse? = null,
    val rank: Int? = null,
    val images: BangumiImagesResponse? = null,
)

/**
 * Bangumi 评分。
 *
 * @property total 评分人数。
 * @property score 分数。
 */
data class BangumiRatingResponse(
    val total: Int? = null,
    val score: Double? = null,
)

/**
 * Bangumi 封面图集合。
 *
 * @property large 大图。
 * @property common 常规图。
 * @property medium 中图。
 * @property small 小图。
 * @property grid 网格图。
 */
data class BangumiImagesResponse(
    val large: String? = null,
    val common: String? = null,
    val medium: String? = null,
    val small: String? = null,
    val grid: String? = null,
)
