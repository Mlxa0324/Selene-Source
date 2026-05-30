package org.moontechlab.selene.tv.core.network.model

/**
 * TV 首页接口响应。
 *
 * @property sections 首页远端分区。
 */
data class TvHomeResponse(
    val sections: List<TvHomeSectionResponse>,
)

/**
 * TV 首页接口分区响应。
 *
 * @property key 分区标识。
 * @property title 分区标题。
 * @property videos 分区视频列表。
 */
data class TvHomeSectionResponse(
    val key: String,
    val title: String,
    val videos: List<TvVideoCardResponse>,
)

/**
 * TV 视频卡片接口响应。
 *
 * @property id 视频 ID。
 * @property title 视频标题。
 * @property posterUrl 封面地址。
 */
data class TvVideoCardResponse(
    val id: String,
    val title: String,
    val posterUrl: String,
)
