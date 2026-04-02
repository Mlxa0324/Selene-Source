package org.moontechlab.selene.feature.downloads

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.download.DownloadTaskStatus
import org.moontechlab.selene.core.download.DownloadsRepository
import org.moontechlab.selene.core.download.OfflineCatalog

@OptIn(ExperimentalCoroutinesApi::class)
class DownloadsViewModelTest {

    @Test
    fun `downloads state separates active and completed tasks and delete clears offline entry`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val offlineCatalog = OfflineCatalog()
        val repository = DownloadsRepository(offlineCatalog = offlineCatalog)
        val viewModel = DownloadsViewModel(
            repository = repository,
            dispatchers = DownloadsTestDispatchers(dispatcher),
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
            """.trimIndent(),
        )
        repository.addTask(
            videoId = "video-002",
            episodeTitle = "第3集",
            title = "凡人修仙传",
            playUrl = "https://example.com/fanren-3.m3u8",
            playlistContent = """
                #EXTM3U
                #EXTINF:6.0,
                seg-001.ts
            """.trimIndent(),
        )
        val completedTaskId = repository.tasks.value.last().id
        repository.markCompleted(completedTaskId, "/offline/fanren-3/index.m3u8")
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.activeTasks.size)
        assertEquals(1, viewModel.uiState.value.completedTasks.size)
        assertEquals(DownloadTaskStatus.Completed, viewModel.uiState.value.completedTasks.first().status)

        viewModel.removeTask(completedTaskId)
        advanceUntilIdle()

        assertEquals(1, viewModel.uiState.value.activeTasks.size)
        assertTrue(viewModel.uiState.value.completedTasks.isEmpty())
        assertEquals(1, offlineCatalog.entries.value.size)
    }

    @Test
    fun `toggle task flips between downloading and paused`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = DownloadsRepository()
        val viewModel = DownloadsViewModel(
            repository = repository,
            dispatchers = DownloadsTestDispatchers(dispatcher),
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
        advanceUntilIdle()

        val firstTask = viewModel.uiState.value.activeTasks.first()
        assertEquals("三体 第1集", firstTask.title)
        assertEquals(3, firstTask.segmentCount)
        assertEquals(DownloadTaskStatus.Downloading, firstTask.status)

        viewModel.toggleTask(firstTask.id)
        advanceUntilIdle()
        assertEquals(DownloadTaskStatus.Paused, viewModel.uiState.value.activeTasks.first().status)

        viewModel.toggleTask(firstTask.id)
        advanceUntilIdle()
        assertEquals(DownloadTaskStatus.Downloading, viewModel.uiState.value.activeTasks.first().status)
    }
}

private class DownloadsTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
