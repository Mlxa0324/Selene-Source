package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse

/**
 * 网络模块测试用 TV 数据接口。
 */
internal open class FakeSeleneTvApi : SeleneTvApi {
    /** 返回测试首页响应。 */
    override suspend fun getDashboard(): TvHomeResponse {
        return TvHomeResponse(sections = emptyList())
    }

    /** 返回测试播放历史。 */
    override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
        return emptyMap()
    }

    /** 记录测试播放历史删除。 */
    override suspend fun deletePlayRecord(key: String) = Unit

    /** 记录测试播放历史清空。 */
    override suspend fun clearPlayRecords() = Unit

    /** 返回测试收藏夹。 */
    override suspend fun getFavorites(): Map<String, TvFavoriteResponse> {
        return emptyMap()
    }

    /** 记录测试收藏删除。 */
    override suspend fun deleteFavorite(key: String) = Unit

    /** 记录测试收藏清空。 */
    override suspend fun clearFavorites() = Unit

    /** 返回测试搜索历史。 */
    override suspend fun getSearchHistory(): List<String> {
        return emptyList()
    }

    /** 返回测试搜索资源。 */
    override suspend fun getSearchResources(): List<TvSearchResourceResponse> {
        return emptyList()
    }

    /** 返回测试搜索响应。 */
    override suspend fun search(query: String): TvSearchResponse {
        return TvSearchResponse(results = emptyList())
    }
}
