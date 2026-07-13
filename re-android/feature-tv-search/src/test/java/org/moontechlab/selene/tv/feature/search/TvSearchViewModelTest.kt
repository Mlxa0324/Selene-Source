package org.moontechlab.selene.tv.feature.search

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.TvSearchCompleteEvent
import org.moontechlab.selene.tv.core.network.TvSearchSourceResultEvent
import org.moontechlab.selene.tv.core.network.TvSearchStartEvent
import org.moontechlab.selene.tv.core.network.TvSearchStreamEvent
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * 校验 TV 搜索状态机，对齐 Flutter TV 搜索页。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvSearchViewModelTest {
    /**
     * 首屏 bootstrap 应写入历史、热词和推荐。
     */
    @Test
    fun bootstrap_loads_history_hot_and_recommends() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val viewModel = TvSearchViewModel(
            loadBootstrap = {
                TvSearchBootstrapData(
                    searchHistory = listOf("剑来"),
                    hotQueries = listOf("热门电影"),
                    recommendCards = listOf(card("r1", "推荐1")),
                )
            },
            backgroundScope = TestScope(dispatcher),
        )

        viewModel.bootstrap()
        advanceUntilIdle()

        assertThat(viewModel.state.value.searchHistory).containsExactly("剑来")
        assertThat(viewModel.state.value.hotQueries).contains("热门电影")
        assertThat(viewModel.state.value.recommendCards.map { it.id }).containsExactly("r1")
        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Home)
    }

    /**
     * 输入纯字母数字应进入联想面板并触发联想加载。
     */
    @Test
    fun appendChar_enters_suggestion_panel_for_letter_query() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val viewModel = TvSearchViewModel(
            loadSuggestions = { query -> listOf("${query}片", "测试$query") },
            backgroundScope = TestScope(dispatcher),
        )

        viewModel.appendChar("J")
        viewModel.appendChar("L")
        runCurrent()
        advanceTimeBy(180L)
        advanceUntilIdle()

        assertThat(viewModel.state.value.query).isEqualTo("JL")
        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Suggestions)
        assertThat(viewModel.state.value.suggestions).contains("JL片")
        assertThat(viewModel.state.value.isSuggestionLoading).isFalse()
    }

    /**
     * 历史词应直接进入结果面板。
     */
    @Test
    fun submitHistoryQuery_enters_results_and_persists_history() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val viewModel = TvSearchViewModel(
            batchSearch = { query -> listOf(card("1", query)) },
            backgroundScope = TestScope(dispatcher),
        )

        viewModel.submitHistoryQuery("剑来")
        advanceUntilIdle()

        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Results)
        assertThat(viewModel.state.value.resultCards.map { it.title }).containsExactly("剑来")
        assertThat(viewModel.state.value.searchHistory.first()).isEqualTo("剑来")
        assertThat(viewModel.state.value.isSearchResultLoading).isFalse()
    }

    /**
     * SSE 流式结果应按片名聚合，并刷新进度。
     */
    @Test
    fun submitCurrentQuery_aggregates_sse_results_by_title() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val stream = object : SeleneTvSearchStreamClient {
            override suspend fun search(
                query: String,
                onEvent: (TvSearchStreamEvent) -> Unit,
            ) {
                onEvent(TvSearchStartEvent(query = query, totalSources = 2, timestamp = 1L))
                onEvent(
                    TvSearchSourceResultEvent(
                        source = "a",
                        sourceName = "源A",
                        results = listOf(
                            TvSearchResultResponse(
                                id = "1",
                                title = "剑来",
                                poster = "p1",
                                episodes = listOf("e1"),
                                source = "a",
                                sourceName = "源A",
                            ),
                        ),
                        timestamp = 2L,
                    ),
                )
                onEvent(
                    TvSearchSourceResultEvent(
                        source = "b",
                        sourceName = "源B",
                        results = listOf(
                            TvSearchResultResponse(
                                id = "2",
                                title = "剑来",
                                poster = "p2",
                                episodes = listOf("e1", "e2"),
                                source = "b",
                                sourceName = "源B",
                            ),
                        ),
                        timestamp = 3L,
                    ),
                )
                onEvent(TvSearchCompleteEvent(totalResults = 2, completedSources = 2, timestamp = 4L))
            }
        }
        val viewModel = TvSearchViewModel(
            searchStream = stream,
            backgroundScope = TestScope(dispatcher),
        )
        viewModel.setQuery("剑来")
        viewModel.submitCurrentQuery()
        advanceUntilIdle()

        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Results)
        assertThat(viewModel.state.value.resultCards).hasSize(1)
        assertThat(viewModel.state.value.resultCards.single().title).isEqualTo("剑来")
        assertThat(viewModel.state.value.resultCards.single().totalEpisodes).isEqualTo(2)
        assertThat(viewModel.state.value.searchCompletedResourceCount).isEqualTo(2)
        assertThat(viewModel.state.value.isSearchResultLoading).isFalse()
    }

    /**
     * 返回键应先退出结果并恢复联想，再回首页。
     */
    @Test
    fun handleBack_restores_suggestion_then_home() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val viewModel = TvSearchViewModel(
            loadSuggestions = { listOf("剑来") },
            batchSearch = { listOf(card("1", "剑来")) },
            backgroundScope = TestScope(dispatcher),
        )

        viewModel.appendChar("J")
        advanceTimeBy(180L)
        advanceUntilIdle()
        viewModel.submitSuggestionQuery("剑来")
        advanceUntilIdle()
        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Results)

        assertThat(viewModel.handleBack()).isTrue()
        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Suggestions)

        assertThat(viewModel.handleBack()).isTrue()
        assertThat(viewModel.state.value.panelMode).isEqualTo(TvSearchPanelMode.Home)
        assertThat(viewModel.state.value.query).isEmpty()

        assertThat(viewModel.handleBack()).isFalse()
    }

    /**
     * 纯工具函数：同片名结果应聚合为一张卡片。
     */
    @Test
    fun aggregateSearchResults_groups_same_title() {
        val cards = aggregateSearchResults(
            listOf(
                TvSearchResultResponse(id = "1", title = "剑 来", episodes = listOf("1"), sourceName = "A"),
                TvSearchResultResponse(id = "2", title = "剑来", episodes = listOf("1", "2"), sourceName = "B"),
            ),
        )
        assertThat(cards).hasSize(1)
        assertThat(cards.single().totalEpisodes).isEqualTo(2)
    }

    private fun card(id: String, title: String): TvVideoCard {
        return TvVideoCard(id = id, title = title, posterUrl = "")
    }
}
