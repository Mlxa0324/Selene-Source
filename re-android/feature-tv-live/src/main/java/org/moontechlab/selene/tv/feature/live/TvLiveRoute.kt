package org.moontechlab.selene.tv.feature.live

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import org.moontechlab.selene.tv.core.design.layout.TvEmptyStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvPageStatChipData
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail

/**
 * TV 直播频道模型。
 *
 * @property id 频道 ID。
 * @property name 频道名称。
 * @property group 频道分组。
 * @property currentProgram 当前节目名称。
 */
data class TvLiveChannel(
    val id: String,
    val name: String,
    val group: String,
    val currentProgram: String,
)

/**
 * TV 直播节目模型。
 *
 * @property id 节目 ID。
 * @property title 节目标题。
 * @property timeRange 节目时间段。
 */
data class TvLiveProgram(
    val id: String,
    val title: String,
    val timeRange: String,
)

/**
 * TV 直播界面状态。
 *
 * @property sourceName 当前直播源名称。
 * @property channels 频道列表。
 * @property programs 当前频道节目单。
 * @property selectedChannelId 当前选中频道 ID。
 */
data class TvLiveUiState(
    val sourceName: String = "默认直播源",
    val channels: List<TvLiveChannel> = emptyList(),
    val programs: List<TvLiveProgram> = emptyList(),
    val selectedChannelId: String? = null,
)

/**
 * TV 直播路由。
 *
 * @param state 直播界面状态。
 * @param onChannelClick 频道点击回调。
 */
@Composable
fun TvLiveRoute(
    state: TvLiveUiState = TvLiveUiState(),
    onChannelClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "直播",
        subtitle = "频道列表 / 当前节目 / 节目单",
        stats = listOf(
            TvPageStatChipData("直播源", state.sourceName),
            TvPageStatChipData("频道", state.channels.size.toString()),
            TvPageStatChipData("节目", state.programs.size.toString()),
        ),
        modifier = Modifier.fillMaxSize(),
    ) {
        TvPageSection(
            title = "频道列表",
            hint = state.sourceName,
        ) {
            if (state.channels.isEmpty()) {
                TvEmptyStatePanel(
                    title = "暂无直播频道",
                    message = "导入直播源即可在此浏览频道、当前节目和节目单。",
                )
            } else {
                TvPosterGrid(
                    items = state.channels.map { channel ->
                        TvPosterItem(
                            id = channel.id,
                            title = channel.name,
                            subtitle = "${channel.group} · ${channel.currentProgram}",
                        )
                    },
                    columns = 5,
                    onItemClick = { item -> onChannelClick(item.id) },
                )
            }
        }

        TvPageSection(
            title = "当前节目",
            hint = selectedChannelTitle(state),
        ) {
            if (state.programs.isEmpty()) {
                TvEmptyStatePanel(
                    title = "暂无节目单",
                    message = "当前直播源未提供节目时间表，可直接从频道列表进入播放。",
                )
            } else {
                TvPosterRail(
                    items = state.programs.map { program ->
                        TvPosterItem(
                            id = program.id,
                            title = program.title,
                            subtitle = program.timeRange,
                        )
                    },
                )
            }
        }
    }
}

/**
 * 获取当前选中频道名称。
 *
 * @param state 直播界面状态。
 * @return 频道名称或默认提示。
 */
internal fun selectedChannelTitle(state: TvLiveUiState): String {
    return state.channels
        .firstOrNull { channel -> channel.id == state.selectedChannelId }
        ?.name
        ?: "未选择频道"
}
