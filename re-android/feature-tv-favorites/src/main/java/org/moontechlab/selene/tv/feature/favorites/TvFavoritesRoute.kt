package org.moontechlab.selene.tv.feature.favorites

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.moontechlab.selene.tv.core.design.layout.TvEmptyStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageStatChipData
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * TV 收藏夹路由。
 *
 * @param state 收藏夹界面状态。
 * @param onVideoClick 视频卡片点击回调。
 */
@Composable
fun TvFavoritesRoute(
    state: TvFavoritesUiState = TvFavoritesUiState(),
    onVideoClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "收藏夹",
        subtitle = "收藏内容 / 快速进入详情 / 遥控器网格",
        stats = listOf(
            TvPageStatChipData("数量", state.videos.size.toString()),
        ),
        modifier = Modifier.fillMaxSize(),
    ) {
        if (state.isLoading) {
            TvStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "收藏夹加载中",
                message = "正在读取收藏内容。",
            )
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "收藏夹加载失败",
                message = state.errorMessage,
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            TvEmptyStatePanel(
                title = "收藏夹还没有内容",
                message = "收藏过的视频会在这里按网格展示，方便遥控器快速浏览。",
            )
        } else {
            TvPosterGrid(
                items = state.videos.map { video ->
                    TvPosterItem(
                        id = video.id,
                        title = video.title,
                        subtitle = "收藏内容",
                        posterUrl = video.posterUrl,
                    )
                },
                columns = 5,
                onItemClick = { item -> onVideoClick(item.id) },
            )
        }
    }
}
