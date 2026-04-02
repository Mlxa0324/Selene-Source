package org.moontechlab.selene.core.parser

import org.junit.Assert.assertEquals
import org.junit.Test

class M3uPlaylistParserTest {

    @Test
    fun `parse extracts channel names groups and urls`() {
        val content = """
            #EXTM3U
            #EXTINF:-1 tvg-id="cctv1" group-title="央视频道",CCTV-1
            https://live.example.com/cctv1.m3u8
            #EXTINF:-1 tvg-id="dragon" group-title="地方频道",东方卫视
            https://live.example.com/dragontv.m3u8
        """.trimIndent()

        val channels = M3uPlaylistParser().parse(content)

        assertEquals(
            listOf(
                M3uChannel(
                    name = "CCTV-1",
                    url = "https://live.example.com/cctv1.m3u8",
                    group = "央视频道",
                ),
                M3uChannel(
                    name = "东方卫视",
                    url = "https://live.example.com/dragontv.m3u8",
                    group = "地方频道",
                ),
            ),
            channels,
        )
    }
}
