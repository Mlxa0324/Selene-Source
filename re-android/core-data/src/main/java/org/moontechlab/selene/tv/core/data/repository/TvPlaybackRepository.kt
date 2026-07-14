package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertBody
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest

/**
 * TV 播放记录仓库。
 *
 * @property api TV 服务端接口。
 * @property continueWatching 首期注入的继续观看列表。
 */
class TvPlaybackRepository(
    private val api: SeleneTvApi? = null,
    private val continueWatching: List<TvVideoCard> = emptyList(),
) {
    /**
     * 读取继续观看列表。
     *
     * @return 按最近播放排序的影视卡片列表。
     */
    suspend fun readContinueWatching(): List<TvVideoCard> {
        val remoteApi = api ?: return continueWatching
        // 远端接口成功但为空时返回空列表；异常交给调用方展示错误态。
        return remoteApi.getPlayRecords()
            .map { (key, record) -> record.toVideoCard(key) }
            .sortedByDescending { card -> card.saveTime }
    }

    /**
     * 保存单条播放历史。
     *
     * @param video 当前播放记录卡片。
     */
    suspend fun savePlayRecord(video: TvVideoCard) {
        api?.savePlayRecord(video.toUpsertRequest())
    }

    /**
     * 删除单条播放历史。
     *
     * @param video 播放历史卡片。
     */
    suspend fun deletePlayRecord(video: TvVideoCard) {
        deletePlayRecordByKey(video.toRecordKey())
    }

    /**
     * 按后端 key 删除单条播放历史。
     *
     * @param key `source+id` 格式的播放记录 key。
     */
    suspend fun deletePlayRecordByKey(key: String) {
        api?.deletePlayRecord(key)
    }

    /**
     * 清空播放历史。
     */
    suspend fun clearPlayRecords() {
        api?.clearPlayRecords()
    }

    /**
     * 将播放记录响应转换成 TV 卡片模型。
     *
     * @param key 后端 `source+id` 记录 key。
     * @return TV 影视卡片。
     */
    private fun TvPlayRecordResponse.toVideoCard(key: String): TvVideoCard {
        val identity = TvRecordIdentity.fromKey(key)
        return TvVideoCard(
            id = identity.id,
            source = identity.source,
            title = title.orEmpty(),
            sourceName = sourceName.orEmpty(),
            year = year.orEmpty(),
            posterUrl = cover.orEmpty(),
            totalEpisodes = totalEpisodes ?: 0,
            episodeIndex = index ?: 0,
            playTime = playTime ?: 0,
            totalTime = totalTime ?: 0,
            saveTime = saveTime ?: 0,
            searchTitle = searchTitle.orEmpty(),
        )
    }

    /**
     * 将卡片转换成播放记录 key。
     *
     * @return `source+id` 格式的 key。
     */
    private fun TvVideoCard.toRecordKey(): String {
        return if (source.isBlank()) id else "$source+$id"
    }

    /**
     * 将卡片转换成 Flutter 兼容的播放历史保存请求。
     *
     * @return `/api/playrecords` 请求体。
     */
    private fun TvVideoCard.toUpsertRequest(): TvPlayRecordUpsertRequest {
        val safePlayTime = playTime.coerceAtLeast(0)
        val safeTotalTime = totalTime
            .coerceAtLeast(0)
            .coerceAtLeast(if (safePlayTime > 0) safePlayTime + 1 else 0)
        return TvPlayRecordUpsertRequest(
            key = toRecordKey(),
            record = TvPlayRecordUpsertBody(
                title = title,
                sourceName = sourceName,
                year = year,
                cover = posterUrl,
                index = episodeIndex.coerceAtLeast(1),
                totalEpisodes = totalEpisodes.coerceAtLeast(0),
                playTime = safePlayTime,
                totalTime = safeTotalTime,
                saveTime = saveTime.coerceAtLeast(0L),
                searchTitle = searchTitle.ifBlank { title },
            ),
        )
    }
}

/**
 * 后端播放记录 key 拆分结果。
 *
 * @property source 播放来源标识。
 * @property id 视频 ID。
 */
internal data class TvRecordIdentity(
    val source: String,
    val id: String,
) {
    companion object {
        /**
         * 按 Flutter `source+id` 规则解析记录 key。
         *
         * @param key 后端记录 key。
         * @return 拆分后的来源和 ID。
         */
        fun fromKey(key: String): TvRecordIdentity {
            val parts = key.split("+", limit = 2)
            return if (parts.size > 1) {
                TvRecordIdentity(source = parts[0], id = parts[1])
            } else {
                TvRecordIdentity(source = "", id = key)
            }
        }
    }
}
