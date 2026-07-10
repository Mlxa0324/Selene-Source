package uk.oxiang.ivy.tv.core.common.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import uk.oxiang.ivy.tv.core.common.network.model.TvSearchResponse
import uk.oxiang.ivy.tv.core.common.network.model.TvSearchResultResponse
import org.junit.Test

/**
 * [TvDetailRepository] 契约测试：可播放身份判定、标题补源匹配、播放线路去重。
 */
class TvDetailRepositoryTest {

    private class SearchResultApi(
        private val results: List<TvSearchResultResponse>,
    ) : FakeSeleneTvApi() {
        override suspend fun search(query: String): TvSearchResponse {
            return TvSearchResponse(results = results)
        }
    }

    @Test
    fun hasPlayableIdentity_rejectsDoubanAndBangumiSources() {
        val repository = TvDetailRepository(FakeSeleneTvApi())

        assertThat(repository.hasPlayableIdentity(source = "douban", id = "123")).isFalse()
        assertThat(repository.hasPlayableIdentity(source = "bangumi", id = "123")).isFalse()
        assertThat(repository.hasPlayableIdentity(source = "vod1", id = "123")).isTrue()
    }

    @Test
    fun hasPlayableIdentity_rejectsBlankSourceOrId() {
        val repository = TvDetailRepository(FakeSeleneTvApi())

        assertThat(repository.hasPlayableIdentity(source = "", id = "123")).isFalse()
        assertThat(repository.hasPlayableIdentity(source = "vod1", id = "")).isFalse()
    }

    @Test
    fun loadDetailBySearchTitle_matchesTitleAndYear_ignoringWhitespaceAndCase() = runTest {
        val results = listOf(
            TvSearchResultResponse(
                id = "1",
                source = "vod1",
                title = "测试 剧集",
                year = "2024",
                episodes = listOf("https://example.com/ep1.m3u8", "https://example.com/ep2.m3u8"),
            ),
            TvSearchResultResponse(
                id = "2",
                source = "vod2",
                title = "不匹配标题",
                year = "2024",
                episodes = listOf("https://example.com/other.m3u8"),
            ),
        )
        val repository = TvDetailRepository(SearchResultApi(results))

        val detail = repository.loadDetailBySearchTitle(title = "测试剧集", fallbackId = "fallback", year = "2024")

        assertThat(detail).isNotNull()
        assertThat(detail!!.sources).hasSize(1)
        assertThat(detail.sources.first().source).isEqualTo("vod1")
    }

    @Test
    fun loadDetailBySearchTitle_returnsNull_whenNoSourceHasEpisodes() = runTest {
        val results = listOf(
            TvSearchResultResponse(id = "1", source = "vod1", title = "空剧集", year = "2024", episodes = emptyList()),
        )
        val repository = TvDetailRepository(SearchResultApi(results))

        val detail = repository.loadDetailBySearchTitle(title = "空剧集", fallbackId = "fallback")

        assertThat(detail).isNull()
    }

    @Test
    fun toDistinctPlayableSources_keepsEntryWithMoreEpisodes_whenSameSourceAndId() = runTest {
        val results = listOf(
            TvSearchResultResponse(
                id = "same-id",
                source = "vod1",
                title = "重复线路",
                year = "2024",
                episodes = listOf("https://example.com/1.m3u8"),
            ),
            TvSearchResultResponse(
                id = "same-id",
                source = "vod1",
                title = "重复线路",
                year = "2024",
                episodes = listOf(
                    "https://example.com/1.m3u8",
                    "https://example.com/2.m3u8",
                    "https://example.com/3.m3u8",
                ),
            ),
        )
        val repository = TvDetailRepository(SearchResultApi(results))

        val detail = repository.loadDetailBySearchTitle(title = "重复线路", fallbackId = "fallback", year = "2024")

        assertThat(detail).isNotNull()
        assertThat(detail!!.sources).hasSize(1)
        assertThat(detail.sources.first().episodes).hasSize(3)
    }
}
