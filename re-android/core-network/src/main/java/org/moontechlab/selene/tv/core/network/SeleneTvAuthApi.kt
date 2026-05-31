package org.moontechlab.selene.tv.core.network

import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

/**
 * TV 后台登录请求。
 *
 * @property username 登录账号。
 * @property password 登录密码。
 */
data class SeleneTvLoginRequest(
    val username: String,
    val password: String,
)

/**
 * TV 后台认证接口。
 */
interface SeleneTvAuthApi {
    /**
     * 登录后台并返回 Set-Cookie。
     *
     * @param request 登录请求体。
     * @return 原始登录响应。
     */
    @POST("api/login")
    suspend fun login(
        @Body request: SeleneTvLoginRequest,
    ): Response<ResponseBody>
}
