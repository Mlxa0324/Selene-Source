package org.moontechlab.selene.tv.feature.search

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
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * TV 搜索路由。
 *
 * @param state 搜索界面状态。
 * @param onQuerySelected 搜索词确认回调。
 * @param onVideoClick 视频卡片点击回调。
 */
@Composable
fun TvSearchRoute(
    state: TvSearchUiState = TvSearchUiState(),
    onQuerySelected: (String) -> Unit = {},
    onVideoClick: (String) -> Unit = {},
) {
    TvPageScaffold(
        title = "搜索",
        subtitle = state.query.ifBlank { "遥控器输入 / 历史 / 热词 / 结果" },
        stats = listOf(
            TvPageStatChipData("历史", state.searchHistory.size.toString()),
            TvPageStatChipData("结果", state.resultGroups.sumOf { it.videos.size }.toString()),
        ),
        modifier = Modifier.fillMaxSize(),
    ) {
        TvPageSection(
            title = "搜索入口",
            hint = if (state.isLoading) "正在搜索 ${state.query}" else "确认词条可发起搜索",
        ) {
            TvPosterRail(
                items = listOf(
                    TvPosterItem(
                        id = "query-preview",
                        title = state.query.ifBlank { "输入关键词" },
                        subtitle = if (state.query.isBlank()) "遥控器键盘" else "当前搜索词",
                    ),
                    TvPosterItem(
                        id = "clear-query",
                        title = "清空",
                        subtitle = "重置搜索词",
                    ),
                ),
                onItemClick = { item ->
                    // 入口词条只把明确查询交给外层，避免清空按钮误触发搜索。
                    if (item.id == "query-preview" && state.query.isNotBlank()) {
                        onQuerySelected(state.query)
                    }
                },
            )
        }

        TvPageSection(
            title = "搜索历史",
            hint = state.searchHistory.joinToString(" / ").ifBlank { "暂无历史" },
        ) {
            if (state.searchHistory.isEmpty()) {
                TvEmptyStatePanel(
                    title = "暂无搜索历史",
                    message = "确认搜索词会保留在这里，方便下次用遥控器快速选择。",
                )
            } else {
                TvPosterRail(
                    items = state.searchHistory.mapIndexed { index, query ->
                        TvPosterItem(
                            id = "history-$index",
                            title = query,
                            subtitle = "历史",
                        )
                    },
                    onItemClick = { item -> onQuerySelected(item.title) },
                )
            }
        }

        TvPageSection(
            title = "搜索热词",
            hint = "${state.hotQueries.size} 个推荐词",
        ) {
            if (state.hotQueries.isEmpty()) {
                TvEmptyStatePanel(
                    title = "暂无热词",
                    message = "服务器未返回热词时，可直接使用上方搜索入口输入关键词。",
                )
            } else {
                TvPosterRail(
                    items = state.hotQueries.mapIndexed { index, query ->
                        TvPosterItem(
                            id = "hot-$index",
                            title = query,
                            subtitle = "热词",
                        )
                    },
                    onItemClick = { item -> onQuerySelected(item.title) },
                )
            }
        }

        if (state.resultGroups.isEmpty()) {
            TvPageSection(
                title = "搜索结果",
                hint = state.errorMessage ?: "确认关键词开始搜索",
            ) {
                if (!state.errorMessage.isNullOrBlank()) {
                    TvStatePanel(
                        kind = TvStatePanelKind.Error,
                        title = "搜索失败",
                        message = state.errorMessage,
                    )
                } else {
                    TvEmptyStatePanel(
                        title = "暂无搜索结果",
                        message = "选择历史或热词，也可以在搜索入口输入片名。",
                    )
                }
            }
        } else {
            state.resultGroups.forEach { group ->
                TvPageSection(
                    title = group.title,
                    hint = "${group.videos.size} 条结果",
                ) {
                    TvPosterGrid(
                        items = group.videos.map { video ->
                            TvPosterItem(
                                id = video.id,
                                title = video.title,
                                subtitle = "结果",
                                posterUrl = video.posterUrl,
                            )
                        },
                        columns = 5,
                        onItemClick = { item -> onVideoClick(item.id) },
                    )
                }
            }
        }
    }
}
