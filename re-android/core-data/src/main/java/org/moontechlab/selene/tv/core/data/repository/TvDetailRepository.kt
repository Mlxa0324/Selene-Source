package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.TvSearchSourceResultEvent
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * TV 详情仓库。
 *
 * @property api TV 服务端接口。
 * @property searchStreamClient TV 流式搜索客户端。
 */
class TvDetailRepository(
    private val api: SeleneTvApi,
    private val searchStreamClient: SeleneTvSearchStreamClient? = null,
) {
    /**
     * 判断入口身份是否可以直接请求详情接口。
     *
     * @param source 播放来源标识。
     * @param id 视频 ID。
     * @return 具备真实播放来源和视频 ID 时返回 true。
     */
    fun hasPlayableIdentity(
        source: String,
        id: String,
    ): Boolean {
        val normalizedSource = source.trim()
        val sourceType = normalizedSource.lowercase()
        val normalizedId = id.trim()
        if (normalizedSource.isBlank() || normalizedId.isBlank()) {
            // 空来源或空 ID 无法组成 `/api/detail` 的有效请求参数。
            return false
        }
        if (sourceType == UNPLAYABLE_SOURCE_DOUBAN || sourceType == UNPLAYABLE_SOURCE_BANGUMI) {
            // Flutter TV 将 douban / bangumi 视为资料来源，不直接请求播放详情。
            return false
        }
        return true
    }

    /**
     * 读取影视详情。
     *
     * @param source 播放来源标识。
     * @param id 影视 ID。
     * @return 影视详情；缺少来源或 ID 时返回 null。
     */
    suspend fun loadDetail(
        source: String,
        id: String,
    ): TvVideoDetail? {
        val normalizedSource = source.trim()
        val normalizedId = id.trim()
        if (!hasPlayableIdentity(normalizedSource, normalizedId)) {
            // `/api/detail` 必须同时具备可播放 source 和 id，避免发出无意义请求。
            return null
        }
        return api.getDetail(
            source = normalizedSource,
            id = normalizedId,
        ).toDetailModel(
            fallbackSource = normalizedSource,
            fallbackId = normalizedId,
        )
    }

    /**
     * 读取入口精确播放源。
     *
     * @param source 播放来源标识。
     * @param id 视频 ID。
     * @return 精确详情中的播放源；无可播放身份或接口无剧集时返回空列表。
     */
    suspend fun loadExactSources(
        source: String,
        id: String,
    ): List<TvVideoSource> {
        return loadDetail(source = source, id = id)
            ?.sources
            .orEmpty()
            .filter { videoSource -> videoSource.episodes.isNotEmpty() }
    }

    /**
     * 按标题搜索并构建详情模型。
     *
     * 用于首页、分类页或豆瓣入口无法通过 `source + id` 精确取详情时，
     * 对齐 Flutter TV 的标题补源逻辑。
     *
     * @param title 入口标题或搜索标题。
     * @param fallbackId 入口视频 ID 兜底。
     * @param year 入口年份，用于过滤同名影片。
     * @param posterUrl 入口封面兜底。
     * @return 搜索命中的详情模型；没有可播源时返回 null。
     */
    suspend fun loadDetailBySearchTitle(
        title: String,
        fallbackId: String,
        year: String = "",
        posterUrl: String = "",
    ): TvVideoDetail? {
        val query = title.trim()
        if (query.isBlank()) {
            // Flutter TV 在空标题时不触发补源搜索。
            return null
        }
        val matchedResults = api.search(query)
            .results
            .orEmpty()
            .filter { result -> result.matchesTitleAndYear(title = query, year = year) }
        val sources = matchedResults.toDistinctPlayableSources()
        if (sources.isEmpty()) {
            // 搜索完成但没有可播源时交给 UI 展示正式空态。
            return null
        }
        val primarySource = sources.maxByOrNull { source -> source.episodes.size } ?: sources.first()
        val primaryResult = matchedResults.firstOrNull { result ->
            result.source.orEmpty() == primarySource.source && result.id.orEmpty() == primarySource.videoId
        } ?: matchedResults.first()
        return TvVideoDetail(
            id = primarySource.videoId.ifBlank { fallbackId.trim() },
            doubanId = primaryResult.resolvedDoubanId().orEmpty(),
            title = primaryResult.title.orEmpty().trim().ifBlank { query },
            description = primaryResult.description.orEmpty(),
            posterUrl = primaryResult.poster.orEmpty().ifBlank { posterUrl },
            year = primaryResult.year.orEmpty(),
            sourceName = primarySource.name,
            sources = sources,
        )
    }

    /**
     * 按详情标题后台补充更多播放源（对齐 Flutter SSE 搜索逻辑）。
     *
     * Flutter 通过 SSE 流式返回增量结果；Kotlin 用同步 search 批量获取，
     * 但筛选、去重、集数优先逻辑对齐。
     *
     * @param detail 首屏详情。
     * @return 与当前影片同标题和年份的播放源列表。
     */
    suspend fun loadMoreSources(detail: TvVideoDetail): List<TvVideoSource> {
        return loadMoreSourcesByEntry(
            title = detail.title,
            searchTitle = detail.searchTitle(),
            year = detail.year,
        )
    }

    /**
     * 按入口信息后台补充播放源。
     *
     * @param title 展示标题。
     * @param searchTitle 搜索标题，空时回退 title。
     * @param year 年份过滤。
     * @param onIncremental SSE 增量结果回调。
     * @return 匹配入口影片的播放源。
     */
    suspend fun loadMoreSourcesByEntry(
        title: String,
        searchTitle: String = "",
        year: String = "",
        onIncremental: ((List<TvVideoSource>) -> Unit)? = null,
    ): List<TvVideoSource> {
        val query = searchTitle.trim().ifBlank { title.trim() }
        if (query.isBlank()) return emptyList()
        val streamClient = searchStreamClient
        if (streamClient != null && onIncremental != null) {
            val streamedSources = linkedMapOf<String, TvVideoSource>()
            val streamedResult = runCatching {
                streamClient.search(query) { event ->
                    if (event is TvSearchSourceResultEvent) {
                        val incrementalSources = event.results
                            .filter { result ->
                                result.matchesTitleAndYear(
                                    title = title.ifBlank { query },
                                    year = year,
                                )
                            }
                            .toDistinctPlayableSources()
                        if (incrementalSources.isEmpty()) {
                            return@search
                        }
                        incrementalSources.forEach { source ->
                            val key = source.matchKey()
                            val existing = streamedSources[key]
                            if (existing == null || source.episodes.size > existing.episodes.size) {
                                // 流式搜索可能对同一 source+id 后续补回更多剧集，最终仍保留更完整的一条。
                                streamedSources[key] = source
                            }
                        }
                        onIncremental(incrementalSources)
                    }
                }
            }
            if (streamedResult.isSuccess || streamedSources.isNotEmpty()) {
                return streamedSources.values.toList()
            }
        }
        return api.search(query)
            .results.orEmpty()
            .filter { result -> result.matchesTitleAndYear(title = title.ifBlank { query }, year = year) }
            .toDistinctPlayableSources()
    }

    /**
     * 按标题搜索播放源（对齐 Flutter 精确+标题双路搜索）。
     *
     * 用于当 searchTitle（如影片原名）与 title 不同时的二次搜索。
     */
    suspend fun searchByTitle(title: String): List<TvVideoSource> {
        val query = title.trim()
        if (query.isBlank()) return emptyList()
        return api.search(query)
            .results.orEmpty()
            .toDistinctPlayableSources()
    }

    /**
     * 解析详情页对应的豆瓣条目 ID。
     *
     * 对齐 Flutter 手机端逻辑：
     * 1. 优先使用详情接口已返回的 `doubanId`；
     * 2. 豆瓣资料卡入口直接复用入口视频 ID；
     * 3. 仍缺失时，再按标题搜索并取命中结果里出现次数最多的 `doubanId`。
     *
     * @param detail 当前详情模型。
     * @param entrySource 详情入口来源。
     * @param entryVideoId 详情入口视频 ID。
     * @param title 详情标题。
     * @param searchTitle 标题补源搜索词。
     * @param year 年份过滤条件。
     * @return 真实豆瓣条目 ID；无法还原时返回空字符串。
     */
    suspend fun resolveDoubanId(
        detail: TvVideoDetail?,
        entrySource: String,
        entryVideoId: String,
        title: String,
        searchTitle: String = "",
        year: String = "",
    ): String {
        detail?.doubanId
            ?.trim()
            ?.takeIf { doubanId -> doubanId.isNotBlank() }
            ?.let { return it }

        if (entrySource.trim().lowercase() == UNPLAYABLE_SOURCE_DOUBAN) {
            // 豆瓣资料卡入口本身就以豆瓣 subject id 作为 videoId。
            return entryVideoId.trim()
        }

        val resolvedTitle = title.trim().ifBlank { detail?.title.orEmpty().trim() }
        val resolvedSearchTitle = searchTitle.trim().ifBlank { resolvedTitle }
        if (resolvedSearchTitle.isBlank()) {
            return ""
        }
        val resolvedYear = year.trim().ifBlank { detail?.year.orEmpty().trim() }
        val matchedResults = api.search(resolvedSearchTitle)
            .results
            .orEmpty()
            .filter { result ->
                result.matchesTitleAndYear(
                    title = resolvedTitle.ifBlank { resolvedSearchTitle },
                    year = resolvedYear,
                )
            }

        val doubanIdCounts = linkedMapOf<String, Int>()
        for (result in matchedResults) {
            val doubanId = result.resolvedDoubanId() ?: continue
            // 保持第一次出现顺序，确保同票时结果稳定。
            doubanIdCounts[doubanId] = (doubanIdCounts[doubanId] ?: 0) + 1
        }
        return doubanIdCounts.entries
            .maxByOrNull { (_, count) -> count }
            ?.key
            .orEmpty()
    }

    /**
     * 影片用于搜索的标题（对齐 Flutter searchTitle 逻辑）。
     */
    fun TvVideoDetail.searchTitle(): String {
        // Flutter 会从多个字段提取最合适的搜索词
        return title.trim()
    }

    /**
     * 播放线路去重匹配 key。
     */
    private fun TvVideoSource.matchKey(): String {
        return "${source}::${videoId}"
    }

    /**
     * 搜索结果转换为去重后的可播放线路。
     *
     * @return 同一 `source + id` 只保留剧集数更多的播放线路。
     */
    private fun List<TvSearchResultResponse>.toDistinctPlayableSources(): List<TvVideoSource> {
        return map { result ->
            result.toVideoSource(
                fallbackSource = result.source.orEmpty(),
                fallbackId = result.id.orEmpty(),
            )
        }
            .filter { source -> source.episodes.isNotEmpty() }
            // 去重：同一 (source, id) 保留 episodes 更多的那个。
            .fold(linkedMapOf<String, TvVideoSource>()) { acc, source ->
                val key = source.matchKey()
                val existing = acc[key]
                if (existing == null || source.episodes.size > existing.episodes.size) {
                    // 搜索结果可能同源同 ID 分批返回，保留剧集更完整的一条。
                    acc[key] = source
                }
                acc
            }
            .values.toList()
    }

    /**
     * 将远端详情响应转换为详情页业务模型。
     *
     * @param fallbackSource 路由传入的来源兜底。
     * @param fallbackId 路由传入的视频 ID 兜底。
     * @return 详情页业务模型。
     */
    private fun TvSearchResultResponse.toDetailModel(
        fallbackSource: String,
        fallbackId: String,
    ): TvVideoDetail {
        val videoSource = toVideoSource(
            fallbackSource = fallbackSource,
            fallbackId = fallbackId,
        )
        return TvVideoDetail(
            id = videoSource.videoId,
            doubanId = resolvedDoubanId().orEmpty(),
            title = title.orEmpty(),
            description = description.orEmpty(),
            posterUrl = poster.orEmpty(),
            year = year.orEmpty(),
            sourceName = sourceName.orEmpty(),
            sources = listOf(videoSource),
        )
    }

    /**
     * 将远端搜索/详情条目转换为播放线路。
     *
     * @param fallbackSource 播放来源兜底。
     * @param fallbackId 视频 ID 兜底。
     * @return 播放线路模型。
     */
    private fun TvSearchResultResponse.toVideoSource(
        fallbackSource: String,
        fallbackId: String,
    ): TvVideoSource {
        val resolvedSource = source.orEmpty().ifBlank { fallbackSource }
        val resolvedId = id.orEmpty().ifBlank { fallbackId }
        val sourceIdentity = "$resolvedSource::$resolvedId"
        return TvVideoSource(
            id = sourceIdentity,
            source = resolvedSource,
            videoId = resolvedId,
            name = sourceName.orEmpty().ifBlank { resolvedSource },
            episodes = episodes.orEmpty().mapIndexedNotNull { index, url ->
                val normalizedUrl = url.trim()
                if (normalizedUrl.isBlank()) {
                    // 空播放地址不能继续透传到详情页，否则会把黑色真播放器容器误判成可播预览。
                    return@mapIndexedNotNull null
                }
                TvEpisode(
                    id = "$sourceIdentity-$index",
                    title = episodeTitleAt(index),
                    url = normalizedUrl,
                )
            },
        )
    }

    /**
     * 判断搜索结果是否属于当前详情影片。
     *
     * @param detail 当前详情。
     * @return 标题和年份匹配时返回 true。
     */
    private fun TvSearchResultResponse.matchesDetail(detail: TvVideoDetail): Boolean {
        return matchesTitleAndYear(title = detail.title, year = detail.year)
    }

    /**
     * 提取当前条目携带的豆瓣 ID。
     *
     * @return 合法豆瓣 ID；无值时返回 null。
     */
    private fun TvSearchResultResponse.resolvedDoubanId(): String? {
        return doubanId
            ?.takeIf { value -> value > 0 }
            ?.toString()
            ?.trim()
            ?.takeIf { value -> value.isNotBlank() }
    }

    /**
     * 判断搜索结果是否命中指定标题和年份。
     *
     * @param title 入口标题。
     * @param year 入口年份。
     * @return 标题一致且年份兼容时返回 true。
     */
    private fun TvSearchResultResponse.matchesTitleAndYear(
        title: String,
        year: String,
    ): Boolean {
        val resultTitle = this.title.orEmpty().normalizedTitle()
        val detailTitle = title.normalizedTitle()
        if (resultTitle.isBlank() || resultTitle != detailTitle) {
            return false
        }
        val detailYear = year.normalizedYear()
        val resultYear = this.year.orEmpty().normalizedYear()
        return detailYear.isBlank() || resultYear.isBlank() || detailYear == resultYear
    }

    /**
     * 归一化用于匹配的标题。
     *
     * @return 去除空白并转小写后的标题。
     */
    private fun String.normalizedTitle(): String {
        return replace(Regex("\\s+"), "").lowercase()
    }

    /**
     * 归一化用于匹配的年份。
     *
     * @return 缺失或未知年份返回空字符串。
     */
    private fun String.normalizedYear(): String {
        val normalized = trim().lowercase()
        return if (normalized.isBlank() || normalized == "unknown" || normalized == "未知") {
            ""
        } else {
            normalized
        }
    }

    /**
     * 读取指定下标的剧集标题。
     *
     * @param index 剧集下标。
     * @return 后台标题或默认第 N 集。
     */
    private fun TvSearchResultResponse.episodeTitleAt(index: Int): String {
        return episodeTitles
            ?.getOrNull(index)
            ?.takeIf { title -> title.isNotBlank() }
            ?: "第 ${index + 1} 集"
    }

    private companion object {
        /** 豆瓣资料来源，不可直接请求播放详情。 */
        const val UNPLAYABLE_SOURCE_DOUBAN = "douban"

        /** Bangumi 资料来源，不可直接请求播放详情。 */
        const val UNPLAYABLE_SOURCE_BANGUMI = "bangumi"
    }
}
