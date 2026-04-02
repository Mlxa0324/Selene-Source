package org.moontechlab.selene.feature.live

import org.junit.Assert.assertEquals
import org.junit.Test

class LiveViewModelTest {

    @Test
    fun `selecting group filters visible channels`() {
        val viewModel = LiveViewModel(
            playlistContent = """
                #EXTM3U
                #EXTINF:-1 group-title="央视频道",CCTV-1
                https://live.example.com/cctv1.m3u8
                #EXTINF:-1 group-title="央视频道",CCTV-5
                https://live.example.com/cctv5.m3u8
                #EXTINF:-1 group-title="地方频道",东方卫视
                https://live.example.com/dragontv.m3u8
            """.trimIndent(),
        )

        assertEquals(listOf("全部", "央视频道", "地方频道"), viewModel.uiState.value.groups)
        assertEquals("全部", viewModel.uiState.value.selectedGroup)
        assertEquals(3, viewModel.uiState.value.channels.size)

        viewModel.selectGroup("地方频道")

        assertEquals("地方频道", viewModel.uiState.value.selectedGroup)
        assertEquals(listOf("东方卫视"), viewModel.uiState.value.channels.map { it.name })
    }
}
