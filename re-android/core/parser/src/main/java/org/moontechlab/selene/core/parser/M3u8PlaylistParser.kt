package org.moontechlab.selene.core.parser

data class M3u8Segment(
    val durationSeconds: Double,
    val uri: String,
)

class M3u8PlaylistParser {
    fun parse(content: String): List<M3u8Segment> {
        val lines = content.lines()
        val segments = mutableListOf<M3u8Segment>()
        var pendingDuration = 0.0
        lines.forEach { raw ->
            val line = raw.trim()
            when {
                line.startsWith("#EXTINF:") -> {
                    pendingDuration = line.removePrefix("#EXTINF:")
                        .substringBefore(",")
                        .toDoubleOrNull() ?: 0.0
                }
                line.isNotBlank() && !line.startsWith("#") -> {
                    segments += M3u8Segment(durationSeconds = pendingDuration, uri = line)
                }
            }
        }
        return segments
    }
}
