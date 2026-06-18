package org.moontechlab.selene.tv.feature.detail

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * TV 详情页 Route。
 *
 * @param state 详情页状态。
 * @param onSourceSelected 线路选择回调。
 * @param onEpisodeSelected 剧集选择回调。
 * @param onPlayPressed 全屏播放回调。
 * @param onFavoriteToggle 收藏切换回调。
 * @param onResumeFromRecord 续播确认回调。
 * @param onDismissResume 续播忽略回调。
 * @param onEpisodeGroupSelected 选集分组选择回调。
 * @param onHistoryClick 历史入口回调。
 * @param onExitClick 退出详情回调。
 * @param onSearchClick 搜索入口回调。
 * @param playerSurface 预览播放器内容。
 */
@Composable
fun TvDetailRoute(
    state: TvDetailUiState = TvDetailUiState(),
    onSourceSelected: ((String) -> Unit)? = null,
    onEpisodeSelected: ((String) -> Unit)? = null,
    onPlayPressed: (() -> Unit)? = null,
    onFavoriteToggle: (() -> Unit)? = null,
    onResumeFromRecord: (() -> Unit)? = null,
    onDismissResume: (() -> Unit)? = null,
    onEpisodeGroupSelected: ((Int) -> Unit)? = null,
    onHistoryClick: (() -> Unit)? = null,
    onExitClick: (() -> Unit)? = null,
    onSearchClick: (() -> Unit)? = null,
    playerSurface: (@Composable () -> Unit)? = null,
) {
    val detail = state.detail
    val focusTargets = rememberDetailFocusTargets(
        sourceCount = detail?.sources.orEmpty().size,
        episodeCount = state.currentSource?.episodes.orEmpty().size,
        episodeGroupCount = state.episodeGroups.size,
        recommendCount = state.recommendCards.size,
    )
    val sourceOptions = remember(detail?.sources, state.currentSourceId) {
        buildDetailSourceOptions(
            sources = detail?.sources.orEmpty(),
            currentSourceId = state.currentSourceId,
            pinCurrentSource = true,
        )
    }
    val episodeGroups = remember(state.currentSource?.episodes, state.currentEpisodeId, state.selectedEpisodeGroup) {
        buildDetailEpisodeGroups(
            episodes = state.currentSource?.episodes.orEmpty(),
            selectedEpisodeId = state.currentEpisodeId,
            selectedGroupIndex = state.selectedEpisodeGroup,
        )
    }
    val selectedGroup = episodeGroups.getOrNull(
        state.selectedEpisodeGroup.coerceIn(0, (episodeGroups.size - 1).coerceAtLeast(0)),
    )
    val currentSourceFocusRequester = sourceOptions
        .indexOfFirst { option -> option.selected }
        .takeIf { index -> index >= 0 }
        ?.let { index -> focusTargets.sources.getOrNull(index) }
    val currentEpisodeFocusRequester = selectedGroup
        ?.episodes
        ?.firstOrNull { episode -> episode.selected }
        ?.episodeIndex
        ?.let { index -> focusTargets.episodes.getOrNull(index) }
    val layoutSections = remember(detail?.sources, state.currentSource?.episodes, state.recommendCards) {
        buildDetailLayoutSections(
            sources = detail?.sources.orEmpty(),
            episodes = state.currentSource?.episodes.orEmpty(),
            recommends = state.recommendCards,
        )
    }
    val sourceListState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
    val episodeListState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
    val episodeGroupListState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }

    TvPageScaffold(title = null) {
        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "详情加载失败",
                message = state.errorMessage,
                actionLabel = "重试",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
                contentFocusRequester = focusTargets.player,
            )
            return@TvPageScaffold
        }

        if (detail == null) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无详情",
                message = "当前视频没有可展示的详情信息。",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
                contentFocusRequester = focusTargets.player,
            )
            return@TvPageScaffold
        }

        TvDetailTopBar(
            focusTargets = focusTargets,
            onSearchClick = onSearchClick,
        )

        if (state.showResumePrompt) {
            TvResumePrompt(
                state = state,
                onResumeFromRecord = onResumeFromRecord,
                onDismissResume = onDismissResume,
            )
        }

        TvDetailHeroSection(
            state = state,
            focusTargets = focusTargets,
            currentSourceFocusRequester = currentSourceFocusRequester,
            onPlayPressed = onPlayPressed,
            onFavoriteToggle = onFavoriteToggle,
            playerSurface = playerSurface,
        )

        TvDetailSourceSection(
            sourceOptions = sourceOptions,
            isSearching = state.isMoreSourcesLoading,
            emptyPlaybackCompleted = state.emptyPlaybackCompleted,
            focusTargets = focusTargets,
            currentEpisodeFocusRequester = currentEpisodeFocusRequester,
            listState = sourceListState,
            onSourceSelected = onSourceSelected,
        )

        TvDetailEpisodeSection(
            groups = episodeGroups,
            selectedGroup = selectedGroup,
            focusTargets = focusTargets,
            currentSourceFocusRequester = currentSourceFocusRequester,
            currentEpisodeFocusRequester = currentEpisodeFocusRequester,
            hasRecommends = layoutSections.showRecommends,
            episodeListState = episodeListState,
            episodeGroupListState = episodeGroupListState,
            onEpisodeSelected = onEpisodeSelected,
            onGroupSelected = onEpisodeGroupSelected,
        )

        if (layoutSections.showRecommends) {
            TvDetailRecommendSection(
                cards = state.recommendCards,
                focusTargets = focusTargets,
            )
        }

        if (layoutSections.showBottomActions) {
            TvDetailBottomActions(
                focusTargets = focusTargets,
                onHistoryClick = onHistoryClick,
                onExitClick = onExitClick,
            )
        }
    }
}

/**
 * TV 详情页焦点请求器集合。
 *
 * @property search 顶部搜索焦点。
 * @property player 预览播放器焦点。
 * @property fullscreen 全屏按钮焦点。
 * @property favorite 收藏按钮焦点。
 * @property sources 线路焦点列表。
 * @property episodes 选集焦点列表。
 * @property episodeGroups 分组焦点列表。
 * @property recommends 推荐焦点列表。
 * @property bottomAction 底部操作焦点。
 */
private data class TvDetailFocusTargets(
    val search: FocusRequester,
    val player: FocusRequester,
    val fullscreen: FocusRequester,
    val favorite: FocusRequester,
    val sources: List<FocusRequester>,
    val episodes: List<FocusRequester>,
    val episodeGroups: List<FocusRequester>,
    val recommends: List<FocusRequester>,
    val bottomAction: FocusRequester,
)

/**
 * 创建详情页焦点请求器。
 */
@Composable
private fun rememberDetailFocusTargets(
    sourceCount: Int,
    episodeCount: Int,
    episodeGroupCount: Int,
    recommendCount: Int,
): TvDetailFocusTargets {
    val player = remember { FocusRequester() }
    val targets = TvDetailFocusTargets(
        search = remember { FocusRequester() },
        player = player,
        fullscreen = remember { FocusRequester() },
        favorite = remember { FocusRequester() },
        sources = remember(sourceCount) { List(sourceCount) { FocusRequester() } },
        episodes = remember(episodeCount) { List(episodeCount) { FocusRequester() } },
        episodeGroups = remember(episodeGroupCount) { List(episodeGroupCount) { FocusRequester() } },
        recommends = remember(recommendCount) { List(recommendCount) { FocusRequester() } },
        bottomAction = remember { FocusRequester() },
    )
    LaunchedEffect(player) {
        // 详情首屏默认落到播放器，和 Flutter TV 保持一致。
        runCatching { player.requestFocus() }
    }
    return targets
}

/**
 * 顶部栏。
 */
@Composable
private fun TvDetailTopBar(
    focusTargets: TvDetailFocusTargets,
    onSearchClick: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = TvTokens.PageHorizontalPadding, vertical = 22.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "IvyTV",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.ExtraBold,
                color = TvTokens.TextPrimary,
            )
            Text(
                text = "详情",
                style = MaterialTheme.typography.bodyMedium,
                color = TvTokens.TextSecondary,
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TvDetailActionPill(
                label = "搜索",
                accent = false,
                focusRequester = focusTargets.search,
                modifier = Modifier.focusProperties {
                    down = focusTargets.player
                    left = focusTargets.search
                    right = focusTargets.search
                },
                onClick = { onSearchClick?.invoke() },
            )
            Text(
                text = "现在",
                style = MaterialTheme.typography.bodyMedium,
                color = TvTokens.TextSecondary,
            )
        }
    }
}

/**
 * 续播提示。
 */
@Composable
private fun TvResumePrompt(
    state: TvDetailUiState,
    onResumeFromRecord: (() -> Unit)?,
    onDismissResume: (() -> Unit)?,
) {
    TvPageSection(title = "续播提示") {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "上次播放到第 ${state.resumeEpisodeIndex + 1} 集，是否继续？",
                style = MaterialTheme.typography.bodyLarge,
                color = TvTokens.TextPrimary,
                modifier = Modifier.weight(1f),
            )
            TvDetailActionPill(label = "继续", accent = true, onClick = { onResumeFromRecord?.invoke() })
            TvDetailActionPill(label = "忽略", accent = false, onClick = { onDismissResume?.invoke() })
        }
    }
}

/**
 * Hero 区域。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TvDetailHeroSection(
    state: TvDetailUiState,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    onPlayPressed: (() -> Unit)?,
    onFavoriteToggle: (() -> Unit)?,
    playerSurface: (@Composable () -> Unit)?,
) {
    val detail = state.detail ?: return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = TvTokens.PageHorizontalPadding),
        horizontalArrangement = Arrangement.spacedBy(34.dp),
        verticalAlignment = Alignment.Top,
    ) {
        TvDetailPreviewPlayer(
            episodeTitle = state.currentEpisode?.title ?: detail.title,
            sourceName = state.currentSource?.name.orEmpty(),
            posterUrl = detail.posterUrl,
            focusTargets = focusTargets,
            currentSourceFocusRequester = currentSourceFocusRequester,
            onPlayPressed = onPlayPressed,
            playerSurface = playerSurface,
            previewIsLoading = state.previewIsLoading,
            previewNetworkSpeed = state.previewNetworkSpeed,
            previewIsPlaying = state.previewIsPlaying,
            previewPositionMs = state.previewPositionMs,
            previewDurationMs = state.previewDurationMs,
            previewPlaybackStarted = state.previewPlaybackStarted,
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = detail.title,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                fontSize = 30.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White,
            )
            val metaParts = buildList {
                if (detail.year.isNotBlank()) add(detail.year)
                if (detail.sourceName.isNotBlank()) add(detail.sourceName)
                val episodeCount = state.currentSource?.episodes.orEmpty().size
                if (episodeCount > 0) add("共 $episodeCount 集")
            }
            if (metaParts.isNotEmpty()) {
                Text(
                    text = metaParts.joinToString(" · "),
                    fontSize = 15.sp,
                    color = TvTokens.FormTextSecondary,
                )
            }
            Text(
                text = detail.description.ifBlank { "暂无简介" },
                maxLines = 6,
                overflow = TextOverflow.Ellipsis,
                fontSize = 16.sp,
                lineHeight = 23.sp,
                color = TvTokens.TextSecondary,
            )
            Text(
                text = if (state.isMoreSourcesLoading) {
                    "正在补充更多播放线路"
                } else {
                    "共 ${detail.sources.size} 条线路"
                },
                fontSize = 15.sp,
                color = TvTokens.FormTextSecondary,
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TvDetailActionPill(
                    label = "全屏",
                    accent = false,
                    focusRequester = focusTargets.fullscreen,
                    modifier = Modifier.focusProperties {
                        up = focusTargets.search
                        left = focusTargets.player
                        right = focusTargets.favorite
                        down = currentSourceFocusRequester ?: FocusRequester.Default
                    },
                    onClick = { onPlayPressed?.invoke() },
                )
                TvDetailActionPill(
                    label = if (state.isFavorite) "已收藏" else "收藏",
                    accent = state.isFavorite,
                    focusRequester = focusTargets.favorite,
                    modifier = Modifier.focusProperties {
                        up = focusTargets.search
                        left = focusTargets.fullscreen
                        right = focusTargets.favorite
                        down = currentSourceFocusRequester ?: FocusRequester.Default
                    },
                    onClick = { onFavoriteToggle?.invoke() },
                )
            }
        }
    }
}

/**
 * 预览播放器。
 */
@Composable
private fun TvDetailPreviewPlayer(
    episodeTitle: String,
    sourceName: String,
    posterUrl: String,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    onPlayPressed: (() -> Unit)?,
    playerSurface: (@Composable () -> Unit)?,
    previewIsLoading: Boolean,
    previewNetworkSpeed: Long,
    previewIsPlaying: Boolean,
    previewPositionMs: Long,
    previewDurationMs: Long,
    previewPlaybackStarted: Boolean,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    Box(
        modifier = Modifier
            .width(620.dp)
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(10.dp))
            .border(2.dp, if (isFocused) Color.White else Color.Transparent, RoundedCornerShape(10.dp))
            .focusRequester(focusTargets.player)
            .focusProperties {
                up = focusTargets.search
                right = focusTargets.fullscreen
                down = currentSourceFocusRequester ?: FocusRequester.Default
            }
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) {
                    onPlayPressed?.invoke()
                    true
                } else {
                    false
                }
            },
    ) {
        if (playerSurface != null && previewPlaybackStarted) {
            playerSurface()
        } else if (posterUrl.isNotBlank()) {
            AsyncImage(
                model = posterUrl,
                contentDescription = episodeTitle,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(Modifier.fillMaxSize().background(Color.Black))
        }
        if (playerSurface == null || !previewPlaybackStarted) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.72f)))),
            )
            Column(
                modifier = Modifier.align(Alignment.BottomStart).padding(22.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = episodeTitle,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Text(
                    text = sourceName.ifBlank { "选择线路后播放" },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    fontSize = 16.sp,
                    color = Color.White.copy(alpha = 0.78f),
                )
            }
        }
        if (previewIsLoading) {
            TvDetailPreviewLoadingOverlay(previewNetworkSpeed)
        }
        if (previewPlaybackStarted && previewDurationMs > 0) {
            TvDetailPreviewProgressBar(
                isPlaying = previewIsPlaying,
                positionMs = previewPositionMs,
                durationMs = previewDurationMs,
            )
        }
    }
}

/**
 * 预览播放器加载层。
 */
@Composable
private fun TvDetailPreviewLoadingOverlay(previewNetworkSpeed: Long) {
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(
                color = TvTokens.Accent,
                modifier = Modifier.size(36.dp),
                strokeWidth = 3.dp,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = if (previewNetworkSpeed > 0) formatSpeed(previewNetworkSpeed) else "加载中",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.94f),
            )
        }
    }
}

/**
 * 预览播放器进度条。
 */
@Composable
private fun BoxScope.TvDetailPreviewProgressBar(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
) {
    val progress = (positionMs.toFloat() / durationMs).coerceIn(0f, 1f)
    Row(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .height(20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(if (isPlaying) "▶" else "⏸", color = Color.White, fontSize = 12.sp)
        Spacer(Modifier.width(8.dp))
        Text(formatTime(positionMs), color = Color.White.copy(alpha = 0.96f), fontSize = 12.sp)
        Spacer(Modifier.width(8.dp))
        Box(
            modifier = Modifier
                .weight(1f)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(Color.White.copy(alpha = 0.3f)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(progress)
                    .height(4.dp)
                    .background(TvTokens.Accent, RoundedCornerShape(2.dp)),
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(formatTime(durationMs), color = Color.White.copy(alpha = 0.54f), fontSize = 12.sp)
    }
}

/**
 * 线路区。
 */
@Composable
private fun TvDetailSourceSection(
    sourceOptions: List<TvDetailSourceOption>,
    isSearching: Boolean,
    emptyPlaybackCompleted: Boolean,
    focusTargets: TvDetailFocusTargets,
    currentEpisodeFocusRequester: FocusRequester?,
    listState: LazyListState,
    onSourceSelected: ((String) -> Unit)?,
) {
    val scrollScope = rememberCoroutineScope()
    TvPageSection(
        title = "切换线路",
        hint = if (sourceOptions.isEmpty()) "暂无线路" else "遇播放卡顿、音画不同步或无法播放时，请切换播放线路",
        insetContent = false,
    ) {
        if (sourceOptions.isEmpty()) {
            val message = when {
                emptyPlaybackCompleted -> "搜索已完成，未找到可播放信息。"
                isSearching -> "正在搜索可播放线路。"
                else -> "当前详情未返回可播放来源。"
            }
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = if (emptyPlaybackCompleted) "未找到可播放信息" else "暂无播放线路",
                message = message,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageSection
        }
        LazyRow(
            state = listState,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
            ),
        ) {
            items(sourceOptions.size, key = { index -> sourceOptions[index].sourceId }) { index ->
                val option = sourceOptions[index]
                TvDetailOptionChip(
                    label = option.label,
                    trailing = option.trailingText,
                    selected = option.selected,
                    focusRequester = focusTargets.sources.getOrNull(index),
                    modifier = Modifier.focusProperties {
                        up = focusTargets.player
                        down = currentEpisodeFocusRequester ?: FocusRequester.Default
                        left = focusTargets.sources.getOrNull((index - 1).coerceAtLeast(0)) ?: FocusRequester.Default
                        right = focusTargets.sources.getOrNull((index + 1).coerceAtMost(sourceOptions.lastIndex))
                            ?: FocusRequester.Default
                    }.onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            // 线路获焦时推动横向列表，避免焦点停在屏幕外。
                            scrollDetailOptionIntoView(
                                listState = listState,
                                focusedIndex = index,
                                itemCount = sourceOptions.size,
                                scrollScope = scrollScope,
                            )
                        }
                    },
                    onPressed = { onSourceSelected?.invoke(option.sourceId) },
                )
            }
        }
    }
}

/**
 * 选集区。
 */
@Composable
private fun TvDetailEpisodeSection(
    groups: List<TvDetailEpisodeGroupOption>,
    selectedGroup: TvDetailEpisodeGroupOption?,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    currentEpisodeFocusRequester: FocusRequester?,
    hasRecommends: Boolean,
    episodeListState: LazyListState,
    episodeGroupListState: LazyListState,
    onEpisodeSelected: ((String) -> Unit)?,
    onGroupSelected: ((Int) -> Unit)?,
) {
    val scrollScope = rememberCoroutineScope()
    val totalCount = groups.sumOf { group -> group.episodes.size }
    TvPageSection(
        title = "选集",
        hint = if (totalCount == 0) "暂无剧集" else "共 $totalCount 集",
        insetContent = false,
    ) {
        if (totalCount == 0 || selectedGroup == null) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无选集",
                message = "当前线路没有可播放剧集。",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageSection
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            LazyRow(
                state = episodeListState,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(
                    start = TvTokens.PageHorizontalPadding,
                    end = TvTokens.PageHorizontalPadding,
                ),
            ) {
                items(selectedGroup.episodes.size, key = { index -> selectedGroup.episodes[index].episodeId }) { index ->
                    val episode = selectedGroup.episodes[index]
                    TvDetailOptionChip(
                        label = episode.label,
                        selected = episode.selected,
                        focusRequester = focusTargets.episodes.getOrNull(episode.episodeIndex),
                        modifier = Modifier.focusProperties {
                            up = currentSourceFocusRequester ?: FocusRequester.Default
                            down = focusTargets.episodeGroups.firstOrNull() ?: focusTargets.recommends.takeIf { hasRecommends }
                                ?.firstOrNull() ?: FocusRequester.Default
                            left = focusTargets.episodes.getOrNull((episode.episodeIndex - 1).coerceAtLeast(0))
                                ?: FocusRequester.Default
                            right = focusTargets.episodes.getOrNull((episode.episodeIndex + 1).coerceAtMost(totalCount - 1))
                                ?: FocusRequester.Default
                        }.onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                // 选集获焦时按当前组内下标滚动，保留组内安全留白。
                                scrollDetailOptionIntoView(
                                    listState = episodeListState,
                                    focusedIndex = index,
                                    itemCount = selectedGroup.episodes.size,
                                    scrollScope = scrollScope,
                                )
                            }
                        },
                        onPressed = { onEpisodeSelected?.invoke(episode.episodeId) },
                    )
                }
            }
            if (groups.size > 1) {
                LazyRow(
                    state = episodeGroupListState,
                    horizontalArrangement = Arrangement.spacedBy(18.dp),
                    contentPadding = PaddingValues(
                        start = TvTokens.PageHorizontalPadding,
                        end = TvTokens.PageHorizontalPadding,
                    ),
                ) {
                    items(groups.size, key = { index -> groups[index].groupIndex }) { index ->
                        val group = groups[index]
                        TvTextChoice(
                            label = group.label,
                            selected = group.selected,
                            focusRequester = focusTargets.episodeGroups.getOrNull(index),
                            modifier = Modifier.focusProperties {
                                up = currentEpisodeFocusRequester
                                    ?: focusTargets.episodes.getOrNull(group.episodes.firstOrNull()?.episodeIndex ?: 0)
                                    ?: FocusRequester.Default
                                down = focusTargets.recommends.takeIf { hasRecommends }?.firstOrNull()
                                    ?: FocusRequester.Default
                                left = focusTargets.episodeGroups.getOrNull((index - 1).coerceAtLeast(0))
                                    ?: FocusRequester.Default
                                right = focusTargets.episodeGroups.getOrNull((index + 1).coerceAtMost(groups.lastIndex))
                                    ?: FocusRequester.Default
                            }.onFocusChanged { focusState ->
                                if (focusState.isFocused) {
                                    // 分组获焦时滚到可见位置，确认键再切换选集范围。
                                    scrollDetailOptionIntoView(
                                        listState = episodeGroupListState,
                                        focusedIndex = index,
                                        itemCount = groups.size,
                                        scrollScope = scrollScope,
                                    )
                                }
                            },
                            onPressed = { onGroupSelected?.invoke(group.groupIndex) },
                        )
                    }
                }
            }
        }
    }
}

/**
 * 将详情页横向选项滚动到安全可见区域。
 *
 * @param listState 横向列表状态。
 * @param focusedIndex 当前获焦下标。
 * @param itemCount 当前轨道项目总数。
 * @param scrollScope 滚动协程作用域。
 */
private fun scrollDetailOptionIntoView(
    listState: LazyListState,
    focusedIndex: Int,
    itemCount: Int,
    scrollScope: CoroutineScope,
) {
    val targetIndex = TvListLayoutMetrics.resolveRailFirstVisibleItemIndex(
        focusedIndex = focusedIndex,
        itemCount = itemCount,
    )
    if (targetIndex == listState.firstVisibleItemIndex) {
        // 已在目标视窗，不重复触发滚动动画。
        return
    }
    scrollScope.launch {
        // 与首页海报带保持一致：第 5 个选项起按步长推进。
        listState.animateScrollToItem(targetIndex)
    }
}

/**
 * 推荐区。
 */
@Composable
private fun TvDetailRecommendSection(
    cards: List<TvVideoCard>,
    focusTargets: TvDetailFocusTargets,
) {
    TvPageSection(
        title = "相关推荐",
        hint = "${cards.size} 条推荐",
        insetContent = false,
    ) {
        TvPosterRail(
            items = cards.map { card ->
                TvPosterItem(id = card.id, title = card.title, subtitle = "推荐", posterUrl = card.posterUrl)
            },
            firstItemFocusRequester = focusTargets.recommends.firstOrNull(),
        )
    }
}

/**
 * 底部操作。
 */
@Composable
private fun TvDetailBottomActions(
    focusTargets: TvDetailFocusTargets,
    onHistoryClick: (() -> Unit)?,
    onExitClick: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = TvTokens.PageHorizontalPadding),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        TvDetailActionPill(
            label = "观看历史",
            accent = false,
            focusRequester = focusTargets.bottomAction,
            onClick = { onHistoryClick?.invoke() },
        )
        TvDetailActionPill(label = "退出", accent = false, onClick = { onExitClick?.invoke() })
    }
}

/**
 * 操作按钮。
 */
@Composable
private fun TvDetailActionPill(
    label: String,
    accent: Boolean,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onClick: () -> Unit,
) {
    TvFocusableCard(
        modifier = modifier.height(44.dp).widthIn(min = 100.dp),
        focusRequesters = listOfNotNull(focusRequester),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .background(
                    color = if (accent) TvTokens.Accent else TvTokens.Surface,
                    shape = RoundedCornerShape(22.dp),
                )
                .border(
                    width = 1.dp,
                    color = if (accent) TvTokens.Accent else TvTokens.Outline,
                    shape = RoundedCornerShape(22.dp),
                )
                .padding(horizontal = 20.dp, vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                fontSize = 16.sp,
                fontWeight = if (accent) FontWeight.Bold else FontWeight.Medium,
                color = Color.White,
            )
        }
    }
}

/**
 * 分组文本按钮。
 */
@Composable
private fun TvTextChoice(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.08f else 1f,
        animationSpec = tween(140),
        label = "textChoiceScale",
    )
    val textColor = when {
        isFocused || selected -> TvTokens.Accent
        else -> Color(0xFFD9E2E0)
    }
    Column(
        modifier = modifier
            .scale(scale)
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) {
                    onPressed()
                    true
                } else {
                    false
                }
            }
            .padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            fontSize = 17.sp,
            fontWeight = if (isFocused || selected) FontWeight.Bold else FontWeight.Medium,
            color = textColor,
        )
        if (isFocused) {
            Spacer(Modifier.height(2.dp))
            Box(
                modifier = Modifier
                    .width(24.dp)
                    .height(2.dp)
                    .background(TvTokens.Accent, RoundedCornerShape(1.dp)),
            )
        }
    }
}

/**
 * 详情页横向选项。
 */
@Composable
private fun TvDetailOptionChip(
    label: String,
    trailing: String? = null,
    selected: Boolean,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scope = rememberCoroutineScope()
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.08f else 1f,
        animationSpec = tween(140),
        label = "chipScale",
    )
    val bg = when {
        selected -> TvTokens.Accent
        isFocused -> TvTokens.FocusFill
        else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
    }
    val borderColor = when {
        isFocused -> TvTokens.FocusBorder
        selected -> TvTokens.Accent
        else -> Color.Transparent
    }
    Box(
        modifier = modifier
            .widthIn(min = 86.dp, max = 180.dp)
            .scale(scale)
            .clip(RoundedCornerShape(TvTokens.CardRadius))
            .background(bg)
            .border(
                width = if (isFocused || selected) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.Enter,
                    Key.DirectionCenter -> {
                        onPressed()
                        true
                    }
                    Key.DirectionLeft,
                    Key.DirectionRight -> {
                        // 横向边界交给 focusProperties，消费失败时保持当前焦点。
                        scope.launch { focusRequester?.requestFocus() }
                        false
                    }
                    else -> false
                }
            }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontSize = 15.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                color = if (selected) Color.White else Color(0xFFD9E2E0),
            )
            if (!trailing.isNullOrBlank()) {
                Text(text = trailing, fontSize = 13.sp, color = TvTokens.FormTextSecondary)
            }
        }
    }
}

/**
 * 格式化播放时间。
 */
private fun formatTime(ms: Long): String {
    val totalSeconds = (ms / 1000).coerceAtLeast(0)
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return if (hours > 0) {
        "%d:%02d:%02d".format(hours, minutes, seconds)
    } else {
        "%02d:%02d".format(minutes, seconds)
    }
}

/**
 * 格式化网速。
 */
private fun formatSpeed(bytesPerSec: Long): String {
    val kb = bytesPerSec / 1024f
    return if (kb >= 1024) {
        "%.1fMB/s".format(kb / 1024)
    } else {
        "%.0fKB/s".format(kb)
    }
}
