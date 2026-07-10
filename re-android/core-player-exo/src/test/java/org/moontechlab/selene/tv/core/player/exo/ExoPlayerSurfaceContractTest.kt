package org.moontechlab.selene.tv.core.player.exo

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 ExoPlayer 画面承载层契约。
 */
class ExoPlayerSurfaceContractTest {
    /**
     * BlueStacks 下 Exo 画面不能再直接裸挂 SurfaceView，
     * 必须改走 Media3 PlayerView，交给官方宿主处理渲染生命周期。
     */
    @Test
    fun exo_surface_uses_media3_player_view_host() {
        val source = readSurfaceSource()

        assertThat(source).contains("import androidx.media3.ui.PlayerView")
        assertThat(source).contains("PlayerView")
        assertThat(source).contains("setEnableComposeSurfaceSyncWorkaround(true)")
        assertThat(source).doesNotContain("SurfaceView(context)")
        assertThat(source).doesNotContain("SurfaceHolder.Callback")
    }

    /**
     * TV 播放画面宿主必须关闭原生控制层，并强制使用 TextureView，
     * 避免 BlueStacks 对独立 SurfaceView 图层的合成不稳定。
     */
    @Test
    fun exo_surface_layout_uses_texture_view_without_native_controls() {
        val source = readSurfaceLayout()

        assertThat(source).contains("androidx.media3.ui.PlayerView")
        assertThat(source).contains("app:surface_type=\"texture_view\"")
        assertThat(source).contains("app:use_controller=\"false\"")
    }

    /**
     * 共享 ExoPlayer 在详情页和全屏页切换时必须先解绑旧输出，再由活跃页面下一帧接管。
     */
    @Test
    fun exo_surface_rebinds_video_output_when_route_becomes_active() {
        val source = readSurfaceSource()

        assertThat(source).contains("isActive: Boolean = true")
        assertThat(source).contains("LaunchedEffect(exoPlayer, isActive, playerView)")
        assertThat(source).contains("withFrameNanos { }")
        assertThat(source).contains("activePlayerView.player = null")
        assertThat(source).contains("activePlayerView.player = currentPlayer.value")
    }

    /**
     * Exo 平台画面层不能抢占全屏播放器壳的遥控器焦点。
     */
    @Test
    fun exo_surface_does_not_capture_tv_focus() {
        val source = readSurfaceSource()

        assertThat(source).contains("isFocusable = false")
        assertThat(source).contains("isFocusableInTouchMode = false")
    }

    /**
     * Exo 调试链路必须记录首帧、视频尺寸和轨道信息，
     * 否则 adb 里无法区分“没有视频轨”和“有视频轨但没显示出来”。
     */
    @Test
    fun exo_factory_logs_render_and_track_debug_events() {
        val source = readFactorySource()

        assertThat(source).contains("EXO_PLAYER_LOG_TAG")
        assertThat(source).contains("override fun onTracksChanged(tracks: Tracks)")
        assertThat(source).contains("override fun onVideoSizeChanged(videoSize: VideoSize)")
        assertThat(source).contains("override fun onRenderedFirstFrame()")
        assertThat(source).contains("override fun onSurfaceSizeChanged(width: Int, height: Int)")
    }

    /**
     * Exo 内核必须显式带上 HLS 扩展，
     * 否则详情页从 WebView 回退到 Exo 后仍然无法播放大多数 m3u8 源。
     */
    @Test
    fun exo_module_declares_media3_hls_dependency() {
        val source = readBuildScriptSource()

        assertThat(source).contains("libs.androidx.media3.exoplayer.hls")
    }

    /**
     * 读取 ExoPlayer 画面层源码。
     *
     * @return 当前源码文本。
     */
    private fun readSurfaceSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerSurface.kt")
            .readText()
    }

    /**
     * 读取 ExoPlayer 画面层布局。
     *
     * @return 当前布局文本。
     */
    private fun readSurfaceLayout(): String {
        return File("src/main/res/layout/exo_player_surface_view.xml")
            .readText()
    }

    /**
     * 读取 ExoPlayer 工厂源码。
     *
     * @return 当前工厂源码文本。
     */
    private fun readFactorySource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerFactory.kt")
            .readText()
    }

    /**
     * 读取 ExoPlayer 模块构建脚本。
     *
     * @return 当前构建脚本文本。
     */
    private fun readBuildScriptSource(): String {
        return File("build.gradle.kts").readText()
    }
}
