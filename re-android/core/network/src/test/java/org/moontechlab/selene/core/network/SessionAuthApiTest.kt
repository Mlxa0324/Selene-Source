package org.moontechlab.selene.core.network

import java.net.ConnectException
import kotlin.text.Charsets.UTF_8
import kotlinx.coroutines.test.runTest
import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.Response

class SessionAuthApiTest {

    @Test
    fun `login extracts cookie header from response and returns remote session`() = runTest {
        val factory = FakeAuthRemoteServiceFactory(
            service = FakeAuthRemoteService(
                loginResponse = Response.success(
                    Unit,
                    Headers.headersOf(
                        "Set-Cookie", "auth=token-123; Path=/; HttpOnly",
                        "Set-Cookie", "refresh=token-456; Path=/",
                    ),
                ),
            ),
        )
        val api = RetrofitSessionAuthApi(serviceFactory = factory)

        val session = api.login(
            baseUrl = "https://demo.example.com/",
            username = "demo",
            password = "secret",
        )

        assertEquals("https://demo.example.com/", factory.lastBaseUrl)
        assertEquals("", factory.lastCookie)
        assertEquals("demo", factory.service.lastUsername)
        assertEquals("secret", factory.service.lastPassword)
        assertEquals("https://demo.example.com/", session.baseUrl)
        assertEquals("auth=token-123; refresh=token-456", session.cookie)
        assertFalse(session.isLocalMode)
    }

    @Test
    fun `validate session sends existing cookie and maps unauthorized to false`() = runTest {
        val factory = FakeAuthRemoteServiceFactory(
            service = FakeAuthRemoteService(
                healthResponse = Response.error(
                    401,
                    "{}".toResponseBody("application/json".toMediaType()),
                ),
            ),
        )
        val api = RetrofitSessionAuthApi(serviceFactory = factory)

        val valid = api.validateSession(
            CookieSession(
                baseUrl = "https://demo.example.com",
                cookie = "auth=token-123",
                isLocalMode = false,
            ),
        )

        assertEquals("https://demo.example.com", factory.lastBaseUrl)
        assertEquals("auth=token-123", factory.lastCookie)
        assertTrue(factory.service.healthCalled)
        assertFalse(valid)
    }

    @Test
    fun `login maps connect exception to user friendly message`() = runTest {
        val api = RetrofitSessionAuthApi(
            serviceFactory = AuthRemoteServiceFactory { _, _ ->
                throw ConnectException("failed to connect")
            },
        )

        val error = runCatching {
            api.login(
                baseUrl = "http://demo.example.com",
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertEquals("无法连接服务器", error?.message)
    }

    @Test
    fun `login maps missing auth cookie to user friendly message`() = runTest {
        val factory = FakeAuthRemoteServiceFactory(
            service = FakeAuthRemoteService(
                loginResponse = Response.success(Unit),
            ),
        )
        val api = RetrofitSessionAuthApi(serviceFactory = factory)

        val error = runCatching {
            api.login(
                baseUrl = "https://demo.example.com",
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertEquals("登录成功但未收到认证信息", error?.message)
    }

    @Test
    fun `login with real retrofit factory does not fail on body converter creation`() = runTest {
        val api = RetrofitSessionAuthApi(
            serviceFactory = RetrofitAuthRemoteServiceFactory(),
        )

        val error = runCatching {
            api.login(
                baseUrl = "http://127.0.0.1:9",
                username = "demo",
                password = "secret",
            )
        }.exceptionOrNull()

        assertEquals("无法连接服务器", error?.message)
    }
}

private class FakeAuthRemoteServiceFactory(
    val service: FakeAuthRemoteService,
) : AuthRemoteServiceFactory {
    var lastBaseUrl: String = ""
    var lastCookie: String = ""

    override fun create(baseUrl: String, cookie: String): AuthRemoteService {
        lastBaseUrl = baseUrl
        lastCookie = cookie
        return service
    }
}

private class FakeAuthRemoteService(
    private val loginResponse: Response<Unit> = Response.success(Unit),
    private val healthResponse: Response<Unit> = Response.success(Unit),
) : AuthRemoteService {
    var lastUsername: String = ""
    var lastPassword: String = ""
    var healthCalled: Boolean = false

    override suspend fun login(username: String, password: String): Response<Unit> {
        lastUsername = username
        lastPassword = password
        return loginResponse
    }

    override suspend fun health(): Response<Unit> {
        healthCalled = true
        return healthResponse
    }
}
