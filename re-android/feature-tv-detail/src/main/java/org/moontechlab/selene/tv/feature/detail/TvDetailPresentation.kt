package org.moontechlab.selene.tv.feature.detail

import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * TV 详情页线路展示项。
 *
 * @property sourceId 线路 ID。
 * @property label 线路名称。
 * @property trailingText 剧集数量文案。
 * @property episodeCount 剧集数量。
 * @property selected 是否当前线路。
 */
data class TvDetailSourceOption(
    val sourceId: String,
    val label: String,
    val trailingText: String,
    val episodeCount: Int,
    val selected: Boolean,
)

/**
 * TV 详情页选集展示项。
 *
 * @property episodeId 剧集 ID。
 * @property label 剧集标题。
 * @property episodeIndex 剧集下标。
 * @property selected 是否当前剧集。
 */
data class TvDetailEpisodeOption(
    val episodeId: String,
    val label: String,
    val episodeIndex: Int,
    val selected: Boolean,
)

/**
 * TV 详情页选集分组展示项。
 *
 * @property groupIndex 分组下标。
 * @property label 分组文案。
 * @property selected 是否当前分组。
 * @property episodes 当前分组剧集。
 */
data class TvDetailEpisodeGroupOption(
    val groupIndex: Int,
    val label: String,
    val selected: Boolean,
    val episodes: List<TvDetailEpisodeOption>,
)

/**
 * TV 详情页主要区块显隐状态。
 *
 * @property showSources 是否渲染线路区。
 * @property showEpisodes 是否渲染选集区。
 * @property showRecommends 是否渲染推荐区。
 * @property showBottomActions 是否渲染底部操作区。
 */
data class TvDetailLayoutSections(
    val showSources: Boolean,
    val showEpisodes: Boolean,
    val showRecommends: Boolean,
    val showBottomActions: Boolean,
)

/**
 * TV 详情页焦点区域。
 */
enum class TvDetailFocusArea {
    /** 顶部搜索入口。 */
    Search,

    /** 预览播放器。 */
    Player,

    /** 全屏按钮。 */
    Fullscreen,

    /** 收藏按钮。 */
    Favorite,

    /** 播放线路列表。 */
    Source,

    /** 选集列表。 */
    Episode,

    /** 选集分组列表。 */
    EpisodeGroup,

    /** 推荐列表。 */
    Recommend,

    /** 底部操作。 */
    BottomAction,
}

/**
 * TV 详情页方向键。
 */
enum class TvDetailFocusDirection {
    /** 左键。 */
    Left,

    /** 右键。 */
    Right,

    /** 上键。 */
    Up,

    /** 下键。 */
    Down,
}

/**
 * TV 详情页焦点位置。
 *
 * @property area 焦点区域。
 * @property index 区域内下标。
 */
data class TvDetailFocusPosition(
    val area: TvDetailFocusArea,
    val index: Int? = null,
) {
    companion object {
        /**
         * 构造普通区域焦点位置。
         *
         * @param area 焦点区域。
         * @return 焦点位置。
         */
        fun area(area: TvDetailFocusArea): TvDetailFocusPosition {
            return TvDetailFocusPosition(area = area)
        }

        /**
         * 构造线路焦点位置。
         *
         * @param index 线路下标。
         * @return 焦点位置。
         */
        fun source(index: Int): TvDetailFocusPosition {
            return TvDetailFocusPosition(area = TvDetailFocusArea.Source, index = index)
        }

        /**
         * 构造选集焦点位置。
         *
         * @param index 剧集下标。
         * @return 焦点位置。
         */
        fun episode(index: Int): TvDetailFocusPosition {
            return TvDetailFocusPosition(area = TvDetailFocusArea.Episode, index = index)
        }

        /**
         * 构造选集分组焦点位置。
         *
         * @param index 分组下标。
         * @return 焦点位置。
         */
        fun episodeGroup(index: Int): TvDetailFocusPosition {
            return TvDetailFocusPosition(area = TvDetailFocusArea.EpisodeGroup, index = index)
        }

        /**
         * 构造推荐焦点位置。
         *
         * @param index 推荐下标。
         * @return 焦点位置。
         */
        fun recommend(index: Int): TvDetailFocusPosition {
            return TvDetailFocusPosition(area = TvDetailFocusArea.Recommend, index = index)
        }
    }
}

/**
 * TV 详情页焦点移动结果。
 *
 * @property target 目标焦点位置。
 * @property boundary 是否命中边界。
 */
data class TvDetailFocusMove(
    val target: TvDetailFocusPosition,
    val boundary: Boolean = false,
)

/**
 * TV 详情页焦点图。
 *
 * @property sourceCount 线路数量。
 * @property currentSourceIndex 当前线路下标。
 * @property episodeCount 剧集数量。
 * @property currentEpisodeIndex 当前剧集下标。
 * @property selectedEpisodeGroupIndex 当前选集分组下标。
 * @property recommendCount 推荐数量。
 */
class TvDetailFocusGraph(
    private val sourceCount: Int,
    currentSourceIndex: Int = 0,
    private val episodeCount: Int,
    currentEpisodeIndex: Int = 0,
    selectedEpisodeGroupIndex: Int = 0,
    private val recommendCount: Int = 0,
) {
    /** 当前线路安全下标。 */
    private val currentSourceIndex = currentSourceIndex.safeIndex(sourceCount)

    /** 当前剧集安全下标。 */
    private val currentEpisodeIndex = currentEpisodeIndex.safeIndex(episodeCount)

    /** 当前分组安全下标。 */
    private val selectedEpisodeGroupIndex = selectedEpisodeGroupIndex.safeIndex(episodeGroupCount)

    /**
     * 解析方向键移动。
     *
     * @param from 当前焦点位置。
     * @param direction 方向键。
     * @return 焦点移动结果。
     */
    fun resolve(
        from: TvDetailFocusPosition,
        direction: TvDetailFocusDirection,
    ): TvDetailFocusMove {
        return when (from.area) {
            TvDetailFocusArea.Search -> resolveSearch(direction)
            TvDetailFocusArea.Player -> resolvePlayer(direction)
            TvDetailFocusArea.Fullscreen,
            TvDetailFocusArea.Favorite -> resolveHeroAction(direction, from)
            TvDetailFocusArea.Source -> resolveSource(from.index.orZero(), direction)
            TvDetailFocusArea.Episode -> resolveEpisode(from.index.orZero(), direction)
            TvDetailFocusArea.EpisodeGroup -> resolveEpisodeGroup(from.index.orZero(), direction)
            TvDetailFocusArea.Recommend -> resolveRecommend(from.index.orZero(), direction)
            TvDetailFocusArea.BottomAction -> resolveBottomAction(direction)
        }
    }

    /**
     * 解析顶部搜索区域移动。
     */
    private fun resolveSearch(direction: TvDetailFocusDirection): TvDetailFocusMove {
        return when (direction) {
            TvDetailFocusDirection.Down -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Player))
            else -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Search), boundary = true)
        }
    }

    /**
     * 解析播放器区域移动。
     */
    private fun resolvePlayer(direction: TvDetailFocusDirection): TvDetailFocusMove {
        return when (direction) {
            TvDetailFocusDirection.Down -> sourceOrFallback()
            TvDetailFocusDirection.Right -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Fullscreen))
            TvDetailFocusDirection.Up,
            TvDetailFocusDirection.Left -> TvDetailFocusMove(
                target = TvDetailFocusPosition.area(TvDetailFocusArea.Player),
                boundary = true,
            )
        }
    }

    /**
     * 解析 Hero 按钮区域移动。
     */
    private fun resolveHeroAction(
        direction: TvDetailFocusDirection,
        from: TvDetailFocusPosition,
    ): TvDetailFocusMove {
        return when (direction) {
            TvDetailFocusDirection.Down -> sourceOrFallback()
            TvDetailFocusDirection.Up -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Search))
            TvDetailFocusDirection.Left -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Fullscreen))
            TvDetailFocusDirection.Right -> TvDetailFocusMove(
                target = from,
                boundary = from.area == TvDetailFocusArea.Favorite,
            )
        }
    }

    /**
     * 解析线路列表移动。
     */
    private fun resolveSource(
        index: Int,
        direction: TvDetailFocusDirection,
    ): TvDetailFocusMove {
        val safeIndex = index.safeIndex(sourceCount)
        return when (direction) {
            TvDetailFocusDirection.Left -> listMove(
                current = safeIndex,
                count = sourceCount,
                next = safeIndex - 1,
                area = TvDetailFocusArea.Source,
            )
            TvDetailFocusDirection.Right -> listMove(
                current = safeIndex,
                count = sourceCount,
                next = safeIndex + 1,
                area = TvDetailFocusArea.Source,
            )
            TvDetailFocusDirection.Up -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Player))
            TvDetailFocusDirection.Down -> episodeOrLowerFallback(TvDetailFocusPosition.source(safeIndex))
        }
    }

    /**
     * 解析选集列表移动。
     */
    private fun resolveEpisode(
        index: Int,
        direction: TvDetailFocusDirection,
    ): TvDetailFocusMove {
        val safeIndex = index.safeIndex(episodeCount)
        return when (direction) {
            TvDetailFocusDirection.Left -> listMove(
                current = safeIndex,
                count = episodeCount,
                next = safeIndex - 1,
                area = TvDetailFocusArea.Episode,
            )
            TvDetailFocusDirection.Right -> listMove(
                current = safeIndex,
                count = episodeCount,
                next = safeIndex + 1,
                area = TvDetailFocusArea.Episode,
            )
            TvDetailFocusDirection.Up -> sourceOrFallback()
            TvDetailFocusDirection.Down -> episodeGroupOrRecommendOrBoundary(TvDetailFocusPosition.episode(safeIndex))
        }
    }

    /**
     * 解析选集分组移动。
     */
    private fun resolveEpisodeGroup(
        index: Int,
        direction: TvDetailFocusDirection,
    ): TvDetailFocusMove {
        val safeIndex = index.safeIndex(episodeGroupCount)
        return when (direction) {
            TvDetailFocusDirection.Left -> listMove(
                current = safeIndex,
                count = episodeGroupCount,
                next = safeIndex - 1,
                area = TvDetailFocusArea.EpisodeGroup,
            )
            TvDetailFocusDirection.Right -> listMove(
                current = safeIndex,
                count = episodeGroupCount,
                next = safeIndex + 1,
                area = TvDetailFocusArea.EpisodeGroup,
            )
            TvDetailFocusDirection.Up -> TvDetailFocusMove(TvDetailFocusPosition.episode(episodeIndexForGroup(safeIndex)))
            TvDetailFocusDirection.Down -> recommendOrBoundary(TvDetailFocusPosition.episodeGroup(safeIndex))
        }
    }

    /**
     * 解析推荐列表移动。
     */
    private fun resolveRecommend(
        index: Int,
        direction: TvDetailFocusDirection,
    ): TvDetailFocusMove {
        val safeIndex = index.safeIndex(recommendCount)
        return when (direction) {
            TvDetailFocusDirection.Left -> listMove(
                current = safeIndex,
                count = recommendCount,
                next = safeIndex - 1,
                area = TvDetailFocusArea.Recommend,
            )
            TvDetailFocusDirection.Right -> listMove(
                current = safeIndex,
                count = recommendCount,
                next = safeIndex + 1,
                area = TvDetailFocusArea.Recommend,
            )
            TvDetailFocusDirection.Up -> episodeGroupOrEpisodeFallback()
            TvDetailFocusDirection.Down -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.BottomAction))
        }
    }

    /**
     * 解析底部操作移动。
     */
    private fun resolveBottomAction(direction: TvDetailFocusDirection): TvDetailFocusMove {
        return when (direction) {
            TvDetailFocusDirection.Up -> {
                when {
                    recommendCount > 0 -> TvDetailFocusMove(TvDetailFocusPosition.recommend(0))
                    episodeGroupCount > 1 -> TvDetailFocusMove(TvDetailFocusPosition.episodeGroup(selectedEpisodeGroupIndex))
                    episodeCount > 0 -> TvDetailFocusMove(TvDetailFocusPosition.episode(currentEpisodeIndex))
                    sourceCount > 0 -> TvDetailFocusMove(TvDetailFocusPosition.source(currentSourceIndex))
                    else -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.Player))
                }
            }
            else -> TvDetailFocusMove(TvDetailFocusPosition.area(TvDetailFocusArea.BottomAction), boundary = true)
        }
    }

    /**
     * 通用横向列表移动。
     */
    private fun listMove(
        current: Int,
        count: Int,
        next: Int,
        area: TvDetailFocusArea,
    ): TvDetailFocusMove {
        if (count <= 0) {
            return TvDetailFocusMove(TvDetailFocusPosition.area(area), boundary = true)
        }
        if (next !in 0 until count) {
            return TvDetailFocusMove(TvDetailFocusPosition(area = area, index = current), boundary = true)
        }
        return TvDetailFocusMove(TvDetailFocusPosition(area = area, index = next))
    }

    /**
     * 优先返回当前线路，否则进入下一个可用区域。
     */
    private fun sourceOrFallback(): TvDetailFocusMove {
        return if (sourceCount > 0) {
            TvDetailFocusMove(TvDetailFocusPosition.source(currentSourceIndex))
        } else {
            episodeOrLowerFallback(TvDetailFocusPosition.area(TvDetailFocusArea.Player))
        }
    }

    /**
     * 优先返回当前选集，否则进入推荐或停留当前链路。
     */
    private fun episodeOrLowerFallback(from: TvDetailFocusPosition): TvDetailFocusMove {
        return if (episodeCount > 0) {
            TvDetailFocusMove(TvDetailFocusPosition.episode(currentEpisodeIndex))
        } else {
            recommendOrBoundary(from)
        }
    }

    /**
     * 推荐向上时优先回到分组，再回到选集。
     */
    private fun episodeGroupOrEpisodeFallback(): TvDetailFocusMove {
        return if (episodeGroupCount > 1) {
            TvDetailFocusMove(TvDetailFocusPosition.episodeGroup(selectedEpisodeGroupIndex))
        } else {
            episodeGroupOrRecommendOrBoundary(TvDetailFocusPosition.area(TvDetailFocusArea.Recommend))
        }
    }

    /**
     * 优先进入分组，其次推荐，最后停留当前链路。
     */
    private fun episodeGroupOrRecommendOrBoundary(from: TvDetailFocusPosition): TvDetailFocusMove {
        return if (episodeGroupCount > 1) {
            TvDetailFocusMove(TvDetailFocusPosition.episodeGroup(selectedEpisodeGroupIndex))
        } else {
            recommendOrBoundary(from)
        }
    }

    /**
     * 推荐存在时进入推荐，否则停留当前链路。
     */
    private fun recommendOrBoundary(from: TvDetailFocusPosition): TvDetailFocusMove {
        return if (recommendCount > 0) {
            TvDetailFocusMove(TvDetailFocusPosition.recommend(0))
        } else {
            TvDetailFocusMove(target = from, boundary = true)
        }
    }

    /**
     * 获取分组内优先聚焦剧集。
     */
    private fun episodeIndexForGroup(groupIndex: Int): Int {
        val groupStart = groupIndex * EPISODE_GROUP_SIZE
        return currentEpisodeIndex
            .takeIf { index -> index in groupStart until (groupStart + EPISODE_GROUP_SIZE) }
            ?: groupStart.coerceAtMost((episodeCount - 1).coerceAtLeast(0))
    }

    /**
     * 选集分组数量。
     */
    private val episodeGroupCount: Int
        get() = if (episodeCount <= 0) 0 else ((episodeCount - 1) / EPISODE_GROUP_SIZE) + 1
}

/**
 * 构建线路展示项。
 *
 * @param sources 播放线路。
 * @param currentSourceId 当前线路 ID。
 * @param pinCurrentSource 是否把当前线路固定在首位。
 * @return 线路展示项。
 */
fun buildDetailSourceOptions(
    sources: List<TvVideoSource>,
    currentSourceId: String,
    pinCurrentSource: Boolean,
): List<TvDetailSourceOption> {
    val indexedSources = sources.mapIndexed { index, source -> IndexedValue(index, source) }
    val sortedSources = indexedSources.sortedWith(
        compareByDescending<IndexedValue<TvVideoSource>> { entry -> entry.value.episodes.size }
            .thenBy { entry -> entry.index },
    )
    val orderedSources = if (!pinCurrentSource) {
        sortedSources
    } else {
        val current = indexedSources.firstOrNull { entry -> entry.value.id == currentSourceId }
        if (current == null) {
            sortedSources
        } else {
            listOf(current) + sortedSources.filterNot { entry -> entry.value.id == currentSourceId }
        }
    }
    return orderedSources.map { entry ->
        val source = entry.value
        TvDetailSourceOption(
            sourceId = source.id,
            label = source.name.ifBlank { source.id },
            trailingText = "（${source.episodes.size}）",
            episodeCount = source.episodes.size,
            selected = source.id == currentSourceId,
        )
    }
}

/**
 * 构建 20 集一组的选集展示项。
 *
 * @param episodes 剧集列表。
 * @param selectedEpisodeId 当前剧集 ID。
 * @param selectedGroupIndex 当前分组下标。
 * @return 选集分组展示项。
 */
fun buildDetailEpisodeGroups(
    episodes: List<TvEpisode>,
    selectedEpisodeId: String,
    selectedGroupIndex: Int,
): List<TvDetailEpisodeGroupOption> {
    if (episodes.isEmpty()) {
        return emptyList()
    }
    return episodes.chunked(EPISODE_GROUP_SIZE).mapIndexed { groupIndex, groupEpisodes ->
        val groupStart = groupIndex * EPISODE_GROUP_SIZE
        val startLabel = groupStart + 1
        val endLabel = groupStart + groupEpisodes.size
        TvDetailEpisodeGroupOption(
            groupIndex = groupIndex,
            label = "$startLabel-$endLabel",
            selected = groupIndex == selectedGroupIndex,
            episodes = groupEpisodes.mapIndexed { localIndex, episode ->
                val episodeIndex = groupStart + localIndex
                TvDetailEpisodeOption(
                    episodeId = episode.id,
                    label = episode.title.ifBlank { "${episodeIndex + 1}" },
                    episodeIndex = episodeIndex,
                    selected = episode.id == selectedEpisodeId,
                )
            },
        )
    }
}

/**
 * 判断是否需要展示选集分组切换条。
 *
 * @param groupCount 选集分组数量。
 * @return 多个分组时返回 true。
 */
fun shouldShowDetailEpisodeGroupChoices(groupCount: Int): Boolean {
    return groupCount > 1
}

/**
 * 构建详情页区块显隐状态。
 *
 * @param sources 播放线路。
 * @param episodes 剧集列表。
 * @param recommends 推荐卡片。
 * @return 区块显隐状态。
 */
fun buildDetailLayoutSections(
    sources: List<TvVideoSource>,
    episodes: List<TvEpisode>,
    recommends: List<TvVideoCard>,
): TvDetailLayoutSections {
    val hasRecommends = recommends.isNotEmpty()
    return TvDetailLayoutSections(
        showSources = sources.isNotEmpty(),
        showEpisodes = episodes.isNotEmpty(),
        showRecommends = hasRecommends,
        showBottomActions = true,
    )
}

/**
 * 空值转 0。
 */
private fun Int?.orZero(): Int = this ?: 0

/**
 * 把下标约束到列表范围。
 */
private fun Int.safeIndex(count: Int): Int {
    return if (count <= 0) 0 else coerceIn(0, count - 1)
}

/** 选集分组大小。 */
const val EPISODE_GROUP_SIZE = 20
