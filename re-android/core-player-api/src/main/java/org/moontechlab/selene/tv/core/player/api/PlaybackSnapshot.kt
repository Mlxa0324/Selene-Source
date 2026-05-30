package org.moontechlab.selene.tv.core.player.api

/**
 * TV 画面比例模式。
 */
enum class TvResizeMode {
    /** 按视频比例适应容器。 */
    FIT,

    /** 填满容器，可能裁剪画面。 */
    FILL,

    /** 按容器宽度适配。 */
    WIDTH,

    /** 按容器高度适配。 */
    HEIGHT,
}

/**
 * 播放状态快照。
 *
 * @property videoId 影视 ID。
 * @property sourceId 当前线路 ID。
 * @property episodeId 当前剧集 ID。
 * @property url 当前播放地址。
 * @property positionMs 当前播放位置，单位毫秒。
 * @property durationMs 当前总时长，单位毫秒。
 * @property playbackSpeed 当前播放倍速。
 * @property resizeMode 当前画面比例模式。
 */
data class PlaybackSnapshot(
    val videoId: String,
    val sourceId: String,
    val episodeId: String,
    val url: String,
    val positionMs: Long,
    val durationMs: Long,
    val playbackSpeed: Float,
    val resizeMode: TvResizeMode,
)
