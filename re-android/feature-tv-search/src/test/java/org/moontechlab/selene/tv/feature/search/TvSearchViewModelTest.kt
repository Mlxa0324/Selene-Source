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
    }
}
