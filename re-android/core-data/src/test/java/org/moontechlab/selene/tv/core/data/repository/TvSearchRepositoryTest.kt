package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * 校验 TV 搜索仓库映射契约。
 */
class TvSearchRepositoryTest {
    /**
     * 搜索结果应转成页面可展示卡片。
     */
    @Test
    fun search_maps_remote_results_to_payload() = runTest {
        val queries = mutableListOf<String>()
        val repository = TvSearchRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "video_a",
                                title = "搜索影片",
                                poster = "poster.jpg",
                                episodes = listOf("1.m3u8", "2.m3u8"),
                                source = "source_a",
                                sourceName = "线路 A",
                                year = "2026",
                            ),
                        ),
                    )
                }
            },
        )

        val payload = repository.search("  搜索影片  ")

        assertThat(queries).containsExactly("搜索影片")
        assertThat(payload.query).isEqualTo("搜索影片")
        assertThat(payload.results).hasSize(1)
        assertThat(payload.results.first().id).isEqualTo("video_a")
        assertThat(payload.results.first().totalEpisodes).isEqualTo(2)
        assertThat(payload.results.first().sourceName).isEqualTo("线路 A")
    }

    /**
     * 搜索资源接口应保留禁用状态。
     */
    @Test
    fun readSearchResources_maps_disabled_flag() = runTest {
        val repository = TvSearchRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getSearchResources(): List<TvSearchResourceResponse> {
                    return listOf(
                        TvSearchResourceResponse(
                            key = "api_a",
                            name = "资源 A",
                            api = "https://api.example.com",
                            detail = "https://detail.example.com",
                            from = "json",
                            disabled = true,
                        ),
                    )
                }
            },
        )

        val resources = repository.readSearchResources()

        assertThat(resources.first().key).isEqualTo("api_a")
        assertThat(resources.first().disabled).isTrue()
    }

    /**
     * 远端搜索异常不能被吞成空结果。
     */
    @Test
    fun search_keeps_remote_failure_visible() = runTest {
        val repository = TvSearchRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    error("搜索接口失败")
                }
            },
        )

        val error = runCatching { repository.search("影片") }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("搜索接口失败")
    }
}
