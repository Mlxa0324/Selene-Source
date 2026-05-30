package org.moontechlab.selene.tv.core.network

import okhttp3.Interceptor
import okhttp3.Response

/**
 * TV 请求认证拦截器。
 *
 * @property cookieProvider Cookie 读取函数。
 */
class AuthInterceptor(
    private val cookieProvider: () -> String?,
) : Interceptor {
    /**
     * 为请求补充 Cookie。
     *
     * @param chain OkHttp 请求链。
     * @return 服务端响应。
     */
    override fun intercept(chain: Interceptor.Chain): Response {
        val cookie = cookieProvider()
        val request = if (cookie.isNullOrBlank()) {
            // 未配置服务器会话时保持原请求。
            chain.request()
        } else {
            chain.request().newBuilder()
                .header("Cookie", cookie)
                .build()
        }
        return chain.proceed(request)
    }
}
