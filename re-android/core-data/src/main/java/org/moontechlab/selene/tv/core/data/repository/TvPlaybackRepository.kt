package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 播放记录仓库。
 *
 * @property continueWatching 首期注入的继续观看列表。
 */
class TvPlaybackRepository(
    private val continueWatching: List<TvVideoCard> = emptyList(),
) {
    /**
     * 读取继续观看列表。
     *
     * @return 按最近播放排序的影视卡片列表。
     */
    suspend fun readContinueWatching(): List<TvVideoCard> {
        // 首期先使用内存数据，后续接入播放记录表和进度节流策略。
        return continueWatching
    }
}
