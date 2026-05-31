package org.moontechlab.selene.tv.core.design.layout

import kotlin.math.min

/**
 * TV 设计视口计算结果。
 *
 * @property configuredPreset 调用方配置的设计预设。
 * @property effectivePreset 当前视口最终生效的设计预设。
 * @property viewportWidth 当前视口宽度。
 * @property viewportHeight 当前视口高度。
 * @property scale 当前视口相对设计稿的缩放比例。
 */
data class TvDesignMetrics(
    val configuredPreset: TvDesignPreset,
    val effectivePreset: TvDesignPreset,
    val viewportWidth: Float,
    val viewportHeight: Float,
    val scale: Float,
) {
    /**
     * 兼容旧调用方读取的当前设计预设。
     */
    val preset: TvDesignPreset
        get() = effectivePreset

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
            val effectivePreset = resolveEffectivePreset(
                preset = preset,
                viewportWidth = viewportWidth,
                viewportHeight = viewportHeight,
            )
            val widthScale = viewportWidth / effectivePreset.designWidth
            val heightScale = viewportHeight / effectivePreset.designHeight
            // 低分辨率等比缩小，高分辨率保持设计稿原始比例。
            val scale = min(1f, min(widthScale, heightScale))
            return TvDesignMetrics(
                configuredPreset = preset,
                effectivePreset = effectivePreset,
                viewportWidth = viewportWidth,
                viewportHeight = viewportHeight,
                scale = scale,
            )
        }

        /**
         * 解析自动预设在当前视口下的实际设计稿。
         *
         * @param preset 调用方配置的预设。
         * @param viewportWidth 当前视口宽度。
         * @param viewportHeight 当前视口高度。
         * @return 实际生效的固定预设。
         */
        private fun resolveEffectivePreset(
            preset: TvDesignPreset,
            viewportWidth: Float,
            viewportHeight: Float,
        ): TvDesignPreset {
            if (preset != TvDesignPreset.AUTO) {
                return preset
            }
            return when {
                viewportWidth >= TvDesignPreset.QHD_1440.designWidth &&
                    viewportHeight >= TvDesignPreset.QHD_1440.designHeight -> TvDesignPreset.QHD_1440
                viewportWidth >= TvDesignPreset.FULL_HD_1080.designWidth &&
                    viewportHeight >= TvDesignPreset.FULL_HD_1080.designHeight -> TvDesignPreset.FULL_HD_1080
                else -> TvDesignPreset.HD720
            }
        }
    }
}
