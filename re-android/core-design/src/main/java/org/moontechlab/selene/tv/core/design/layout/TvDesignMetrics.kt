package org.moontechlab.selene.tv.core.design.layout

import kotlin.math.min

/**
 * TV 设计视口计算结果。
 *
 * @property preset 当前使用的设计预设。
 * @property viewportWidth 当前视口宽度。
 * @property viewportHeight 当前视口高度。
 * @property scale 当前视口相对设计稿的缩放比例。
 */
data class TvDesignMetrics(
    val preset: TvDesignPreset,
    val viewportWidth: Float,
    val viewportHeight: Float,
    val scale: Float,
) {
    companion object {
        /**
         * 根据当前视口创建设计标尺。
         *
         * @param preset 设计预设。
         * @param viewportWidth 当前视口宽度。
         * @param viewportHeight 当前视口高度。
         * @return 设计标尺计算结果。
         */
        fun fromViewport(
            preset: TvDesignPreset,
            viewportWidth: Float,
            viewportHeight: Float,
        ): TvDesignMetrics {
            val widthScale = viewportWidth / preset.designWidth
            val heightScale = viewportHeight / preset.designHeight
            // 低分辨率等比缩小，高分辨率保持设计稿原始比例。
            val scale = min(1f, min(widthScale, heightScale))
            return TvDesignMetrics(
                preset = preset,
                viewportWidth = viewportWidth,
                viewportHeight = viewportHeight,
                scale = scale,
            )
        }
    }
}
