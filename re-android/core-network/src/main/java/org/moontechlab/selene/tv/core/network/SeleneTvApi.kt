package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse
import org.moontechlab.selene.tv.core.network.model.TvFavoriteUpsertRequest
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest
import org.moontechlab.selene.tv.core.network.model.TvSearchResourceResponse
import org.moontechlab.selene.tv.core.network.model.TvSearchResponse
import retrofit2.http.DELETE
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

/**
 * TV 原生工程服务端接口。
 */
interface SeleneTvApi {
    /**
     * 获取 TV 首页聚合数据。
     *
     * @return 首页接口响应。
     */
    @GET("admin/dashboard")
    suspend fun getDashboard(): TvHomeResponse

    /**
     * 获取播放历史记录。
     *
     * @return 以 `source+id` 为 key 的播放历史。
     */
    @GET("api/playrecords")
    suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse>

    /**
     * 保存单条播放历史。
     *
     * @param request 与 Flutter `/api/playrecords` 对齐的保存请求体。
     */
    @POST("api/playrecords")
    suspend fun savePlayRecord(
        @Body request: TvPlayRecordUpsertRequest,
    )

    /**
     * 删除单条播放历史。
     *
     * @param key `source+id` 形式的播放记录 key。
     */
    @DELETE("api/playrecords")
    suspend fun deletePlayRecord(
        @Query("key") key: String,
    )

    /**
     * 清空播放历史。
     */
    @DELETE("api/playrecords")
    suspend fun clearPlayRecords()

    /**
     * 获取收藏夹记录。
     *
     * @return 以 `source+id` 为 key 的收藏记录。
     */
    @GET("api/favorites")
    suspend fun getFavorites(): Map<String, TvFavoriteResponse>

    /**
     * 保存单条收藏。
     *
     * @param request 与 Flutter `/api/favorites` 对齐的保存请求体。
     */
    @POST("api/favorites")
    suspend fun saveFavorite(
        @Body request: TvFavoriteUpsertRequest,
    )

    /**
     * 删除单条收藏。
     *
     * @param key `source+id` 形式的收藏 key。
     */
    @DELETE("api/favorites")
    suspend fun deleteFavorite(
        @Query("key") key: String,
    )

    /**
     * 清空收藏夹。
     */
    @DELETE("api/favorites")
    suspend fun clearFavorites()

    /**
     * 获取搜索历史。
     *
     * @return 搜索历史关键词列表。
     */
    @GET("api/searchhistory")
    suspend fun getSearchHistory(): List<String>

    /**
     * 获取搜索资源站列表。
     *
     * @return 搜索资源站列表。
     */
    @GET("api/search/resources")
    suspend fun getSearchResources(): List<TvSearchResourceResponse>

    /**
     * 搜索影视内容。
     *
     * @param query 搜索关键词。
     * @return 搜索结果响应。
     */
    @GET("api/search")
    suspend fun search(
        @Query("q") query: String,
    ): TvSearchResponse

    /**
     * 获取指定播放源的视频详情。
     *
     * @param source 播放来源标识。
     * @param id 视频 ID。
     * @return 视频详情响应。
     */
    @GET("api/detail")
    suspend fun getDetail(
        @Query("source") source: String,
        @Query("id") id: String,
    ): org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse
}
