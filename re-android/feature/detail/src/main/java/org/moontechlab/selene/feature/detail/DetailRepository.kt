package org.moontechlab.selene.feature.detail

import org.moontechlab.selene.core.model.DemoVideoCatalog
import org.moontechlab.selene.core.model.VideoDetail
import org.moontechlab.selene.core.model.VideoEpisode
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.DemoSeleneApi
import org.moontechlab.selene.core.network.SeleneApi

open class DetailRepository(
    private val sessionStore: CookieSessionStore = CookieSessionStore(),
    private val api: SeleneApi = DemoSeleneApi(),
) {
    open suspend fun loadDetail(
        id: String,
        sourceKey: String? = null,
    ): VideoDetail {
        if (sessionStore.currentSession()?.isLocalMode == false) {
            return api.fetchDetail(videoId = id, sourceKey = sourceKey)
        }

        val video = DemoVideoCatalog.findById(id)
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
                id = id,
                title = "示例详情",
                description = "原生 Android 重构占位详情",
                posterUrl = "",
                sourceKey = "demo",
                sourceName = "Demo Source",
                episodes = listOf(VideoEpisode(index = 0, title = "第1集", playUrl = "https://example.com/demo.m3u8")),
            )
        }
    }
}
