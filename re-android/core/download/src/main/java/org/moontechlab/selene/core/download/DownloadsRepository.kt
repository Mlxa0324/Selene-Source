package org.moontechlab.selene.core.download

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class DownloadTaskStatus {
    Downloading,
    Paused,
    Completed,
}

data class DownloadTaskRecord(
    val id: String,
    val videoId: String,
    val title: String,
    val playUrl: String,
    val segmentCount: Int,
    val progressPercent: Int,
    val status: DownloadTaskStatus,
)

class DownloadsRepository(
    private val planner: M3u8DownloadPlanner = M3u8DownloadPlanner(),
    private val offlineCatalog: OfflineCatalog = OfflineCatalog(),
    initialTasks: List<DownloadTaskRecord> = emptyList(),
) {
    private val tasksState = MutableStateFlow(initialTasks)

    val tasks: StateFlow<List<DownloadTaskRecord>> = tasksState.asStateFlow()

    fun addTask(
        videoId: String,
        title: String,
        episodeTitle: String,
        playUrl: String,
        playlistContent: String = defaultPlaylistContent(),
    ): String {
        val existingTask = tasksState.value.firstOrNull { it.videoId == videoId && it.playUrl == playUrl }
        if (existingTask != null) {
            return existingTask.id
        }

        val taskId = "download-${videoId.hashCode().toUInt().toString(16)}-${episodeTitle.hashCode().toUInt().toString(16)}"
        val planned = planner.plan(url = playUrl, playlistContent = playlistContent)
        val task = DownloadTaskRecord(
            id = taskId,
            videoId = videoId,
            title = "$title $episodeTitle",
            playUrl = playUrl,
            segmentCount = planned.segmentCount,
            progressPercent = 0,
            status = DownloadTaskStatus.Downloading,
        )
        tasksState.value = listOf(task) + tasksState.value
        offlineCatalog.upsert(
            OfflineEntry(
                taskId = taskId,
                title = task.title,
                localPath = "",
                playUrl = playUrl,
            ),
        )
        return taskId
    }

    fun hasTask(videoId: String, playUrl: String): Boolean =
        tasksState.value.any { it.videoId == videoId && it.playUrl == playUrl }

    fun toggleTask(taskId: String) {
        tasksState.value = tasksState.value.map { task ->
            if (task.id != taskId || task.status == DownloadTaskStatus.Completed) {
                task
            } else {
                task.copy(
                    status = if (task.status == DownloadTaskStatus.Downloading) {
                        DownloadTaskStatus.Paused
                    } else {
                        DownloadTaskStatus.Downloading
                    },
                )
            }
        }
    }

    fun markCompleted(taskId: String, localPath: String) {
        val target = tasksState.value.firstOrNull { it.id == taskId } ?: return
        tasksState.value = tasksState.value.map { task ->
            if (task.id == taskId) {
                task.copy(status = DownloadTaskStatus.Completed, progressPercent = 100)
            } else {
                task
            }
        }
        offlineCatalog.upsert(
            OfflineEntry(
                taskId = target.id,
                title = target.title,
                localPath = localPath,
                playUrl = target.playUrl,
            ),
        )
    }

    fun removeTask(taskId: String) {
        tasksState.value = tasksState.value.filterNot { it.id == taskId }
        offlineCatalog.remove(taskId)
    }

    fun offlineCatalog(): OfflineCatalog = offlineCatalog

    private fun defaultPlaylistContent(): String = """
        #EXTM3U
        #EXTINF:8.0,
        seg-001.ts
        #EXTINF:8.0,
        seg-002.ts
        #EXTINF:8.0,
        seg-003.ts
    """.trimIndent()
}
