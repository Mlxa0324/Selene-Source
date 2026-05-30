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
            loadDetail = { videoId ->
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
}
