package org.moontechlab.selene.core.parser

data class M3uChannel(
    val name: String,
    val url: String,
    val group: String = "",
)

class M3uPlaylistParser {
    fun parse(content: String): List<M3uChannel> {
        val lines = content.lines()
        val channels = mutableListOf<M3uChannel>()
        for (index in 0 until lines.lastIndex) {
            val current = lines[index].trim()
            val next = lines[index + 1].trim()
            if (current.startsWith("#EXTINF") && next.startsWith("http")) {
                val name = current.substringAfterLast(",").ifBlank { "Unknown" }
                val group = current
                    .substringAfter("group-title=\"", missingDelimiterValue = "")
                    .substringBefore("\"")
                channels += M3uChannel(
                    name = name,
                    url = next,
                    group = group,
                )
            }
        }
        return channels
    }
}
