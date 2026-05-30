package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验 TV 会话 Cookie 存储契约。
 */
class SessionCookieStoreTest {
    /**
     * 保存会话后应能读回服务器地址、账号和 Cookie。
     */
    @Test
    fun saveSession_persists_base_url_account_and_cookie() = runTest {
        val store = SessionCookieStore()

        store.saveSession(
            baseUrl = "https://example.com",
            account = "demo",
            cookie = "sid=1",
        )

        val session = store.readSession()
        assertThat(session?.baseUrl).isEqualTo("https://example.com")
        assertThat(session?.account).isEqualTo("demo")
        assertThat(session?.cookie).isEqualTo("sid=1")
    }
}
