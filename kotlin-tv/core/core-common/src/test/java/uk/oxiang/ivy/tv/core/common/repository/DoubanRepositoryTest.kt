package uk.oxiang.ivy.tv.core.common.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import uk.oxiang.ivy.tv.core.common.network.SeleneDoubanApi
import uk.oxiang.ivy.tv.core.common.network.model.DoubanCategoryResponse
import uk.oxiang.ivy.tv.core.common.network.model.DoubanMovieItem
import uk.oxiang.ivy.tv.core.common.network.model.DoubanPic
import uk.oxiang.ivy.tv.core.common.network.model.DoubanRating
import org.junit.Test

/**
 * [DoubanRepository] 契约测试：DTO -> 业务模型映射与会话级 LRU 缓存。
 */
class DoubanRepositoryTest {

    private class RecordingDoubanApi(
        private val response: DoubanCategoryResponse,
    ) : SeleneDoubanApi {
        var categoryCallCount = 0
            private set

        override suspend fun getCategoryData(
            kind: String,
            start: Int,
            limit: Int,
            category: String,
            type: String,
        ): DoubanCategoryResponse {
            categoryCallCount += 1
            return response
        }

        override suspend fun getRecommends(
            kind: String,
            refresh: Int,
            start: Int,
            count: Int,
            selectedCategories: String,
            uncollect: Boolean,
            scoreRange: String,
            tags: String,
            sort: String,
        ): DoubanCategoryResponse {
            return response
        }
    }

    @Test
    fun loadCategory_mapsDoubanItemToVideoCard_extractingYearFromSubtitle() = runTest {
        val response = DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "123",
                    title = "测试电影",
                    pic = DoubanPic(normal = "https://example.com/normal.jpg", large = null),
                    rating = DoubanRating(value = 8.5),
                    cardSubtitle = "2023 / 剧情 / 中国大陆",
                ),
            ),
        )
        val repository = DoubanRepository(RecordingDoubanApi(response))

        val result = repository.loadCategory(DoubanCategoryParams(kind = "movie", category = "热门"))

        assertThat(result).hasSize(1)
        val card = result.first()
        assertThat(card.id).isEqualTo("123")
        assertThat(card.source).isEqualTo("douban")
        assertThat(card.year).isEqualTo("2023")
        assertThat(card.posterUrl).isEqualTo("https://example.com/normal.jpg")
        assertThat(card.doubanRate).isEqualTo("8.5")
    }

    @Test
    fun loadCategory_cachesResultForSameParams_skipsSecondRemoteCall() = runTest {
        val response = DoubanCategoryResponse(items = emptyList())
        val api = RecordingDoubanApi(response)
        val repository = DoubanRepository(api)
        val params = DoubanCategoryParams(kind = "movie", category = "热门")

        repository.loadCategory(params)
        repository.loadCategory(params)

        assertThat(api.categoryCallCount).isEqualTo(1)
    }

    @Test
    fun loadCategory_fallsBackToCoverField_whenPicMissing() = runTest {
        val response = DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "456",
                    title = "无 pic 字段",
                    pic = null,
                    cover = "https://example.com/cover.jpg",
                    rating = null,
                    cardSubtitle = null,
                ),
            ),
        )
        val repository = DoubanRepository(RecordingDoubanApi(response))

        val result = repository.loadCategory(DoubanCategoryParams(kind = "movie", category = "热门"))

        assertThat(result.first().posterUrl).isEqualTo("https://example.com/cover.jpg")
        assertThat(result.first().doubanRate).isEmpty()
        assertThat(result.first().year).isEmpty()
    }
}
