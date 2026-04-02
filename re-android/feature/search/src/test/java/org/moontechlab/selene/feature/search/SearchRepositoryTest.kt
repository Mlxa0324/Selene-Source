package org.moontechlab.selene.feature.search

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.test.runTest
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.SeleneApi
import org.moontechlab.selene.core.model.VideoCardModel
import org.moontechlab.selene.core.model.VideoDetail

class SearchRepositoryTest {

    @Test
    fun `search returns multiple source matched cards with metadata`() = runTest {
        val repository = SearchRepository()

        val results = repository.search("三体")

        assertEquals(2, results.size)
        assertEquals("video-santi-ff", results.first().id)
        assertEquals("三体", results.first().title)
        assertEquals("非凡影视", results.first().sourceName)
        assertEquals("2023", results.first().year)
        assertTrue(results.first().subtitle!!.contains("科幻"))
    }

    @Test
    fun `search switches to server catalog when session is remote mode`() = runTest {
        val sessionStore = CookieSessionStore()
        sessionStore.save(
            baseUrl = "https://demo.example.com",
            cookie = "auth=token",
            isLocalMode = false,
        )
        val repository = SearchRepository(
            sessionStore = sessionStore,
            api = FakeSeleneApi(),
        )

        val results = repository.search("三体")

        assertEquals(1, results.size)
        assertEquals("video-from-api", results.first().id)
        assertEquals("远端接口源", results.first().sourceName)
        assertTrue(results.first().subtitle!!.contains("接口返回"))
    }
}

private class FakeSeleneApi : SeleneApi {
    override suspend fun autoLogin(): Boolean = true

    override suspend fun search(query: String): List<VideoCardModel> = listOf(
        VideoCardModel(
            id = "video-from-api",
            title = "接口搜索：$query",
            posterUrl = "",
            sourceKey = "selene-api",
            sourceName = "远端接口源",
            year = "2026",
            subtitle = "接口返回",
        ),
    )

    override suspend fun fetchDetail(videoId: String, sourceKey: String?): VideoDetail {
        error("not used in search repository test")
    }
}
