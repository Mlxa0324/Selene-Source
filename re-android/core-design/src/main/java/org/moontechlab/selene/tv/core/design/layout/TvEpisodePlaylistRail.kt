package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** 默认每组集数，对齐详情/播放器。 */
const val TV_EPISODE_PLAYLIST_GROUP_SIZE: Int = 20

/**
 * 选集横滑焦点落点策略。
 *
 * - [SoftEdgeFollow]：左右键默认。焦点随方向在行内走，只在贴边被裁时 scrollBy 露出。
 * - [PinLeading]：打开/确认分组。目标项钉在左侧安全区。
 * - [KeepSlot]：保留原视觉 X。
 */
enum class TvEpisodePlaylistPinMode {
    SoftEdgeFollow,
    PinLeading,
    KeepSlot,
}

/**
 * 选集轨单集数据。
 *
 * @property id 剧集 ID。
 * @property label 展示文案。
 */
data class TvEpisodePlaylistItem(
    val id: String,
    val label: String,
)

/**
 * 选集/分组 chip 渲染作用域（由 [TvEpisodePlaylistRail] 注入焦点与方向回调）。
 *
 * @property label 文案。
 * @property selected 是否选中（当前集 / 已确认分组）。
 * @property isFirst 是否首项。
 * @property isLast 是否末项。
 * @property modifier 已挂 focusRequester / onFocusChanged 等。
 * @property onClick 确认。
 * @property onArrowLeft 左键；null 表示边界。
 * @property onArrowRight 右键。
 * @property onArrowUp 上键。
 * @property onArrowDown 下键。
 */
data class TvEpisodePlaylistChipScope(
    val label: String,
    val selected: Boolean,
    val isFirst: Boolean,
    val isLast: Boolean,
    val modifier: Modifier,
    val onClick: () -> Unit,
    val onArrowLeft: (() -> Unit)?,
    val onArrowRight: (() -> Unit)?,
    val onArrowUp: (() -> Unit)?,
    val onArrowDown: (() -> Unit)?,
)

/**
 * 全剧集连续横轨 + 可选分组条（全屏播放器与详情页共用逻辑）。
 *
 * 关键契约：
 * - 选集 **不按组拆页**，左右始终在同一 LazyRow 上步进，避免焦点逃到其它纵向层；
 * - 左右 [TvEpisodePlaylistPinMode.SoftEdgeFollow]；
 * - 分组获焦不改选中，确认后下划线 + 选集钉到组首；
 * - 关闭系统 bringIntoView，滚动由本组件统一处理。
 *
 * @param episodes 全量选集。
 * @param currentEpisodeId 当前播放/选中集 ID。
 * @param contentStartPadding 左 contentPadding。
 * @param contentEndPadding 右 contentPadding。
 * @param episodeRowHeight 选集行高度（含放大溢出）。
 * @param groupRowHeight 分组行高度。
 * @param episodeSpacing 选集间距。
 * @param groupSpacing 分组间距。
 * @param groupSize 每组集数。
 * @param currentEpisodeFocusRequester 当前集优先挂载的焦点（详情/二级入口）。
 * @param entryFocusRequester 始终可挂载的列表入口：上下键进选集时先就近/滚到目标再落焦。
 * @param pinCurrentTicket 递增后把焦点钉到当前集（打开菜单/进入层）。
 * @param onEpisodeSelected 选集确认。
 * @param onArrowUpFromEpisode 选集上键（到线路等）。
 * @param onArrowDownFromEpisodeNoGroups 无分组时选集下键。
 * @param onArrowDownFromGroup 分组下键。
 * @param onSelectedGroupChanged 选中分组变化（供 ViewModel 同步）。
 * @param episodeChip 选集 chip UI。
 * @param groupChip 分组 chip UI。
 * @param modifier 外层修饰器。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TvEpisodePlaylistRail(
    episodes: List<TvEpisodePlaylistItem>,
    currentEpisodeId: String,
    contentStartPadding: Dp,
    contentEndPadding: Dp,
    episodeRowHeight: Dp,
    groupRowHeight: Dp = 48.dp,
    episodeSpacing: Dp = 8.dp,
    groupSpacing: Dp = 12.dp,
    groupSize: Int = TV_EPISODE_PLAYLIST_GROUP_SIZE,
    currentEpisodeFocusRequester: FocusRequester? = null,
    entryFocusRequester: FocusRequester? = null,
    pinCurrentTicket: Int = 0,
    onEpisodeSelected: (String) -> Unit,
    onArrowUpFromEpisode: (() -> Unit)? = null,
    onArrowDownFromEpisodeNoGroups: (() -> Unit)? = null,
    onArrowDownFromGroup: (() -> Unit)? = null,
    onSelectedGroupChanged: ((Int) -> Unit)? = null,
    episodeChip: @Composable (TvEpisodePlaylistChipScope) -> Unit,
    groupChip: @Composable (TvEpisodePlaylistChipScope) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (episodes.isEmpty()) {
        return
    }

    val safeGroupSize = groupSize.coerceAtLeast(1)
    val groupCount = ((episodes.size + safeGroupSize - 1) / safeGroupSize).coerceAtLeast(1)
    val showGroupChoices = groupCount > 1
    val currentAbsoluteIndex = remember(episodes, currentEpisodeId) {
        episodes.indexOfFirst { episode -> episode.id == currentEpisodeId }
            .takeIf { value -> value >= 0 } ?: 0
    }
    var selectedGroup by remember(currentAbsoluteIndex) {
        mutableIntStateOf(currentAbsoluteIndex / safeGroupSize)
    }
    val safeGroup = selectedGroup.coerceIn(0, (groupCount - 1).coerceAtLeast(0))

    LaunchedEffect(safeGroup) {
        onSelectedGroupChanged?.invoke(safeGroup)
    }

    val groupFocusRequesters = remember(groupCount) {
        List(groupCount) { FocusRequester() }
    }
    val episodeFocusRequesters = remember(episodes.size) {
        List(episodes.size.coerceAtLeast(0)) { FocusRequester() }
    }
    val episodeListState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
    val groupListState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
    val scrollScope = rememberCoroutineScope()
    var activeEpisodeFocusedIndex by remember {
        mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex)
    }
    var activeGroupFocusedIndex by remember {
        mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex)
    }
    var episodeFocusMoveJob by remember { mutableStateOf<Job?>(null) }

    val density = LocalDensity.current
    val leadingInsetPx = with(density) { contentStartPadding.roundToPx() }
    val trailingInsetPx = with(density) { contentEndPadding.roundToPx() }

    val noAutoBringIntoViewSpec = remember {
        object : BringIntoViewSpec {
            override fun calculateScrollDistance(
                offset: Float,
                size: Float,
                containerSize: Float,
            ): Float = 0f
        }
    }

    fun focusRequesterForAbsoluteIndex(index: Int): FocusRequester? {
        val episode = episodes.getOrNull(index) ?: return null
        return if (episode.id == currentEpisodeId && currentEpisodeFocusRequester != null) {
            currentEpisodeFocusRequester
        } else {
            episodeFocusRequesters.getOrNull(index)
        }
    }

    suspend fun ensureGroupChipVisibleNow(groupIndex: Int) {
        if (!showGroupChoices || groupCount <= 0) {
            return
        }
        val target = groupIndex.coerceIn(0, groupCount - 1)
        for (attempt in 0 until 6) {
            if (attempt > 0) {
                delay(16L)
            }
            val visible = groupListState.layoutInfo.visibleItemsInfo.any { info ->
                info.index == target
            }
            if (!visible) {
                runCatching { groupListState.scrollToItem(index = target) }
                withFrameNanos { }
            } else {
                break
            }
        }
        scrollChipIntoViewSuspend(
            listState = groupListState,
            index = target,
            itemCount = groupCount,
            leadingInsetPx = leadingInsetPx,
            trailingInsetPx = trailingInsetPx,
        )
    }

    fun ensureGroupChipVisible(groupIndex: Int) {
        scrollScope.launch { ensureGroupChipVisibleNow(groupIndex) }
    }

    fun moveGroupFocus(targetIndex: Int) {
        if (!showGroupChoices || groupCount <= 0) {
            return
        }
        val target = targetIndex.coerceIn(0, groupCount - 1)
        scrollScope.launch {
            var focused = false
            for (attempt in 0 until 10) {
                if (attempt > 0) {
                    delay(16L)
                }
                val visible = groupListState.layoutInfo.visibleItemsInfo.any { info ->
                    info.index == target
                }
                if (!visible) {
                    runCatching { groupListState.scrollToItem(index = target) }
                    withFrameNanos { }
                }
                val requester = groupFocusRequesters.getOrNull(target) ?: continue
                if (runCatching { requester.requestFocus() }.getOrDefault(false)) {
                    focused = true
                    break
                }
            }
            if (focused) {
                activeGroupFocusedIndex = target
            }
            ensureGroupChipVisibleNow(target)
        }
    }

    fun moveEpisodeFocus(
        targetIndex: Int,
        pinFocusMode: TvEpisodePlaylistPinMode,
        fromIndex: Int = activeEpisodeFocusedIndex.takeIf { index -> index >= 0 }
            ?: currentAbsoluteIndex,
    ) {
        if (episodes.isEmpty() || targetIndex !in episodes.indices) {
            return
        }
        val previousJob = episodeFocusMoveJob
        episodeFocusMoveJob = scrollScope.launch {
            previousJob?.join()
            if (!isActive) {
                return@launch
            }
            val liveFrom = activeEpisodeFocusedIndex
                .takeIf { index -> index >= 0 }
                ?: fromIndex
            val liveTo = when (pinFocusMode) {
                TvEpisodePlaylistPinMode.SoftEdgeFollow -> {
                    when {
                        targetIndex == fromIndex + 1 || targetIndex == liveFrom + 1 ->
                            (liveFrom + 1).coerceIn(0, episodes.lastIndex)
                        targetIndex == fromIndex - 1 || targetIndex == liveFrom - 1 ->
                            (liveFrom - 1).coerceIn(0, episodes.lastIndex)
                        else -> targetIndex.coerceIn(0, episodes.lastIndex)
                    }
                }
                TvEpisodePlaylistPinMode.PinLeading,
                TvEpisodePlaylistPinMode.KeepSlot,
                -> targetIndex.coerceIn(0, episodes.lastIndex)
            }
            if (liveTo == liveFrom && pinFocusMode == TvEpisodePlaylistPinMode.SoftEdgeFollow) {
                return@launch
            }
            moveHorizontalChipFocus(
                listState = episodeListState,
                fromIndex = liveFrom,
                toIndex = liveTo,
                pinFocusMode = pinFocusMode,
                leadingInsetPx = leadingInsetPx,
                trailingInsetPx = trailingInsetPx,
                requestFocus = { index ->
                    val primary = focusRequesterForAbsoluteIndex(index)
                    val fallback = episodeFocusRequesters.getOrNull(index)
                    requestFocusWhenReady(
                        primary = primary,
                        fallback = if (fallback !== primary) fallback else null,
                    )
                },
            )
            selectedGroup = liveTo / safeGroupSize
        }
    }

    val requestCurrentGroupFocus: () -> Unit = {
        moveGroupFocus(safeGroup)
    }

    val requestCurrentEpisodeFocus: () -> Unit = {
        moveEpisodeFocus(
            targetIndex = currentAbsoluteIndex,
            pinFocusMode = TvEpisodePlaylistPinMode.PinLeading,
        )
    }

    LaunchedEffect(safeGroup, showGroupChoices, groupCount) {
        if (!showGroupChoices || groupCount <= 0) {
            return@LaunchedEffect
        }
        withFrameNanos { }
        ensureGroupChipVisibleNow(safeGroup)
    }

    /**
     * 当前集变化 / 列表首帧：把选中集滚入可视区（不抢焦点）。
     * 详情页无 pinCurrentTicket，必须靠此保证第 600+ 集不会停在 1–20。
     */
    LaunchedEffect(currentAbsoluteIndex, episodes.size, currentEpisodeId) {
        if (episodes.isEmpty()) {
            return@LaunchedEffect
        }
        val target = currentAbsoluteIndex.coerceIn(0, episodes.lastIndex)
        // 等 LazyRow 完成首轮 measure，避免空 layoutInfo 时 scroll 无效。
        withFrameNanos { }
        for (attempt in 0 until 8) {
            if (attempt > 0) {
                delay(16L)
            }
            val visible = episodeListState.layoutInfo.visibleItemsInfo.any { info ->
                info.index == target
            }
            if (!visible) {
                runCatching { episodeListState.scrollToItem(index = target) }
                withFrameNanos { }
            } else {
                break
            }
        }
        // 钉到左侧安全区，与全屏打开播放列表观感一致。
        moveHorizontalChipFocus(
            listState = episodeListState,
            fromIndex = target,
            toIndex = target,
            pinFocusMode = TvEpisodePlaylistPinMode.PinLeading,
            leadingInsetPx = leadingInsetPx,
            trailingInsetPx = trailingInsetPx,
            requestFocus = {
                // 仅滚动：不 requestFocus，避免详情首屏抢走预览播放器焦点。
                true
            },
        )
        selectedGroup = target / safeGroupSize
        if (showGroupChoices) {
            ensureGroupChipVisibleNow(selectedGroup)
        }
    }

    LaunchedEffect(pinCurrentTicket) {
        if (pinCurrentTicket <= 0 || episodes.isEmpty()) {
            return@LaunchedEffect
        }
        moveHorizontalChipFocus(
            listState = episodeListState,
            fromIndex = activeEpisodeFocusedIndex.takeIf { index -> index >= 0 }
                ?: currentAbsoluteIndex,
            toIndex = currentAbsoluteIndex,
            pinFocusMode = TvEpisodePlaylistPinMode.PinLeading,
            leadingInsetPx = leadingInsetPx,
            trailingInsetPx = trailingInsetPx,
            requestFocus = { index ->
                val primary = focusRequesterForAbsoluteIndex(index)
                val fallback = episodeFocusRequesters.getOrNull(index)
                requestFocusWhenReady(
                    primary = primary,
                    fallback = if (fallback !== primary) fallback else null,
                )
            },
        )
        selectedGroup = currentAbsoluteIndex / safeGroupSize
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // 始终组合的入口：Hero/线路 down 指向它，避免 current 集未组合时整轨进不去。
        if (entryFocusRequester != null) {
            TvLazyListFocusEntry(
                entryFocusRequester = entryFocusRequester,
                preferredIndex = {
                    activeEpisodeFocusedIndex
                        .takeIf { index -> index >= 0 }
                        ?: currentAbsoluteIndex
                },
                itemCount = episodes.size,
                listState = episodeListState,
                requestItemFocus = { index ->
                    val primary = focusRequesterForAbsoluteIndex(index)
                    val fallback = episodeFocusRequesters.getOrNull(index)
                    requestFocusWhenReady(
                        primary = primary,
                        fallback = if (fallback !== primary) fallback else null,
                    )
                },
                // 入口下探允许滚到当前/上次集，保证业务落点正确。
                scrollPreferredIntoView = true,
            )
        }
        CompositionLocalProvider(LocalBringIntoViewSpec provides noAutoBringIntoViewSpec) {
            LazyRow(
                state = episodeListState,
                horizontalArrangement = Arrangement.spacedBy(episodeSpacing),
                contentPadding = PaddingValues(
                    start = contentStartPadding,
                    end = contentEndPadding,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(episodeRowHeight)
                    .focusProperties {
                        onEnter = {
                            val isVerticalEnter =
                                requestedFocusDirection == FocusDirection.Up ||
                                    requestedFocusDirection == FocusDirection.Down
                            if (isVerticalEnter) {
                                activeEpisodeFocusedIndex =
                                    TvLayeredHorizontalFocusScroll.NoActiveIndex
                                // 几何进轨时：可见就近；无可见则滚到当前集。
                                cancelFocusChange()
                                scrollScope.launch {
                                    val preferred = currentAbsoluteIndex
                                    focusLazyListItemNearest(
                                        listState = episodeListState,
                                        preferredIndex = preferred,
                                        itemCount = episodes.size,
                                        requestFocus = { index ->
                                            val primary = focusRequesterForAbsoluteIndex(index)
                                            val fallback = episodeFocusRequesters.getOrNull(index)
                                            requestFocusWhenReady(
                                                primary = primary,
                                                fallback = if (fallback !== primary) {
                                                    fallback
                                                } else {
                                                    null
                                                },
                                            )
                                        },
                                        scrollPreferredIntoView = false,
                                    )
                                }
                            }
                        }
                    }
                    .focusGroup(),
            ) {
                items(
                    count = episodes.size,
                    key = { index -> episodes[index].id },
                ) { absIndex ->
                    val ep = episodes[absIndex]
                    val isFirst = absIndex == 0
                    val isLast = absIndex == episodes.lastIndex
                    val isCurrent = ep.id == currentEpisodeId
                    val episodeRequester = episodeFocusRequesters.getOrNull(absIndex)
                    val baseRequesterModifier = if (isCurrent && currentEpisodeFocusRequester != null) {
                        Modifier.focusRequester(currentEpisodeFocusRequester)
                    } else if (episodeRequester != null) {
                        Modifier.focusRequester(episodeRequester)
                    } else {
                        Modifier
                    }
                    episodeChip(
                        TvEpisodePlaylistChipScope(
                            label = ep.label,
                            selected = isCurrent,
                            isFirst = isFirst,
                            isLast = isLast,
                            modifier = baseRequesterModifier.onFocusChanged { focusState ->
                                if (focusState.isFocused) {
                                    activeEpisodeFocusedIndex = absIndex
                                    val groupOfFocus = absIndex / safeGroupSize
                                    if (selectedGroup != groupOfFocus) {
                                        selectedGroup = groupOfFocus
                                    }
                                }
                            },
                            onClick = { onEpisodeSelected(ep.id) },
                            onArrowLeft = if (!isFirst) {
                                {
                                    moveEpisodeFocus(
                                        targetIndex = absIndex - 1,
                                        pinFocusMode = TvEpisodePlaylistPinMode.SoftEdgeFollow,
                                        fromIndex = absIndex,
                                    )
                                }
                            } else {
                                null
                            },
                            onArrowRight = if (!isLast) {
                                {
                                    moveEpisodeFocus(
                                        targetIndex = absIndex + 1,
                                        pinFocusMode = TvEpisodePlaylistPinMode.SoftEdgeFollow,
                                        fromIndex = absIndex,
                                    )
                                }
                            } else {
                                null
                            },
                            onArrowUp = onArrowUpFromEpisode,
                            onArrowDown = if (showGroupChoices) {
                                { requestCurrentGroupFocus() }
                            } else {
                                onArrowDownFromEpisodeNoGroups
                            },
                        ),
                    )
                }
            }
        }

        if (showGroupChoices) {
            LazyRow(
                state = groupListState,
                horizontalArrangement = Arrangement.spacedBy(groupSpacing),
                contentPadding = PaddingValues(
                    start = contentStartPadding,
                    end = contentEndPadding,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(groupRowHeight)
                    .focusProperties {
                        onEnter = {
                            val isVerticalEnter =
                                requestedFocusDirection == FocusDirection.Up ||
                                    requestedFocusDirection == FocusDirection.Down
                            if (isVerticalEnter) {
                                activeGroupFocusedIndex =
                                    TvLayeredHorizontalFocusScroll.NoActiveIndex
                            }
                        }
                    }
                    .focusGroup(),
            ) {
                items(groupCount) { gi ->
                    val start = gi * safeGroupSize + 1
                    val end = minOf((gi + 1) * safeGroupSize, episodes.size)
                    val groupRequester = groupFocusRequesters.getOrNull(gi)
                    groupChip(
                        TvEpisodePlaylistChipScope(
                            label = "$start-$end",
                            selected = gi == safeGroup,
                            isFirst = gi == 0,
                            isLast = gi == groupCount - 1,
                            modifier = Modifier
                                .then(
                                    if (groupRequester != null) {
                                        Modifier.focusRequester(groupRequester)
                                    } else {
                                        Modifier
                                    },
                                )
                                .onFocusChanged { focusState ->
                                    if (focusState.isFocused) {
                                        activeGroupFocusedIndex = gi
                                        ensureGroupChipVisible(gi)
                                    }
                                },
                            onClick = {
                                selectedGroup = gi
                                ensureGroupChipVisible(gi)
                                val firstAbs = gi * safeGroupSize
                                moveEpisodeFocus(
                                    targetIndex = firstAbs.coerceIn(0, episodes.lastIndex),
                                    pinFocusMode = TvEpisodePlaylistPinMode.PinLeading,
                                )
                            },
                            onArrowLeft = if (gi > 0) {
                                { moveGroupFocus(gi - 1) }
                            } else {
                                null
                            },
                            onArrowRight = if (gi < groupCount - 1) {
                                { moveGroupFocus(gi + 1) }
                            } else {
                                null
                            },
                            onArrowUp = { requestCurrentEpisodeFocus() },
                            onArrowDown = onArrowDownFromGroup,
                        ),
                    )
                }
            }
        }
    }
}

/**
 * 多帧重试 requestFocus（Lazy 项未挂载时会失败）。
 */
suspend fun requestFocusWhenReady(
    primary: FocusRequester?,
    fallback: FocusRequester? = null,
    attempts: Int = 12,
    frameDelayMs: Long = 16L,
): Boolean {
    if (primary == null && fallback == null) {
        return false
    }
    repeat(attempts) { attempt ->
        if (attempt > 0) {
            delay(frameDelayMs)
        }
        if (primary != null && runCatching { primary.requestFocus() }.getOrDefault(false)) {
            return true
        }
        if (fallback != null && runCatching { fallback.requestFocus() }.getOrDefault(false)) {
            return true
        }
    }
    return false
}

/**
 * 横向 chip 列表：先滚后焦，再按 [pinFocusMode] 软边/钉左。
 */
suspend fun moveHorizontalChipFocus(
    listState: LazyListState,
    fromIndex: Int,
    toIndex: Int,
    pinFocusMode: TvEpisodePlaylistPinMode,
    leadingInsetPx: Int,
    trailingInsetPx: Int,
    requestFocus: suspend (Int) -> Boolean,
): Boolean {
    if (toIndex < 0) {
        return false
    }
    val fromInfo = listState.layoutInfo.visibleItemsInfo.firstOrNull { info ->
        info.index == fromIndex
    }
    val anchorOffset = fromInfo?.offset
    val lastIndex = (listState.layoutInfo.totalItemsCount - 1).coerceAtLeast(0)

    val targetVisible = listState.layoutInfo.visibleItemsInfo.any { info ->
        info.index == toIndex
    }
    if (!targetVisible) {
        runCatching { listState.scrollToItem(index = toIndex) }
        withFrameNanos { }
    }

    var focused = requestFocus(toIndex)
    if (!focused) {
        runCatching { listState.scrollToItem(index = toIndex) }
        withFrameNanos { }
        focused = requestFocus(toIndex)
        if (!focused) {
            return false
        }
    }

    withFrameNanos { }
    val toInfo = listState.layoutInfo.visibleItemsInfo.firstOrNull { info ->
        info.index == toIndex
    } ?: return true

    val layoutInfo = listState.layoutInfo
    val effectiveLeading = layoutInfo.beforeContentPadding.takeIf { pad -> pad > 0 }
        ?: leadingInsetPx
    val effectiveTrailing = layoutInfo.afterContentPadding.takeIf { pad -> pad > 0 }
        ?: trailingInsetPx
    val viewportStart = layoutInfo.viewportStartOffset
    val viewportEnd = layoutInfo.viewportEndOffset
    val leftDelta = (toInfo.offset - (viewportStart + effectiveLeading)).toFloat()
    val rightDelta = (toInfo.offset + toInfo.size - (viewportEnd - effectiveTrailing)).toFloat()

    when (pinFocusMode) {
        TvEpisodePlaylistPinMode.KeepSlot -> {
            if (anchorOffset != null) {
                val delta = (toInfo.offset - anchorOffset).toFloat()
                if (abs(delta) > 0.5f) {
                    listState.scrollBy(delta)
                }
            }
        }
        TvEpisodePlaylistPinMode.PinLeading -> {
            if (abs(leftDelta) > 0.5f) {
                listState.scrollBy(leftDelta)
            }
        }
        TvEpisodePlaylistPinMode.SoftEdgeFollow -> {
            when {
                toIndex == 0 || leftDelta < 0f -> {
                    if (abs(leftDelta) > 0.5f) {
                        listState.scrollBy(leftDelta)
                    }
                }
                toIndex >= lastIndex || rightDelta > 0f -> {
                    if (abs(rightDelta) > 0.5f) {
                        listState.scrollBy(rightDelta)
                    }
                }
            }
        }
    }
    return true
}

/**
 * 把 chip 滚入视口（屏外优先瞬移）。
 */
suspend fun scrollChipIntoViewSuspend(
    listState: LazyListState,
    index: Int,
    itemCount: Int,
    leadingInsetPx: Int = 0,
    trailingInsetPx: Int = 0,
) {
    if (itemCount <= 0 || index !in 0 until itemCount) {
        return
    }
    var target = listState.layoutInfo.visibleItemsInfo
        .firstOrNull { info -> info.index == index }
    if (target == null) {
        runCatching { listState.scrollToItem(index = index) }
        withFrameNanos { }
        target = listState.layoutInfo.visibleItemsInfo
            .firstOrNull { info -> info.index == index }
        if (target == null) {
            runCatching { listState.animateScrollToItem(index = index) }
            target = listState.layoutInfo.visibleItemsInfo
                .firstOrNull { info -> info.index == index }
                ?: return
        }
    }
    val layoutInfo = listState.layoutInfo
    val effectiveLeading = layoutInfo.beforeContentPadding.takeIf { pad -> pad > 0 }
        ?: leadingInsetPx
    val effectiveTrailing = layoutInfo.afterContentPadding.takeIf { pad -> pad > 0 }
        ?: trailingInsetPx
    val leftDelta = (target.offset - (layoutInfo.viewportStartOffset + effectiveLeading)).toFloat()
    val rightDelta =
        (target.offset + target.size - (layoutInfo.viewportEndOffset - effectiveTrailing)).toFloat()
    when {
        index == 0 || leftDelta < 0f -> {
            if (abs(leftDelta) > 0.5f) {
                listState.animateScrollBy(leftDelta)
            }
        }
        index >= itemCount - 1 || rightDelta > 0f -> {
            if (abs(rightDelta) > 0.5f) {
                listState.animateScrollBy(rightDelta)
            }
        }
    }
}
