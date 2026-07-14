package org.moontechlab.selene.tv.core.network

import com.google.gson.JsonParser
import java.util.concurrent.TimeUnit
import java.util.logging.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.Proxy

/**
 * 外部站点首字母联想服务。
 *
 * 对齐 Flutter [ExternalSearchSuggestionService]：
 * 聚合腾讯视频、爱奇艺、芒果 TV 公开联想接口，仅处理纯字母/数字首字母查询。
 *
 * @property client 专用于外站联想的 OkHttp 客户端（直连、短超时）。
 */
class ExternalSearchSuggestionService(
    private val client: OkHttpClient = createDefaultClient(),
) {
    /**
     * 聚合首字母联想结果。
     *
     * @param query 左侧键盘拼出的查询串。
     * @return 去重后的片名列表；非首字母查询返回空。
     */
    suspend fun fetchSuggestions(query: String): List<String> = withContext(Dispatchers.IO) {
        val normalizedQuery = query.trim().uppercase()
        if (!isInitialsQuery(normalizedQuery)) {
            return@withContext emptyList()
        }
        LOGGER.info("[首字母联想] 开始请求 query=$normalizedQuery")

        // 三端并行，总等待接近最慢一端（Flutter 串行；Kotlin 并行提速，解析规则一致）。
        val (tencent, iqiyi, mgtv) = coroutineScope {
            val tencentDeferred = async {
                runCatching { fetchTencentSuggestions(normalizedQuery) }.getOrDefault(emptyList())
            }
            val iqiyiDeferred = async {
                runCatching { fetchIqiyiSuggestions(normalizedQuery.lowercase()) }.getOrDefault(emptyList())
            }
            val mgtvDeferred = async {
                runCatching { fetchMgtvSuggestions(normalizedQuery.lowercase()) }.getOrDefault(emptyList())
            }
            Triple(tencentDeferred.await(), iqiyiDeferred.await(), mgtvDeferred.await())
        }

        LOGGER.info(
            "[首字母联想] 腾讯=${tencent.size} 爱奇艺=${iqiyi.size} 芒果=${mgtv.size}",
        )
        val merged = tencent + iqiyi + mgtv
        val deduped = dedupeSuggestions(merged)
        LOGGER.info("[首字母联想] 去重后=${deduped.size} 词=$deduped")
        deduped
    }

    /**
     * 请求腾讯视频联想词。
     */
    private fun fetchTencentSuggestions(query: String): List<String> {
        val bodyJson = """
            {
              "query":"$query",
              "page_num":0,
              "page_size":10,
              "scene_id":5,
              "sug_id":"selene_$query",
              "auth_info":{"app_id":"3172","app_key":"lGhFIPeD3HsO9xEp"}
            }
        """.trimIndent()
        val request = Request.Builder()
            .url(TENCENT_URL)
            .post(bodyJson.toRequestBody(JSON_MEDIA_TYPE))
            .header("accept", "application/json")
            .header("content-type", "application/json")
            .header("origin", "https://film.qq.com")
            .header("referer", "https://film.qq.com/")
            .header("user-agent", DEFAULT_USER_AGENT)
            .build()
        return execute(request, ::parseTencentBody)
    }

    /**
     * 请求爱奇艺联想词。
     */
    private fun fetchIqiyiSuggestions(query: String): List<String> {
        val url = "https://mesh.if.iqiyi.com/portal/lw/search/searchKeyWord" +
            "?key=$query" +
            "&version=17.054.25384" +
            "&deviceId=6ab07a4f0966c704610f0448494b67cb" +
            "&appMode=" +
            "&os=" +
            "&pcv=17.054.25384"
        val request = Request.Builder()
            .url(url)
            .get()
            .header("accept", "*/*")
            .header("origin", "https://www.iqiyi.com")
            .header("referer", "https://www.iqiyi.com/")
            .header("user-agent", DEFAULT_USER_AGENT)
            .build()
        return execute(request, ::parseIqiyiBody)
    }

    /**
     * 请求芒果 TV 联想词。
     */
    private fun fetchMgtvSuggestions(query: String): List<String> {
        val url = "https://mobileso.bz.mgtv.com/pc/suggest/v1" +
            "?allowedRC=1" +
            "&src=mgtv" +
            "&did=5bbe5b75-33e3-471c-87df-de12d62291f2" +
            "&pc=1" +
            "&q=$query" +
            "&_support=10000000"
        val request = Request.Builder()
            .url(url)
            .get()
            .header("accept", "application/json, text/plain, */*")
            .header("origin", "https://www.mgtv.com")
            .header("referer", "https://www.mgtv.com/")
            .header("user-agent", DEFAULT_USER_AGENT)
            .build()
        return execute(request, ::parseMgtvBody)
    }

    private fun execute(request: Request, parser: (String) -> List<String>): List<String> {
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                return emptyList()
            }
            val body = response.body?.string().orEmpty()
            if (body.isBlank()) {
                return emptyList()
            }
            return runCatching { parser(body) }.getOrDefault(emptyList())
        }
    }

    companion object {
        private val LOGGER = Logger.getLogger(ExternalSearchSuggestionService::class.java.name)
        private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
        private const val TENCENT_URL =
            "https://actapi.video.qq.com/" +
                "trpc.videosearch.smartboxServer.SugRecallHttp/GetSugHttp" +
                "?vplatform=2"
        private const val DEFAULT_USER_AGENT =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/148.0.0.0 Safari/537.36"
        private const val REQUEST_TIMEOUT_SECONDS = 5L

        /**
         * 是否为纯字母数字首字母查询。
         *
         * @param query 已 trim 的查询串。
         * @return true 表示可走外部联想。
         */
        fun isInitialsQuery(query: String): Boolean {
            return query.isNotEmpty() && query.matches(Regex("^[A-Z0-9]+$"))
        }

        /**
         * 创建默认直连短超时客户端。
         */
        fun createDefaultClient(): OkHttpClient {
            return OkHttpClient.Builder()
                .proxy(Proxy.NO_PROXY)
                .connectTimeout(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .readTimeout(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .callTimeout(REQUEST_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                .build()
        }

        /**
         * 解析腾讯视频联想 JSON。
         *
         * @param body 响应体。
         * @return 片名列表。
         */
        fun parseTencentBody(body: String): List<String> {
            val root = JsonParser.parseString(body).asJsonObject
            val itemList = root
                .getAsJsonObject("data")
                ?.getAsJsonObject("result_list")
                ?.getAsJsonArray("item_list")
                ?: return emptyList()
            val suggestions = ArrayList<String>()
            for (element in itemList) {
                if (!element.isJsonObject) continue
                val lines = element.asJsonObject
                    .getAsJsonObject("view")
                    ?.getAsJsonArray("lines")
                    ?: continue
                if (lines.size() == 0) continue
                val first = lines[0]
                if (!first.isJsonObject) continue
                val text = first.asJsonObject.get("text")?.asString.orEmpty()
                val clean = text.replace(Regex("</?em>"), "").trim()
                if (clean.isNotEmpty()) {
                    suggestions += clean
                }
            }
            return suggestions
        }

        /**
         * 解析爱奇艺联想 JSON。
         *
         * @param body 响应体。
         * @return 片名列表。
         */
        fun parseIqiyiBody(body: String): List<String> {
            val root = JsonParser.parseString(body).asJsonObject
            val items = root
                .getAsJsonObject("data")
                ?.getAsJsonArray("keyWordData")
                ?: return emptyList()
            return items.mapNotNull { element ->
                if (!element.isJsonObject) return@mapNotNull null
                element.asJsonObject.get("name")?.asString?.trim()?.takeIf { it.isNotEmpty() }
            }
        }

        /**
         * 解析芒果 TV 联想 JSON。
         *
         * @param body 响应体。
         * @return 片名列表。
         */
        fun parseMgtvBody(body: String): List<String> {
            val root = JsonParser.parseString(body).asJsonObject
            val items = root
                .getAsJsonObject("data")
                ?.getAsJsonArray("suggest")
                ?: return emptyList()
            return items.mapNotNull { element ->
                if (!element.isJsonObject) return@mapNotNull null
                element.asJsonObject.get("title")?.asString?.trim()?.takeIf { it.isNotEmpty() }
            }
        }

        /**
         * 对聚合结果做有序去重。
         *
         * @param suggestions 原始列表。
         * @return 去重后的列表。
         */
        fun dedupeSuggestions(suggestions: List<String>): List<String> {
            val ordered = ArrayList<String>()
            val seen = LinkedHashSet<String>()
            for (suggestion in suggestions) {
                val normalized = suggestion.replace(Regex("\\s+"), " ").trim()
                if (normalized.isEmpty() || !seen.add(normalized)) {
                    continue
                }
                ordered += normalized
            }
            return ordered
        }
    }
}
