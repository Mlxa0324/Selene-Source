package org.moontechlab.selene.feature.downloads

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.download.DownloadTaskRecord
import org.moontechlab.selene.core.download.DownloadTaskStatus
import org.moontechlab.selene.core.download.DownloadsRepository

data class DownloadsUiState(
    val activeTasks: List<DownloadTaskRecord> = emptyList(),
    val completedTasks: List<DownloadTaskRecord> = emptyList(),
)

class DownloadsViewModel(
    private val repository: DownloadsRepository = buildDefaultDownloadsRepository(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(DownloadsUiState())

    val uiState: StateFlow<DownloadsUiState> = state.asStateFlow()

    init {
        viewModelScope.launch(dispatchers.main) {
            repository.tasks.collect { tasks ->
                state.value = DownloadsUiState(
                    activeTasks = tasks.filter { it.status != DownloadTaskStatus.Completed },
                    completedTasks = tasks.filter { it.status == DownloadTaskStatus.Completed },
                )
            }
        }
    }

    fun toggleTask(taskId: String) {
        repository.toggleTask(taskId)
    }

    fun removeTask(taskId: String) {
        repository.removeTask(taskId)
    }
}

private fun buildDefaultDownloadsRepository(): DownloadsRepository {
    val repository = DownloadsRepository()
    repository.addTask(
        videoId = "video-001",
        title = "三体",
        episodeTitle = "第1集",
        playUrl = "https://download.example.com/download-001/index.m3u8",
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
    val completedTaskId = repository.addTask(
        videoId = "video-002",
        title = "凡人修仙传",
        episodeTitle = "第3集",
        playUrl = "https://download.example.com/download-002/index.m3u8",
        playlistContent = """
            #EXTM3U
            #EXTINF:6.0,
            seg-001.ts
            #EXTINF:6.0,
            seg-002.ts
        """.trimIndent(),
    )
    repository.markCompleted(completedTaskId, "/offline/fanren-3/index.m3u8")
    return repository
}
