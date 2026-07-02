package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Constraints

/**
 * 当前 TV 设计视口标尺。
 */
val LocalTvDesignMetrics = compositionLocalOf {
    TvDesignMetrics(
        configuredPreset = TvDesignPreset.QHD_1440,
        effectivePreset = TvDesignPreset.QHD_1440,
        viewportWidth = TvDesignPreset.QHD_1440.designWidth.toFloat(),
        viewportHeight = TvDesignPreset.QHD_1440.designHeight.toFloat(),
        scale = 1f,
        effectiveDesignWidth = TvDesignPreset.QHD_1440.designWidth,
        effectiveDesignHeight = TvDesignPreset.QHD_1440.designHeight,
    )
}

/**
 * TV 设计稿画布。
 *
 * 固定使用指定设计稿尺寸作为逻辑坐标系：
 * - 当前视口小于设计稿时等比缩小；
 * - 当前视口大于设计稿时等比放大；
 * - 所有页面共享同一套逻辑宽高，避免 1080P 切到另一套更紧凑的版式。
 *
 * @param preset 设计稿预设。
 * @param modifier 外层修饰器。
 * @param content 画布内容。
 */
@Composable
fun TvDesignCanvas(
    preset: TvDesignPreset = TvDesignPreset.QHD_1440,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .clipToBounds(),
    ) {
        val density = LocalDensity.current
        val viewportWidthPx = with(density) { maxWidth.toPx() }
        val viewportHeightPx = with(density) { maxHeight.toPx() }
        val designMetrics = remember(preset, viewportWidthPx, viewportHeightPx) {
            TvDesignMetrics.fromViewport(
                preset = preset,
                viewportWidth = viewportWidthPx,
                viewportHeight = viewportHeightPx,
            )
        }

        CompositionLocalProvider(LocalTvDesignMetrics provides designMetrics) {
            Layout(
                modifier = Modifier
                    .fillMaxSize()
                    .clipToBounds(),
                content = {
                    Box {
                        content()
                    }
                },
            ) { measurables, constraints ->
                val canvasPlaceable = measurables.single().measure(
                    Constraints.fixed(
                        width = designMetrics.effectiveDesignWidth,
                        height = designMetrics.effectiveDesignHeight,
                    ),
                )
                layout(
                    width = constraints.maxWidth,
                    height = constraints.maxHeight,
                ) {
                    // 画布固定从左上角放置，避免 Box + graphicsLayer 组合把缩小后的内容居中成负坐标。
                    canvasPlaceable.placeWithLayer(0, 0) {
                        scaleX = designMetrics.scale
                        scaleY = designMetrics.scale
                        transformOrigin = TransformOrigin(0f, 0f)
                    }
                }
            }
        }
    }
}
