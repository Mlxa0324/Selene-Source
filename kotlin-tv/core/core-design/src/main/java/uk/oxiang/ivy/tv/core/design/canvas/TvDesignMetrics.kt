package uk.oxiang.ivy.tv.core.design.canvas

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.unit.IntSize
import kotlin.math.min

/**
 * TV 设计画布指标。
 *
 * 统一暴露当前 TV 页面相对于设计稿预设的缩放结果，对齐 Flutter `TvDesignMetrics`。
 *
 * @property scale 当前视口相对于设计稿的缩放比例，只会小于等于 1。
 * @property designSize 设计稿逻辑尺寸（像素）。
 * @property viewportSize 当前实际视口尺寸（像素）。
 * @property preset 调用方配置的设计稿预设。
 * @property resolvedPreset 当前视口下最终生效的设计稿预设。
 */
data class TvDesignMetrics(
    val scale: Float,
    val designSize: IntSize,
    val viewportSize: IntSize = designSize,
    val preset: TvDesignPreset = TvDesignPreset.FULL_HD1080,
    val resolvedPreset: TvDesignPreset = TvDesignPreset.FULL_HD1080,
) {
    companion object {
        /**
         * 根据当前视口和配置的预设计算设计画布指标。
         *
         * @param preset 调用方配置的设计稿预设。
         * @param viewportWidth 当前实际视口宽度。
         * @param viewportHeight 当前实际视口高度。
         * @return 已解析好缩放比例的设计画布指标。
         */
        fun fromViewport(
            preset: TvDesignPreset,
            viewportWidth: Int,
            viewportHeight: Int,
        ): TvDesignMetrics {
            val resolvedPreset = resolveEffectivePreset(preset, viewportWidth, viewportHeight)
            val designWidth = resolvedPreset.designWidth
            val designHeight = resolvedPreset.designHeight
            val widthScale = viewportWidth.toFloat() / designWidth
            val heightScale = viewportHeight.toFloat() / designHeight
            // 高分屏不额外放大，只在较小分辨率下按比例缩小。
            val scale = min(1f, min(widthScale, heightScale))
            return TvDesignMetrics(
                scale = scale,
                designSize = IntSize(designWidth, designHeight),
                viewportSize = IntSize(viewportWidth, viewportHeight),
                preset = preset,
                resolvedPreset = resolvedPreset,
            )
        }

        /**
         * 解析自动预设在当前视口下实际应使用的固定预设。
         *
         * 先匹配更高档位，保证大屏设备优先使用更接近的设计基准；
         * 更小分辨率统一回退到 720p 设计稿，避免低分屏整体显大一圈。
         *
         * @param preset 调用方配置的预设。
         * @param viewportWidth 当前视口宽度。
         * @param viewportHeight 当前视口高度。
         * @return 实际生效的固定预设。
         */
        private fun resolveEffectivePreset(
            preset: TvDesignPreset,
            viewportWidth: Int,
            viewportHeight: Int,
        ): TvDesignPreset {
            if (preset != TvDesignPreset.AUTO) {
                return preset
            }
            return when {
                viewportWidth >= TvDesignPreset.QHD1440.designWidth &&
                    viewportHeight >= TvDesignPreset.QHD1440.designHeight -> TvDesignPreset.QHD1440

                viewportWidth >= TvDesignPreset.FULL_HD1080.designWidth &&
                    viewportHeight >= TvDesignPreset.FULL_HD1080.designHeight -> TvDesignPreset.FULL_HD1080

                else -> TvDesignPreset.HD720
            }
        }
    }
}

/**
 * 当前 TV 设计画布指标的组合本地值。
 *
 * 默认值回退到 1080p 基准，避免测试或弹窗拿到无穷大尺寸。
 */
val LocalTvDesignMetrics = compositionLocalOf {
    TvDesignMetrics(
        scale = 1f,
        designSize = IntSize(
            TvDesignPreset.FULL_HD1080.designWidth,
            TvDesignPreset.FULL_HD1080.designHeight,
        ),
    )
}
