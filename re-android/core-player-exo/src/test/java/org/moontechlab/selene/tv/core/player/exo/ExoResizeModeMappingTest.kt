package org.moontechlab.selene.tv.core.player.exo

import androidx.media3.ui.AspectRatioFrameLayout
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 ExoPlayer 画面比例映射契约。
 */
class ExoResizeModeMappingTest {
    /**
     * TV 画面比例协议必须映射到 Media3 PlayerView 支持的真实 resizeMode。
     */
    @Test
    fun resize_mode_maps_to_media3_aspect_ratio_modes() {
        assertThat(TvResizeMode.FIT.toAspectRatioResizeMode())
            .isEqualTo(AspectRatioFrameLayout.RESIZE_MODE_FIT)
        assertThat(TvResizeMode.FILL.toAspectRatioResizeMode())
            .isEqualTo(AspectRatioFrameLayout.RESIZE_MODE_FILL)
        assertThat(TvResizeMode.WIDTH.toAspectRatioResizeMode())
            .isEqualTo(AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH)
        assertThat(TvResizeMode.HEIGHT.toAspectRatioResizeMode())
            .isEqualTo(AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT)
    }

    /**
     * Android 适配器设置画面比例时必须下发到 PlayerView 应用器，而不能只更新上层快照。
     */
    @Test
    fun android_adapter_delegates_resize_mode_to_player_view_applier() {
        val source = readFactorySource()

        assertThat(source).contains("private var resizeModeApplier: ExoResizeModeApplier")
        assertThat(source).contains("fun bindResizeModeApplier(applier: ExoResizeModeApplier)")
        assertThat(source).contains("resizeModeApplier.applyResizeMode(resizeMode)")
        assertThat(source).doesNotContain("这里先由上层快照持久化")
    }

    /**
     * 读取 ExoPlayer 工厂源码。
     *
     * @return 当前 ExoPlayerFactory 源码文本。
     */
    private fun readFactorySource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/exo/ExoPlayerFactory.kt")
            .readText()
    }
}
