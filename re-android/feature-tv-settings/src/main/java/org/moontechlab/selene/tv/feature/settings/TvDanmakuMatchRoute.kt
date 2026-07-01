package org.moontechlab.selene.tv.feature.settings

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvPageStatChipData
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail

/** 删除一个字符操作 ID。 */
private const val DANMAKU_ACTION_DELETE = "delete"

/** 清空搜索词操作 ID。 */
private const val DANMAKU_ACTION_CLEAR = "clear"

/** 恢复初始片名操作 ID。 */
private const val DANMAKU_ACTION_RESTORE = "restore"

/** 开始搜索操作 ID。 */
private const val DANMAKU_ACTION_SEARCH = "search"

/** 返回上一页操作 ID。 */
private const val DANMAKU_ACTION_BACK = "back"

/**
 * TV 弹幕手动匹配路由。
 *
 * @param state 弹幕匹配界面状态。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param onDeleteLastClick 删除末尾字符回调。
 * @param onClearClick 清空搜索词回调。
 * @param onRestoreClick 恢复初始搜索词回调。
 * @param onSearchClick 开始搜索回调。
 * @param onEpisodeSelected 剧集候选确认回调。
 * @param onBackClick 返回上一页回调。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvDanmakuMatchRoute(
    state: TvDanmakuMatchUiState,
    contentFocusRequester: FocusRequester? = null,
    onDeleteLastClick: () -> Unit = {},
    onClearClick: () -> Unit = {},
    onRestoreClick: () -> Unit = {},
    onSearchClick: () -> Unit = {},
    onEpisodeSelected: (TvDanmakuSearchAnime, TvDanmakuSearchEpisode, Int) -> Unit = { _, _, _ -> },
    onBackClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val displayQuery = state.query.ifBlank { "未带入片名" }
    TvPageScaffold(
        title = "手动匹配弹幕",
        subtitle = "默认带入当前片名，遥控器可删字微调搜索词。",
        stats = listOf(
            TvPageStatChipData("搜索词", displayQuery),
            TvPageStatChipData("结果", if (state.results.isEmpty()) "未搜索" else "${state.results.size} 个候选"),
        ),
        modifier = modifier,
    ) {
        TvPageSection(
            title = "搜索词",
            hint = if (state.query.isBlank()) "从播放器进入时会自动带入片名" else "确认搜索前可先删减关键词",
            insetContent = false,
        ) {
            TvPosterRail(
                firstItemFocusRequester = contentFocusRequester,
                items = listOf(
                    TvPosterItem(
                        id = "query",
                        title = displayQuery,
                        subtitle = "当前弹幕匹配关键词",
                    ),
                ),
            )
        }

        TvPageSection(
            title = "遥控器操作",
            hint = "先微调片名，再进入弹幕搜索流程",
            insetContent = false,
        ) {
            TvPosterRail(
                items = danmakuMatchActions(state = state),
                onItemClick = { item ->
                    when (item.id) {
                        DANMAKU_ACTION_DELETE -> onDeleteLastClick()
                        DANMAKU_ACTION_CLEAR -> onClearClick()
                        DANMAKU_ACTION_RESTORE -> onRestoreClick()
                        DANMAKU_ACTION_SEARCH -> onSearchClick()
                        DANMAKU_ACTION_BACK -> onBackClick()
                    }
                },
            )
        }

        TvPageSection(
            title = "搜索结果",
            hint = state.errorMessage ?: if (state.isLoading) "正在搜索弹幕剧集" else "选择正确剧集完成手动匹配",
            insetContent = false,
        ) {
            val resultItems = state.results.flatMap { anime ->
                anime.episodes.mapIndexed { episodeIndex, episode ->
                    TvPosterItem(
                        id = "${anime.animeId}:${episode.episodeId}",
                        title = episode.episodeTitle,
                        subtitle = danmakuEpisodeSubtitle(anime),
                    )
                }
            }
            TvPosterRail(
                items = resultItems.ifEmpty {
                    listOf(
                        TvPosterItem(
                            id = "empty-result",
                            title = if (state.isLoading) "搜索中" else "暂无候选",
                            subtitle = state.errorMessage ?: "点击开始搜索后显示候选剧集",
                        ),
                    )
                },
                onItemClick = { item ->
                    state.results.forEach { anime ->
                        anime.episodes.forEachIndexed { episodeIndex, episode ->
                            if (item.id == "${anime.animeId}:${episode.episodeId}") {
                                // 候选确认只回传业务选择，保存和加载弹幕由宿主决定。
                                onEpisodeSelected(anime, episode, episodeIndex)
                            }
                        }
                    }
                },
            )
        }
    }
}

/**
 * 构建弹幕匹配操作卡片。
 *
 * @param query 当前搜索词。
 * @param initialQuery 初始搜索词。
 * @return 可直接渲染的操作卡片。
 */
private fun danmakuMatchActions(state: TvDanmakuMatchUiState): List<TvPosterItem> {
    return listOf(
        TvPosterItem(
            id = DANMAKU_ACTION_DELETE,
            title = "删一字",
            subtitle = if (state.query.isBlank()) "当前没有可删除字符" else "删除搜索词最后一个字",
        ),
        TvPosterItem(
            id = DANMAKU_ACTION_CLEAR,
            title = "清空",
            subtitle = "清空当前搜索词",
        ),
        TvPosterItem(
            id = DANMAKU_ACTION_RESTORE,
            title = "恢复片名",
            subtitle = state.initialQuery.ifBlank { "暂无片名可恢复" },
        ),
        TvPosterItem(
            id = DANMAKU_ACTION_SEARCH,
            title = "开始搜索",
            subtitle = if (state.isLoading) "正在请求弹幕服务" else "按当前关键词查询弹幕剧集",
        ),
        TvPosterItem(
            id = DANMAKU_ACTION_BACK,
            title = "返回",
            subtitle = "回到上一页",
        ),
    )
}

/**
 * 生成弹幕候选副标题。
 *
 * @param anime 动画候选。
 * @return 包含类型和年份的副标题。
 */
private fun danmakuEpisodeSubtitle(anime: TvDanmakuSearchAnime): String {
    val typeText = anime.typeDescription.ifBlank { anime.type }
    val yearText = if (anime.year > 0) anime.year.toString() else "未知年份"
    return "${anime.animeTitle} · $typeText · $yearText"
}
