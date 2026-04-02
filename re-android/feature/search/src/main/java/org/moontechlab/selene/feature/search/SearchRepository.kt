package org.moontechlab.selene.feature.search

import org.moontechlab.selene.core.model.DemoVideoCatalog
import org.moontechlab.selene.core.model.VideoCardModel
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.DemoSeleneApi
import org.moontechlab.selene.core.network.SeleneApi

open class SearchRepository(
    private val sessionStore: CookieSessionStore = CookieSessionStore(),
    private val api: SeleneApi = DemoSeleneApi(),
) {
    open suspend fun search(keyword: String): List<VideoCardModel> = if (isRemoteMode()) {
        api.search(keyword)
    } else {
        DemoVideoCatalog.search(keyword).map { video ->
            VideoCardModel(
                id = video.id,
                title = video.title,
                posterUrl = video.posterUrl,
                sourceKey = video.sourceKey,
                sourceName = video.sourceName,
                year = video.year,
                subtitle = "${video.typeName} · 共${video.episodes.size}集",
            )
        }
    }

    private fun isRemoteMode(): Boolean = sessionStore.currentSession()?.isLocalMode == false
}
