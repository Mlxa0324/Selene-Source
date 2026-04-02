package org.moontechlab.selene.feature.sourcebrowser

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.moontechlab.selene.core.model.VideoCardModel

data class SourceCatalog(
    val id: String,
    val name: String,
    val entries: List<VideoCardModel>,
)

data class SourceBrowserUiState(
    val sources: List<SourceCatalog> = emptyList(),
    val selectedSourceId: String = "",
    val selectedSourceName: String = "",
    val entries: List<VideoCardModel> = emptyList(),
)

class SourceBrowserViewModel : ViewModel() {
    private val catalogs = listOf(
        SourceCatalog(
            id = "hot",
            name = "热门推荐",
            entries = listOf(
                demoEntry(id = "movie-001", title = "流浪地球 2", sourceName = "量子资源"),
                demoEntry(id = "drama-001", title = "三体", sourceName = "非凡影视"),
            ),
        ),
        SourceCatalog(
            id = "anime",
            name = "动漫专栏",
            entries = listOf(
                demoEntry(id = "anime-001", title = "凡人修仙传", sourceName = "动漫港"),
                demoEntry(id = "anime-002", title = "灵笼", sourceName = "动漫港"),
            ),
        ),
        SourceCatalog(
            id = "doc",
            name = "纪录片",
            entries = listOf(
                demoEntry(id = "doc-001", title = "蓝色星球", sourceName = "纪录片之家"),
            ),
        ),
    )
    private val state = MutableStateFlow(catalogs.toState(selectedSourceId = catalogs.first().id))

    val uiState: StateFlow<SourceBrowserUiState> = state.asStateFlow()

    fun selectSource(sourceId: String) {
        state.value = catalogs.toState(selectedSourceId = sourceId)
    }

    private fun List<SourceCatalog>.toState(selectedSourceId: String): SourceBrowserUiState {
        val selected = first { it.id == selectedSourceId }
        return SourceBrowserUiState(
            sources = this,
            selectedSourceId = selected.id,
            selectedSourceName = selected.name,
            entries = selected.entries,
        )
    }

    private fun demoEntry(
        id: String,
        title: String,
        sourceName: String,
    ): VideoCardModel = VideoCardModel(
        id = id,
        title = title,
        posterUrl = "",
        sourceKey = sourceName.lowercase(),
        sourceName = sourceName,
        subtitle = "按资源站聚合展示",
    )
}
