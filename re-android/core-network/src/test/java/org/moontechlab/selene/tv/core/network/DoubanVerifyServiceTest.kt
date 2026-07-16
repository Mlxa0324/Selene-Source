package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import java.security.MessageDigest
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * 校验豆瓣 PoW 验证链路对 302 Cookie 的回收契约。
 *
 * 豆瓣验证成功时会在 POST `/c` 的 302 响应写入 `dbsawcv1`；
 * 若只读取最终响应头，Cookie 会丢失，相关推荐永远解析为空。
 */
class DoubanVerifyServiceTest {
    private lateinit var server: MockWebServer

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        server.shutdown()
    }

    /**
     * 验证提交后即使 OkHttp 自动跟随 302，也应从 prior 链回收 `dbsawcv1`，
     * 并在重试详情页时携带该 Cookie，最终返回含相关推荐的正文。
     */
    @Test
    fun fetchWithVerify_keeps_pow_cookie_from_redirect_chain() = runTest {
        val challenge = "unit-test-challenge"
        val solution = solvePow(challenge)
        val subjectPath = "/subject/36217763"
        val challengeHtml = """
            <html>
              <div id="sec"></div>
              <input id="tok" name="tok" value="tok-1" />
              <input id="cha" name="cha" value="$challenge" />
              <input id="red" name="red" value="${server.url(subjectPath)}" />
            </html>
        """.trimIndent()
        val successHtml = """
            <html>
              <span property="v:itemreviewed">我的妈耶</span>
              <div id="recommendations">
                <dl>
                  <dt>
                    <a href="https://movie.douban.com/subject/36522427/">
                      <img src="https://img.test/a.jpg" alt="奇遇" />
                    </a>
                  </dt>
                </dl>
              </div>
            </html>
        """.trimIndent()

        server.dispatcher = object : Dispatcher() {
            private var subjectHits = 0

            override fun dispatch(request: RecordedRequest): MockResponse {
                val path = request.path.orEmpty()
                return when {
                    // 详情页：首次返回验证页，持有 dbsawcv1 后返回推荐正文。
                    path.startsWith(subjectPath) && request.method == "GET" -> {
                        subjectHits += 1
                        val cookie = request.getHeader("Cookie").orEmpty()
                        if (cookie.contains("dbsawcv1=session-cookie")) {
                            MockResponse()
                                .setResponseCode(200)
                                .setBody(successHtml)
                        } else {
                            MockResponse()
                                .setResponseCode(200)
                                .setBody(challengeHtml)
                        }
                    }

                    // 验证提交：302 下发会话 Cookie；即使被跟随，prior 链也应保留它。
                    path == "/c" && request.method == "POST" -> {
                        val body = request.body.readUtf8()
                        assertThat(body).contains("tok=tok-1")
                        assertThat(body).contains("cha=$challenge")
                        assertThat(body).contains("sol=$solution")
                        MockResponse()
                            .setResponseCode(302)
                            .addHeader(
                                "Set-Cookie",
                                "dbsawcv1=session-cookie; Max-Age=120; Path=/",
                            )
                            .addHeader("Location", server.url(subjectPath).toString())
                    }

                    else -> MockResponse().setResponseCode(404)
                }
            }
        }

        val client = OkHttpClient.Builder()
            .followRedirects(true)
            .followSslRedirects(true)
            .build()
        val service = DoubanVerifyService(
            client = client,
            verifyUrl = server.url("/c").toString(),
        )

        val html = service.fetchWithVerify(server.url(subjectPath).toString())

        assertThat(service.hasVerifySessionCookie()).isTrue()
        assertThat(html).contains("""id="recommendations"""")
        assertThat(html).contains("奇遇")
        assertThat(html).doesNotContain("""id="sec"""")

        // 至少命中：首次详情、验证后详情（验证 POST 关闭自动跟随，不再额外请求 Location）。
        assertThat(server.requestCount).isAtLeast(3)
    }

    /**
     * 磁盘 Cookie 应在构造时回灌，后续请求直接携带会话，避免重复 PoW。
     */
    @Test
    fun fetchWithVerify_restores_persisted_session_cookie() = runTest {
        val store = InMemoryDoubanCookieStore(
            initial = listOf(
                DoubanPersistedCookie(
                    name = "dbsawcv1",
                    value = "persisted-session",
                    expiryEpochMs = System.currentTimeMillis() + 120_000,
                ),
            ),
        )
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""<div id="recommendations"><dl></dl></div>"""),
        )
        val service = DoubanVerifyService(
            client = OkHttpClient(),
            verifyUrl = server.url("/c").toString(),
            cookieStore = store,
        )

        assertThat(service.hasVerifySessionCookie()).isTrue()
        service.fetchWithVerify(server.url("/subject/1").toString())

        val request = server.takeRequest()
        assertThat(request.getHeader("Cookie")).contains("dbsawcv1=persisted-session")
        assertThat(server.requestCount).isEqualTo(1)
    }

    /**
     * 无验证页时直接返回正文，不应额外提交 PoW。
     */
    @Test
    fun fetchWithVerify_returns_body_when_challenge_absent() = runTest {
        server.enqueue(
            MockResponse()
                .setResponseCode(200)
                .setBody("""<div id="recommendations"><dl></dl></div>"""),
        )
        val service = DoubanVerifyService(
            client = OkHttpClient(),
            verifyUrl = server.url("/c").toString(),
        )

        val html = service.fetchWithVerify(server.url("/subject/1").toString())

        assertThat(html).contains("recommendations")
        assertThat(server.requestCount).isEqualTo(1)
        assertThat(service.hasVerifySessionCookie()).isFalse()
    }

    /**
     * 本地复现 PoW 求解，保证测试与生产难度前缀一致。
     *
     * @param cha 挑战串。
     * @return 满足 4 个前导零的 nonce。
     */
    private fun solvePow(cha: String): Int {
        val digest = MessageDigest.getInstance("SHA-512")
        var nonce = 0
        while (true) {
            nonce++
            val hash = digest.digest((cha + nonce).toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }
            if (hash.startsWith("0000")) {
                return nonce
            }
        }
    }
}

/**
 * 测试用内存 Cookie 存储。
 */
private class InMemoryDoubanCookieStore(
    initial: List<DoubanPersistedCookie> = emptyList(),
) : DoubanCookieStore {
    private var cookies: List<DoubanPersistedCookie> = initial

    override fun load(): List<DoubanPersistedCookie> = cookies

    override fun save(cookies: List<DoubanPersistedCookie>) {
        this.cookies = cookies
    }
}
