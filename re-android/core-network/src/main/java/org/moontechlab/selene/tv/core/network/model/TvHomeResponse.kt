package org.moontechlab.selene.tv.core.network.model

import com.google.gson.annotations.SerializedName

/**
 * TV 首页接口响应。
 *
 * @property sections 首页远端分区。
 */
data class TvHomeResponse(
    val sections: List<TvHomeSectionResponse>,
)

/**
 * TV 首页接口分区响应。
 *
 * @property key 分区标识。
 * @property title 分区标题。
 * @property videos 分区视频列表。
 */
data class TvHomeSectionResponse(
    val key: String,
    val title: String,
    val videos: List<TvVideoCardResponse>,
)

/**
 * TV 视频卡片接口响应。
 *
 * @property id 视频 ID。
 * @property source 播放来源标识。
 * @property title 视频标题。
 * @property sourceName 播放来源名称。
 * @property year 上映年份。
 * @property posterUrl Kotlin TV 旧字段封面地址。
 * @property cover Flutter TV / 播放记录字段封面地址。
 * @property poster 搜索接口字段封面地址。
 * @property rate 评分文案。
 */
data class TvVideoCardResponse(
    val id: String? = null,
    val source: String? = null,
    val title: String? = null,
    @SerializedName("source_name")
    val sourceName: String? = null,
    val year: String? = null,
    val posterUrl: String? = null,
    val cover: String? = null,
    val poster: String? = null,
    val rate: String? = null,
) {
    /**
     * 解析首页卡片封面地址。
     *
     * @return 优先兼容 Flutter TV 的 cover，其次兼容搜索 poster 和旧 posterUrl。
     */
    fun resolvedPosterUrl(): String {
        // 后台可能复用 Flutter VideoInfo，也可能返回原生 TV 初版 posterUrl。
        return firstNotBlank(cover, poster, posterUrl)
    }

    /**
     * 获取首个非空字符串。
     *
     * @param values 候选字符串。
     * @return 首个非空值，没有时返回空串。
     */
    private fun firstNotBlank(vararg values: String?): String {
        return values.firstOrNull { value -> !value.isNullOrBlank() }.orEmpty()
    }
}
