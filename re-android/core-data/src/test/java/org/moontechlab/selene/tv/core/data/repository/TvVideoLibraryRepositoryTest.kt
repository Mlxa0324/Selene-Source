package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * 校验 TV 分类视频库仓库契约。
 */
class TvVideoLibraryRepositoryTest {
    /**
     * 分类加载应复用后端搜索结果作为首期列表数据来源。
     */
    @Test
    fun loadCategory_uses_category_default_keyword() = runTest {
        val queries = mutableListOf<String>()
        val repository = TvVideoLibraryRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "movie_a",
                                title = "电影 A",
                                poster = "movie.jpg",
                                source = "source_a",
                                episodes = listOf("1.m3u8"),
                            ),
                        ),
                    )
                }
            },
        )

        val cards = repository.loadCategory(categoryKey = "movie")

        assertThat(queries).containsExactly("电影")
        assertThat(cards.first().id).isEqualTo("movie_a")
        assertThat(cards.first().totalEpisodes).isEqualTo(1)
    }
}
