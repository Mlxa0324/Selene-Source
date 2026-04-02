package org.moontechlab.selene.core.model

data class VideoCardModel(
    val id: String,
    val title: String,
    val posterUrl: String,
    val sourceKey: String,
    val sourceName: String,
    val year: String? = null,
    val subtitle: String? = null,
)
