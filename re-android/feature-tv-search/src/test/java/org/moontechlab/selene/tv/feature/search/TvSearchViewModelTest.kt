package org.moontechlab.selene.tv.feature.search

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvSearchPayload
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 搜索状态管理契约。
 */
class TvSearchViewModelTest {
    /**
     * 提交搜索词后应写入历史并展示搜索结果分组。
     */
    @Test
    fun submitQuery_updates_history_and_search_results() = runTest {
        val viewModel = TvSearchViewModel(
            search = { query ->
                TvSearchPayload(
                    query = query,
                    results = listOf(
                        TvVideoCard(id = "video-1", title = "剑来", posterUrl = ""),
                    ),
                )
            },
        )

        viewModel.submitQuery("剑来")

        assertThat(viewModel.state.value.searchHistory).contains("剑来")
        assertThat(viewModel.state.value.resultGroups).isNotEmpty()
        assertThat(viewModel.state.value.errorMessage).isNull()
    }

    /**
     * 初始状态应提供 TV 搜索热词，保证页面空数据时仍有可选入口。
     */
    @Test
    fun initialState_exposes_hot_queries() {
        val viewModel = TvSearchViewModel(
            search = { query ->
                TvSearchPayload(query = query, results = emptyList())
            },
        )

        assertThat(viewModel.state.value.hotQueries).isNotEmpty()
    }

    /**
     * 重复搜索同一关键词时历史只保留最新一条。
     */
    @Test
    fun submitQuery_deduplicates_history() = runTest {
        val viewModel = TvSearchViewModel(
            search = { query ->
                TvSearchPayload(query = query, results = emptyList())
            },
        )

        viewModel.submitQuery("剑来")
        viewModel.submitQuery("  剑来  ")

        assertThat(viewModel.state.value.searchHistory).containsExactly("剑来")
    }

    /**
     * 搜索成功但无结果时应展示空结果分组而非错误态。
     */
    @Test
    fun submitQuery_keeps_empty_result_as_success_state() = runTest {
        val viewModel = TvSearchViewModel(
            search = { query ->
                TvSearchPayload(query = query, results = emptyList())
            },
        )

        viewModel.submitQuery("不存在")

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.errorMessage).isNull()
        assertThat(viewModel.state.value.resultGroups.single().videos).isEmpty()
    }

    /**
     * 搜索失败时应展示错误态，不能静默显示空列表。
     */
    @Test
    fun submitQuery_exposes_failure_message() = runTest {
        val viewModel = TvSearchViewModel(
            search = {
                error("搜索接口失败")
            },
        )

        viewModel.submitQuery("剑来")

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.errorMessage).contains("搜索接口失败")
        assertThat(viewModel.state.value.resultGroups).isEmpty()
    }
}
