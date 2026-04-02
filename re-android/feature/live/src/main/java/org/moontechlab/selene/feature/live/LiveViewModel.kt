package org.moontechlab.selene.feature.live

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.moontechlab.selene.core.parser.M3uPlaylistParser

data class LiveChannelItem(
    val name: String,
    val url: String,
    val group: String,
)

data class LiveUiState(
    val groups: List<String> = emptyList(),
    val selectedGroup: String = "全部",
    val channels: List<LiveChannelItem> = emptyList(),
)

class LiveViewModel(
    parser: M3uPlaylistParser = M3uPlaylistParser(),
    playlistContent: String = DEFAULT_PLAYLIST,
) : ViewModel() {
    private val allChannels = parser.parse(playlistContent).map { channel ->
        LiveChannelItem(
            name = channel.name,
            url = channel.url,
            group = channel.group.ifBlank { "未分组" },
        )
    }
    private val groups = listOf("全部") + allChannels.map { it.group }.distinct()
    private val state = MutableStateFlow(
        LiveUiState(
            groups = groups,
            selectedGroup = "全部",
            channels = allChannels,
        ),
    )

    val uiState: StateFlow<LiveUiState> = state.asStateFlow()

    fun selectGroup(group: String) {
        val visibleChannels = if (group == "全部") {
            allChannels
        } else {
            allChannels.filter { it.group == group }
        }
        state.value = state.value.copy(
            selectedGroup = group,
            channels = visibleChannels,
        )
    }

    private companion object {
        private val DEFAULT_PLAYLIST = """
            #EXTM3U
            #EXTINF:-1 group-title="央视频道",CCTV-1
            https://live.example.com/cctv1.m3u8
            #EXTINF:-1 group-title="央视频道",CCTV-5
            https://live.example.com/cctv5.m3u8
            #EXTINF:-1 group-title="地方频道",东方卫视
            https://live.example.com/dragontv.m3u8
            #EXTINF:-1 group-title="地方频道",江苏卫视
            https://live.example.com/jstv.m3u8
        """.trimIndent()
    }
}
