package org.moontechlab.selene.feature.home

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    @Test
    fun `home exposes recent history and favorite items`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val favoritesRepository = FavoritesRepository()
        val historyRepository = PlaybackHistoryRepository()
        val viewModel = HomeViewModel(
            favoritesRepository = favoritesRepository,
            historyRepository = historyRepository,
            dispatchers = HomeTestDispatchers(dispatcher),
        )

        favoritesRepository.toggle(
            FavoriteItem(
                videoId = "video-001",
                title = "三体",
                sourceName = "非凡影视",
                subtitle = "科幻",
            ),
        )
        historyRepository.record(
            PlaybackHistoryItem(
                videoId = "video-002",
                title = "凡人修仙传",
                episodeTitle = "第8集",
                playUrl = "https://example.com/2.m3u8",
                progressPercent = 66,
            ),
        )
        advanceUntilIdle()

        assertEquals("凡人修仙传", viewModel.uiState.value.continueWatching.first().title)
        assertEquals("三体", viewModel.uiState.value.favorites.first().title)
    }
}

private class HomeTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
