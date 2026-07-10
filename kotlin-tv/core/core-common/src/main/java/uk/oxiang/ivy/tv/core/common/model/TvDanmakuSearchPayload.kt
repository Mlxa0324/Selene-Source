package uk.oxiang.ivy.tv.core.common.model

/**
 * TV 弹幕搜索业务结果。
 *
 * @property success 搜索是否成功。
 * @property errorMessage 搜索失败文案。
 * @property animes 动画候选列表。
 */
data class TvDanmakuSearchPayload(
    val success: Boolean,
    val errorMessage: String,
    val animes: List<TvDanmakuAnimePayload>,
)

/**
 * TV 弹幕动画候选。
 *
 * @property animeId 动画 ID。
 * @property animeTitle 动画标题。
 * @property type 类型编码。
 * @property typeDescription 类型描述。
 * @property year 年份。
 * @property episodes 剧集候选列表。
 */
data class TvDanmakuAnimePayload(
    val animeId: Int,
    val animeTitle: String,
    val type: String,
    val typeDescription: String,
    val year: Int,
    val episodes: List<TvDanmakuEpisodePayload>,
)

/**
 * TV 弹幕剧集候选。
 *
 * @property episodeId 弹幕剧集 ID。
 * @property episodeTitle 剧集标题。
 */
data class TvDanmakuEpisodePayload(
    val episodeId: Int,
    val episodeTitle: String,
)

/**
 * TV 弹幕加载业务结果。
 *
 * @property episodeId 命中的弹幕剧集 ID。
 * @property comments 已按时间排序的弹幕评论列表。
 */
data class TvDanmakuLoadPayload(
    val episodeId: Int,
    val comments: List<TvDanmakuCommentPayload>,
)

/**
 * TV 弹幕评论业务模型。
 *
 * @property cid 评论 ID。
 * @property p 原始弹幕参数。
 * @property text 弹幕正文。
 * @property timestamp 服务端时间戳。
 * @property timeSeconds 弹幕出现时间，单位秒。
 * @property type 弹幕类型，1 为滚动，4 为底部，5 为顶部。
 * @property color 弹幕颜色。
 */
data class TvDanmakuCommentPayload(
    val cid: Int,
    val p: String,
    val text: String,
    val timestamp: Int,
    val timeSeconds: Double,
    val type: Int,
    val color: Int,
)
