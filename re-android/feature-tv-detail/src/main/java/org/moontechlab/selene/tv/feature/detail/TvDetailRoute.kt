package org.moontechlab.selene.tv.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * TV 详情页路由。
 *
 * @param state 详情页界面状态。
 * @param onSourceSelected 播放线路选择回调。
 * @param onEpisodeSelected 剧集选择回调。
 * @param onPlayPressed 播放入口回调。
 */
@Composable
fun TvDetailRoute(
    state: TvDetailUiState = TvDetailUiState(),
    onSourceSelected: ((String) -> Unit)? = null,
    onEpisodeSelected: ((String) -> Unit)? = null,
    onPlayPressed: (() -> Unit)? = null,
) {
    TvPageScaffold(
        title = state.detail?.title ?: "详情",
    ) {
        when {
            state.isLoading -> {
                TvStatePanel(
                    kind = TvStatePanelKind.Loading,
                    title = "详情加载中",
                    message = "正在获取首个可播源。",
                )
                return@TvPageScaffold
            }
            !state.errorMessage.isNullOrBlank() -> {
                TvStatePanel(
                    kind = TvStatePanelKind.Error,
                    title = "详情加载失败",
                    message = state.errorMessage,
                    actionLabel = "重试",
                )
                return@TvPageScaffold
            }
            state.detail == null -> {
                TvStatePanel(
                    kind = TvStatePanelKind.Empty,
                    title = "暂无详情",
                    message = "当前视频没有可展示的详情信息。",
                )
                return@TvPageScaffold
            }
        }

        TvPageSection(
            title = "播放预览",
            hint = state.currentSource?.name ?: "等待播放地址",
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TvPlaybackPreview(
                    title = state.currentEpisode?.title ?: state.detail.title,
                    sourceName = state.currentSource?.name.orEmpty(),
                    onPlayPressed = onPlayPressed,
                )
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = state.detail.description.ifBlank { "暂无简介" },
                        maxLines = 4,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    val sourceSummary = if (state.isLoadingMoreSources) {
                        "正在补充更多播放线路"
                    } else {
                        "共 ${state.detail.sources.size} 条线路"
                    }
                    Text(
                        text = sourceSummary,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        TvSourceSection(
            sources = state.detail.sources,
            selectedSourceId = state.currentSourceId,
            onSourceSelected = onSourceSelected,
        )

        TvEpisodeSection(
            episodes = state.currentSource?.episodes.orEmpty(),
            selectedEpisodeId = state.currentEpisodeId,
            onEpisodeSelected = onEpisodeSelected,
        )

        if (state.recommendCards.isNotEmpty()) {
            TvPageSection(
                title = "相关推荐",
                hint = "${state.recommendCards.size} 条推荐",
            ) {
                TvPosterRail(
                    items = state.recommendCards.map { card ->
                        TvPosterItem(
                            id = card.id,
                            title = card.title,
                            subtitle = "推荐",
                            posterUrl = card.posterUrl,
                        )
                    },
                )
            }
        }
    }
}

/**
 * TV 详情页播放预览区。
 *
 * @param title 当前剧集标题。
 * @param sourceName 当前线路名称。
 * @param onPlayPressed 播放入口回调。
 */
@Composable
private fun TvPlaybackPreview(
    title: String,
    sourceName: String,
    onPlayPressed: (() -> Unit)?,
) {
    TvFocusableCard(
        modifier = Modifier
            .width(420.dp)
            .height(236.dp),
        onPressed = onPlayPressed,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(236.dp)
                .background(
                    color = TvTokens.SurfaceElevated,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(22.dp),
            contentAlignment = Alignment.BottomStart,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = title,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = sourceName.ifBlank { "选择线路后播放" },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

/**
 * TV 详情页线路区。
 *
 * @param sources 播放线路列表。
 * @param selectedSourceId 当前线路 ID。
 * @param onSourceSelected 线路选择回调。
 */
@Composable
private fun TvSourceSection(
    sources: List<TvVideoSource>,
    selectedSourceId: String,
    onSourceSelected: ((String) -> Unit)?,
) {
    TvPageSection(
        title = "播放线路",
        hint = if (sources.isEmpty()) "暂无线路" else "遇到卡顿可切换线路",
    ) {
        if (sources.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无播放线路",
                message = "当前详情未返回可播放来源。",
            )
            return@TvPageSection
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(end = TvTokens.PageHorizontalPadding),
        ) {
            items(sources, key = TvVideoSource::id) { source ->
                TvDetailOptionChip(
                    label = source.name,
                    trailing = "${source.episodes.size}",
                    selected = source.id == selectedSourceId,
                    onPressed = { onSourceSelected?.invoke(source.id) },
                )
            }
        }
    }
}

/**
 * TV 详情页选集区。
 *
 * @param episodes 当前线路剧集。
 * @param selectedEpisodeId 当前剧集 ID。
 * @param onEpisodeSelected 剧集选择回调。
 */
@Composable
private fun TvEpisodeSection(
    episodes: List<TvEpisode>,
    selectedEpisodeId: String,
    onEpisodeSelected: ((String) -> Unit)?,
) {
    TvPageSection(
        title = "选集",
        hint = if (episodes.isEmpty()) "暂无剧集" else "共 ${episodes.size} 集",
    ) {
        if (episodes.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无剧集",
                message = "当前线路没有可播放剧集。",
            )
            return@TvPageSection
        }
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(end = TvTokens.PageHorizontalPadding),
        ) {
            items(episodes, key = TvEpisode::id) { episode ->
                TvDetailOptionChip(
                    label = episode.title,
                    selected = episode.id == selectedEpisodeId,
                    onPressed = { onEpisodeSelected?.invoke(episode.id) },
                )
            }
        }
    }
}

/**
 * TV 详情页通用横向选项。
 *
 * @param label 主文案。
 * @param trailing 右侧辅助文案。
 * @param selected 是否选中。
 * @param onPressed 确认回调。
 */
@Composable
private fun TvDetailOptionChip(
    label: String,
    trailing: String? = null,
    selected: Boolean,
    onPressed: () -> Unit,
) {
    val background = if (selected) {
        TvTokens.Accent
    } else {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
    }
    TvFocusableCard(
        modifier = Modifier.widthIn(min = 96.dp),
        onPressed = onPressed,
    ) {
        Row(
            modifier = Modifier
                .background(
                    color = background,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(horizontal = 16.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                color = if (selected) TvTokens.TextPrimary else MaterialTheme.colorScheme.onSurface,
            )
            if (!trailing.isNullOrBlank()) {
                Text(
                    text = trailing,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
