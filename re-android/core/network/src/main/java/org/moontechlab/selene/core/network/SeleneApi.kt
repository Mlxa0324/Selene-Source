package org.moontechlab.selene.core.network

import org.moontechlab.selene.core.model.DemoServerVideoCatalog
import org.moontechlab.selene.core.model.VideoCardModel
import org.moontechlab.selene.core.model.VideoDetail

interface SeleneApi {
    suspend fun autoLogin(): Boolean
    suspend fun search(query: String): List<VideoCardModel>
    suspend fun fetchDetail(videoId: String, sourceKey: String? = null): VideoDetail
}

class DemoSeleneApi : SeleneApi {
    override suspend fun autoLogin(): Boolean = true

    override suspend fun search(query: String): List<VideoCardModel> = DemoServerVideoCatalog.search(query).map { video ->
        VideoCardModel(
            id = video.id,
            title = video.title,
            posterUrl = video.posterUrl,
            sourceKey = video.sourceKey,
            sourceName = video.sourceName,
            year = video.year,
            subtitle = "${video.typeName} · 共${video.episodes.size}集 · 服务器",
        )
    }

    override suspend fun fetchDetail(videoId: String, sourceKey: String?): VideoDetail {
        val video = DemoServerVideoCatalog.findById(videoId)
        return if (video != null) {
            VideoDetail(
                id = video.id,
                title = video.title,
                description = video.description,
                posterUrl = video.posterUrl,
                sourceKey = video.sourceKey,
                sourceName = video.sourceName,
                year = video.year,
                typeName = video.typeName,
                episodes = video.episodes,
            )
        } else {
            VideoDetail(
                id = videoId,
                title = "服务器详情占位",
                description = "远端接口未返回匹配条目。",
                posterUrl = "",
                sourceKey = "selene-api",
                sourceName = "Selene 聚合",
            )
        }
    }
}
