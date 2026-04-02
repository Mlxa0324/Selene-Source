package org.moontechlab.selene.core.download

import org.moontechlab.selene.core.parser.M3u8PlaylistParser

data class PlannedDownload(
    val url: String,
    val segmentCount: Int,
)

class M3u8DownloadPlanner(
    private val parser: M3u8PlaylistParser = M3u8PlaylistParser(),
) {
    fun plan(url: String, playlistContent: String): PlannedDownload {
        val segments = parser.parse(playlistContent)
        return PlannedDownload(url = url, segmentCount = segments.size)
    }
}
