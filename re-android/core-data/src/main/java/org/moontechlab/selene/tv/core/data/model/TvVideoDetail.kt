package org.moontechlab.selene.tv.core.data.model

/**
 * TV 影视详情模型。
 *
 * @property id 视频 ID。
 * @property doubanId 豆瓣条目 ID，用于资料页相关推荐抓取。
 * @property title 视频标题。
 * @property description 剧情简介。
 * @property posterUrl 封面地址。
 * @property year 上映年份。
 * @property typeName 类型名称（如“国产剧”）。
 * @property categories 分类标签列表（由 type_name + class 解析）。
 * @property remarks 更新/备注文案。
 * @property qualityTag 清晰度或更新标签。
 * @property rating 评分文案；无有效评分时为空。
 * @property sourceName 当前来源名称。
 * @property sources 可播放来源列表。
 */
data class TvVideoDetail(
    val id: String,
    val doubanId: String = "",
    val title: String,
    val description: String,
    val posterUrl: String = "",
    val year: String = "",
    val typeName: String = "",
    val categories: List<String> = emptyList(),
    val remarks: String = "",
    val qualityTag: String = "",
    val rating: String = "",
    val sourceName: String = "",
    val sources: List<TvVideoSource>,
)

/**
 * TV 播放来源模型。
 *
 * @property id 页面内唯一线路 ID，格式为 `source::videoId`。
 * @property source 后台播放来源标识。
 * @property videoId 后台视频 ID。
 * @property name 来源名称。
 * @property episodes 剧集列表。
 */
data class TvVideoSource(
    val id: String,
    val source: String = id,
    val videoId: String = "",
    val name: String,
    val episodes: List<TvEpisode>,
)

/**
 * TV 剧集模型。
 *
 * @property id 剧集 ID。
 * @property title 剧集标题。
 * @property url 播放地址。
 */
data class TvEpisode(
    val id: String,
    val title: String,
    val url: String,
)
