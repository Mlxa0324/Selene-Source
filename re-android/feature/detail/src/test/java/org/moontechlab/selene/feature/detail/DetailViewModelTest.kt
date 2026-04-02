package org.moontechlab.selene.feature.detail

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.model.VideoDetail
import org.moontechlab.selene.core.model.VideoEpisode

@OptIn(ExperimentalCoroutinesApi::class)
class DetailViewModelTest {

    @Test
    fun `load detail hydrates selected video`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = FakeDetailRepository()
        val favoritesRepository = FavoritesRepository()
        val viewModel = DetailViewModel(
            repository = repository,
            favoritesRepository = favoritesRepository,
            dispatchers = DetailTestDispatchers(dispatcher),
        )

        viewModel.load(id = "video-001", sourceKey = "demo")
        advanceUntilIdle()

        assertEquals("video-001", repository.lastId)
        assertEquals("demo", repository.lastSourceKey)
        assertNotNull(viewModel.uiState.value.detail)
        assertEquals("video-001", viewModel.uiState.value.detail?.id)
        assertFalse(viewModel.uiState.value.isFavorite)
    }

    @Test
    fun `toggle favorite writes through shared favorites repository`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = FakeDetailRepository()
        val favoritesRepository = FavoritesRepository()
        val viewModel = DetailViewModel(
            repository = repository,
            favoritesRepository = favoritesRepository,
            dispatchers = DetailTestDispatchers(dispatcher),
        )

        viewModel.load(id = "video-001", sourceKey = "demo")
        advanceUntilIdle()
        viewModel.toggleFavorite()

        assertTrue(viewModel.uiState.value.isFavorite)
        assertTrue(favoritesRepository.isFavorite("video-001"))

        val favorite = favoritesRepository.items.value.first()
        assertEquals("测试详情", favorite.title)
        assertEquals("demo", favorite.sourceKey)
        assertEquals("Demo Source", favorite.sourceName)
    }

    @Test
    fun `load detail marks item favorite when repository already contains video`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = FakeDetailRepository()
        val favoritesRepository = FavoritesRepository(
            initialItems = listOf(
                FavoriteItem(
                    videoId = "video-001",
                    title = "测试详情",
                    sourceKey = "demo",
                    sourceName = "Demo Source",
                    subtitle = "详情页收藏",
                ),
            ),
        )
        val viewModel = DetailViewModel(
            repository = repository,
            favoritesRepository = favoritesRepository,
            dispatchers = DetailTestDispatchers(dispatcher),
        )

        viewModel.load(id = "video-001", sourceKey = "demo")
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.isFavorite)
    }
}

private class FakeDetailRepository : DetailRepository() {
    var lastId: String = ""
    var lastSourceKey: String? = null

    override suspend fun loadDetail(id: String, sourceKey: String?): VideoDetail {
        lastId = id
        lastSourceKey = sourceKey
        return VideoDetail(
            id = id,
            title = "测试详情",
            description = "详情描述",
            posterUrl = "",
            sourceKey = sourceKey ?: "demo",
            sourceName = "Demo Source",
            episodes = listOf(VideoEpisode(index = 0, title = "第1集", playUrl = "https://example.com/test.m3u8")),
        )
    }
}

private class DetailTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
