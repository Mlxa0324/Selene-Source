package org.moontechlab.selene.core.download

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DownloadsRepositoryTest {

    @Test
    fun `add task creates planned download and offline entry`() {
        val offlineCatalog = OfflineCatalog()
        val repository = DownloadsRepository(
            planner = M3u8DownloadPlanner(),
            offlineCatalog = offlineCatalog,
        )

        repository.addTask(
            videoId = "video-001",
            episodeTitle = "第1集",
            title = "三体",
            playUrl = "https://example.com/santi-1.m3u8",
            playlistContent = """
                #EXTM3U
                #EXTINF:8.0,
                seg-001.ts
                #EXTINF:8.0,
                seg-002.ts
                #EXTINF:8.0,
                seg-003.ts
            """.trimIndent(),
        )

        assertEquals(1, repository.tasks.value.size)
        assertEquals(3, repository.tasks.value.first().segmentCount)
        assertEquals(DownloadTaskStatus.Downloading, repository.tasks.value.first().status)
        assertEquals(1, offlineCatalog.entries.value.size)
        assertEquals(repository.tasks.value.first().id, offlineCatalog.entries.value.first().taskId)
    }

    @Test
    fun `remove task clears matching offline entry`() {
        val offlineCatalog = OfflineCatalog()
        val repository = DownloadsRepository(
            planner = M3u8DownloadPlanner(),
            offlineCatalog = offlineCatalog,
        )

        repository.addTask(
            videoId = "video-001",
            episodeTitle = "第1集",
            title = "三体",
            playUrl = "https://example.com/santi-1.m3u8",
            playlistContent = """
                #EXTM3U
                #EXTINF:8.0,
                seg-001.ts
            """.trimIndent(),
        )

        val taskId = repository.tasks.value.first().id
        repository.removeTask(taskId)

        assertTrue(repository.tasks.value.isEmpty())
        assertTrue(offlineCatalog.entries.value.isEmpty())
    }
}
