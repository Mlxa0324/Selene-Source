package org.moontechlab.selene.tv.core.network

import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.reflect.TypeToken
import java.io.BufferedReader
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse
import kotlin.coroutines.coroutineContext

/**
 * TV 搜索流式客户端契约。
 */
interface SeleneTvSearchStreamClient {
    /**
     * 以 SSE 方式搜索影视内容。
     *
     * @param query 搜索关键词。
     * @param onEvent 每条 SSE 事件的回调。
     */
    suspend fun search(
        query: String,
        onEvent: (TvSearchStreamEvent) -> Unit,
    )
}

/**
 * TV 搜索流式事件。
 *
 * @property timestamp 事件时间戳。
 */
sealed interface TvSearchStreamEvent {
    val timestamp: Long
}

/**
 * 搜索开始事件。
 *
 * @property query 当前搜索词。
 * @property totalSources 参与搜索的资源站数量。
 * @property timestamp 事件时间戳。
 */
data class TvSearchStartEvent(
    val query: String,
    val totalSources: Int,
    override val timestamp: Long,
) : TvSearchStreamEvent

/**
 * 单个资源站的搜索结果事件。
 *
 * @property source 资源站标识。
 * @property sourceName 资源站名称。
 * @property results 当前资源站返回的结果批次。
 * @property timestamp 事件时间戳。
 */
data class TvSearchSourceResultEvent(
    val source: String,
    val sourceName: String,
    val results: List<TvSearchResultResponse>,
    override val timestamp: Long,
) : TvSearchStreamEvent

/**
 * 单个资源站的错误事件。
 *
 * @property source 资源站标识。
 * @property sourceName 资源站名称。
 * @property error 错误信息。
 * @property timestamp 事件时间戳。
 */
data class TvSearchSourceErrorEvent(
    val source: String,
    val sourceName: String,
    val error: String,
    override val timestamp: Long,
) : TvSearchStreamEvent

/**
 * 搜索完成事件。
 *
 * @property totalResults 最终结果总数。
 * @property completedSources 已完成的资源站数量。
 * @property timestamp 事件时间戳。
 */
data class TvSearchCompleteEvent(
    val totalResults: Int,
    val completedSources: Int,
    override val timestamp: Long,
) : TvSearchStreamEvent

/**
 * Selene TV 搜索 SSE 客户端。
 *
 * 对齐 Flutter：
 * 1. 优先连接 `/api/search/ws`；
 * 2. 失败后降级 `/api/search?stream=1`；
 * 3. 整段阻塞 IO 必须跑在 [Dispatchers.IO]，避免详情页/搜索页在主线程直接 [Call.execute]。
 *
 * 复用 TV 后台同一套 Cookie 会话，让原生 TV 详情页和搜索页都能边搜边展示线路。
 *
 * @property rawBaseUrl 后台原始基础地址。
 * @property sessionCookieStore 会话 Cookie 存储。
 * @property client SSE 使用的 HTTP 客户端。
 */
class SeleneTvSseSearchClient(
    rawBaseUrl: String,
    private val sessionCookieStore: SessionCookieStore,
    client: OkHttpClient? = null,
) : SeleneTvSearchStreamClient {
    /** SSE 使用的 HTTP 客户端。 */
    private val client: OkHttpClient = (client ?: SeleneTvNetworkFactory.createOkHttpClient(sessionCookieStore))
        .newBuilder()
        // SSE 长连接不能沿用普通 REST 的读超时，否则某个源慢一点就会被 OkHttp 提前切断。
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    /** 标准化后的后台基础地址。 */
    private val baseUrl: String = SeleneTvNetworkFactory.normalizeBaseUrl(rawBaseUrl)

    /** SSE 事件解析器。 */
    private val eventParser = TvSearchStreamEventParser()

    /**
     * 以 SSE 方式执行搜索。
     *
     * @param query 搜索关键词。
     * @param onEvent 每条 SSE 事件的回调。
     */
    override suspend fun search(
        query: String,
        onEvent: (TvSearchStreamEvent) -> Unit,
    ) {
        val normalizedQuery = query.trim()
        if (normalizedQuery.isBlank()) {
            return
        }
        // 阻塞式 OkHttp execute/读流统一切到 IO，避免主线程 NetworkOnMainThread 导致 0ms ERR。
        withContext(Dispatchers.IO) {
            val endpoints = buildStreamEndpoints(normalizedQuery)
            var lastError: Throwable? = null
            for ((index, endpoint) in endpoints.withIndex()) {
                val emittedAnyResult = AtomicBoolean(false)
                val wrappedOnEvent: (TvSearchStreamEvent) -> Unit = { event ->
                    if (event is TvSearchSourceResultEvent && event.results.isNotEmpty()) {
                        emittedAnyResult.set(true)
                    }
                    onEvent(event)
                }
                val result = runCatching {
                    Log.i(LOG_TAG, "开始流式搜索 endpoint=${endpoint.label} q=$normalizedQuery")
                    executeStream(endpoint.url, wrappedOnEvent)
                }
                if (result.isSuccess) {
                    Log.i(
                        LOG_TAG,
                        "流式搜索完成 endpoint=${endpoint.label} emittedResults=${emittedAnyResult.get()}",
                    )
                    // 当前端点已有增量结果时直接结束；空结果再尝试下一个流式端点。
                    if (emittedAnyResult.get() || index == endpoints.lastIndex) {
                        return@withContext
                    }
                    Log.w(LOG_TAG, "流式端点无结果，尝试下一个: ${endpoint.label}")
                    continue
                }
                lastError = result.exceptionOrNull()
                Log.w(
                    LOG_TAG,
                    "流式端点失败 endpoint=${endpoint.label} error=${lastError?.javaClass?.simpleName}:${lastError?.message}",
                )
            }
            throw lastError ?: IllegalStateException("TV 搜索 SSE 全部端点失败")
        }
    }

    /**
     * 构造流式搜索端点列表。
     *
     * @param query 搜索关键词。
     * @return 优先 ws、再 stream=1 的端点列表。
     */
    private fun buildStreamEndpoints(query: String): List<StreamEndpoint> {
        val root = baseUrl.toHttpUrl()
        return listOf(
            StreamEndpoint(
                label = "/api/search/ws",
                url = root.newBuilder()
                    .addPathSegments("api/search/ws")
                    .addQueryParameter("q", query)
                    .addQueryParameter("timeout", DEFAULT_STREAM_TIMEOUT_SECONDS)
                    .build(),
            ),
            StreamEndpoint(
                label = "/api/search?stream=1",
                url = root.newBuilder()
                    .addPathSegments("api/search")
                    .addQueryParameter("q", query)
                    .addQueryParameter("stream", "1")
                    .addQueryParameter("timeout", DEFAULT_STREAM_TIMEOUT_SECONDS)
                    .build(),
            ),
        )
    }

    /**
     * 执行单个流式端点并顺序分发事件。
     *
     * @param url 流式搜索地址。
     * @param onEvent 事件回调。
     */
    private suspend fun executeStream(
        url: HttpUrl,
        onEvent: (TvSearchStreamEvent) -> Unit,
    ) {
        val request = Request.Builder()
            .url(url)
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
            .apply {
                sessionCookieStore.currentCookie()
                    ?.takeIf { cookie -> cookie.isNotBlank() }
                    ?.let { cookie -> header("Cookie", cookie) }
            }
            .build()
        val call = client.newCall(request)
        // 协程取消时立刻关掉 OkHttp 调用，避免详情页离开后还继续占着连接。
        val completionHandle = coroutineContext[Job]
            ?.invokeOnCompletion { cause ->
                if (cause != null) {
                    call.cancel()
                }
            }
        try {
            call.execute().use { response ->
                if (!response.isSuccessful) {
                    throw IllegalStateException("TV 搜索 SSE 连接失败(${response.code})")
                }
                val reader = response.body?.charStream()?.buffered()
                    ?: return
                readEventStream(reader, onEvent)
            }
        } finally {
            completionHandle?.dispose()
            if (!call.isCanceled()) {
                call.cancel()
            }
        }
    }

    /**
     * 顺序消费 SSE / NDJSON 文本流。
     *
     * @param reader 文本读取器。
     * @param onEvent 每条事件的回调。
     */
    private suspend fun readEventStream(
        reader: BufferedReader,
        onEvent: (TvSearchStreamEvent) -> Unit,
    ) {
        // use 块不是 suspend lambda，这里改用 CoroutineContext.ensureActive 检查取消。
        val activeContext = coroutineContext
        reader.use { activeReader ->
            while (true) {
                activeContext.ensureActive()
                val rawLine = activeReader.readLine() ?: break
                val line = rawLine.trim()
                if (line.isEmpty()) {
                    continue
                }
                val payload = when {
                    line.startsWith(SSE_DATA_PREFIX) -> line.removePrefix(SSE_DATA_PREFIX).trim()
                    // stream=1 有时直接吐 NDJSON，没有 data: 前缀。
                    line.startsWith("{") || line.startsWith("[") -> line
                    else -> continue
                }
                if (payload.isEmpty() || payload == SSE_DONE_PAYLOAD) {
                    continue
                }
                val event = eventParser.parse(payload) ?: continue
                onEvent(event)
            }
        }
    }

    /**
     * 流式搜索端点描述。
     *
     * @property label 日志用端点标签。
     * @property url 完整请求地址。
     */
    private data class StreamEndpoint(
        val label: String,
        val url: HttpUrl,
    )

    private companion object {
        /** 日志标签。 */
        const val LOG_TAG = "SeleneTV-SSE"

        /** SSE 数据行前缀。 */
        const val SSE_DATA_PREFIX = "data:"

        /** SSE 结束标记。 */
        const val SSE_DONE_PAYLOAD = "[DONE]"

        /** 与 Flutter 对齐的流式搜索超时秒数。 */
        const val DEFAULT_STREAM_TIMEOUT_SECONDS = "30"
    }
}

/**
 * TV 搜索 SSE 事件解析器。
 *
 * @property gson JSON 解析器。
 */
internal class TvSearchStreamEventParser(
    private val gson: Gson = Gson(),
) {
    /**
     * 把单条 SSE / NDJSON payload 解析成强类型事件。
     *
     * @param payload 单条 `data:` 后的 JSON 文本。
     * @return 解析后的事件；可忽略的失败源心跳返回 null。
     */
    fun parse(payload: String): TvSearchStreamEvent? {
        val root = JsonParser.parseString(payload)
        if (root.isJsonArray) {
            // 少数兼容实现会直接吐结果数组。
            val results = gson.fromJson<List<TvSearchResultResponse>>(
                root,
                object : TypeToken<List<TvSearchResultResponse>>() {}.type,
            ).orEmpty()
            if (results.isEmpty()) {
                return null
            }
            return TvSearchSourceResultEvent(
                source = "",
                sourceName = "",
                results = results,
                timestamp = 0L,
            )
        }

        val json = root.asJsonObject
        val type = json.readString("type")
        if (type.isNotBlank()) {
            return when (type) {
                "start" -> TvSearchStartEvent(
                    query = json.readString("query"),
                    totalSources = json.readInt("totalSources"),
                    timestamp = json.readTimestamp(),
                )

                "source_result" -> TvSearchSourceResultEvent(
                    source = json.readString("source"),
                    sourceName = json.readString("sourceName"),
                    results = json.readResults(gson),
                    timestamp = json.readTimestamp(),
                )

                "source_error" -> TvSearchSourceErrorEvent(
                    source = json.readString("source"),
                    sourceName = json.readString("sourceName"),
                    error = json.readString("error"),
                    timestamp = json.readTimestamp(),
                )

                "complete" -> TvSearchCompleteEvent(
                    totalResults = json.readInt("totalResults"),
                    completedSources = json.readInt("completedSources"),
                    timestamp = json.readTimestamp(),
                )

                else -> throw IllegalArgumentException("未知 TV 搜索 SSE 事件类型：$type")
            }
        }

        // 兼容 /api/search?stream=1 的 pageResults / results 批次。
        val pageResults = json.readResultList(gson, "pageResults")
        if (pageResults.isNotEmpty()) {
            return TvSearchSourceResultEvent(
                source = json.readString("source"),
                sourceName = json.readString("sourceName"),
                results = pageResults,
                timestamp = json.readTimestamp(),
            )
        }
        val plainResults = json.readResultList(gson, "results")
        if (plainResults.isNotEmpty()) {
            return TvSearchSourceResultEvent(
                source = json.readString("source"),
                sourceName = json.readString("sourceName"),
                results = plainResults,
                timestamp = json.readTimestamp(),
            )
        }
        // failedSources 等心跳信息没有可展示结果，直接跳过。
        if (json.has("failedSources")) {
            return null
        }
        throw IllegalArgumentException("无法识别的 TV 搜索流式 payload")
    }

    /**
     * 读取字符串字段。
     *
     * @param key JSON 字段名。
     * @return 对应字符串值；空值回退为空串。
     */
    private fun JsonObject.readString(key: String): String {
        return get(key)
            ?.takeIf { element -> !element.isJsonNull }
            ?.asString
            .orEmpty()
    }

    /**
     * 读取整数字段。
     *
     * @param key JSON 字段名。
     * @return 对应整型值；缺失时回退 0。
     */
    private fun JsonObject.readInt(key: String): Int {
        return get(key)
            ?.takeIf { element -> !element.isJsonNull }
            ?.asInt
            ?: 0
    }

    /**
     * 读取时间戳字段。
     *
     * @return 时间戳；缺失时回退 0。
     */
    private fun JsonObject.readTimestamp(): Long {
        return get("timestamp")
            ?.takeIf { element -> !element.isJsonNull }
            ?.asLong
            ?: 0L
    }

    /**
     * 读取搜索结果列表。
     *
     * @param gson JSON 解析器。
     * @return 当前结果批次。
     */
    private fun JsonObject.readResults(gson: Gson): List<TvSearchResultResponse> {
        return readResultList(gson, "results")
    }

    /**
     * 按字段名读取搜索结果列表。
     *
     * @param gson JSON 解析器。
     * @param key 字段名。
     * @return 结果批次；缺失或非法时返回空列表。
     */
    private fun JsonObject.readResultList(gson: Gson, key: String): List<TvSearchResultResponse> {
        val resultsElement = get(key)
            ?.takeIf { element -> !element.isJsonNull && element.isJsonArray }
            ?: return emptyList()
        return gson.fromJson(
            resultsElement,
            object : TypeToken<List<TvSearchResultResponse>>() {}.type,
        ) ?: emptyList()
    }
}
