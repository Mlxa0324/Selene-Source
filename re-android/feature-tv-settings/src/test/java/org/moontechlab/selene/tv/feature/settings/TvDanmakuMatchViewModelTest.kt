package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验 TV 弹幕手动匹配状态管理契约。
 */
class TvDanmakuMatchViewModelTest {
    /**
     * 空搜索词必须进入正式错误态，避免请求无意义接口。
     */
    @Test
    fun submitSearch_rejects_blank_query() = runTest {
        val viewModel = TvDanmakuMatchViewModel(
            initialQuery = "",
            searchEpisodes = { error("不应请求空搜索词") },
        )

        viewModel.submitSearch()

        val state = viewModel.state.value
        assertThat(state.errorMessage).isEqualTo("请至少保留一个搜索字符")
        assertThat(state.results).isEmpty()
        assertThat(state.isLoading).isFalse()
    }

    /**
     * 搜索成功后必须展示动画候选和剧集候选，供遥控器继续确认。
     */
    @Test
    fun submitSearch_updates_results_from_search_callback() = runTest {
        val viewModel = TvDanmakuMatchViewModel(
            initialQuery = "测试影片",
            searchEpisodes = { query ->
                TvDanmakuSearchResult(
                    success = true,
                    errorMessage = "",
                    animes = listOf(
                        TvDanmakuSearchAnime(
                            animeId = 101,
                            animeTitle = "$query 第一季",
                            type = "tv",
                            typeDescription = "TV",
                            year = 2024,
                            episodes = listOf(
                                TvDanmakuSearchEpisode(
                                    episodeId = 9001,
                                    episodeTitle = "第 1 集",
                                ),
                            ),
                        ),
                    ),
                )
            },
        )

        viewModel.submitSearch()

        val state = viewModel.state.value
        assertThat(state.errorMessage).isNull()
        assertThat(state.results).hasSize(1)
        assertThat(state.results.first().animeTitle).isEqualTo("测试影片 第一季")
        assertThat(state.results.first().episodes.first().episodeId).isEqualTo(9001)
        assertThat(state.isLoading).isFalse()
    }

    /**
     * 搜索失败结果必须展示后端错误文案。
     */
    @Test
    fun submitSearch_uses_error_message_from_failed_result() = runTest {
        val viewModel = TvDanmakuMatchViewModel(
            initialQuery = "测试影片",
            searchEpisodes = {
                TvDanmakuSearchResult(
                    success = false,
                    errorMessage = "服务拒绝搜索",
                    animes = emptyList(),
                )
            },
        )

        viewModel.submitSearch()

        assertThat(viewModel.state.value.errorMessage).isEqualTo("服务拒绝搜索")
        assertThat(viewModel.state.value.results).isEmpty()
    }

    /**
     * 删字、清空和恢复片名必须复刻 Flutter TV 的遥控器文本调整习惯。
     */
    @Test
    fun query_actions_match_flutter_tv_remote_flow() {
        val viewModel = TvDanmakuMatchViewModel(initialQuery = "测试影片")

        viewModel.deleteLastCharacter()
        assertThat(viewModel.state.value.query).isEqualTo("测试影")

        viewModel.clearQuery()
        assertThat(viewModel.state.value.query).isEmpty()

        viewModel.restoreInitialQuery()
        assertThat(viewModel.state.value.query).isEqualTo("测试影片")
    }
}
