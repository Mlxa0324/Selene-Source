package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import okhttp3.OkHttpClient
import org.junit.Test

/**
 * 校验豆瓣详情 HTML 抓取的回退和协程取消边界。
 */
class SeleneDoubanHtmlApiTest {
    /**
     * 直连请求被取消时必须立即传播取消，不能继续请求镜像地址。
     */
    @Test
    fun fetchSubjectHtml_propagates_cancellation_without_mirror_fallback() = runTest {
        val requestCount = AtomicInteger(0)
        val client = OkHttpClient.Builder()
            .addInterceptor {
                requestCount.incrementAndGet()
                throw CancellationException("test cancellation")
            }
            .build()
        val api = SeleneDoubanHtmlApi(
            verifyService = DoubanVerifyService(client),
        )

        val thrown = runCatching {
            api.fetchSubjectHtml("1292052")
        }.exceptionOrNull()

        assertThat(thrown).isInstanceOf(CancellationException::class.java)
        assertThat(requestCount.get()).isEqualTo(1)
    }
}
