package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import okhttp3.Headers
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Test
import retrofit2.Response
import java.io.IOException

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

    /**
     * PassNAT 节点错误页应提示用户检查穿透域名绑定。
     */
    @Test
    fun login_explains_passnat_node_page() = runTest {
        val client = SeleneTvNetworkClient(
            baseUrl = "http://ivy3004.s.odn.cc/",
            tvApi = FakeSeleneTvApi(),
            authApi = FakeAuthApi(
                response = Response.error(
                    404,
                    "<html><title>PassNAT 节点</title></html>".toResponseBody(),
                ),
            ),
            sessionCookieStore = SessionCookieStore(),
        )

        val error = runCatching {
            client.login(
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("后台地址未命中 Selene 服务")
        assertThat(error).hasMessageThat().contains("http://ivy3004.s.odn.cc")
        assertThat(error).hasMessageThat().contains("穿透域名")
    }

    /**
     * 普通网页错误页应提示服务器地址不是 API 入口。
     */
    @Test
    fun login_explains_html_error_page() = runTest {
        val client = SeleneTvNetworkClient(
            baseUrl = "https://tv.example.com/",
            tvApi = FakeSeleneTvApi(),
            authApi = FakeAuthApi(
                response = Response.error(
                    502,
                    "<html><title>Bad Gateway</title></html>".toResponseBody(),
                ),
            ),
            sessionCookieStore = SessionCookieStore(),
        )

        val error = runCatching {
            client.login(
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("后台登录失败(502)")
        assertThat(error).hasMessageThat().contains("返回网页内容")
        assertThat(error).hasMessageThat().contains("后台 API")
    }

    /**
     * 网络连接异常应转换成可操作的后台地址诊断文案。
     */
    @Test
    fun login_wraps_network_error_with_actionable_message() = runTest {
        val client = SeleneTvNetworkClient(
            baseUrl = "http://192.168.31.28:9000/",
            tvApi = FakeSeleneTvApi(),
            authApi = ThrowingAuthApi(
                IOException("Failed to connect to /192.168.31.28:9000"),
            ),
            sessionCookieStore = SessionCookieStore(),
        )

        val error = runCatching {
            client.login(
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("无法连接后台服务")
        assertThat(error).hasMessageThat().contains("http://192.168.31.28:9000")
        assertThat(error).hasMessageThat().contains("Failed to connect")
        assertThat(error).hasMessageThat().contains("重新构建并安装")
    }

    /**
     * 域名最终连接到其他地址失败时，应提示用户排查解析或穿透目标。
     */
    @Test
    fun login_explains_resolved_target_when_connection_uses_different_address() = runTest {
        val client = SeleneTvNetworkClient(
            baseUrl = "http://ivy3004.s.odn.cc/",
            tvApi = FakeSeleneTvApi(),
            authApi = ThrowingAuthApi(
                IOException("Failed to connect to /192.168.31.28:9000"),
            ),
            sessionCookieStore = SessionCookieStore(),
        )

        val error = runCatching {
            client.login(
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("http://ivy3004.s.odn.cc")
        assertThat(error).hasMessageThat().contains("实际连接到 192.168.31.28:9000")
        assertThat(error).hasMessageThat().contains("域名解析、穿透或重定向")
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

/**
 * 测试用异常认证接口。
 *
 * @property throwable 登录时抛出的异常。
 */
private class ThrowingAuthApi(
    private val throwable: Throwable,
) : SeleneTvAuthApi {
    /**
     * 抛出预设异常。
     *
     * @param request 登录请求体。
     * @return 不返回。
     */
    override suspend fun login(
        request: SeleneTvLoginRequest,
    ): Response<okhttp3.ResponseBody> {
        throw throwable
    }
}
