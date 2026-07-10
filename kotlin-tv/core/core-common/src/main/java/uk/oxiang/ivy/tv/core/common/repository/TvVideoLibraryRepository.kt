package uk.oxiang.ivy.tv.core.common.repository

import uk.oxiang.ivy.tv.core.common.model.TvVideoCard
import uk.oxiang.ivy.tv.core.common.network.SeleneTvApi

/**
 * TV 分类视频库仓库。
 *
 * @property api TV 服务端接口。
 */
class TvVideoLibraryRepository(
    private val api: SeleneTvApi,
) {
    /**
     * 读取分类视频列表。
     *
     * @param categoryKey 分类标识。
     * @param keyword 可选搜索关键词。
     * @return 分类视频卡片列表。
     */
    suspend fun loadCategory(
        categoryKey: String,
        keyword: String = categoryKey.toDefaultKeyword(),
    ): List<TvVideoCard> {
        val query = keyword.trim().ifEmpty { categoryKey.toDefaultKeyword() }
        return api.search(query)
            .results
            .orEmpty()
            .map { result ->
                TvVideoCard(
                    id = result.id.orEmpty(),
                    source = result.source.orEmpty(),
                    title = result.title.orEmpty(),
                    sourceName = result.sourceName.orEmpty(),
                    year = result.year.orEmpty(),
                    posterUrl = result.poster.orEmpty(),
                    totalEpisodes = result.episodes.orEmpty().size,
                    searchTitle = result.title.orEmpty(),
                )
            }
    }

    /**
     * 将分类标识转换成后端可搜索关键词。
     *
     * @return 默认搜索关键词。
     */
    private fun String.toDefaultKeyword(): String {
        return when (this) {
            "movie" -> "电影"
            "tv" -> "剧集"
            "anime" -> "动漫"
            "show" -> "综艺"
            else -> "影视"
        }
    }
}
