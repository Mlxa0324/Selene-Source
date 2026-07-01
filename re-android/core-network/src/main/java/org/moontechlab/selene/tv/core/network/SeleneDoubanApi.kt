package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.DoubanCategoryResponse
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * 豆瓣代理 API 接口。
 *
 * 端点对应 Flutter TV DoubanService，使用 Tencent CDN 镜像。
 */
interface SeleneDoubanApi {
    /**
     * 获取豆瓣分类热门数据。
     *
     * @param kind 影视类型（movie / tv）。
     * @param start 分页偏移。
     * @param limit 每页条数。
     * @param category 分类（热门、最近热门 等）。
     * @param type 子类型筛选。
     * @return 豆瓣分类响应。
     */
    @GET("rexxar/api/v2/subject/recent_hot/{kind}")
    suspend fun getCategoryData(
        @Path("kind") kind: String,
        @Query("start") start: Int,
        @Query("limit") limit: Int = 25,
        @Query("category") category: String,
        @Query("type") type: String = "全部",
    ): DoubanCategoryResponse

    /**
     * 获取豆瓣高级推荐筛选数据。
     *
     * @param kind 影视类型（movie / tv）。
     * @param refresh 是否强制刷新。
     * @param start 分页偏移。
     * @param count 每页条数。
     * @param selectedCategories 已选分类 JSON。
     * @param uncollect 是否排除已收藏。
     * @param scoreRange 评分范围。
     * @param tags 筛选标签（逗号分隔）。
     * @param sort 排序方式（T 综合 / U 热度 / R 时间 / S 评分）。
     * @return 豆瓣推荐响应。
     */
    @GET("rexxar/api/v2/{kind}/recommend")
    suspend fun getRecommends(
        @Path("kind") kind: String,
        @Query("refresh") refresh: Int = 0,
        @Query("start") start: Int,
        @Query("count") count: Int,
        @Query("selected_categories") selectedCategories: String = "",
        @Query("uncollect") uncollect: Boolean = false,
        @Query("score_range") scoreRange: String = "0,10",
        @Query("tags") tags: String = "",
        @Query("sort") sort: String = "T",
    ): DoubanCategoryResponse
}
