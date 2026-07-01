package org.moontechlab.selene.tv.feature.favorites

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
 * TV 收藏夹路由。
 *
 * @param state 收藏夹界面状态。
 * @param contentFocusRequester 内容区首张海报焦点请求器。
 * @param onVideoClick 视频卡片点击回调。
 */
@Composable
fun TvFavoritesRoute(
    state: TvFavoritesUiState = TvFavoritesUiState(),
    contentFocusRequester: FocusRequester? = null,
    onVideoClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "收藏夹",
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
                title = "收藏夹加载失败",
                message = state.errorMessage,
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            TvEmptyStatePanel(
                title = "收藏夹还没有内容",
                message = "收藏过的视频会在这里按网格展示，方便遥控器快速浏览。",
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
                        subtitle = video.favoriteSubtitle(),
                        posterUrl = video.posterUrl,
                        totalEpisodes = video.totalEpisodes,
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
