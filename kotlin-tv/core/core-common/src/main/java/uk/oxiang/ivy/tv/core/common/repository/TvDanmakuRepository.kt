package uk.oxiang.ivy.tv.core.common.repository

import uk.oxiang.ivy.tv.core.common.model.TvDanmakuAnimePayload
import uk.oxiang.ivy.tv.core.common.model.TvDanmakuCommentPayload
import uk.oxiang.ivy.tv.core.common.model.TvDanmakuEpisodePayload
import uk.oxiang.ivy.tv.core.common.model.TvDanmakuLoadPayload
import uk.oxiang.ivy.tv.core.common.model.TvDanmakuSearchPayload
import uk.oxiang.ivy.tv.core.common.network.SeleneDanmakuApi
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuCommentResponse
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuSearchAnimeResponse
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuSearchEpisodeResponse
import uk.oxiang.ivy.tv.core.common.network.model.TvDanmakuSearchResponse

/**
 * TV 弹幕数据仓库。
 *
 * @property api 弹幕服务接口。
 */
class TvDanmakuRepository(
    private val api: SeleneDanmakuApi,
) {
    /** 搜索结果缓存，复刻 Flutter TV 的短期搜索缓存习惯。 */
    private val searchCache = mutableMapOf<String, CachedDanmakuSearch>()

    /**
     * 搜索弹幕剧集候选。
     *
     * @param query 原始搜索词。
     * @return 弹幕搜索业务结果，空搜索词返回空。
     */
    suspend fun searchEpisodes(query: String): TvDanmakuSearchPayload? {
        val cleanQuery = query.trim()
        if (cleanQuery.isEmpty()) {
            return null
        }
        val cached = searchCache[cleanQuery]
        val nowMs = System.currentTimeMillis()
        if (cached != null && nowMs - cached.createdAtMs < SEARCH_CACHE_TTL_MS) {
            return cached.payload
        }

        val payload = api.searchEpisodes(cleanQuery).toPayload()
        if (payload.success) {
            // 只缓存成功搜索，避免短暂服务错误长期卡住用户重试。
            searchCache[cleanQuery] = CachedDanmakuSearch(
                payload = payload,
                createdAtMs = nowMs,
            )
        }
        return payload
    }

    /**
     * 按弹幕剧集 ID 加载评论列表。
     *
     * @param episodeId 弹幕剧集 ID。
     * @return 已排序的弹幕加载结果。
     */
    suspend fun loadDanmakuByEpisodeId(episodeId: Int): TvDanmakuLoadPayload {
        val comments = api.getComments(
            episodeId = episodeId,
            format = DANMAKU_COMMENT_FORMAT,
        ).comments.orEmpty()
            .map { comment -> comment.toPayload() }
            .sortedBy { comment -> comment.timeSeconds }
        return TvDanmakuLoadPayload(
            episodeId = episodeId,
            comments = comments,
        )
    }

    /**
     * 清理搜索缓存。
     */
    fun clearSearchCache() {
        searchCache.clear()
    }

    private companion object {
        /** 搜索缓存有效期，单位毫秒。 */
        const val SEARCH_CACHE_TTL_MS = 3_600_000L

        /** 弹幕评论接口使用的返回格式。 */
        const val DANMAKU_COMMENT_FORMAT = "json"
    }
}

/**
 * 弹幕搜索缓存条目。
 *
 * @property payload 搜索业务结果。
 * @property createdAtMs 缓存创建时间。
 */
private data class CachedDanmakuSearch(
    val payload: TvDanmakuSearchPayload,
    val createdAtMs: Long,
)

/**
 * 转换弹幕搜索响应为业务模型。
 *
 * @return 弹幕搜索业务结果。
 */
private fun TvDanmakuSearchResponse.toPayload(): TvDanmakuSearchPayload {
    return TvDanmakuSearchPayload(
        success = success == true,
        errorMessage = errorMessage.orEmpty(),
        animes = animes.orEmpty().map { anime -> anime.toPayload() },
    )
}

/**
 * 转换弹幕动画候选响应为业务模型。
 *
 * @return 动画候选业务模型。
 */
private fun TvDanmakuSearchAnimeResponse.toPayload(): TvDanmakuAnimePayload {
    return TvDanmakuAnimePayload(
        animeId = animeId ?: 0,
        animeTitle = animeTitle.orEmpty(),
        type = type.orEmpty(),
        typeDescription = typeDescription.orEmpty(),
        year = year ?: 0,
        episodes = episodes.orEmpty().map { episode -> episode.toPayload() },
    )
}

/**
 * 转换弹幕剧集候选响应为业务模型。
 *
 * @return 剧集候选业务模型。
 */
private fun TvDanmakuSearchEpisodeResponse.toPayload(): TvDanmakuEpisodePayload {
    return TvDanmakuEpisodePayload(
        episodeId = episodeId ?: 0,
        episodeTitle = episodeTitle.orEmpty(),
    )
}

/**
 * 转换弹幕评论响应为业务模型。
 *
 * @return 弹幕评论业务模型。
 */
private fun TvDanmakuCommentResponse.toPayload(): TvDanmakuCommentPayload {
    return TvDanmakuCommentPayload(
        cid = cid ?: 0,
        p = p ?: "0,1,16777215",
        text = m.orEmpty(),
        timestamp = t ?: 0,
        timeSeconds = timeSeconds,
        type = type,
        color = color,
    )
}
