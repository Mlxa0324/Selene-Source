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
 * TV 播放历史保存请求体。
 *
 * @property key 后端 `source+id` 记录键。
 * @property record 具体播放记录内容。
 */
data class TvPlayRecordUpsertRequest(
    val key: String,
    val record: TvPlayRecordUpsertBody,
)

/**
 * TV 播放历史保存内容。
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
data class TvPlayRecordUpsertBody(
    val title: String = "",
    @SerializedName("source_name")
    val sourceName: String = "",
    val year: String = "",
    val cover: String = "",
    val index: Int = 0,
    @SerializedName("total_episodes")
    val totalEpisodes: Int = 0,
    @SerializedName("play_time")
    val playTime: Int = 0,
    @SerializedName("total_time")
    val totalTime: Int = 0,
    @SerializedName("save_time")
    val saveTime: Long = 0L,
    @SerializedName("search_title")
    val searchTitle: String = "",
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

/**
 * TV 收藏保存请求体。
 *
 * 与 Flutter `/api/favorites` POST 对齐：`{ key, favorite }`。
 *
 * @property key 后端 `source+id` 记录键。
 * @property favorite 收藏内容。
 */
data class TvFavoriteUpsertRequest(
    val key: String,
    val favorite: TvFavoriteUpsertBody,
)

/**
 * TV 收藏保存内容。
 *
 * @property title 影视标题。
 * @property sourceName 播放来源名称。
 * @property year 上映年份。
 * @property cover 封面地址。
 * @property totalEpisodes 总集数。
 * @property saveTime 最近保存时间戳（毫秒）。
 * @property origin 收藏来源描述。
 */
data class TvFavoriteUpsertBody(
    val title: String = "",
    @SerializedName("source_name")
    val sourceName: String = "",
    val year: String = "",
    val cover: String = "",
    @SerializedName("total_episodes")
    val totalEpisodes: Int = 0,
    @SerializedName("save_time")
    val saveTime: Long = 0L,
    val origin: String = "",
)
