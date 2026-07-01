package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 播放器壳层遥控器控制契约。
 */
class TvPlayerRouteControlContractTest {
    /**
     * 菜单未弹出时确认键必须切换播放暂停，不直接打开底部菜单。
     */
    @Test
    fun route_confirm_key_toggles_play_pause_when_menu_hidden() {
        val source = readRouteSource()

        assertThat(source).contains("Key.DirectionCenter")
        assertThat(source).contains("Key.Enter")
        assertThat(source).contains("state.isMenuVisible")
        assertThat(source).contains("viewModel.togglePlayPause()")
    }

    /**
     * 菜单未弹出时左右键必须执行进度跳转。
     */
    @Test
    fun route_left_right_keys_seek_when_menu_hidden() {
        val source = readRouteSource()

        assertThat(source).contains("Key.DirectionLeft")
        assertThat(source).contains("Key.DirectionRight")
        assertThat(source).contains("viewModel.seekByDirection")
    }

    /**
     * 左右键长按 repeat 必须把 Android 原生按住时长传给 seek 规则，不能永远当短按处理。
     */
    @Test
    fun route_repeat_left_right_keys_pass_native_hold_duration_to_seek() {
        val source = readRouteSource()

        assertThat(source).contains("nativeEvent = nativeKeyEvent")
        assertThat(source).contains("repeatCount")
        assertThat(source).contains("nativeEvent.eventTime - nativeEvent.downTime")
        assertThat(source).contains("holdMs = event.resolveSeekHoldMs()")
    }

    /**
     * 左右键长按必须由播放器壳按 100ms 节拍连续 seek，不能依赖设备 repeat 频率。
     */
    @Test
    fun route_long_press_seek_uses_internal_100ms_tick_loop() {
        val source = readRouteSource()

        assertThat(source).contains("rememberContinuousSeekState")
        assertThat(source).contains("delay(CONTINUOUS_SEEK_START_DELAY_MS)")
        assertThat(source).contains("delay(CONTINUOUS_SEEK_TICK_MS)")
        assertThat(source).contains("holdMs += CONTINUOUS_SEEK_TICK_MS")
    }

    /**
     * Android repeat 事件只能维持长按态，不能绕过内部 tick 再额外触发 seek。
     */
    @Test
    fun route_consumes_native_repeat_without_duplicate_seek() {
        val source = readRouteSource()

        assertThat(source).contains("if (event.isSeekRepeatEvent())")
        assertThat(source).contains("return@onPreviewKeyEvent true")
    }

    /**
     * 左右键松手必须停止连续 seek，避免松手后还继续跳进度。
     */
    @Test
    fun route_stops_continuous_seek_on_left_right_key_up() {
        val source = readRouteSource()

        assertThat(source).contains("KeyEventType.KeyUp")
        assertThat(source).contains("continuousSeekState.stop()")
    }

    /**
     * 左右键 seek 后必须显示中心进度提示，并在短暂停留后自动隐藏。
     */
    @Test
    fun route_renders_and_auto_hides_seek_overlay() {
        val source = readRouteSource()

        assertThat(source).contains("if (state.isSeekOverlayVisible)")
        assertThat(source).contains("TvPlayerSeekOverlay")
        assertThat(source).contains("delay(1_200)")
        assertThat(source).contains("viewModel.hideSeekOverlay()")
        assertThat(source).contains("testTag(\"tv-player-seek-overlay\")")
    }

    /**
     * 菜单未弹出时下键必须呼出底部菜单。
     */
    @Test
    fun route_down_key_opens_bottom_menu_when_menu_hidden() {
        val source = readRouteSource()

        assertThat(source).contains("Key.DirectionDown")
        assertThat(source).contains("viewModel.openMenu(PLAYER_MENU_PLAYLIST)")
    }

    /**
     * 返回键和 ESC 必须复刻 Flutter TV：菜单打开时关闭菜单，菜单隐藏时退出播放器。
     */
    @Test
    fun route_back_and_escape_close_menu_before_exit() {
        val source = readRouteSource()

        assertThat(source).contains("onExitRequested: () -> Unit = {}")
        assertThat(source).contains("Key.Back")
        assertThat(source).contains("Key.Escape")
        assertThat(source).contains("viewModel.closeMenu()")
        assertThat(source).contains("onExitRequested()")
    }

    /**
     * 底部菜单必须按状态显隐，不能常驻遮住播放器画面。
     */
    @Test
    fun route_bottom_menu_renders_only_when_menu_visible() {
        val source = readRouteSource()

        assertThat(source).contains("if (state.isMenuVisible) {")
        assertThat(source).contains("LaunchedEffect(state.isMenuVisible, menuInteractionKey)")
    }

    /**
     * 菜单和 loading 都未显示时，全屏底部必须常驻播放进度条。
     */
    @Test
    fun route_renders_bottom_progress_when_menu_and_loading_hidden() {
        val source = readRouteSource()

        assertThat(source).contains("!state.isMenuVisible && !state.isPlayerLoading")
        assertThat(source).contains("TvPlayerBottomProgressBar")
        assertThat(source).contains("testTag(\"tv-player-bottom-progress\")")
    }

    /**
     * 播放器页必须持续观察内核状态，WebView 真实进度上报后底部进度条才能跟随刷新。
     */
    @Test
    fun route_observes_player_engine_state_after_entering_player() {
        val source = readRouteSource()

        assertThat(source).contains("LaunchedEffect(viewModel) {")
        assertThat(source).contains("viewModel.observePlayerState()")
    }

    /**
     * 播放器进入页面后必须同步加载当前剧集弹幕。
     */
    @Test
    fun route_loads_danmaku_after_entering_player() {
        val source = readRouteSource()

        assertThat(source).contains("LaunchedEffect(viewModel, playbackRequest)")
        assertThat(source).contains("viewModel.loadDanmakuForCurrentRequest()")
    }

    /**
     * 播放器进入页面后必须读取片头片尾跳过配置，保证其它菜单展示持久化值。
     */
    @Test
    fun route_loads_skip_durations_after_entering_player() {
        val source = readRouteSource()

        assertThat(source).contains("LaunchedEffect(viewModel, playbackRequest)")
        assertThat(source).contains("viewModel.loadSkipDurations()")
    }

    /**
     * 弹幕加载完成后播放器画面层必须渲染弹幕覆盖层，不能只停留在 ViewModel 状态。
     */
    @Test
    fun route_renders_danmaku_overlay_from_emission_state() {
        val source = readRouteSource()

        assertThat(source).contains("if (state.shouldShowDanmakuOverlay())")
        assertThat(source).contains("TvPlayerDanmakuOverlay(")
        assertThat(source).contains("emissionVersion = state.danmakuEmissionVersion")
        assertThat(source).contains("comments = state.danmakuEmissionComments")
    }

    /**
     * 底部进度条必须保留稳定时间槽位，避免时间文本变化导致轨道左右跳动。
     */
    @Test
    fun route_bottom_progress_uses_stable_time_slots() {
        val source = readRouteSource()

        assertThat(source).contains("BOTTOM_PROGRESS_TIME_SLOT_WIDTH")
        assertThat(source).contains("testTag(\"tv-player-bottom-current-time-slot\")")
        assertThat(source).contains("testTag(\"tv-player-bottom-total-time-slot\")")
    }

    /**
     * 底部进度条必须绘制 Flutter TV 的缓存段，且缓存显示最多延伸到当前位置后 3 分钟。
     */
    @Test
    fun route_bottom_progress_renders_cached_segments_between_background_and_played_track() {
        val source = readRouteSource()
        val progressBarSource = source.substringAfter("private fun TvPlayerBottomProgressBar(")
            .substringBefore("/**\n * TV 全屏播放器控制菜单按钮。")

        assertThat(source).contains("resolvePlayerCachedProgressSegments")
        assertThat(source).contains("BOTTOM_PROGRESS_CACHE_FORWARD_LIMIT_MS")
        assertThat(progressBarSource).contains("cachedProgressSegments: List<TvPlayerCachedProgressSegment>")
        assertThat(progressBarSource).contains("Color.White.copy(alpha = 0.24f)")
        assertThat(progressBarSource.indexOf("Color.White.copy(alpha = 0.54f)"))
            .isLessThan(progressBarSource.indexOf("Color.White.copy(alpha = 0.24f)"))
        assertThat(progressBarSource.indexOf("Color.White.copy(alpha = 0.24f)"))
            .isLessThan(progressBarSource.indexOf("TvTokens.Accent"))
    }

    /**
     * 底部进度条圆点必须按 Flutter TV 公式居中贴合已播放宽度，避免 seek 时轨道左右抖动。
     */
    @Test
    fun route_bottom_progress_knob_uses_flutter_centered_offset_formula() {
        val source = readRouteSource()
        val progressBarSource = source.substringAfter("private fun TvPlayerBottomProgressBar(")
            .substringBefore("/**\n * TV 全屏播放器控制菜单按钮。")

        assertThat(progressBarSource).contains("val playedWidth = maxWidth * progressFraction")
        assertThat(progressBarSource).contains("playedWidth - BOTTOM_PROGRESS_KNOB_RADIUS")
        assertThat(progressBarSource).contains("maxWidth - BOTTOM_PROGRESS_KNOB_SIZE")
        assertThat(progressBarSource).contains(".coerceIn(")
        assertThat(source).contains("BOTTOM_PROGRESS_KNOB_RADIUS")
    }

    /**
     * seek 期间底部进度必须使用真实 seek 目标，而不是中心提示的装饰性展示时间。
     */
    @Test
    fun route_bottom_progress_uses_real_seek_target_not_display_position() {
        val source = readRouteSource()

        assertThat(source).contains("state.seekOverlayPositionMs")
        assertThat(source).doesNotContain("progressPositionMs = state.seekOverlayDisplayPositionMs")
    }

    /**
     * 全屏 loading 必须使用独立无背景转圈和网速文案，不能只在画布中展示普通文字。
     */
    @Test
    fun route_renders_fullscreen_loading_overlay_with_speed_text() {
        val source = readRouteSource()

        assertThat(source).contains("if (state.isPlayerLoading)")
        assertThat(source).contains("TvPlayerLoadingOverlay")
        assertThat(source).contains("CircularProgressIndicator")
        assertThat(source).contains("testTag(\"tv-player-fullscreen-loading\")")
        assertThat(source).contains("networkSpeedText = formatNetworkSpeed(state.networkSpeedBytesPerSecond)")
        assertThat(source).contains("private fun formatNetworkSpeed(bytesPerSecond: Long): String")
        assertThat(source).contains("return \"0KB/s\"")
    }

    /**
     * 全屏播放器顶部装饰层必须对齐 Flutter TV：菜单打开或非加载播放壳层时展示。
     */
    @Test
    fun route_renders_top_decorations_when_menu_visible_or_playback_chrome_visible() {
        val source = readRouteSource()

        assertThat(source).contains("val shouldShowTopDecorations =")
        assertThat(source).contains("state.isMenuVisible || !state.isPlayerLoading")
        assertThat(source).contains("TvPlayerTopDecorations")
        assertThat(source).contains("testTag(\"tv-player-top-decorations\")")
    }

    /**
     * 顶部装饰层必须展示返回图标、当前播放身份、操作提示、装饰图标和 HH:mm 时钟。
     */
    @Test
    fun route_top_decorations_include_title_hint_icon_and_clock() {
        val source = readRouteSource()

        assertThat(source).contains("formatPlayerClock")
        assertThat(source).contains("DateTimeFormatter.ofPattern(\"HH:mm\")")
        assertThat(source).contains("delay(TOP_DECORATION_CLOCK_REFRESH_MS)")
        assertThat(source).contains("showHintText = !state.isSeekOverlayVisible")
        assertThat(source).contains("\"‹\"")
        assertThat(source).contains("\"按返回键返回上一页 | 下键打开播放设置\"")
        assertThat(source).contains("\"☷\"")
    }

    /**
     * 暂停态必须展示中心播放提示，但提示不参与焦点和点击。
     */
    @Test
    fun route_renders_visual_center_play_hint_only_when_paused() {
        val source = readRouteSource()
        val centerPlaySource = source.substringAfter("private fun TvPlayerCenterPlayButton(")
            .substringBefore("/**\n * TV 全屏播放器中心 seek 提示。")

        assertThat(source).contains("val shouldShowCenterPlayButton =")
        assertThat(source).contains("!state.isMenuVisible && !state.isPlayerLoading && !state.isPlaybackPlaying")
        assertThat(source).contains("TvPlayerCenterPlayButton")
        assertThat(source).contains("testTag(\"tv-player-center-play\")")
        assertThat(centerPlaySource).doesNotContain(".clickable(")
        assertThat(centerPlaySource).doesNotContain(".focusable(")
    }

    /**
     * 菜单未弹出且非 loading 时必须展示底部遥控器安全提醒。
     */
    @Test
    fun route_renders_bottom_hint_when_menu_hidden_and_not_loading() {
        val source = readRouteSource()
        val bottomHintSource = source.substringAfter("private fun TvPlayerBottomHint(")
            .substringBefore("/**\n * TV 全屏播放器底部播放进度条。")

        assertThat(source).contains("TvPlayerBottomHint")
        assertThat(source).contains("testTag(\"tv-player-bottom-hint\")")
        assertThat(source).contains("!state.isMenuVisible && !state.isPlayerLoading")
        assertThat(source).contains("返回键退出")
        assertThat(source).contains("下键播放设置")
        assertThat(source).contains("保持安全观看距离")
        assertThat(bottomHintSource).doesNotContain(".clickable(")
        assertThat(bottomHintSource).doesNotContain(".focusable(")
    }

    /**
     * 暂停或 seek 壳层必须渲染上下渐变遮罩，保证顶部和底部信息可读。
     */
    @Test
    fun route_renders_playback_chrome_scrim_when_menu_hidden_and_not_loading() {
        val source = readRouteSource()

        assertThat(source).contains("val shouldShowPlaybackChrome = !state.isMenuVisible && !state.isPlayerLoading")
        assertThat(source).contains("TvPlayerPlaybackChromeScrim")
        assertThat(source).contains("testTag(\"tv-player-playback-chrome-scrim\")")
        assertThat(source).contains("Brush.verticalGradient")
        assertThat(source).contains("0.34f")
        assertThat(source).contains("0.28f")
        assertThat(source).contains("0.18f")
        assertThat(source).contains("0.72f")
    }

    /**
     * 底部一级菜单必须对齐 Flutter TV 的 5 个入口，不能只展示播放列表和其它。
     */
    @Test
    fun route_bottom_primary_menu_renders_flutter_tab_set() {
        val source = readRouteSource()
        val viewModelSource = readViewModelSource()

        assertThat(source).contains("PLAYER_PRIMARY_MENU_ITEMS.forEach")
        assertThat(source).contains("onClick = { viewModel.openMenu(menu) }")
        assertThat(viewModelSource).contains("PLAYER_MENU_PLAYLIST")
        assertThat(viewModelSource).contains("PLAYER_MENU_SOURCES")
        assertThat(viewModelSource).contains("PLAYER_MENU_ASPECT_RATIO")
        assertThat(viewModelSource).contains("PLAYER_MENU_SPEED")
        assertThat(viewModelSource).contains("PLAYER_MENU_OTHER")
        assertThat(viewModelSource).contains("PLAYER_PRIMARY_MENU_ITEMS")
    }

    /**
     * 一级菜单必须在焦点移入时切换二级菜单，复刻 Flutter TV 的 onFocus 行为。
     */
    @Test
    fun route_bottom_primary_menu_switches_secondary_menu_on_focus() {
        val source = readRouteSource()
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")
            .substringBefore("/** 连续 seek 进入长按态前的短按保护时间。")

        assertThat(source).contains("onFocused = { viewModel.openMenu(menu) }")
        assertThat(menuChipSource).contains("onFocused: (() -> Unit)? = null")
        assertThat(source).contains("import androidx.compose.ui.focus.onFocusChanged")
        assertThat(menuChipSource).contains(".onFocusChanged { focusState ->")
        assertThat(menuChipSource).contains("if (focusState.isFocused)")
        assertThat(menuChipSource).contains("onFocused?.invoke()")
    }

    /**
     * 一级菜单上键必须进入当前二级菜单，二级菜单下键必须回到当前一级菜单。
     */
    @Test
    fun route_bottom_menu_moves_focus_between_primary_and_secondary_rows() {
        val source = readRouteSource()
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")
            .substringBefore("/** 连续 seek 进入长按态前的短按保护时间。")

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        assertThat(source).contains("import androidx.compose.ui.focus.focusRequester")
        assertThat(source).contains("rememberPlayerMenuFocusRequesters")
        assertThat(source).contains("primaryMenuFocusRequesters[index]")
        assertThat(source).contains("secondaryMenuFocusRequesters")
        assertThat(source).contains("requestSelectedSecondaryMenuFocus")
        assertThat(source).contains("requestSelectedPrimaryMenuFocus")
        assertThat(menuChipSource).contains("onArrowUp: (() -> Unit)? = null")
        assertThat(menuChipSource).contains("onArrowDown: (() -> Unit)? = null")
        assertThat(menuChipSource).contains("Key.DirectionUp ->")
        assertThat(menuChipSource).contains("Key.DirectionDown ->")
    }

    /**
     * 一级和普通二级菜单获焦必须使用影视卡片同款 1.08 放大反馈。
     */
    @Test
    fun route_menu_chip_scales_like_flutter_tv_video_card_when_focused() {
        val source = readRouteSource()
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")
            .substringBefore("/** 连续 seek 进入长按态前的短按保护时间。")

        assertThat(source).contains("import androidx.compose.animation.core.animateFloatAsState")
        assertThat(source).contains("import androidx.compose.animation.core.tween")
        assertThat(source).contains("import androidx.compose.ui.draw.scale")
        assertThat(source).contains("private const val PLAYER_MENU_FOCUSED_SCALE = 1.08f")
        assertThat(source).contains("private const val PLAYER_MENU_FOCUS_ANIMATION_MS = 140")
        assertThat(menuChipSource).contains("val scale by animateFloatAsState(")
        assertThat(menuChipSource).contains("targetValue = if (isFocused) PLAYER_MENU_FOCUSED_SCALE else 1f")
        assertThat(menuChipSource).contains("animationSpec = tween(durationMillis = PLAYER_MENU_FOCUS_ANIMATION_MS)")
        assertThat(menuChipSource).contains(".scale(scale)")
    }

    /**
     * 播放器画面层必须通过稳定插槽注入，避免菜单和遮罩状态重建底层平台视图。
     */
    @Test
    fun route_player_surface_is_injected_below_overlay_chrome() {
        val source = readRouteSource()
        val routeSource = source.substringAfter("fun TvPlayerRoute(")
            .substringBefore("/**\n * TV 全屏播放器播放列表二级菜单。")

        assertThat(source).contains("import androidx.compose.foundation.layout.BoxScope")
        assertThat(routeSource).contains("playerSurface: @Composable BoxScope.(TvPlayerUiState) -> Unit")
        assertThat(routeSource).contains("TvPlayerDefaultSurface(surfaceState = surfaceState)")
        assertThat(routeSource).contains("playerSurface(state)")
        assertThat(routeSource.indexOf("playerSurface(state)"))
            .isLessThan(routeSource.indexOf("TvPlayerPlaybackChromeScrim()"))
    }

    /**
     * 默认播放列表一级菜单也必须提供二级焦点落点，避免菜单刚打开时上键无目标。
     */
    @Test
    fun route_playlist_menu_renders_current_episode_secondary_focus_target() {
        val source = readRouteSource()

        assertThat(source).contains("TvPlayerPlaylistMenu")
        assertThat(source).contains("playbackRequest = state.playbackRequest")
        assertThat(source).contains("resolvePlaylistMenuLabel")
        assertThat(source).contains("PLAYER_MENU_PLAYLIST ->")
    }

    /**
     * 画面比例二级菜单文案必须与 Flutter TV 和手机端播放器设置一致。
     */
    @Test
    fun route_aspect_ratio_menu_renders_flutter_fit_options() {
        val source = readRouteSource()
        val viewModelSource = readViewModelSource()
        val aspectMenuSource = source.substringAfter("private fun TvPlayerAspectRatioMenu(")
            .substringBefore("/**\n * TV 全屏播放器倍速二级菜单。")

        assertThat(source).contains("TvPlayerAspectRatioMenu")
        assertThat(aspectMenuSource).contains("PLAYER_ASPECT_RATIO_OPTIONS")
        assertThat(aspectMenuSource).contains("selectedResizeMode: TvResizeMode")
        assertThat(aspectMenuSource).contains("onResizeModeSelected: (TvResizeMode) -> Unit")
        assertThat(aspectMenuSource).contains("onClick = { onResizeModeSelected(resizeMode) }")
        assertThat(source).contains("viewModel.selectResizeMode(resizeMode)")
        assertThat(viewModelSource).contains("\"适应\"")
        assertThat(viewModelSource).contains("\"填充\"")
        assertThat(viewModelSource).contains("\"宽度\"")
        assertThat(viewModelSource).contains("\"高度\"")
    }

    /**
     * 倍速二级菜单必须提供 Flutter TV 的常用 5 档。
     */
    @Test
    fun route_speed_menu_renders_flutter_speed_options() {
        val source = readRouteSource()
        val viewModelSource = readViewModelSource()
        val speedMenuSource = source.substringAfter("private fun TvPlayerSpeedMenu(")
            .substringBefore("/**\n * TV 全屏播放器其它二级菜单。")

        assertThat(source).contains("TvPlayerSpeedMenu")
        assertThat(speedMenuSource).contains("PLAYER_SPEED_OPTIONS")
        assertThat(speedMenuSource).contains("selectedPlaybackSpeed: Float")
        assertThat(speedMenuSource).contains("onPlaybackSpeedSelected: (Float) -> Unit")
        assertThat(speedMenuSource).contains("onClick = { onPlaybackSpeedSelected(playbackSpeed) }")
        assertThat(source).contains("viewModel.selectPlaybackSpeed(speed)")
        assertThat(viewModelSource).contains("\"0.75x\"")
        assertThat(viewModelSource).contains("\"1.0x\"")
        assertThat(viewModelSource).contains("\"1.25x\"")
        assertThat(viewModelSource).contains("\"1.5x\"")
        assertThat(viewModelSource).contains("\"2.0x\"")
    }

    /**
     * 其它二级菜单必须对齐 Flutter TV，只展示片头、片尾、弹幕和手动匹配。
     */
    @Test
    fun route_other_menu_hides_disabled_quality_and_kernel_entries() {
        val source = readRouteSource()
        val viewModelSource = readViewModelSource()
        val otherMenuSource = source.substringAfter("private fun TvPlayerOtherMenu(")
            .substringBefore("/**\n * TV 全屏播放器暂停和 seek 壳层可读性遮罩。")

        assertThat(source).contains("TvPlayerOtherMenu")
        assertThat(otherMenuSource).contains("PLAYER_OTHER_MENU_ITEMS")
        assertThat(otherMenuSource).contains("确认/空格/Enter 设置当前时间，长按清空")
        assertThat(otherMenuSource).doesNotContain("state.selectedOtherMenuItem")
        assertThat(otherMenuSource).doesNotContain("PLAYER_OTHER_ENGINE_SWITCH")
        assertThat(otherMenuSource).doesNotContain("清晰度")
        assertThat(viewModelSource).contains("PLAYER_OTHER_INTRO")
        assertThat(viewModelSource).contains("PLAYER_OTHER_OUTRO")
        assertThat(viewModelSource).contains("PLAYER_OTHER_DANMAKU")
        assertThat(viewModelSource).contains("PLAYER_OTHER_MANUAL_MATCH")
        assertThat(viewModelSource).doesNotContain("PLAYER_OTHER_ENGINE_SWITCH")
        assertThat(viewModelSource).doesNotContain("PLAYER_OTHER_QUALITY")
    }

    /**
     * 片头片尾菜单必须展示当前跳过秒数，并支持短按设置、长按清空。
     */
    @Test
    fun route_other_menu_controls_intro_and_outro_skip_positions() {
        val source = readRouteSource()
        val otherMenuCallSource = source.substringAfter("TvPlayerOtherMenu(")
            .substringBefore(")\n                    }")
        val otherMenuSource = source.substringAfter("private fun TvPlayerOtherMenu(")
            .substringBefore("/**\n * 解析弹幕手动匹配默认搜索词。")
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")

        assertThat(otherMenuCallSource).contains("skipIntroSeconds = state.skipIntroSeconds")
        assertThat(otherMenuCallSource).contains("skipOutroSeconds = state.skipOutroSeconds")
        assertThat(otherMenuCallSource).contains("scope.launch { viewModel.setSkipIntroToCurrentPosition() }")
        assertThat(otherMenuCallSource).contains("scope.launch { viewModel.setSkipOutroToCurrentPosition() }")
        assertThat(otherMenuCallSource).contains("scope.launch { viewModel.clearSkipIntroPosition() }")
        assertThat(otherMenuCallSource).contains("scope.launch { viewModel.clearSkipOutroPosition() }")
        assertThat(otherMenuSource).contains(
            "PLAYER_OTHER_INTRO -> \"片头 ${'$'}{formatPlayerDuration(skipIntroSeconds * 1_000L)}\"",
        )
        assertThat(otherMenuSource).contains(
            "PLAYER_OTHER_OUTRO -> \"片尾 ${'$'}{formatPlayerDuration(skipOutroSeconds * 1_000L)}\"",
        )
        assertThat(otherMenuSource).contains("onLongClick =")
        assertThat(menuChipSource).contains("onLongClick: (() -> Unit)? = null")
    }

    /**
     * 手动匹配菜单必须把当前片名交给宿主，弹幕搜索面板才能复用 Flutter TV 默认搜索词。
     */
    @Test
    fun route_other_menu_exposes_manual_danmaku_match_callback_with_title_query() {
        val source = readRouteSource()
        val otherMenuCallSource = source.substringAfter("TvPlayerOtherMenu(")
            .substringBefore(")\n                    }")
        val otherMenuSource = source.substringAfter("private fun TvPlayerOtherMenu(")
            .substringBefore("/**\n * TV 全屏播放器暂停和 seek 壳层可读性遮罩。")

        assertThat(source).contains("onDanmakuMatchRequested: (String) -> Unit = {}")
        assertThat(otherMenuCallSource).contains("onDanmakuMatchRequested = {")
        assertThat(otherMenuCallSource).contains("resolveDanmakuMatchQuery(state.playbackRequest)")
        assertThat(otherMenuSource).contains("onDanmakuMatchRequested: () -> Unit")
        assertThat(otherMenuSource).contains("PLAYER_OTHER_MANUAL_MATCH -> onDanmakuMatchRequested()")
        assertThat(otherMenuSource).contains("onDanmakuMatchRequested()")
    }

    /**
     * 弹幕菜单必须使用真实开关状态并把确认键交给 ViewModel，不能继续硬编码为开启。
     */
    @Test
    fun route_other_menu_toggles_danmaku_enabled_from_view_model_state() {
        val source = readRouteSource()
        val otherMenuCallSource = source.substringAfter("TvPlayerOtherMenu(")
            .substringBefore(")\n                    }")
        val otherMenuSource = source.substringAfter("private fun TvPlayerOtherMenu(")
            .substringBefore("/**\n * 解析弹幕手动匹配默认搜索词。")

        assertThat(otherMenuCallSource).contains("danmakuEnabled = state.isDanmakuEnabled")
        assertThat(otherMenuCallSource).contains("scope.launch { viewModel.toggleDanmakuEnabled() }")
        assertThat(otherMenuSource).contains("onDanmakuToggle: () -> Unit")
        assertThat(otherMenuSource).contains("item == PLAYER_OTHER_DANMAKU")
        assertThat(otherMenuSource).contains("onDanmakuToggle()")
        assertThat(otherMenuCallSource).doesNotContain("danmakuEnabled = true")
    }

    /**
     * 弹幕关闭时覆盖层必须一起隐藏，避免菜单显示关但画面仍继续飘弹幕。
     */
    @Test
    fun route_danmaku_overlay_requires_enabled_state() {
        val source = readRouteSource()
        val overlayGateSource = source.substringAfter("private fun TvPlayerUiState.shouldShowDanmakuOverlay()")
            .substringBefore("/**\n * 将弹幕颜色转换为 Compose 文本颜色。")

        assertThat(overlayGateSource).contains("isDanmakuEnabled")
        assertThat(overlayGateSource).contains("currentDanmakuEpisodeId != null")
        assertThat(overlayGateSource).contains("!isDanmakuLoading")
    }

    /**
     * 读取播放器路由源码。
     *
     * @return 当前播放器路由源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerRoute.kt")
            .readText()
    }

    /**
     * 读取播放器状态源码。
     *
     * @return 当前播放器 ViewModel 源码文本。
     */
    private fun readViewModelSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/player/TvPlayerViewModel.kt")
            .readText()
    }
}
