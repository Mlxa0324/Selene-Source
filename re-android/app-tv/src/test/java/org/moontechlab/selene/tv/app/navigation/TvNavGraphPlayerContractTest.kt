package org.moontechlab.selene.tv.app.navigation

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 导航图与播放器内核的连接契约。
 */
class TvNavGraphPlayerContractTest {
    /**
     * 播放器路由必须通过应用容器注入播放器 ViewModel，避免全屏页拿不到真实内核。
     */
    @Test
    fun player_route_uses_container_created_player_view_model() {
        val source = readNavGraphSource()

        assertThat(source).contains("appContainer.createPlayerViewModel(")
        assertThat(source).contains("playbackRequest = playbackRequest")
        assertThat(source).contains("viewModel = playerViewModel")
    }

    /**
     * 播放器返回语义必须由导航图统一退栈，避免功能模块直接持有 NavController。
     */
    @Test
    fun player_route_exposes_exit_callback_to_pop_back_stack() {
        val source = readNavGraphSource()

        assertThat(source).contains("onExitRequested = {")
        assertThat(source).contains("navController.popBackStack()")
    }

    /**
     * 播放器路由必须注入 WebView 真实画面层，避免全屏页只显示默认占位信息。
     */
    @Test
    fun player_route_injects_webview_player_surface() {
        val source = readNavGraphSource()

        assertThat(source).contains("import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSurface")
        assertThat(source).contains("playerSurface = { state ->")
        assertThat(source).contains("WebViewPlayerSurface(")
        assertThat(source).contains("playbackRequest = state.playbackRequest")
        assertThat(source).contains("modifier = Modifier.fillMaxSize()")
    }

    /**
     * WebView 播放内核和画面层必须共享同一个会话，遥控器命令才能真正下发给 WebView。
     */
    @Test
    fun player_route_shares_webview_session_between_view_model_and_surface() {
        val source = readNavGraphSource()

        assertThat(source).contains("val webViewPlayerSession = remember(requestId, appContainer)")
        assertThat(source).contains("appContainer.createWebViewPlayerSession()")
        assertThat(source).contains("appContainer.createPlayerViewModel(")
        assertThat(source).contains("playerEngine = webViewPlayerSession.engine")
        assertThat(source).contains("commandBus = webViewPlayerSession.commandBus")
    }

    /**
     * WebView 画面层必须把真实播放事件回灌给同一个播放内核，驱动进度条和暂停态。
     */
    @Test
    fun player_route_routes_webview_playback_events_back_to_engine() {
        val source = readNavGraphSource()

        assertThat(source).contains("onPlaybackEvent = webViewPlayerSession.engine::updateFromWebView")
    }

    /**
     * 设置页必须接收顶层内容焦点请求器，保证右上角设置入口按下键能进入设置卡片。
     */
    @Test
    fun settings_route_receives_content_focus_requester() {
        val source = readNavGraphSource()
        val settingsRouteSource = source.substringAfter("composable(TvDestination.Settings.route)")
            .substringBefore("composable(TvDestination.Live.route)")

        assertThat(settingsRouteSource).contains("TvSettingsRoute(")
        assertThat(settingsRouteSource).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 设置页和播放器里的手动匹配入口必须进入同一个弹幕匹配路由，避免卡片或菜单确认后无动作。
     */
    @Test
    fun danmaku_match_entries_navigate_to_danmaku_match_route() {
        val source = readNavGraphSource()
        val settingsRouteSource = source.substringAfter("composable(TvDestination.Settings.route)")
            .substringBefore("composable(TvDestination.Live.route)")
        val playerRouteSource = source.substringAfter("TvPlayerRoute(")
            .substringBefore("onExitRequested = {")

        assertThat(source).contains("import org.moontechlab.selene.tv.feature.settings.TvDanmakuMatchRoute")
        assertThat(settingsRouteSource).contains("onDanmakuMatchClick = {")
        assertThat(settingsRouteSource).contains("TvDestination.DanmakuMatch.createRoute(\"\")")
        assertThat(playerRouteSource).contains("onDanmakuMatchRequested = { query ->")
        assertThat(playerRouteSource).contains("TvDestination.DanmakuMatch.createRoute(query)")
        assertThat(source).contains("composable(")
        assertThat(source).contains("route = TvDestination.DanmakuMatch.route")
        assertThat(source).contains("TvDanmakuMatchRoute(")
    }

    /**
     * 弹幕匹配页选择剧集后必须交给应用容器保存手动匹配结果。
     */
    @Test
    fun danmaku_match_route_saves_selected_episode_through_container() {
        val source = readNavGraphSource()
        val danmakuRouteSource = source.substringAfter("TvDanmakuMatchRoute(")
            .substringBefore("composable(TvDestination.Live.route)")

        assertThat(source).contains("var danmakuMatchPlaybackRequest by remember")
        assertThat(source).contains("danmakuMatchPlaybackRequest = playbackRequest")
        assertThat(danmakuRouteSource).contains("onEpisodeSelected = { anime, episode, episodeIndex ->")
        assertThat(danmakuRouteSource).contains("appContainer.saveDanmakuManualSelection(")
        assertThat(danmakuRouteSource).contains("searchKeyword = danmakuMatchState.query")
        assertThat(danmakuRouteSource).contains("navController.popBackStack()")
    }

    /**
     * 读取 TV 导航图源码。
     *
     * @return 当前 TvNavGraph 源码文本。
     */
    private fun readNavGraphSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/app/navigation/TvNavGraph.kt")
            .readText()
    }
}
