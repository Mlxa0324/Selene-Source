package org.moontechlab.selene.core.datastore

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaybackRepositoriesTest {

    @Test
    fun `favorites repository toggles membership by video id`() {
        val repository = FavoritesRepository()
        val item = FavoriteItem(
            videoId = "video-001",
            title = "三体",
            sourceName = "非凡影视",
            subtitle = "科幻",
        )

        repository.toggle(item)
        assertTrue(repository.isFavorite("video-001"))
        assertEquals(listOf(item), repository.items.value)

        repository.toggle(item)
        assertFalse(repository.isFavorite("video-001"))
        assertTrue(repository.items.value.isEmpty())
    }

    @Test
    fun `history repository keeps most recent playback at top and replaces duplicates`() {
        val repository = PlaybackHistoryRepository()
        val first = PlaybackHistoryItem(
            videoId = "video-001",
            title = "三体",
            episodeTitle = "第1集",
            playUrl = "https://example.com/1.m3u8",
            progressPercent = 25,
        )
        val second = PlaybackHistoryItem(
            videoId = "video-002",
            title = "凡人修仙传",
            episodeTitle = "第8集",
            playUrl = "https://example.com/2.m3u8",
            progressPercent = 66,
        )

        repository.record(first)
        repository.record(second)
        repository.record(first.copy(progressPercent = 88))

        assertEquals(listOf("video-001", "video-002"), repository.items.value.map { it.videoId })
        assertEquals(88, repository.items.value.first().progressPercent)
    }
}
