package org.moontechlab.selene.tv.core.network

import android.util.Log
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.Call
import okhttp3.EventListener
import okhttp3.Protocol
import okhttp3.Response

/**
 * 全局 HTTP 请求耗时监听器。
 *
 * 在 [callStart] 到 [callEnd]/[callFailed] 之间统计整次调用耗时，
 * 覆盖 Retrofit body 反序列化前的完整网络阶段，也覆盖 SSE 长连接整段时长。
 *
 * @property logger 日志输出函数，默认写入 Logcat。
 */
class ResponseTimingEventListener(
    private val logger: (String) -> Unit = DEFAULT_LOGGER,
) : EventListener() {
    /** 调用开始时间（纳秒）。 */
    private var callStartNs: Long = 0L

    /** 请求方法。 */
    private var method: String = ""

    /** 请求地址。 */
    private var url: String = ""

    /** HTTP 状态码，失败时为 null。 */
    private var statusCode: Int? = null

    /** 协议版本，例如 h2 / http/1.1。 */
    private var protocol: String = ""

    /**
     * 记录调用开始。
     *
     * @param call 当前 HTTP 调用。
     */
    override fun callStart(call: Call) {
        callStartNs = System.nanoTime()
        method = call.request().method
        url = call.request().url.toString()
        statusCode = null
        protocol = ""
    }

    /**
     * 记录响应头到达时的状态信息。
     *
     * @param call 当前 HTTP 调用。
     * @param response 响应头。
     */
    override fun responseHeadersEnd(call: Call, response: Response) {
        statusCode = response.code
        protocol = response.protocol.toDisplayName()
    }

    /**
     * 记录调用成功结束。
     *
     * @param call 当前 HTTP 调用。
     */
    override fun callEnd(call: Call) {
        logger(
            formatMessage(
                method = method.ifBlank { call.request().method },
                url = url.ifBlank { call.request().url.toString() },
                statusCode = statusCode,
                protocol = protocol,
                elapsedMs = elapsedMs(),
                error = null,
            ),
        )
    }

    /**
     * 记录调用失败。
     *
     * @param call 当前 HTTP 调用。
     * @param ioe 失败异常。
     */
    override fun callFailed(call: Call, ioe: IOException) {
        logger(
            formatMessage(
                method = method.ifBlank { call.request().method },
                url = url.ifBlank { call.request().url.toString() },
                statusCode = statusCode,
                protocol = protocol,
                elapsedMs = elapsedMs(),
                error = ioe,
            ),
        )
    }

    /**
     * 计算从 callStart 到当前的耗时毫秒。
     *
     * @return 耗时毫秒。
     */
    private fun elapsedMs(): Long {
        if (callStartNs <= 0L) {
            return 0L
        }
        return TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - callStartNs)
    }

    companion object {
        /** Logcat 标签，便于统一过滤。 */
        const val LOG_TAG = "SeleneTV-HTTP"

        /** 默认日志输出。 */
        val DEFAULT_LOGGER: (String) -> Unit = { message ->
            Log.i(LOG_TAG, message)
        }

        /**
         * 格式化请求耗时日志。
         *
         * @param method HTTP 方法。
         * @param url 请求地址。
         * @param statusCode HTTP 状态码。
         * @param protocol 协议版本。
         * @param elapsedMs 总耗时毫秒。
         * @param error 失败异常。
         * @return 单行日志文本。
         */
        fun formatMessage(
            method: String,
            url: String,
            statusCode: Int?,
            protocol: String,
            elapsedMs: Long,
            error: Throwable?,
        ): String {
            val statusText = statusCode?.toString() ?: "ERR"
            val protocolText = protocol.takeIf { value -> value.isNotBlank() } ?: "-"
            val errorText = error
                ?.let { throwable ->
                    val reason = throwable.message
                        ?.takeIf { message -> message.isNotBlank() }
                        ?: throwable.javaClass.simpleName
                    " error=$reason"
                }
                .orEmpty()
            return "$method $url -> $statusText ${elapsedMs}ms protocol=$protocolText$errorText"
        }

        /**
         * 协议显示名。
         *
         * @return 简短协议文本。
         */
        private fun Protocol.toDisplayName(): String {
            return when (this) {
                Protocol.HTTP_1_0 -> "http/1.0"
                Protocol.HTTP_1_1 -> "http/1.1"
                Protocol.HTTP_2 -> "h2"
                Protocol.H2_PRIOR_KNOWLEDGE -> "h2c"
                Protocol.QUIC -> "quic"
                else -> toString()
            }
        }
    }
}

/**
 * 为每次 HTTP 调用创建独立的耗时监听器。
 *
 * @property logger 日志输出函数。
 */
class ResponseTimingEventListenerFactory(
    private val logger: (String) -> Unit = ResponseTimingEventListener.DEFAULT_LOGGER,
) : EventListener.Factory {
    /**
     * 创建单次调用监听器。
     *
     * @param call 当前 HTTP 调用。
     * @return 新的耗时监听器实例。
     */
    override fun create(call: Call): EventListener {
        // 每次 call 都要新实例，避免并发请求共享 start 时间戳。
        return ResponseTimingEventListener(logger = logger)
    }
}
