package uk.oxiang.ivy.tv.core.common.network.model

/**
 * 弹幕搜索接口响应。
 *
 * @property errorCode 弹幕服务错误码。
 * @property success 搜索是否成功。
 * @property errorMessage 搜索失败文案。
 * @property animes 动画候选列表。
 */
data class TvDanmakuSearchResponse(
    val errorCode: Int? = null,
    val success: Boolean? = null,
    val errorMessage: String? = null,
    val animes: List<TvDanmakuSearchAnimeResponse>? = null,
)

/**
 * 弹幕搜索动画候选响应。
 *
 * @property animeId 动画 ID。
 * @property animeTitle 动画标题。
 * @property type 类型编码。
 * @property typeDescription 类型描述。
 * @property year 年份。
 * @property episodes 剧集候选列表。
 */
data class TvDanmakuSearchAnimeResponse(
    val animeId: Int? = null,
    val animeTitle: String? = null,
    val type: String? = null,
    val typeDescription: String? = null,
    val year: Int? = null,
    val episodes: List<TvDanmakuSearchEpisodeResponse>? = null,
)

/**
 * 弹幕搜索剧集候选响应。
 *
 * @property episodeId 弹幕剧集 ID。
 * @property episodeTitle 剧集标题。
 */
data class TvDanmakuSearchEpisodeResponse(
    val episodeId: Int? = null,
    val episodeTitle: String? = null,
)

/**
 * 弹幕评论列表接口响应。
 *
 * @property count 服务端返回的评论数量。
 * @property comments 评论列表。
 */
data class TvDanmakuCommentListResponse(
    val count: Int? = null,
    val comments: List<TvDanmakuCommentResponse>? = null,
)

/**
 * 弹幕单条评论响应。
 *
 * @property cid 评论 ID。
 * @property p 弹幕参数，格式为 `time,type,color,...`。
 * @property m 弹幕正文。
 * @property t 服务端时间戳。
 */
data class TvDanmakuCommentResponse(
    val cid: Int? = null,
    val p: String? = null,
    val m: String? = null,
    val t: Int? = null,
) {
    /** 弹幕出现时间，单位秒。 */
    val timeSeconds: Double
        get() = parsedPPart(index = 0)?.toDoubleOrNull() ?: 0.0

    /** 弹幕类型，1 为滚动，4 为底部，5 为顶部。 */
    val type: Int
        get() = parsedPPart(index = 1)?.toIntOrNull() ?: 1

    /** 弹幕颜色，默认白色。 */
    val color: Int
        get() = parsedPPart(index = 2)?.toIntOrNull() ?: 16_777_215

    /**
     * 读取 `p` 字段指定位置的参数。
     *
     * @param index 参数下标。
     * @return 已裁剪空白的参数，越界时返回空。
     */
    private fun parsedPPart(index: Int): String? {
        return p
            ?.split(",")
            ?.getOrNull(index)
            ?.trim()
            ?.takeIf { value -> value.isNotEmpty() }
    }
}
