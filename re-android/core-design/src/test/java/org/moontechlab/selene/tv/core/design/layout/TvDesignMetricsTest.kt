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
     * 低于设计稿的视口只缩小不放大。
     */
    @Test
    fun fixedPreset_scalesDownButNeverScalesUp() {
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
        assertThat(largeViewport.scale).isEqualTo(1f)
    }
}
