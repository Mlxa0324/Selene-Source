package org.moontechlab.selene.tv.feature.player

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusDirection
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
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.layout.TvLayeredHorizontalFocusScroll
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressAction
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressPolicy
import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSource
import org.moontechlab.selene.tv.core.player.api.TvResizeMode
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/**
 * TV 全屏播放器路由。
 *
 * @param playbackRequest 详情页传入的当前播放请求。
 * @param viewModel 播放器 ViewModel。
 * @param playerSurface 播放器画面层插槽，用于承载 ExoPlayer/WebView 等真实平台视图。
 * @param onDanmakuMatchRequested 弹幕手动匹配请求回调，入参为默认搜索词。
 * @param onExitRequested 退出播放器回调。
 */
@Composable
fun TvPlayerRoute(
    playbackRequest: PlaybackRequest? = null,
    viewModel: TvPlayerViewModel = remember(playbackRequest) {
        TvPlayerViewModel(initialRequest = playbackRequest)
    },
    playerSurface: @Composable BoxScope.(TvPlayerUiState) -> Unit = { surfaceState ->
        TvPlayerDefaultSurface(surfaceState = surfaceState)
    },
    onDanmakuMatchRequested: (String) -> Unit = {},
    onExitRequested: () -> Unit = {},
) {
    val state by viewModel.state.collectAsState()
    val scope = rememberCoroutineScope()
    // 菜单交互计数器：每次操作递增，驱动 4s 无操作自动隐藏重新计时。
    var menuInteractionKey by remember { mutableIntStateOf(0) }
    // 顶部/底部播放壳层可见性：无操作倒计时后隐藏标题、进度条等。
    var isChromeVisible by remember { mutableStateOf(true) }
    // 壳层交互计数器，任意操作重置 4s 隐藏计时。
    var chromeInteractionKey by remember { mutableIntStateOf(0) }
    val continuousSeekState = rememberContinuousSeekState(
        scope = scope,
        viewModel = viewModel,
    )
    val playerRootFocusRequester = remember { FocusRequester() }
    val primaryMenuFocusRequesters = rememberPlayerMenuFocusRequesters(PLAYER_PRIMARY_MENU_ITEMS.size)
    val secondaryMenuFocusRequesters = rememberPlayerMenuFocusRequesters(
        count = resolveSecondaryMenuItemCount(state),
    )
    // 一级/二级 chip 窗口坐标，供一级上键做屏幕空间就近落点。
    val menuFocusGeometry = remember { TvPlayerMenuFocusGeometry() }
    LaunchedEffect(state.selectedTopMenu, state.isMenuVisible) {
        // 切换一级分类或关闭菜单时清空二级坐标，避免用上一层的旧位置算就近。
        menuFocusGeometry.clearSecondary()
    }
    /**
     * 显示顶部/底部播放壳层，并重置无操作隐藏倒计时。
     */
    val revealChrome: () -> Unit = {
        isChromeVisible = true
        chromeInteractionKey++
    }
    /**
     * 记录底部菜单交互，并把自动隐藏倒计时整体后延。
     *
     * 任意焦点移动、确认选择、方向键切换都会调用；
     * 只在用户持续无操作时才关闭菜单。
     */
    val bumpMenuInteraction: () -> Unit = {
        // 递增 key 取消旧 delay，重新计时。
        menuInteractionKey++
        // 菜单活跃时同步保持顶部壳层可见。
        revealChrome()
    }
    val requestSelectedPrimaryMenuFocus: () -> Unit = {
        // 一级/二级之间跳转也算操作，后延自动隐藏。
        // 二级→一级：固定回到当前选中的一级项，不跳到首项。
        bumpMenuInteraction()
        primaryMenuFocusRequesters.requestFocusAt(resolveSelectedPrimaryMenuIndex(state))
    }
    val requestSelectedSecondaryMenuFocus: () -> Unit = {
        // 打开菜单 / 播放线路上键：落到业务“当前选中”的二级项。
        bumpMenuInteraction()
        secondaryMenuFocusRequesters.requestFocusAt(resolveSelectedSecondaryMenuIndex(state))
    }
    /**
     * 一级→二级：屏幕空间就近。
     *
     * @param primaryIndex 当前获焦的一级下标（以实际焦点为准，不用间接推算）。
     */
    val requestNearestSecondaryMenuFocus: (primaryIndex: Int) -> Unit = { primaryIndex ->
        bumpMenuInteraction()
        val fallbackIndex = resolveSelectedSecondaryMenuIndex(state)
        val nearestIndex = menuFocusGeometry.resolveNearestSecondaryIndex(
            primaryIndex = primaryIndex,
            fallbackIndex = fallbackIndex,
        )
        secondaryMenuFocusRequesters.requestFocusAt(nearestIndex)
    }

    LaunchedEffect(viewModel) {
        viewModel.observePlayerState()
    }

    LaunchedEffect(viewModel, playbackRequest) {
        viewModel.loadInitialRequest()
        viewModel.loadSkipDurations()
        viewModel.loadDanmakuForCurrentRequest()
    }

    LaunchedEffect(state.isMenuVisible) {
        if (state.isMenuVisible) {
            // 菜单刚展开时优先落到当前二级菜单（播放列表/线路），一级菜单用下键回落。
            // 一级菜单左右切换只更新二级内容，不能因状态变化再次抢走焦点。
            // 二级无项时再落一级，避免“上键无响应”。
            val secondaryReady = when (state.selectedTopMenu) {
                PLAYER_MENU_PLAYLIST -> state.allEpisodes.isNotEmpty()
                PLAYER_MENU_SOURCES -> state.availableSources.isNotEmpty()
                PLAYER_MENU_ASPECT_RATIO,
                PLAYER_MENU_SPEED,
                PLAYER_MENU_OTHER,
                -> true
                else -> false
            }
            if (secondaryReady) {
                requestSelectedSecondaryMenuFocus()
            } else {
                requestSelectedPrimaryMenuFocus()
            }
        } else {
            // 菜单关闭后重新露出进度条/标题，并启动 4s 无操作隐藏。
            revealChrome()
            // 首次进入全屏或菜单关闭后，根节点必须重新获焦，左右键才能稳定执行 seek。
            runCatching { playerRootFocusRequester.requestFocus() }
        }
    }

    // 顶部标题/底部进度条：无操作 4 秒后隐藏；菜单打开时由菜单层接管底部。
    LaunchedEffect(isChromeVisible, state.isMenuVisible, state.isPlayerLoading, chromeInteractionKey) {
        if (!isChromeVisible || state.isMenuVisible || state.isPlayerLoading) {
            return@LaunchedEffect
        }
        delay(PLAYER_MENU_AUTO_HIDE_MS)
        isChromeVisible = false
    }

    LaunchedEffect(
        state.isSeekOverlayVisible,
        state.seekOverlayPositionMs,
        state.seekOverlayDirection,
    ) {
        if (state.isSeekOverlayVisible) {
            // Flutter TV 的 seek 中心提示停留约 1.2 秒后自动淡出。
            delay(1_200)
            viewModel.hideSeekOverlay()
        }
    }

    DisposableEffect(continuousSeekState) {
        onDispose {
            // 页面退出或重组切换播放器实例时，必须停止后台 seek tick。
            continuousSeekState.stop()
        }
    }

    BackHandler {
        continuousSeekState.stop()
        if (state.isMenuVisible) {
            // 系统返回优先关闭底部菜单，和 Flutter TV 全屏播放器一致。
            viewModel.closeMenu()
        } else {
            onExitRequested()
        }
    }

    // 菜单打开时保留顶栏；菜单关闭后跟随壳层倒计时显示/隐藏。
    val shouldShowTopDecorations =
        !state.isPlayerLoading && (state.isMenuVisible || isChromeVisible)
    // 底部进度条/提示仅在菜单关闭且壳层可见时展示。
    val shouldShowPlaybackChrome =
        isChromeVisible && !state.isMenuVisible && !state.isPlayerLoading
    val shouldShowCenterPlayButton =
        isChromeVisible && !state.isMenuVisible && !state.isPlayerLoading && !state.isPlaybackPlaying

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .focusRequester(playerRootFocusRequester)
            .onPreviewKeyEvent { event ->
                if (event.type == KeyEventType.KeyUp && event.key.isSeekDirectionKey()) {
                    // 方向键松手立刻停止连续 seek，避免松手后进度继续跳动。
                    continuousSeekState.stop()
                    return@onPreviewKeyEvent true
                }
                if (event.type != KeyEventType.KeyDown) {
                    return@onPreviewKeyEvent false
                }
                when (event.key) {
                    Key.Escape -> {
                        continuousSeekState.stop()
                        if (state.isMenuVisible) {
                            // 键盘 ESC 先收起菜单；系统返回键统一交给 BackHandler，避免一次按键被消费两遍。
                            viewModel.closeMenu()
                        } else {
                            onExitRequested()
                        }
                        true
                    }
                    Key.DirectionCenter,
                    Key.Enter,
                    Key.NumPadEnter,
                    Key.Spacebar,
                    -> {
                        if (state.isMenuVisible) {
                            return@onPreviewKeyEvent false
                        }
                        // 先露出壳层再切播放，避免隐藏态误以为无响应。
                        revealChrome()
                        // Flutter TV 全屏页菜单未弹出时，确认键只切换播放暂停。
                        scope.launch { viewModel.togglePlayPause() }
                        true
                    }
                    Key.DirectionLeft -> {
                        if (state.isMenuVisible) {
                            return@onPreviewKeyEvent false
                        }
                        revealChrome()
                        if (event.isSeekRepeatEvent()) {
                            // 原生 repeat 只维持长按态，实际连续节拍由内部 100ms tick 控制。
                            return@onPreviewKeyEvent true
                        }
                        val holdMs = event.resolveSeekHoldMs()
                        continuousSeekState.start(
                            direction = -1,
                            initialHoldMs = holdMs,
                        )
                        true
                    }
                    Key.DirectionRight -> {
                        if (state.isMenuVisible) {
                            return@onPreviewKeyEvent false
                        }
                        revealChrome()
                        if (event.isSeekRepeatEvent()) {
                            // 原生 repeat 只消费不下发 seek，避免叠加内部 tick 后过快跳动。
                            return@onPreviewKeyEvent true
                        }
                        val holdMs = event.resolveSeekHoldMs()
                        continuousSeekState.start(
                            direction = 1,
                            initialHoldMs = holdMs,
                        )
                        true
                    }
                    Key.DirectionDown -> {
                        if (state.isMenuVisible) {
                            return@onPreviewKeyEvent false
                        }
                        continuousSeekState.stop()
                        // Flutter TV 全屏页下键呼出底部菜单，默认进入播放列表。
                        viewModel.openMenu(PLAYER_MENU_PLAYLIST)
                        // 打开菜单也算一次操作，开始 4s 无操作计时。
                        bumpMenuInteraction()
                        true
                    }
                    else -> false
                }
            }
            .focusable()
                ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentAlignment = Alignment.Center,
        ) {
            // 全屏真铺：不留外边距/圆角裁切，避免视频四周出现黑边框。
            playerSurface(state)
        }

        if (state.shouldShowDanmakuOverlay()) {
            TvPlayerDanmakuOverlay(
                emissionVersion = state.danmakuEmissionVersion,
                comments = state.danmakuEmissionComments,
                modifier = Modifier.fillMaxSize(),
            )
        }

        if (shouldShowPlaybackChrome) {
            TvPlayerPlaybackChromeScrim()
        }

        if (shouldShowTopDecorations) {
            TvPlayerTopDecorations(
                playbackRequest = state.playbackRequest,
                showHintText = !state.isSeekOverlayVisible,
                modifier = Modifier.align(Alignment.TopStart),
            )
        }

        if (shouldShowCenterPlayButton) {
            TvPlayerCenterPlayButton(
                modifier = Modifier.align(Alignment.Center),
            )
        }

        if (state.isPlayerLoading) {
            TvPlayerLoadingOverlay(
                networkSpeedText = formatNetworkSpeed(state.networkSpeedBytesPerSecond),
                modifier = Modifier.align(Alignment.Center),
            )
        }

        if (state.isSeekOverlayVisible) {
            TvPlayerSeekOverlay(
                direction = state.seekOverlayDirection,
                positionMs = state.seekOverlayDisplayPositionMs,
                durationMs = state.seekOverlayDurationMs,
                modifier = Modifier.align(Alignment.Center),
            )
        }

        if (state.isMenuVisible) {
            // 底部按钮组：用户每次操作后重新计时，无操作才自动收起。
            LaunchedEffect(state.isMenuVisible, menuInteractionKey) {
                if (!state.isMenuVisible) {
                    return@LaunchedEffect
                }
                delay(PLAYER_MENU_AUTO_HIDE_MS)
                // 倒计时结束时菜单仍打开，才执行关闭。
                viewModel.closeMenu()
            }
            // 对齐 Flutter：二级菜单在上、一级菜单在下。
            // 底部渐变背景必须保留，托住按钮组可读性。
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .onPreviewKeyEvent {
                        // 任意按键（含方向/确认）后延自动隐藏。
                        bumpMenuInteraction()
                        false
                    }
                    .fillMaxWidth()
                    .background(
                        // 底部背景渐变：上透明、下加深，不能去掉。
                        Brush.verticalGradient(
                            colorStops = arrayOf(
                                0.0f to Color.Transparent,
                                0.28f to Color(0x990A0F16),
                                0.62f to Color(0xD90A0F16),
                                1.0f to Color(0xF205090E),
                            ),
                        ),
                    )
                    // 整组菜单统一左右安全边，避免二级贴边、一级内缩两套规则。
                    .padding(
                        start = 0.dp,
                        top = 20.dp,
                        end = 0.dp,
                        bottom = 22.dp,
                    ),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                when (state.selectedTopMenu) {
                    PLAYER_MENU_PLAYLIST -> {
                        TvPlayerPlaylistMenu(
                            episodes = state.allEpisodes,
                            currentEpisodeId = state.playbackRequest?.episodeId.orEmpty(),
                            focusRequester = secondaryMenuFocusRequesters.firstOrNull(),
                            focusRequesters = secondaryMenuFocusRequesters,
                            // 二级/三级下键：回到一级当前选中项，不跳首项。
                            onArrowDownToPrimary = requestSelectedPrimaryMenuFocus,
                            onArrowUp = null,
                            onEpisodeSelected = { episodeId ->
                                // 选集也是操作，后延关闭。
                                bumpMenuInteraction()
                                scope.launch { viewModel.selectEpisode(episodeId) }
                            },
                        )
                    }
                    PLAYER_MENU_SOURCES -> {
                        TvPlayerSourceMenu(
                            sources = state.availableSources,
                            currentSourceId = state.playbackRequest?.sourceId.orEmpty(),
                            currentSourceName = state.playbackRequest?.sourceName.orEmpty(),
                            // 每条线路仍挂独立 FocusRequester；一级上键落到“当前选中线路”。
                            focusRequesters = secondaryMenuFocusRequesters,
                            onItemCenterXChanged = menuFocusGeometry::updateSecondaryCenterX,
                            // 二级→一级：回到当前选中的一级项。
                            onArrowDown = requestSelectedPrimaryMenuFocus,
                            onSourceSelected = { sourceId ->
                                bumpMenuInteraction()
                                scope.launch { viewModel.selectSource(sourceId) }
                            },
                        )
                    }
                    PLAYER_MENU_ASPECT_RATIO -> {
                        TvPlayerAspectRatioMenu(
                            selectedResizeMode = state.selectedResizeMode,
                            focusRequesters = secondaryMenuFocusRequesters,
                            onItemCenterXChanged = menuFocusGeometry::updateSecondaryCenterX,
                            onArrowDown = requestSelectedPrimaryMenuFocus,
                            onResizeModeSelected = { resizeMode ->
                                bumpMenuInteraction()
                                scope.launch { viewModel.selectResizeMode(resizeMode) }
                            },
                        )
                    }
                    PLAYER_MENU_SPEED -> {
                        TvPlayerSpeedMenu(
                            selectedPlaybackSpeed = state.selectedPlaybackSpeed,
                            focusRequesters = secondaryMenuFocusRequesters,
                            onItemCenterXChanged = menuFocusGeometry::updateSecondaryCenterX,
                            onArrowDown = requestSelectedPrimaryMenuFocus,
                            onPlaybackSpeedSelected = { speed ->
                                bumpMenuInteraction()
                                scope.launch { viewModel.selectPlaybackSpeed(speed) }
                            },
                        )
                    }
                    PLAYER_MENU_OTHER -> {
                        TvPlayerOtherMenu(
                            danmakuEnabled = state.isDanmakuEnabled,
                            skipIntroSeconds = state.skipIntroSeconds,
                            skipOutroSeconds = state.skipOutroSeconds,
                            focusRequesters = secondaryMenuFocusRequesters,
                            onItemCenterXChanged = menuFocusGeometry::updateSecondaryCenterX,
                            onArrowDown = requestSelectedPrimaryMenuFocus,
                            onIntroClick = {
                                bumpMenuInteraction()
                                scope.launch { viewModel.setSkipIntroToCurrentPosition() }
                            },
                            onIntroLongClick = {
                                bumpMenuInteraction()
                                scope.launch { viewModel.clearSkipIntroPosition() }
                            },
                            onOutroClick = {
                                bumpMenuInteraction()
                                scope.launch { viewModel.setSkipOutroToCurrentPosition() }
                            },
                            onOutroLongClick = {
                                bumpMenuInteraction()
                                scope.launch { viewModel.clearSkipOutroPosition() }
                            },
                            onDanmakuToggle = {
                                bumpMenuInteraction()
                                scope.launch { viewModel.toggleDanmakuEnabled() }
                            },
                            onDanmakuMatchRequested = {
                                bumpMenuInteraction()
                                // 手动匹配默认沿用当前片名，贴近 Flutter TV 弹幕搜索面板。
                                onDanmakuMatchRequested(resolveDanmakuMatchQuery(state.playbackRequest))
                            },
                        )
                    }
                }
                // 一级菜单：左右切换分类，上键回二级，下键停在一级。
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.padding(
                        start = TvTokens.PageHorizontalPadding,
                        end = TvTokens.PageHorizontalPadding,
                    ),
                ) {
                    PLAYER_PRIMARY_MENU_ITEMS.forEachIndexed { index, menu ->
                        val primaryMenuModifier = if (menu == PLAYER_MENU_OTHER) {
                            Modifier.testTag("tv-player-menu-other")
                        } else {
                            Modifier
                        }
                        TvPlayerMenuChip(
                            label = menu,
                            selected = state.selectedTopMenu == menu,
                            // 一级用更克制的视觉，突出当前分类而非抢二级焦点。
                            compact = true,
                            modifier = primaryMenuModifier.focusRequester(primaryMenuFocusRequesters[index]),
                            onCenterXChanged = { centerX ->
                                menuFocusGeometry.updatePrimaryCenterX(index, centerX)
                            },
                            onFocused = {
                                // 焦点移动也算操作，后延自动隐藏。
                                bumpMenuInteraction()
                                // 焦点移入即切换二级内容，避免再按确认。
                                if (state.selectedTopMenu != menu) {
                                    viewModel.openMenu(menu)
                                }
                            },
                            onArrowUp = {
                                // 播放线路：落到当前选中线路；其余一级：屏幕 X 就近。
                                // 二级→一级统一 requestSelectedPrimaryMenuFocus（当前选中一级项）。
                                if (menu == PLAYER_MENU_SOURCES) {
                                    requestSelectedSecondaryMenuFocus()
                                } else {
                                    requestNearestSecondaryMenuFocus(index)
                                }
                            },
                            onClick = {
                                bumpMenuInteraction()
                                viewModel.openMenu(menu)
                                // 一级确认只切换当前分类；进入二级菜单必须由上键明确触发。
                            },
                        )
                    }
                }
            }
        } else {
            if (shouldShowPlaybackChrome) {
                val progressPositionMs = resolveBottomProgressPositionMs(state)
                val cachedProgressSegments = resolvePlayerCachedProgressSegments(
                    cachedRanges = state.cachedRanges,
                    durationMs = state.durationMs,
                    positionMs = progressPositionMs,
                )
                TvPlayerBottomHint(
                    modifier = Modifier.align(Alignment.BottomStart),
                )
                TvPlayerBottomProgressBar(
                    isPlaying = state.isPlaybackPlaying,
                    positionMs = progressPositionMs,
                    durationMs = state.durationMs,
                    cachedProgressSegments = cachedProgressSegments,
                    modifier = Modifier.align(Alignment.BottomStart),
                )
            }
        }
    }
}

/**
 * TV 弹幕覆盖层。
 *
 * @param emissionVersion 当前弹幕发射批次版本。
 * @param comments 当前批次需要展示的弹幕评论。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerDanmakuOverlay(
    emissionVersion: Int,
    comments: List<TvPlayerDanmakuComment>,
    modifier: Modifier = Modifier,
) {
    var visibleComments by remember { mutableStateOf(emptyList<TvPlayerDanmakuComment>()) }

    LaunchedEffect(emissionVersion, comments) {
        // 每一批弹幕只短暂停留，避免 seek 或暂停后旧弹幕继续遮挡画面。
        visibleComments = comments.take(DANMAKU_OVERLAY_MAX_VISIBLE_COMMENTS)
        if (visibleComments.isNotEmpty()) {
            delay(DANMAKU_OVERLAY_VISIBLE_MS)
            visibleComments = emptyList()
        }
    }

    Box(
        modifier = modifier.testTag("tv-player-danmaku-overlay"),
    ) {
        visibleComments.forEachIndexed { index, comment ->
            Text(
                text = comment.text,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .offset(y = DANMAKU_OVERLAY_TOP_PADDING + DANMAKU_OVERLAY_ROW_SPACING * index)
                    .padding(horizontal = TvTokens.PageHorizontalPadding),
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                color = comment.toDanmakuTextColor(),
            )
        }
    }
}

/**
 * TV 全屏播放器播放列表二级/三级菜单。
 *
 * 布局对齐详情页：选集在上、分组在下；分组无背景条样式。
 * 焦点：二级(选集)↔三级(分组)就近，二级/三级下键回一级当前选中项。
 *
 * @param focusRequester 当前集焦点请求器（一级上键落点）。
 * @param onArrowDownToPrimary 下方向键回到一级当前选中项。
 */
@Composable
private fun TvPlayerPlaylistMenu(
    episodes: List<PlaybackEpisode>,
    currentEpisodeId: String,
    focusRequester: FocusRequester?,
    focusRequesters: List<FocusRequester> = emptyList(),
    onArrowDownToPrimary: () -> Unit,
    onArrowUp: (() -> Unit)? = null,
    onEpisodeSelected: (String) -> Unit,
) {
    if (episodes.isEmpty()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
            ),
        ) {
            val emptyModifier = (focusRequester ?: focusRequesters.firstOrNull())?.let {
                Modifier.focusRequester(it)
            } ?: Modifier
            TvPlayerMenuChip(
                label = "暂无选集",
                selected = true,
                modifier = emptyModifier,
                onArrowDown = onArrowDownToPrimary,
                onArrowUp = onArrowUp,
                onClick = {},
            )
        }
        return
    }

    val groups = episodes.chunked(PLAYER_PLAYLIST_GROUP_SIZE)
    val showGroupChoices = groups.size > 1
    // 默认落在当前集所在分组，保证打开菜单后一级上键能进二级。
    val initialGroup = remember(episodes, currentEpisodeId) {
        val index = episodes.indexOfFirst { episode -> episode.id == currentEpisodeId }
            .takeIf { value -> value >= 0 } ?: 0
        index / PLAYER_PLAYLIST_GROUP_SIZE
    }
    var selectedGroup by remember(initialGroup) { mutableIntStateOf(initialGroup) }
    val safeGroup = selectedGroup.coerceIn(0, groups.lastIndex)
    val group = groups[safeGroup]
    val currentInGroupIndex = group.indexOfFirst { episode -> episode.id == currentEpisodeId }
        .takeIf { value -> value >= 0 } ?: 0
    // 当前集优先挂 secondary 焦点，保证一级→二级就近落到“正在播的那一集”。
    val currentEpisodeFocusRequester = focusRequester ?: focusRequesters.firstOrNull()
    // 三级分组焦点：数量随分组变化，供二级下键就近落到当前分组。
    val groupFocusRequesters = remember(groups.size) {
        List(groups.size) { FocusRequester() }
    }
    val requestCurrentGroupFocus: () -> Unit = {
        groupFocusRequesters.getOrNull(safeGroup)?.let { requester ->
            runCatching { requester.requestFocus() }
        }
    }
    val requestCurrentEpisodeFocus: () -> Unit = {
        currentEpisodeFocusRequester?.let { requester ->
            runCatching { requester.requestFocus() }
        }
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // 二级：选集在上（对齐详情页）。
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
            ),
        ) {
            items(group.size) { i ->
                val ep = group[i]
                val isFirst = i == 0
                val isLast = i == group.lastIndex
                val isCurrent = ep.id == currentEpisodeId
                val itemModifier = when {
                    isCurrent && currentEpisodeFocusRequester != null ->
                        Modifier.focusRequester(currentEpisodeFocusRequester)
                    isFirst && currentEpisodeFocusRequester != null && currentInGroupIndex == 0 ->
                        Modifier.focusRequester(currentEpisodeFocusRequester)
                    else -> Modifier
                }
                TvPlayerMenuChip(
                    label = ep.title.ifBlank {
                        val absoluteIndex = safeGroup * PLAYER_PLAYLIST_GROUP_SIZE + i + 1
                        "第${absoluteIndex.toString().padStart(2, '0')}集"
                    },
                    selected = isCurrent,
                    modifier = itemModifier,
                    // 有三级分组时下键进分组；否则直接回一级当前选中项。
                    onArrowDown = if (showGroupChoices) {
                        { requestCurrentGroupFocus() }
                    } else {
                        onArrowDownToPrimary
                    },
                    onArrowUp = onArrowUp,
                    onClick = { onEpisodeSelected(ep.id) },
                    onArrowLeft = if (isFirst && safeGroup > 0) {
                        {
                            selectedGroup = safeGroup - 1
                        }
                    } else {
                        null
                    },
                    onArrowRight = if (isLast && safeGroup < groups.lastIndex) {
                        {
                            selectedGroup = safeGroup + 1
                        }
                    } else {
                        null
                    },
                )
            }
        }

        // 三级：分组在下，样式对齐详情页（无背景 chip，仅底线 + 文字）。
        if (showGroupChoices) {
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(17.dp),
                contentPadding = PaddingValues(
                    start = TvTokens.PageHorizontalPadding,
                    end = TvTokens.PageHorizontalPadding,
                ),
                modifier = Modifier.height(52.dp),
            ) {
                items(groups.size) { gi ->
                    val start = gi * PLAYER_PLAYLIST_GROUP_SIZE + 1
                    val end = minOf((gi + 1) * PLAYER_PLAYLIST_GROUP_SIZE, episodes.size)
                    TvPlayerEpisodeGroupChoice(
                        label = "$start-$end",
                        selected = gi == safeGroup,
                        focusRequester = groupFocusRequesters.getOrNull(gi),
                        // 上键回二级当前集（就近：回到正在看的那一集）。
                        onArrowUp = { requestCurrentEpisodeFocus() },
                        // 下键回一级当前选中项，不跳到一级首项。
                        onArrowDown = onArrowDownToPrimary,
                        onArrowLeft = if (gi > 0) {
                            {
                                selectedGroup = gi - 1
                                groupFocusRequesters.getOrNull(gi - 1)?.let { requester ->
                                    runCatching { requester.requestFocus() }
                                }
                            }
                        } else {
                            null
                        },
                        onArrowRight = if (gi < groups.lastIndex) {
                            {
                                selectedGroup = gi + 1
                                groupFocusRequesters.getOrNull(gi + 1)?.let { requester ->
                                    runCatching { requester.requestFocus() }
                                }
                            }
                        } else {
                            null
                        },
                        onFocused = {
                            // 分组获焦即切换，对齐详情页“移动即切换”。
                            if (selectedGroup != gi) {
                                selectedGroup = gi
                            }
                        },
                        onClick = { selectedGroup = gi },
                    )
                }
            }
        }
    }
}

/**
 * 全屏播放列表分组选项（对齐详情页 NcatEpisodeGroupChoice：无背景块）。
 *
 * @param label 分组文案，如 `1-20`。
 * @param selected 是否当前分组。
 * @param focusRequester 焦点请求器。
 * @param onArrowUp 上键回调。
 * @param onArrowDown 下键回调。
 * @param onArrowLeft 左键回调。
 * @param onArrowRight 右键回调。
 * @param onFocused 获焦回调。
 * @param onClick 确认回调。
 */
@Composable
private fun TvPlayerEpisodeGroupChoice(
    label: String,
    selected: Boolean,
    focusRequester: FocusRequester?,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
    onFocused: (() -> Unit)? = null,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val active = selected || isFocused
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.05f else 1f,
        animationSpec = tween(140),
        label = "tvPlayerEpisodeGroupScale",
    )
    Column(
        modifier = Modifier
            .widthIn(min = 60.dp)
            .scale(scale)
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .onFocusChanged { focusState ->
                if (focusState.isFocused) {
                    onFocused?.invoke()
                }
            }
            .focusable(interactionSource = interactionSource)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) {
                    return@onPreviewKeyEvent false
                }
                when (event.key) {
                    Key.Enter,
                    Key.DirectionCenter,
                    -> {
                        onClick()
                        true
                    }
                    Key.DirectionUp -> {
                        onArrowUp?.invoke()
                        onArrowUp != null
                    }
                    Key.DirectionDown -> {
                        onArrowDown?.invoke()
                        onArrowDown != null
                    }
                    Key.DirectionLeft -> {
                        onArrowLeft?.invoke()
                        onArrowLeft != null
                    }
                    Key.DirectionRight -> {
                        onArrowRight?.invoke()
                        onArrowRight != null
                    }
                    else -> false
                }
            },
        horizontalAlignment = Alignment.Start,
    ) {
        // 顶线：未选中浅灰，选中/获焦主题红；无整块背景。
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(13.dp)
                .padding(top = 5.dp)
                .background(Color(0xFF454852), RoundedCornerShape(2.dp)),
        ) {
            if (active) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(13.dp)
                        .background(TvTokens.Accent, RoundedCornerShape(2.dp)),
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = label,
            color = if (active) TvTokens.Accent else Color.White.copy(alpha = 0.86f),
            fontSize = 15.sp,
            fontWeight = if (active) FontWeight.Bold else FontWeight.Medium,
        )
    }
}

/**
 * TV 全屏播放器播放线路二级菜单。
 *
 * @param focusRequesters 每条线路的焦点请求器（与二级菜单列表对齐）。
 * @param onItemCenterXChanged 二级项窗口中心 X 回调，用于一级上键空间就近。
 * @param onArrowDown 下方向键回到一级当前选中项。
 */
@Composable
private fun TvPlayerSourceMenu(
    sources: List<PlaybackSource>,
    currentSourceId: String,
    currentSourceName: String = "",
    focusRequesters: List<FocusRequester> = emptyList(),
    onItemCenterXChanged: ((Int, Float) -> Unit)? = null,
    onArrowDown: () -> Unit,
    onSourceSelected: (String) -> Unit,
) {
    if (sources.isEmpty()) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            TvPlayerMenuChip(
                label = "当前线路",
                selected = true,
                modifier = focusRequesters.firstOrNull()?.let { Modifier.focusRequester(it) } ?: Modifier,
                onCenterXChanged = { centerX -> onItemCenterXChanged?.invoke(0, centerX) },
                onArrowDown = onArrowDown,
                onClick = {},
            )
        }
    } else {
        // 视觉贴右屏边：列表 viewport 拉满右侧；仅滚动到末项时用 contentPadding.end 留安全边。
        // 获焦项滚动进视口，配合锚点放大，避免焦点裁切遮挡。
        val sourceChipOverflowY = PLAYER_MENU_CHIP_HEIGHT * ((PLAYER_MENU_FOCUSED_SCALE - 1f) / 2f)
        // 二级线路菜单：上下回到一级再下探时保持横向偏移，不复位。
        val listState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
        val scrollScope = rememberCoroutineScope()
        var activeFocusedIndex by remember {
            mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex)
        }
        LazyRow(
            state = listState,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(
                // 二级线路与一级菜单左右安全边对齐，滚动仍由 LazyRow 单独控制。
                start = TvTokens.PageHorizontalPadding,
                end = PLAYER_MENU_LIST_END_PADDING,
                top = sourceChipOverflowY,
                bottom = sourceChipOverflowY,
            ),
            // 上下回到一级再下探时清会话，保持横向偏移不复位。
            modifier = Modifier
                .fillMaxWidth()
                .height(PLAYER_MENU_CHIP_HEIGHT + sourceChipOverflowY * 2)
                .focusProperties {
                    onEnter = {
                        val isVerticalEnter =
                            requestedFocusDirection == FocusDirection.Up ||
                                requestedFocusDirection == FocusDirection.Down
                        if (isVerticalEnter) {
                            activeFocusedIndex = TvLayeredHorizontalFocusScroll.NoActiveIndex
                        }
                    }
                }
                .focusGroup(),
        ) {
            items(sources.size) { i ->
                val src = sources[i]
                val isFirst = i == 0
                val isLast = i == sources.lastIndex
                val itemFocusRequester = focusRequesters.getOrNull(i)
                val isSelected = isCurrentPlaybackSource(
                    source = src,
                    currentSourceId = currentSourceId,
                    currentSourceName = currentSourceName,
                )
                TvPlayerMenuChip(
                    label = src.name.ifBlank { "线路${i + 1}" },
                    selected = isSelected,
                    // 首项左锚向右扩，末项右锚向左扩，中间居中，避免左右裁切抖动。
                    focusScaleOrigin = when {
                        isFirst && isLast -> TransformOrigin.Center
                        isFirst -> TransformOrigin(0f, 0.5f)
                        isLast -> TransformOrigin(1f, 0.5f)
                        else -> TransformOrigin.Center
                    },
                    modifier = (if (itemFocusRequester != null) {
                        Modifier.focusRequester(itemFocusRequester)
                    } else {
                        Modifier
                    }).onFocusChanged { focusState ->
                        if (focusState.isFocused) {
                            // 仅同轨左右相邻才滚；从一级菜单跨层进入保持原横向位置。
                            val shouldScroll =
                                TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                    previousActiveIndex = activeFocusedIndex,
                                    newlyFocusedIndex = i,
                                )
                            activeFocusedIndex = i
                            if (shouldScroll) {
                                scrollPlayerMenuChipIntoView(
                                    listState = listState,
                                    index = i,
                                    itemCount = sources.size,
                                    scrollScope = scrollScope,
                                )
                            }
                        }
                    },
                    onCenterXChanged = { centerX -> onItemCenterXChanged?.invoke(i, centerX) },
                    // 下键回一级当前选中项；上键不在二级内循环抢焦点。
                    onArrowDown = onArrowDown,
                    onClick = { onSourceSelected(src.id) },
                )
            }
        }
    }
}

/**
 * TV 全屏播放器画面比例二级菜单。
 *
 * @param selectedResizeMode 当前选中的画面比例。
 * @param focusRequesters 二级菜单焦点请求器。
 * @param onArrowDown 下方向键回到一级菜单。
 * @param onResizeModeSelected 画面比例确认回调。
 */
@Composable
private fun TvPlayerAspectRatioMenu(
    selectedResizeMode: TvResizeMode,
    focusRequesters: List<FocusRequester>,
    onItemCenterXChanged: ((Int, Float) -> Unit)? = null,
    onArrowDown: () -> Unit,
    onResizeModeSelected: (TvResizeMode) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.padding(
            start = TvTokens.PageHorizontalPadding,
            end = TvTokens.PageHorizontalPadding,
        ),
    ) {
        PLAYER_ASPECT_RATIO_OPTIONS.forEachIndexed { index, option ->
            val resizeMode = option.toPlayerResizeMode()
            val itemModifier = focusRequesters.getOrNull(index)?.let { requester ->
                Modifier.focusRequester(requester)
            } ?: Modifier
            TvPlayerMenuChip(
                label = option,
                selected = resizeMode == selectedResizeMode,
                modifier = itemModifier,
                onCenterXChanged = { centerX -> onItemCenterXChanged?.invoke(index, centerX) },
                onArrowDown = onArrowDown,
                onClick = { onResizeModeSelected(resizeMode) },
            )
        }
    }
}

/**
 * TV 全屏播放器倍速二级菜单。
 *
 * @param selectedPlaybackSpeed 当前选中的播放倍速。
 * @param focusRequesters 二级菜单焦点请求器。
 * @param onArrowDown 下方向键回到一级菜单。
 * @param onPlaybackSpeedSelected 倍速确认回调。
 */
@Composable
private fun TvPlayerSpeedMenu(
    selectedPlaybackSpeed: Float,
    focusRequesters: List<FocusRequester>,
    onItemCenterXChanged: ((Int, Float) -> Unit)? = null,
    onArrowDown: () -> Unit,
    onPlaybackSpeedSelected: (Float) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.padding(
            start = TvTokens.PageHorizontalPadding,
            end = TvTokens.PageHorizontalPadding,
        ),
    ) {
        PLAYER_SPEED_OPTIONS.forEachIndexed { index, option ->
            val playbackSpeed = option.toPlayerSpeed()
            val itemModifier = focusRequesters.getOrNull(index)?.let { requester ->
                Modifier.focusRequester(requester)
            } ?: Modifier
            TvPlayerMenuChip(
                label = option,
                selected = kotlin.math.abs(playbackSpeed - selectedPlaybackSpeed) < 0.01f,
                modifier = itemModifier,
                onCenterXChanged = { centerX -> onItemCenterXChanged?.invoke(index, centerX) },
                onArrowDown = onArrowDown,
                onClick = { onPlaybackSpeedSelected(playbackSpeed) },
            )
        }
    }
}

/**
 * TV 全屏播放器其它二级菜单。
 *
 * @param danmakuEnabled 当前弹幕开关状态。
 * @param skipIntroSeconds 片头跳过秒数。
 * @param skipOutroSeconds 片尾跳过剩余秒数。
 * @param focusRequesters 二级菜单焦点请求器。
 * @param onArrowDown 下方向键回到一级菜单。
 * @param onIntroClick 片头短按设置回调。
 * @param onIntroLongClick 片头长按清空回调。
 * @param onOutroClick 片尾短按设置回调。
 * @param onOutroLongClick 片尾长按清空回调。
 * @param onDanmakuToggle 弹幕开关确认回调。
 * @param onDanmakuMatchRequested 手动匹配确认回调。
 */
@Composable
private fun TvPlayerOtherMenu(
    danmakuEnabled: Boolean,
    skipIntroSeconds: Int,
    skipOutroSeconds: Int,
    focusRequesters: List<FocusRequester>,
    onItemCenterXChanged: ((Int, Float) -> Unit)? = null,
    onArrowDown: () -> Unit,
    onIntroClick: () -> Unit,
    onIntroLongClick: () -> Unit,
    onOutroClick: () -> Unit,
    onOutroLongClick: () -> Unit,
    onDanmakuToggle: () -> Unit,
    onDanmakuMatchRequested: () -> Unit,
) {
    Column(
        modifier = Modifier.padding(
            start = TvTokens.PageHorizontalPadding,
            end = TvTokens.PageHorizontalPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = "确认设置当前时间 · 长按清空",
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.64f),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            PLAYER_OTHER_MENU_ITEMS.forEachIndexed { index, item ->
                val label = when (item) {
                    PLAYER_OTHER_INTRO -> "片头 ${formatPlayerDuration(skipIntroSeconds * 1_000L)}"
                    PLAYER_OTHER_OUTRO -> "片尾 ${formatPlayerDuration(skipOutroSeconds * 1_000L)}"
                    PLAYER_OTHER_DANMAKU -> {
                        // 弹幕入口文案跟随当前开关，和 Flutter TV 菜单保持一致。
                        if (danmakuEnabled) "弹幕 开" else "弹幕 关"
                    }
                    else -> item
                }
                val itemModifier = focusRequesters.getOrNull(index)?.let { requester ->
                    Modifier.focusRequester(requester)
                } ?: Modifier
                TvPlayerMenuChip(
                    label = label,
                    selected = item == PLAYER_OTHER_DANMAKU && danmakuEnabled,
                    modifier = itemModifier,
                    onCenterXChanged = { centerX -> onItemCenterXChanged?.invoke(index, centerX) },
                    onArrowDown = onArrowDown,
                    onClick = {
                        // 弹幕项和手动匹配项分别承接 Flutter TV 的两个真实动作。
                        when (item) {
                            PLAYER_OTHER_INTRO -> onIntroClick()
                            PLAYER_OTHER_OUTRO -> onOutroClick()
                            PLAYER_OTHER_DANMAKU -> onDanmakuToggle()
                            PLAYER_OTHER_MANUAL_MATCH -> onDanmakuMatchRequested()
                        }
                    },
                    onLongClick = when (item) {
                        PLAYER_OTHER_INTRO -> onIntroLongClick
                        PLAYER_OTHER_OUTRO -> onOutroLongClick
                        else -> null
                    },
                )
            }
        }
    }
}

/**
 * 解析弹幕手动匹配默认搜索词。
 *
 * @param playbackRequest 当前播放请求。
 * @return 优先使用片名，缺失时用视频 ID 兜底。
 */
private fun resolveDanmakuMatchQuery(playbackRequest: PlaybackRequest?): String {
    return playbackRequest?.videoTitle
        ?.trim()
        ?.ifBlank { playbackRequest.videoId.trim() }
        .orEmpty()
}

/**
 * TV 全屏播放器暂停和 seek 壳层可读性遮罩。
 */
@Composable
private fun TvPlayerPlaybackChromeScrim() {
    Box(
        modifier = Modifier
            .testTag("tv-player-playback-chrome-scrim")
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colorStops = arrayOf(
                        // 顶部标题可读；中段透明不挡画面；底部加深托住进度条。
                        0.0f to Color.Black.copy(alpha = 0.42f),
                        0.16f to Color.Transparent,
                        0.62f to Color.Transparent,
                        0.84f to Color.Black.copy(alpha = 0.34f),
                        1.0f to Color.Black.copy(alpha = 0.58f),
                    ),
                ),
            ),
    )
}

/**
 * TV 全屏播放器顶部标题和时间装饰层。
 *
 * @param playbackRequest 当前播放请求。
 * @param showHintText 是否展示右侧操作提示。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerTopDecorations(
    playbackRequest: PlaybackRequest?,
    showHintText: Boolean,
    modifier: Modifier = Modifier,
) {
    var clockText by remember { mutableStateOf(formatPlayerClock(LocalTime.now())) }

    LaunchedEffect(Unit) {
        while (true) {
            clockText = formatPlayerClock(LocalTime.now())
            delay(TOP_DECORATION_CLOCK_REFRESH_MS)
        }
    }

    Row(
        modifier = modifier
            .testTag("tv-player-top-decorations")
            .fillMaxWidth()
            .padding(
                start = TvTokens.PageHorizontalPadding,
                top = 18.dp,
                end = TvTokens.PageHorizontalPadding,
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier.weight(if (showHintText) 0.45f else 0.58f),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "‹",
                style = MaterialTheme.typography.headlineMedium,
                color = Color.White,
            )
            Spacer(modifier = Modifier.width(14.dp))
            Text(
                text = resolveTopDecorationTitle(playbackRequest),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
            )
        }

        Row(
            modifier = Modifier.weight(if (showHintText) 0.52f else 0.34f),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (showHintText) {
                Text(
                    text = "按返回键返回上一页 | 下键打开播放设置",
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.End,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    color = Color.White.copy(alpha = 0.94f),
                )
                Spacer(modifier = Modifier.width(18.dp))
            }
            Text(
                text = "☷",
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = clockText,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
            )
        }
    }
}

/**
 * TV 全屏播放器暂停态中心播放提示。
 *
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerCenterPlayButton(
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .testTag("tv-player-center-play")
            .size(64.dp)
            .background(
                color = Color.Black.copy(alpha = 0.52f),
                shape = CircleShape,
            )
            .border(
                width = 1.5.dp,
                color = Color.White.copy(alpha = 0.28f),
                shape = CircleShape,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "▶",
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White,
        )
    }
}

/**
 * TV 全屏播放器中心 seek 提示。
 *
 * @param direction seek 方向。
 * @param positionMs 展示播放位置，单位毫秒。
 * @param durationMs 展示总时长，单位毫秒。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerSeekOverlay(
    direction: Int,
    positionMs: Long,
    durationMs: Long,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .testTag("tv-player-seek-overlay")
            .width(232.dp)
            .height(94.dp)
            .background(
                color = Color(0xFF10161D).copy(alpha = 0.80f),
                shape = RoundedCornerShape(10.dp),
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.08f),
                shape = RoundedCornerShape(10.dp),
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = if (direction < 0) "«" else "»",
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White,
        )
        Text(
            text = "${formatPlayerDuration(positionMs)}/${formatPlayerDuration(durationMs)}",
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
        )
    }
}

/**
 * 渲染默认播放器画面层。
 *
 * @param surfaceState 播放器当前界面状态。
 */
@Composable
private fun TvPlayerDefaultSurface(surfaceState: TvPlayerUiState) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = "IvyTV",
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White.copy(alpha = 0.72f),
        )
        val request = surfaceState.playbackRequest
        if (request != null) {
            // 真正播放器内核接入前，先暴露当前播放身份，防止全屏页丢失详情选择。
            Text(
                text = "${request.videoId} · ${request.sourceId} · ${request.episodeId}",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.82f),
            )
            Text(
                text = if (surfaceState.isPlaybackPlaying) "播放中" else "已暂停",
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.68f),
            )
        }
        if (!surfaceState.playerErrorMessage.isNullOrBlank()) {
            Text(
                text = surfaceState.playerErrorMessage,
                style = MaterialTheme.typography.bodyMedium,
                color = TvTokens.Danger,
            )
        }
    }
}

/**
 * TV 全屏播放器 loading 覆盖层。
 *
 * @param networkSpeedText 当前网速文案，未知时使用 `0KB/s`。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerLoadingOverlay(
    networkSpeedText: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.testTag("tv-player-fullscreen-loading"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator(
            modifier = Modifier
                .size(36.dp)
                .shadow(
                    elevation = 4.dp,
                    shape = CircleShape,
                    clip = false,
                ),
            color = Color.White,
            strokeWidth = 3.dp,
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = "加载中",
            style = MaterialTheme.typography.titleMedium,
            color = Color.White.copy(alpha = 0.94f),
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = networkSpeedText,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White.copy(alpha = 0.72f),
        )
    }
}

/**
 * 格式化播放器时间。
 *
 * @param positionMs 播放位置，单位毫秒。
 * @return `m:ss` 或 `h:mm:ss` 时间文本。
 */
private fun formatPlayerDuration(positionMs: Long): String {
    val totalSeconds = (positionMs / 1_000L).coerceAtLeast(0L)
    val hours = totalSeconds / 3_600L
    val minutes = (totalSeconds / 60L) % 60L
    val seconds = totalSeconds % 60L
    return if (hours > 0L) {
        "$hours:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
    } else {
        "$minutes:${seconds.toString().padStart(2, '0')}"
    }
}

/**
 * 格式化播放器 loading 网速。
 *
 * @param bytesPerSecond 当前下载网速，单位 B/s。
 * @return TV loading 覆盖层展示的网速文案。
 */
private fun formatNetworkSpeed(bytesPerSecond: Long): String {
    if (bytesPerSecond <= 0L) {
        return "0KB/s"
    }
    val kilobytesPerSecond = (bytesPerSecond + 1_023L) / 1_024L
    if (kilobytesPerSecond < 1_024L) {
        // KB 档位用整数，避免 TV loading 文案在低速时频繁抖动。
        return "${kilobytesPerSecond}KB/s"
    }
    val megabytesTenths = bytesPerSecond * 10L / (1_024L * 1_024L)
    return "${megabytesTenths / 10L}.${megabytesTenths % 10L}MB/s"
}

/**
 * 格式化播放器顶部时钟。
 *
 * @param time 当前本地时间。
 * @return `HH:mm` 顶部时钟文本。
 */
private fun formatPlayerClock(time: LocalTime): String {
    return time.format(DateTimeFormatter.ofPattern("HH:mm"))
}

/**
 * 将 Flutter TV 菜单文案映射为播放器画面比例协议。
 *
 * @return 当前菜单项对应的画面比例模式。
 */
private fun String.toPlayerResizeMode(): TvResizeMode {
    return when (this) {
        "填充" -> TvResizeMode.FILL
        "宽度" -> TvResizeMode.WIDTH
        "高度" -> TvResizeMode.HEIGHT
        else -> TvResizeMode.FIT
    }
}

/**
 * 将倍速菜单文案转换为播放器协议数值。
 *
 * @return 可下发给播放器内核的倍速。
 */
private fun String.toPlayerSpeed(): Float {
    return removeSuffix("x").toFloatOrNull() ?: PLAYER_DEFAULT_SPEED
}

/**
 * 解析顶部播放身份文案。
 *
 * @param request 当前播放请求。
 * @return 顶部左侧标题与剧集信息。
 */
private fun resolveTopDecorationTitle(request: PlaybackRequest?): String {
    if (request == null) {
        return "IvyTV | 当前播放"
    }
    // 对齐 Flutter TV：左侧展示「片名 | 集数标题」，不暴露内部 videoId。
    val title = request.videoTitle.trim().ifBlank { request.videoId.trim() }.ifBlank { "IvyTV" }
    val episodeLabel = request.episodeTitle.trim().ifBlank {
        request.episodeId.trim().ifBlank { "当前集" }
    }
    return "$title | $episodeLabel"
}

/**
 * 记住全屏播放器连续 seek 状态。
 *
 * @param scope 播放器壳层协程作用域。
 * @param viewModel 播放器状态模型。
 * @return 当前播放器实例绑定的连续 seek 状态。
 */
@Composable
private fun rememberContinuousSeekState(
    scope: CoroutineScope,
    viewModel: TvPlayerViewModel,
): ContinuousSeekState {
    return remember(scope, viewModel) {
        ContinuousSeekState(
            scope = scope,
            viewModel = viewModel,
        )
    }
}

/**
 * 管理遥控器左右键长按的连续 seek 调度。
 *
 * @property scope 播放器壳层协程作用域。
 * @property viewModel 播放器状态模型。
 */
private class ContinuousSeekState(
    private val scope: CoroutineScope,
    private val viewModel: TvPlayerViewModel,
) {
    /** 当前连续 seek 任务。 */
    private var seekJob: Job? = null

    /**
     * 开始一次方向键 seek。
     *
     * @param direction seek 方向，`1` 为快进，`-1` 为快退。
     * @param initialHoldMs 首次按下使用的短按时长。
     */
    fun start(
        direction: Int,
        initialHoldMs: Long,
    ) {
        stop()
        seekJob = scope.launch {
            // 初次按下先执行 10 秒短跳；若用户很快松手，就保持短按语义。
            viewModel.seekByDirection(
                direction = direction,
                holdMs = initialHoldMs,
            )
            delay(CONTINUOUS_SEEK_START_DELAY_MS)

            var holdMs = CONTINUOUS_SEEK_START_DELAY_MS
            while (isActive) {
                // 长按进入内部节拍后，每 100ms 按 12/22 秒分档规则连续推进。
                viewModel.seekByDirection(
                    direction = direction,
                    holdMs = holdMs,
                )
                delay(CONTINUOUS_SEEK_TICK_MS)
                holdMs += CONTINUOUS_SEEK_TICK_MS
            }
        }
    }

    /**
     * 停止当前连续 seek。
     */
    fun stop() {
        seekJob?.cancel()
        seekJob = null
    }
}

/**
 * 解析遥控器 seek 按住时长。
 *
 * @return 短按返回 100ms，长按 repeat 返回 Android 原生按住时长。
 */
private fun androidx.compose.ui.input.key.KeyEvent.resolveSeekHoldMs(): Long {
    val nativeEvent = nativeKeyEvent
    if (nativeEvent.repeatCount <= 0) {
        // 初次按下仍按短按处理，避免未达到保护阈值时误入长按 seek。
        return 100L
    }
    val holdMs = nativeEvent.eventTime - nativeEvent.downTime
    return holdMs.coerceAtLeast(0L)
}

/**
 * 判断当前按键是否是左右 seek 方向键。
 *
 * @return 左右方向键返回 true。
 */
private fun Key.isSeekDirectionKey(): Boolean {
    return this == Key.DirectionLeft || this == Key.DirectionRight
}

/**
 * 判断当前按键事件是否是 Android 原生 repeat。
 *
 * @return repeatCount 大于 0 时返回 true。
 */
private fun androidx.compose.ui.input.key.KeyEvent.isSeekRepeatEvent(): Boolean {
    return nativeKeyEvent.repeatCount > 0
}

/**
 * 解析底部进度条展示位置。
 *
 * @param state 当前播放器界面状态。
 * @return seek 期间使用真实 seek 目标，否则使用当前播放位置。
 */
private fun resolveBottomProgressPositionMs(state: TvPlayerUiState): Long {
    return if (state.isSeekOverlayVisible) {
        // 底部进度条必须跟随真实 seek 目标，不能使用中心提示的装饰性展示时间。
        state.seekOverlayPositionMs
    } else {
        state.currentPositionMs
    }
}

/**
 * 判断是否展示弹幕覆盖层。
 *
 * @return 当前已有弹幕剧集且不在加载中时展示覆盖层。
 */
private fun TvPlayerUiState.shouldShowDanmakuOverlay(): Boolean {
    return isDanmakuEnabled && currentDanmakuEpisodeId != null && !isDanmakuLoading
}

/**
 * 将弹幕颜色转换为 Compose 文本颜色。
 *
 * @return 带不透明 alpha 的弹幕颜色。
 */
private fun TvPlayerDanmakuComment.toDanmakuTextColor(): Color {
    return Color(0xFF000000 or (color.toLong() and 0x00FFFFFF))
}

/**
 * 计算底部进度条缓存分段。
 *
 * @param cachedRanges 播放器上报的缓存区间。
 * @param durationMs 视频总时长，单位毫秒。
 * @param positionMs 当前播放位置，单位毫秒。
 * @return 已合并且裁剪后的可绘制分段。
 */
internal fun resolvePlayerCachedProgressSegments(
    cachedRanges: List<TvPlayerCachedRange>,
    durationMs: Long,
    positionMs: Long,
): List<TvPlayerCachedProgressSegment> {
    if (durationMs <= 0L || cachedRanges.isEmpty()) {
        return emptyList()
    }
    val cappedEndMs = (positionMs.coerceAtLeast(0L) + BOTTOM_PROGRESS_CACHE_FORWARD_LIMIT_MS)
        .coerceAtMost(durationMs)
    return cachedRanges
        .filter { range -> range.endMs > range.startMs }
        .sortedBy(TvPlayerCachedRange::startMs)
        .fold(emptyList<TvPlayerCachedRange>()) { mergedRanges, nextRange ->
            val safeNext = TvPlayerCachedRange(
                startMs = nextRange.startMs.coerceIn(0L, durationMs),
                endMs = nextRange.endMs.coerceIn(0L, durationMs),
            )
            if (safeNext.endMs <= safeNext.startMs) {
                return@fold mergedRanges
            }
            val lastRange = mergedRanges.lastOrNull()
            if (lastRange == null || safeNext.startMs > lastRange.endMs) {
                mergedRanges + safeNext
            } else {
                mergedRanges.dropLast(1) + lastRange.copy(
                    endMs = maxOf(lastRange.endMs, safeNext.endMs),
                )
            }
        }
        .mapNotNull { range ->
            val startMs = range.startMs.coerceAtMost(cappedEndMs)
            val endMs = range.endMs.coerceAtMost(cappedEndMs)
            if (endMs <= startMs) {
                null
            } else {
                TvPlayerCachedProgressSegment(
                    startFraction = (startMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f),
                    endFraction = (endMs.toFloat() / durationMs.toFloat()).coerceIn(0f, 1f),
                )
            }
        }
}

/**
 * TV 全屏播放器底部遥控器安全提醒。
 *
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerBottomHint(
    modifier: Modifier = Modifier,
) {
    Text(
        text = "返回键退出 · 下键播放设置 · 保持安全观看距离",
        modifier = modifier
            .testTag("tv-player-bottom-hint")
            .fillMaxWidth()
            .padding(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
                bottom = 68.dp,
            ),
        textAlign = TextAlign.Center,
        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
        color = Color.White.copy(alpha = 0.70f),
    )
}

/**
 * TV 全屏播放器底部播放进度条。
 *
 * @param isPlaying 当前是否播放中。
 * @param positionMs 展示位置，单位毫秒。
 * @param durationMs 总时长，单位毫秒。
 * @param cachedProgressSegments 已缓存进度分段。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPlayerBottomProgressBar(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    cachedProgressSegments: List<TvPlayerCachedProgressSegment>,
    modifier: Modifier = Modifier,
) {
    val safeDurationMs = durationMs.coerceAtLeast(0L)
    val safePositionMs = if (safeDurationMs > 0L) {
        positionMs.coerceIn(0L, safeDurationMs)
    } else {
        positionMs.coerceAtLeast(0L)
    }
    val progressFraction = if (safeDurationMs > 0L) {
        (safePositionMs.toFloat() / safeDurationMs.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }

    Row(
        modifier = modifier
            .testTag("tv-player-bottom-progress")
            .fillMaxWidth()
            .padding(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
                bottom = 28.dp,
            )
            // 固定行高，保证播放图标/时间/进度条/全屏图标同一基线居中。
            .height(BOTTOM_PROGRESS_ROW_HEIGHT),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (isPlaying) "Ⅱ" else "▶",
            modifier = Modifier.width(18.dp),
            style = MaterialTheme.typography.titleSmall,
            color = Color.White,
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.width(BOTTOM_PROGRESS_INNER_GAP))
        Text(
            text = formatPlayerDuration(safePositionMs),
            modifier = Modifier
                .testTag("tv-player-bottom-current-time-slot")
                .width(BOTTOM_PROGRESS_TIME_SLOT_WIDTH),
            style = MaterialTheme.typography.titleSmall,
            color = Color.White.copy(alpha = 0.96f),
            maxLines = 1,
        )
        // 时间与进度条间距收紧，避免视觉“空一截”。
        Spacer(modifier = Modifier.width(BOTTOM_PROGRESS_TIME_TRACK_GAP))
        BoxWithConstraints(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .testTag("tv-player-bottom-progress-track"),
            contentAlignment = Alignment.CenterStart,
        ) {
            val playedWidth = maxWidth * progressFraction
            val knobOffset = (playedWidth - BOTTOM_PROGRESS_KNOB_RADIUS)
                .coerceIn(0.dp, maxWidth - BOTTOM_PROGRESS_KNOB_SIZE)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(BOTTOM_PROGRESS_TRACK_HEIGHT)
                    .background(
                        color = Color.White.copy(alpha = 0.28f),
                        shape = RoundedCornerShape(999.dp),
                    ),
            )
            cachedProgressSegments.forEach { segment ->
                Box(
                    modifier = Modifier
                        .offset(x = maxWidth * segment.startFraction)
                        .fillMaxWidth(segment.endFraction - segment.startFraction)
                        .height(BOTTOM_PROGRESS_TRACK_HEIGHT)
                        .background(
                            color = Color.White.copy(alpha = 0.42f),
                            shape = RoundedCornerShape(999.dp),
                        ),
                )
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth(progressFraction)
                    .height(BOTTOM_PROGRESS_TRACK_HEIGHT)
                    .background(
                        color = TvTokens.Accent,
                        shape = RoundedCornerShape(999.dp),
                    ),
            )
            Box(
                modifier = Modifier
                    .offset(x = knobOffset)
                    .size(BOTTOM_PROGRESS_KNOB_SIZE)
                    .background(
                        color = TvTokens.Accent,
                        shape = RoundedCornerShape(999.dp),
                    ),
            )
        }
        Spacer(modifier = Modifier.width(BOTTOM_PROGRESS_TIME_TRACK_GAP))
        Text(
            text = formatPlayerDuration(safeDurationMs),
            modifier = Modifier
                .testTag("tv-player-bottom-total-time-slot")
                .width(BOTTOM_PROGRESS_TIME_SLOT_WIDTH),
            textAlign = TextAlign.End,
            style = MaterialTheme.typography.titleSmall,
            color = Color.White.copy(alpha = 0.96f),
            maxLines = 1,
        )
        Spacer(modifier = Modifier.width(BOTTOM_PROGRESS_INNER_GAP))
        // Flutter TV 底部进度条右侧保留展开/全屏示意图标。
        Text(
            text = "⛶",
            modifier = Modifier.width(18.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.92f),
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * TV 全屏播放器控制菜单按钮。
 *
 * @param label 菜单文案。
 * @param modifier 外层修饰器。
 * @param selected 是否为当前二级选中项。
 * @param onFocused 焦点进入回调。
 * @param onArrowUp 上方向键回调。
 * @param onArrowDown 下方向键回调。
 * @param onClick 点击回调。
 * @param onLongClick 长按确认回调。
 */
@Composable
private fun TvPlayerMenuChip(
    label: String,
    modifier: Modifier = Modifier,
    selected: Boolean = false,
    /**
     * 一级菜单更扁更窄，二级选项稍大，避免整组按钮视觉打架。
     */
    compact: Boolean = false,
    /**
     * 获焦放大锚点。
     *
     * 列表首项用左锚、末项用右锚，放大时向列表内侧扩展，避免贴边裁切。
     */
    focusScaleOrigin: TransformOrigin = TransformOrigin.Center,
    /**
     * 布局完成后回报窗口坐标系中心 X，供一级→二级空间就近使用。
     */
    onCenterXChanged: ((Float) -> Unit)? = null,
    onFocused: (() -> Unit)? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val pressPolicy = remember(onLongClick) {
        TvRemotePressPolicy(hasLongPressHandler = onLongClick != null)
    }
    val scale by animateFloatAsState(
        targetValue = if (isFocused) PLAYER_MENU_FOCUSED_SCALE else 1f,
        animationSpec = tween(durationMillis = PLAYER_MENU_FOCUS_ANIMATION_MS),
        label = "tvPlayerMenuChipScale",
    )
    val shape = RoundedCornerShape(if (compact) 10.dp else 12.dp)
    // 选中=主题红；未选中=半透明深灰；获焦只加白边，不改底色。
    val backgroundColor = when {
        selected -> TvTokens.Accent
        else -> Color(0xCC2A303A)
    }
    val chipHeight = if (compact) PLAYER_MENU_PRIMARY_CHIP_HEIGHT else PLAYER_MENU_CHIP_HEIGHT
    val minWidth = if (compact) 96.dp else 104.dp
    val horizontalPadding = if (compact) 16.dp else 18.dp

    Box(
        modifier = modifier
            .height(chipHeight)
            .widthIn(min = minWidth)
            // 布局占位固定，按锚点向内侧视觉放大，配合列表 end/top padding 不裁切不抖动。
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                transformOrigin = focusScaleOrigin
                clip = false
            }
            .clip(shape)
            .background(backgroundColor)
            .onGloballyPositioned { coordinates ->
                if (onCenterXChanged != null) {
                    val bounds: Rect = coordinates.boundsInWindow()
                    onCenterXChanged(bounds.left + bounds.width / 2f)
                }
            }
            .onFocusChanged { focusState ->
                if (focusState.isFocused) {
                    // 一级菜单：焦点移入即切换当前二级菜单。
                    onFocused?.invoke()
                }
            }
            .onPreviewKeyEvent { event ->
                if (
                    event.key == Key.DirectionCenter ||
                    event.key == Key.Enter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                ) {
                    val action = when (event.type) {
                        KeyEventType.KeyDown -> pressPolicy.onKeyDown(
                            isRepeat = pressPolicy.isPressing || event.nativeKeyEvent.repeatCount > 0,
                        )
                        KeyEventType.KeyUp -> pressPolicy.onKeyUp()
                        else -> TvRemotePressAction.None
                    }
                    when (action) {
                        TvRemotePressAction.ShortPress -> onClick()
                        TvRemotePressAction.LongPress -> onLongClick?.invoke()
                        TvRemotePressAction.None -> Unit
                    }
                    return@onPreviewKeyEvent true
                }
                // 自定义方向键：KeyDown 也要消费，否则系统会先把焦点挪到“就近项”，
                // KeyUp 再 requestFocus 到首项，表现为“闪一下第二个再跳回第一个”。
                val directionHandler = when (event.key) {
                    Key.DirectionUp -> onArrowUp
                    Key.DirectionDown -> onArrowDown
                    Key.DirectionLeft -> onArrowLeft
                    Key.DirectionRight -> onArrowRight
                    else -> null
                }
                if (directionHandler != null) {
                    if (event.type == KeyEventType.KeyUp) {
                        directionHandler.invoke()
                    }
                    return@onPreviewKeyEvent true
                }
                false
            }
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) Color.White else Color.White.copy(alpha = 0.10f),
                shape = shape,
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .focusable(interactionSource = interactionSource)
            .padding(horizontal = horizontalPadding),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.titleMedium.copy(
                fontWeight = if (selected || isFocused) FontWeight.SemiBold else FontWeight.Medium,
                fontSize = if (compact) 14.sp else 15.sp,
            ),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/**
 * 记住一组菜单焦点请求器。
 *
 * @param count 当前菜单项数量。
 * @return 与菜单项一一对应的焦点请求器。
 */
@Composable
private fun rememberPlayerMenuFocusRequesters(count: Int): List<FocusRequester> {
    return remember(count) {
        List(count.coerceAtLeast(0)) { FocusRequester() }
    }
}

/**
 * 请求指定菜单项焦点。
 *
 * @param index 目标菜单下标。
 * @return 请求是否成功。
 */
private fun List<FocusRequester>.requestFocusAt(index: Int): Boolean {
    val requester = getOrNull(index) ?: return false
    return runCatching { requester.requestFocus() }.getOrDefault(false)
}

/**
 * 计算当前一级菜单下标。
 *
 * @param state 播放器界面状态。
 * @return 当前一级菜单下标。
 */
private fun resolveSelectedPrimaryMenuIndex(state: TvPlayerUiState): Int {
    return PLAYER_PRIMARY_MENU_ITEMS.indexOf(state.selectedTopMenu).takeIf { index ->
        index >= 0
    } ?: 0
}

/**
 * 计算当前二级菜单项数量。
 *
 * @param state 播放器界面状态。
 * @return 当前二级菜单项数量。
 */
private fun resolveSecondaryMenuItemCount(state: TvPlayerUiState): Int {
    return when (state.selectedTopMenu) {
        PLAYER_MENU_ASPECT_RATIO -> PLAYER_ASPECT_RATIO_OPTIONS.size
        PLAYER_MENU_SPEED -> PLAYER_SPEED_OPTIONS.size
        PLAYER_MENU_OTHER -> PLAYER_OTHER_MENU_ITEMS.size
        // 线路列表每项都要有 FocusRequester，才能就近落到第 N 项。
        PLAYER_MENU_SOURCES -> state.availableSources.size.coerceAtLeast(1)
        PLAYER_MENU_PLAYLIST -> 1
        else -> 0
    }
}

/**
 * 计算当前二级菜单选中项下标。
 *
 * 用于菜单刚打开等“应落在业务选中项”的场景。
 *
 * @param state 播放器界面状态。
 * @return 当前二级菜单选中项下标。
 */
private fun resolveSelectedSecondaryMenuIndex(state: TvPlayerUiState): Int {
    return when (state.selectedTopMenu) {
        PLAYER_MENU_ASPECT_RATIO -> PLAYER_ASPECT_RATIO_OPTIONS.indexOfFirst { option ->
            option.toPlayerResizeMode() == state.selectedResizeMode
        }
        PLAYER_MENU_SPEED -> PLAYER_SPEED_OPTIONS.indexOfFirst { option ->
            kotlin.math.abs(option.toPlayerSpeed() - state.selectedPlaybackSpeed) < 0.01f
        }
        PLAYER_MENU_OTHER -> PLAYER_OTHER_MENU_ITEMS.indexOf(PLAYER_OTHER_DANMAKU)
        PLAYER_MENU_SOURCES -> state.availableSources.indexOfFirst { source ->
            isCurrentPlaybackSource(
                source = source,
                currentSourceId = state.playbackRequest?.sourceId.orEmpty(),
                currentSourceName = state.playbackRequest?.sourceName.orEmpty(),
            )
        }
        else -> 0
    }.takeIf { index -> index >= 0 } ?: 0
}

/**
 * 判断线路列表项是否就是当前播放线路。
 *
 * 详情页线路列表使用页面唯一 id（`source::videoId`），
 * 而 [PlaybackRequest.sourceId] 通常是后台 source 短键，二者不能直接 `==`。
 *
 * @param source 二级菜单线路项。
 * @param currentSourceId 当前播放请求中的线路 id。
 * @param currentSourceName 当前播放请求中的线路名，id 对不上时作兜底。
 * @return 是当前线路时 true。
 */
internal fun isCurrentPlaybackSource(
    source: PlaybackSource,
    currentSourceId: String,
    currentSourceName: String = "",
): Boolean {
    if (matchesPlaybackSourceId(candidateId = source.id, currentSourceId = currentSourceId)) {
        return true
    }
    val name = currentSourceName.trim()
    return name.isNotEmpty() && source.name.trim() == name
}

/**
 * 兼容 `source` 短键与 `source::videoId` / `source+id` 复合键的线路 id 匹配。
 *
 * @param candidateId 列表项 id。
 * @param currentSourceId 播放请求 id。
 * @return 指向同一线路时 true。
 */
internal fun matchesPlaybackSourceId(
    candidateId: String,
    currentSourceId: String,
): Boolean {
    val left = candidateId.trim()
    val right = currentSourceId.trim()
    if (left.isEmpty() || right.isEmpty()) {
        return false
    }
    if (left == right) {
        return true
    }
    // 列表复合键，请求是短键。
    if (left.startsWith("$right::") || left.startsWith("$right+")) {
        return true
    }
    // 请求复合键，列表是短键。
    if (right.startsWith("$left::") || right.startsWith("$left+")) {
        return true
    }
    // 两侧都是复合键时，比 source 段。
    val leftKey = left.substringBefore("::").substringBefore("+")
    val rightKey = right.substringBefore("::").substringBefore("+")
    val leftIsComposite = left.contains("::") || left.contains("+")
    val rightIsComposite = right.contains("::") || right.contains("+")
    return leftIsComposite && rightIsComposite && leftKey.isNotBlank() && leftKey == rightKey
}

/**
 * 底部菜单一级/二级 chip 的窗口中心 X 几何，用于一级上键空间就近。
 */
internal class TvPlayerMenuFocusGeometry {
    /** 一级菜单项中心 X（窗口坐标）。 */
    private val primaryCenterXByIndex = linkedMapOf<Int, Float>()

    /** 当前二级菜单项中心 X（窗口坐标，仅已布局项）。 */
    private val secondaryCenterXByIndex = linkedMapOf<Int, Float>()

    /**
     * 更新一级菜单项中心 X。
     *
     * @param index 一级下标。
     * @param centerX 窗口中心 X。
     */
    fun updatePrimaryCenterX(index: Int, centerX: Float) {
        primaryCenterXByIndex[index] = centerX
    }

    /**
     * 更新二级菜单项中心 X。
     *
     * @param index 二级下标。
     * @param centerX 窗口中心 X。
     */
    fun updateSecondaryCenterX(index: Int, centerX: Float) {
        secondaryCenterXByIndex[index] = centerX
    }

    /**
     * 清空二级坐标（切换一级分类后旧坐标失效）。
     */
    fun clearSecondary() {
        secondaryCenterXByIndex.clear()
    }

    /**
     * 按一级项屏幕 X 找二级里中心最近的项。
     *
     * 只在已布局的二级项中比较（LazyRow 未进屏的项没有坐标）；
     * 若坐标不足则回退到 [fallbackIndex]。
     *
     * @param primaryIndex 当前一级下标。
     * @param fallbackIndex 坐标缺失时的回退下标。
     * @return 空间就近的二级下标。
     */
    fun resolveNearestSecondaryIndex(
        primaryIndex: Int,
        fallbackIndex: Int,
    ): Int {
        val primaryX = primaryCenterXByIndex[primaryIndex] ?: return fallbackIndex.coerceAtLeast(0)
        if (secondaryCenterXByIndex.isEmpty()) {
            return fallbackIndex.coerceAtLeast(0)
        }
        return secondaryCenterXByIndex.minByOrNull { (_, centerX) ->
            abs(centerX - primaryX)
        }?.key ?: fallbackIndex.coerceAtLeast(0)
    }
}

/**
 * 生成播放列表当前集菜单文案。
 *
 * @param playbackRequest 当前播放请求。
 * @return 播放列表二级菜单文案。
 */
private fun resolvePlaylistMenuLabel(playbackRequest: PlaybackRequest?): String {
    val episodeLabel = playbackRequest?.episodeId?.ifBlank { null }
    return episodeLabel ?: "当前播放"
}


/**
 * 播放器二级菜单 chip 获焦后滚进可视安全区。
 *
 * 末项对齐列表末尾，利用 end contentPadding 形成贴边滚动后的右边距；
 * 其余项尽量完整露出，避免焦点放大被右边缘裁切。
 *
 * @param listState 横向列表状态。
 * @param index 获焦下标。
 * @param itemCount 列表总数。
 * @param scrollScope 滚动协程作用域。
 */
private fun scrollPlayerMenuChipIntoView(
    listState: LazyListState,
    index: Int,
    itemCount: Int,
    scrollScope: CoroutineScope,
) {
    if (itemCount <= 0 || index !in 0 until itemCount) {
        return
    }
    scrollScope.launch {
        val lastIndex = itemCount - 1
        if (index >= lastIndex) {
            // 滚到最右：末卡落在 end padding 内侧，视觉有边距。
            listState.animateScrollToItem(lastIndex)
            return@launch
        }
        val visible = listState.layoutInfo.visibleItemsInfo
        val target = visible.firstOrNull { info -> info.index == index }
        val viewportEnd = listState.layoutInfo.viewportEndOffset
        val viewportStart = listState.layoutInfo.viewportStartOffset
        if (target == null) {
            listState.animateScrollToItem(index)
            return@launch
        }
        // 右侧被裁或贴边过紧时，向左推进一格，给获焦放大留空。
        val rightOverflow = target.offset + target.size - viewportEnd
        val leftOverflow = viewportStart - target.offset
        when {
            rightOverflow > 0 -> {
                val nextFirst = (listState.firstVisibleItemIndex + 1).coerceAtMost(index)
                listState.animateScrollToItem(nextFirst)
            }
            leftOverflow > 0 -> {
                listState.animateScrollToItem(index)
            }
        }
    }
}

/**
 * 全屏播放器底部按钮组无操作自动隐藏时长。
 *
 * 用户任意操作后会重置该倒计时，只有持续无操作才关闭。
 */
private const val PLAYER_MENU_AUTO_HIDE_MS = 4_000L

/** 全屏播放列表选集分组大小，对齐详情页每组 20 集。 */
private const val PLAYER_PLAYLIST_GROUP_SIZE = 20

/** 连续 seek 进入长按态前的短按保护时间。 */
private const val CONTINUOUS_SEEK_START_DELAY_MS = 250L

/** 连续 seek 的内部节拍间隔。 */
private const val CONTINUOUS_SEEK_TICK_MS = 100L

/** 顶部时钟刷新间隔，对齐 Flutter TV 的 30 秒刷新。 */
private const val TOP_DECORATION_CLOCK_REFRESH_MS = 30_000L

/** 播放器菜单获焦放大比例，对齐 Flutter TV 的 TvVideoCard.focusedScale。 */
private const val PLAYER_MENU_FOCUSED_SCALE = 1.05f

/** 播放器菜单获焦放大动画时长。 */
private const val PLAYER_MENU_FOCUS_ANIMATION_MS = 140

/** 播放器菜单 chip 固定高度。 */
private val PLAYER_MENU_CHIP_HEIGHT = 46.dp

/** 一级菜单 chip 高度，略矮于二级，形成层级。 */
private val PLAYER_MENU_PRIMARY_CHIP_HEIGHT = 42.dp

/**
 * 线路 chip 水平安全宽度估算。
 *
 * minWidth 只有 108.dp，宽文案实际更宽；用于获焦溢出估算。
 */
private val PLAYER_MENU_CHIP_SAFE_WIDTH = 160.dp

/**
 * 二级线路列表滚到最右时的 end 安全边。
 *
 * 列表 viewport 贴右屏边；仅末项依赖此 padding 与屏边拉开距离。
 */
private val PLAYER_MENU_LIST_END_PADDING = TvTokens.PageHorizontalPadding

/** 底部进度条整行高度，图标/时间/轨道垂直居中共用。 */
private val BOTTOM_PROGRESS_ROW_HEIGHT = 30.dp

/** 底部进度条左右时间槽位宽度。 */
private val BOTTOM_PROGRESS_TIME_SLOT_WIDTH = 58.dp

/** 播放图标/全屏图标与相邻时间的间距。 */
private val BOTTOM_PROGRESS_INNER_GAP = 8.dp

/** 时间数字与进度条之间的间距。 */
private val BOTTOM_PROGRESS_TIME_TRACK_GAP = 10.dp

/** 弹幕覆盖层顶部安全间距。 */
private val DANMAKU_OVERLAY_TOP_PADDING = 72.dp

/** 弹幕覆盖层多行间距。 */
private val DANMAKU_OVERLAY_ROW_SPACING = 34.dp

/** 单批弹幕最多展示行数。 */
private const val DANMAKU_OVERLAY_MAX_VISIBLE_COMMENTS = 4

/** 单批弹幕在画面上的保留时间。 */
private const val DANMAKU_OVERLAY_VISIBLE_MS = 4_200L

/** 底部进度条轨道高度。 */
private val BOTTOM_PROGRESS_TRACK_HEIGHT = 5.dp

/** 底部进度条当前时间圆点尺寸。 */
private val BOTTOM_PROGRESS_KNOB_SIZE = 14.dp

/** 底部进度条当前时间圆点半径。 */
private val BOTTOM_PROGRESS_KNOB_RADIUS = 7.dp

/** 底部缓存段最多展示到当前位置之后 3 分钟。 */
private const val BOTTOM_PROGRESS_CACHE_FORWARD_LIMIT_MS = 180_000L
