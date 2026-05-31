package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * 校验 TV 详情页状态管理契约。
 */
class TvDetailViewModelTest {
    /**
     * 详情加载后应选中首个可用来源和首个可用剧集。
     */
    @Test
    fun loadDetail_sets_current_source_and_current_episode() = runTest {
        val viewModel = TvDetailViewModel(
            loadInitialDetail = { videoId ->
                TvVideoDetail(
                    id = videoId,
                    title = "测试影片",
                    description = "测试简介",
                    sources = listOf(
                        TvVideoSource(
                            id = "source-a",
                            name = "线路 A",
                            episodes = listOf(
                                TvEpisode(id = "ep-1", title = "第 1 集", url = "https://cdn.test/1.m3u8"),
                            ),
                        ),
                    ),
                )
            },
        )

        viewModel.load(videoId = "video-1")

        assertThat(viewModel.state.value.currentSourceId).isNotEmpty()
        assertThat(viewModel.state.value.currentEpisodeId).isNotEmpty()
    }

    /**
     * 详情补源后应去重合并同线路剧集。
     */
    @Test
    fun loadDetail_merges_more_sources_and_deduplicates_episodes() = runTest {
        val viewModel = TvDetailViewModel(
            loadInitialDetail = { videoId ->
                TvVideoDetail(
                    id = videoId,
                    title = "测试影片",
                    description = "测试简介",
                    sources = listOf(
                        TvVideoSource(
                            id = "source-a",
                            name = "线路 A",
                            episodes = listOf(
                                TvEpisode(id = "ep-1", title = "第 1 集", url = "https://cdn.test/1.m3u8"),
                            ),
                        ),
                    ),
                )
            },
            loadMoreSources = { _, _ ->
                listOf(
                    TvVideoSource(
                        id = "source-a",
                        name = "线路 A",
                        episodes = listOf(
                            TvEpisode(id = "ep-1", title = "第 1 集", url = "https://cdn.test/1.m3u8"),
                            TvEpisode(id = "ep-2", title = "第 2 集", url = "https://cdn.test/2.m3u8"),
                        ),
                    ),
                    TvVideoSource(
                        id = "source-b",
                        name = "线路 B",
                        episodes = listOf(
                            TvEpisode(id = "b-1", title = "第 1 集", url = "https://cdn-b.test/1.m3u8"),
                        ),
                    ),
                )
            },
        )

        viewModel.load(videoId = "video-1")

        val sources = viewModel.state.value.detail?.sources.orEmpty()
        assertThat(sources.map { source -> source.id }).containsExactly("source-a", "source-b").inOrder()
        assertThat(sources.first().episodes.map { episode -> episode.id }).containsExactly("ep-1", "ep-2").inOrder()
        assertThat(viewModel.state.value.isLoadingMoreSources).isFalse()
    }

    /**
     * 详情页应按续播剧集构建播放器请求。
     */
    @Test
    fun loadDetail_builds_playback_request_from_resume_episode() = runTest {
        val viewModel = TvDetailViewModel(
            loadInitialDetail = { videoId ->
                TvVideoDetail(
                    id = videoId,
                    title = "测试影片",
                    description = "测试简介",
                    sources = listOf(
                        TvVideoSource(
                            id = "source-a",
                            name = "线路 A",
                            episodes = listOf(
                                TvEpisode(id = "ep-1", title = "第 1 集", url = "https://cdn.test/1.m3u8"),
                                TvEpisode(id = "ep-2", title = "第 2 集", url = "https://cdn.test/2.m3u8"),
                            ),
                        ),
                    ),
                )
            },
            loadResumeEpisodeId = { "ep-2" },
        )

        viewModel.load(videoId = "video-1")

        val request = viewModel.state.value.playbackRequest
        assertThat(request?.episodeId).isEqualTo("ep-2")
        assertThat(request?.url).isEqualTo("https://cdn.test/2.m3u8")
    }
}
