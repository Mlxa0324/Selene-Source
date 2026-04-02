package org.moontechlab.selene.feature.detail

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.model.VideoCardModel
import org.moontechlab.selene.core.model.VideoDetail
import org.moontechlab.selene.core.model.VideoEpisode
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.SeleneApi

class DetailRepositoryTest {

    @Test
    fun `load detail returns matching catalog entry with episodes and source metadata`() = runTest {
        val repository = DetailRepository()

        val detail = repository.loadDetail("video-santi-ff")

        assertEquals("video-santi-ff", detail.id)
        assertEquals("三体", detail.title)
        assertEquals("ffm3u8", detail.sourceKey)
        assertEquals("非凡影视", detail.sourceName)
        assertEquals("2023", detail.year)
        assertEquals("科幻", detail.typeName)
        assertEquals(4, detail.episodes.size)
        assertTrue(detail.episodes.first().playUrl.contains("santi-01"))
    }

    @Test
    fun `load detail switches to server catalog when session is remote mode`() = runTest {
        val sessionStore = CookieSessionStore()
        sessionStore.save(
            baseUrl = "https://demo.example.com",
            cookie = "auth=token",
            isLocalMode = false,
        )
        val api = FakeDetailSeleneApi()
        val repository = DetailRepository(
            sessionStore = sessionStore,
            api = api,
        )

        val detail = repository.loadDetail(
            id = "video-santi-server",
            sourceKey = "selene-api",
        )

        assertEquals("接口详情源", detail.sourceName)
        assertEquals("2026", detail.year)
        assertEquals(1, detail.episodes.size)
        assertTrue(detail.description.contains("接口详情"))
        assertEquals("selene-api", api.lastSourceKey)
    }
}

private class FakeDetailSeleneApi : SeleneApi {
    var lastSourceKey: String? = null

    override suspend fun autoLogin(): Boolean = true

    override suspend fun search(query: String): List<VideoCardModel> = emptyList()

    override suspend fun fetchDetail(videoId: String, sourceKey: String?): VideoDetail {
        lastSourceKey = sourceKey
        return VideoDetail(
            id = videoId,
            title = "接口详情",
            description = "接口详情返回",
            posterUrl = "",
            sourceKey = sourceKey.orEmpty(),
            sourceName = "接口详情源",
            year = "2026",
            typeName = "科幻",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://api.example.com/ep1.m3u8"),
            ),
        )
    }
}
