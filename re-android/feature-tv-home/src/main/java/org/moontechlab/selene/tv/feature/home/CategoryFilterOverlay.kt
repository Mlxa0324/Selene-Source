package org.moontechlab.selene.tv.feature.home

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import kotlin.math.roundToInt
import kotlinx.coroutines.delay

/**
 * 壳层分类筛选 overlay 状态：由分类页写入数据，由壳层绘制图层。
 *
 * 列表顶开高度 [revealedHeightPx] 与面板下滑共用同一 progress，避免双套动画。
 */
class CategoryFilterOverlayState {
    /** 当前分类可用筛选项（空表示本页不提供 overlay 内容）。 */
    var filters by mutableStateOf<List<TvLibraryFilter>>(emptyList())

    /** 筛选确认回调。 */
    var onOptionSelected by mutableStateOf<((String, String) -> Unit)?>(null)

    /** 打开筛选时落焦的入口请求器（分类页 content 入口）。 */
    var entryFocusRequester by mutableStateOf<FocusRequester?>(null)

    /**
     * 列表应预留的顶部 inset（px）= (伸进内容区高度 + 与列表间距) × progress。
     * 由 overlay 写入，分类页只读。
     */
    var revealedHeightPx by mutableIntStateOf(0)

    /**
     * 0..1 展开进度，供淡入淡出与列表 inset 同步。
     */
    var revealProgress by mutableFloatStateOf(0f)
}

/** 壳层提供、分类页消费的 overlay 状态。 */
val LocalCategoryFilterOverlayState = compositionLocalOf<CategoryFilterOverlayState?> { null }

/**
 * 全屏坐标系下的分类筛选图层。
 *
 * - 起点：略高于屏幕顶边（约 20% 面板高），从上往下滑入
 * - 落点：translationY = 0，整块贴屏顶，**完全盖住** Logo + 主菜单 tab
 * - 底层顶栏仍占位（不卸组合），只是被 overlay 盖住
 * - 列表 inset = (max(0, 面板高 - 顶栏高) + 弹框与列表间距) × progress
 *
 * @param visible 是否展开筛选。
 * @param topChromeHeightPx 固定顶栏实测高度。
 * @param state overlay 状态。
 */
@Composable
fun TvCategoryFilterOverlayLayer(
    visible: Boolean,
    topChromeHeightPx: Int,
    state: CategoryFilterOverlayState,
) {
    val density = LocalDensity.current
    var panelHeightPx by remember { mutableIntStateOf(0) }
    val heightReady = panelHeightPx > 0
    // 关闭时拉长淡出，配合底层去模糊，避免顶栏焦点瞬间可抢。
    val progress by animateFloatAsState(
        targetValue = if (visible && heightReady && state.filters.isNotEmpty()) 1f else 0f,
        animationSpec = tween(
            durationMillis = if (visible) 320 else 280,
            easing = FastOutSlowInEasing,
        ),
        label = "categoryFilterOverlayProgress",
    )
    val composePanel = (visible || progress > 0.001f) && state.filters.isNotEmpty()
    val chromePx = topChromeHeightPx.coerceAtLeast(0)
    // 贴屏顶后，只有「超出顶栏、伸进内容区」的那一段需要顶开海报。
    val hangIntoContentPx = (panelHeightPx - chromePx).coerceAtLeast(0)
    // 弹框底边与首行海报之间略留呼吸间距（随 progress 同步）。
    val listGapPx = with(density) { 12.dp.roundToPx() }
    val revealedHeightPx = ((hangIntoContentPx + listGapPx) * progress).roundToInt()
    // 落点贴屏顶（完全遮挡 Logo/tab）；起点略上方，短距下滑。
    val restY = 0f
    val startY = if (heightReady) {
        -panelHeightPx * 0.2f
    } else {
        0f
    }
    val translationYPx = if (heightReady) {
        startY + (restY - startY) * progress
    } else {
        0f
    }

    SideEffect {
        state.revealProgress = progress
        state.revealedHeightPx = if (visible || progress > 0.001f) revealedHeightPx else 0
    }

    val entryFocus = state.entryFocusRequester
    LaunchedEffect(visible, entryFocus, heightReady, progress) {
        if (!visible || entryFocus == null || !heightReady) {
            return@LaunchedEffect
        }
        // 等 chip 挂上 focusRequester 再落焦，失败不抛杀进程。
        for (attempt in 0 until 20) {
            delay(32)
            val ok = runCatching { entryFocus.requestFocus() }.getOrDefault(false)
            if (ok) {
                return@LaunchedEffect
            }
        }
    }

    if (!composePanel) {
        return
    }

    // 至少盖住整段顶栏，避免内容偏矮时露出 Logo/tab。
    val minCoverHeight = with(density) { chromePx.toDp() }
    val panelAlpha = if (heightReady) progress.coerceIn(0f, 1f) else 0f

    // 仅筛选弹框本身做图层与动画；不铺全屏实色，海报保持清晰可见。
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .zIndex(12f),
    ) {
        TvLibraryFilterPanel(
            filters = state.filters,
            contentFocusRequester = entryFocus.takeIf { visible },
            onOptionSelected = state.onOptionSelected,
            modifier = Modifier
                .align(Alignment.TopStart)
                .fillMaxWidth()
                .heightIn(min = minCoverHeight)
                .onSizeChanged { size ->
                    if (size.height > 0 && size.height != panelHeightPx) {
                        panelHeightPx = size.height
                    }
                }
                .graphicsLayer {
                    translationY = translationYPx
                    alpha = panelAlpha
                },
        )
    }
}
