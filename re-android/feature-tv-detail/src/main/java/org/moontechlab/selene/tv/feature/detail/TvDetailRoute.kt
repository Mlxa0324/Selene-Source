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
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
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
    playerSurface: (@Composable () -> Unit)? = null,
) {
    TvPageScaffold(title = state.detail?.title ?: "详情") {
        // 错误态
        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "详情加载失败",
                message = state.errorMessage,
                actionLabel = "重试",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.detail == null) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "暂无详情",
                message = "当前视频没有可展示的详情信息。",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.emptyPlaybackCompleted) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "未找到可播放信息",
                message = "搜索已完成，未找到可播放信息。",
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        // ═══ 续播提示 ═══
        if (state.showResumePrompt) {
            TvPageSection(title = "续播提示") {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = TvTokens.PageHorizontalPadding),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "上次看到第 ${state.resumeEpisodeId} 集，是否继续？",
                        style = MaterialTheme.typography.bodyLarge,
                        color = TvTokens.TextPrimary,
                        modifier = Modifier.weight(1f),
                    )
                    TvDetailActionPill(label = "继续", accent = true, onClick = { onResumeFromRecord?.invoke() })
                    TvDetailActionPill(
                        label = "忽略",
                        accent = false,
                        onClick = { onDismissResume?.invoke() },
                    )
                }
                Spacer(Modifier.height(8.dp))
            }
        }

        // ═══ Hero: 播放器 + 信息面板 ═══
        TvDetailHeroArea(
            posterUrl = state.detail.posterUrl,
            episodeTitle = state.currentEpisode?.title ?: state.detail.title,
            sourceName = state.currentSource?.name.orEmpty(),
            title = state.detail.title,
            year = state.detail.year,
            detailSourceName = state.detail.sourceName,
            episodeCount = state.currentSource?.episodes.orEmpty().size,
            description = state.detail.description,
            isLoadingMoreSources = state.isLoadingMoreSources,
            totalSources = state.detail.sources.size,
            isFavorite = state.isFavorite,
            onPlayPressed = onPlayPressed,
            onFavoriteToggle = onFavoriteToggle,
            playerSurface = playerSurface,
            previewIsLoading = state.previewIsLoading,
            previewNetworkSpeed = state.previewNetworkSpeed,
            previewIsPlaying = state.previewIsPlaying,
            previewPositionMs = state.previewPositionMs,
            previewDurationMs = state.previewDurationMs,
            previewPlaybackStarted = state.previewPlaybackStarted,
        )

        // ═══ 线路 ═══
        TvSourceSection(
            sources = state.detail.sources,
            selectedSourceId = state.currentSourceId,
            onSourceSelected = onSourceSelected,
        )

        // ═══ 选集 (支持分组) ═══
        TvEpisodeGroupedSection(
            groups = state.episodeGroups,
            selectedGroup = state.selectedEpisodeGroup,
            currentEpisodes = state.currentGroupEpisodes,
            selectedEpisodeId = state.currentEpisodeId,
            onEpisodeSelected = onEpisodeSelected,
            onGroupSelected = onEpisodeGroupSelected,
        )

        // ═══ 推荐 ═══
        if (state.recommendCards.isNotEmpty()) {
            TvPageSection(
                title = "相关推荐",
                hint = "${state.recommendCards.size} 条推荐",
                insetContent = false,
            ) {
                TvPosterRail(
                    items = state.recommendCards.map { card ->
                        TvPosterItem(id = card.id, title = card.title, subtitle = "推荐", posterUrl = card.posterUrl)
                    },
                )
            }
        }

        // ═══ 底部操作 ═══
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = TvTokens.PageHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            TvDetailActionPill(label = "观看历史", accent = false, onClick = { onHistoryClick?.invoke() })
            TvDetailActionPill(label = "退出", accent = false, onClick = { onExitClick?.invoke() })
        }
    }
}

// ── Hero 区域 (对齐 Flutter TV _buildHeroArea + _buildInfoPanel) ──

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TvDetailHeroArea(
    posterUrl: String, episodeTitle: String, sourceName: String,
    title: String, year: String, detailSourceName: String, episodeCount: Int,
    description: String, isLoadingMoreSources: Boolean, totalSources: Int,
    isFavorite: Boolean, onPlayPressed: (() -> Unit)?, onFavoriteToggle: (() -> Unit)?,
    playerSurface: (@Composable () -> Unit)?, previewIsLoading: Boolean, previewNetworkSpeed: Long,
    previewIsPlaying: Boolean, previewPositionMs: Long, previewDurationMs: Long, previewPlaybackStarted: Boolean,
) {
    Row(Modifier.fillMaxWidth().padding(horizontal = TvTokens.PageHorizontalPadding), horizontalArrangement = Arrangement.spacedBy(34.dp), verticalAlignment = Alignment.Top) {
        TvDetailPlayerPreview(episodeTitle, sourceName, posterUrl, onPlayPressed, playerSurface, previewIsLoading, previewNetworkSpeed, previewIsPlaying, previewPositionMs, previewDurationMs, previewPlaybackStarted)
        // 信息面板
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = title,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                fontSize = 30.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color.White,
            )
            // Meta: 年份 · 来源 · 共N集 (Flutter 风格纯文本)
            val metaParts = buildList {
                if (year.isNotBlank()) add(year)
                if (detailSourceName.isNotBlank()) add(detailSourceName)
                if (episodeCount > 0) add("共 $episodeCount 集")
            }
            if (metaParts.isNotEmpty()) {
                Text(
                    text = metaParts.joinToString(" · "),
                    fontSize = 15.sp,
                    color = TvTokens.FormTextSecondary,
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = description.ifBlank { "暂无简介" },
                maxLines = 6,
                overflow = TextOverflow.Ellipsis,
                fontSize = 16.sp,
                lineHeight = 23.sp,
                color = TvTokens.FormTextSecondary,
            )
            Spacer(Modifier.height(4.dp))
            val sourceSummary = if (isLoadingMoreSources) "正在补充更多播放线路"
            else "共 $totalSources 条线路"
            Text(text = sourceSummary, fontSize = 15.sp, color = TvTokens.FormTextSecondary)

            Spacer(Modifier.height(10.dp))
            // 操作按钮 (Flutter Wrap 风格)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                TvDetailActionPill(label = "全屏", accent = false, onClick = { onPlayPressed?.invoke() })
                TvDetailActionPill(
                    label = if (isFavorite) "已收藏" else "收藏",
                    accent = isFavorite,
                    onClick = { onFavoriteToggle?.invoke() },
                )
            }
        }
    }
}

@Composable
private fun TvDetailPlayerPreview(
    episodeTitle: String, sourceName: String, posterUrl: String, onPlayPressed: (() -> Unit)?,
    playerSurface: (@Composable () -> Unit)?, previewIsLoading: Boolean, previewNetworkSpeed: Long,
    previewIsPlaying: Boolean, previewPositionMs: Long, previewDurationMs: Long, previewPlaybackStarted: Boolean,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    Box(
        modifier = Modifier
            .width(620.dp).aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(10.dp))
            .border(2.dp, if (isFocused) Color.White else Color.Transparent, RoundedCornerShape(10.dp))
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) { onPlayPressed?.invoke(); true }
                else false
            },
    ) {
        // 视频层 或 静态封面
        if (playerSurface != null) {
            playerSurface()
        } else if (posterUrl.isNotBlank()) {
            AsyncImage(model = posterUrl, contentDescription = episodeTitle, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        }
        // 标题叠加层
        if (playerSurface == null || !previewPlaybackStarted) {
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.72f)))))
            Column(Modifier.align(Alignment.BottomStart).padding(22.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(episodeTitle, maxLines = 2, overflow = TextOverflow.Ellipsis, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.White)
                Text(sourceName.ifBlank { "选择线路后播放" }, maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 16.sp, color = Color.White.copy(alpha = 0.78f))
            }
        }
        // 加载中覆盖层 (Flutter _buildPreviewLoadingOverlay)
        if (previewIsLoading) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator(color = TvTokens.Accent, modifier = Modifier.size(36.dp), strokeWidth = 3.dp)
                    Spacer(Modifier.height(12.dp))
                    Text("加载中", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White.copy(alpha = 0.94f))
                    if (previewNetworkSpeed > 0) {
                        Spacer(Modifier.height(4.dp))
                        Text(formatSpeed(previewNetworkSpeed), fontSize = 13.sp, color = Color.White.copy(alpha = 0.72f))
                    }
                }
            }
        }
        // 进度条 (Flutter _buildDetailProgressBar)
        if (previewPlaybackStarted && previewDurationMs > 0) {
            val progress = (previewPositionMs.toFloat() / previewDurationMs).coerceIn(0f, 1f)
            Row(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp).height(20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(if (previewIsPlaying) "▶" else "⏸", color = Color.White, fontSize = 12.sp)
                Spacer(Modifier.width(8.dp))
                Text(formatTime(previewPositionMs), color = Color.White.copy(alpha = 0.96f), fontSize = 12.sp)
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(alpha = 0.3f))) {
                    Box(Modifier.fillMaxWidth(progress).height(4.dp).background(TvTokens.Accent, RoundedCornerShape(2.dp)))
                }
                Spacer(Modifier.width(8.dp))
                Text(formatTime(previewDurationMs), color = Color.White.copy(alpha = 0.54f), fontSize = 12.sp)
            }
        }
    }
}

private fun formatTime(ms: Long): String {
    val s = (ms / 1000).coerceAtLeast(0)
    return "${s / 3600}:${(s % 3600) / 60}:${s % 60}".replace(Regex("(?<!:)\\b(\\d)\\b"), "0$1")
}
private fun formatSpeed(bytesPerSec: Long): String {
    val kb = bytesPerSec / 1024f
    return if (kb >= 1024) "%.1fMB/s".format(kb / 1024) else "%.0fKB/s".format(kb)
}

@Composable
private fun TvDetailActionPill(label: String, accent: Boolean, onClick: () -> Unit) {
    TvFocusableCard(
        modifier = Modifier.height(44.dp).widthIn(min = 100.dp),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .background(
                    color = if (accent) TvTokens.Accent else TvTokens.Surface,
                    shape = RoundedCornerShape(22.dp),
                )
                .border(width = 1.dp, color = if (accent) TvTokens.Accent else TvTokens.Outline, shape = RoundedCornerShape(22.dp))
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

@Composable
private fun TvSourceSection(sources: List<TvVideoSource>, selectedSourceId: String, onSourceSelected: ((String) -> Unit)?) {
    TvPageSection(title = "切换线路", hint = if (sources.isEmpty()) "暂无线路" else "遇播放卡顿，音画不同步或无法播放时，请切换播放线路", insetContent = false) {
        if (sources.isEmpty()) {
            TvStatePanel(kind = TvStatePanelKind.Empty, title = "暂无播放线路", message = "当前详情未返回可播放来源。", modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding))
            return@TvPageSection
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(start = TvTokens.PageHorizontalPadding, end = TvTokens.PageHorizontalPadding)) {
            items(sources, key = TvVideoSource::id) { source ->
                TvDetailOptionChip(label = source.name, trailing = "${source.episodes.size}", selected = source.id == selectedSourceId, onPressed = { onSourceSelected?.invoke(source.id) })
            }
        }
    }
}

/**
 * TV 详情页选集区（支持 20 集分组）。
 */
@Composable
private fun TvEpisodeGroupedSection(
    groups: List<List<TvEpisode>>,
    selectedGroup: Int,
    currentEpisodes: List<TvEpisode>,
    selectedEpisodeId: String,
    onEpisodeSelected: ((String) -> Unit)?,
    onGroupSelected: ((Int) -> Unit)?,
) {
    val totalCount = groups.sumOf { it.size }
    TvPageSection(title = "选集", hint = if (totalCount == 0) "暂无剧集" else "共 $totalCount 集", insetContent = false) {
        if (totalCount == 0) {
            TvStatePanel(kind = TvStatePanelKind.Empty, title = "暂无剧集", message = "当前线路没有可播放剧集。", modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding))
            return@TvPageSection
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 分组选择行
            if (groups.size > 1) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp), contentPadding = PaddingValues(start = TvTokens.PageHorizontalPadding)) {
                    items(groups.size) { gi ->
                        val start = gi * 20 + 1
                        val end = minOf((gi + 1) * 20, totalCount)
                        TvTextChoice(label = "$start-$end", selected = gi == selectedGroup, onPressed = { onGroupSelected?.invoke(gi) })
                    }
                }
            }
            // 当前分组剧集
            LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(start = TvTokens.PageHorizontalPadding, end = TvTokens.PageHorizontalPadding)) {
                items(currentEpisodes, key = TvEpisode::id) { episode ->
                    TvDetailOptionChip(label = episode.title, selected = episode.id == selectedEpisodeId, onPressed = { onEpisodeSelected?.invoke(episode.id) })
                }
            }
        }
    }
}

@Composable
private fun TvTextChoice(label: String, selected: Boolean, onPressed: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scale by animateFloatAsState(if (isFocused) 1.08f else 1f, animationSpec = tween(140), label = "textChoiceScale")
    val textColor = when { isFocused || selected -> TvTokens.Accent; else -> Color(0xFFD9E2E0) }
    Column(
        modifier = Modifier
            .scale(scale)
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) { onPressed(); true }
                else false
            }
            .padding(horizontal = 4.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = label, fontSize = 17.sp, fontWeight = if (isFocused || selected) FontWeight.Bold else FontWeight.Medium, color = textColor)
        if (isFocused) {
            Spacer(Modifier.height(2.dp))
            Box(modifier = Modifier.width(24.dp).height(2.dp).background(TvTokens.Accent, RoundedCornerShape(1.dp)))
        }
    }
}

@Composable
private fun TvDetailOptionChip(label: String, trailing: String? = null, selected: Boolean, onPressed: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scale by animateFloatAsState(if (isFocused) 1.08f else 1f, animationSpec = tween(140), label = "chipScale")
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
        modifier = Modifier
            .widthIn(min = 86.dp, max = 180.dp)
            .scale(scale)
            .clip(RoundedCornerShape(TvTokens.CardRadius))
            .background(bg)
            .border(if (isFocused || selected) 2.dp else 1.dp, borderColor, RoundedCornerShape(TvTokens.CardRadius))
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) { onPressed(); true }
                else false
            }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(text = label, maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 15.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium, color = if (selected) TvTokens.Accent else Color(0xFFD9E2E0))
            if (!trailing.isNullOrBlank()) Text(text = trailing, fontSize = 13.sp, color = TvTokens.FormTextSecondary)
        }
    }
}
