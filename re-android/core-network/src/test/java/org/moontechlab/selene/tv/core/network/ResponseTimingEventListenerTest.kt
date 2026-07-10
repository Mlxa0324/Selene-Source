package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import java.io.IOException
import org.junit.Test

/**
 * 校验全局 HTTP 耗时日志格式契约。
 */
class ResponseTimingEventListenerTest {
    /**
     * 成功请求应输出方法、地址、状态码和毫秒耗时。
     */
    @Test
    fun formatMessage_includes_success_fields() {
        val message = ResponseTimingEventListener.formatMessage(
            method = "GET",
            url = "https://tv.example.com/api/detail?source=a&id=1",
            statusCode = 200,
            protocol = "h2",
            elapsedMs = 1284L,
            error = null,
        )

        assertThat(message).isEqualTo(
            "GET https://tv.example.com/api/detail?source=a&id=1 -> 200 1284ms protocol=h2",
        )
    }

    /**
     * 失败请求应输出 ERR 和异常原因。
     */
    @Test
    fun formatMessage_includes_error_reason() {
        val message = ResponseTimingEventListener.formatMessage(
            method = "GET",
            url = "https://m.douban.example/rexxar/api/v2/subject/26683290",
            statusCode = null,
            protocol = "",
            elapsedMs = 5032L,
            error = IOException("timeout"),
        )

        assertThat(message).isEqualTo(
            "GET https://m.douban.example/rexxar/api/v2/subject/26683290 -> ERR 5032ms protocol=- error=timeout",
        )
    }
}
