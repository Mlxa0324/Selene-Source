package uk.oxiang.ivy.tv.core.common.repository

import uk.oxiang.ivy.tv.core.common.model.TvVideoCard
import uk.oxiang.ivy.tv.core.common.network.SeleneTvApi
import uk.oxiang.ivy.tv.core.common.network.model.TvFavoriteResponse

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
     * 删除单条收藏。
     *
     * @param video 收藏卡片。
     */
    suspend fun deleteFavorite(video: TvVideoCard) {
        deleteFavoriteByKey(video.toRecordKey())
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
        return if (source.isBlank()) id else "$source+$id"
    }
}
