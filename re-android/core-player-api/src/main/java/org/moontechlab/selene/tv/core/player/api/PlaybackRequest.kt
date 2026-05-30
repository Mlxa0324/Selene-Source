package org.moontechlab.selene.tv.core.player.api

/**
 * 播放加载请求。
 *
 * @property videoId 影视 ID。
 * @property sourceId 播放线路 ID。
 * @property episodeId 剧集 ID。
 * @property url 播放地址。
 * @property startPositionMs 起播位置，单位毫秒。
 * @property playbackSpeed 起播倍速。
 * @property resizeMode 画面比例模式。
 */
data class PlaybackRequest(
    val videoId: String,
    val sourceId: String,
    val episodeId: String,
    val url: String,
    val startPositionMs: Long = 0L,
    val playbackSpeed: Float = 1.0f,
    val resizeMode: TvResizeMode = TvResizeMode.FIT,
)
