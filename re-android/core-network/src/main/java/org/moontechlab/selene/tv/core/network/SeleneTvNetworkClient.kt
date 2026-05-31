package org.moontechlab.selene.tv.core.network

import okhttp3.Headers
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

/**
 * TV 后台网关客户端契约。
 */
interface SeleneTvGatewayClient {
    /** TV 数据接口。 */
    val tvApi: SeleneTvApi

    /**
     * 使用账号密码登录后台。
     *
     * @param username 登录账号。
     * @param password 登录密码。
     * @return 登录后保存的会话。
     */
    suspend fun login(
        username: String,
        password: String,
    ): SessionPayload
}

/**
 * TV 后台网关客户端。
 *
 * @property baseUrl 标准化后的服务器基础地址。
 * @property tvApi TV 数据接口。
 * @property authApi TV 认证接口。
 * @property sessionCookieStore 会话存储。
 */
class SeleneTvNetworkClient(
    private val baseUrl: String,
    override val tvApi: SeleneTvApi,
    private val authApi: SeleneTvAuthApi,
    private val sessionCookieStore: SessionCookieStore,
) : SeleneTvGatewayClient {
    /**
     * 使用账号密码登录后台。
     *
     * @param username 登录账号。
     * @param password 登录密码。
     * @return 登录后保存的会话。
     */
    override suspend fun login(
        username: String,
        password: String,
    ): SessionPayload {
        val normalizedUsername = username.trim()
        val response = authApi.login(
            SeleneTvLoginRequest(
                username = normalizedUsername,
                password = password,
            ),
        )
        if (!response.isSuccessful) {
            // 认证失败直接抛给 ViewModel，首页展示明确错误态。
            throw IllegalStateException(
                if (response.code() == UNAUTHORIZED_STATUS_CODE) {
                    "后台账号或密码错误"
                } else {
                    "后台登录失败(${response.code()})"
                },
            )
        }
        val cookie = SeleneTvNetworkFactory.parseSetCookie(response.headers())
        sessionCookieStore.saveSession(
            baseUrl = baseUrl.trimEnd('/'),
            account = normalizedUsername,
            cookie = cookie,
        )
        return sessionCookieStore.readSession()
            ?: error("后台会话保存失败")
    }

    private companion object {
        /** 后台认证失败状态码。 */
        const val UNAUTHORIZED_STATUS_CODE = 401
    }
}

/**
 * TV 后台网络客户端工厂。
 */
object SeleneTvNetworkFactory {
    /**
     * 创建 TV 后台客户端。
     *
     * @param rawBaseUrl 原始服务器地址。
     * @param sessionCookieStore 会话存储。
     * @return TV 后台客户端。
     */
    fun create(
        rawBaseUrl: String,
        sessionCookieStore: SessionCookieStore = SessionCookieStore(),
    ): SeleneTvNetworkClient {
        val baseUrl = normalizeBaseUrl(rawBaseUrl)
        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor(
                AuthInterceptor(
                    cookieProvider = { sessionCookieStore.currentCookie() },
                ),
            )
            .build()
        val retrofit = Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
        return SeleneTvNetworkClient(
            baseUrl = baseUrl,
            tvApi = retrofit.create(SeleneTvApi::class.java),
            authApi = retrofit.create(SeleneTvAuthApi::class.java),
            sessionCookieStore = sessionCookieStore,
        )
    }

    /**
     * 标准化 Retrofit 基础地址。
     *
     * @param rawBaseUrl 原始服务器地址。
     * @return 带协议和末尾斜杠的基础地址。
     */
    fun normalizeBaseUrl(rawBaseUrl: String): String {
        val trimmed = rawBaseUrl.trim()
        require(trimmed.isNotEmpty()) { "服务器地址未配置" }
        val withScheme = if (
            trimmed.startsWith("http://", ignoreCase = true) ||
            trimmed.startsWith("https://", ignoreCase = true)
        ) {
            trimmed
        } else {
            "http://$trimmed"
        }
        return withScheme.trimEnd('/') + "/"
    }

    /**
     * 从登录响应头解析 Cookie。
     *
     * @param headers 登录响应头。
     * @return 可直接放入 Cookie header 的字符串。
     */
    fun parseSetCookie(headers: Headers): String {
        return headers.values("Set-Cookie")
            .flatMap { header -> header.split(",") }
            .map { item -> item.substringBefore(";").trim() }
            .filter { item -> item.isNotEmpty() }
            .joinToString("; ")
    }
}
