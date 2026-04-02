package org.moontechlab.selene.core.model

data class VideoEpisode(
    val index: Int,
    val title: String,
    val playUrl: String,
)

data class VideoDetail(
    val id: String,
    val title: String,
    val description: String,
    val posterUrl: String,
    val sourceKey: String,
    val sourceName: String,
    val year: String? = null,
    val typeName: String? = null,
    val doubanId: Int? = null,
    val episodes: List<VideoEpisode> = emptyList(),
)
