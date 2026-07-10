package uk.oxiang.ivy.tv.core.design.focus

import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.geometry.Rect

/**
 * TV 焦点记忆分组注册表。
 *
 * 对齐 Flutter `TvFocusable` 的静态焦点记忆分组能力
 * （`_focusMemoryGroups`/`_lastFocusedByGroup`/`clearLastFocusedForGroup`/
 * `resetGroupEntryToFirstFocusable`/`groupHasFocusedChild`/
 * `requestRememberedFocusForGroup`）。每个分组维护"最近一次真实获焦项"的
 * 记忆；跨组上下方向移动时优先回到目标分组的记忆项，其次回退到分组内第一个
 * 可聚焦项（排序规则"先上后下、同行从左到右"）。
 *
 * 调用方需要在获焦/失焦和位置变化时主动同步 [Entry] 状态
 * （见 [TvFocusableCard] 内部用法），这个注册表本身只做纯状态管理。
 */
object TvFocusMemoryRegistry {
    /** 上下焦点判定容差，过滤同一横向列表内的轻微布局偏差。 */
    private const val VERTICAL_DIRECTION_TOLERANCE = 28f

    /**
     * 焦点记忆条目。
     *
     * @property groupKey 所属分组标识。
     * @property focusRequester 绑定到真实焦点节点的请求器。
     * @property boundsProvider 读取当前全局位置的函数；未布局完成时返回 null。
     */
    class Entry(
        val groupKey: Any,
        val focusRequester: FocusRequester,
        val boundsProvider: () -> Rect?,
    ) {
        /** 当前是否真实持有焦点，由调用方在 `onFocusChanged` 中同步。 */
        var hasFocus: Boolean = false

        /** 当前是否仍允许请求焦点（例如已从组合树移除时应置为 false）。 */
        var canRequestFocus: Boolean = true
    }

    private val groups = mutableMapOf<Any, MutableSet<Entry>>()
    private val lastFocusedByGroup = mutableMapOf<Any, Entry>()

    /**
     * 注册一个分组内的焦点记忆条目。
     *
     * @param entry 待注册条目。
     */
    fun register(entry: Entry) {
        groups.getOrPut(entry.groupKey) { mutableSetOf() }.add(entry)
    }

    /**
     * 注销一个分组内的焦点记忆条目。
     *
     * @param entry 待注销条目。
     */
    fun unregister(entry: Entry) {
        val group = groups[entry.groupKey] ?: return
        group.remove(entry)
        if (group.isEmpty()) {
            groups.remove(entry.groupKey)
        }
        if (lastFocusedByGroup[entry.groupKey] == entry) {
            lastFocusedByGroup.remove(entry.groupKey)
        }
    }

    /**
     * 上报一次真实获焦事件，供后续记忆跳转消费。
     *
     * @param entry 真实获焦的条目。
     */
    fun onFocused(entry: Entry) {
        entry.hasFocus = true
        lastFocusedByGroup[entry.groupKey] = entry
    }

    /**
     * 上报一次真实失焦事件。
     *
     * @param entry 失焦的条目。
     */
    fun onUnfocused(entry: Entry) {
        entry.hasFocus = false
    }

    /**
     * 清理指定分组最近一次记住的焦点项。
     *
     * 某些横向列表在离开后需要下次从头进入，此时只清掉"最近一次焦点"即可，
     * 不影响列表内部节点继续保留同一个焦点记忆分组。
     *
     * @param groupKey 分组标识。
     */
    fun clearLastFocusedForGroup(groupKey: Any) {
        lastFocusedByGroup.remove(groupKey)
    }

    /**
     * 将指定分组的入口焦点重置到首个可聚焦项。
     *
     * 适用于首页横向分区这类"离开后下次从第一个重新进入"的场景。
     * 若当前分组里没有可用节点，则回退为清理最近一次焦点记录。
     *
     * @param groupKey 分组标识。
     */
    fun resetGroupEntryToFirstFocusable(groupKey: Any) {
        val firstEntry = firstFocusableEntryForGroup(groupKey)
        if (firstEntry == null) {
            lastFocusedByGroup.remove(groupKey)
            return
        }
        lastFocusedByGroup[groupKey] = firstEntry
    }

    /**
     * 判断指定分组当前是否仍有子项持有焦点。
     *
     * 用于列表在"最后一个焦点离开分组"时执行离组复位。
     *
     * @param groupKey 分组标识。
     * @return 分组内是否仍有条目处于真实获焦态。
     */
    fun groupHasFocusedChild(groupKey: Any): Boolean {
        val entries = groups[groupKey] ?: return false
        return entries.any { entry -> entry.hasFocus }
    }

    /**
     * 请求焦点回到指定分组最近一次获焦的控件。
     *
     * 多个横向列表上下切换时，优先回到该列表上次停留的位置；
     * 若该分组还没有焦点记忆，则回退到分组内第一个可聚焦项。
     *
     * @param groupKey 分组标识。
     * @return 是否成功发起了一次焦点请求。
     */
    fun requestRememberedFocusForGroup(groupKey: Any): Boolean {
        val rememberedEntry = lastFocusedByGroup[groupKey]
        if (rememberedEntry != null && isUsable(rememberedEntry)) {
            return runCatching { rememberedEntry.focusRequester.requestFocus() }.isSuccess
        }
        val firstEntry = firstFocusableEntryForGroup(groupKey) ?: return false
        return runCatching { firstEntry.focusRequester.requestFocus() }.isSuccess
    }

    /**
     * 查找目标方向上最近的其它分组焦点，用于跨组上下方向导航。
     *
     * 优先在"各分组最近一次记忆焦点"里找方向匹配项；找不到再回退到遍历
     * 全部分组的全部条目。
     *
     * @param currentGroupKey 当前分组标识。
     * @param currentRect 当前控件的全局位置。
     * @param direction 方向，`1` 表示向下，`-1` 表示向上。
     * @return 匹配到的目标条目；没有匹配时返回 null。
     */
    fun nearestRememberedGroupEntry(
        currentGroupKey: Any,
        currentRect: Rect,
        direction: Int,
    ): Entry? {
        val rememberedEntries = lastFocusedByGroup.entries
            .filter { entry -> entry.key != currentGroupKey }
            .map { entry -> entry.value }
        val rememberedTarget = nearestEntryInDirection(
            entries = rememberedEntries,
            currentRect = currentRect,
            direction = direction,
            currentGroupKey = currentGroupKey,
            excludeCurrentGroup = true,
        )
        if (rememberedTarget != null) {
            return rememberedTarget
        }

        val fallbackEntries = groups.entries
            .filter { entry -> entry.key != currentGroupKey }
            .flatMap { entry -> entry.value }
        return nearestEntryInDirection(
            entries = fallbackEntries,
            currentRect = currentRect,
            direction = direction,
            currentGroupKey = currentGroupKey,
            excludeCurrentGroup = true,
        )
    }

    /**
     * 查找同一分组内目标方向上是否还有可聚焦项。
     *
     * 用于判断当前列表在该方向是否已经到达边界（需要跨组跳转），
     * 还是应该交给默认焦点系统继续处理组内移动。
     *
     * @param groupKey 当前分组标识。
     * @param currentRect 当前控件全局位置。
     * @param direction 方向，`1` 表示向下，`-1` 表示向上。
     * @return 匹配到的组内目标条目；没有匹配时返回 null。
     */
    fun nearestEntryInSameGroup(
        groupKey: Any,
        currentRect: Rect,
        direction: Int,
    ): Entry? {
        val entries = groups[groupKey] ?: return null
        return nearestEntryInDirection(
            entries = entries,
            currentRect = currentRect,
            direction = direction,
            currentGroupKey = groupKey,
            excludeCurrentGroup = false,
        )
    }

    /**
     * 获取分组内第一个可聚焦的节点。
     *
     * 排序规则按大屏上的阅读顺序处理：先上后下，同一行再从左到右。
     *
     * @param groupKey 分组标识。
     * @return 分组内排序最靠前的可用条目；分组为空时返回 null。
     */
    private fun firstFocusableEntryForGroup(groupKey: Any): Entry? {
        val entries = groups[groupKey] ?: return null
        var bestEntry: Entry? = null
        var bestRect: Rect? = null
        for (entry in entries) {
            if (!isUsable(entry)) {
                continue
            }
            val rect = entry.boundsProvider() ?: continue
            val isBetterEntry = bestRect == null ||
                rect.top < bestRect.top - 1f ||
                (kotlin.math.abs(rect.top - bestRect.top) <= 1f && rect.left < bestRect.left)
            if (isBetterEntry) {
                bestEntry = entry
                bestRect = rect
            }
        }
        return bestEntry
    }

    /**
     * 查找指定方向上最近的可用焦点项。
     *
     * @param entries 候选条目集合。
     * @param currentRect 当前控件全局位置。
     * @param direction 方向，`1` 表示向下，`-1` 表示向上。
     * @param currentGroupKey 当前分组标识，用于排除同分组条目。
     * @param excludeCurrentGroup 是否排除与当前分组相同的条目。
     * @return 匹配到的最近条目；没有匹配时返回 null。
     */
    private fun nearestEntryInDirection(
        entries: Iterable<Entry>,
        currentRect: Rect,
        direction: Int,
        currentGroupKey: Any,
        excludeCurrentGroup: Boolean,
    ): Entry? {
        var bestEntry: Entry? = null
        var bestScore: Double? = null
        val currentCenterY = currentRect.center.y
        val currentCenterX = currentRect.center.x
        for (entry in entries) {
            if (!isUsable(entry)) {
                continue
            }
            if (excludeCurrentGroup && entry.groupKey == currentGroupKey) {
                continue
            }
            val rect = entry.boundsProvider() ?: continue
            val deltaY = rect.center.y - currentCenterY
            val isInDirection = if (direction > 0) {
                deltaY > VERTICAL_DIRECTION_TOLERANCE
            } else {
                deltaY < -VERTICAL_DIRECTION_TOLERANCE
            }
            if (!isInDirection) {
                continue
            }
            val deltaX = kotlin.math.abs(rect.center.x - currentCenterX)
            val score = kotlin.math.abs(deltaY) * 1000.0 + deltaX
            if (bestScore == null || score < bestScore) {
                bestScore = score
                bestEntry = entry
            }
        }
        return bestEntry
    }

    /**
     * 判断条目当前是否可作为焦点记忆目标。
     *
     * @param entry 待判断条目。
     * @return 条目是否仍允许请求焦点且已完成布局。
     */
    private fun isUsable(entry: Entry): Boolean {
        return entry.canRequestFocus && entry.boundsProvider() != null
    }
}
