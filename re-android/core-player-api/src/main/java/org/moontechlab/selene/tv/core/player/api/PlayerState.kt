package org.moontechlab.selene.tv.core.player.api

/**
 * 播放器运行状态。
 */
sealed interface PlayerState {
    /** 播放器空闲。 */
    data object Idle : PlayerState

    /** 播放器正在加载播放地址。 */
    data object Loading : PlayerState

    /** 播放器正在播放。 */
    data class Playing(
        /** 当前播放快照。 */
        val snapshot: PlaybackSnapshot,
    ) : PlayerState

    /** 播放器暂停。 */
    data class Paused(
        /** 当前播放快照。 */
        val snapshot: PlaybackSnapshot?,
    ) : PlayerState

    /** 播放器出现错误。 */
    data class Error(
        /** 错误说明。 */
        val message: String,
        /** 原始异常。 */
        val cause: Throwable? = null,
    ) : PlayerState
}
