package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 设计画布缩放布局契约。
 */
class TvDesignCanvasContractTest {
    /**
     * 画布必须通过 density 缩放整棵 Compose 树，避免 AndroidView / WebView / SurfaceView 在父级 graphicsLayer 下黑屏。
     */
    @Test
    fun canvas_scales_through_density_instead_of_graphics_layer() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignCanvas.kt")
            .readText()

        assertThat(source).contains(".fillMaxSize()")
        assertThat(source).contains("CompositionLocalProvider(")
        assertThat(source).contains("LocalTvDesignMetrics provides designMetrics")
        assertThat(source).contains("LocalDensity provides scaledDensity")
        assertThat(source).contains("Density(")
        assertThat(source).contains("baseDensity.density * designMetrics.scale")
        assertThat(source).doesNotContain("placeWithLayer(")
        assertThat(source).doesNotContain("TransformOrigin")
        assertThat(source).doesNotContain("Constraints.fixed(")
    }
}
