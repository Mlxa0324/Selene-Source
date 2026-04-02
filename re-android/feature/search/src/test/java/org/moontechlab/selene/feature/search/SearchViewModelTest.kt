package org.moontechlab.selene.feature.search

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.model.VideoCardModel

@OptIn(ExperimentalCoroutinesApi::class)
class SearchViewModelTest {

    @Test
    fun `search updates query loading and result list`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = FakeSearchRepository()
        val viewModel = SearchViewModel(
            repository = repository,
            dispatchers = SearchTestDispatchers(dispatcher),
        )

        viewModel.updateQuery("三体")
        viewModel.search()

        assertTrue(viewModel.uiState.value.isLoading)
        advanceUntilIdle()

        assertEquals("三体", repository.lastKeyword)
        assertFalse(viewModel.uiState.value.isLoading)
        assertEquals(1, viewModel.uiState.value.results.size)
        assertEquals("搜索结果：三体", viewModel.uiState.value.results.first().title)
    }
}

private class FakeSearchRepository : SearchRepository() {
    var lastKeyword: String = ""

    override suspend fun search(keyword: String): List<VideoCardModel> {
        lastKeyword = keyword
        return listOf(
            VideoCardModel(
                id = "result-$keyword",
                title = "搜索结果：$keyword",
                posterUrl = "",
                sourceKey = "demo",
                sourceName = "Demo Source",
            )
        )
    }
}

private class SearchTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
