package org.moontechlab.selene.tv.core.player.api

/**
 * 用于识别“是否还是同一条媒体播放流”的轻量身份。
 *
 * @property videoId 视频 ID。
 * @property sourceId 播放线路 ID。
 * @property episodeId 剧集 ID。
 * @property url 实际播放地址。
 */
data class PlaybackIdentity(
    val videoId: String,
    val sourceId: String,
    val episodeId: String,
    val url: String,
)

/**
 * 将播放请求转换为媒体身份。
 *
 * `startPositionMs`、倍速和画面比例属于同一媒体上的播放状态，
 * 不能拿来判断是不是“另一条新媒体”，否则详情页切全屏时会被误判成新请求。
 *
 * @return 当前播放请求的媒体身份。
 */
fun PlaybackRequest.toPlaybackIdentity(): PlaybackIdentity {
    return PlaybackIdentity(
        videoId = videoId,
        sourceId = sourceId,
        episodeId = episodeId,
        url = url,
    )
}

/**
 * 将播放快照转换为媒体身份。
 *
 * @return 当前播放快照的媒体身份。
 */
fun PlaybackSnapshot.toPlaybackIdentity(): PlaybackIdentity {
    return PlaybackIdentity(
        videoId = videoId,
        sourceId = sourceId,
        episodeId = episodeId,
        url = url,
    )
}

/**
 * 判断当前播放请求和既有播放快照是否指向同一条媒体。
 *
 * @param snapshot 既有播放器快照。
 * @return 媒体身份一致时返回 true。
 */
fun PlaybackRequest.matchesPlaybackSnapshot(snapshot: PlaybackSnapshot?): Boolean {
    return snapshot != null && toPlaybackIdentity() == snapshot.toPlaybackIdentity()
}

/**
 * 从播放器状态中提取当前播放快照。
 *
 * @return 播放和暂停态返回快照，其余状态返回空。
 */
fun PlayerState.snapshotOrNull(): PlaybackSnapshot? {
    return when (this) {
        is PlayerState.Playing -> snapshot
        is PlayerState.Paused -> snapshot
        is PlayerState.Error,
        PlayerState.Idle,
        PlayerState.Loading,
        -> null
    }
}

/**
 * 判断播放器当前状态是否已经承载同一条媒体。
 *
 * @param request 目标播放请求。
 * @return 当前播放器状态里的媒体身份与目标请求一致时返回 true。
 */
fun PlayerState.matchesPlaybackRequest(request: PlaybackRequest): Boolean {
    return request.matchesPlaybackSnapshot(snapshotOrNull())
}
