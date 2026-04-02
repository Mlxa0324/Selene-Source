package org.moontechlab.selene.core.network

import okhttp3.Interceptor
import okhttp3.Response

class AuthInterceptor(
    private val sessionStore: CookieSessionStore,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val session = sessionStore.currentSession()
        val request = chain.request().newBuilder().apply {
            if (!session?.cookie.isNullOrBlank()) {
                addHeader("Cookie", session!!.cookie)
            }
        }.build()
        return chain.proceed(request)
    }
}
