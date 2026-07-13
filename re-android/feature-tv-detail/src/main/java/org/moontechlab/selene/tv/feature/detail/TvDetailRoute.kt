package org.moontechlab.selene.tv.feature.detail

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
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
import androidx.compose.ui.input.pointer.pointerInput
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
import org.moontechlab.selene.tv.core.design.layout.LocalTvDesignMetrics
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import org.moontechlab.selene.tv.core.design.layout.TvLayeredHorizontalFocusScroll
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/** TV 详情页截图版背景色。 */
private val NcatBackground = Color(0xFF11131C)

/** 右侧介绍卡片半透明底色。 */
private val NcatInfoPanelSurface = Color(0xCC1A1D27)

/** TV 详情页截图版卡片底色。 */
private val NcatSurface = Color(0xFF454852)

/** TV 详情页截图版弱文字色。 */
private val NcatMutedText = Color(0xFF9A9AA3)

/** TV 详情页截图版圆角。 */
private val NcatRadius = 8.dp

/**
 * 详情页左侧对齐竖线。
 *
 * Logo、预览播放器、区块标题、横向列表首卡共用。
 * 列表不通过外层 page padding 控制横向滚动，只靠 LazyRow contentPadding，
 * 因此向左滚出首屏时不会被页面边距二次夹死。
 */
private val NcatContentStartPadding = 32.dp

/**
 * 详情页右侧边距。
 *
 * 横向列表 end contentPadding 与之相同：滚到最右侧时末卡不贴屏。
 */
private val NcatContentEndPadding = 32.dp

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
 * @param onRecommendClick 相关推荐点击回调。
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
    onRecommendClick: ((TvVideoCard) -> Unit)? = null,
    playerSurface: (@Composable () -> Unit)? = null,
) {
    val detail = state.detail
    val focusTargets = rememberDetailFocusTargets(
        sourceCount = detail?.sources.orEmpty().size,
        episodeCount = state.currentSource?.episodes.orEmpty().size,
        episodeGroupCount = state.episodeGroups.size,
        recommendCount = state.recommendCards.size,
    )
    // 线路列表保持静态顺序：只刷新选中态，不把当前线路顶到首位。
    val sourceOptions = remember(detail?.sources, state.currentSourceId) {
        buildDetailSourceOptions(
            sources = detail?.sources.orEmpty(),
            currentSourceId = state.currentSourceId,
            pinCurrentSource = false,
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
    val designMetrics = LocalTvDesignMetrics.current
    val sourceListState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) {
        LazyListState()
    }
    val episodeListState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) {
        LazyListState()
    }
    val episodeGroupListState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) {
        LazyListState()
    }
    val recommendListState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) { LazyListState() }
    val detailScrollState = rememberScrollState()
    val detailScrollScope = rememberCoroutineScope()
    // 简介全屏浮层开关：摘要获焦确认后展示完整文案。
    var showDescriptionOverlay by rememberSaveable { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NcatBackground),
    ) {
        // 主海报固定铺满页面，不随详情内容滚动。
        NcatDetailBackdrop(posterUrl = detail?.posterUrl.orEmpty())

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(detailScrollState)
                .padding(bottom = 80.dp),
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

            NcatDetailHero(
                state = state,
                focusTargets = focusTargets,
                currentSourceFocusRequester = currentSourceFocusRequester,
                onPlayPressed = onPlayPressed,
                onFavoriteToggle = onFavoriteToggle,
                onOpenDescription = { showDescriptionOverlay = true },
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
                    hasEpisodeGroupChoices = shouldShowDetailEpisodeGroupChoices(episodeGroups.size),
                    onRecommendClick = onRecommendClick,
                )
            }

            if (layoutSections.showBottomActions) {
                NcatBottomActions(
                    focusTargets = focusTargets,
                    hasEpisodeGroupChoices = shouldShowDetailEpisodeGroupChoices(episodeGroups.size),
                    onBackToTop = {
                        detailScrollScope.launch {
                            detailScrollState.animateScrollTo(0)
                        }
                    },
                    onExitClick = onExitClick,
                )
            }
        }

        if (showDescriptionOverlay) {
            NcatDescriptionOverlay(
                title = detail?.title.orEmpty(),
                description = detail?.description.orEmpty(),
                sourceName = detail?.sourceName.orEmpty(),
                posterUrl = detail?.posterUrl.orEmpty(),
                onDismiss = { showDescriptionOverlay = false },
            )
        }
    }
}

/**
 * TV 详情页焦点请求器集合。
 *
 * @property search 顶部搜索焦点。
 * @property login 顶部登录焦点。
 * @property player 预览播放器焦点。
 * @property description 简介摘要焦点。
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
    /** 简介摘要焦点，确认后打开全屏影片简介。 */
    val description: FocusRequester,
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
        description = remember { FocusRequester() },
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
/**
 * 详情页固定海报背景。
 *
 * 以主图/海报铺满整页，滚动内容层叠在上方，背景本身不随滚动移动。
 *
 * @param posterUrl 海报地址。
 */
@Composable
private fun NcatDetailBackdrop(posterUrl: String) {
    Box(modifier = Modifier.fillMaxSize()) {
        if (posterUrl.isNotBlank()) {
            AsyncImage(
                model = posterUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                // 轻微模糊，避免海报像素放大后的马赛克感。
                modifier = Modifier
                    .fillMaxSize()
                    .blur(radius = 18.dp),
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(NcatBackground),
            )
        }
        // 自上而下压暗，保证标题和线路文字可读。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.42f),
                            Color.Black.copy(alpha = 0.72f),
                            Color(0xF20B0D14),
                        ),
                    ),
                ),
        )
        // 左右微暗，避免边缘过亮干扰焦点描边。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.28f),
                            Color.Transparent,
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.34f),
                        ),
                    ),
                ),
        )
    }
}

@Composable
private fun NcatDetailTopBar(
    focusTargets: TvDetailFocusTargets,
    onSearchClick: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = NcatContentStartPadding,
                end = NcatContentEndPadding,
                top = 36.dp,
                bottom = 20.dp,
            ),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "IvyTV",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.6.sp,
            )
            Spacer(Modifier.width(14.dp))
            Box(
                modifier = Modifier
                    .width(1.dp)
                    .height(18.dp)
                    .background(Color.White.copy(alpha = 0.18f)),
            )
            Spacer(Modifier.width(14.dp))
            Text(
                text = "按返回键返回上一页  ·  全屏时按向下键打开播放设置",
                color = NcatMutedText,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatTopPill(
                label = "⌕ 搜索",
                width = 88.dp,
                focusRequester = focusTargets.search,
                modifier = Modifier.focusProperties {
                    down = focusTargets.player
                },
                onClick = { onSearchClick?.invoke() },
            )
            Text(
                text = remember { LocalTime.now().format(NcatTimeFormatter) },
                color = Color.White.copy(alpha = 0.86f),
                fontSize = 17.sp,
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
    width: Dp,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    NcatPillFocusButton(
        modifier = modifier.height(36.dp).width(width),
        focusRequester = focusRequester,
        cornerRadius = 19.dp,
        onClick = onClick,
    ) {
        Text(text = label, color = Color.White.copy(alpha = 0.88f), fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1)
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
    onOpenDescription: () -> Unit,
    playerSurface: (@Composable () -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = NcatContentStartPadding, end = NcatContentEndPadding),
        horizontalArrangement = Arrangement.spacedBy(28.dp),
        verticalAlignment = Alignment.Top,
    ) {
        NcatPreviewPanel(
            modifier = Modifier.weight(1f),
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
            onOpenDescription = onOpenDescription,
        )
    }
}

/**
 * 截图式预览播放器。
 *
 * @param title 当前标题。
 * @param sourceName 当前线路名称。
 * @param posterUrl 海报兜底地址。
 * @param modifier 外层修饰器。
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
    modifier: Modifier = Modifier,
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
        modifier = modifier
            .aspectRatio(16f / 9f)
            // 主预览区大圆角，贴近截图卡片。
            .clip(RoundedCornerShape(18.dp))
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) Color.White else Color.White.copy(alpha = 0.12f),
                shape = RoundedCornerShape(18.dp),
            )
            .focusRequester(focusTargets.player)
            .focusProperties {
                up = focusTargets.search
                right = focusTargets.description
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
                .padding(horizontal = 19.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // 仅保留品牌名，不展示外部网址。
            Text(
                text = "IvyTV",
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
            )
            Box(
                modifier = Modifier
                    .width(240.dp)
                    .height(1.dp)
                    .background(TvTokens.Accent.copy(alpha = 0.45f)),
            )
            Text(
                text = if (sourceName.isBlank()) "精彩马上开始" else "精彩马上开始 · $sourceName",
                color = Color.White.copy(alpha = 0.9f),
                fontSize = 13.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            text = "提醒：请勿随意相信视频上广告、网址、电影、二维码等！",
            color = Color.White.copy(alpha = 0.86f),
            fontSize = 12.sp,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 23.dp, bottom = 20.dp),
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
                modifier = Modifier.size(25.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (previewNetworkSpeed > 0L) formatSpeed(previewNetworkSpeed) else "加载中",
                fontSize = 10.sp,
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
    val progress = (positionMs.toFloat() / durationMs.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
    // 贴底进度条：左播放态/当前时间，中红条，右总时长。
    Column(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color.Transparent,
                        Color.Black.copy(alpha = 0.55f),
                    ),
                ),
            )
            .padding(start = 12.dp, end = 12.dp, top = 18.dp, bottom = 10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = if (isPlaying) "▶" else "⏸",
                color = Color.White,
                fontSize = 11.sp,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = formatTime(positionMs),
                color = Color.White.copy(alpha = 0.96f),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
            )
            Spacer(Modifier.width(10.dp))
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(3.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.28f)),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress)
                        .height(3.dp)
                        .background(TvTokens.Accent, RoundedCornerShape(2.dp)),
                )
            }
            Spacer(Modifier.width(10.dp))
            Text(
                text = formatTime(durationMs),
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
            )
        }
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
    onOpenDescription: () -> Unit,
) {
    val detail = state.detail ?: return
    val descriptionText = detail.description.ifBlank { "暂无简介，切换线路后仍可继续播放。" }
    // 右侧介绍区：半透明圆角底块包住标题/标签/简介/操作；高度随内容自适应，避免裁切按钮文案。
    Column(
        modifier = modifier
            .background(NcatInfoPanelSurface, RoundedCornerShape(18.dp))
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.08f),
                shape = RoundedCornerShape(18.dp),
            )
            .padding(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = detail.title,
            color = Color.White,
            fontSize = 21.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(11.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatMetaBadge(label = "豆瓣：暂无评分", accent = true)
            if (detail.year.isNotBlank()) {
                NcatMetaBadge(label = detail.year, accent = false)
            }
            NcatMetaBadge(label = detail.sourceName.ifBlank { "中国大陆" }, accent = false)
            NcatMetaBadge(label = "剧情 / 奇幻 / 冒险", accent = false)
        }
        // 简介摘要可获焦：确认后打开全屏影片简介。
        val descriptionInteraction = remember { MutableInteractionSource() }
        val descriptionFocused by descriptionInteraction.collectIsFocusedAsState()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp)
                .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                .border(
                    width = if (descriptionFocused) 2.dp else 0.dp,
                    color = if (descriptionFocused) Color.White else Color.Transparent,
                    shape = RoundedCornerShape(12.dp),
                )
                .focusRequester(focusTargets.description)
                .focusProperties {
                    up = focusTargets.search
                    left = focusTargets.player
                    down = focusTargets.fullscreen
                }
                .focusable(interactionSource = descriptionInteraction)
                .ncatClickable(onOpenDescription)
                .onPreviewKeyEvent { event ->
                    if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                    if (
                        event.key == Key.Enter ||
                        event.key == Key.DirectionCenter ||
                        event.key == Key.NumPadEnter ||
                        event.key == Key.Spacebar
                    ) {
                        onOpenDescription()
                        true
                    } else {
                        false
                    }
                },
        ) {
            Text(
                text = descriptionText,
                color = Color.White.copy(alpha = 0.78f),
                fontSize = 12.sp,
                lineHeight = 19.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 13.dp, top = 12.dp, end = 52.dp, bottom = 12.dp),
            )
            Box(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(end = 8.dp)
                    .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 8.dp),
            ) {
                Text(text = "简介", color = Color.White.copy(alpha = 0.78f), fontSize = 11.sp)
            }
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NcatActionTile(
                label = "全屏",
                selected = false,
                focusRequester = focusTargets.fullscreen,
                modifier = Modifier.focusProperties {
                    up = focusTargets.description
                    left = focusTargets.player
                    right = focusTargets.favorite
                    down = currentSourceFocusRequester ?: FocusRequester.Default
                },
                onPressed = { onPlayPressed?.invoke() },
                iconContent = { NcatFullscreenGlyph(modifier = Modifier.size(22.dp), color = Color.White) },
            )
            NcatActionTile(
                // 收藏态只变心形颜色，文案固定“收藏”，贴近目标截图。
                label = "收藏",
                selected = state.isFavorite,
                focusRequester = focusTargets.favorite,
                modifier = Modifier.focusProperties {
                    up = focusTargets.description
                    left = focusTargets.fullscreen
                    right = focusTargets.favorite
                    down = currentSourceFocusRequester ?: FocusRequester.Default
                },
                onPressed = { onFavoriteToggle?.invoke() },
                iconContent = {
                    NcatFavoriteGlyph(
                        modifier = Modifier.size(22.dp),
                        favorited = state.isFavorite,
                    )
                },
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
            .height(27.dp)
            .background(if (accent) TvTokens.Accent else NcatSurface, RoundedCornerShape(3.dp))
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
    }
}

/**
 * Hero 操作按钮：上方图标，下方文案。
 *
 * @param label 按钮下方文案，例如“全屏”“收藏”“已收藏”。
 * @param selected 是否选中（收藏态）。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param icon 可选字符图标。
 * @param iconContent 自定义矢量图标。
 * @param onPressed 确认回调。
 */
@Composable
private fun NcatActionTile(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    icon: String? = null,
    iconContent: (@Composable () -> Unit)? = null,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    // 对齐目标截图：深灰圆角方块，上图标下文案；获焦白边。
    val shape = RoundedCornerShape(12.dp)
    val background = Color(0xFF3A3D48)
    val borderColor = when {
        isFocused -> Color.White
        else -> Color.White.copy(alpha = 0.08f)
    }
    Column(
        modifier = modifier
            .width(72.dp)
            .height(72.dp)
            .background(background, shape)
            .border(BorderStroke(if (isFocused) 2.dp else 1.dp, borderColor), shape)
            .focusRequester(focusRequester)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter || event.key == Key.NumPadEnter || event.key == Key.Spacebar) {
                    onPressed(); true
                } else false
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier.size(24.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (iconContent != null) {
                iconContent()
            } else if (icon != null) {
                Text(
                    text = icon,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = label,
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
        )
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
    var activeFocusedIndex by remember { mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex) }
    NcatSectionHeader(
        title = "切换线路",
        hint = "遇播放卡顿，音画不同步或无法播放时，请切换播放线路或播放内核",
        topPadding = 32.dp,
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
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(start = NcatContentStartPadding, end = NcatContentEndPadding),
        modifier = Modifier.height(77.dp),
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
                            val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                previousActiveIndex = activeFocusedIndex,
                                newlyFocusedIndex = index,
                            )
                            activeFocusedIndex = index
                            if (shouldScroll) {
                                scrollDetailOptionIntoView(
                                    listState = listState,
                                    focusedIndex = index,
                                    itemCount = sourceOptions.size,
                                    scrollScope = scrollScope,
                                )
                            }
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
    // 仅“已选线路”用红色底；获焦未选中只加白描边，避免整行都变红。
    val selected = option.selected
    val activeBackground = selected || isFocused
    Box(
        modifier = modifier
            .width(163.dp)
            .height(69.dp)
            .background(
                color = when {
                    selected -> TvTokens.Accent
                    isFocused -> NcatSurface.copy(alpha = 0.98f)
                    else -> NcatSurface
                },
                shape = RoundedCornerShape(NcatRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(NcatRadius),
            )
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
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
        // 左上角“多集”角标，对齐目标截图。
        if (option.episodeCount > 1) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 0.dp, top = 0.dp)
                    .background(
                        color = if (selected) Color.White.copy(alpha = 0.22f) else Color(0xFF5B2B7A),
                        shape = RoundedCornerShape(topStart = NcatRadius, bottomEnd = 6.dp),
                    )
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            ) {
                Text(
                    text = "多集",
                    color = Color.White,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 14.dp, start = 8.dp, end = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                // 后台名称若已带胶片符号，这里不再重复追加。
                text = formatSourceCardTitle(option.label, option.trailingText),
                color = if (activeBackground) Color.White else Color.White.copy(alpha = 0.78f),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                // 选中：当前线路 · 推荐；未选中：高清。
                text = if (option.selected) "当前线路 · 推荐" else "高清",
                color = if (selected) Color.White.copy(alpha = 0.92f) else Color.White.copy(alpha = 0.50f),
                fontSize = 12.sp,
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
    // 选集行：上下切层时保留横向偏移，不复位。
    var activeEpisodeFocusedIndex by remember {
        mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex)
    }
    // 分组行：上下切层时同样 keep-offset。
    var activeGroupFocusedIndex by remember {
        mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex)
    }
    val totalCount = groups.sumOf { group -> group.episodes.size }
    val showGroupChoices = shouldShowDetailEpisodeGroupChoices(groups.size)
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

    // 早版布局：选集在上，分组在下；长剧集时下方才出现分组条。
    LazyRow(
        state = episodeListState,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(start = NcatContentStartPadding, end = NcatContentEndPadding),
        modifier = Modifier
            .height(62.dp)
            .padding(top = 3.dp),
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
                        // 有分组时下键进分组；否则进推荐/底部。
                        down = focusTargets.episodeGroups
                            .getOrNull(selectedGroup.groupIndex)
                            .takeIf { showGroupChoices }
                            ?: focusTargets.recommends.firstOrNull()
                            ?: focusTargets.backTop
                        left = focusTargets.episodes.getOrNull((episode.episodeIndex - 1).coerceAtLeast(0))
                            ?: FocusRequester.Default
                        right = focusTargets.episodes.getOrNull(
                            (episode.episodeIndex + 1).coerceAtMost(totalCount - 1),
                        ) ?: FocusRequester.Default
                    }
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                previousActiveIndex = activeEpisodeFocusedIndex,
                                newlyFocusedIndex = index,
                            )
                            activeEpisodeFocusedIndex = index
                            if (shouldScroll) {
                                scrollDetailOptionIntoView(
                                    listState = episodeListState,
                                    focusedIndex = index,
                                    itemCount = selectedGroup.episodes.size,
                                    scrollScope = scrollScope,
                                )
                            }
                        }
                    },
                onPressed = { onEpisodeSelected?.invoke(episode.episodeId) },
            )
        }
    }

    if (showGroupChoices) {
        LazyRow(
            state = episodeGroupListState,
            horizontalArrangement = Arrangement.spacedBy(17.dp),
            contentPadding = PaddingValues(start = NcatContentStartPadding, end = NcatContentEndPadding),
            modifier = Modifier
                .height(61.dp)
                .padding(top = 12.dp),
        ) {
            items(groups.size, key = { index -> groups[index].groupIndex }) { index ->
                val group = groups[index]
                NcatEpisodeGroupChoice(
                    label = group.label,
                    selected = group.selected,
                    focusRequester = focusTargets.episodeGroups.getOrNull(index),
                    modifier = Modifier
                        .focusProperties {
                            // 分组在选集下方：上键回选集，下键去推荐。
                            up = currentEpisodeFocusRequester
                                ?: focusTargets.episodes.getOrNull(
                                    group.episodes.firstOrNull()?.episodeIndex ?: 0,
                                )
                                ?: currentSourceFocusRequester
                                ?: FocusRequester.Default
                            down = focusTargets.recommends.takeIf { hasRecommends }?.firstOrNull()
                                ?: focusTargets.backTop
                            left = focusTargets.episodeGroups.getOrNull((index - 1).coerceAtLeast(0))
                                ?: FocusRequester.Default
                            right = focusTargets.episodeGroups.getOrNull(
                                (index + 1).coerceAtMost(groups.lastIndex),
                            ) ?: FocusRequester.Default
                        }
                        .onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                    previousActiveIndex = activeGroupFocusedIndex,
                                    newlyFocusedIndex = index,
                                )
                                activeGroupFocusedIndex = index
                                // 分组移动即切换，无需再按确认。
                                if (!group.selected) {
                                    onGroupSelected?.invoke(group.groupIndex)
                                }
                                if (shouldScroll) {
                                    scrollDetailOptionIntoView(
                                        listState = episodeGroupListState,
                                        focusedIndex = index,
                                        itemCount = groups.size,
                                        scrollScope = scrollScope,
                                    )
                                }
                            }
                        },
                    // 保留确认键切换，兼容鼠标点击。
                    onPressed = { onGroupSelected?.invoke(group.groupIndex) },
                )
            }
        }
    }
}

/**
 * 截图式选集分组选项。
 *
 * @param label 分组文案。
 * @param selected 是否当前分组。
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
            .widthIn(min = 60.dp)
            .scale(scale)
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
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
                .height(13.dp)
                .padding(top = 5.dp)
                .background(NcatSurface, RoundedCornerShape(2.dp)),
        ) {
            if (active) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(1f)
                        .height(13.dp)
                        .background(TvTokens.Accent, RoundedCornerShape(2.dp)),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Text(
            text = label,
            color = if (active) TvTokens.Accent else Color.White.copy(alpha = 0.86f),
            fontSize = 16.sp,
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
            .widthIn(min = 56.dp)
            .height(48.dp)
            .background(if (active) TvTokens.Accent else NcatSurface, RoundedCornerShape(NcatRadius))
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) Color.White else Color.Transparent,
                shape = RoundedCornerShape(NcatRadius),
            )
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) {
                    onPressed()
                    true
                } else {
                    false
                }
            }
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

/**
 * 截图式推荐轨道。
 *
 * @param cards 推荐卡片。
 * @param focusTargets 焦点请求器。
 * @param listState 横向列表状态。
 * @param hasEpisodeGroupChoices 是否展示选集分组切换条。
 * @param onRecommendClick 推荐卡点击回调。
 */
@Composable
private fun NcatRecommendRail(
    cards: List<TvVideoCard>,
    focusTargets: TvDetailFocusTargets,
    listState: LazyListState,
    hasEpisodeGroupChoices: Boolean,
    onRecommendClick: ((TvVideoCard) -> Unit)? = null,
) {
    val scrollScope = rememberCoroutineScope()
    var activeFocusedIndex by remember { mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex) }
    // 相关推荐左右边距对齐全局横向列表契约，首屏刚好放下 PosterColumns 列。
    // 相关推荐与线路/选集共用详情页内容竖线，滚动由 LazyRow contentPadding 单独控制。
    val recommendStartPadding = NcatContentStartPadding
    val recommendEndPadding = NcatContentEndPadding
    val recommendSpacing = TvTokens.CardSpacing
    NcatSectionHeader(
        title = "相关推荐",
        hint = null,
        topPadding = 23.dp,
    )
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        // 按当前视口宽度反推卡片宽高，避免写死 113.dp 导致列数漂移。
        val cardWidth = TvListLayoutMetrics.resolvePosterRailItemWidth(
            viewportWidth = maxWidth,
            startPadding = recommendStartPadding,
            endPadding = recommendEndPadding,
            spacing = recommendSpacing,
            columns = TvListLayoutMetrics.PosterColumns,
        )
        val coverHeight = TvListLayoutMetrics.resolvePosterCoverHeight(cardWidth)
        // 封面 + 标题行 + 间距，获焦放大后仍有轻微纵向余量。
        val railHeight = coverHeight + 36.dp
        LazyRow(
            state = listState,
            horizontalArrangement = Arrangement.spacedBy(recommendSpacing),
            contentPadding = PaddingValues(
                start = recommendStartPadding,
                end = recommendEndPadding,
            ),
            modifier = Modifier.height(railHeight),
        ) {
            items(cards.size, key = { index -> cards[index].source + "::" + cards[index].id + "::" + index }) { index ->
                val card = cards[index]
                NcatRecommendCard(
                    card = card,
                    cardWidth = cardWidth,
                    coverHeight = coverHeight,
                    focusRequester = focusTargets.recommends.getOrNull(index),
                    onPressed = { onRecommendClick?.invoke(card) },
                    modifier = Modifier
                        .focusProperties {
                            up = focusTargets.episodeGroups
                                .firstOrNull()
                                .takeIf { hasEpisodeGroupChoices }
                                ?: focusTargets.episodes.firstOrNull()
                                ?: FocusRequester.Default
                            down = focusTargets.backTop
                            left = focusTargets.recommends.getOrNull((index - 1).coerceAtLeast(0)) ?: FocusRequester.Default
                            right = focusTargets.recommends.getOrNull((index + 1).coerceAtMost(cards.lastIndex))
                                ?: FocusRequester.Default
                        }
                        .onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                    previousActiveIndex = activeFocusedIndex,
                                    newlyFocusedIndex = index,
                                )
                                activeFocusedIndex = index
                                if (shouldScroll) {
                                    scrollDetailOptionIntoView(
                                        listState = listState,
                                        focusedIndex = index,
                                        itemCount = cards.size,
                                        scrollScope = scrollScope,
                                    )
                                }
                            }
                        },
                )
            }
        }
    }
}

/**
 * 截图式推荐卡。
 *
 * @param card 推荐数据。
 * @param cardWidth 由全局 7 列密度反推的卡片宽度。
 * @param coverHeight 与首页海报同比例的封面高度。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onPressed 确认/点击回调。
 */
@Composable
private fun NcatRecommendCard(
    card: TvVideoCard,
    cardWidth: Dp,
    coverHeight: Dp,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onPressed: (() -> Unit)? = null,
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
            .width(cardWidth)
            .scale(scale),
        verticalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Box(
            modifier = Modifier
                .width(cardWidth)
                .height(coverHeight)
                .clip(RoundedCornerShape(7.dp))
                .border(
                    width = if (isFocused) 2.dp else 0.dp,
                    color = if (isFocused) Color.White else Color.Transparent,
                    shape = RoundedCornerShape(7.dp),
                )
                .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
                .focusable(interactionSource = interactionSource)
                .then(if (onPressed != null) Modifier.ncatClickable(onPressed) else Modifier)
                .onPreviewKeyEvent { event ->
                    if (onPressed == null || event.type != KeyEventType.KeyUp) {
                        return@onPreviewKeyEvent false
                    }
                    if (
                        event.key == Key.Enter ||
                        event.key == Key.DirectionCenter ||
                        event.key == Key.NumPadEnter ||
                        event.key == Key.Spacebar
                    ) {
                        onPressed()
                        true
                    } else {
                        false
                    }
                },
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
                    .height(37.dp)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.72f)),
                        ),
                    ),
            )
            Text(
                text = cardEpisodeText(card),
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 9.dp, bottom = 7.dp, end = 7.dp),
            )
        }
        Text(
            text = card.title,
            color = Color.White,
            fontSize = 13.sp,
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
            text = "IvyTV",
            color = Color(0xFFCACDD2),
            fontSize = 16.sp,
            fontWeight = FontWeight.ExtraBold,
        )
    }
}

/**
 * 截图式底部动作。
 *
 * @param focusTargets 焦点请求器。
 * @param hasEpisodeGroupChoices 是否展示选集分组切换条。
 * @param onHistoryClick 历史入口回调。
 * @param onExitClick 退出或随机回调。
 */
@Composable
private fun NcatBottomActions(
    focusTargets: TvDetailFocusTargets,
    hasEpisodeGroupChoices: Boolean,
    onBackToTop: () -> Unit,
    onExitClick: (() -> Unit)?,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 24.dp, bottom = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(36.dp)) {
            NcatBottomPill(
                label = "返回顶部",
                leadingIcon = { NcatBottomActionGlyph(kind = NcatBottomActionIcon.BackToTop) },
                focusRequester = focusTargets.backTop,
                modifier = Modifier.focusProperties {
                    up = focusTargets.recommends.firstOrNull()
                        ?: focusTargets.episodeGroups.firstOrNull().takeIf { hasEpisodeGroupChoices }
                        ?: focusTargets.episodes.firstOrNull()
                        ?: FocusRequester.Default
                    right = focusTargets.random
                },
                onClick = onBackToTop,
            )
            NcatBottomPill(
                label = "随便看看",
                leadingIcon = { NcatBottomActionGlyph(kind = NcatBottomActionIcon.RandomBrowse) },
                focusRequester = focusTargets.random,
                modifier = Modifier.focusProperties {
                    up = focusTargets.recommends.firstOrNull()
                        ?: focusTargets.episodeGroups.firstOrNull().takeIf { hasEpisodeGroupChoices }
                        ?: focusTargets.episodes.firstOrNull()
                        ?: FocusRequester.Default
                    left = focusTargets.backTop
                },
                onClick = { onExitClick?.invoke() },
            )
        }
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
    leadingIcon: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    NcatPillFocusButton(
        modifier = modifier.height(36.dp).width(128.dp),
        focusRequester = focusRequester,
        cornerRadius = 19.dp,
        onClick = onClick,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            leadingIcon?.invoke()
            Text(text = label, color = Color.White.copy(alpha = 0.88f), fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1)
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
            .padding(
                start = NcatContentStartPadding,
                end = NcatContentEndPadding,
                top = topPadding,
                bottom = 14.dp,
            ),
        // 红竖线与主标题垂直居中对齐，副文案跟随同一中线。
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                // 高度贴近 20sp 加粗主标题视觉字高，避免顶到底看起来偏长。
                .width(3.dp)
                .height(18.dp)
                .background(TvTokens.Accent, RoundedCornerShape(1.5.dp)),
        )
        Spacer(Modifier.width(10.dp))
        Text(
            text = title,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.ExtraBold,
            maxLines = 1,
        )
        if (!hint.isNullOrBlank()) {
            Spacer(Modifier.width(8.dp))
            Text(
                text = hint,
                color = NcatMutedText,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
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
        modifier = Modifier.padding(start = NcatContentStartPadding, end = NcatContentEndPadding),
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
            .height(27.dp)
            .widthIn(min = 55.dp),
        onPressed = onClick,
    ) {
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .background(if (accent) TvTokens.Accent else NcatSurface, RoundedCornerShape(13.dp))
                .padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = label, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        }
    }
}

/**
 * 详情页自绘焦点控件的点击手势。
 *
 * @param onPressed 点击确认回调。
 * @return 支持鼠标和触摸点击的修饰器。
 */
private fun Modifier.ncatClickable(onPressed: () -> Unit): Modifier {
    return pointerInput(onPressed) {
        detectTapGestures(
            onTap = {
                // 模拟器鼠标点击和真实触摸都走同一套确认逻辑。
                onPressed()
            },
        )
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

@Composable
private fun NcatPillFocusButton(
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester,
    cornerRadius: Dp,
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(cornerRadius)
    Box(
        modifier = modifier
            .background(brush = Brush.horizontalGradient(listOf(Color(0xFF3A4150), Color(0xFF2B313D))), shape = shape)
            .border(width = if (isFocused) 2.dp else 1.dp, color = if (isFocused) Color.White else Color.White.copy(alpha = 0.08f), shape = shape)
            .focusRequester(focusRequester)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onClick)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter || event.key == Key.NumPadEnter || event.key == Key.Spacebar) {
                    onClick(); true
                } else false
            },
        contentAlignment = Alignment.Center,
    ) { content() }
}

private enum class NcatBottomActionIcon { BackToTop, RandomBrowse }

@Composable
private fun NcatBottomActionGlyph(kind: NcatBottomActionIcon, modifier: Modifier = Modifier.size(16.dp)) {
    Canvas(modifier = modifier) {
        val stroke = 1.8.dp.toPx()
        val color = Color.White.copy(alpha = 0.9f)
        when (kind) {
            NcatBottomActionIcon.BackToTop -> {
                val midX = size.width / 2f
                drawLine(color, Offset(midX, size.height * 0.78f), Offset(midX, size.height * 0.28f), stroke, StrokeCap.Square)
                drawLine(color, Offset(midX, size.height * 0.28f), Offset(size.width * 0.28f, size.height * 0.52f), stroke, StrokeCap.Square)
                drawLine(color, Offset(midX, size.height * 0.28f), Offset(size.width * 0.72f, size.height * 0.52f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.22f, size.height * 0.18f), Offset(size.width * 0.78f, size.height * 0.18f), stroke, StrokeCap.Square)
            }
            NcatBottomActionIcon.RandomBrowse -> {
                drawLine(color, Offset(size.width * 0.18f, size.height * 0.34f), Offset(size.width * 0.72f, size.height * 0.34f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.72f, size.height * 0.34f), Offset(size.width * 0.55f, size.height * 0.18f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.72f, size.height * 0.34f), Offset(size.width * 0.55f, size.height * 0.50f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.82f, size.height * 0.66f), Offset(size.width * 0.28f, size.height * 0.66f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.28f, size.height * 0.66f), Offset(size.width * 0.45f, size.height * 0.50f), stroke, StrokeCap.Square)
                drawLine(color, Offset(size.width * 0.28f, size.height * 0.66f), Offset(size.width * 0.45f, size.height * 0.82f), stroke, StrokeCap.Square)
            }
        }
    }
}


/**
 * 全屏影片简介浮层。
 *
 * @param title 影片标题。
 * @param description 完整简介。
 * @param sourceName 线路/来源名。
 * @param posterUrl 背景海报。
 * @param onDismiss 关闭回调。
 */
@Composable
private fun NcatDescriptionOverlay(
    title: String,
    description: String,
    sourceName: String,
    posterUrl: String,
    onDismiss: () -> Unit,
) {
    val closeRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { closeRequester.requestFocus() }
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.72f))
            .focusable()
            .onPreviewKeyEvent { event ->
                // 浮层打开时拦截返回，只关闭简介不退出详情。
                if (
                    event.type == KeyEventType.KeyUp &&
                    (event.key == Key.Back || event.key == Key.Escape)
                ) {
                    onDismiss()
                    true
                } else {
                    false
                }
            }
            .ncatClickable(onDismiss),
    ) {
        // 背景海报弱化，突出左侧文案。
        if (posterUrl.isNotBlank()) {
            AsyncImage(
                model = posterUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .blur(radius = 12.dp),
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.62f)),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(
                    start = NcatContentStartPadding,
                    end = NcatContentEndPadding,
                    top = 36.dp,
                    bottom = 36.dp,
                ),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "影片简介",
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.ExtraBold,
                    )
                    Spacer(modifier = Modifier.width(14.dp))
                    Text(
                        text = "按[返回键]退出本页",
                        color = NcatMutedText,
                        fontSize = 13.sp,
                    )
                }
                Box(
                    modifier = Modifier
                        .size(42.dp)
                        .background(TvTokens.Accent, RoundedCornerShape(21.dp))
                        .border(BorderStroke(2.dp, Color.White), RoundedCornerShape(21.dp))
                        .focusRequester(closeRequester)
                        .focusable()
                        .ncatClickable(onDismiss)
                        .onPreviewKeyEvent { event ->
                            if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                            if (
                                event.key == Key.Enter ||
                                event.key == Key.DirectionCenter ||
                                event.key == Key.Back ||
                                event.key == Key.Escape
                            ) {
                                onDismiss()
                                true
                            } else {
                                false
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = "×", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(modifier = Modifier.height(28.dp))
            Text(
                text = title.ifBlank { "影片简介" },
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.ExtraBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (sourceName.isNotBlank()) {
                Spacer(modifier = Modifier.height(14.dp))
                NcatMetaBadge(label = sourceName, accent = false)
            }
            Spacer(modifier = Modifier.height(22.dp))
            Text(
                text = "影片简介",
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = description.ifBlank { "暂无简介，切换线路后仍可继续播放。" },
                color = Color.White.copy(alpha = 0.92f),
                fontSize = 15.sp,
                lineHeight = 24.sp,
            )
        }
    }
}

@Composable
private fun NcatFavoriteGlyph(modifier: Modifier = Modifier, favorited: Boolean) {
    val color = if (favorited) TvTokens.Accent else Color.White
    Canvas(modifier = modifier) {
        val stroke = 2.dp.toPx(); val width = size.width; val height = size.height
        val path = Path().apply {
            moveTo(width * 0.50f, height * 0.88f)
            cubicTo(width * 0.22f, height * 0.70f, width * 0.06f, height * 0.48f, width * 0.08f, height * 0.30f)
            cubicTo(width * 0.10f, height * 0.14f, width * 0.24f, height * 0.08f, width * 0.36f, height * 0.12f)
            cubicTo(width * 0.44f, height * 0.15f, width * 0.48f, height * 0.24f, width * 0.50f, height * 0.30f)
            cubicTo(width * 0.52f, height * 0.24f, width * 0.56f, height * 0.15f, width * 0.64f, height * 0.12f)
            cubicTo(width * 0.76f, height * 0.08f, width * 0.90f, height * 0.14f, width * 0.92f, height * 0.30f)
            cubicTo(width * 0.94f, height * 0.48f, width * 0.78f, height * 0.70f, width * 0.50f, height * 0.88f)
            close()
        }
        if (favorited) drawPath(path = path, color = color, style = Fill)
        else drawPath(path = path, color = color, style = Stroke(width = stroke, cap = StrokeCap.Square, join = StrokeJoin.Miter))
    }
}

@Composable
private fun NcatFullscreenGlyph(modifier: Modifier = Modifier, color: Color = Color.White) {
    // 目标截图为圆角方框，不再使用四角展开箭头。
    Canvas(modifier = modifier) {
        val stroke = 2.dp.toPx()
        val inset = stroke
        val corner = size.minDimension * 0.18f
        drawRoundRect(
            color = color,
            topLeft = Offset(inset, inset),
            size = Size(size.width - inset * 2f, size.height - inset * 2f),
            cornerRadius = CornerRadius(corner, corner),
            style = Stroke(width = stroke, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
    }
}

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
    val alreadyAtTarget = listState.firstVisibleItemIndex == targetIndex &&
        (targetIndex != 0 || listState.firstVisibleItemScrollOffset == 0)
    if (alreadyAtTarget) return
    scrollScope.launch {
        listState.animateScrollToItem(index = targetIndex, scrollOffset = 0)
    }
}

/**
 * 获取线路副标题。
 *
 * @param option 线路选项。
 * @return 副标题。
 */

/**
 * 组装线路卡主标题。
 *
 * 后台名称本身可能已带 🎬/胶片符号，前端只在缺失时补一个，避免双图标。
 *
 * @param label 线路原始名称。
 * @param trailingText 集数后缀，例如（84）。
 * @return 展示标题。
 */
private fun formatSourceCardTitle(label: String, trailingText: String): String {
    val raw = label.trim()
    // 去掉后台可能重复下发的胶片符号，最后只保留一个。
    val stripped = raw
        .replace("🎬", "")
        .replace("🎞", "")
        .replace("🎥", "")
        .trim()
    return "🎬 $stripped$trailingText"
}

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


/**
 * 计算固定焦点槽对应的首个可见下标。
 */
internal fun resolveDetailPinnedFirstVisibleIndex(
    focusedIndex: Int,
    itemCount: Int,
    pinIndex: Int = 1,
): Int {
    if (itemCount <= 0 || focusedIndex <= pinIndex) return 0
    val safePin = pinIndex.coerceAtLeast(0)
    val maxFirst = (itemCount - 1 - safePin).coerceAtLeast(0)
    return (focusedIndex - safePin).coerceIn(0, maxFirst)
}
