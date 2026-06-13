package org.moontechlab.selene.tv.core.network

import okhttp3.Headers
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.IOException
import java.net.URI

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
        val response = try {
            authApi.login(
                SeleneTvLoginRequest(
                    username = normalizedUsername,
                    password = password,
                ),
            )
        } catch (throwable: IOException) {
            // 连接类异常需要转换成 TV 端可操作文案，避免只展示 OkHttp 原始地址。
            throw IllegalStateException(
                buildConnectionErrorMessage(reason = throwable.message),
                throwable,
            )
        }
        if (!response.isSuccessful) {
            // 认证失败直接抛给 ViewModel，首页展示明确错误态。
            throw IllegalStateException(buildLoginFailureMessage(response))
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

    /**
     * 构建后台连接失败提示。
     *
     * @param reason 底层网络异常原因。
     * @return 可直接展示给 TV 用户的诊断文案。
     */
    private fun buildConnectionErrorMessage(reason: String?): String {
        val reasonText = reason
            ?.takeIf { value -> value.isNotBlank() }
            ?.let { value -> "原因：$value。" }
            .orEmpty()
        return "无法连接后台服务：${baseUrl.trimEnd('/')}。" +
            reasonText +
            buildResolvedTargetHint(reason = reason) +
            "请确认 TV/模拟器与后台在同一网络、后台端口已启动并监听局域网地址；" +
            "如果刚修改 local.gateway.properties，请重新构建并安装 TV 应用。"
    }

    /**
     * 构建实际连接地址提示。
     *
     * @param reason 底层网络异常原因。
     * @return 域名最终连接地址和配置地址不一致时的排查提示。
     */
    private fun buildResolvedTargetHint(reason: String?): String {
        val failedTarget = reason
            ?.let { value -> FAILED_CONNECT_TARGET_REGEX.find(value) }
            ?.groupValues
            ?.getOrNull(1)
            .orEmpty()
        if (failedTarget.isBlank()) {
            return ""
        }
        val baseHost = runCatching {
            URI(baseUrl).host.orEmpty()
        }.getOrDefault("")
        if (baseHost.isNotBlank() && failedTarget.contains(baseHost, ignoreCase = true)) {
            return ""
        }
        // 域名和最终连接地址不同，通常是穿透、解析或网关转发到内网地址。
        return "当前请求实际连接到 $failedTarget，" +
            "请检查域名解析、穿透或重定向是否指向可访问的后端 API。"
    }

    /**
     * 构建登录失败提示。
     *
     * @param response 登录接口响应。
     * @return 可直接展示给 TV 用户的登录失败原因。
     */
    private fun buildLoginFailureMessage(response: retrofit2.Response<*>): String {
        if (response.code() == UNAUTHORIZED_STATUS_CODE) {
            return "后台账号或密码错误"
        }
        val errorBody = runCatching {
            response.errorBody()?.string().orEmpty()
        }.getOrDefault("")
        return when {
            errorBody.contains(PASSNAT_MARKER, ignoreCase = true) ->
                "后台地址未命中 Selene 服务：${baseUrl.trimEnd('/')} 返回 PassNAT 节点页面。" +
                    "请检查穿透域名是否绑定到后端服务，或改填真实后端 API 地址。"

            errorBody.contains(HTML_MARKER, ignoreCase = true) ->
                "后台登录失败(${response.code()})：${baseUrl.trimEnd('/')} 返回网页内容，" +
                    "不是 Selene 后台 API。请检查服务器地址是否填到后端接口入口。"

            else -> "后台登录失败(${response.code()})"
        }
    }

    private companion object {
        /** 后台认证失败状态码。 */
        const val UNAUTHORIZED_STATUS_CODE = 401

        /** PassNAT 错误页特征文本。 */
        const val PASSNAT_MARKER = "PassNAT"

        /** HTML 错误页特征文本。 */
        const val HTML_MARKER = "<html"

        /** OkHttp 连接失败目标地址提取规则。 */
        val FAILED_CONNECT_TARGET_REGEX = Regex("Failed to connect to /([^\\s。]+)")
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
