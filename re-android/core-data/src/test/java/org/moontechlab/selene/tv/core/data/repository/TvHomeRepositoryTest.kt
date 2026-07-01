package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.model.DoubanCategoryResponse
import org.moontechlab.selene.tv.core.network.model.DoubanMovieItem
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse

/**
 * 校验 TV 首页仓库的数据聚合契约。
 *
 * 首页分区与分类 Tab 共用 [DoubanRepository] LRU 缓存，
 * 确保首页卡片和对应分类页首屏数据一致、不重复请求。
 */
class TvHomeRepositoryTest {
    /**
     * 首页加载应聚合继续观看和四个内容分区。
     */
    @Test
    fun loadHome_aggregates_continue_watching_and_hot_sections() = runTest {
        val repository = TvHomeRepository(
            playbackRepository = TvPlaybackRepository(
                continueWatching = listOf(TvVideoCard(id = "resume-1", title = "续看", posterUrl = "")),
            ),
            doubanRepository = DoubanRepository(api = FakeHomeDoubanApi()),
        )

        val payload = repository.loadHome()

        assertThat(payload.sections.map { it.key }).containsExactly(
            "continue_watching",
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
    }

    /**
     * 无播放记录时首页应隐藏继续观看。
     */
    @Test
    fun loadHome_hides_continue_watching_when_empty() = runTest {
        val repository = TvHomeRepository(
            playbackRepository = TvPlaybackRepository(continueWatching = emptyList()),
            doubanRepository = DoubanRepository(api = FakeHomeDoubanApi()),
        )

        val payload = repository.loadHome()

        assertThat(payload.sections.map { it.key }).containsExactly(
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
    }

    /**
     * 播放记录接口失败时，首页仍应展示内容分区。
     */
    @Test
    fun loadHome_keepsSectionsWhenContinueWatchingFails() = runTest {
        val failingPlayback = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    throw IllegalStateException("play records 500")
                }
            },
        )
        val repository = TvHomeRepository(
            playbackRepository = failingPlayback,
            doubanRepository = DoubanRepository(api = FakeHomeDoubanApi()),
        )

        val payload = repository.loadHome()

        assertThat(payload.sections.map { it.key }).containsAtLeast(
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        )
    }

    /**
     * 单个分类接口失败时，其它分区仍应继续展示。
     */
    @Test
    fun loadHome_keepsOtherSectionsWhenOneCategoryFails() = runTest {
        val repository = TvHomeRepository(
            playbackRepository = TvPlaybackRepository(
                continueWatching = listOf(TvVideoCard(id = "resume-1", title = "续看", posterUrl = "")),
            ),
            doubanRepository = DoubanRepository(api = object : FakeHomeDoubanApi() {
                override suspend fun getCategoryData(
                    kind: String, start: Int, limit: Int, category: String, type: String,
                ): DoubanCategoryResponse {
                    if (category == "最近热门") {
                        throw IllegalStateException("tv category 500")
                    }
                    return super.getCategoryData(kind, start, limit, category, type)
                }
            }),
        )

        val payload = repository.loadHome()

        // 热门电影正常
        assertThat(payload.sections.first { it.key == "hot_movies" }.videos).isNotEmpty()
        // 热门剧集失败 → 空列表
        assertThat(payload.sections.first { it.key == "hot_tv_shows" }.videos).isEmpty()
        // 新番放送正常（走 recommends 而非 getCategoryData）
        assertThat(payload.sections.first { it.key == "bangumi_calendar" }.videos).isNotEmpty()
        // 热门综艺正常
        assertThat(payload.sections.first { it.key == "hot_shows" }.videos).isNotEmpty()
    }

    /**
     * 首页请求的 Douban 参数应与分类 Tab 默认参数一致，确保缓存命中。
     */
    @Test
    fun loadHome_usesCategoryTabEquivalentParams() = runTest {
        val recordedParams = java.util.Collections.synchronizedList(mutableListOf<DoubanCategoryParams>())
        val repository = TvHomeRepository(
            playbackRepository = TvPlaybackRepository(continueWatching = emptyList()),
            doubanRepository = DoubanRepository(api = object : FakeHomeDoubanApi() {
                override suspend fun getCategoryData(
                    kind: String, start: Int, limit: Int, category: String, type: String,
                ): DoubanCategoryResponse {
                    recordedParams.add(
                        DoubanCategoryParams(kind = kind, category = category, type = type)
                    )
                    return super.getCategoryData(kind, start, limit, category, type)
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
                    recordedParams.add(
                        DoubanCategoryParams(kind = kind, sort = sort)
                    )
                    return super.getRecommends(kind, refresh, start, count, selectedCategories, uncollect, scoreRange, tags, sort)
                }
            }),
        )

        repository.loadHome()

        // 热门电影 → 对齐 Movie Tab 简单模式 (kind=movie, category=热门)
        val movieParam = recordedParams.find { it.kind == "movie" }
        assertThat(movieParam).isNotNull()
        assertThat(movieParam!!.category).isEqualTo("热门")

        // 热门剧集 → 对齐 TV Tab 简单模式 (kind=tv, category=最近热门)
        val tvParam = recordedParams.find { it.kind == "tv" && it.category == "最近热门" }
        assertThat(tvParam).isNotNull()

        // 热门综艺 → 对齐 Variety Tab 简单模式 (kind=tv, category=show)
        val showParam = recordedParams.find { it.kind == "tv" && it.category == "show" }
        assertThat(showParam).isNotNull()
    }
}

/**
 * 豆瓣代理 API 测试替身 —— 返回固定测试数据。
 */
private open class FakeHomeDoubanApi : SeleneDoubanApi {
    private val testPic = org.moontechlab.selene.tv.core.network.model.DoubanPic(
        normal = "test.jpg",
        large = "test-lg.jpg",
    )
    private val testRating = org.moontechlab.selene.tv.core.network.model.DoubanRating(value = 8.5)

    override suspend fun getCategoryData(
        kind: String,
        start: Int,
        limit: Int,
        category: String,
        type: String,
    ): DoubanCategoryResponse {
        return DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "test-$kind-$category",
                    title = "$category $kind",
                    pic = testPic,
                    rating = testRating,
                    cardSubtitle = "2025 / USA",
                ),
            ),
        )
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
        return DoubanCategoryResponse(
            items = listOf(
                DoubanMovieItem(
                    id = "rec-$kind",
                    title = "推荐 $kind",
                    pic = testPic,
                    rating = testRating,
                    cardSubtitle = "2025",
                ),
            ),
        )
    }
}
