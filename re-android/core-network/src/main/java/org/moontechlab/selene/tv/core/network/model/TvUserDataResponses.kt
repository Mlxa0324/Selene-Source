package org.moontechlab.selene.tv.core.network.model

import com.google.gson.annotations.SerializedName

/**
 * TV 播放历史接口条目。
 *
 * @property title 影视标题。
 * @property sourceName 播放来源名称。
 * @property year 上映年份。
 * @property cover 封面地址。
 * @property index 当前集数，从 1 开始。
 * @property totalEpisodes 总集数。
 * @property playTime 当前播放秒数。
 * @property totalTime 总时长秒数。
 * @property saveTime 最近保存时间戳。
 * @property searchTitle 搜索回源标题。
 */
data class TvPlayRecordResponse(
    val title: String? = null,
    @SerializedName("source_name")
    val sourceName: String? = null,
    val year: String? = null,
    val cover: String? = null,
    val index: Int? = null,
    @SerializedName("total_episodes")
    val totalEpisodes: Int? = null,
    @SerializedName("play_time")
    val playTime: Int? = null,
    @SerializedName("total_time")
    val totalTime: Int? = null,
    @SerializedName("save_time")
    val saveTime: Long? = null,
    @SerializedName("search_title")
    val searchTitle: String? = null,
)

/**
 * TV 收藏夹接口条目。
 *
 * @property title 影视标题。
 * @property sourceName 播放来源名称。
 * @property year 上映年份。
 * @property cover 封面地址。
 * @property totalEpisodes 总集数。
 * @property saveTime 最近保存时间戳。
 * @property origin 收藏来源描述。
 */
data class TvFavoriteResponse(
    val title: String? = null,
    @SerializedName("source_name")
    val sourceName: String? = null,
    val year: String? = null,
    val cover: String? = null,
    @SerializedName("total_episodes")
    val totalEpisodes: Int? = null,
    @SerializedName("save_time")
    val saveTime: Long? = null,
    val origin: String? = null,
)
