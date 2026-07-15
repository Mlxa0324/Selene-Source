package org.moontechlab.selene.tv.feature.detail

import android.os.Build
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.animateScrollBy
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
import androidx.compose.foundation.layout.IntrinsicSize
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
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.compose.AsyncImagePainter
import coil.request.ImageRequest
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvEdgeShakeState
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.focus.consumeDirectionalKeyWithEdgeShake
import org.moontechlab.selene.tv.core.design.focus.rememberTvEdgeShakeState
import org.moontechlab.selene.tv.core.design.focus.tvEdgeShake
import org.moontechlab.selene.tv.core.design.layout.LocalTvDesignMetrics
import org.moontechlab.selene.tv.core.design.layout.TvCachedTitlePosterImage
import org.moontechlab.selene.tv.core.design.layout.TvEpisodePlaylistItem
import org.moontechlab.selene.tv.core.design.layout.TvEpisodePlaylistRail
import org.moontechlab.selene.tv.core.design.layout.TvLayeredHorizontalFocusScroll
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.TvPosterTitleUrlCache
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * 详情页纵向焦点跟滚宿主：嵌套 LazyRow 时 bringIntoView 常失效，改用窗口坐标 + ScrollState。
 */
private data class DetailVerticalScrollHost(
    val scrollState: ScrollState,
    val scope: CoroutineScope,
    val viewportBounds: () -> Rect?,
)

private val LocalDetailVerticalScroll = compositionLocalOf<DetailVerticalScrollHost?> { null }

/**
 * 详情纵向钉靠策略。
 */
private enum class DetailVerticalPin {
    /** 仅保证获焦项完整可见（上下安全边）。 */
    Visible,

    /** 顶部区（搜索/播放器/简介/全屏）：钉到 scroll=0。 */
    Top,

    /** 底部操作：钉到 scroll=max。 */
    Bottom,
}

/** TV 详情页截图版背景色。 */
private val NcatBackground = Color(0xFF11131C)

/** 右侧介绍卡片半透明底色。 */
private val NcatInfoPanelSurface = Color(0xCC1A1D27)

/**
 * 预览播放器舞台底色。
 *
 * 与右侧简介卡同系冷蓝黑，避免 [TvTokens.Surface] 偏青灰在详情页显得突兀。
 */
private val NcatPreviewStageBase = Color(0xFF171B26)

/** TV 详情页截图版卡片底色（略压暗，减少脏灰块感）。 */
private val NcatSurface = Color(0xFF2F3440)

/** 详情芯片获焦未选中时的抬升底色。 */
private val NcatSurfaceFocused = Color(0xFF3C4352)

/** TV 详情页截图版弱文字色。 */
private val NcatMutedText = Color(0xFF9A9AA3)

/** TV 详情页截图版圆角。 */
private val NcatRadius = 10.dp

// 按钮图标尺寸统一走 TvTokens.ActionIconSize / TopActionIconGlyph，与全局搜索胶囊一致。

/**
 * 详情页左侧对齐竖线。
 *
 * Logo、预览播放器、区块标题、横向列表首卡共用。
 * 列表不通过外层 page padding 控制横向滚动，只靠 LazyRow contentPadding，
 * 因此向左滚出首屏时不会被页面边距二次夹死。
 */
private val NcatContentStartPadding = 36.dp

/**
 * 详情页右侧边距。
 *
 * 横向列表 end contentPadding 与之相同：滚到最右侧时末卡不贴屏。
 */
private val NcatContentEndPadding = 36.dp

/** 详情右侧简介摘要背景框固定高度。 */
private val NcatDescriptionBoxHeight = 88.dp

/** 简介正文右侧预留给“简介”操作列的宽度，避免末行与按钮重叠。 */
private val NcatDescriptionBadgeReserve = 112.dp

/** 线路/选集内联状态卡高度，与线路卡视觉同高，避免大块灰板突兀。 */
private val NcatInlineStatusCardHeight = 70.dp

/** 线路/选集内联状态卡最小宽度。 */
private val NcatInlineStatusCardMinWidth = 240.dp

/** 影片简介浮层打开时，详情内容层使用的背景模糊半径。 */
private val NcatDescriptionBackdropBlurRadius = 12.dp

/** Android 8 至 11 不支持原生模糊时，详情内容层保留的弱可见度。 */
private const val NcatDescriptionLegacyContentAlpha = 0.12f

/** TV 详情页顶部右侧时间格式。 */
private val NcatTimeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

/**
 * 根据系统图形能力弱化影片简介下方的详情内容。
 *
 * Android 12 及以上使用原生模糊；旧系统将内容淡出，避免清晰文字与简介正文重叠。
 *
 * @param showOverlay 是否正在展示影片简介浮层。
 * @return 应用于详情内容层的视觉效果修饰器。
 */
private fun Modifier.ncatDescriptionBackdropEffect(showOverlay: Boolean): Modifier {
    // 浮层关闭时不创建额外图层，保持播放器和滚动内容的正常渲染成本。
    if (!showOverlay) return this
    // Android 12+ 支持 RenderEffect 模糊，旧系统改用淡出保障文字可读性。
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        blur(radius = NcatDescriptionBackdropBlurRadius)
    } else {
        alpha(NcatDescriptionLegacyContentAlpha)
    }
}

/**
 * TV 详情页 Route。
 *
 * @param state 详情页状态。
 * @param backgroundKey 设置页保存的基础背景标识。
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
    backgroundKey: String = "deep_blue",
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
    // 详情底色统一复用设置页背景标识，海报缺失时也保持用户选择的颜色。
    val detailBackgroundColor = TvTokens.resolveBackgroundColor(backgroundKey)
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
    val layoutSections = remember(
        detail?.sources,
        state.currentSource?.episodes,
        state.recommendCards,
        state.recommendLoadState,
    ) {
        buildDetailLayoutSections(
            sources = detail?.sources.orEmpty(),
            episodes = state.currentSource?.episodes.orEmpty(),
            recommends = state.recommendCards,
            // 加载中也占位展示，避免卡片到位后整段「一下子蹦出来」。
            recommendLoadState = state.recommendLoadState,
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
    val recommendListState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) { LazyListState() }
    val detailScrollState = rememberScrollState()
    val detailScrollScope = rememberCoroutineScope()
    // 简介全屏浮层开关：摘要获焦确认后展示完整文案。
    var showDescriptionOverlay by rememberSaveable { mutableStateOf(false) }
    // 「返回顶部」专用：记录切换线路分区在滚动内容中的 Y。
    var sourceSectionYPx by remember { mutableIntStateOf(0) }
    // 视口窗口坐标：焦点跟滚用 boundsInWindow 对比，不依赖嵌套 LazyRow 的 bringIntoView。
    var detailViewportCoords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val detailScrollHost = remember(detailScrollState, detailScrollScope) {
        DetailVerticalScrollHost(
            scrollState = detailScrollState,
            scope = detailScrollScope,
            viewportBounds = {
                detailViewportCoords?.takeIf { coords -> coords.isAttached }?.boundsInWindow()
            },
        )
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(detailBackgroundColor)
            .onGloballyPositioned { coordinates ->
                detailViewportCoords = coordinates
            },
    ) {
        // 主海报固定铺满页面，不随详情内容滚动。
        NcatDetailBackdrop(
            title = detail?.title.orEmpty(),
            posterUrl = detail?.posterUrl.orEmpty(),
            fallbackPosterUrl = state.backdropFallbackPosterUrl,
            backgroundColor = detailBackgroundColor,
        )

        CompositionLocalProvider(LocalDetailVerticalScroll provides detailScrollHost) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 只模糊下方详情内容，浮层作为同级上层继续保持清晰。
                .ncatDescriptionBackdropEffect(showDescriptionOverlay)
                .verticalScroll(detailScrollState)
                // 底栏安全留白：够焦点描边即可，避免滚到底时大块空白。
                .padding(bottom = 48.dp),
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
                previewFillColor = detailPreviewFillColor(detailBackgroundColor),
                onPlayPressed = onPlayPressed,
                onFavoriteToggle = onFavoriteToggle,
                onOpenDescription = { showDescriptionOverlay = true },
                playerSurface = playerSurface,
            )

            Column(
                modifier = Modifier.onGloballyPositioned { coordinates ->
                    // 仅供「返回顶部」按钮定位，焦点获焦不再强制纵向滚到顶/底。
                    sourceSectionYPx = coordinates.positionInParent().y.toInt().coerceAtLeast(0)
                },
            ) {
                NcatSourceRail(
                    sourceOptions = sourceOptions,
                    isSearching = state.isMoreSourcesLoading,
                    emptyPlaybackCompleted = state.emptyPlaybackCompleted,
                    focusTargets = focusTargets,
                    currentEpisodeFocusRequester = currentEpisodeFocusRequester,
                    listState = sourceListState,
                    onSourceSelected = onSourceSelected,
                )
            }

            NcatEpisodeGroupRail(
                groups = episodeGroups,
                episodes = state.currentSource?.episodes.orEmpty(),
                currentEpisodeId = state.currentEpisodeId,
                focusTargets = focusTargets,
                currentSourceFocusRequester = currentSourceFocusRequester,
                currentEpisodeFocusRequester = currentEpisodeFocusRequester,
                hasRecommends = layoutSections.showRecommends,
                onEpisodeSelected = onEpisodeSelected,
                onGroupSelected = onEpisodeGroupSelected,
            )

            if (layoutSections.showRecommends) {
                NcatRecommendRail(
                    cards = state.recommendCards,
                    loadState = state.recommendLoadState,
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
                            // 显式「返回顶部」：回到切换线路分区，不与焦点 bringIntoView 抢动画。
                            val target = sourceSectionYPx.coerceIn(0, detailScrollState.maxValue)
                            detailScrollState.animateScrollTo(target)
                        }
                    },
                    onExitClick = onExitClick,
                )
            }
        }
        } // CompositionLocalProvider

        if (showDescriptionOverlay) {
            NcatDescriptionOverlay(
                title = detail?.title.orEmpty(),
                description = detail?.description.orEmpty(),
                sourceName = detail?.sourceName.orEmpty(),
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
 * 封面策略：
 * - 入口/首张 [posterUrl] 粘住展示，数据源后到的图不立刻替换（避免切换动画）。
 * - 首张在超时内未成功，或加载失败，再尝试 [fallbackPosterUrl]。
 *
 * @param title 影片名，用于封面失败时同名 URL 回退。
 * @param posterUrl 入口或已锁定的主封面。
 * @param fallbackPosterUrl 数据源封面兜底。
 * @param backgroundColor 设置页选择的海报缺失兜底背景色。
 */
@Composable
private fun NcatDetailBackdrop(
    title: String,
    posterUrl: String,
    fallbackPosterUrl: String = "",
    backgroundColor: Color,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        // 底层兜底色：封面失败/无缓存时仍可见设置页背景。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(backgroundColor),
        )
        NcatStickyBackdropPoster(
            title = title,
            preferredPosterUrl = posterUrl,
            fallbackPosterUrl = fallbackPosterUrl,
            modifier = Modifier
                .fillMaxSize()
                // 轻微模糊，避免海报像素放大后的马赛克感。
                .blur(radius = 18.dp),
        )
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

/**
 * 详情背景粘性封面：入口/首张 URL 不因数据源后到而切换；超时或失败再兜底。
 *
 * @param title 片名（同名缓存键）。
 * @param preferredPosterUrl 入口或已锁定主封面。
 * @param fallbackPosterUrl 数据源封面兜底。
 * @param modifier 外层修饰。
 * @param loadTimeoutMs 主图未成功时切换兜底的超时毫秒。
 */
@Composable
private fun NcatStickyBackdropPoster(
    title: String,
    preferredPosterUrl: String,
    fallbackPosterUrl: String,
    modifier: Modifier = Modifier,
    loadTimeoutMs: Long = BACKDROP_POSTER_LOAD_TIMEOUT_MS,
) {
    val context = LocalContext.current
    val preferred = preferredPosterUrl.trim()
    val fallback = fallbackPosterUrl.trim()
    // 仅按片名粘住本页会话，不因 preferred 后到二次 remount 造成切换闪动。
    var activeUrl by remember(title) {
        mutableStateOf(
            preferred.ifBlank {
                TvPosterTitleUrlCache.resolvePrimaryUrl(title = title, posterUrl = "")
                    .orEmpty()
            },
        )
    }
    var loadSucceeded by remember(title) { mutableStateOf(false) }
    var timeoutFallbackTried by remember(title) { mutableStateOf(false) }
    var errorFallbackTried by remember(title) { mutableStateOf(false) }

    // 主 URL 从空补到非空（入口稍后带上封面）时只补一次，已有成功图不改。
    LaunchedEffect(preferred, title) {
        if (loadSucceeded) {
            return@LaunchedEffect
        }
        if (activeUrl.isBlank() && preferred.isNotBlank()) {
            activeUrl = preferred
        }
    }

    // 指定时间内主图未成功 → 尝试数据源兜底（仅一次）。
    LaunchedEffect(activeUrl, fallback, loadTimeoutMs, title) {
        if (loadSucceeded || timeoutFallbackTried || fallback.isBlank()) {
            return@LaunchedEffect
        }
        if (activeUrl.isBlank()) {
            timeoutFallbackTried = true
            activeUrl = fallback
            return@LaunchedEffect
        }
        if (activeUrl == fallback) {
            return@LaunchedEffect
        }
        delay(loadTimeoutMs)
        if (!loadSucceeded && !timeoutFallbackTried) {
            timeoutFallbackTried = true
            activeUrl = fallback
        }
    }

    val requestUrl = activeUrl.takeIf { url -> url.isNotBlank() }
    if (requestUrl == null) {
        return
    }
    val imageRequest = remember(requestUrl, title) {
        ImageRequest.Builder(context)
            .data(requestUrl)
            // 关闭 crossfade，避免主图/兜底切换时的显式动画。
            .crossfade(false)
            .build()
    }
    AsyncImage(
        model = imageRequest,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        // 以顶部为起点，再向下偏移总高度的 1/10。
        alignment = BiasAlignment(horizontalBias = 0f, verticalBias = -0.8f),
        modifier = modifier,
        onState = { state ->
            when (state) {
                is AsyncImagePainter.State.Success -> {
                    loadSucceeded = true
                    TvPosterTitleUrlCache.putSuccess(title = title, posterUrl = requestUrl)
                }
                is AsyncImagePainter.State.Error -> {
                    if (loadSucceeded) {
                        return@AsyncImage
                    }
                    // 失败：优先数据源兜底，再同名会话缓存。
                    if (!errorFallbackTried && fallback.isNotBlank() && fallback != requestUrl) {
                        errorFallbackTried = true
                        activeUrl = fallback
                        return@AsyncImage
                    }
                    val cached = TvPosterTitleUrlCache.resolveFallbackUrl(
                        title = title,
                        failedUrl = requestUrl,
                    )
                    if (cached != null && cached != requestUrl && cached != activeUrl) {
                        activeUrl = cached
                    }
                }
                else -> Unit
            }
        },
    )
}

/** 详情背景主封面加载超时后尝试数据源兜底。 */
private const val BACKDROP_POSTER_LOAD_TIMEOUT_MS = 2_500L

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
            // 样式与首页右上角快捷「搜索」对齐：胶囊 + 图标 + 自适应宽度。
            val searchEdgeShake = rememberTvEdgeShakeState()
            NcatTopPill(
                label = "搜索",
                leadingGlyph = "⌕",
                leadingGlyphSize = TvTokens.TopActionIconGlyph,
                focusRequester = focusTargets.search,
                modifier = Modifier
                    .tvEdgeShake(searchEdgeShake)
                    .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Top)
                    .focusProperties {
                        // 右列竖链：搜索 ↓ 进简介，不斜穿到左侧播放器。
                        down = focusTargets.description
                        // 顶行最上：上键不再逃出详情内容区。
                        up = FocusRequester.Cancel
                        left = focusTargets.player
                    }
                    .onPreviewKeyEvent { event ->
                        // 上键到底抖动（与 Cancel 配套）。
                        searchEdgeShake.consumeBoundaryKey(event = event, up = true)
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
 * 顶部胶囊按钮（对齐首页右上角快捷入口：高度 / 圆角 / 底色 / 描边）。
 *
 * @param label 展示文案。
 * @param leadingGlyph 文案前的图标字符。
 * @param leadingGlyphSize 图标字符字号。
 * @param focusRequester 焦点请求器。
 * @param modifier 外层修饰器。
 * @param onClick 点击回调。
 */
@Composable
private fun NcatTopPill(
    label: String,
    leadingGlyph: String? = null,
    leadingGlyphSize: TextUnit = TvTokens.TopActionIconGlyph,
    focusRequester: FocusRequester,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(TvTokens.TopActionRadius)
    val backgroundColor = if (isFocused) TvTokens.FocusFill else TvTokens.Surface
    Box(
        modifier = modifier
            .height(TvTokens.TopActionHeight)
            .clip(shape)
            .background(backgroundColor)
            .border(
                width = 2.dp,
                color = if (isFocused) TvTokens.FocusBorder else Color.Transparent,
                shape = shape,
            )
            .focusRequester(focusRequester)
            .onPreviewKeyEvent { event ->
                // 与首页快捷入口一致：确认键在 KeyDown 触发，避免仅 KeyUp 时无反应。
                val isConfirm = event.key == Key.Enter ||
                    event.key == Key.DirectionCenter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                if (!isConfirm) {
                    return@onPreviewKeyEvent false
                }
                if (event.type == KeyEventType.KeyDown) {
                    onClick()
                }
                true
            }
            .ncatClickable(onClick)
            .focusable(interactionSource = interactionSource)
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (!leadingGlyph.isNullOrBlank()) {
                Text(
                    text = leadingGlyph,
                    color = Color.White,
                    fontSize = leadingGlyphSize,
                    fontWeight = FontWeight.Bold,
                )
            }
            Text(
                text = label,
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
        }
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
    previewFillColor: Color,
    onPlayPressed: (() -> Unit)?,
    onFavoriteToggle: (() -> Unit)?,
    onOpenDescription: () -> Unit,
    playerSurface: (@Composable () -> Unit)?,
) {
    // 左右等宽，高度以 16:9 预览区为准，简介面板强制同高。
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = NcatContentStartPadding, end = NcatContentEndPadding),
    ) {
        val heroGap = 28.dp
        val panelWidth = (maxWidth - heroGap) / 2
        // 播放器高度 = 半宽 * 9/16；简介面板与之齐平。
        val panelHeight = panelWidth * 9f / 16f
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(heroGap),
            verticalAlignment = Alignment.Top,
        ) {
            NcatPreviewPanel(
                modifier = Modifier
                    .width(panelWidth)
                    .height(panelHeight),
                sourceName = state.currentSource?.name.orEmpty(),
                fillColor = previewFillColor,
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
                modifier = Modifier
                    .width(panelWidth)
                    .height(panelHeight),
                onPlayPressed = onPlayPressed,
                onFavoriteToggle = onFavoriteToggle,
                onOpenDescription = onOpenDescription,
            )
        }
    }
}

/**
 * 截图式预览播放器。
 *
 * @param sourceName 当前线路名称（仅加载文案，不用于铺海报）。
 * @param fillColor 初始化/加载中纯色底，禁止影片海报与纯黑。
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
    sourceName: String,
    fillColor: Color,
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
    val edgeShake = rememberTvEdgeShakeState()
    // 初始化与缓冲阶段不挂影片画面，只铺纯色；真正开播后再显示 Surface。
    val showPlayerSurface = playerSurface != null &&
        previewPlaybackStarted &&
        !previewIsLoading
    Box(
        modifier = modifier
            // 高度由 Hero 按 16:9 统一下发，避免与右侧简介错高。
            .fillMaxSize()
            .tvEdgeShake(edgeShake)
            // 主预览区大圆角，贴近截图卡片。
            .clip(RoundedCornerShape(18.dp))
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) Color.White else Color.White.copy(alpha = 0.12f),
                shape = RoundedCornerShape(18.dp),
            )
            .focusRequester(focusTargets.player)
            .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Top)
            .focusProperties {
                // 左列：上到搜索；右到全屏（与全屏左回播放器对开）；下到线路。
                up = focusTargets.search
                right = focusTargets.fullscreen
                left = FocusRequester.Cancel
                down = currentSourceFocusRequester ?: FocusRequester.Default
            }
            .focusable(interactionSource = interactionSource)
            .onPreviewKeyEvent { event ->
                if (edgeShake.consumeBoundaryKey(event = event, left = true)) {
                    return@onPreviewKeyEvent true
                }
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter) {
                    onPlayPressed?.invoke()
                    true
                } else {
                    false
                }
            },
    ) {
        // 底层始终纯色，避免加载瞬间闪出黑底或海报。
        NcatPreviewSolidFill(fillColor = fillColor)
        if (showPlayerSurface) {
            playerSurface!!()
        }
        if (previewIsLoading || !showPlayerSurface) {
            // 详情预览专用：转圈 + IvyTV + 文案同一列排版，避免两层居中叠在一起。
            NcatPreviewBrandStage(
                sourceName = sourceName,
                isLoading = previewIsLoading,
                networkSpeed = previewNetworkSpeed,
            )
        }
        if (previewPlaybackStarted && previewDurationMs > 0L && showPlayerSurface) {
            NcatPreviewProgressBar(
                isPlaying = previewIsPlaying,
                positionMs = previewPositionMs,
                durationMs = previewDurationMs,
            )
        }
    }
}

/**
 * 预览区舞台底。
 *
 * 轻纵向渐变：上沿略提亮、底部略沉，贴近播放舞台而不是平板色块。
 *
 * @param fillColor 舞台主色（非纯黑）。
 */
@Composable
private fun NcatPreviewSolidFill(fillColor: Color) {
    val top = Color(
        red = (fillColor.red + 0.04f).coerceIn(0f, 1f),
        green = (fillColor.green + 0.04f).coerceIn(0f, 1f),
        blue = (fillColor.blue + 0.05f).coerceIn(0f, 1f),
        alpha = 1f,
    )
    val bottom = Color(
        red = (fillColor.red * 0.78f).coerceIn(0f, 1f),
        green = (fillColor.green * 0.78f).coerceIn(0f, 1f),
        blue = (fillColor.blue * 0.86f).coerceIn(0f, 1f),
        alpha = 1f,
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colorStops = arrayOf(
                        0f to top,
                        0.48f to fillColor,
                        1f to bottom,
                    ),
                ),
            ),
    )
}

/**
 * 详情预览区品牌舞台（仅详情页小窗使用）。
 *
 * 把转圈、IvyTV、分隔线与下方文案收进同一 Column，避免原先「品牌层 + 加载层」双居中重叠。
 *
 * @param sourceName 线路名。
 * @param isLoading 是否加载中（显示转圈与状态行）。
 * @param networkSpeed 当前网速 B/s，>0 时显示速度文案。
 */
@Composable
private fun BoxScope.NcatPreviewBrandStage(
    sourceName: String,
    isLoading: Boolean,
    networkSpeed: Long,
) {
    val statusLine = when {
        !isLoading -> null
        networkSpeed > 0L -> formatSpeed(networkSpeed)
        else -> "加载中"
    }
    val caption = if (sourceName.isBlank()) {
        "精彩马上开始"
    } else {
        "精彩马上开始 · $sourceName"
    }
    Column(
        modifier = Modifier
            .align(Alignment.Center)
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        Text(
            text = "IvyTV",
            color = Color.White,
            fontSize = 28.sp,
            fontWeight = FontWeight.Black,
        )
        Spacer(Modifier.height(10.dp))
        Box(
            modifier = Modifier
                .width(220.dp)
                .height(1.dp)
                .background(TvTokens.Accent.copy(alpha = 0.5f)),
        )
        if (isLoading) {
            Spacer(Modifier.height(14.dp))
            CircularProgressIndicator(
                color = TvTokens.Accent,
                modifier = Modifier.size(26.dp),
                strokeWidth = 2.dp,
            )
            Spacer(Modifier.height(10.dp))
            Text(
                text = statusLine.orEmpty(),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.92f),
            )
        }
        Spacer(Modifier.height(if (isLoading) 10.dp else 12.dp))
        Text(
            text = caption,
            color = Color.White.copy(alpha = 0.88f),
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 预览区填充色：与右侧简介卡/页面背景同系冷蓝黑，禁止纯黑与青灰脱节。
 *
 * @param pageBackground 详情页背景色。
 * @return 预览区舞台主色。
 */
private fun detailPreviewFillColor(pageBackground: Color): Color {
    // 纯黑主题也落舞台深蓝灰，不铺 #000。
    val channelSum = pageBackground.red + pageBackground.green + pageBackground.blue
    if (channelSum < 0.06f) {
        return NcatPreviewStageBase
    }
    // 以页面主题色相为主，混入舞台冷色，与简介卡视觉对齐。
    return Color(
        red = (pageBackground.red * 0.58f + NcatPreviewStageBase.red * 0.42f).coerceIn(0f, 1f),
        green = (pageBackground.green * 0.58f + NcatPreviewStageBase.green * 0.42f).coerceIn(0f, 1f),
        blue = (pageBackground.blue * 0.58f + NcatPreviewStageBase.blue * 0.42f).coerceIn(0f, 1f),
        alpha = 1f,
    )
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
            // 简约无色播控：纯白几何图标，不用彩色 emoji。
            NcatPreviewPlayPauseGlyph(
                isPlaying = isPlaying,
                modifier = Modifier.size(12.dp),
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
                // 进度条也用中性白，不跟主题红抢色。
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress)
                        .height(3.dp)
                        .background(Color.White.copy(alpha = 0.92f), RoundedCornerShape(2.dp)),
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
 * 详情预览进度条旁的简约播控图标（纯白、无底色、无主题色）。
 *
 * 播放中：双竖线暂停；暂停：三角播放。
 *
 * @param isPlaying 是否正在播放。
 * @param modifier 外层尺寸。
 */
@Composable
private fun NcatPreviewPlayPauseGlyph(
    isPlaying: Boolean,
    modifier: Modifier = Modifier,
) {
    val iconColor = Color.White.copy(alpha = 0.95f)
    Canvas(modifier = modifier) {
        if (isPlaying) {
            // 暂停：两根细竖条。
            val barW = size.width * 0.22f
            val gap = size.width * 0.18f
            val barH = size.height * 0.88f
            val top = (size.height - barH) / 2f
            val left1 = size.width / 2f - gap / 2f - barW
            val left2 = size.width / 2f + gap / 2f
            drawRoundRect(
                color = iconColor,
                topLeft = Offset(left1, top),
                size = Size(barW, barH),
                cornerRadius = CornerRadius(barW * 0.25f, barW * 0.25f),
            )
            drawRoundRect(
                color = iconColor,
                topLeft = Offset(left2, top),
                size = Size(barW, barH),
                cornerRadius = CornerRadius(barW * 0.25f, barW * 0.25f),
            )
        } else {
            // 播放：向右三角。
            val path = Path().apply {
                val insetY = size.height * 0.08f
                val insetX = size.width * 0.12f
                moveTo(insetX, insetY)
                lineTo(size.width - insetX * 0.4f, size.height / 2f)
                lineTo(insetX, size.height - insetY)
                close()
            }
            drawPath(path = path, color = iconColor, style = Fill)
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
    // 右侧介绍区与左侧播放器同高：上下外边距加大，简介块与标题/按钮留出呼吸。
    Column(
        modifier = modifier
            .background(NcatInfoPanelSurface, RoundedCornerShape(18.dp))
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.08f),
                shape = RoundedCornerShape(18.dp),
            )
            // 面板外边距：左右略收、上下更松，避免简介块贴边。
            .padding(horizontal = 18.dp, vertical = 20.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
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
        }
        // 简介摘要可获焦：确认后打开全屏影片简介。
        val descriptionInteraction = remember { MutableInteractionSource() }
        val descriptionFocused by descriptionInteraction.collectIsFocusedAsState()
        // 固定高度背景框；末行绕开右下角“简介”标签，上方文本保持整行宽度。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp)
                .height(NcatDescriptionBoxHeight)
                .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                .border(
                    width = if (descriptionFocused) 2.dp else 0.dp,
                    color = if (descriptionFocused) Color.White else Color.Transparent,
                    shape = RoundedCornerShape(12.dp),
                )
                .focusRequester(focusTargets.description)
                .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Top)
                .focusProperties {
                    // 右列中枢：上搜索、下全屏、左播放器。
                    up = focusTargets.search
                    left = focusTargets.player
                    down = focusTargets.fullscreen
                    right = FocusRequester.Cancel
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
            NcatWrappedDescription(
                description = descriptionText,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .fillMaxSize()
                    .padding(
                        start = 16.dp,
                        top = 12.dp,
                        end = 16.dp,
                        bottom = 12.dp,
                    ),
            )
            // 右下角“简介”角标，与正文最后一行同一底部基线区域。
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 10.dp, bottom = 10.dp)
                    .background(
                        color = Color.White.copy(alpha = 0.14f),
                        shape = RoundedCornerShape(topStart = 8.dp, bottomEnd = 10.dp),
                    )
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "简介",
                    color = Color.White.copy(alpha = 0.82f),
                    fontSize = 11.sp,
                )
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
                modifier = Modifier
                    .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Top)
                    .focusProperties {
                        // 右列底：上简介、左播放器、右收藏、下线路。
                        up = focusTargets.description
                        left = focusTargets.player
                        right = focusTargets.favorite
                        down = currentSourceFocusRequester ?: FocusRequester.Default
                    },
                onPressed = { onPlayPressed?.invoke() },
                iconContent = {
                    NcatFullscreenGlyph(
                        modifier = Modifier.size(TvTokens.ActionIconSize),
                        color = Color.White,
                    )
                },
            )
            val favoriteEdgeShake = rememberTvEdgeShakeState()
            NcatActionTile(
                // 收藏态只变心形颜色，文案固定“收藏”，贴近目标截图。
                label = "收藏",
                selected = state.isFavorite,
                focusRequester = focusTargets.favorite,
                modifier = Modifier
                    .tvEdgeShake(favoriteEdgeShake)
                    .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Top)
                    .focusProperties {
                        up = focusTargets.description
                        left = focusTargets.fullscreen
                        right = FocusRequester.Cancel
                        down = currentSourceFocusRequester ?: FocusRequester.Default
                    },
                edgeShakeRight = true,
                edgeShakeState = favoriteEdgeShake,
                onPressed = { onFavoriteToggle?.invoke() },
                iconContent = {
                    NcatFavoriteGlyph(
                        modifier = Modifier.size(TvTokens.ActionIconSize),
                        favorited = state.isFavorite,
                    )
                },
            )
        }
    }
}

/**
 * 渲染绕开右下角“简介”标签的影片简介摘要。
 *
 * 前两行使用完整宽度，第三行缩窄以绕过标签，超出第三行的内容由第三行省略号表示。
 *
 * @param description 影片简介原文。
 * @param modifier 摘要可用区域修饰器。
 */
@OptIn(ExperimentalTextApi::class)
@Composable
private fun NcatWrappedDescription(
    description: String,
    modifier: Modifier = Modifier,
) {
    val textMeasurer = rememberTextMeasurer()
    val descriptionStyle = TextStyle(
        color = Color.White.copy(alpha = 0.78f),
        fontSize = 12.sp,
        lineHeight = 19.sp,
    )
    BoxWithConstraints(modifier = modifier) {
        // 右下标签只影响最末行；上方两行按完整可用宽度排版。
        val fullLineWidth = maxWidth
        val lastLineWidth = (maxWidth - NcatDescriptionBadgeReserve).coerceAtLeast(0.dp)
        val density = LocalDensity.current
        val fullLineLayout = textMeasurer.measure(
            text = AnnotatedString(description),
            style = descriptionStyle,
            constraints = Constraints(
                maxWidth = with(density) { fullLineWidth.roundToPx() },
            ),
        )
        val upperTextEnd = if (fullLineLayout.lineCount > 2) {
            // 取完整前两行的文本边界，第三行交给缩窄区域处理。
            fullLineLayout.getLineEnd(1, visibleEnd = true)
        } else {
            description.length
        }
        val upperDescription = description.substring(0, upperTextEnd)
        val finalDescription = description.substring(upperTextEnd)

        Column {
            Text(
                text = upperDescription,
                style = descriptionStyle,
            )
            if (finalDescription.isNotEmpty()) {
                Text(
                    text = finalDescription,
                    modifier = Modifier.width(lastLineWidth),
                    style = descriptionStyle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
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
    edgeShakeState: TvEdgeShakeState? = null,
    edgeShakeRight: Boolean = false,
    edgeShakeLeft: Boolean = false,
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
            .width(76.dp)
            .height(76.dp)
            .background(background, shape)
            .border(BorderStroke(if (isFocused) 2.dp else 1.dp, borderColor), shape)
            .focusRequester(focusRequester)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
            .onPreviewKeyEvent { event ->
                if (
                    edgeShakeState != null &&
                    edgeShakeState.consumeBoundaryKey(
                        event = event,
                        left = edgeShakeLeft,
                        right = edgeShakeRight,
                    )
                ) {
                    return@onPreviewKeyEvent true
                }
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key == Key.Enter || event.key == Key.DirectionCenter || event.key == Key.NumPadEnter || event.key == Key.Spacebar) {
                    onPressed(); true
                } else false
            },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier.size(TvTokens.ActionIconSize),
            contentAlignment = Alignment.Center,
        ) {
            if (iconContent != null) {
                iconContent()
            } else if (icon != null) {
                Text(
                    text = icon,
                    color = Color.White,
                    fontSize = TvTokens.TopActionIconGlyph,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Spacer(modifier = Modifier.height(6.dp))
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
        val title = when {
            emptyPlaybackCompleted -> "未找到可播放线路"
            isSearching -> "正在搜索线路"
            else -> "暂无播放线路"
        }
        val message = when {
            emptyPlaybackCompleted -> "已搜完可用源，可稍后再试或换关键词"
            isSearching -> "正在聚合可播放来源…"
            else -> "当前详情暂无可用播放源"
        }
        NcatInlineStatusCard(
            title = title,
            message = message,
            loading = isSearching && !emptyPlaybackCompleted,
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
            val edgeShake = rememberTvEdgeShakeState()
            val isFirst = index == 0
            val isLast = index == sourceOptions.lastIndex
            NcatSourceCard(
                option = option,
                focusRequester = focusTargets.sources.getOrNull(index),
                modifier = Modifier
                    .tvEdgeShake(edgeShake)
                    .tvBringFocusedItemIntoView()
                    .focusProperties {
                        up = focusTargets.player
                        down = currentEpisodeFocusRequester ?: focusTargets.episodeGroups.firstOrNull()
                            ?: focusTargets.recommends.firstOrNull()
                            ?: FocusRequester.Default
                        // 首/末项禁止 left/right 指回自己，否则永远到不了横向边界。
                        left = if (index > 0) {
                            focusTargets.sources.getOrNull(index - 1) ?: FocusRequester.Cancel
                        } else {
                            FocusRequester.Cancel
                        }
                        right = if (index < sourceOptions.lastIndex) {
                            focusTargets.sources.getOrNull(index + 1) ?: FocusRequester.Cancel
                        } else {
                            FocusRequester.Cancel
                        }
                    }
                    .onPreviewKeyEvent { event ->
                        edgeShake.consumeBoundaryKey(
                            event = event,
                            left = isFirst,
                            right = isLast,
                        )
                    }
                    .onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                previousActiveIndex = activeFocusedIndex,
                                newlyFocusedIndex = index,
                            )
                            activeFocusedIndex = index
                            // 仅同轨左右相邻才横向滚动，上下跨层进入不拽 offset。
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
    // 仅“已选线路”用红色底；获焦未选中抬底 + 白描边，避免未选中也整块变红。
    val selected = option.selected
    Box(
        modifier = modifier
            .width(168.dp)
            .height(70.dp)
            .background(
                color = when {
                    selected -> TvTokens.Accent
                    isFocused -> NcatSurfaceFocused
                    else -> NcatSurface
                },
                shape = RoundedCornerShape(NcatRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) {
                    Color.White
                } else {
                    Color.White.copy(alpha = 0.06f)
                },
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
                    .background(
                        color = if (selected) Color.White.copy(alpha = 0.22f) else Color(0xFF4A3560),
                        shape = RoundedCornerShape(topStart = NcatRadius, bottomEnd = 8.dp),
                    )
                    .padding(horizontal = 7.dp, vertical = 3.dp),
            ) {
                Text(
                    text = "多集",
                    color = Color.White.copy(alpha = 0.92f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 14.dp, start = 10.dp, end = 10.dp, bottom = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                // 后台名称若已带胶片符号，这里不再重复追加。
                text = formatSourceCardTitle(option.label, option.trailingText),
                color = Color.White.copy(alpha = if (selected || isFocused) 1f else 0.82f),
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                // 选中：当前线路；未选中：资源质量提示。
                text = if (option.selected) "当前线路 · 推荐" else "高清",
                color = if (selected) {
                    Color.White.copy(alpha = 0.90f)
                } else {
                    Color.White.copy(alpha = 0.48f)
                },
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 截图式选集轨道。
 *
 * 全剧集连续横轨 + 分组条，逻辑复用 [TvEpisodePlaylistRail]（与全屏播放器一致），
 * 避免组边界左右键跳到线路/推荐等其它层。
 *
 * @param groups 选集分组（仅用于标题总数与空态）。
 * @param episodes 当前线路全量剧集。
 * @param currentEpisodeId 当前剧集 ID。
 * @param focusTargets 焦点请求器。
 * @param currentSourceFocusRequester 当前线路焦点。
 * @param currentEpisodeFocusRequester 当前选集焦点。
 * @param hasRecommends 是否有推荐。
 * @param onEpisodeSelected 选集回调。
 * @param onGroupSelected 分组确认回调（同步 ViewModel 下划线语义）。
 */
@Composable
private fun NcatEpisodeGroupRail(
    groups: List<TvDetailEpisodeGroupOption>,
    episodes: List<TvEpisode>,
    currentEpisodeId: String,
    focusTargets: TvDetailFocusTargets,
    currentSourceFocusRequester: FocusRequester?,
    currentEpisodeFocusRequester: FocusRequester?,
    hasRecommends: Boolean,
    onEpisodeSelected: ((String) -> Unit)?,
    onGroupSelected: ((Int) -> Unit)?,
) {
    val totalCount = episodes.size
    NcatSectionHeader(
        title = "选集",
        hint = if (totalCount == 0) "暂无选集" else "(共${totalCount}集全)",
        topPadding = 38.dp,
    )
    if (totalCount == 0) {
        NcatInlineStatusCard(
            title = "暂无选集",
            message = "有可用线路后将在此展示剧集",
            loading = false,
        )
        return
    }

    val playlistItems = remember(episodes) {
        episodes.mapIndexed { index, episode ->
            TvEpisodePlaylistItem(
                id = episode.id,
                label = episode.title.ifBlank { "第${(index + 1).toString().padStart(2, '0')}集" },
            )
        }
    }
    val downFromGroup = focusTargets.recommends.takeIf { hasRecommends }?.firstOrNull()
        ?: focusTargets.backTop

    TvEpisodePlaylistRail(
        episodes = playlistItems,
        currentEpisodeId = currentEpisodeId,
        contentStartPadding = NcatContentStartPadding,
        contentEndPadding = NcatContentEndPadding,
        episodeRowHeight = 54.dp,
        groupRowHeight = 48.dp,
        currentEpisodeFocusRequester = currentEpisodeFocusRequester,
        onEpisodeSelected = { id -> onEpisodeSelected?.invoke(id) },
        onArrowUpFromEpisode = {
            currentSourceFocusRequester?.let { runCatching { it.requestFocus() } }
        },
        onArrowDownFromEpisodeNoGroups = {
            runCatching { downFromGroup.requestFocus() }
        },
        onArrowDownFromGroup = {
            runCatching { downFromGroup.requestFocus() }
        },
        onSelectedGroupChanged = { groupIndex ->
            // 焦点随集移动时同步 ViewModel，保持分组下划线与当前浏览位置一致。
            onGroupSelected?.invoke(groupIndex)
        },
        episodeChip = { scope ->
            NcatEpisodeChip(
                label = scope.label,
                selected = scope.selected,
                focusRequester = null,
                modifier = scope.modifier,
                onArrowLeft = scope.onArrowLeft,
                onArrowRight = scope.onArrowRight,
                onArrowUp = scope.onArrowUp,
                onArrowDown = scope.onArrowDown,
                onPressed = scope.onClick,
            )
        },
        groupChip = { scope ->
            NcatEpisodeGroupChoice(
                label = scope.label,
                selected = scope.selected,
                focusRequester = null,
                onArrowLeft = scope.onArrowLeft,
                onArrowRight = scope.onArrowRight,
                onArrowUp = scope.onArrowUp,
                onArrowDown = scope.onArrowDown,
                modifier = scope.modifier,
                onPressed = scope.onClick,
            )
        },
    )
}

@Composable
private fun NcatEpisodeGroupChoice(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester?,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val edgeShake = rememberTvEdgeShakeState()
    // 获焦或选中都用主题色；下划线仅 selected。
    val textAccent = selected || isFocused
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.04f else 1f,
        animationSpec = tween(140),
        label = "ncatEpisodeGroupScale",
    )
    Column(
        modifier = modifier
            // 热区略放大；高度交给外层 LazyRow(48.dp)，避免 heightIn 挤掉下划线。
            .widthIn(min = 56.dp)
            .fillMaxHeight()
            .tvEdgeShake(edgeShake)
            .scale(scale)
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
            .onPreviewKeyEvent { event ->
                // 与详情页其它焦点控件一致：回车 / 中键 / 小键盘回车 / 空格 在 KeyUp 确认。
                // 模拟器常用空格当 OK；此前未处理 Spacebar 会导致「按了没反应」。
                if (
                    event.key == Key.Enter ||
                    event.key == Key.DirectionCenter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                ) {
                    if (event.type == KeyEventType.KeyUp) {
                        onPressed()
                    }
                    return@onPreviewKeyEvent true
                }
                consumeDirectionalKeyWithEdgeShake(
                    event = event,
                    edgeShake = edgeShake,
                    onArrowLeft = onArrowLeft,
                    onArrowRight = onArrowRight,
                    onArrowUp = onArrowUp,
                    onArrowDown = onArrowDown,
                )
            }
            .padding(horizontal = 6.dp, vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // 下划线宽度跟文字：内层 IntrinsicSize.Max，线 fillMaxWidth = 文案宽。
        Column(
            modifier = Modifier.width(IntrinsicSize.Max),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = label,
                color = if (textAccent) TvTokens.Accent else Color.White.copy(alpha = 0.86f),
                fontSize = 15.sp,
                fontWeight = if (textAccent) FontWeight.Bold else FontWeight.Medium,
                maxLines = 1,
            )
            Spacer(modifier = Modifier.height(3.dp))
            // 仅选中显示底部主题色下划线；获焦未确认只改文字色。占位高度固定，避免选中时布局跳动。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .widthIn(min = 14.dp)
                    .background(
                        if (selected) TvTokens.Accent else Color.Transparent,
                        RoundedCornerShape(1.5.dp),
                    ),
            )
        }
    }
}

@Composable
private fun NcatEpisodeChip(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester?,
    modifier: Modifier = Modifier,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    onPressed: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val edgeShake = rememberTvEdgeShakeState()
    Box(
        modifier = modifier
            .widthIn(min = 56.dp)
            .height(48.dp)
            .tvEdgeShake(edgeShake)
            .background(
                color = when {
                    // 仅当前集用强调色；获焦未选中抬底，避免整行扫过都变红。
                    selected -> TvTokens.Accent
                    isFocused -> NcatSurfaceFocused
                    else -> NcatSurface
                },
                shape = RoundedCornerShape(NcatRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) {
                    Color.White
                } else {
                    Color.White.copy(alpha = 0.06f)
                },
                shape = RoundedCornerShape(NcatRadius),
            )
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .focusable(interactionSource = interactionSource)
            .ncatClickable(onPressed)
            .onPreviewKeyEvent { event ->
                if (
                    event.key == Key.Enter ||
                    event.key == Key.DirectionCenter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                ) {
                    if (event.type == KeyEventType.KeyUp) {
                        onPressed()
                    }
                    return@onPreviewKeyEvent true
                }
                // 有回调则移动；左右无回调=首/末集边界抖动。
                consumeDirectionalKeyWithEdgeShake(
                    event = event,
                    edgeShake = edgeShake,
                    onArrowLeft = onArrowLeft,
                    onArrowRight = onArrowRight,
                    onArrowUp = onArrowUp,
                    onArrowDown = onArrowDown,
                )
            }
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = if (selected || isFocused) 1f else 0.84f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

/**
 * 截图式推荐轨道。
 *
 * 加载中先占位骨架，数据到达后淡入上滑，避免整段突然插入跳动。
 *
 * @param cards 推荐卡片。
 * @param loadState 推荐加载状态。
 * @param focusTargets 焦点请求器。
 * @param listState 横向列表状态。
 * @param hasEpisodeGroupChoices 是否展示选集分组切换条。
 * @param onRecommendClick 推荐卡点击回调。
 */
@Composable
private fun NcatRecommendRail(
    cards: List<TvVideoCard>,
    loadState: TvDetailRecommendLoadState,
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
    val sectionHint = when {
        cards.isNotEmpty() -> "${cards.size} 部"
        loadState == TvDetailRecommendLoadState.Failed -> "暂时不可用"
        loadState == TvDetailRecommendLoadState.Loading ||
            loadState == TvDetailRecommendLoadState.Scheduled -> "加载中…"
        else -> null
    }
    NcatSectionHeader(
        title = "相关推荐",
        hint = sectionHint,
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
        when {
            cards.isNotEmpty() -> {
                // 首次有数据：淡入 + 轻微上滑，替代整段突然蹦出。
                val appearState = remember {
                    MutableTransitionState(false).apply { targetState = true }
                }
                AnimatedVisibility(
                    visibleState = appearState,
                    enter = fadeIn(animationSpec = tween(320)) + slideInVertically(
                        animationSpec = tween(340),
                        initialOffsetY = { distance -> distance / 10 },
                    ),
                ) {
                    LazyRow(
                        state = listState,
                        horizontalArrangement = Arrangement.spacedBy(recommendSpacing),
                        contentPadding = PaddingValues(
                            start = recommendStartPadding,
                            end = recommendEndPadding,
                        ),
                        modifier = Modifier.height(railHeight),
                    ) {
                        items(
                            cards.size,
                            key = { index ->
                                cards[index].source + "::" + cards[index].id + "::" + index
                            },
                        ) { index ->
                            val card = cards[index]
                            val edgeShake = rememberTvEdgeShakeState()
                            val isFirst = index == 0
                            val isLast = index == cards.lastIndex
                            NcatRecommendCard(
                                card = card,
                                cardWidth = cardWidth,
                                coverHeight = coverHeight,
                                focusRequester = focusTargets.recommends.getOrNull(index),
                                onPressed = { onRecommendClick?.invoke(card) },
                                modifier = Modifier
                                    .tvEdgeShake(edgeShake)
                                    .tvBringFocusedItemIntoView()
                                    .focusProperties {
                                        up = focusTargets.episodeGroups
                                            .firstOrNull()
                                            .takeIf { hasEpisodeGroupChoices }
                                            ?: focusTargets.episodes.firstOrNull()
                                            ?: FocusRequester.Default
                                        down = focusTargets.backTop
                                        left = if (index > 0) {
                                            focusTargets.recommends.getOrNull(index - 1)
                                                ?: FocusRequester.Cancel
                                        } else {
                                            FocusRequester.Cancel
                                        }
                                        right = if (index < cards.lastIndex) {
                                            focusTargets.recommends.getOrNull(index + 1)
                                                ?: FocusRequester.Cancel
                                        } else {
                                            FocusRequester.Cancel
                                        }
                                    }
                                    .onPreviewKeyEvent { event ->
                                        edgeShake.consumeBoundaryKey(
                                            event = event,
                                            left = isFirst,
                                            right = isLast,
                                        )
                                    }
                                    .onFocusChanged { focusState ->
                                        if (focusState.isFocused) {
                                            val shouldScroll =
                                                TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                                    previousActiveIndex = activeFocusedIndex,
                                                    newlyFocusedIndex = index,
                                                )
                                            activeFocusedIndex = index
                                            // 仅同轨左右相邻才横向滚动，上下跨层进入不拽 offset。
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

            loadState == TvDetailRecommendLoadState.Failed -> {
                Text(
                    text = "相关推荐加载失败，稍后再试",
                    color = NcatMutedText,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(
                        start = recommendStartPadding,
                        end = recommendEndPadding,
                        bottom = 8.dp,
                    ),
                )
            }

            else -> {
                // 调度/加载中：骨架占位，高度与正式轨一致，避免底部突然顶开。
                NcatRecommendSkeletonRail(
                    cardWidth = cardWidth,
                    coverHeight = coverHeight,
                    railHeight = railHeight,
                    spacing = recommendSpacing,
                    startPadding = recommendStartPadding,
                    endPadding = recommendEndPadding,
                )
            }
        }
    }
}

/**
 * 相关推荐骨架轨：与正式卡片同宽高，弱对比色块。
 */
@Composable
private fun NcatRecommendSkeletonRail(
    cardWidth: Dp,
    coverHeight: Dp,
    railHeight: Dp,
    spacing: Dp,
    startPadding: Dp,
    endPadding: Dp,
) {
    val placeholderCount = TvListLayoutMetrics.PosterColumns
    Row(
        modifier = Modifier
            .height(railHeight)
            .padding(start = startPadding, end = endPadding),
        horizontalArrangement = Arrangement.spacedBy(spacing),
    ) {
        repeat(placeholderCount) {
            Column(
                verticalArrangement = Arrangement.spacedBy(11.dp),
                modifier = Modifier.width(cardWidth),
            ) {
                Box(
                    modifier = Modifier
                        .width(cardWidth)
                        .height(coverHeight)
                        .clip(RoundedCornerShape(7.dp))
                        .background(NcatSurface.copy(alpha = 0.85f)),
                )
                Box(
                    modifier = Modifier
                        .fillMaxWidth(0.72f)
                        .height(12.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(NcatSurface.copy(alpha = 0.65f)),
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
            if (card.posterUrl.isNotBlank() || card.title.isNotBlank()) {
                TvCachedTitlePosterImage(
                    title = card.title,
                    posterUrl = card.posterUrl,
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
            .padding(top = 20.dp, bottom = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(36.dp)) {
            NcatBottomPill(
                label = "返回顶部",
                leadingIcon = { NcatBottomActionGlyph(kind = NcatBottomActionIcon.BackToTop) },
                focusRequester = focusTargets.backTop,
                modifier = Modifier
                    .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Bottom)
                    .focusProperties {
                        up = focusTargets.recommends.firstOrNull()
                            ?: focusTargets.episodeGroups.firstOrNull().takeIf { hasEpisodeGroupChoices }
                            ?: focusTargets.episodes.firstOrNull()
                            ?: FocusRequester.Default
                        down = FocusRequester.Cancel
                        left = FocusRequester.Cancel
                        right = focusTargets.random
                    },
                onClick = onBackToTop,
            )
            NcatBottomPill(
                label = "随便看看",
                leadingIcon = { NcatBottomActionGlyph(kind = NcatBottomActionIcon.RandomBrowse) },
                focusRequester = focusTargets.random,
                modifier = Modifier
                    .tvBringFocusedItemIntoView(pin = DetailVerticalPin.Bottom)
                    .focusProperties {
                        up = focusTargets.recommends.firstOrNull()
                            ?: focusTargets.episodeGroups.firstOrNull().takeIf { hasEpisodeGroupChoices }
                            ?: focusTargets.episodes.firstOrNull()
                            ?: FocusRequester.Default
                        down = FocusRequester.Cancel
                        left = focusTargets.backTop
                        right = FocusRequester.Cancel
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
    // 高度/圆角与顶栏「搜索」胶囊一致（TvTokens.TopActionHeight / TopActionRadius）。
    NcatPillFocusButton(
        modifier = modifier
            .height(TvTokens.TopActionHeight)
            .widthIn(min = 140.dp),
        focusRequester = focusRequester,
        cornerRadius = TvTokens.TopActionRadius,
        onClick = onClick,
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 16.dp),
        ) {
            leadingIcon?.invoke()
            Text(
                text = label,
                color = Color.White.copy(alpha = 0.92f),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
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
 * 线路/选集内联状态卡：与详情深色色板一致，高度贴近线路卡，可选加载转圈。
 *
 * @param title 主文案。
 * @param message 次要说明。
 * @param loading 是否展示加载指示。
 */
@Composable
private fun NcatInlineStatusCard(
    title: String,
    message: String,
    loading: Boolean,
) {
    val shape = RoundedCornerShape(NcatRadius)
    Row(
        modifier = Modifier
            .padding(start = NcatContentStartPadding, end = NcatContentEndPadding)
            .height(NcatInlineStatusCardHeight)
            .widthIn(min = NcatInlineStatusCardMinWidth)
            .background(NcatSurface, shape)
            .border(1.dp, Color.White.copy(alpha = 0.06f), shape)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = TvTokens.Accent,
                strokeWidth = 2.dp,
            )
        } else {
            // 静默空态：细红点作轻提示，避免大块状态板。
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(TvTokens.Accent.copy(alpha = 0.75f)),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = title,
                color = Color.White.copy(alpha = 0.92f),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = message,
                color = NcatMutedText,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/**
 * 页面级错误/空详情状态：沿用详情深色板，不再套通用 TvStatePanel 冷灰块。
 *
 * @param kind 状态类型（影响边框色）。
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
    val shape = RoundedCornerShape(14.dp)
    val borderColor = when (kind) {
        TvStatePanelKind.Error -> Color(0xFFB84A4A).copy(alpha = 0.55f)
        TvStatePanelKind.Loading -> TvTokens.Accent.copy(alpha = 0.35f)
        TvStatePanelKind.Empty -> Color.White.copy(alpha = 0.06f)
    }
    val panelModifier = Modifier
        .padding(start = NcatContentStartPadding, end = NcatContentEndPadding)
        .fillMaxWidth()
        .background(NcatSurface.copy(alpha = 0.95f), shape)
        .border(1.dp, borderColor, shape)
        .padding(horizontal = 20.dp, vertical = 18.dp)
        .then(
            if (focusRequester != null) {
                Modifier.focusRequester(focusRequester).focusable()
            } else {
                Modifier
            },
        )
    Column(
        modifier = panelModifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 17.sp,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = message,
            color = NcatMutedText,
            fontSize = 13.sp,
        )
    }
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
private fun NcatBottomActionGlyph(
    kind: NcatBottomActionIcon,
    modifier: Modifier = Modifier.size(TvTokens.ActionIconSize),
) {
    Canvas(modifier = modifier) {
        // 线宽随统一图标尺寸略收，避免 22dp 框内显得过粗。
        val stroke = 2.dp.toPx()
        val color = Color.White.copy(alpha = 0.92f)
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
 * 不另铺海报背景，直接半透明盖在详情页上，沿用详情页画面作底。
 *
 * @param title 影片标题。
 * @param description 完整简介。
 * @param sourceName 线路/来源名。
 * @param onDismiss 关闭回调。
 */
@Composable
private fun NcatDescriptionOverlay(
    title: String,
    description: String,
    sourceName: String,
    onDismiss: () -> Unit,
) {
    val closeRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        runCatching { closeRequester.requestFocus() }
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            // 仅半透明遮罩，透出下方详情页背景。
            .background(Color.Black.copy(alpha = 0.58f))
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

/**
 * 横向列表获焦后滚动（仅在同轨左右相邻切换时调用）。
 *
 * 目标：靠近左右边界时真正到边，中间项仅被裁切时才跟手；
 * 不做「第 2 项强制最左」等额外 pin，避免上下切层或中段跳动。
 *
 * - 首项：滚到 offset=0（真正最左）
 * - 末项：滚到 maxScrollExtent（真正最右，末卡完整露出）
 * - 中间：仅当左右被裁切时滚入视口
 *
 * 屏外项优先 [LazyListState.scrollToItem] 瞬移，避免高下标 animate 过久。
 */
private suspend fun scrollDetailOptionIntoViewNow(
    listState: LazyListState,
    focusedIndex: Int,
    itemCount: Int,
) {
    if (itemCount <= 0 || focusedIndex !in 0 until itemCount) {
        return
    }
    val lastIndex = itemCount - 1
    when {
        focusedIndex == 0 -> {
            // 首项：真正到最左。
            if (listState.firstVisibleItemIndex != 0 || listState.firstVisibleItemScrollOffset != 0) {
                listState.scrollToItem(index = 0, scrollOffset = 0)
            }
        }
        focusedIndex >= lastIndex -> {
            // 末项：先滚到末项可见，再大幅 scrollBy 夹到 max，真正到最右。
            val alreadyVisible = listState.layoutInfo.visibleItemsInfo.any { item ->
                item.index == lastIndex
            }
            if (!alreadyVisible) {
                runCatching { listState.scrollToItem(index = lastIndex) }
                withFrameNanos { }
            } else {
                runCatching { listState.animateScrollToItem(index = lastIndex) }
            }
            if (listState.canScrollForward) {
                val info = listState.layoutInfo
                val last = info.visibleItemsInfo.firstOrNull { item -> item.index == lastIndex }
                val overflow = if (last != null) {
                    (last.offset + last.size - info.viewportEndOffset).toFloat().coerceAtLeast(0f)
                } else {
                    0f
                }
                // overflow 对齐末项右缘；再推一截以吃掉 endPadding，夹到真正 max。
                val push = (overflow + info.viewportEndOffset.toFloat()).coerceAtLeast(1f)
                listState.animateScrollBy(push)
            }
        }
        else -> {
            val layoutInfo = listState.layoutInfo
            val visible = layoutInfo.visibleItemsInfo
            val target = visible.firstOrNull { info -> info.index == focusedIndex }
            if (target == null) {
                runCatching { listState.scrollToItem(index = focusedIndex) }
                withFrameNanos { }
                return
            }
            val viewportStart = layoutInfo.viewportStartOffset
            val viewportEnd = layoutInfo.viewportEndOffset
            val itemStart = target.offset
            val itemEnd = target.offset + target.size
            val edgeSafePx = 8
            when {
                itemStart < viewportStart + edgeSafePx -> {
                    listState.animateScrollToItem(index = focusedIndex)
                }
                itemEnd > viewportEnd - edgeSafePx -> {
                    // 右缘裁切：用 scrollBy 刚好露出，避免 animateScrollToItem 把项钉到最左造成跳动。
                    val overflow = (itemEnd - (viewportEnd - edgeSafePx)).toFloat()
                    if (overflow > 1f) {
                        listState.animateScrollBy(overflow)
                    }
                }
            }
        }
    }
}

/**
 * 详情页横向选项滚入可视区（异步包装）。
 */
private fun scrollDetailOptionIntoView(
    listState: LazyListState,
    focusedIndex: Int,
    itemCount: Int,
    scrollScope: CoroutineScope,
) {
    scrollScope.launch {
        scrollDetailOptionIntoViewNow(
            listState = listState,
            focusedIndex = focusedIndex,
            itemCount = itemCount,
        )
    }
}

/**
 * 获焦时驱动详情页外层 verticalScroll 跟滚。
 *
 * 嵌套横向 LazyRow 时系统 bringIntoView 经常只处理横轴或失效；
 * 这里用窗口坐标相对视口计算 delta，直接 animateScrollTo。
 *
 * @param pin 顶/底钉靠或仅保证可见。
 */
private fun Modifier.tvBringFocusedItemIntoView(
    pin: DetailVerticalPin = DetailVerticalPin.Visible,
): Modifier = composed {
    val host = LocalDetailVerticalScroll.current
    var itemCoords by remember { mutableStateOf<LayoutCoordinates?>(null) }
    this
        .onGloballyPositioned { coordinates ->
            itemCoords = coordinates
        }
        .onFocusChanged { focusState ->
            // 仅 isFocused：避免父 hasFocus 与子项重复触发。
            if (!focusState.isFocused) {
                return@onFocusChanged
            }
            val scrollHost = host ?: return@onFocusChanged
            val coords = itemCoords?.takeIf { item -> item.isAttached } ?: return@onFocusChanged
            val viewport = scrollHost.viewportBounds() ?: return@onFocusChanged
            val itemBounds = coords.boundsInWindow()
            scrollHost.scope.launch {
                scrollDetailFocusedItemVertically(
                    scrollState = scrollHost.scrollState,
                    itemBounds = itemBounds,
                    viewportBounds = viewport,
                    pin = pin,
                )
            }
        }
}

/**
 * 根据获焦项与视口的窗口坐标，调整详情纵向 ScrollState。
 *
 * @param scrollState 外层 verticalScroll 状态。
 * @param itemBounds 获焦项窗口矩形。
 * @param viewportBounds 详情视口窗口矩形。
 * @param pin 钉靠策略。
 * @param edgePaddingPx 上下安全边（像素）。
 */
private suspend fun scrollDetailFocusedItemVertically(
    scrollState: ScrollState,
    itemBounds: Rect,
    viewportBounds: Rect,
    pin: DetailVerticalPin,
    edgePaddingPx: Float = 28f,
) {
    when (pin) {
        DetailVerticalPin.Top -> {
            // 顶部区：真正到顶，避免 Hero 半截停在视口。
            if (scrollState.value > 0) {
                scrollState.animateScrollTo(0)
            }
        }
        DetailVerticalPin.Bottom -> {
            // 底栏：真正到底，完整露出返回顶部/随便看看。
            val max = scrollState.maxValue
            if (max > 0 && scrollState.value < max) {
                scrollState.animateScrollTo(max)
            }
            // 再夹一次 residual。
            if (scrollState.value < scrollState.maxValue) {
                scrollState.scrollTo(scrollState.maxValue)
            }
        }
        DetailVerticalPin.Visible -> {
            val topOverflow = (viewportBounds.top + edgePaddingPx) - itemBounds.top
            val bottomOverflow = itemBounds.bottom - (viewportBounds.bottom - edgePaddingPx)
            val delta = when {
                topOverflow > 1f -> -topOverflow
                bottomOverflow > 1f -> bottomOverflow
                else -> 0f
            }
            if (abs(delta) <= 1f) {
                return
            }
            val target = (scrollState.value + delta)
                .toInt()
                .coerceIn(0, scrollState.maxValue.coerceAtLeast(0))
            if (target != scrollState.value) {
                scrollState.animateScrollTo(target)
            }
        }
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
