package uk.oxiang.ivy.tv.core.common.network.model

import com.google.gson.annotations.SerializedName

/**
 * TV 搜索资源接口条目。
 *
 * @property key 资源标识。
 * @property name 资源展示名称。
 * @property api 下游搜索接口地址。
 * @property detail 下游详情接口地址。
 * @property from 资源来源类型。
 * @property disabled 是否禁用。
 */
data class TvSearchResourceResponse(
    val key: String? = null,
    val name: String? = null,
    val api: String? = null,
    val detail: String? = null,
    val from: String? = null,
    val disabled: Boolean? = null,
)

/**
 * TV 搜索接口响应。
 *
 * @property results 搜索结果列表。
 */
data class TvSearchResponse(
    val results: List<TvSearchResultResponse>? = null,
)

/**
 * TV 搜索结果接口条目。
 *
 * @property id 视频 ID。
 * @property title 视频标题。
 * @property url 详情地址。
 * @property poster 封面地址。
 * @property episodes 播放地址列表。
 * @property episodeTitles 剧集标题列表。
 * @property source 播放来源标识。
 * @property sourceName 播放来源名称。
 * @property videoClass 视频分类。
 * @property year 上映年份。
 * @property description 简介。
 * @property typeName 类型名称。
 * @property doubanId 豆瓣 ID。
 */
data class TvSearchResultResponse(
    val id: String? = null,
    val title: String? = null,
    val url: String? = null,
    val poster: String? = null,
    val episodes: List<String>? = null,
    @SerializedName("episodes_titles")
    val episodeTitles: List<String>? = null,
    val source: String? = null,
    @SerializedName("source_name")
    val sourceName: String? = null,
    @SerializedName("class")
    val videoClass: String? = null,
    val year: String? = null,
    @SerializedName("desc")
    val description: String? = null,
    @SerializedName("type_name")
    val typeName: String? = null,
    @SerializedName("douban_id")
    val doubanId: Int? = null,
)
