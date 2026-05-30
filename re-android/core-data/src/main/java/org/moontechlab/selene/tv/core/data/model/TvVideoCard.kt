package org.moontechlab.selene.tv.core.data.model

/**
 * TV 影视卡片模型。
 *
 * @property id 视频 ID。
 * @property title 视频标题。
 * @property posterUrl 封面地址。
 */
data class TvVideoCard(
    val id: String,
    val title: String,
    val posterUrl: String,
)
