package org.moontechlab.selene.tv.core.data.model

/**
 * TV 影视详情模型。
 *
 * @property id 视频 ID。
 * @property title 视频标题。
 * @property description 剧情简介。
 * @property sources 可播放来源列表。
 */
data class TvVideoDetail(
    val id: String,
    val title: String,
    val description: String,
    val sources: List<TvVideoSource>,
)

/**
 * TV 播放来源模型。
 *
 * @property id 来源 ID。
 * @property name 来源名称。
 * @property episodes 剧集列表。
 */
data class TvVideoSource(
    val id: String,
    val name: String,
    val episodes: List<TvEpisode>,
)

/**
 * TV 剧集模型。
 *
 * @property id 剧集 ID。
 * @property title 剧集标题。
 * @property url 播放地址。
 */
data class TvEpisode(
    val id: String,
    val title: String,
    val url: String,
)
