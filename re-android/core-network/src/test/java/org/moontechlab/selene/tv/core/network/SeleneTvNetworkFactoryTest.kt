package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import okhttp3.Headers
import org.junit.Test

/**
 * 校验 TV 后台网络工厂契约。
 */
class SeleneTvNetworkFactoryTest {
    /**
     * 基础地址应补齐协议和末尾斜杠。
     */
    @Test
    fun normalizeBaseUrl_adds_scheme_and_trailing_slash() {
        val baseUrl = SeleneTvNetworkFactory.normalizeBaseUrl("127.0.0.1:3000/")

        assertThat(baseUrl).isEqualTo("http://127.0.0.1:3000/")
    }

    /**
     * 基础地址已有 HTTPS 协议时应保留协议。
     */
    @Test
    fun normalizeBaseUrl_keeps_https_scheme() {
        val baseUrl = SeleneTvNetworkFactory.normalizeBaseUrl("https://tv.example.com/api")

        assertThat(baseUrl).isEqualTo("https://tv.example.com/api/")
    }

    /**
     * 空基础地址应直接拒绝，避免 Retrofit 创建无效客户端。
     */
    @Test
    fun normalizeBaseUrl_rejects_blank_value() {
        val error = runCatching {
            SeleneTvNetworkFactory.normalizeBaseUrl("   ")
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(error).hasMessageThat().contains("服务器地址未配置")
    }

    /**
     * 登录响应应把多个 Set-Cookie 合并为请求 Cookie。
     */
    @Test
    fun parseSetCookie_joins_cookie_pairs() {
        val headers = Headers.headersOf(
            "Set-Cookie",
            "sid=fresh; Path=/; HttpOnly",
            "Set-Cookie",
            "auth=token; Path=/",
        )

        val cookie = SeleneTvNetworkFactory.parseSetCookie(headers)

        assertThat(cookie).isEqualTo("sid=fresh; auth=token")
    }
}
