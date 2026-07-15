package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test
import org.moontechlab.selene.tv.core.player.api.PlaybackSource

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
     * 全屏播放器必须主动持有根焦点，并在菜单关闭后抢回焦点。
     */
    @Test
    fun route_requests_root_focus_for_fullscreen_keyboard_controls() {
        val source = readRouteSource()

        assertThat(source).contains("val playerRootFocusRequester = remember { FocusRequester() }")
        assertThat(source).contains("LaunchedEffect(state.isMenuVisible) {")
        assertThat(source).contains("playerRootFocusRequester.requestFocus()")
        assertThat(source).contains("requestSelectedSecondaryMenuFocus()")
        assertThat(source).contains(".focusRequester(playerRootFocusRequester)")
        assertThat(source).contains(".focusable()")
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
     * 方向键 KeyUp 分支必须先停止连续 seek，再消费本次松手事件。
     * 菜单打开时不得吞 KeyUp，否则一级/二级/三级横向移动全部失灵。
     */
    @Test
    fun route_direction_key_up_branch_stops_continuous_seek_before_consuming_event() {
        val source = readRouteSource()
        val keyUpCondition =
            "if (event.type == KeyEventType.KeyUp && event.key.isSeekDirectionKey()) {"
        val keyUpBranchStart = source.indexOf(keyUpCondition)

        assertThat(keyUpBranchStart).isAtLeast(0)
        // 菜单打开时优先放行，禁止根节点抢菜单左右 KeyUp。
        assertThat(source).contains("根节点不消费（return false），避免挡掉一级/二级/三级横向焦点。")
        assertThat(source.indexOf("if (state.isMenuVisible)")).isLessThan(keyUpBranchStart)

        // 只截取方向键 KeyUp 分支，避免其它生命周期 stop 调用造成契约误判。
        val keyUpBranchEnd = source.indexOf(
            string = "return@onPreviewKeyEvent true",
            startIndex = keyUpBranchStart,
        )
        assertThat(keyUpBranchEnd).isGreaterThan(keyUpBranchStart)
        assertThat(source.substring(keyUpBranchStart, keyUpBranchEnd))
            .contains("continuousSeekState.stop()")
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
     * 系统返回键和键盘 ESC 必须复刻 Flutter TV，且不能由两套处理器重复消费。
     */
    @Test
    fun route_back_and_escape_close_menu_before_exit() {
        val source = readRouteSource()

        assertThat(source).contains("onExitRequested: () -> Unit = {}")
        assertThat(source).contains("BackHandler {")
        assertThat(source).contains("Key.Escape")
        assertThat(source).contains("viewModel.closeMenu()")
        assertThat(source).contains("onExitRequested()")
        assertThat(source).doesNotContain("Key.Back,")
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
     * 底部按钮组有操作后必须后延关闭，并保留底部渐变背景。
     * 上下左右/确认 KeyDown 必须续约自动关闭（根节点 + chip 双路径）。
     */
    @Test
    fun route_menu_interaction_resets_auto_hide_and_keeps_bottom_gradient() {
        val source = readRouteSource()

        // 交互计数器驱动重新计时。
        assertThat(source).contains("menuInteractionKey++")
        assertThat(source).contains("bumpMenuInteraction()")
        assertThat(source).contains("PLAYER_MENU_AUTO_HIDE_MS")
        // 方向/确认续约：根节点菜单态 + chip 内 KeyDown。
        assertThat(source).contains("isPlayerMenuRenewKey()")
        assertThat(source).contains("LocalPlayerMenuInteractionBumps")
        assertThat(source).contains("renewMenuAutoHide()")
        // 底部背景渐变必须保留。
        assertThat(source).contains("Brush.verticalGradient(")
        assertThat(source).contains("底部背景渐变")
    }

    /**
     * 菜单和 loading 都未显示时，全屏底部必须常驻播放进度条。
     */
    @Test
    fun route_renders_bottom_progress_when_menu_and_loading_hidden() {
        val source = readRouteSource()

        assertThat(source).contains("!state.isMenuVisible && !showLoadingOverlay")
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
        assertThat(progressBarSource).contains("Color.White.copy(alpha = 0.42f)")
        assertThat(progressBarSource.indexOf("Color.White.copy(alpha = 0.28f)"))
            .isLessThan(progressBarSource.indexOf("Color.White.copy(alpha = 0.42f)"))
        assertThat(progressBarSource.indexOf("Color.White.copy(alpha = 0.42f)"))
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

        // 转圈仅在松手后/首启加载展示：按住 seek 时 shouldShowLoadingOverlay=false。
        assertThat(source).contains("shouldShowLoadingOverlay()")
        assertThat(source).contains("if (showLoadingOverlay)")
        assertThat(source).contains("onSeekGestureStarted()")
        assertThat(source).contains("onSeekGestureReleased()")
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
        assertThat(source).contains("state.isMenuVisible || isChromeVisible")
        assertThat(source).contains("PLAYER_MENU_AUTO_HIDE_MS")
        assertThat(source).contains("isChromeVisible = false")
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
        assertThat(source).contains("!state.isMenuVisible && !showLoadingOverlay && !state.isPlaybackPlaying")
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
        assertThat(source).contains("!state.isMenuVisible && !showLoadingOverlay")
        assertThat(source).contains("返回键退出")
        assertThat(source).contains("下键播放设置")
        assertThat(source).contains("保持安全观看距离")
        // 有下一集时底部提示必须告知「本集结束后自动下一集」。
        assertThat(source).contains("本集结束后自动下一集")
        assertThat(source).contains("hasNextEpisode = state.hasNextEpisode()")
        // 自动下一集：右下角轻提示 + 加载层短文案。
        assertThat(source).contains("tv-player-auto-next-notice")
        assertThat(source).contains("Alignment.BottomEnd")
        assertThat(source).contains("switchLoadingMessage")
        assertThat(source).contains("下一集...")
        assertThat(source).contains("title = state.switchLoadingMessage ?: \"加载中\"")
        assertThat(source).doesNotContain("TvActionNotice")
        assertThat(bottomHintSource).doesNotContain(".clickable(")
        assertThat(bottomHintSource).doesNotContain(".focusable(")
    }

    /**
     * 暂停或 seek 壳层必须渲染上下渐变遮罩，保证顶部和底部信息可读。
     */
    @Test
    fun route_renders_playback_chrome_scrim_when_menu_hidden_and_not_loading() {
        val source = readRouteSource()

        assertThat(source).contains("val shouldShowPlaybackChrome =")
        assertThat(source).contains("isChromeVisible")
        assertThat(source).contains("TvPlayerPlaybackChromeScrim")
        assertThat(source).contains("testTag(\"tv-player-playback-chrome-scrim\")")
        assertThat(source).contains("Brush.verticalGradient")
        assertThat(source).contains("0.42f")
        assertThat(source).contains("0.58f")
        assertThat(source).contains("0.16f")
        assertThat(source).contains("0.62f")
        assertThat(source).contains("0.84f")
    }

    /**
     * 底部一级菜单必须对齐 Flutter TV 的 5 个入口，不能只展示播放列表和其它。
     */
    @Test
    fun route_bottom_primary_menu_renders_flutter_tab_set() {
        val source = readRouteSource()
        val viewModelSource = readViewModelSource()

        assertThat(source).contains("PLAYER_PRIMARY_MENU_ITEMS.forEach")
        assertThat(source).contains("viewModel.openMenu(menu)")
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
            .substringBefore("private fun rememberPlayerMenuFocusRequesters")

        assertThat(source).contains("viewModel.openMenu(menu)")
        assertThat(menuChipSource).contains("onFocused: (() -> Unit)? = null")
        assertThat(source).contains("import androidx.compose.ui.focus.onFocusChanged")
        assertThat(menuChipSource).contains(".onFocusChanged { focusState ->")
        assertThat(menuChipSource).contains("if (focusState.isFocused)")
        assertThat(menuChipSource).contains("onFocused?.invoke()")
    }

    /**
     * 一级菜单左右切换只更新二级内容，焦点必须留在一级菜单，用户按上键后才进入二级菜单。
     */
    @Test
    fun route_primary_menu_horizontal_switch_does_not_move_focus_to_secondary_row() {
        val source = readRouteSource()
        val primaryMenuSource = source
            .substringAfter("// 一级菜单：左右切换分类，上键回二级，下键停在一级。")
            .substringBefore("        } else {")
        val primaryMenuClickSource = primaryMenuSource
            .substringAfter("onClick = {")
            .substringBefore("},\n                        )")

        // 自动焦点仅在菜单由关闭变为打开时执行，切换一级分类不能再次触发。
        assertThat(source).contains("LaunchedEffect(state.isMenuVisible) {")
        assertThat(source).doesNotContain(
            "LaunchedEffect(state.isMenuVisible, state.selectedTopMenu, state.allEpisodes, state.availableSources)",
        )
        // 进入二级菜单必须继续只由一级菜单的上键显式触发。
        assertThat(source).contains("onArrowUp = {")
        assertThat(source).contains("requestNearestSecondaryMenuFocus(index)")
        // 播放列表：门票滚焦；播放线路：当前选中线路；其余：空间就近。
        assertThat(source).contains("PLAYER_MENU_PLAYLIST -> requestPlaylistSecondaryFocus()")
        assertThat(source).contains("PLAYER_MENU_SOURCES ->")
        assertThat(source).contains("requestSelectedSecondaryMenuFocus()")
        assertThat(primaryMenuClickSource).doesNotContain("requestSelectedSecondaryMenuFocus()")
        assertThat(primaryMenuClickSource).doesNotContain("requestNearestSecondaryMenuFocus")
        assertThat(primaryMenuClickSource).doesNotContain("requestPlaylistSecondaryFocus")
    }

    /**
     * 一级菜单上键必须进入当前二级菜单，二级菜单下键必须回到当前一级菜单。
     */
    @Test
    fun route_bottom_menu_moves_focus_between_primary_and_secondary_rows() {
        val source = readRouteSource()
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")
            .substringBefore("private fun rememberPlayerMenuFocusRequesters")

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        assertThat(source).contains("import androidx.compose.ui.focus.focusRequester")
        assertThat(source).contains("rememberPlayerMenuFocusRequesters")
        assertThat(source).contains("primaryMenuFocusRequesters[index]")
        assertThat(source).contains("secondaryMenuFocusRequesters")
        assertThat(source).contains("requestSelectedSecondaryMenuFocus")
        assertThat(source).contains("requestNearestSecondaryMenuFocus")
        assertThat(source).contains("requestSelectedPrimaryMenuFocus")
        assertThat(source).contains("TvPlayerMenuFocusGeometry")
        assertThat(source).contains("resolveNearestSecondaryIndex")
        assertThat(source).contains("onGloballyPositioned")
        assertThat(source).contains("boundsInWindow")
        assertThat(menuChipSource).contains("onArrowUp: (() -> Unit)? = null")
        assertThat(menuChipSource).contains("onArrowDown: (() -> Unit)? = null")
        assertThat(menuChipSource).contains("Key.DirectionUp ->")
        assertThat(menuChipSource).contains("Key.DirectionDown ->")
        // 方向键在 KeyDown（含 repeat）步进，长按左右连续跟焦；KeyUp 只消费不二次移动。
        assertThat(menuChipSource).contains("if (event.type == KeyEventType.KeyDown)")
        assertThat(menuChipSource).contains("directionHandler.invoke()")
        assertThat(menuChipSource).contains("长按左右连续跟焦")
        assertThat(menuChipSource).doesNotContain("if (event.type == KeyEventType.KeyUp) {\n                        directionHandler.invoke()")
    }

    /**
     * 播放线路二级菜单必须为每一项挂 FocusRequester，一级上键按屏幕 X 就近落点。
     */
    @Test
    fun route_source_menu_focus_targets_each_source_for_nearest_entry() {
        val source = readRouteSource()
        val sourceMenu = source.substringAfter("private fun TvPlayerSourceMenu(")
            .substringBefore("/**\n * TV 全屏播放器画面比例二级菜单。")

        assertThat(source).contains("PLAYER_MENU_SOURCES -> state.availableSources.size.coerceAtLeast(1)")
        assertThat(sourceMenu).contains("focusRequesters: List<FocusRequester>")
        assertThat(sourceMenu).contains("focusRequesters.getOrNull(i)")
        assertThat(sourceMenu).contains("onItemCenterXChanged")
        assertThat(sourceMenu).doesNotContain("isFirst && focusRequester != null")
        // 播放列表：门票滚焦；播放线路：当前选中线路；其它一级：空间就近。
        assertThat(source).contains("PLAYER_MENU_PLAYLIST -> requestPlaylistSecondaryFocus()")
        assertThat(source).contains("PLAYER_MENU_SOURCES ->")
        assertThat(source).contains("requestNearestSecondaryMenuFocus(index)")
        assertThat(source).contains("menuFocusGeometry.resolveNearestSecondaryIndex")
    }

    /**
     * 一级菜单左右必须在项间移动，首/末边界停止，避免永远到不了最左/最右。
     */
    @Test
    fun route_primary_menu_has_horizontal_edge_navigation() {
        val source = readRouteSource()

        assertThat(source).contains("onArrowLeft = if (index > 0)")
        assertThat(source).contains("onArrowRight = if (index < PLAYER_PRIMARY_MENU_ITEMS.lastIndex)")
        assertThat(source).contains("primaryMenuFocusRequesters.requestFocusAt(index - 1)")
        assertThat(source).contains("primaryMenuFocusRequesters.requestFocusAt(index + 1)")
    }

    /**
     * 二级/三级横向滚动：首/末与 contentPadding 对齐，用 scrollBy 跟手。
     */
    @Test
    fun route_secondary_menu_scroll_handles_first_and_last() {
        val source = readRouteSource()
        val scrollSource = source.substringAfter("private suspend fun scrollPlayerMenuChipIntoViewSuspend(")
            .substringBefore("private fun scrollPlayerMenuChipIntoView(")

        assertThat(scrollSource).contains("animateScrollBy(")
        assertThat(scrollSource).contains("scrollToItem(index = index)")
        assertThat(scrollSource).contains("leftDelta")
        assertThat(scrollSource).contains("rightDelta")
        assertThat(source).contains("PageHorizontalPadding")
    }

    /**
     * 空间就近几何：一级 X 应落到中心最近的二级项。
     */
    @Test
    fun menu_focus_geometry_picks_secondary_with_closest_center_x() {
        val geometry = TvPlayerMenuFocusGeometry()
        geometry.updatePrimaryCenterX(1, 400f)
        geometry.updateSecondaryCenterX(0, 100f)
        geometry.updateSecondaryCenterX(1, 250f)
        geometry.updateSecondaryCenterX(2, 420f)
        geometry.updateSecondaryCenterX(3, 700f)

        assertThat(geometry.resolveNearestSecondaryIndex(primaryIndex = 1, fallbackIndex = 0))
            .isEqualTo(2)
    }

    /**
     * 当前线路高亮必须兼容 request 短键与列表 source::videoId 复合键。
     */
    @Test
    fun current_source_selected_matches_short_key_and_composite_id() {
        val composite = PlaybackSource(id = "bfzy::12345", name = "暴风资源")
        val shortKey = PlaybackSource(id = "bfzy", name = "暴风资源")

        assertThat(
            isCurrentPlaybackSource(
                source = composite,
                currentSourceId = "bfzy",
                currentSourceName = "",
            ),
        ).isTrue()
        assertThat(
            isCurrentPlaybackSource(
                source = shortKey,
                currentSourceId = "bfzy::12345",
                currentSourceName = "",
            ),
        ).isTrue()
        assertThat(
            isCurrentPlaybackSource(
                source = PlaybackSource(id = "other::1", name = "量子影视"),
                currentSourceId = "bfzy",
                currentSourceName = "暴风资源",
            ),
        ).isFalse()
        assertThat(
            isCurrentPlaybackSource(
                source = PlaybackSource(id = "other::1", name = "暴风资源"),
                currentSourceId = "unknown",
                currentSourceName = "暴风资源",
            ),
        ).isTrue()
    }

    /**
     * 二级坐标清空后应回退 fallback，避免用脏数据。
     */
    @Test
    fun menu_focus_geometry_falls_back_when_secondary_empty() {
        val geometry = TvPlayerMenuFocusGeometry()
        geometry.updatePrimaryCenterX(0, 120f)
        geometry.updateSecondaryCenterX(3, 500f)
        geometry.clearSecondary()

        assertThat(geometry.resolveNearestSecondaryIndex(primaryIndex = 0, fallbackIndex = 1))
            .isEqualTo(1)
    }

    /**
     * 一级和普通二级菜单获焦必须使用影视卡片同款 1.08 放大反馈。
     */
    @Test
    fun route_menu_chip_scales_like_flutter_tv_video_card_when_focused() {
        val source = readRouteSource()
        val menuChipSource = source.substringAfter("private fun TvPlayerMenuChip(")
            .substringBefore("private fun rememberPlayerMenuFocusRequesters")

        assertThat(source).contains("import androidx.compose.animation.core.animateFloatAsState")
        assertThat(source).contains("import androidx.compose.animation.core.tween")
        assertThat(source).contains("import androidx.compose.ui.graphics.graphicsLayer")
        assertThat(source).contains("private const val PLAYER_MENU_FOCUSED_SCALE = 1.05f")
        assertThat(source).contains("private const val PLAYER_MENU_FOCUS_ANIMATION_MS = 140")
        assertThat(menuChipSource).contains("val scale by animateFloatAsState(")
        assertThat(menuChipSource).contains("targetValue = if (isFocused) PLAYER_MENU_FOCUSED_SCALE else 1f")
        assertThat(menuChipSource).contains("animationSpec = tween(durationMillis = PLAYER_MENU_FOCUS_ANIMATION_MS)")
        assertThat(menuChipSource).contains("scaleX = scale")
        assertThat(menuChipSource).contains("scaleY = scale")
        assertThat(menuChipSource).contains("transformOrigin = focusScaleOrigin")
    }

    /**
     * 播放线路二级列表必须预留右侧放大 gutter，且末项右锚向左扩展，避免贴边裁切。
     */
    @Test
    fun route_source_menu_reserves_end_gutter_and_edge_scale_origin() {
        val source = readRouteSource()
        val sourceMenu = source.substringAfter("private fun TvPlayerSourceMenu(")
            .substringBefore("private fun TvPlayerAspectRatioMenu(")

        // 列表 viewport 贴右；仅滚到末项时 end padding 留边；获焦滚动避免裁切。
        assertThat(source).contains("private val PLAYER_MENU_LIST_END_PADDING = TvTokens.PageHorizontalPadding")
        assertThat(source).contains("private val PLAYER_MENU_CHIP_SAFE_WIDTH = 160.dp")
        assertThat(sourceMenu).contains("end = PLAYER_MENU_LIST_END_PADDING")
        assertThat(sourceMenu).contains("start = TvTokens.PageHorizontalPadding")
        assertThat(sourceMenu).contains("fillMaxWidth()")
        assertThat(sourceMenu).contains("scrollPlayerMenuChipIntoView(")
        assertThat(sourceMenu).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(sourceMenu).contains("rememberSaveable(saver = LazyListState.Saver)")
        assertThat(sourceMenu).contains("if (shouldScroll)")
        assertThat(sourceMenu).contains("TransformOrigin(1f, 0.5f)")
        assertThat(sourceMenu).contains("TransformOrigin(0f, 0.5f)")
        assertThat(sourceMenu).contains("focusScaleOrigin = when {")
        assertThat(source).contains("top = 20.dp")
        assertThat(source).contains("bottom = 22.dp")
        assertThat(source).contains("start = TvTokens.PageHorizontalPadding")
        assertThat(source).contains("end = TvTokens.PageHorizontalPadding")
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
     *
     * 全剧集 LazyRow 下当前集常在屏外：必须先 scroll 再 requestFocus，
     * 禁止对未挂载 FocusRequester 硬点导致整页焦点丢失。
     */
    @Test
    fun route_playlist_menu_renders_current_episode_secondary_focus_target() {
        val source = readRouteSource()
        val playlistSource = source.substringAfter("private fun TvPlayerPlaylistMenu(")
            .substringBefore("/**\n * TV 全屏播放器播放线路二级菜单。")

        assertThat(source).contains("TvPlayerPlaylistMenu")
        assertThat(source).contains("playbackRequest = state.playbackRequest")
        assertThat(source).contains("resolvePlaylistMenuLabel")
        assertThat(source).contains("PLAYER_MENU_PLAYLIST ->")
        // 打开菜单 / 一级上键走门票，内部滚到当前集再落焦。
        assertThat(source).contains("playlistSecondaryFocusTicket")
        assertThat(source).contains("requestPlaylistSecondaryFocus")
        assertThat(source).contains("secondaryFocusTicket = playlistSecondaryFocusTicket")
        assertThat(playlistSource).contains("secondaryFocusTicket")
        assertThat(playlistSource).contains("LaunchedEffect(secondaryFocusTicket)")
        assertThat(playlistSource).contains("onSecondaryFocusFailed")
        assertThat(source).contains("onSecondaryFocusFailed = requestSelectedPrimaryMenuFocus")
        // 一级播放列表上键必须走门票，不能 requestNearest 硬点屏外 requester。
        assertThat(source).contains("PLAYER_MENU_PLAYLIST -> requestPlaylistSecondaryFocus()")
    }

    /**
     * 全屏播放列表：选集在上、分组在下；分组用无背景样式；下键回一级当前选中项。
     * 集数横滑必须有 LazyListState + 获焦滚动，禁止“焦点在动列表不滚”。
     */
    @Test
    fun route_playlist_menu_puts_groups_below_episodes_with_detail_style() {
        val source = readRouteSource()
        val playlistSource = source.substringAfter("private fun TvPlayerPlaylistMenu(")
            .substringBefore("/**\n * TV 全屏播放器播放线路二级菜单。")

        // 布局：先渲染全剧集连续 LazyRow，再渲染分组条。
        val episodeRow = playlistSource.indexOf("movePlaylistEpisodeFocus")
            .takeIf { index -> index >= 0 }
            ?: playlistSource.indexOf("items(")
        val groupChoice = playlistSource.indexOf("TvPlayerEpisodeGroupChoice(")
        assertThat(episodeRow).isAtLeast(0)
        assertThat(groupChoice).isAtLeast(0)
        assertThat(episodeRow).isLessThan(groupChoice)

        // 分组无背景样式组件存在。
        assertThat(source).contains("private fun TvPlayerEpisodeGroupChoice(")
        assertThat(source).contains("获焦未确认：主题色文字，无下划线")
        assertThat(source).contains("ensureGroupChipVisible")
        assertThat(source).contains("ensureGroupChipVisibleNow")
        assertThat(source).contains("moveGroupFocus")
        assertThat(source).contains("scrollPlayerMenuChipIntoViewSuspend")
        assertThat(playlistSource).contains("获焦只保证芯片可见；不改 selectedGroup")
        assertThat(playlistSource).contains("确认：下划线落到该组")
        // 分组左右：先滚后焦，禁止对屏外 requester 硬点。
        assertThat(playlistSource).contains("moveGroupFocus(gi - 1)")
        assertThat(playlistSource).contains("moveGroupFocus(gi + 1)")
        assertThat(playlistSource).contains("先滚后焦")
        // 确认：回车/中键/空格 + 鼠标 clickable；热区放大。
        val groupChoiceSource = source
            .substringAfter("private fun TvPlayerEpisodeGroupChoice(")
            .substringBefore("/**\n * TV 全屏播放器播放线路二级菜单。")
        assertThat(groupChoiceSource).contains("Key.Spacebar")
        assertThat(groupChoiceSource).contains("KeyEventType.KeyUp")
        assertThat(groupChoiceSource).contains("clickable(")
        // 下划线 3dp 且外层 LazyRow 48dp，避免被裁切。
        assertThat(groupChoiceSource).contains("height(3.dp)")
        assertThat(playlistSource).contains(".height(48.dp)")
        assertThat(groupChoiceSource).contains("if (selected) TvTokens.Accent else Color.Transparent")
        // 连续横轨；左右键 SoftEdgeFollow（焦点随方向走，贴边才滚），打开菜单钉左。
        assertThat(source).contains("movePlaylistEpisodeFocus")
        assertThat(source).contains("requestPlaylistEpisodeFocusWhenReady")
        assertThat(source).contains("PlaylistFocusPinMode.SoftEdgeFollow")
        assertThat(source).contains("PlaylistFocusPinMode.PinLeading")
        assertThat(playlistSource).contains("LocalBringIntoViewSpec")
        // 左右键不得再 KeepSlot 钉死原 X，否则会出现「向右焦点常驻左侧」的反转感。
        assertThat(playlistSource).contains("pinFocusMode = PlaylistFocusPinMode.SoftEdgeFollow")
        // 首/末集贴边与一级菜单水平边距对齐。
        assertThat(source).contains("PageHorizontalPadding")
        assertThat(playlistSource).doesNotContain("pendingInGroupFocusIndex")
        assertThat(playlistSource).doesNotContain("isSettlingCrossGroupFocus")
        assertThat(playlistSource).doesNotContain("keepVisualSlot = true")

        // 二级/三级下键回一级当前选中项；下键进分组需能 requestFocus。
        assertThat(source).contains("onArrowDownToPrimary = requestSelectedPrimaryMenuFocus")
        assertThat(playlistSource).contains("onArrowDownToPrimary")
        assertThat(playlistSource).contains("requestCurrentGroupFocus")
        assertThat(playlistSource).contains("requestCurrentEpisodeFocus")
        assertThat(playlistSource).contains("groupListState.scrollToItem")
        assertThat(playlistSource).contains("moveGroupFocus(safeGroup)")

        // 集数/分组横滑 state；分组可见性走 suspend 瞬移+软边。
        assertThat(playlistSource).contains("episodeListState")
        assertThat(playlistSource).contains("groupListState")
        assertThat(playlistSource).contains("scrollPlayerMenuChipIntoViewSuspend(")
        assertThat(playlistSource).contains("state = episodeListState")
        assertThat(playlistSource).contains("state = groupListState")
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
        assertThat(otherMenuSource).contains("确认设置当前时间 · 长按清空")
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
