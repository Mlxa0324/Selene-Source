package org.moontechlab.selene.tv.core.data.model

/**
 * TV 影视卡片模型。
 *
 * @property id 视频 ID。
 * @property source 播放来源标识。
 * @property title 视频标题。
 * @property sourceName 播放来源名称。
 * @property year 上映年份。
 * @property posterUrl 封面地址。
 * @property totalEpisodes 总集数。
 * @property episodeIndex 当前播放集数，从 1 开始。
 * @property playTime 当前播放秒数。
 * @property totalTime 总时长秒数。
 * @property saveTime 最近保存时间戳。
 * @property searchTitle 搜索回源标题。
 * @property origin 收藏来源描述。
 * @property doubanRate 豆瓣评分（无评分为空字符串）。
 */
data class TvVideoCard(
    val id: String,
    val source: String = "",
    val title: String,
    val sourceName: String = "",
    val year: String = "",
    val posterUrl: String,
    val totalEpisodes: Int = 0,
    val episodeIndex: Int = 0,
    val playTime: Int = 0,
    val totalTime: Int = 0,
    val saveTime: Long = 0L,
    val searchTitle: String = "",
    val origin: String = "",
    val doubanRate: String = "",
)
