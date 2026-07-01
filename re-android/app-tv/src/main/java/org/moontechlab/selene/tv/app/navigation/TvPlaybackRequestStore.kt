package org.moontechlab.selene.tv.app.navigation

import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSource

/**
 * 详情页传递到播放器的完整上下文。
 */
data class TvPlaybackContext(
    val request: PlaybackRequest,
    val sources: List<PlaybackSource> = emptyList(),
    val episodes: List<PlaybackEpisode> = emptyList(),
)

class TvPlaybackRequestStore {
    private val contextsById = linkedMapOf<String, TvPlaybackContext>()
    private var nextRequestIndex = 1

    fun save(
        request: PlaybackRequest,
        sources: List<PlaybackSource> = emptyList(),
        episodes: List<PlaybackEpisode> = emptyList(),
    ): String {
        val requestId = "playback-${nextRequestIndex++}"
        contextsById[requestId] = TvPlaybackContext(request, sources, episodes)
        return requestId
    }

    fun get(requestId: String): PlaybackRequest? = contextsById[requestId]?.request

    fun getContext(requestId: String): TvPlaybackContext? = contextsById[requestId]
}
