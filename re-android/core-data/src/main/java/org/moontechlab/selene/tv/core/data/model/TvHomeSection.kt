package org.moontechlab.selene.tv.core.data.model

/**
 * TV 首页分区模型。
 *
 * @property key 分区标识。
 * @property title 分区标题。
 * @property videos 分区视频列表。
 */
data class TvHomeSection(
    val key: String,
    val title: String,
    val videos: List<TvVideoCard>,
)

/**
 * TV 首页聚合结果。
 *
 * @property sections 首页分区列表。
 */
data class TvHomePayload(
    val sections: List<TvHomeSection>,
)
