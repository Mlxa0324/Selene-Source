package org.moontechlab.selene.tv.core.design.layout

/**
 * TV 页面统计信息模型。
 *
 * @property label 统计项左侧标签。
 * @property value 统计项右侧值。
 */
data class TvPageStatChipData(
    val label: String,
    val value: String,
)

/**
 * TV 海报卡片模型。
 *
 * @property id 海报唯一标识。
 * @property title 海报主标题。
 * @property subtitle 海报副标题。
 * @property posterUrl 海报地址，用于生成占位背景纹理。
 */
data class TvPosterItem(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val posterUrl: String = "",
)
