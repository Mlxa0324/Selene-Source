package org.moontechlab.selene.tv.feature.favorites

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.dialog.TvConfirmDialog
import org.moontechlab.selene.tv.core.design.layout.TvEmptyStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvHeaderActionButton
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterGridSkeleton
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvScrollablePageHeader
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind
import org.moontechlab.selene.tv.core.design.layout.toVideoDetailKey

/**
 * TV 收藏夹路由。
 *
 * 页头紧凑、随网格滚动（对齐电影 Tab）；右侧「删除全部」需二次确认。
 *
 * @param state 收藏夹界面状态。
 * @param contentFocusRequester 内容区首张海报焦点请求器。
 * @param onVideoClick 视频卡片点击回调。
 * @param onClearAll 清空全部收藏回调。
 */
@Composable
fun TvFavoritesRoute(
    state: TvFavoritesUiState = TvFavoritesUiState(),
    contentFocusRequester: FocusRequester? = null,
    onVideoClick: (String) -> Unit = {},
    onClearAll: (suspend () -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    var showClearConfirm by remember { mutableStateOf(false) }
    val firstItemFocusRequester = remember { FocusRequester() }
    val resolvedContentFocus = contentFocusRequester ?: firstItemFocusRequester

    TvPageScaffold(
        title = null,
        modifier = Modifier.fillMaxSize(),
    ) {
        val showSkeleton = state.isLoading && state.videos.isEmpty()
        if (showSkeleton) {
            TvPosterGridSkeleton(contentFocusRequester = resolvedContentFocus)
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank() && state.videos.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "收藏夹加载失败",
                message = state.errorMessage,
                contentFocusRequester = resolvedContentFocus,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            TvScrollablePageHeader(
                title = "收藏夹",
                subtitle = "我的收藏",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            TvEmptyStatePanel(
                title = "收藏夹还没有内容",
                message = "收藏过的视频会在这里按网格展示，方便遥控器快速浏览。",
                contentFocusRequester = resolvedContentFocus,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
        } else {
            TvPosterGrid(
                items = state.videos.map { video ->
                    TvPosterItem(
                        id = video.id,
                        source = video.source,
                        title = video.title,
                        subtitle = video.favoriteSubtitle(),
                        posterUrl = video.posterUrl,
                        totalEpisodes = video.totalEpisodes,
                    )
                },
                columns = TvListLayoutMetrics.PosterColumns,
                firstItemFocusRequester = resolvedContentFocus,
                onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                headerContent = {
                    TvScrollablePageHeader(
                        title = "收藏夹",
                        subtitle = "共 ${state.videos.size} 部",
                        trailing = if (onClearAll != null) {
                            {
                                TvHeaderActionButton(
                                    label = "删除全部",
                                    onClick = { showClearConfirm = true },
                                    onArrowDown = {
                                        runCatching { resolvedContentFocus.requestFocus() }
                                    },
                                )
                            }
                        } else {
                            null
                        },
                    )
                },
            )
        }
    }

    // 删除全部：公共 TvConfirmDialog；返回/取消即退出确认。
    if (showClearConfirm) {
        TvConfirmDialog(
            title = "清空收藏夹",
            message = "确定要清空全部收藏吗？此操作不可恢复。",
            confirmLabel = "清空",
            cancelLabel = "取消",
            confirmIsDanger = true,
            onConfirm = {
                showClearConfirm = false
                val clear = onClearAll ?: return@TvConfirmDialog
                scope.launch { clear() }
            },
            onDismiss = { showClearConfirm = false },
        )
    }
}

/**
 * 生成收藏卡片副标题。
 *
 * @return 年份、来源或收藏兜底文案。
 */
private fun TvVideoCard.favoriteSubtitle(): String {
    val parts = buildList {
        if (year.isNotBlank()) {
            add(year)
        }
        if (sourceName.isNotBlank()) {
            add(sourceName)
        }
    }
    return parts.joinToString(" · ").ifBlank { "收藏内容" }
}
