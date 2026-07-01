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
 * @property source 播放来源标识。
 * @property title 海报主标题。
 * @property subtitle 海报副标题。
 * @property posterUrl 海报地址，用于生成默认背景纹理。
 * @property totalEpisodes 总集数，用于续播徽标。
 * @property episodeIndex 当前集数，从 1 开始。
 * @property progressFraction 播放进度比例，取值范围会在渲染前归一化到 0..1。
 */
data class TvPosterItem(
    val id: String,
    val source: String = "",
    val title: String,
    val subtitle: String = "",
    val posterUrl: String = "",
    val totalEpisodes: Int = 0,
    val episodeIndex: Int = 0,
    val progressFraction: Float = 0f,
)

/**
 * 生成携带播放来源的视频身份 key。
 *
 * @return `source::id`；缺少来源时回退视频 ID。
 */
fun TvPosterItem.toVideoIdentityKey(): String {
    return if (source.isBlank()) id else "$source::$id"
}

/**
 * 生成携带标题的详情页路由 key。
 *
 * 当播放来源为未知（如 "douban"）时，详情页可通过标题搜索兜底。
 *
 * @return `source::id::encodedTitle`；标题为空时回退 [toVideoIdentityKey]。
 */
fun TvPosterItem.toVideoDetailKey(): String {
    val identityKey = toVideoIdentityKey()
    return if (title.isNotBlank()) {
        "$identityKey::$title"
    } else {
        identityKey
    }
}

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

/**
 * 归一化海报播放进度。
 *
 * @param rawProgress 原始进度比例。
 * @return 可安全用于进度条宽度的 0..1 比例。
 */
internal fun normalizedPosterProgress(rawProgress: Float): Float {
    if (!rawProgress.isFinite()) {
        return 0f
    }
    return rawProgress.coerceIn(0f, 1f)
}
