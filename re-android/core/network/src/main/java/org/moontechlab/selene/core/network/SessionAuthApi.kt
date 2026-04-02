package org.moontechlab.selene.core.network

import com.squareup.moshi.Json
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST

interface SessionAuthApi {
    suspend fun login(baseUrl: String, username: String, password: String): CookieSession
    suspend fun validateSession(session: CookieSession): Boolean
}

class DemoSessionAuthApi : SessionAuthApi {
    override suspend fun login(baseUrl: String, username: String, password: String): CookieSession = CookieSession(
        baseUrl = baseUrl,
        cookie = "auth=demo-token",
        isLocalMode = false,
    )

    override suspend fun validateSession(session: CookieSession): Boolean = true
}

data class LoginRequestDto(
    @Json(name = "username") val username: String,
    @Json(name = "password") val password: String,
)

interface AuthRemoteService {
    suspend fun login(username: String, password: String): Response<Unit>
    suspend fun health(): Response<Unit>
}

fun interface AuthRemoteServiceFactory {
    fun create(baseUrl: String, cookie: String): AuthRemoteService
}

class RetrofitSessionAuthApi(
    private val serviceFactory: AuthRemoteServiceFactory = RetrofitAuthRemoteServiceFactory(),
) : SessionAuthApi {
    override suspend fun login(baseUrl: String, username: String, password: String): CookieSession {
        return runCatching {
            val response = serviceFactory
                .create(baseUrl = baseUrl, cookie = "")
                .login(username = username, password = password)

            if (!response.isSuccessful) {
                throw IllegalStateException(loginErrorMessage(response.code()))
            }

            val cookie = response.headers()
                .values("Set-Cookie")
                .mapNotNull { header -> header.substringBefore(';').trim().takeIf { it.isNotBlank() } }
                .joinToString("; ")

            if (cookie.isBlank()) {
                throw IllegalStateException("missing auth cookie")
            }

            CookieSession(
                baseUrl = baseUrl,
                cookie = cookie,
                isLocalMode = false,
            )
        }.getOrElse { throwable ->
            throw IllegalStateException(normalizeLoginFailure(throwable))
        }
    }

    override suspend fun validateSession(session: CookieSession): Boolean = runCatching {
        serviceFactory
            .create(baseUrl = session.baseUrl, cookie = session.cookie)
            .health()
            .isSuccessful
    }.getOrDefault(false)
}

class RetrofitAuthRemoteServiceFactory : AuthRemoteServiceFactory {
    override fun create(baseUrl: String, cookie: String): AuthRemoteService {
        val client = OkHttpClient.Builder()
            .addInterceptor(
                Interceptor { chain ->
                    val request = chain.request().newBuilder()
                        .header("Accept", "application/json")
                        .header("Content-Type", "application/json")
                        .apply {
                            if (cookie.isNotBlank()) {
                                header("Cookie", cookie)
                            }
                        }
                        .build()
                    chain.proceed(request)
                },
            )
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.NONE
                },
            )
            .build()
        val moshi = Moshi.Builder()
            .addLast(KotlinJsonAdapterFactory())
            .build()
        val retrofit = Retrofit.Builder()
            .baseUrl(normalizeAuthBaseUrl(baseUrl))
            .client(client)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
        val service = retrofit.create(RetrofitAuthService::class.java)
        return object : AuthRemoteService {
            override suspend fun login(username: String, password: String): Response<Unit> =
                service.login(LoginRequestDto(username = username, password = password))

            override suspend fun health(): Response<Unit> = service.health()
        }
    }
}

private interface RetrofitAuthService {
    @POST("api/login")
    suspend fun login(@Body request: LoginRequestDto): Response<Unit>

    @GET("api/health")
    suspend fun health(): Response<Unit>
}

private fun loginErrorMessage(code: Int): String = when (code) {
    401 -> "用户名或密码错误"
    500 -> "服务器错误"
    else -> "登录失败: $code"
}

private fun normalizeLoginFailure(throwable: Throwable): String = when (throwable) {
    is IllegalStateException -> when (throwable.message) {
        "missing auth cookie" -> "登录成功但未收到认证信息"
        else -> throwable.message ?: "登录失败"
    }
    is UnknownHostException, is ConnectException -> "无法连接服务器"
    is SocketTimeoutException -> "连接服务器超时"
    else -> throwable.message ?: "登录失败"
}

private fun normalizeAuthBaseUrl(baseUrl: String): String = buildString {
    append(baseUrl.trim().trimEnd('/'))
    append("/")
}
