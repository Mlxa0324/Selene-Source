package uk.oxiang.ivy.tv.core.player.api

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
 * 播放器已缓存区间。
 *
 * @property startMs 缓存起点，单位毫秒。
 * @property endMs 缓存终点，单位毫秒。
 */
data class PlaybackCachedRange(
    val startMs: Long,
    val endMs: Long,
)

/**
 * 播放状态快照。
 *
 * @property videoId 影视 ID。
 * @property sourceId 当前线路 ID。
 * @property episodeId 当前剧集 ID。
 * @property url 当前播放地址。
 * @property positionMs 当前播放位置，单位毫秒。
 * @property durationMs 当前总时长，单位毫秒。
 * @property cachedRanges 当前播放器已缓存区间。
 * @property networkSpeedBytesPerSecond 当前下载网速，单位 B/s，未知时为 0。
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
    val cachedRanges: List<PlaybackCachedRange> = emptyList(),
    val networkSpeedBytesPerSecond: Long = 0L,
    val playbackSpeed: Float,
    val resizeMode: TvResizeMode,
)
