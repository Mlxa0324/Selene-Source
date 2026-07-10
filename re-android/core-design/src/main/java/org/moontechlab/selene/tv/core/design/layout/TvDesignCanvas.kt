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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density

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
 * 固定使用指定设计稿尺寸作为视觉基准：
 * - 当前视口小于设计稿时等比缩小；
 * - 当前视口大于设计稿时等比放大；
 * - 所有页面共享同一套逻辑宽高，避免 1080P 切到另一套更紧凑的版式。
 *
 * 这里不再对整棵树做 graphicsLayer 缩放，而是改成缩放 `LocalDensity`。
 * 原因是 WebView / SurfaceView / 其它 AndroidView 在父级 layer 变换下，BlueStacks 等环境里容易出现
 * “有声音无画面”的黑屏现象；density 缩放可以保持视觉比例，同时让平台视图走原生测量与绘制链路。
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
        val baseDensity = LocalDensity.current
        val viewportWidthPx = with(baseDensity) { maxWidth.toPx() }
        val viewportHeightPx = with(baseDensity) { maxHeight.toPx() }
        val designMetrics = remember(preset, viewportWidthPx, viewportHeightPx) {
            TvDesignMetrics.fromViewport(
                preset = preset,
                viewportWidth = viewportWidthPx,
                viewportHeight = viewportHeightPx,
            )
        }
        val scaledDensity = remember(baseDensity, designMetrics.scale) {
            Density(
                density = baseDensity.density * designMetrics.scale,
                fontScale = baseDensity.fontScale,
            )
        }

        CompositionLocalProvider(
            LocalTvDesignMetrics provides designMetrics,
            LocalDensity provides scaledDensity,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clipToBounds(),
            ) {
                content()
            }
        }
    }
}
