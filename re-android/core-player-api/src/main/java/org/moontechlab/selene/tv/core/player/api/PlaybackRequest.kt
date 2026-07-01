package org.moontechlab.selene.tv.core.player.api

/**
 * 播放器可用的播放线路摘要。
 */
data class PlaybackSource(
    val id: String,
    val name: String,
)

/**
 * 播放器可用的剧集摘要。
 */
data class PlaybackEpisode(
    val id: String,
    val title: String,
)

/**
 * 播放加载请求。
 *
 * @property videoId 影视 ID。
 * @property videoTitle 影视标题，用于播放器标题栏和弹幕手动匹配默认词。
 * @property sourceId 播放线路 ID。
 * @property episodeId 剧集 ID。
 * @property episodeIndex 剧集下标，从 0 开始，用于弹幕手动匹配和续播映射。
 * @property episodeTitle 剧集标题，用于弹幕匹配和播放记录展示。
 * @property url 播放地址。
 * @property startPositionMs 起播位置，单位毫秒。
 * @property playbackSpeed 起播倍速。
 * @property resizeMode 画面比例模式。
 */
data class PlaybackRequest(
    val videoId: String,
    val videoTitle: String = "",
    val sourceId: String,
    val episodeId: String,
    val episodeIndex: Int = 0,
    val episodeTitle: String = "",
    val url: String,
    val startPositionMs: Long = 0L,
    val playbackSpeed: Float = 1.0f,
    val resizeMode: TvResizeMode = TvResizeMode.FIT,
)
