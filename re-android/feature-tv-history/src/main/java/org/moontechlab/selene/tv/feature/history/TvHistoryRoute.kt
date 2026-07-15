package org.moontechlab.selene.tv.feature.history

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
 * TV 播放历史路由。
 *
 * 页头紧凑、随网格滚动（对齐电影 Tab）；右侧「删除全部」需二次确认。
 *
 * @param state 播放历史界面状态。
 * @param contentFocusRequester 内容区首张海报焦点请求器。
 * @param onVideoClick 视频卡片点击回调。
 * @param onClearAll 清空全部历史回调。
 */
@Composable
fun TvHistoryRoute(
    state: TvHistoryUiState = TvHistoryUiState(),
    contentFocusRequester: FocusRequester? = null,
    onVideoClick: (String) -> Unit = {},
    onClearAll: (suspend () -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    var showClearConfirm by remember { mutableStateOf(false) }
    val firstItemFocusRequester = remember { FocusRequester() }
    val resolvedContentFocus = contentFocusRequester ?: firstItemFocusRequester

    // 无固定大标题：与电影库一致，标题放进网格 header 随内容滚。
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
                title = "历史加载失败",
                message = state.errorMessage,
                contentFocusRequester = resolvedContentFocus,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            // 空态仍给紧凑标题行，但不展示删除按钮。
            TvScrollablePageHeader(
                title = "播放历史",
                subtitle = "最近播放",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            TvEmptyStatePanel(
                title = "历史列表为空",
                message = "这里会展示最近播放过的内容，方便从上次离开的地方继续。",
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
                        subtitle = video.sourceName.ifBlank { "继续观看" },
                        posterUrl = video.posterUrl,
                        totalEpisodes = video.totalEpisodes,
                        episodeIndex = video.episodeIndex,
                        progressFraction = video.playbackProgressFraction(),
                    )
                },
                columns = TvListLayoutMetrics.PosterColumns,
                firstItemFocusRequester = resolvedContentFocus,
                onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                headerContent = {
                    TvScrollablePageHeader(
                        title = "播放历史",
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
            title = "清空播放历史",
            message = "确定要清空全部播放记录吗？此操作不可恢复。",
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
 * 计算播放历史卡片进度。
 *
 * @return 0..1 之间的进度比例。
 */
private fun TvVideoCard.playbackProgressFraction(): Float {
    if (playTime <= 0 || totalTime <= 0) {
        return 0f
    }
    return playTime.toFloat() / totalTime.toFloat()
}
