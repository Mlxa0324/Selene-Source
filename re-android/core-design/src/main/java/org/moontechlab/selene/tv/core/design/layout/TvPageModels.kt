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
 * @property posterUrl 海报地址，用于生成默认背景纹理。
 */
data class TvPosterItem(
    val id: String,
    val title: String,
    val subtitle: String = "",
    val posterUrl: String = "",
)

/**
 * 构建海报列表渲染 key。
 *
 * @param index 海报在当前列表中的位置。
 * @param item 海报卡片数据。
 * @return Compose Lazy 列表使用的唯一渲染 key。
 */
internal fun posterListItemKey(
    index: Int,
    item: TvPosterItem,
): String {
    // 后台可能在同一分区返回重复视频 ID，UI key 需要追加位置避免 Compose key 冲突。
    return "poster:${item.id}:$index"
}
