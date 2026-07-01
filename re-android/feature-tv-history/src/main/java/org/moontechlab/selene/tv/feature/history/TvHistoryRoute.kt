package org.moontechlab.selene.tv.feature.history

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.layout.TvEmptyStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterGridSkeleton
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind
import org.moontechlab.selene.tv.core.design.layout.toVideoDetailKey

/**
 * TV 播放历史路由。
 *
 * @param state 播放历史界面状态。
 * @param contentFocusRequester 内容区首张海报焦点请求器。
 * @param onVideoClick 视频卡片点击回调。
 */
@Composable
fun TvHistoryRoute(
    state: TvHistoryUiState = TvHistoryUiState(),
    contentFocusRequester: FocusRequester? = null,
    onVideoClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "播放历史",
        modifier = Modifier.fillMaxSize(),
    ) {
        val showSkeleton = state.isLoading && state.videos.isEmpty()
        if (showSkeleton) {
            TvPosterGridSkeleton(contentFocusRequester = contentFocusRequester)
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank() && state.videos.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "历史加载失败",
                message = state.errorMessage,
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            TvEmptyStatePanel(
                title = "历史列表为空",
                message = "这里会展示最近播放过的内容，方便从上次离开的地方继续。",
                contentFocusRequester = contentFocusRequester,
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
                columns = 7,
                firstItemFocusRequester = contentFocusRequester,
                onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
            )
        }
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
