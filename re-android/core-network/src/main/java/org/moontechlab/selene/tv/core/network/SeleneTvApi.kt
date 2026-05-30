package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import retrofit2.http.GET

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
}
