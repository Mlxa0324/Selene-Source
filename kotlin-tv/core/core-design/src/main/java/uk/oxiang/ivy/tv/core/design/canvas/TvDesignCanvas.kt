package uk.oxiang.ivy.tv.core.design.canvas

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.isFinite

/**
 * TV 端设计画布。
 *
 * 支持自动和固定设计稿预设，并在较小分辨率下整体等比缩小，保持 TV 页面在不同
 * 设备上的视觉比例稳定。对齐 Flutter `lib/tv_app/widgets/tv_design_canvas.dart`。
 *
 * 子树内部按设计稿坐标系开发（例如始终认为视口是 1920x1080），不需要感知实际
 * 设备分辨率；只在视口小于设计稿时等比缩小，不会因为视口更大而放大。
 *
 * @param preset 设计稿预设，默认自动匹配。
 * @param modifier 外层修饰器。
 * @param content 需要在设计画布坐标系下渲染的子树内容。
 */
@Composable
fun TvDesignCanvas(
    preset: TvDesignPreset = TvDesignPreset.AUTO,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    BoxWithConstraints(modifier = modifier) {
        val density = LocalDensity.current
        // 无约束场景（例如测试或极端弹窗）统一回退到 1080p 基准。
        val viewportWidthPx = with(density) {
            if (maxWidth.isFinite) maxWidth.toPx() else TvDesignPreset.FULL_HD1080.designWidth.dp.toPx()
        }
        val viewportHeightPx = with(density) {
            if (maxHeight.isFinite) maxHeight.toPx() else TvDesignPreset.FULL_HD1080.designHeight.dp.toPx()
        }
        val metrics = remember(preset, viewportWidthPx, viewportHeightPx) {
            TvDesignMetrics.fromViewport(
                preset = preset,
                viewportWidth = viewportWidthPx.toInt(),
                viewportHeight = viewportHeightPx.toInt(),
            )
        }

        CompositionLocalProvider(LocalTvDesignMetrics provides metrics) {
            val designWidthDp = with(density) { metrics.designSize.width.toDp() }
            val designHeightDp = with(density) { metrics.designSize.height.toDp() }
            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .size(width = designWidthDp, height = designHeightDp)
                    .graphicsLayer(
                        scaleX = metrics.scale,
                        scaleY = metrics.scale,
                        transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0f),
                    ),
            ) {
                content()
            }
        }
    }
}
