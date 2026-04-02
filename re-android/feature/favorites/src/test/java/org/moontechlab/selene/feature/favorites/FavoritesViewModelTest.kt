package org.moontechlab.selene.feature.favorites

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository

@OptIn(ExperimentalCoroutinesApi::class)
class FavoritesViewModelTest {

    @Test
    fun `toggle favorite removes entry from repository backed list`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = FavoritesRepository(
            initialItems = listOf(
                FavoriteItem(
                    videoId = "favorite-001",
                    title = "三体",
                    sourceName = "非凡影视",
                    subtitle = "科幻 / 已收藏",
                ),
                FavoriteItem(
                    videoId = "favorite-002",
                    title = "凡人修仙传",
                    sourceName = "动漫港",
                    subtitle = "动画 / 已收藏",
                ),
            ),
        )
        val viewModel = FavoritesViewModel(
            repository = repository,
            dispatchers = FavoritesTestDispatchers(dispatcher),
        )
        advanceUntilIdle()

        assertEquals(2, viewModel.uiState.value.items.size)
        val firstItemId = viewModel.uiState.value.items.first().videoId

        viewModel.toggleFavorite(firstItemId)
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.items.size)
        assertFalse(repository.isFavorite(firstItemId))
    }
}

private class FavoritesTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
