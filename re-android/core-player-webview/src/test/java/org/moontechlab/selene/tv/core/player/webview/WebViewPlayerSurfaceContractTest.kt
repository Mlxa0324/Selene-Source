package org.moontechlab.selene.tv.core.player.webview

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 WebView 播放画面层的 Compose 接入契约。
 */
class WebViewPlayerSurfaceContractTest {
    /**
     * WebView 播放模块必须启用 Compose，才能向播放器壳注入真实画面层。
     */
    @Test
    fun webview_player_module_enables_compose_surface() {
        val source = readBuildGradleSource()

        assertThat(source).contains("alias(libs.plugins.kotlin.compose)")
        assertThat(source).contains("compose = true")
        assertThat(source).contains("implementation(platform(libs.androidx.compose.bom))")
        assertThat(source).contains("implementation(libs.androidx.compose.ui)")
    }

    /**
     * WebView 播放画面层必须使用 AndroidView 承载系统 WebView。
     */
    @Test
    fun webview_player_surface_renders_android_webview() {
        val source = readSurfaceSource()

        assertThat(source).contains("fun WebViewPlayerSurface(")
        assertThat(source).contains("AndroidView(")
        assertThat(source).contains("import android.webkit.WebView")
        assertThat(source).contains("settings.javaScriptEnabled = true")
        assertThat(source).contains("settings.mediaPlaybackRequiresUserGesture = false")
        assertThat(source).contains("settings.allowUniversalAccessFromFileURLs = true")
        assertThat(source).contains("settings.allowFileAccessFromFileURLs = true")
        assertThat(source).contains("settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW")
    }

    /**
     * WebView 播放画面层必须透出页面日志和资源错误，黑屏时可直接从 Logcat 定位原因。
     */
    @Test
    fun webview_player_surface_logs_console_and_resource_errors() {
        val source = readSurfaceSource()

        assertThat(source).contains("import android.webkit.WebChromeClient")
        assertThat(source).contains("import android.webkit.ConsoleMessage")
        assertThat(source).contains("import android.webkit.WebResourceError")
        assertThat(source).contains("import android.webkit.WebResourceRequest")
        assertThat(source).contains("import android.webkit.WebResourceResponse")
        assertThat(source).contains("webChromeClient = object : WebChromeClient()")
        assertThat(source).contains("override fun onConsoleMessage")
        assertThat(source).contains("override fun onReceivedError")
        assertThat(source).contains("override fun onReceivedHttpError")
        assertThat(source).contains("WEBVIEW_PLAYER_LOG_TAG")
    }

    /**
     * WebView 播放画面层必须复用内置 HLS 播放页并把播放地址传给页面。
     */
    @Test
    fun webview_player_surface_loads_bundled_hls_player_with_request_url() {
        val source = readSurfaceSource()

        assertThat(source).contains("HLS_PLAYER_ASSET_URL")
        assertThat(source).contains("loadUrl(resolveWebViewPlayerUrl(playbackUrl))")
        assertThat(source).contains("URLEncoder.encode(playbackUrl, Charsets.UTF_8.name())")
    }

    /**
     * WebView 页面加载完成后必须补一次 play，避免详情页首播命令早于页面创建而丢失。
     */
    @Test
    fun webview_player_surface_replays_play_after_page_finished() {
        val source = readSurfaceSource()

        assertThat(source).contains("import android.webkit.WebViewClient")
        assertThat(source).contains("override fun onPageFinished")
        assertThat(source).contains("evaluateJavascript(WebViewPlayerCommand.Play.toJavaScript(), null)")
    }

    /**
     * WebView 播放画面层不能在空播放地址时重复加载空页面。
     */
    @Test
    fun webview_player_surface_ignores_blank_playback_url() {
        val source = readSurfaceSource()

        assertThat(source).contains("playbackRequest: PlaybackRequest?")
        assertThat(source).contains("val playbackUrl = playbackRequest?.url.orEmpty()")
        assertThat(source).contains("if (playbackUrl.isBlank())")
        assertThat(source).contains("return@AndroidView")
    }

    /**
     * WebView 播放画面层必须收播放器内核命令并下发到页面 JS。
     */
    @Test
    fun webview_player_surface_evaluates_player_commands() {
        val source = readSurfaceSource()

        assertThat(source).contains("commandBus: WebViewPlayerCommandBus?")
        assertThat(source).contains("LaunchedEffect(commandBus)")
        assertThat(source).contains("commandBus.commands.collect")
        assertThat(source).contains("evaluateJavascript(command.toJavaScript(), null)")
    }

    /**
     * WebView 播放画面层必须注入原生 JS 桥，接收页面真实播放进度。
     */
    @Test
    fun webview_player_surface_injects_playback_event_bridge() {
        val source = readSurfaceSource()

        assertThat(source).contains("onPlaybackEvent: ((WebViewPlaybackEvent) -> Unit)?")
        assertThat(source).contains("import android.webkit.JavascriptInterface")
        assertThat(source).contains("addJavascriptInterface(")
        assertThat(source).contains("WEBVIEW_PLAYER_BRIDGE_NAME")
        assertThat(source).contains("@JavascriptInterface")
        assertThat(source).contains("onPlaybackEvent(payload: String)")
    }

    /**
     * WebView 命令必须映射到内置播放器页面的统一 JS 控制接口。
     */
    @Test
    fun webview_player_commands_map_to_bundled_page_api() {
        val source = readCommandSource()

        assertThat(source).contains("sealed interface WebViewPlayerCommand")
        assertThat(source).contains("WebViewPlayerCommand.Play")
        assertThat(source).contains("WebViewPlayerCommand.Pause")
        assertThat(source).contains("WebViewPlayerCommand.SeekTo")
        assertThat(source).contains("WebViewPlayerCommand.SetPlaybackSpeed")
        assertThat(source).contains("WebViewPlayerCommand.SetResizeMode")
        assertThat(source).contains("window.selenePlayer")
    }

    /**
     * 内置 HLS 播放页必须暴露统一 JS 控制接口，承接遥控器外壳命令。
     */
    @Test
    fun bundled_player_page_exposes_remote_control_api() {
        val source = readPlayerAssetSource()

        assertThat(source).contains("window.selenePlayer")
        assertThat(source).contains("play()")
        assertThat(source).contains("pause()")
        assertThat(source).contains("seekTo(positionMs)")
        assertThat(source).contains("setPlaybackSpeed(speed)")
        assertThat(source).contains("setResizeMode(mode)")
    }

    /**
     * 内置 HLS 库必须是真实 hls.js 包，不能再提交占位注释导致 m3u8 黑屏。
     */
    @Test
    fun bundled_hls_script_is_real_hls_runtime() {
        val source = readHlsScriptSource()

        assertThat(source.length).isAtLeast(100_000)
        assertThat(source).contains("Hls")
        assertThat(source).contains("MANIFEST_LOADING")
        assertThat(source).doesNotContain("hls bundle for initial WebView fallback integration")
    }

    /**
     * 内置播放页必须把真实播放事件上报给 Android，驱动原生进度条和播放状态。
     */
    @Test
    fun bundled_player_page_reports_playback_events_to_android_bridge() {
        val source = readPlayerAssetSource()

        assertThat(source).contains("window.SeleneAndroidPlayer")
        assertThat(source).contains("onPlaybackEvent(JSON.stringify")
        assertThat(source).contains("positionMs")
        assertThat(source).contains("durationMs")
        assertThat(source).contains("cachedRanges")
        assertThat(source).contains("networkSpeedBytesPerSecond")
        assertThat(source).contains("Hls.Events.FRAG_LOADED")
        assertThat(source).contains("updateNetworkSpeedFromStats")
        assertThat(source).contains("isPlaying")
        assertThat(source).contains("timeupdate")
        assertThat(source).contains("durationchange")
        assertThat(source).contains("progress")
        assertThat(source).contains("play")
        assertThat(source).contains("pause")
    }

    /**
     * 内置播放页必须在 manifest 解析和 video 可播放后重试起播，避免早期 play 被 WebView 吞掉。
     */
    @Test
    fun bundled_player_page_retries_play_after_media_is_ready() {
        val source = readPlayerAssetSource()

        assertThat(source).contains("let playRequested = true")
        assertThat(source).contains("function requestPlayback()")
        assertThat(source).contains("player.addEventListener('loadedmetadata', requestPlayback)")
        assertThat(source).contains("player.addEventListener('canplay', requestPlayback)")
        assertThat(source).contains("Hls.Events.MANIFEST_PARSED")
        assertThat(source).contains("hls.on(Hls.Events.ERROR")
        assertThat(source).contains("hls.recoverMediaError()")
        assertThat(source).contains("hls.startLoad()")
    }

    /**
     * 内置播放页不能展示 WebView 原生控件，TV 遥控器控制统一由 Compose 壳层接管。
     */
    @Test
    fun bundled_player_page_hides_native_video_controls() {
        val source = readPlayerAssetSource()

        assertThat(source).contains("<video id=\"player\"")
        assertThat(source).doesNotContain(" controls")
    }

    /**
     * 读取 WebView 播放模块构建脚本。
     *
     * @return 当前 Gradle 脚本文本。
     */
    private fun readBuildGradleSource(): String {
        return File("build.gradle.kts").readText()
    }

    /**
     * 读取 WebView 播放画面层源码。
     *
     * @return 当前画面层源码文本。
     */
    private fun readSurfaceSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerSurface.kt")
            .readText()
    }

    /**
     * 读取 WebView 播放命令源码。
     *
     * @return 当前命令源码文本。
     */
    private fun readCommandSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerCommand.kt")
            .readText()
    }

    /**
     * 读取内置 HLS 播放页。
     *
     * @return 当前播放页源码文本。
     */
    private fun readPlayerAssetSource(): String {
        return File("src/main/assets/player/hls_player.html").readText()
    }

    /**
     * 读取内置 hls.js。
     *
     * @return 当前 hls.js 源码文本。
     */
    private fun readHlsScriptSource(): String {
        return File("src/main/assets/player/hls.min.js").readText()
    }
}
