package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuCommentListResponse
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * TV 弹幕服务接口。
 */
interface SeleneDanmakuApi {
    /**
     * 搜索弹幕剧集候选。
     *
     * @param anime 动画或影视标题搜索词。
     * @return 弹幕搜索响应。
     */
    @GET("api/v2/search/episodes")
    suspend fun searchEpisodes(
        @Query("anime") anime: String,
    ): TvDanmakuSearchResponse

    /**
     * 加载指定弹幕剧集的评论列表。
     *
     * @param episodeId 弹幕剧集 ID。
     * @param format 评论格式，TV 端沿用 Flutter 的 json 格式。
     * @return 弹幕评论响应。
     */
    @GET("api/v2/comment/{episodeId}")
    suspend fun getComments(
        @Path("episodeId") episodeId: Int,
        @Query("format") format: String = "json",
    ): TvDanmakuCommentListResponse
}
