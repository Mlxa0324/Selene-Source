package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import okhttp3.Headers
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Test
import retrofit2.Response

/**
 * 校验 TV 后台网络客户端登录契约。
 */
class SeleneTvNetworkClientTest {
    /**
     * 登录成功后应保存服务器、账号和 Cookie。
     */
    @Test
    fun login_saves_session_cookie() = runTest {
        val store = SessionCookieStore()
        val client = SeleneTvNetworkClient(
            baseUrl = "https://tv.example.com/",
            tvApi = FakeSeleneTvApi(),
            authApi = FakeAuthApi(
                response = Response.success(
                    "{}".toResponseBody(),
                    Headers.headersOf("Set-Cookie", "sid=fresh; Path=/"),
                ),
            ),
            sessionCookieStore = store,
        )

        val session = client.login(
            username = " demo ",
            password = "secret",
        )

        assertThat(session.baseUrl).isEqualTo("https://tv.example.com")
        assertThat(session.account).isEqualTo("demo")
        assertThat(session.cookie).isEqualTo("sid=fresh")
        assertThat(store.currentCookie()).isEqualTo("sid=fresh")
    }

    /**
     * 登录 401 应返回账号密码错误。
     */
    @Test
    fun login_throws_for_unauthorized() = runTest {
        val client = SeleneTvNetworkClient(
            baseUrl = "https://tv.example.com/",
            tvApi = FakeSeleneTvApi(),
            authApi = FakeAuthApi(
                response = Response.error(
                    401,
                    "bad".toResponseBody(),
                ),
            ),
            sessionCookieStore = SessionCookieStore(),
        )

        val error = runCatching {
            client.login(
                username = "demo",
                password = "wrong",
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("后台账号或密码错误")
    }
}

/**
 * 测试用认证接口。
 *
 * @property response 登录响应。
 */
private class FakeAuthApi(
    private val response: Response<okhttp3.ResponseBody>,
) : SeleneTvAuthApi {
    /**
     * 返回预设登录响应。
     *
     * @param request 登录请求体。
     * @return 预设响应。
     */
    override suspend fun login(
        request: SeleneTvLoginRequest,
    ): Response<okhttp3.ResponseBody> {
        return response
    }
}
