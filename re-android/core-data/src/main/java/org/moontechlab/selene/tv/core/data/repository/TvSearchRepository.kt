package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvSearchPayload
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * TV 搜索仓库。
 *
 * @property api TV 服务端接口。
 */
class TvSearchRepository(
    private val api: SeleneTvApi,
) {
    /**
     * 读取搜索历史关键词。
     *
     * @return 搜索历史列表。
     */
    suspend fun readSearchHistory(): List<String> {
        return api.getSearchHistory()
    }

    /**
     * 读取可用搜索资源。
     *
     * @return 搜索资源列表。
     */
    suspend fun readSearchResources(): List<TvSearchResource> {
        return api.getSearchResources().map { resource -> resource.toModel() }
    }

    /**
     * 搜索影视内容。
     *
     * @param query 搜索关键词。
     * @return 搜索结果载荷。
     */
    suspend fun search(query: String): TvSearchPayload {
        val normalizedQuery = query.trim()
        if (normalizedQuery.isEmpty()) {
            // 空搜索不触发网络请求，避免页面误确认产生无意义错误态。
            return TvSearchPayload(query = normalizedQuery, results = emptyList())
        }
        val response = api.search(normalizedQuery)
        return TvSearchPayload(
            query = normalizedQuery,
            results = response.results.orEmpty().map { result -> result.toVideoCard() },
        )
    }

    /**
     * 将搜索资源响应转换为业务模型。
     *
     * @return 搜索资源模型。
     */
    private fun TvSearchResourceResponse.toModel(): TvSearchResource {
        return TvSearchResource(
            key = key.orEmpty(),
            name = name.orEmpty(),
            api = api.orEmpty(),
            detail = detail.orEmpty(),
            from = from.orEmpty(),
            disabled = disabled ?: false,
        )
    }

    /**
     * 将搜索结果响应转换为 TV 卡片模型。
     *
     * @return TV 影视卡片。
     */
    private fun TvSearchResultResponse.toVideoCard(): TvVideoCard {
        return TvVideoCard(
            id = id.orEmpty(),
            source = source.orEmpty(),
            title = title.orEmpty(),
            sourceName = sourceName.orEmpty(),
            year = year.orEmpty(),
            posterUrl = poster.orEmpty(),
            totalEpisodes = episodes.orEmpty().size,
            searchTitle = title.orEmpty(),
        )
    }
}

/**
 * TV 搜索资源模型。
 *
 * @property key 资源标识。
 * @property name 资源展示名称。
 * @property api 下游搜索接口地址。
 * @property detail 下游详情接口地址。
 * @property from 资源来源类型。
 * @property disabled 是否禁用。
 */
data class TvSearchResource(
    val key: String,
    val name: String,
    val api: String,
    val detail: String,
    val from: String,
    val disabled: Boolean,
)
