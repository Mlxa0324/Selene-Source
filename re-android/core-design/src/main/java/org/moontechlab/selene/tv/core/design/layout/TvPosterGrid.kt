package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlin.math.abs
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.rememberTvEdgeShakeState
import org.moontechlab.selene.tv.core.design.focus.tvEdgeShake

/**
 * TV 纵向海报网格。
 *
 * 方向键使用显式行列邻居（同列上下 / 同行左右），避免 Compose 默认焦点搜索
 * 在「封面不满格宽」时退化成线性上一项，出现「上行最后一个」而不是「正上方」的误跳。
 *
 * @param items 影视卡片列表。
 * @param columns 每行列数。
 * @param modifier 外层修饰器。
 * @param headerContent 网格顶部内容（全宽 span，随网格滚动）。
 * @param firstItemFocusRequester 内容区入口焦点请求器，进入分组后转给首张海报。
 * @param onItemClick 卡片点击回调。
 * @param onItemLongClick 卡片长按 / 菜单键回调（播放历史、收藏删除等）。
 * @param contentHorizontalPadding 网格左右 contentPadding；容器内嵌时可减小。
 * @param contentTopPadding 网格顶部 contentPadding；给首行获焦放大留白，避免顶缘被裁。
 * @param contentBottomPadding 网格底部 contentPadding。
 * @param horizontalSpacing 列间距。
 * @param verticalSpacing 行间距。
 * @param fillCellWidth true 时卡片铺满单元格宽（搜索 5 列更舒展）；false 用全局固定海报宽。
 * @param prefetchRows 距离末尾多少行时开始触发下一页预取。
 * @param onApproachingEnd 焦点接近列表末尾时触发，用于触底加载下一页。
 */
@Composable
fun TvPosterGrid(
    items: List<TvPosterItem>,
    columns: Int,
    modifier: Modifier = Modifier,
    headerContent: (@Composable () -> Unit)? = null,
    firstItemFocusRequester: FocusRequester? = null,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    onItemLongClick: ((TvPosterItem) -> Unit)? = null,
    contentHorizontalPadding: Dp = TvListLayoutMetrics.GridHorizontalPadding,
    contentTopPadding: Dp = TvListLayoutMetrics.FocusSafePadding,
    contentBottomPadding: Dp = TvListLayoutMetrics.GridBottomPadding,
    horizontalSpacing: Dp = TvTokens.CardSpacing,
    verticalSpacing: Dp = TvTokens.CardSpacing,
    fillCellWidth: Boolean = false,
    prefetchRows: Int = 3,
    onApproachingEnd: (() -> Unit)? = null,
) {
    // 预取行数至少保留一行，避免外部错误配置导致末尾分页失效。
    val resolvedPrefetchRows = prefetchRows.coerceAtLeast(1)
    val safeColumns = columns.coerceAtLeast(1)
    val designMetrics = LocalTvDesignMetrics.current
    val gridState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyGridState.Saver,
    ) {
        LazyGridState()
    }
    // 首卡 requester 即 itemFocusRequesters[0]，单挂避免双 FocusRequester 失效。
    val firstCardFocusRequester = remember { FocusRequester() }
    val itemFocusRequesters = remember(items.size) {
        List(items.size) { index ->
            if (index == 0) firstCardFocusRequester else FocusRequester()
        }
    }
    val scrollScope = rememberCoroutineScope()
    var gridFocusScrollJob by remember { mutableStateOf<Job?>(null) }
    var lastFocusedItemIndex by rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
    ) {
        mutableIntStateOf(0)
    }
    // 全宽 header 占 1 个 lazy 下标，animateScrollToItem 必须加上偏移。
    val headerLazyOffset = if (headerContent != null) 1 else 0
    // 首次 RESUME 不抢焦（留给顶栏/入口）；之后从详情返回再 RESUME 时恢复上次卡片。
    var hasCompletedFirstResume by rememberSaveable { mutableStateOf(false) }
    val lifecycleOwner = LocalLifecycleOwner.current

    /**
     * 滚到 [lastFocusedItemIndex] 并请求焦点；用于详情返回后还原选中卡。
     */
    fun restoreFocusToLastItem() {
        if (items.isEmpty()) {
            return
        }
        val target = lastFocusedItemIndex.coerceIn(0, items.lastIndex)
        lastFocusedItemIndex = target
        val lazyIndex = target + headerLazyOffset
        gridFocusScrollJob?.cancel()
        gridFocusScrollJob = scrollScope.launch {
            // 先瞬时滚进视口，避免 requestFocus 打在已回收 item 上失败。
            val visible = gridState.layoutInfo.visibleItemsInfo.any { info -> info.index == lazyIndex }
            if (!visible) {
                runCatching { gridState.scrollToItem(index = lazyIndex) }
                delay(32)
            }
            val focused = runCatching {
                itemFocusRequesters.getOrNull(target)?.requestFocus() == true
            }.getOrDefault(false)
            if (!focused) {
                // 首帧 requester 未挂上时再试一次入口 requester。
                delay(16)
                runCatching {
                    itemFocusRequesters.getOrNull(target)?.requestFocus()
                        ?: firstItemFocusRequester?.requestFocus()
                }
            }
        }
    }

    DisposableEffect(lifecycleOwner, items.size) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> {
                    if (!hasCompletedFirstResume) {
                        hasCompletedFirstResume = true
                    } else if (items.isNotEmpty()) {
                        // 详情页 pop 后分类页回到 RESUMED：落焦并露出上次卡片。
                        restoreFocusToLastItem()
                    }
                }
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    Box(modifier = modifier) {
        // 顶栏下探入口始终组合：上次卡片不在可视区时仍可 scroll + 落焦。
        if (firstItemFocusRequester != null && items.isNotEmpty()) {
            Box(
                modifier = Modifier
                    .size(1.dp)
                    .focusRequester(firstItemFocusRequester)
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            restoreFocusToLastItem()
                        }
                    }
                    .focusable(),
            )
        }
    LazyVerticalGrid(
        columns = GridCells.Fixed(safeColumns),
        modifier = Modifier.posterGridFocusGroup(
            firstCardFocusRequester = firstCardFocusRequester,
            gridState = gridState,
            preferredIndex = { lastFocusedItemIndex },
            itemCount = items.size,
            headerOffset = headerLazyOffset,
            requestItemFocus = { index ->
                runCatching {
                    itemFocusRequesters.getOrNull(index)?.requestFocus() == true
                }.getOrDefault(false)
            },
        ),
        state = gridState,
        contentPadding = PaddingValues(
            start = contentHorizontalPadding,
            top = contentTopPadding,
            end = contentHorizontalPadding,
            bottom = contentBottomPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(verticalSpacing),
        horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
    ) {
        // 网格头部（全宽，不获焦，随网格一起滚动）
        if (headerContent != null) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                headerContent()
            }
        }
        itemsIndexed(items, key = ::posterListItemKey) { index, item ->
            // 内容入口由外层 1dp entry 独占 firstItemFocusRequester。
            val cardFocusRequesters = buildList {
                // 每项挂索引 requester，供方向键同列/同行就近移动。
                itemFocusRequesters.getOrNull(index)?.let { add(it) }
            }
            val column = index % safeColumns
            val lastIndex = items.lastIndex
            // 每卡独立抖动态，仅当前获焦项在边界按键时反馈。
            val edgeShake = rememberTvEdgeShakeState()
            val downIndex = resolveGridDownIndex(
                index = index,
                itemCount = items.size,
                columns = safeColumns,
            )
            val isLeftEdge = column == 0
            val isRightEdge = column >= safeColumns - 1 || index >= lastIndex
            // 末行再 Down：到底抖动；首行 Up 仍交给顶栏/筛选，不抖。
            val isDownEdge = downIndex == null
            BoxWithConstraints(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.TopCenter,
            ) {
                // fillCellWidth：搜索 5 列铺满格宽；首页等仍用固定海报宽居中。
                val resolvedCardWidth = if (fillCellWidth) {
                    maxWidth
                } else {
                    TvTokens.PosterWidth
                }
                TvPosterCard(
                    item = item,
                    cardWidth = resolvedCardWidth,
                    // 边界抖动位移挂在整卡（含标题）上。
                    modifier = Modifier.tvEdgeShake(edgeShake),
                    focusRequesters = cardFocusRequesters,
                    // 网格跟滚由 scrollFocusedItemWithCenterBand 统一负责，禁止 bringIntoView 抢滚动。
                    requestBringIntoViewOnFocus = false,
                    // 显式行列邻居：上/下同列，左/右同行；禁止退化到「上一行最后一个」。
                    focusProperties = {
                        left = if (column > 0) {
                            itemFocusRequesters[index - 1]
                        } else {
                            FocusRequester.Cancel
                        }
                        right = if (column < safeColumns - 1 && index < lastIndex) {
                            itemFocusRequesters[index + 1]
                        } else {
                            FocusRequester.Cancel
                        }
                        up = if (index >= safeColumns) {
                            itemFocusRequesters[index - safeColumns]
                        } else {
                            // 首行交给系统几何搜索（顶栏/筛选），不在网格内线性回退。
                            FocusRequester.Default
                        }
                        // 同列优先；下一行缺列时落到末项，避免末列 Down 无响应。
                        down = downIndex?.let { target ->
                            itemFocusRequesters[target]
                        } ?: FocusRequester.Cancel
                    },
                    onPreviewKey = { event ->
                        // 同列上下目标若未组合：先 scroll 再落焦，避免「不在可视区就无法移动」。
                        if (event.type == KeyEventType.KeyDown) {
                            val verticalTarget = when (event.key) {
                                Key.DirectionDown -> downIndex
                                Key.DirectionUp -> if (index >= safeColumns) {
                                    index - safeColumns
                                } else {
                                    null
                                }
                                else -> null
                            }
                            if (verticalTarget != null) {
                                val attached = runCatching {
                                    itemFocusRequesters.getOrNull(verticalTarget)?.requestFocus() == true
                                }.getOrDefault(false)
                                if (attached) {
                                    return@TvPosterCard true
                                }
                                scrollScope.launch {
                                    focusLazyGridItemNearest(
                                        gridState = gridState,
                                        preferredIndex = verticalTarget,
                                        itemCount = items.size,
                                        headerOffset = headerLazyOffset,
                                        requestFocus = { businessIndex ->
                                            runCatching {
                                                itemFocusRequesters.getOrNull(businessIndex)
                                                    ?.requestFocus() == true
                                            }.getOrDefault(false)
                                        },
                                        scrollPreferredIntoView = true,
                                    )
                                }
                                return@TvPosterCard true
                            }
                        }
                        edgeShake.consumeBoundaryKey(
                            event = event,
                            left = isLeftEdge,
                            right = isRightEdge,
                            down = isDownEdge,
                        )
                    },
                    onClick = onItemClick?.let { click ->
                        {
                            // 进详情前停掉跟滚，避免确认瞬间列表还在 animate 造成整页抖一下。
                            gridFocusScrollJob?.cancel()
                            gridFocusScrollJob = null
                            // 确认时立刻记下位置，返回后即使焦点链路被重置也能还原。
                            lastFocusedItemIndex = index
                            click(item)
                        }
                    },
                    onLongClick = onItemLongClick?.let { longClick ->
                        {
                            lastFocusedItemIndex = index
                            longClick(item)
                        }
                    },
                    onFocusChanged = { hasFocus ->
                        if (hasFocus) {
                            // 记录真实业务焦点，避免首卡被 LazyGrid 回收后顶部下探没有目标。
                            lastFocusedItemIndex = index
                            val lazyIndex = index + headerLazyOffset
                            // 首行 lazy 下标范围：[headerOffset, headerOffset + columns)
                            val firstRowEndExclusive = headerLazyOffset + safeColumns
                            // 末行业务下标起点（半行末列也算末行）。
                            val lastRowStartIndex = resolveLastRowStartIndex(
                                itemCount = items.size,
                                columns = safeColumns,
                            )
                            val lastRowStartLazy = lastRowStartIndex + headerLazyOffset
                            val lastLazyIndex = items.lastIndex + headerLazyOffset
                            // 取消上一次跟滚，避免连按方向键时动画互相打断导致底行标题露不出。
                            val previousJob = gridFocusScrollJob
                            gridFocusScrollJob = scrollScope.launch {
                                previousJob?.cancel()
                                // 中心带跟焦；首行钉顶、末行钉底，中间才中线跟滚。
                                gridState.scrollFocusedItemWithCenterBand(
                                    lazyIndex = lazyIndex,
                                    firstRowEndExclusive = firstRowEndExclusive,
                                    lastRowStartLazy = lastRowStartLazy,
                                    lastLazyIndex = lastLazyIndex,
                                )
                            }
                        }
                        // 焦点进入预取阈值时后台请求下一页，避免用户触底后停在加载态。
                        val approachingEnd = index >= items.size - safeColumns * resolvedPrefetchRows
                        if (hasFocus && approachingEnd && onApproachingEnd != null) {
                            onApproachingEnd()
                        }
                    },
                )
            }
        }
    }
    } // Box
}

/**
 * 业务列表末行首项 0-based 下标。
 *
 * @param itemCount 业务项数量。
 * @param columns 列数。
 * @return 末行第一个业务下标；空列表为 0。
 */
private fun resolveLastRowStartIndex(itemCount: Int, columns: Int): Int {
    if (itemCount <= 0) return 0
    val safeColumns = columns.coerceAtLeast(1)
    val rem = itemCount % safeColumns
    return if (rem == 0) {
        (itemCount - safeColumns).coerceAtLeast(0)
    } else {
        itemCount - rem
    }
}

/**
 * 网格 Down 邻居业务下标。
 *
 * - 下一行同列存在：落到 `index + columns`。
 * - 下一行存在但缺列（半行）：落到列表末项，避免末列 Down 被 Cancel 卡死。
 * - 已在末行：返回 null（调用方 Cancel 或交给外层）。
 *
 * @param index 当前业务下标。
 * @param itemCount 业务项数量。
 * @param columns 列数。
 * @return 目标下标；无向下邻居时 null。
 */
fun resolveGridDownIndex(
    index: Int,
    itemCount: Int,
    columns: Int,
): Int? {
    if (itemCount <= 0 || index < 0 || index >= itemCount) {
        return null
    }
    val safeColumns = columns.coerceAtLeast(1)
    val lastIndex = itemCount - 1
    val exactDown = index + safeColumns
    if (exactDown <= lastIndex) {
        return exactDown
    }
    val currentRow = index / safeColumns
    val lastRow = lastIndex / safeColumns
    // 还有更低的半行：夹到末项（用户期望的「落到最后一个」）。
    return if (currentRow < lastRow) lastIndex else null
}

/**
 * 纵向网格跟焦：优先保证「封面+标题」整卡在视口内。
 *
 * - **首行**：钉到真正列表顶。
 * - **末行**：钉到真正列表底。
 * - **中间行**：多轮瞬时 scrollBy 校正顶/底裁切；底边安全区加大，避免只露封面不见标题。
 *
 * 禁止与卡片 bringIntoView 并用（网格侧已关）。
 */
private suspend fun LazyGridState.scrollFocusedItemWithCenterBand(
    lazyIndex: Int,
    firstRowEndExclusive: Int,
    lastRowStartLazy: Int,
    lastLazyIndex: Int,
) {
    // 首行：必须到真正顶部。
    if (lazyIndex in 0 until firstRowEndExclusive) {
        scrollGridToAbsoluteTop()
        return
    }
    // 末行：必须到真正底部，否则末行标题/副标题停在视口外。
    if (lastLazyIndex >= 0 && lazyIndex >= lastRowStartLazy) {
        scrollGridToAbsoluteBottom(
            lastLazyIndex = lastLazyIndex,
            focusedLazyIndex = lazyIndex,
        )
        return
    }
    if (layoutInfo.visibleItemsInfo.none { info -> info.index == lazyIndex }) {
        // 尚未进入布局：瞬时滚进可见范围（避免 animate 被下次获焦取消）。
        scrollToItem(lazyIndex)
    }
    // 顶边：描边；底边：标题块必须完整进屏（宁可多滚一点）。
    val topEdgeSafePx = 12
    val bottomEdgeSafePx = 48
    // 多轮校正：先底后顶，解决「只露出封面、标题仍在视口外」。
    repeat(8) {
        val target = layoutInfo.visibleItemsInfo.firstOrNull { info -> info.index == lazyIndex }
            ?: return
        val viewportStart = layoutInfo.viewportStartOffset
        val viewportEnd = layoutInfo.viewportEndOffset
        val itemStart = target.offset.y
        val itemEnd = itemStart + target.size.height
        when {
            itemEnd > viewportEnd - bottomEdgeSafePx -> {
                val delta = (itemEnd - (viewportEnd - bottomEdgeSafePx)).toFloat()
                if (delta > 1f) {
                    scrollBy(delta)
                } else {
                    return
                }
            }
            itemStart < viewportStart + topEdgeSafePx -> {
                val delta = (itemStart - (viewportStart + topEdgeSafePx)).toFloat()
                if (abs(delta) > 1f) {
                    scrollBy(delta)
                } else {
                    return
                }
            }
            else -> return
        }
    }
}

/**
 * 把纵向网格钉到真正顶部（firstVisible=0 且 scrollOffset=0）。
 *
 * 仅 animateScrollToItem(0) 在部分机型/动画中断后可能仍留 residual offset，
 * 故动画后再 scrollToItem 一次兜底。
 */
private suspend fun LazyGridState.scrollGridToAbsoluteTop() {
    if (firstVisibleItemIndex == 0 && firstVisibleItemScrollOffset == 0) {
        return
    }
    animateScrollToItem(index = 0, scrollOffset = 0)
    if (firstVisibleItemIndex != 0 || firstVisibleItemScrollOffset != 0) {
        scrollToItem(index = 0, scrollOffset = 0)
    }
    // 极端情况下 layout 仍带一点像素 residual，再用 scrollBy 吃掉。
    val residual = firstVisibleItemScrollOffset
    if (firstVisibleItemIndex == 0 && residual > 0) {
        scrollBy(-residual.toFloat())
    }
}

/**
 * 把纵向网格钉到真正底部。
 *
 * 策略（比「animate 到末项 + 有限次 animateScrollBy」更稳）：
 * 1. 末项未布局时先 scrollToItem 带进视口；
 * 2. 按末项/当前项几何把 item 底边滚到 viewportEnd 内侧（保证标题在布局高度内）；
 * 3. 再用瞬时 scrollBy 抽干 canScrollForward，吃掉 contentBottomPadding。
 *
 * 不用 animateScrollToItem(last) 钉在视口顶再慢慢推——动画易被下一次获焦取消，表现为到底失败。
 *
 * @param lastLazyIndex 最后一项的 lazy 下标（含 header 偏移）。
 * @param focusedLazyIndex 当前获焦 lazy 下标，优先保证该项底边露出。
 */
private suspend fun LazyGridState.scrollGridToAbsoluteBottom(
    lastLazyIndex: Int,
    focusedLazyIndex: Int = lastLazyIndex,
) {
    if (lastLazyIndex < 0) {
        return
    }
    // 1) 末项进布局（瞬时，避免动画被取消）。
    if (layoutInfo.visibleItemsInfo.none { info -> info.index == lastLazyIndex }) {
        scrollToItem(index = lastLazyIndex)
    }
    // 2) 几何：优先当前获焦项，否则末项；底边（含标题）顶到视口底内侧。
    // 标题两行 + 间距约 40–50dp，safe 取足；scale 描边不占布局另留一点。
    val bottomSafePx = 36
    repeat(6) {
        val targetInfo = layoutInfo.visibleItemsInfo.firstOrNull { info ->
            info.index == focusedLazyIndex
        } ?: layoutInfo.visibleItemsInfo.firstOrNull { info ->
            info.index == lastLazyIndex
        } ?: layoutInfo.visibleItemsInfo.maxByOrNull { info -> info.index }
            ?: return
        val viewportEnd = layoutInfo.viewportEndOffset
        val itemEnd = targetInfo.offset.y + targetInfo.size.height
        val overflow = (itemEnd - (viewportEnd - bottomSafePx)).toFloat()
        if (overflow > 1f) {
            scrollBy(overflow)
        } else {
            return@repeat
        }
    }
    // 3) 抽干剩余 scroll extent（contentBottomPadding 等），确保末行标题真正进屏。
    var guard = 0
    while (canScrollForward && guard < 32) {
        val viewportSpan = (layoutInfo.viewportEndOffset - layoutInfo.viewportStartOffset)
            .coerceAtLeast(32)
            .toFloat()
        scrollBy(viewportSpan * 0.35f)
        guard++
    }
    // 4) 再校正一次获焦项底边，避免 step3 把项顶得过高后又因 residual 裁标题。
    val finalInfo = layoutInfo.visibleItemsInfo.firstOrNull { info ->
        info.index == focusedLazyIndex
    } ?: layoutInfo.visibleItemsInfo.firstOrNull { info ->
        info.index == lastLazyIndex
    }
    if (finalInfo != null) {
        val overflow = (
            finalInfo.offset.y + finalInfo.size.height -
                (layoutInfo.viewportEndOffset - bottomSafePx)
            ).toFloat()
        if (overflow > 1f) {
            scrollBy(overflow)
        }
    }
}
