package uk.oxiang.ivy.tv.core.design.canvas

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * [TvDesignMetrics] 契约测试：4 预设缩放计算、`auto` 匹配规则、只缩小不放大边界。
 *
 * 对齐 Flutter `tv_design_canvas.dart` 的 `TvDesignCanvas` 缩放语义。
 */
class TvDesignMetricsTest {

    @Test
    fun fixedPreset_scalesDownWhenViewportSmallerThanDesign() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.FULL_HD1080,
            viewportWidth = 960,
            viewportHeight = 540,
        )

        assertThat(metrics.resolvedPreset).isEqualTo(TvDesignPreset.FULL_HD1080)
        assertThat(metrics.scale).isEqualTo(0.5f)
    }

    @Test
    fun fixedPreset_neverScalesUp_whenViewportLargerThanDesign() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.HD720,
            viewportWidth = 3840,
            viewportHeight = 2160,
        )

        // 视口比设计稿更大时，缩放比例封顶 1，不允许放大。
        assertThat(metrics.scale).isEqualTo(1f)
    }

    @Test
    fun autoPreset_resolvesToQhd1440_whenViewportAtLeastQhd() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 2560,
            viewportHeight = 1440,
        )

        assertThat(metrics.resolvedPreset).isEqualTo(TvDesignPreset.QHD1440)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    @Test
    fun autoPreset_resolvesToFullHd1080_whenViewportBetweenFullHdAndQhd() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 1920,
            viewportHeight = 1080,
        )

        assertThat(metrics.resolvedPreset).isEqualTo(TvDesignPreset.FULL_HD1080)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    @Test
    fun autoPreset_fallsBackToHd720_whenViewportBelowFullHd() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 1280,
            viewportHeight = 720,
        )

        assertThat(metrics.resolvedPreset).isEqualTo(TvDesignPreset.HD720)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    @Test
    fun autoPreset_scalesDown_whenViewportSmallerThanHd720Fallback() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 640,
            viewportHeight = 360,
        )

        assertThat(metrics.resolvedPreset).isEqualTo(TvDesignPreset.HD720)
        assertThat(metrics.scale).isEqualTo(0.5f)
    }

    @Test
    fun scale_usesSmallerDimension_whenAspectRatioMismatched() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.FULL_HD1080,
            viewportWidth = 1920,
            viewportHeight = 540, // 高度只有设计稿一半，宽度不变
        )

        // 取宽高两个缩放比例中较小的一个，保证内容不会在任一方向溢出。
        assertThat(metrics.scale).isEqualTo(0.5f)
    }
}
