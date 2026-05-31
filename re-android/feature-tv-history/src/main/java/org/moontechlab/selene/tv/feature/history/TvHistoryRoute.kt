package org.moontechlab.selene.tv.feature.history

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
 * TV 播放历史路由。
 *
 * @param state 播放历史界面状态。
 * @param onVideoClick 视频卡片点击回调。
 */
@Composable
fun TvHistoryRoute(
    state: TvHistoryUiState = TvHistoryUiState(),
    onVideoClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "播放历史",
        subtitle = "继续观看 / 最近播放 / 遥控器网格",
        stats = listOf(
            TvPageStatChipData("数量", state.videos.size.toString()),
        ),
        modifier = Modifier.fillMaxSize(),
    ) {
        if (state.isLoading) {
            TvStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "历史加载中",
                message = "正在读取最近播放记录。",
            )
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "历史加载失败",
                message = state.errorMessage,
            )
            return@TvPageScaffold
        }

        if (state.videos.isEmpty()) {
            TvEmptyStatePanel(
                title = "历史列表为空",
                message = "这里会展示最近播放过的内容，方便从上次离开的地方继续。",
            )
        } else {
            TvPosterGrid(
                items = state.videos.map { video ->
                    TvPosterItem(
                        id = video.id,
                        title = video.title,
                        subtitle = "继续观看",
                        posterUrl = video.posterUrl,
                    )
                },
                columns = 5,
                onItemClick = { item -> onVideoClick(item.id) },
            )
        }
    }
}
