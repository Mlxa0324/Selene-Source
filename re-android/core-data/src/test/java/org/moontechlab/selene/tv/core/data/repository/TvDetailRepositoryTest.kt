package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.TvSearchCompleteEvent
import org.moontechlab.selene.tv.core.network.TvSearchSourceResultEvent
import org.moontechlab.selene.tv.core.network.TvSearchStartEvent
import org.moontechlab.selene.tv.core.network.TvSearchStreamEvent
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * 校验 TV 详情仓库映射契约。
 */
class TvDetailRepositoryTest {
    /**
     * 精准详情接口应映射成详情页可播放模型。
     */
    @Test
    fun loadDetail_maps_remote_detail_to_playable_model() = runTest {
        val calls = mutableListOf<Pair<String, String>>()
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    calls += source to id
                    return TvSearchResultResponse(
                        id = "video-1",
                        title = "详情影片",
                        poster = "https://img.test/poster.jpg",
                        episodes = listOf("https://cdn.test/1.m3u8", "https://cdn.test/2.m3u8"),
                        episodeTitles = listOf("第 1 集", "第 2 集"),
                        source = "source-a",
                        sourceName = "线路 A",
                        videoClass = "剧情,运动",
                        year = "2026",
                        remarks = "更新至20集",
                        qualityTag = "更新至20集",
                        description = "剧情简介",
                        typeName = "国产剧",
                        doubanId = 35267208,
                        rate = "8.6",
                    )
                }
            },
        )

        val detail = repository.loadDetail(source = "source-a", id = "video-1")

        assertThat(calls).containsExactly("source-a" to "video-1")
        assertThat(detail?.id).isEqualTo("video-1")
        assertThat(detail?.title).isEqualTo("详情影片")
        assertThat(detail?.posterUrl).isEqualTo("https://img.test/poster.jpg")
        assertThat(detail?.year).isEqualTo("2026")
        assertThat(detail?.typeName).isEqualTo("国产剧")
        assertThat(detail?.categories).containsExactly("国产剧", "剧情", "运动").inOrder()
        assertThat(detail?.remarks).isEqualTo("更新至20集")
        assertThat(detail?.qualityTag).isEqualTo("更新至20集")
        assertThat(detail?.rating).isEqualTo("8.6")
        assertThat(detail?.doubanId).isEqualTo("35267208")
        assertThat(detail?.sourceName).isEqualTo("线路 A")
        assertThat(detail?.description).isEqualTo("剧情简介")
        assertThat(detail?.sources?.first()?.id).isEqualTo("source-a::video-1")
        assertThat(detail?.sources?.first()?.source).isEqualTo("source-a")
        assertThat(detail?.sources?.first()?.videoId).isEqualTo("video-1")
        assertThat(detail?.sources?.first()?.episodes?.map { episode -> episode.title })
            .containsExactly("第 1 集", "第 2 集")
            .inOrder()
        assertThat(detail?.sources?.first()?.episodes?.map { episode -> episode.url })
            .containsExactly("https://cdn.test/1.m3u8", "https://cdn.test/2.m3u8")
            .inOrder()
    }


    /**
     * 详情映射应透传分类/更新字段，并过滤 unknown 年份哨兵。
     */
    @Test
    fun loadDetail_maps_categories_and_filters_unknown_year() = runTest {
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    return TvSearchResultResponse(
                        id = "video-meta",
                        title = "灿如繁星",
                        episodes = listOf("https://cdn.test/1.m3u8"),
                        episodeTitles = listOf("第01集"),
                        source = "source-a",
                        sourceName = "爱奇艺",
                        videoClass = "剧情,运动",
                        year = "unknown",
                        remarks = "更新至20集",
                        qualityTag = "更新至20集",
                        description = "青春热血",
                        typeName = "国产剧",
                        rate = "0",
                    )
                }
            },
        )

        val detail = repository.loadDetail(source = "source-a", id = "video-meta")

        assertThat(detail?.year).isEqualTo("")
        assertThat(detail?.rating).isEqualTo("")
        assertThat(detail?.typeName).isEqualTo("国产剧")
        assertThat(detail?.categories).containsExactly("国产剧", "剧情", "运动").inOrder()
        assertThat(detail?.remarks).isEqualTo("更新至20集")
        assertThat(detail?.qualityTag).isEqualTo("更新至20集")
    }

    /**
     * 详情映射必须过滤空播放地址，避免详情页把脏剧集误判成可播线路。
     */
    @Test
    fun loadDetail_filters_blank_episode_urls_from_remote_detail() = runTest {
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    return TvSearchResultResponse(
                        id = "video-blank",
                        title = "空地址影片",
                        episodes = listOf("", "   ", "https://cdn.test/3.m3u8"),
                        episodeTitles = listOf("无效 1", "无效 2", "正片"),
                        source = "source-a",
                        sourceName = "线路 A",
                    )
                }
            },
        )

        val detail = repository.loadDetail(source = "source-a", id = "video-blank")

        assertThat(detail?.sources?.first()?.episodes?.map { episode -> episode.title })
            .containsExactly("正片")
        assertThat(detail?.sources?.first()?.episodes?.map { episode -> episode.url })
            .containsExactly("https://cdn.test/3.m3u8")
    }

    /**
     * 缺少 source 或 id 时不发起无效详情请求。
     */
    @Test
    fun loadDetail_returns_null_when_identity_missing() = runTest {
        var detailCalls = 0
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    detailCalls += 1
                    return TvSearchResultResponse(id = id, title = "不应请求")
                }
            },
        )

        val detail = repository.loadDetail(source = "", id = "video-1")

        assertThat(detail).isNull()
        assertThat(detailCalls).isEqualTo(0)
    }

    /**
     * 精准详情失败时应继续按标题补源，避免首页或分类卡片进入详情页后无数据。
     */
    @Test
    fun loadDetailBySearchTitle_recovers_when_exact_detail_unavailable() = runTest {
        val detailCalls = mutableListOf<Pair<String, String>>()
        val queries = mutableListOf<String>()
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    detailCalls += source to id
                    error("详情接口暂不可用")
                }

                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "search-video-1",
                                title = "  详情影片 ",
                                poster = "https://img.test/search.jpg",
                                episodes = listOf("https://cdn-search.test/1.m3u8"),
                                episodeTitles = listOf("正片"),
                                source = "source-b",
                                sourceName = "线路 B",
                                year = "2026",
                                description = "搜索详情简介",
                                doubanId = 35267208,
                            ),
                        ),
                    )
                }
            },
        )

        val exactDetail = runCatching {
            repository.loadDetail(source = "source-a", id = "video-1")
        }.getOrNull()
        val fallbackDetail = exactDetail ?: repository.loadDetailBySearchTitle(
            title = "详情影片",
            fallbackId = "video-1",
        )

        assertThat(detailCalls).containsExactly("source-a" to "video-1")
        assertThat(queries).containsExactly("详情影片")
        assertThat(fallbackDetail?.title).isEqualTo("详情影片")
        assertThat(fallbackDetail?.description).isEqualTo("搜索详情简介")
        assertThat(fallbackDetail?.posterUrl).isEqualTo("https://img.test/search.jpg")
        assertThat(fallbackDetail?.doubanId).isEqualTo("35267208")
        assertThat(fallbackDetail?.sources?.map { source -> source.id })
            .containsExactly("source-b::search-video-1")
    }

    /**
     * Douban 或空来源入口没有可直连身份时应直接走标题补源，不请求详情接口。
     */
    @Test
    fun loadDetailBySearchTitle_supports_unplayable_entry_identity_without_detail_call() = runTest {
        var detailCalls = 0
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getDetail(
                    source: String,
                    id: String,
                ): TvSearchResultResponse {
                    detailCalls += 1
                    return TvSearchResultResponse(id = id, source = source)
                }

                override suspend fun search(query: String): TvSearchResponse {
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "playable-1",
                                title = "豆瓣影片",
                                episodes = listOf("https://cdn.test/1.m3u8"),
                                source = "source-playable",
                                sourceName = "可播线路",
                            ),
                        ),
                    )
                }
            },
        )

        val exactDetail = repository.loadDetail(
            source = "Douban",
            id = "douban-35267208",
        )
        val detail = exactDetail ?: repository.loadDetailBySearchTitle(
            title = "豆瓣影片",
            fallbackId = "douban-35267208",
        )

        assertThat(exactDetail).isNull()
        assertThat(detailCalls).isEqualTo(0)
        assertThat(detail?.id).isEqualTo("playable-1")
        assertThat(detail?.sources?.first()?.source).isEqualTo("source-playable")
    }

    /**
     * 后台补源应按标题搜索并按 source+id 保留多线路。
     */
    @Test
    fun loadMoreSources_maps_search_results_to_distinct_sources() = runTest {
        val queries = mutableListOf<String>()
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "video-1",
                                title = "详情影片",
                                episodes = listOf("https://cdn-a.test/1.m3u8"),
                                source = "source-a",
                                sourceName = "线路 A",
                                year = "2026",
                            ),
                            TvSearchResultResponse(
                                id = "video-2",
                                title = "详情影片",
                                episodes = listOf("https://cdn-b.test/1.m3u8"),
                                source = "source-a",
                                sourceName = "线路 A 备用",
                                year = "2026",
                            ),
                            TvSearchResultResponse(
                                id = "other",
                                title = "别的影片",
                                episodes = listOf("https://cdn-other.test/1.m3u8"),
                                source = "source-c",
                                sourceName = "不应出现",
                                year = "2026",
                            ),
                        ),
                    )
                }
            },
        )
        val detail = org.moontechlab.selene.tv.core.data.model.TvVideoDetail(
            id = "video-1",
            title = "详情影片",
            description = "剧情简介",
            year = "2026",
            sources = emptyList(),
        )

        val sources = repository.loadMoreSources(detail)

        assertThat(queries).containsExactly("详情影片")
        assertThat(sources.map { source -> source.id })
            .containsExactly("source-a::video-1", "source-a::video-2")
            .inOrder()
        assertThat(sources.map { source -> source.name })
            .containsExactly("线路 A", "线路 A 备用")
            .inOrder()
    }

    /**
     * 标题补源接入 SSE 后，应在事件到达时先回调增量线路，再收敛最终列表。
     */
    @Test
    fun loadMoreSourcesByEntry_emits_incremental_sources_from_sse_stream() = runTest {
        val incrementalBatches = mutableListOf<List<String>>()
        val repository = TvDetailRepository(
            api = FakeSeleneTvApi(),
            searchStreamClient = object : SeleneTvSearchStreamClient {
                override suspend fun search(
                    query: String,
                    onEvent: (TvSearchStreamEvent) -> Unit,
                ) {
                    onEvent(TvSearchStartEvent(query = query, totalSources = 2, timestamp = 1L))
                    onEvent(
                        TvSearchSourceResultEvent(
                            source = "source-a",
                            sourceName = "线路 A",
                            results = listOf(
                                TvSearchResultResponse(
                                    id = "video-1",
                                    title = "详情影片",
                                    episodes = listOf("https://cdn-a.test/1.m3u8"),
                                    source = "source-a",
                                    sourceName = "线路 A",
                                    year = "2026",
                                ),
                            ),
                            timestamp = 2L,
                        ),
                    )
                    onEvent(
                        TvSearchSourceResultEvent(
                            source = "source-other",
                            sourceName = "无关线路",
                            results = listOf(
                                TvSearchResultResponse(
                                    id = "video-other",
                                    title = "别的影片",
                                    episodes = listOf("https://cdn-other.test/1.m3u8"),
                                    source = "source-other",
                                    sourceName = "无关线路",
                                    year = "2026",
                                ),
                            ),
                            timestamp = 3L,
                        ),
                    )
                    onEvent(
                        TvSearchSourceResultEvent(
                            source = "source-b",
                            sourceName = "线路 B",
                            results = listOf(
                                TvSearchResultResponse(
                                    id = "video-2",
                                    title = "详情影片",
                                    episodes = listOf(
                                        "https://cdn-b.test/1.m3u8",
                                        "https://cdn-b.test/2.m3u8",
                                    ),
                                    source = "source-b",
                                    sourceName = "线路 B",
                                    year = "2026",
                                ),
                            ),
                            timestamp = 4L,
                        ),
                    )
                    onEvent(TvSearchCompleteEvent(totalResults = 2, completedSources = 2, timestamp = 5L))
                }
            },
        )

        val sources = repository.loadMoreSourcesByEntry(
            title = "详情影片",
            searchTitle = "详情影片",
            year = "2026",
            onIncremental = { batch ->
                incrementalBatches += batch.map { source -> source.id }
            },
        )

        assertThat(incrementalBatches)
            .containsExactly(
                listOf("source-a::video-1"),
                listOf("source-b::video-2"),
            )
            .inOrder()
        assertThat(sources.map { source -> source.id })
            .containsExactly("source-a::video-1", "source-b::video-2")
            .inOrder()
    }

    /**
     * SSE 建链失败且未收到任何结果时，标题补源必须回退批量搜索，避免整条链路直接报废。
     */
    @Test
    fun loadMoreSourcesByEntry_falls_back_to_batch_search_when_sse_fails_before_results() = runTest {
        val queries = mutableListOf<String>()
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "video-1",
                                title = "详情影片",
                                episodes = listOf("https://cdn-a.test/1.m3u8"),
                                source = "source-a",
                                sourceName = "线路 A",
                                year = "2026",
                            ),
                        ),
                    )
                }
            },
            searchStreamClient = object : SeleneTvSearchStreamClient {
                override suspend fun search(
                    query: String,
                    onEvent: (TvSearchStreamEvent) -> Unit,
                ) {
                    error("SSE 连接失败")
                }
            },
        )

        val sources = repository.loadMoreSourcesByEntry(
            title = "详情影片",
            searchTitle = "详情影片",
            year = "2026",
            onIncremental = {},
        )

        assertThat(queries).containsExactly("详情影片")
        assertThat(sources.map { source -> source.id }).containsExactly("source-a::video-1")
    }

    /**
     * 已有详情豆瓣 ID 时，不应再次发起搜索还原。
     */
    @Test
    fun resolveDoubanId_prefers_detail_douban_id_without_search() = runTest {
        var searchCalls = 0
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    searchCalls += 1
                    return TvSearchResponse(results = emptyList())
                }
            },
        )
        val detail = TvVideoDetail(
            id = "video-1",
            doubanId = "35267208",
            title = "详情影片",
            description = "剧情简介",
            sources = emptyList(),
        )

        val doubanId = repository.resolveDoubanId(
            detail = detail,
            entrySource = "source-a",
            entryVideoId = "video-1",
            title = "详情影片",
            searchTitle = "详情影片",
            year = "2026",
        )

        assertThat(doubanId).isEqualTo("35267208")
        assertThat(searchCalls).isEqualTo(0)
    }

    /**
     * 详情未携带豆瓣 ID 时，应按 Flutter 手机端逻辑从同名搜索结果中还原出现次数最多的豆瓣 ID。
     */
    @Test
    fun resolveDoubanId_uses_most_common_search_result_douban_id() = runTest {
        val queries = mutableListOf<String>()
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    queries += query
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "video-a",
                                title = "测试影片",
                                year = "2026",
                                doubanId = 10101,
                            ),
                            TvSearchResultResponse(
                                id = "video-b",
                                title = "测试影片",
                                year = "2026",
                                doubanId = 20202,
                            ),
                            TvSearchResultResponse(
                                id = "video-c",
                                title = "测试影片",
                                year = "2026",
                                doubanId = 10101,
                            ),
                            TvSearchResultResponse(
                                id = "video-d",
                                title = "别的影片",
                                year = "2026",
                                doubanId = 99999,
                            ),
                        ),
                    )
                }
            },
        )

        val doubanId = repository.resolveDoubanId(
            detail = null,
            entrySource = "source-a",
            entryVideoId = "video-1",
            title = "测试影片",
            searchTitle = "测试影片 原名",
            year = "2026",
        )

        assertThat(queries).containsExactly("测试影片 原名")
        assertThat(doubanId).isEqualTo("10101")
    }

    /**
     * 标题补源应过滤同名影片并在年份缺失时允许匹配，重复线路保留集数更多的一条。
     */
    @Test
    fun loadDetailBySearchTitle_filters_title_and_keeps_source_with_more_episodes() = runTest {
        val repository = TvDetailRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun search(query: String): TvSearchResponse {
                    return TvSearchResponse(
                        results = listOf(
                            TvSearchResultResponse(
                                id = "video-a",
                                title = "测 试 影 片",
                                episodes = listOf("https://cdn-a.test/1.m3u8"),
                                source = "source-a",
                                sourceName = "线路 A",
                                year = "",
                            ),
                            TvSearchResultResponse(
                                id = "video-a",
                                title = "测试影片",
                                episodes = listOf(
                                    "https://cdn-a.test/1.m3u8",
                                    "https://cdn-a.test/2.m3u8",
                                ),
                                source = "source-a",
                                sourceName = "线路 A 高清",
                                year = "unknown",
                            ),
                            TvSearchResultResponse(
                                id = "other",
                                title = "别的影片",
                                episodes = listOf("https://cdn-other.test/1.m3u8"),
                                source = "source-b",
                                sourceName = "不应出现",
                                year = "2026",
                            ),
                        ),
                    )
                }
            },
        )

        val detail = repository.loadDetailBySearchTitle(
            title = "测试影片",
            fallbackId = "fallback-id",
            year = "2026",
        )

        assertThat(detail?.sources?.map { source -> source.id })
            .containsExactly("source-a::video-a")
        assertThat(detail?.sources?.first()?.episodes?.map { episode -> episode.url })
            .containsExactly("https://cdn-a.test/1.m3u8", "https://cdn-a.test/2.m3u8")
            .inOrder()
        assertThat(detail?.sourceName).isEqualTo("线路 A 高清")
    }
}
