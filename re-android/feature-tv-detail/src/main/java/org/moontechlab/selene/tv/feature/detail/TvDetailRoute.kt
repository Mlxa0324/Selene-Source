package org.moontechlab.selene.tv.feature.detail

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/** TV 详情页截图版背景色。 */
private val NcatBackground = Color(0xFF11131C)

/** TV 详情页截图版卡片底色。 */
private val NcatSurface = Color(0xFF454852)

/** TV 详情页截图版弱文字色。 */
private val NcatMutedText = Color(0xFF9A9AA3)

/** TV 详情页截图版圆角。 */
private val NcatRadius = 8.dp

/** TV 详情页顶部右侧时间格式。 */
private val NcatTimeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

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
    val recommendListState = rememberLazyListState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NcatBackground),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 58.dp),
        ) {
            NcatDetailTopBar(
                focusTargets = focusTargets,
                onSearchClick = onSearchClick,
            )

            when {
                !state.errorMessage.isNullOrBlank() -> {
                    NcatStateBlock(
                        kind = TvStatePanelKind.Error,
                        title = "详情加载失败",
                        message = state.errorMessage,
                        focusRequester = focusTargets.player,
                    )
                    return@Column
                }

                detail == null -> {
                    NcatStateBlock(
                        kind = TvStatePanelKind.Empty,
                        title = "暂无详情",
                        message = "当前视频没有可展示的详情信息。",
                        focusRequester = focusTargets.player,
                    )
                    return@Column
                }
            }

            if (state.showResumePrompt) {
                NcatResumePrompt(
                    state = state,
                    onResumeFromRecord = onResumeFromRecord,
                    onDismissResume = onDismissResume,
                )
            }

            NcatDetailHero(
                state = state,
                focusTargets = focusTargets,
                currentSourceFocusRequester = currentSourceFocusRequester,
                onPlayPressed = onPlayPressed,
                onFavoriteToggle = onFavoriteToggle,
                playerSurface = playerSurface,
            )

            NcatSourceRail(
                sourceOptions = sourceOptions,
                isSearching = state.isMoreSourcesLoading,
                emptyPlaybackCompleted = state.emptyPlaybackCompleted,
                focusTargets = focusTargets,
                currentEpisodeFocusRequester = currentEpisodeFocusRequester,
                listState = sourceListState,
                onSourceSelected = onSourceSelected,
            )

            NcatEpisodeGroupRail(
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
                NcatRecommendRail(
                    cards = state.recommendCards,
                    focusTargets = focusTargets,
                    listState = recommendListState,
                )
            }

            if (layoutSections.showBottomActions) {
                NcatBottomActions(
                    focusTargets = focusTargets,
                    onHistoryClick = onHistoryClick,
                    onExitClick = onExitClick,
                )
            }
        }
    }
}

/**
 * TV 详情页焦点请求器集合。
 *
 * @property search 顶部搜索焦点。
 * @property login 顶部登录焦点。
 * @property player 预览播放器焦点。
 * @property fullscreen 全屏按钮焦点。
 * @property favorite 收藏按钮焦点。
 * @property feedback 反馈按钮焦点。
 * @property sources 线路焦点列表。
 * @property episodes 选集焦点列表。
 * @property episodeGroups 分组焦点列表。
 * @property recommends 推荐焦点列表。
 * @property backTop 底部返回顶部焦点。
 * @property random 底部随便看看焦点。
 */
private data class TvDetailFocusTargets(
    val search: FocusRequester,
    val login: FocusRequester,
    val player: FocusRequester,
    val fullscreen: FocusRequester,
    val favorite: FocusRequester,
    val feedback: FocusRequester,
    val sources: List<FocusRequester>,
    val episodes: List<FocusRequester>,
    val episodeGroups: List<FocusRequester>,
    val recommends: List<FocusRequester>,
    val backTop: FocusRequester,
    val random: FocusRequester,
)

/**
 * 创建详情页焦点请求器。
 *
 * @param sourceCount 线路数量。
 * @param episodeCount 选集数量。
 * @param episodeGroupCount 选集分组数量。
 * @param recommendCount 推荐数量。
 * @return 焦点请求器集合。
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
        login = remember { FocusRequester() },
        player = player,
        fullscreen = remember { FocusRequester() },
        favorite = remember { FocusRequester() },
        feedback = remember { FocusRequester() },
        sources = remember(sourceCount) { List(sourceCount) { FocusRequester() } },
        episodes = remember(episodeCount) { List(episodeCount) { FocusRequester() } },
        episodeGroups = remember(episodeGroupCount) { List(episodeGroupCount) { FocusRequester() } },
        recommends = remember(recommendCount) { List(recommendCount) { FocusRequester() } },
        backTop = remember { FocusRequester() },
        random = remember { FocusRequester() },
    )
    LaunchedEffect(player) {
        // 详情首屏默认落到预览播放器，避免遥控器从顶部死角开始。
        runCatching { player.requestFocus() }
    }
    return targets
}

/**
 * 截图式顶部栏。
 *
 * @param focusTargets 焦点请求器。
 * @param onSearchClick 搜索入口回调。
 */
@Composable
private fun NcatDetailTopBar(
    focusTargets: TvDetailFocusTargets,
    onSearchClick: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 46.dp, end = 46.dp, top = 54.dp, bottom = 30.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "网飞猫",
                color = Color.White,
                fontSize = 30.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            Spacer(Modifier.width(22.dp))
            Text(
                text = "按返回键返回上一页 | 全屏时[向下键]可进行播放设置（内核，倍数，其它）",
                color = NcatMutedText,
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatTopPill(
                label = "⌕ 搜索",
                focusRequester = focusTargets.search,
                modifier = Modifier.focusProperties {
                    right = focusTargets.login
                    down = focusTargets.player
                },
                onClick = { onSearchClick?.invoke() },
            )
            NcatTopPill(
                label = "♟ 立即登录",
                focusRequester = focusTargets.login,
                modifier = Modifier.focusProperties {
                    left = focusTargets.search
                    down = focusTargets.fullscreen
                },
                onClick = {},
            )
            Text(
                text = remember { LocalTime.now().format(NcatTimeFormatter) },
                color = Color.White.copy(alpha = 0.86f),
                fontSize = 26.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

/**
 * 顶部胶囊按钮。
 *
 * @param label 展示文案。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onClick 点击回调。
 */
@Composable
private fun NcatTopPill(
    label: String,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    TvFocusableCard(
        modifier = modifier
            .height(54.dp)
            .widthIn(min = 118.dp),
        focusRequesters = listOf(focusRequester),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF343840), RoundedCornerShape(28.dp))
                .padding(horizontal = 22.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
        }
    }
}

/**
 * 截图式续播提示。
 *
 * @param state 详情页状态。
 * @param onResumeFromRecord 续播回调。
 * @param onDismissResume 忽略回调。
 */
@Composable
private fun NcatResumePrompt(
    state: TvDetailUiState,
    onResumeFromRecord: (() -> Unit)?,
    onDismissResume: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 46.dp, vertical = 8.dp)
            .background(Color(0xFF2B2F38), RoundedCornerShape(NcatRadius))
            .padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "上次播放到第 ${state.resumeEpisodeIndex + 1} 集，是否继续？",
            color = Color.White,
            fontSize = 18.sp,
            modifier = Modifier.weight(1f),
        )
        NcatSmallPill(label = "继续", accent = true, onClick = { onResumeFromRecord?.invoke() })
        NcatSmallPill(label = "忽略", accent = false, onClick = { onDismissResume?.invoke() })
    }
}

/**
 * 截图式 Hero 区。
 *
 * @param state 详情页状态。
 * @param focusTargets 焦点请求器。
 * @param currentSourceFocusRequester 当前线路焦点。
 * @param onPlayPressed 全屏播放回调。
 * @param onFavoriteToggle 收藏切换回调。
 * @param playerSurface 播放器内容。
 */
@Composable
private fun NcatDetailHero(
    state: TvDetailUiState,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    onPlayPressed: (() -> Unit)?,
    onFavoriteToggle: (() -> Unit)?,
    playerSurface: (@Composable () -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 46.dp),
        horizontalArrangement = Arrangement.spacedBy(42.dp),
        verticalAlignment = Alignment.Top,
    ) {
        NcatPreviewPanel(
            title = state.currentEpisode?.title ?: state.detail?.title.orEmpty(),
            sourceName = state.currentSource?.name.orEmpty(),
            posterUrl = state.detail?.posterUrl.orEmpty(),
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
        NcatInfoPanel(
            state = state,
            focusTargets = focusTargets,
            currentSourceFocusRequester = currentSourceFocusRequester,
            modifier = Modifier.weight(1f),
            onPlayPressed = onPlayPressed,
            onFavoriteToggle = onFavoriteToggle,
        )
    }
}

/**
 * 截图式预览播放器。
 *
 * @param title 当前标题。
 * @param sourceName 当前线路名称。
 * @param posterUrl 海报兜底地址。
 * @param focusTargets 焦点请求器。
 * @param currentSourceFocusRequester 当前线路焦点。
 * @param onPlayPressed 播放回调。
 * @param playerSurface 播放器内容。
 * @param previewIsLoading 是否加载中。
 * @param previewNetworkSpeed 当前网速。
 * @param previewIsPlaying 是否正在播放。
 * @param previewPositionMs 当前进度。
 * @param previewDurationMs 总时长。
 * @param previewPlaybackStarted 是否已下发播放。
 */
@Composable
private fun NcatPreviewPanel(
    title: String,
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
            .width(650.dp)
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(0.dp))
            .border(
                width = if (isFocused) 3.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
            )
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
        } else {
            NcatPreviewPlaceholder(
                title = title,
                sourceName = sourceName,
                posterUrl = posterUrl,
            )
        }
        if (previewIsLoading) {
            NcatPreviewLoadingOverlay(previewNetworkSpeed)
        }
        if (previewPlaybackStarted && previewDurationMs > 0L) {
            NcatPreviewProgressBar(
                isPlaying = previewIsPlaying,
                positionMs = previewPositionMs,
                durationMs = previewDurationMs,
            )
        }
    }
}

/**
 * 播放器占位内容。
 *
 * @param title 当前标题。
 * @param sourceName 当前线路名称。
 * @param posterUrl 海报兜底地址。
 */
@Composable
private fun NcatPreviewPlaceholder(
    title: String,
    sourceName: String,
    posterUrl: String,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF061A23)),
    ) {
        if (posterUrl.isNotBlank()) {
            AsyncImage(
                model = posterUrl,
                contentDescription = title,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f)),
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.42f)),
            )
        }
        Column(
            modifier = Modifier
                .align(Alignment.Center)
                .padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text(
                text = "NCAT.APP",
                color = TvTokens.Accent,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
            )
            Text(
                text = "网飞猫",
                color = Color.White,
                fontSize = 42.sp,
                fontWeight = FontWeight.Black,
            )
            Box(
                modifier = Modifier
                    .width(360.dp)
                    .height(2.dp)
                    .background(TvTokens.Accent.copy(alpha = 0.45f)),
            )
            Text(
                text = if (sourceName.isBlank()) "精彩马上开始" else "精彩马上开始 · $sourceName",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 20.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            text = "提醒：请勿随意相信视频上广告、网址、电影、二维码等！",
            color = Color.White.copy(alpha = 0.86f),
            fontSize = 18.sp,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 34.dp, bottom = 30.dp),
        )
    }
}

/**
 * 预览播放器加载层。
 *
 * @param previewNetworkSpeed 当前网速。
 */
@Composable
private fun NcatPreviewLoadingOverlay(previewNetworkSpeed: Long) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.45f)),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(
                color = TvTokens.Accent,
                modifier = Modifier.size(38.dp),
                strokeWidth = 3.dp,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = if (previewNetworkSpeed > 0L) formatSpeed(previewNetworkSpeed) else "加载中",
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.94f),
            )
        }
    }
}

/**
 * 预览播放器进度条。
 *
 * @param isPlaying 是否正在播放。
 * @param positionMs 当前进度。
 * @param durationMs 总时长。
 */
@Composable
private fun BoxScope.NcatPreviewProgressBar(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
) {
    val progress = (positionMs.toFloat() / durationMs).coerceIn(0f, 1f)
    Row(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp)
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
 * 截图式右侧信息面板。
 *
 * @param state 详情页状态。
 * @param focusTargets 焦点请求器。
 * @param currentSourceFocusRequester 当前线路焦点。
 * @param modifier 外层修饰器。
 * @param onPlayPressed 全屏播放回调。
 * @param onFavoriteToggle 收藏切换回调。
 */
@Composable
private fun NcatInfoPanel(
    state: TvDetailUiState,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onPlayPressed: (() -> Unit)?,
    onFavoriteToggle: (() -> Unit)?,
) {
    val detail = state.detail ?: return
    Column(
        modifier = modifier.height(366.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Text(
            text = detail.title,
            color = Color.White,
            fontSize = 32.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatMetaBadge(label = "豆瓣：暂无评分", accent = true)
            if (detail.year.isNotBlank()) {
                NcatMetaBadge(label = detail.year, accent = false)
            }
            NcatMetaBadge(label = detail.sourceName.ifBlank { "中国大陆" }, accent = false)
            NcatMetaBadge(label = "剧情 / 奇幻 / 冒险", accent = false)
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(104.dp)
                .background(NcatSurface, RoundedCornerShape(6.dp)),
        ) {
            Text(
                text = detail.description.ifBlank { "暂无简介" },
                color = Color.White.copy(alpha = 0.78f),
                fontSize = 18.sp,
                lineHeight = 28.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
            )
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .background(Color.White.copy(alpha = 0.14f), RoundedCornerShape(topStart = 4.dp))
                    .padding(horizontal = 18.dp, vertical = 8.dp),
            ) {
                Text(text = "更多", color = Color.White.copy(alpha = 0.72f), fontSize = 16.sp)
            }
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatActionTile(
                label = "全屏",
                icon = "▢",
                selected = false,
                focusRequester = focusTargets.fullscreen,
                modifier = Modifier.focusProperties {
                    up = focusTargets.login
                    left = focusTargets.player
                    right = focusTargets.favorite
                    down = currentSourceFocusRequester ?: FocusRequester.Default
                },
                onPressed = { onPlayPressed?.invoke() },
            )
            NcatActionTile(
                label = if (state.isFavorite) "已收藏" else "收藏",
                icon = "♥",
                selected = state.isFavorite,
                focusRequester = focusTargets.favorite,
                modifier = Modifier.focusProperties {
                    up = focusTargets.login
                    left = focusTargets.fullscreen
                    right = focusTargets.feedback
                    down = currentSourceFocusRequester ?: FocusRequester.Default
                },
                onPressed = { onFavoriteToggle?.invoke() },
            )
            NcatActionTile(
                label = "反馈",
                icon = "▰",
                selected = false,
                focusRequester = focusTargets.feedback,
                modifier = Modifier.focusProperties {
                    up = focusTargets.login
                    left = focusTargets.favorite
                    right = focusTargets.feedback
                    down = currentSourceFocusRequester ?: FocusRequester.Default
                },
                onPressed = {},
            )
        }
    }
}

/**
 * 元信息标签。
 *
 * @param label 展示文案。
 * @param accent 是否红色强调。
 */
@Composable
private fun NcatMetaBadge(
    label: String,
    accent: Boolean,
) {
    Box(
        modifier = Modifier
            .height(40.dp)
            .background(if (accent) TvTokens.Accent else NcatSurface, RoundedCornerShape(5.dp))
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
    }
}

/**
 * Hero 大方块操作。
 *
 * @param label 展示文案。
 * @param icon 简洁图标。
 * @param selected 是否选中。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onPressed 确认回调。
 */
@Composable
private fun NcatActionTile(
    label: String,
    icon: String,
    selected: Boolean,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val background = if (selected || isFocused) TvTokens.Accent else NcatSurface
    val borderColor = if (isFocused) Color.White else Color.Transparent
    Column(
        modifier = modifier
            .width(92.dp)
            .height(102.dp)
            .background(background, RoundedCornerShape(NcatRadius))
            .border(BorderStroke(3.dp, borderColor), RoundedCornerShape(NcatRadius))
            .focusRequester(focusRequester)
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
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = icon, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(text = label, color = Color.White, fontSize = 19.sp, fontWeight = FontWeight.Bold)
    }
}

/**
 * 截图式线路轨道。
 *
 * @param sourceOptions 线路选项。
 * @param isSearching 是否补源中。
 * @param emptyPlaybackCompleted 是否已完成无源搜索。
 * @param focusTargets 焦点请求器。
 * @param currentEpisodeFocusRequester 当前选集焦点。
 * @param listState 横向列表状态。
 * @param onSourceSelected 线路选择回调。
 */
@Composable
private fun NcatSourceRail(
    sourceOptions: List<TvDetailSourceOption>,
    isSearching: Boolean,
    emptyPlaybackCompleted: Boolean,
    focusTargets: TvDetailFocusTargets,
    currentEpisodeFocusRequester: FocusRequester?,
    listState: LazyListState,
    onSourceSelected: ((String) -> Unit)?,
) {
    val scrollScope = rememberCoroutineScope()
    NcatSectionHeader(
        title = "切换线路",
        hint = "遇播放卡顿，音画不同步或无法播放时，请切换播放线路或播放内核",
        topPadding = 48.dp,
    )
    if (sourceOptions.isEmpty()) {
        val message = when {
            emptyPlaybackCompleted -> "搜索已完成，未找到可播放信息。"
            isSearching -> "正在搜索可播放线路。"
            else -> "当前详情未返回可播放来源。"
        }
        NcatStateBlock(
            kind = TvStatePanelKind.Empty,
            title = if (emptyPlaybackCompleted) "未找到可播放信息" else "暂无播放线路",
            message = message,
            focusRequester = null,
        )
        return
    }
    LazyRow(
        state = listState,
        horizontalArrangement = Arrangement.spacedBy(18.dp),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp),
        modifier = Modifier.height(116.dp),
    ) {
        items(sourceOptions.size, key = { index -> sourceOptions[index].sourceId }) { index ->
            val option = sourceOptions[index]
            NcatSourceCard(
                option = option,
                focusRequester = focusTargets.sources.getOrNull(index),
                modifier = Modifier
                    .focusProperties {
                        up = focusTargets.player
                        down = currentEpisodeFocusRequester ?: focusTargets.episodeGroups.firstOrNull()
                            ?: focusTargets.recommends.firstOrNull()
                            ?: FocusRequester.Default
                        left = focusTargets.sources.getOrNull((index - 1).coerceAtLeast(0)) ?: FocusRequester.Default
                        right = focusTargets.sources.getOrNull((index + 1).coerceAtMost(sourceOptions.lastIndex))
                            ?: FocusRequester.Default
                    }
                    .onFocusChanged { focusState ->
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

/**
 * 截图式线路卡。
 *
 * @param option 线路选项。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onPressed 确认回调。
 */
@Composable
private fun NcatSourceCard(
    option: TvDetailSourceOption,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val selected = option.selected || isFocused
    val label = "${option.label}${option.trailingText}"
    Box(
        modifier = modifier
            .width(244.dp)
            .height(104.dp)
            .background(if (selected) TvTokens.Accent else NcatSurface, RoundedCornerShape(NcatRadius))
            .border(
                width = if (isFocused) 3.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(NcatRadius),
            )
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
            },
    ) {
        if (option.episodeCount >= 20) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .background(
                        color = if (selected) Color(0xFFD0171D) else Color(0xFFB73138),
                        shape = RoundedCornerShape(topStart = NcatRadius, bottomEnd = 2.dp),
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp),
            ) {
                Text(text = "待加速", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = label,
                color = if (selected) Color.White else Color.White.copy(alpha = 0.48f),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (option.selected) "秒播/4K" else sourceDescription(option),
                color = if (selected) Color.White.copy(alpha = 0.9f) else Color.White.copy(alpha = 0.46f),
                fontSize = 18.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 截图式选集分组轨道。
 *
 * @param groups 选集分组。
 * @param selectedGroup 当前分组。
 * @param focusTargets 焦点请求器。
 * @param currentSourceFocusRequester 当前线路焦点。
 * @param currentEpisodeFocusRequester 当前选集焦点。
 * @param hasRecommends 是否有推荐。
 * @param episodeListState 选集列表状态。
 * @param episodeGroupListState 分组列表状态。
 * @param onEpisodeSelected 选集回调。
 * @param onGroupSelected 分组回调。
 */
@Composable
private fun NcatEpisodeGroupRail(
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
    NcatSectionHeader(
        title = "选集",
        hint = if (totalCount == 0) "暂无选集" else "(共${totalCount}集全)",
        topPadding = 38.dp,
    )
    if (totalCount == 0 || selectedGroup == null) {
        NcatStateBlock(
            kind = TvStatePanelKind.Empty,
            title = "暂无选集",
            message = "当前线路没有可播放剧集。",
            focusRequester = null,
        )
        return
    }

    LazyRow(
        state = episodeGroupListState,
        horizontalArrangement = Arrangement.spacedBy(26.dp),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp),
        modifier = Modifier.height(92.dp),
    ) {
        items(groups.size, key = { index -> groups[index].groupIndex }) { index ->
            val group = groups[index]
            NcatEpisodeGroupChoice(
                label = group.label,
                selected = group.selected,
                focusRequester = focusTargets.episodeGroups.getOrNull(index),
                modifier = Modifier
                    .focusProperties {
                        up = currentEpisodeFocusRequester
                            ?: focusTargets.episodes.getOrNull(group.episodes.firstOrNull()?.episodeIndex ?: 0)
                            ?: currentSourceFocusRequester
                            ?: FocusRequester.Default
                        down = focusTargets.recommends.takeIf { hasRecommends }?.firstOrNull()
                            ?: focusTargets.backTop
                        left = focusTargets.episodeGroups.getOrNull((index - 1).coerceAtLeast(0))
                            ?: FocusRequester.Default
                        right = focusTargets.episodeGroups.getOrNull((index + 1).coerceAtMost(groups.lastIndex))
                            ?: FocusRequester.Default
                    }
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            // 分组获焦时只滚动定位，确认键才切换当前分组。
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

    LazyRow(
        state = episodeListState,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp),
        modifier = Modifier
            .height(76.dp)
            .padding(top = 4.dp),
    ) {
        items(selectedGroup.episodes.size, key = { index -> selectedGroup.episodes[index].episodeId }) { index ->
            val episode = selectedGroup.episodes[index]
            NcatEpisodeChip(
                label = episode.label,
                selected = episode.selected,
                focusRequester = focusTargets.episodes.getOrNull(episode.episodeIndex),
                modifier = Modifier
                    .focusProperties {
                        up = currentSourceFocusRequester ?: FocusRequester.Default
                        down = focusTargets.episodeGroups.getOrNull(selectedGroup.groupIndex)
                            ?: focusTargets.recommends.firstOrNull()
                            ?: focusTargets.backTop
                        left = focusTargets.episodes.getOrNull((episode.episodeIndex - 1).coerceAtLeast(0))
                            ?: FocusRequester.Default
                        right = focusTargets.episodes.getOrNull((episode.episodeIndex + 1).coerceAtMost(totalCount - 1))
                            ?: FocusRequester.Default
                    }
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            // 选集获焦时推动组内横向列表，保留左侧安全留白。
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
}

/**
 * 截图式分组选项。
 *
 * @param label 分组文案。
 * @param selected 是否选中。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onPressed 确认回调。
 */
@Composable
private fun NcatEpisodeGroupChoice(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val active = selected || isFocused
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.05f else 1f,
        animationSpec = tween(140),
        label = "ncatEpisodeGroupScale",
    )
    Column(
        modifier = modifier
            .width(180.dp)
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
            },
        horizontalAlignment = Alignment.Start,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(20.dp)
                .padding(top = 8.dp)
                .background(NcatSurface, RoundedCornerShape(3.dp)),
        ) {
            if (active) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(1f)
                        .height(20.dp)
                        .background(TvTokens.Accent, RoundedCornerShape(3.dp)),
                )
            }
        }
        Spacer(Modifier.height(18.dp))
        Text(
            text = label,
            color = if (active) TvTokens.Accent else Color.White.copy(alpha = 0.86f),
            fontSize = 24.sp,
            fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
        )
    }
}

/**
 * 选集短按钮。
 *
 * @param label 选集文案。
 * @param selected 是否选中。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onPressed 确认回调。
 */
@Composable
private fun NcatEpisodeChip(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val active = selected || isFocused
    Box(
        modifier = modifier
            .widthIn(min = 82.dp, max = 170.dp)
            .height(54.dp)
            .background(if (active) TvTokens.Accent else NcatSurface, RoundedCornerShape(NcatRadius))
            .border(
                width = if (isFocused) 3.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(NcatRadius),
            )
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
            .padding(horizontal = 18.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 截图式推荐轨道。
 *
 * @param cards 推荐卡片。
 * @param focusTargets 焦点请求器。
 * @param listState 横向列表状态。
 */
@Composable
private fun NcatRecommendRail(
    cards: List<TvVideoCard>,
    focusTargets: TvDetailFocusTargets,
    listState: LazyListState,
) {
    val scrollScope = rememberCoroutineScope()
    NcatSectionHeader(
        title = "好片推荐",
        hint = null,
        topPadding = 34.dp,
    )
    LazyRow(
        state = listState,
        horizontalArrangement = Arrangement.spacedBy(26.dp),
        contentPadding = PaddingValues(start = 46.dp, end = 46.dp),
        modifier = Modifier.height(320.dp),
    ) {
        items(cards.size, key = { index -> cards[index].source + "::" + cards[index].id + "::" + index }) { index ->
            val card = cards[index]
            NcatRecommendCard(
                card = card,
                focusRequester = focusTargets.recommends.getOrNull(index),
                modifier = Modifier
                    .focusProperties {
                        up = focusTargets.episodeGroups.firstOrNull()
                            ?: focusTargets.episodes.firstOrNull()
                            ?: FocusRequester.Default
                        down = focusTargets.backTop
                        left = focusTargets.recommends.getOrNull((index - 1).coerceAtLeast(0)) ?: FocusRequester.Default
                        right = focusTargets.recommends.getOrNull((index + 1).coerceAtMost(cards.lastIndex))
                            ?: FocusRequester.Default
                    }
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            // 推荐获焦时滚到安全可见区域，沿用详情横向列表策略。
                            scrollDetailOptionIntoView(
                                listState = listState,
                                focusedIndex = index,
                                itemCount = cards.size,
                                scrollScope = scrollScope,
                            )
                        }
                    },
            )
        }
    }
}

/**
 * 截图式推荐卡。
 *
 * @param card 推荐数据。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 */
@Composable
private fun NcatRecommendCard(
    card: TvVideoCard,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.06f else 1f,
        animationSpec = tween(140),
        label = "ncatRecommendScale",
    )
    Column(
        modifier = modifier
            .width(170.dp)
            .scale(scale),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(
            modifier = Modifier
                .width(170.dp)
                .height(240.dp)
                .clip(RoundedCornerShape(10.dp))
                .border(
                    width = if (isFocused) 3.dp else 0.dp,
                    color = if (isFocused) Color.White else Color.Transparent,
                    shape = RoundedCornerShape(10.dp),
                )
                .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
                .focusable(interactionSource = interactionSource),
        ) {
            if (card.posterUrl.isNotBlank()) {
                AsyncImage(
                    model = card.posterUrl,
                    contentDescription = card.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                NcatPosterPlaceholder()
            }
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(56.dp)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.72f)),
                        ),
                    ),
            )
            Text(
                text = cardEpisodeText(card),
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 14.dp, bottom = 10.dp, end = 10.dp),
            )
        }
        Text(
            text = card.title,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 推荐空封面占位。
 */
@Composable
private fun NcatPosterPlaceholder() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFE9E9E9)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "网飞猫",
            color = Color(0xFFCACDD2),
            fontSize = 24.sp,
            fontWeight = FontWeight.ExtraBold,
        )
    }
}

/**
 * 截图式底部动作。
 *
 * @param focusTargets 焦点请求器。
 * @param onHistoryClick 历史入口回调。
 * @param onExitClick 退出或随机回调。
 */
@Composable
private fun NcatBottomActions(
    focusTargets: TvDetailFocusTargets,
    onHistoryClick: (() -> Unit)?,
    onExitClick: (() -> Unit)?,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 18.dp, bottom = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(30.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(36.dp)) {
            NcatBottomPill(
                label = "♤ 返回顶部",
                focusRequester = focusTargets.backTop,
                modifier = Modifier.focusProperties {
                    up = focusTargets.recommends.firstOrNull()
                        ?: focusTargets.episodeGroups.firstOrNull()
                        ?: focusTargets.episodes.firstOrNull()
                        ?: FocusRequester.Default
                    right = focusTargets.random
                },
                onClick = { onHistoryClick?.invoke() },
            )
            NcatBottomPill(
                label = "⦿ 随便看看",
                focusRequester = focusTargets.random,
                modifier = Modifier.focusProperties {
                    up = focusTargets.recommends.firstOrNull()
                        ?: focusTargets.episodeGroups.firstOrNull()
                        ?: focusTargets.episodes.firstOrNull()
                        ?: FocusRequester.Default
                    left = focusTargets.backTop
                },
                onClick = { onExitClick?.invoke() },
            )
        }
        Text(
            text = "按遥控器[返回键]回到顶部导航",
            color = Color.White.copy(alpha = 0.38f),
            fontSize = 18.sp,
        )
    }
}

/**
 * 底部胶囊按钮。
 *
 * @param label 展示文案。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onClick 点击回调。
 */
@Composable
private fun NcatBottomPill(
    label: String,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    TvFocusableCard(
        modifier = modifier
            .height(54.dp)
            .width(170.dp),
        focusRequesters = listOf(focusRequester),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF555963), RoundedCornerShape(28.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = label,
                color = Color.White.copy(alpha = 0.64f),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

/**
 * 区块标题。
 *
 * @param title 标题。
 * @param hint 提示文案。
 * @param topPadding 顶部间距。
 */
@Composable
private fun NcatSectionHeader(
    title: String,
    hint: String?,
    topPadding: Dp,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 46.dp, end = 46.dp, top = topPadding, bottom = 20.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 30.sp,
            fontWeight = FontWeight.ExtraBold,
        )
        if (!hint.isNullOrBlank()) {
            Spacer(Modifier.width(6.dp))
            Text(
                text = hint,
                color = NcatMutedText,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 状态面板包裹。
 *
 * @param kind 状态类型。
 * @param title 状态标题。
 * @param message 状态说明。
 * @param focusRequester 焦点请求器。
 */
@Composable
private fun NcatStateBlock(
    kind: TvStatePanelKind,
    title: String,
    message: String,
    focusRequester: FocusRequester?,
) {
    TvStatePanel(
        kind = kind,
        title = title,
        message = message,
        modifier = Modifier.padding(horizontal = 46.dp),
        contentFocusRequester = focusRequester,
    )
}

/**
 * 小型胶囊按钮。
 *
 * @param label 展示文案。
 * @param accent 是否红色强调。
 * @param onClick 点击回调。
 */
@Composable
private fun NcatSmallPill(
    label: String,
    accent: Boolean,
    onClick: () -> Unit,
) {
    TvFocusableCard(
        modifier = Modifier
            .height(40.dp)
            .widthIn(min = 82.dp),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .background(if (accent) TvTokens.Accent else NcatSurface, RoundedCornerShape(20.dp))
                .padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = label, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
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
 * 获取线路副标题。
 *
 * @param option 线路选项。
 * @return 副标题。
 */
private fun sourceDescription(option: TvDetailSourceOption): String {
    return when {
        option.label.contains("蓝光") -> "香港加速"
        option.label.contains("HN", ignoreCase = true) -> "中国大陆加速"
        option.episodeCount >= 20 -> "播放快/高清"
        else -> "秒播/4K"
    }
}

/**
 * 获取推荐卡片集数文案。
 *
 * @param card 推荐卡片。
 * @return 集数状态。
 */
private fun cardEpisodeText(card: TvVideoCard): String {
    return when {
        card.totalEpisodes > 0 && card.episodeIndex >= card.totalEpisodes -> "已完结"
        card.totalEpisodes > 0 && card.episodeIndex > 0 -> "第${card.episodeIndex}集"
        card.totalEpisodes > 0 -> "全${card.totalEpisodes}集"
        else -> "已完结"
    }
}

/**
 * 毫秒格式化为 `mm:ss`。
 *
 * @param valueMs 毫秒值。
 * @return 时间文案。
 */
private fun formatTime(valueMs: Long): String {
    val totalSeconds = (valueMs / 1000L).coerceAtLeast(0L)
    val minutes = totalSeconds / 60L
    val seconds = totalSeconds % 60L
    return "%02d:%02d".format(minutes, seconds)
}

/**
 * 播放网速格式化。
 *
 * @param bytesPerSecond 每秒字节数。
 * @return 网速文案。
 */
private fun formatSpeed(bytesPerSecond: Long): String {
    if (bytesPerSecond <= 0L) {
        return "0 KB/s"
    }
    val kb = bytesPerSecond / 1024f
    if (kb < 1024f) {
        return "%.0f KB/s".format(kb)
    }
    return "%.1f MB/s".format(kb / 1024f)
}
