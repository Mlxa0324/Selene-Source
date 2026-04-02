package org.moontechlab.selene.feature.history

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository

@OptIn(ExperimentalCoroutinesApi::class)
class HistoryViewModelTest {

    @Test
    fun `remove deletes watch record from repository backed timeline`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = PlaybackHistoryRepository(
            initialItems = listOf(
                PlaybackHistoryItem(
                    videoId = "history-001",
                    title = "三体",
                    episodeTitle = "第4集",
                    playUrl = "https://example.com/santi-4.m3u8",
                    progressPercent = 67,
                ),
                PlaybackHistoryItem(
                    videoId = "history-002",
                    title = "流浪地球 2",
                    episodeTitle = "正片",
                    playUrl = "https://example.com/wandering-earth-2.m3u8",
                    progressPercent = 94,
                ),
            ),
        )
        val viewModel = HistoryViewModel(
            repository = repository,
            dispatchers = HistoryTestDispatchers(dispatcher),
        )
        advanceUntilIdle()

        assertEquals(2, viewModel.uiState.value.items.size)
        assertEquals("三体", viewModel.uiState.value.items.first().title)

        viewModel.remove("history-001")
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.items.size)
        assertEquals("流浪地球 2", viewModel.uiState.value.items.first().title)
    }
}

private class HistoryTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
