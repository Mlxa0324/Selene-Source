package org.moontechlab.selene.tv.core.network

import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.reflect.TypeToken
import java.io.BufferedReader
import java.util.concurrent.TimeUnit
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

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
 * 复用 TV 后台同一套 Cookie 会话，直接消费 `/api/search/ws` 的流式结果，
 * 让原生 TV 详情页和搜索页都能像 Flutter 一样边搜边展示。
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
        val request = Request.Builder()
            .url(
                baseUrl.toHttpUrl()
                    .newBuilder()
                    .addPathSegments("api/search/ws")
                    .addQueryParameter("q", normalizedQuery)
                    .build(),
            )
            .header("Accept", "text/event-stream")
            .header("Cache-Control", "no-cache")
            .apply {
                sessionCookieStore.currentCookie()
                    ?.takeIf { cookie -> cookie.isNotBlank() }
                    ?.let { cookie -> header("Cookie", cookie) }
            }
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("TV 搜索 SSE 连接失败(${response.code})")
            }
            val reader = response.body?.charStream()?.buffered()
                ?: return
            readEventStream(reader, onEvent)
        }
    }

    /**
     * 顺序消费 SSE 文本流。
     *
     * @param reader SSE 文本读取器。
     * @param onEvent 每条 SSE 事件的回调。
     */
    private fun readEventStream(
        reader: BufferedReader,
        onEvent: (TvSearchStreamEvent) -> Unit,
    ) {
        reader.useLines { lines ->
            lines.forEach { rawLine ->
                val line = rawLine.trim()
                if (line.isEmpty() || !line.startsWith(SSE_DATA_PREFIX)) {
                    return@forEach
                }
                val payload = line.removePrefix(SSE_DATA_PREFIX).trim()
                if (payload.isEmpty()) {
                    return@forEach
                }
                onEvent(eventParser.parse(payload))
            }
        }
    }

    private companion object {
        /** SSE 数据行前缀。 */
        const val SSE_DATA_PREFIX = "data:"
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
     * 把单条 SSE payload 解析成强类型事件。
     *
     * @param payload 单条 `data:` 后的 JSON 文本。
     * @return 解析后的 SSE 事件。
     */
    fun parse(payload: String): TvSearchStreamEvent {
        val json = JsonParser.parseString(payload).asJsonObject
        val type = json.readString("type")
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
        val resultsElement = get("results")
            ?.takeIf { element -> !element.isJsonNull }
            ?: return emptyList()
        return gson.fromJson(
            resultsElement,
            object : TypeToken<List<TvSearchResultResponse>>() {}.type,
        )
    }
}
