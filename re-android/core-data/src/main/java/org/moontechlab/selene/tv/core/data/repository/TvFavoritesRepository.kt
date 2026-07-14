package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse
import org.moontechlab.selene.tv.core.network.model.TvFavoriteUpsertBody
import org.moontechlab.selene.tv.core.network.model.TvFavoriteUpsertRequest

/**
 * TV 收藏夹仓库。
 *
 * @property api TV 服务端接口。
 */
class TvFavoritesRepository(
    private val api: SeleneTvApi,
) {
    /**
     * 读取收藏夹列表。
     *
     * @return 按最近收藏倒序排列的影视卡片。
     */
    suspend fun readFavorites(): List<TvVideoCard> {
        // 接口异常不吞掉，交给页面展示明确错误态。
        return api.getFavorites()
            .map { (key, favorite) -> favorite.toVideoCard(key) }
            .sortedByDescending { card -> card.saveTime }
    }

    /**
     * 判断指定视频是否已收藏。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @return 已收藏时返回 true。
     */
    suspend fun isFavorite(
        source: String,
        videoId: String,
    ): Boolean {
        val normalizedId = videoId.trim()
        if (normalizedId.isBlank()) {
            return false
        }
        val normalizedSource = source.trim()
        val targetKey = toRecordKey(source = normalizedSource, id = normalizedId)
        return readFavorites().any { card ->
            // 优先 source+id 精确匹配；source 缺失时退化为 id 匹配，兼容旧收藏数据。
            card.toRecordKey() == targetKey ||
                (normalizedSource.isBlank() && card.id == normalizedId) ||
                (card.source.isBlank() && card.id == normalizedId)
        }
    }

    /**
     * 保存单条收藏。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param title 影视标题。
     * @param sourceName 线路名称。
     * @param year 年份。
     * @param cover 封面地址。
     * @param totalEpisodes 总集数。
     * @param origin 收藏来源描述。
     */
    suspend fun saveFavorite(
        source: String,
        videoId: String,
        title: String,
        sourceName: String = "",
        year: String = "",
        cover: String = "",
        totalEpisodes: Int = 0,
        origin: String = "detail",
    ) {
        val key = toRecordKey(source = source, id = videoId)
        api.saveFavorite(
            TvFavoriteUpsertRequest(
                key = key,
                favorite = TvFavoriteUpsertBody(
                    title = title,
                    sourceName = sourceName,
                    year = year,
                    cover = cover,
                    totalEpisodes = totalEpisodes.coerceAtLeast(0),
                    saveTime = System.currentTimeMillis(),
                    origin = origin,
                ),
            ),
        )
    }

    /**
     * 删除单条收藏。
     *
     * @param video 收藏卡片。
     */
    suspend fun deleteFavorite(video: TvVideoCard) {
        deleteFavoriteByKey(video.toRecordKey())
    }

    /**
     * 按来源和视频 ID 删除收藏。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     */
    suspend fun deleteFavorite(
        source: String,
        videoId: String,
    ) {
        deleteFavoriteByKey(toRecordKey(source = source, id = videoId))
    }

    /**
     * 按后端 key 删除单条收藏。
     *
     * @param key `source+id` 格式的收藏 key。
     */
    suspend fun deleteFavoriteByKey(key: String) {
        api.deleteFavorite(key)
    }

    /**
     * 清空收藏夹。
     */
    suspend fun clearFavorites() {
        api.clearFavorites()
    }

    /**
     * 将收藏响应转换成 TV 卡片模型。
     *
     * @param key 后端 `source+id` 收藏 key。
     * @return TV 影视卡片。
     */
    private fun TvFavoriteResponse.toVideoCard(key: String): TvVideoCard {
        val identity = TvRecordIdentity.fromKey(key)
        return TvVideoCard(
            id = identity.id,
            source = identity.source,
            title = title.orEmpty(),
            sourceName = sourceName.orEmpty(),
            year = year.orEmpty(),
            posterUrl = cover.orEmpty(),
            totalEpisodes = totalEpisodes ?: 0,
            saveTime = saveTime ?: 0,
            origin = origin.orEmpty(),
        )
    }

    /**
     * 将卡片转换成收藏 key。
     *
     * @return `source+id` 格式的 key。
     */
    private fun TvVideoCard.toRecordKey(): String {
        return toRecordKey(source = source, id = id)
    }

    /**
     * 组装 Flutter 兼容的收藏 key。
     *
     * @param source 播放来源标识。
     * @param id 视频 ID。
     * @return `source+id`；source 为空时仅返回 id。
     */
    private fun toRecordKey(
        source: String,
        id: String,
    ): String {
        val normalizedId = id.trim()
        val normalizedSource = source.trim()
        return if (normalizedSource.isBlank()) {
            normalizedId
        } else {
            "$normalizedSource+$normalizedId"
        }
    }
}
