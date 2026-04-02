package org.moontechlab.selene.feature.player

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.download.DownloadsRepository
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository
import org.moontechlab.selene.core.model.VideoEpisode
import org.moontechlab.selene.core.player.AndroidVideoPlayerEngine

class PlayerViewModelTest {

    @Test
    fun `load episode primes player records history and toggles play pause state`() {
        val engine = AndroidVideoPlayerEngine()
        val favoritesRepository = FavoritesRepository()
        val historyRepository = PlaybackHistoryRepository()
        val downloadsRepository = DownloadsRepository()
        val viewModel = PlayerViewModel(
            engine = engine,
            favoritesRepository = favoritesRepository,
            historyRepository = historyRepository,
            downloadsRepository = downloadsRepository,
        )
        val episode = VideoEpisode(
            index = 0,
            title = "第1集",
            playUrl = "https://example.com/test.m3u8",
        )

        viewModel.loadEpisode(
            videoId = "video-001",
            title = "测试视频",
            sourceKey = "ffm3u8",
            sourceName = "非凡影视",
            episode = episode,
        )
        assertEquals("https://example.com/test.m3u8", engine.currentUrl)
        assertEquals("测试视频 - 第1集", viewModel.uiState.value.title)
        assertEquals("测试视频", historyRepository.items.value.first().title)
        assertEquals("ffm3u8", historyRepository.items.value.first().sourceKey)
        assertEquals("非凡影视", historyRepository.items.value.first().sourceName)
        assertFalse(viewModel.uiState.value.isFavorite)
        assertFalse(viewModel.uiState.value.hasDownloadTask)

        viewModel.play()
        assertTrue(viewModel.uiState.value.isPlaying)
        assertTrue(engine.playing)

        viewModel.toggleFavorite()
        assertTrue(viewModel.uiState.value.isFavorite)
        assertTrue(favoritesRepository.isFavorite("video-001"))
        assertEquals("ffm3u8", favoritesRepository.items.value.first().sourceKey)
        assertEquals("非凡影视", favoritesRepository.items.value.first().sourceName)

        viewModel.addDownload()
        assertTrue(viewModel.uiState.value.hasDownloadTask)
        assertEquals(1, downloadsRepository.tasks.value.size)
        assertEquals("测试视频 第1集", downloadsRepository.tasks.value.first().title)

        viewModel.pause()
        assertFalse(viewModel.uiState.value.isPlaying)
        assertFalse(engine.playing)
    }
}
