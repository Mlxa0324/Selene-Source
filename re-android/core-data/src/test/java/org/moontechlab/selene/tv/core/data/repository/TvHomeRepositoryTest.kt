package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeSectionResponse

/**
 * 校验 TV 首页仓库的数据聚合契约。
 */
class TvHomeRepositoryTest {
    /**
     * 首页加载应聚合继续观看和热门分区。
     */
    @Test
    fun loadHome_aggregates_continue_watching_and_hot_sections() = runTest {
        val repository = TvHomeRepository(
            api = FakeSeleneTvApi(),
            playbackRepository = TvPlaybackRepository(
                continueWatching = listOf(TvVideoCard(id = "resume-1", title = "续看", posterUrl = "")),
            ),
        )

        val payload = repository.loadHome()

        assertThat(payload.sections.map { it.key }).containsAtLeast(
            "continue_watching",
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        )
    }
}

/**
 * 首页接口测试替身。
 */
private class FakeSeleneTvApi : SeleneTvApi {
    override suspend fun getDashboard(): TvHomeResponse {
        return TvHomeResponse(
            sections = listOf(
                TvHomeSectionResponse(key = "hot_movies", title = "热门电影", videos = emptyList()),
                TvHomeSectionResponse(key = "hot_tv_shows", title = "热门剧集", videos = emptyList()),
                TvHomeSectionResponse(key = "bangumi_calendar", title = "新番放送", videos = emptyList()),
                TvHomeSectionResponse(key = "hot_shows", title = "热门综艺", videos = emptyList()),
            ),
        )
    }
}
