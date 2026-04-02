package org.moontechlab.selene.core.network

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RetrofitSeleneApiTest {

    @Test
    fun `search maps remote search payload using active session`() = runTest {
        val sessionStore = CookieSessionStore()
        sessionStore.save(
            baseUrl = "https://selene.example.com/app",
            cookie = "auth=token",
            isLocalMode = false,
        )
        val factory = FakeSeleneRemoteServiceFactory(
            service = FakeSeleneRemoteService(
                searchResponse = SearchResponseDto(
                    results = listOf(
                        RemoteVideoDto(
                            id = "video-santi",
                            title = "三体",
                            poster = "https://image.example.com/santi.jpg",
                            episodes = listOf(
                                "https://media.example.com/santi-01.m3u8",
                                "https://media.example.com/santi-02.m3u8",
                            ),
                            episodesTitles = listOf("第1集", "第2集"),
                            source = "ffm3u8",
                            sourceName = "非凡影视",
                            year = "2023",
                            desc = "接口搜索结果",
                            typeName = "科幻",
                        ),
                    ),
                ),
            ),
        )
        val api = RetrofitSeleneApi(
            sessionStore = sessionStore,
            serviceFactory = factory,
        )

        val results = api.search("三体")

        assertEquals("https://selene.example.com/app", factory.lastBaseUrl)
        assertEquals("auth=token", factory.lastCookie)
        assertEquals("video-santi", results.first().id)
        assertEquals("ffm3u8", results.first().sourceKey)
        assertEquals("非凡影视", results.first().sourceName)
        assertEquals("2023", results.first().year)
        assertEquals("科幻 · 共2集", results.first().subtitle)
    }

    @Test
    fun `detail forwards source key and maps remote episodes`() = runTest {
        val sessionStore = CookieSessionStore()
        sessionStore.save(
            baseUrl = "https://selene.example.com",
            cookie = "auth=token",
            isLocalMode = false,
        )
        val service = FakeSeleneRemoteService(
            detailResponse = RemoteVideoDto(
                id = "video-santi",
                title = "三体",
                poster = "https://image.example.com/santi.jpg",
                episodes = listOf(
                    "https://media.example.com/santi-01.m3u8",
                    "https://media.example.com/santi-02.m3u8",
                ),
                episodesTitles = listOf("第1集", "第2集"),
                source = "ffm3u8",
                sourceName = "非凡影视",
                year = "2023",
                desc = "接口详情结果",
                typeName = "科幻",
                doubanId = 1295644,
            ),
        )
        val api = RetrofitSeleneApi(
            sessionStore = sessionStore,
            serviceFactory = FakeSeleneRemoteServiceFactory(service = service),
        )

        val detail = api.fetchDetail(
            videoId = "video-santi",
            sourceKey = "ffm3u8",
        )

        assertEquals("ffm3u8", service.lastDetailSourceKey)
        assertEquals("video-santi", service.lastDetailVideoId)
        assertEquals("非凡影视", detail.sourceName)
        assertEquals(2, detail.episodes.size)
        assertEquals("第2集", detail.episodes[1].title)
        assertTrue(detail.episodes[1].playUrl.contains("santi-02"))
        assertEquals(1295644, detail.doubanId)
    }
}

private class FakeSeleneRemoteServiceFactory(
    private val service: FakeSeleneRemoteService,
) : SeleneRemoteServiceFactory {
    var lastBaseUrl: String = ""
    var lastCookie: String = ""

    override fun create(baseUrl: String, cookie: String): SeleneRemoteService {
        lastBaseUrl = baseUrl
        lastCookie = cookie
        return service
    }
}

private class FakeSeleneRemoteService(
    private val searchResponse: SearchResponseDto = SearchResponseDto(),
    private val detailResponse: RemoteVideoDto = RemoteVideoDto(),
) : SeleneRemoteService {
    var lastSearchQuery: String = ""
    var lastDetailSourceKey: String = ""
    var lastDetailVideoId: String = ""

    override suspend fun search(query: String): SearchResponseDto {
        lastSearchQuery = query
        return searchResponse
    }

    override suspend fun fetchDetail(sourceKey: String, videoId: String): RemoteVideoDto {
        lastDetailSourceKey = sourceKey
        lastDetailVideoId = videoId
        return detailResponse
    }
}
