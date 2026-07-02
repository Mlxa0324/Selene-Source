package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 设计视口选择和缩放契约。
 */
class TvDesignMetricsTest {
    /**
     * 自动预设在 2K 视口下选择 QHD 设计稿。
     */
    @Test
    fun autoPreset_resolvesQhdWhenViewportIsLargeEnough() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 2560f,
            viewportHeight = 1440f,
        )

        assertThat(metrics.configuredPreset).isEqualTo(TvDesignPreset.AUTO)
        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    /**
     * 自动预设在 1080P 视口下选择 1080P 设计稿。
     */
    @Test
    fun autoPreset_resolvesFullHdWhenViewportIs1080p() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 1920f,
            viewportHeight = 1080f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.FULL_HD_1080)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    /**
     * 固定预设根据视口等比缩放，低分辨率缩小，高分辨率放大。
     */
    @Test
    fun fixedPreset_scalesWithViewportRatio() {
        val smallViewport = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.FULL_HD_1080,
            viewportWidth = 1280f,
            viewportHeight = 720f,
        )
        val largeViewport = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.HD720,
            viewportWidth = 1920f,
            viewportHeight = 1080f,
        )

        assertThat(smallViewport.effectivePreset).isEqualTo(TvDesignPreset.FULL_HD_1080)
        assertThat(smallViewport.scale).isEqualTo(2f / 3f)
        assertThat(largeViewport.scale).isEqualTo(1.5f)
    }

    /**
     * 固定使用 2K 设计稿时，1080P 视口必须只做等比缩小，不能切成另一套更紧凑的版式。
     */
    @Test
    fun qhdPreset_scales1080ViewportWithoutSwitchingLayoutPreset() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.QHD_1440,
            viewportWidth = 1920f,
            viewportHeight = 1080f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.scale).isEqualTo(0.75f)
    }

    /**
     * 固定使用 2K 设计稿时，4K 视口必须等比放大，不能停留在屏幕中间的一块 2K 区域。
     */
    @Test
    fun qhdPreset_scales4kViewportWithSameVisualRatio() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.QHD_1440,
            viewportWidth = 3840f,
            viewportHeight = 2160f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.scale).isEqualTo(1.5f)
    }

    /**
     * AUTO 模式在非 16:9 视口下按宽度选预设，高度按宽高比自适应。
     */
    @Test
    fun autoPreset_adaptsDesignHeightToViewportAspectRatio() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 2560f,
            viewportHeight = 1200f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.effectiveDesignWidth).isEqualTo(2560)
        assertThat(metrics.effectiveDesignHeight).isEqualTo(1200)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    /**
     * AUTO 模式 720P 视口下的预设选择和自适高度。
     */
    @Test
    fun autoPreset_resolvesHd720AndAdaptsAspectRatio() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 1280f,
            viewportHeight = 800f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.HD720)
        assertThat(metrics.effectiveDesignWidth).isEqualTo(1280)
        assertThat(metrics.effectiveDesignHeight).isEqualTo(800)
        assertThat(metrics.scale).isEqualTo(1f)
    }

    /**
     * AUTO 模式 4K 16:9 视口下设计高度与预设一致。
     */
    @Test
    fun autoPreset_4kViewportKeepsPresetHeightForSameAspectRatio() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.AUTO,
            viewportWidth = 3840f,
            viewportHeight = 2160f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.effectiveDesignWidth).isEqualTo(2560)
        assertThat(metrics.effectiveDesignHeight).isEqualTo(1440)
        assertThat(metrics.scale).isEqualTo(1.5f)
    }

    /**
     * 固定 2K 预设 + 非 16:9 视口：设计宽度锚定 2560，高度按宽高比自适应填满屏幕。
     */
    @Test
    fun qhdPreset_adaptsDesignHeightToNon169Viewport() {
        val metrics = TvDesignMetrics.fromViewport(
            preset = TvDesignPreset.QHD_1440,
            viewportWidth = 2560f,
            viewportHeight = 1200f,
        )

        assertThat(metrics.effectivePreset).isEqualTo(TvDesignPreset.QHD_1440)
        assertThat(metrics.effectiveDesignWidth).isEqualTo(2560)
        assertThat(metrics.effectiveDesignHeight).isEqualTo(1200)
        assertThat(metrics.scale).isEqualTo(1f)
    }
}
