package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 设计画布缩放布局契约。
 */
class TvDesignCanvasContractTest {
    /**
     * 画布必须先按设计稿固定测量，再以左上角为原点缩放放置，避免 1080P 下出现负坐标裁切。
     */
    @Test
    fun canvas_placesScaledLayerFromTopLeft() {
        val source = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvDesignCanvas.kt")
            .readText()

        assertThat(source).contains(".fillMaxSize()")
        assertThat(source).contains("Layout(")
        assertThat(source).contains("Constraints.fixed(")
        assertThat(source).contains("canvasPlaceable.placeWithLayer(0, 0)")
        assertThat(source).contains("transformOrigin = TransformOrigin(0f, 0f)")

        val measureIndex = source.indexOf("Constraints.fixed(")
        val placeIndex = source.indexOf("canvasPlaceable.placeWithLayer(0, 0)")

        assertThat(measureIndex).isAtLeast(0)
        assertThat(placeIndex).isAtLeast(0)
        assertThat(measureIndex).isLessThan(placeIndex)
    }
}
