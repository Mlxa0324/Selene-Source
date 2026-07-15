package org.moontechlab.selene.tv.feature.home

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
     * 列表应预留的顶部 inset（px）= 面板全高 × progress。
     * 由 overlay 写入，分类页只读。
     */
    var revealedHeightPx by mutableIntStateOf(0)
}

/** 壳层提供、分类页消费的 overlay 状态。 */
val LocalCategoryFilterOverlayState = compositionLocalOf<CategoryFilterOverlayState?> { null }

/**
 * 全屏坐标系下的分类筛选图层。
 *
 * - 起点：面板在屏幕上方（translationY = -H）
 * - 落点：顶栏下沿（translationY = topChromeHeightPx）
 * - 顶栏与 Logo 仍在底层占位，不参与收起
 * - 动画仅用 graphicsLayer，列表用 [CategoryFilterOverlayState.revealedHeightPx] inset
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
    var panelHeightPx by remember { mutableIntStateOf(0) }
    val heightReady = panelHeightPx > 0
    val progress by animateFloatAsState(
        targetValue = if (visible && heightReady && state.filters.isNotEmpty()) 1f else 0f,
        animationSpec = tween(
            durationMillis = if (visible) 320 else 260,
            easing = FastOutSlowInEasing,
        ),
        label = "categoryFilterOverlayProgress",
    )
    val composePanel = (visible || progress > 0.001f) && state.filters.isNotEmpty()
    // 列表 inset：只顶海报区，不动顶栏。
    val revealedHeightPx = (panelHeightPx * progress).roundToInt()
    // 整屏坐标：p=0 在屏上沿外，p=1 落在顶栏下沿。
    val restY = topChromeHeightPx.coerceAtLeast(0)
    val translationYPx = if (heightReady) {
        -panelHeightPx + (restY + panelHeightPx) * progress
    } else {
        0f
    }

    LaunchedEffect(revealedHeightPx) {
        state.revealedHeightPx = revealedHeightPx
    }
    LaunchedEffect(visible) {
        if (!visible) {
            // 关闭后清空 inset，避免残留顶开。
            state.revealedHeightPx = 0
        }
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
                .onSizeChanged { size ->
                    if (size.height > 0 && size.height != panelHeightPx) {
                        panelHeightPx = size.height
                    }
                }
                .graphicsLayer {
                    translationY = translationYPx
                    alpha = if (heightReady) progress.coerceIn(0f, 1f) else 0f
                },
        )
    }
}
