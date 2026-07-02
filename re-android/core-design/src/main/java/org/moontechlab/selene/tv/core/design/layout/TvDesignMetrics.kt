package org.moontechlab.selene.tv.core.design.layout


/**
 * TV 设计视口计算结果。
 *
 * @property configuredPreset 调用方配置的设计预设。
 * @property effectivePreset 当前视口最终生效的设计预设。
 * @property viewportWidth 当前视口宽度。
 * @property viewportHeight 当前视口高度。
 * @property scale 当前视口相对设计稿的等比缩放比例。
 */
data class TvDesignMetrics(
    val configuredPreset: TvDesignPreset,
    val effectivePreset: TvDesignPreset,
    val viewportWidth: Float,
    val viewportHeight: Float,
    val scale: Float,
    val effectiveDesignWidth: Int,
    val effectiveDesignHeight: Int,
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
            // 设计宽度锚定在预设值，高度按视口宽高比自适应，画布填满任意分辨率。
            val effectiveDesignWidth = effectivePreset.designWidth
            val effectiveDesignHeight = (effectiveDesignWidth * viewportHeight / viewportWidth).toInt()
            // 高度自适应后 widthScale == heightScale，等比缩放不变。
            val scale = viewportWidth / effectiveDesignWidth
            return TvDesignMetrics(
                configuredPreset = preset,
                effectivePreset = effectivePreset,
                viewportWidth = viewportWidth,
                viewportHeight = viewportHeight,
                scale = scale,
                effectiveDesignWidth = effectiveDesignWidth,
                effectiveDesignHeight = effectiveDesignHeight,
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
            // AUTO 模式按视口宽度选设计密度，高度随后按宽高比自适应。
            return when {
                viewportWidth >= TvDesignPreset.QHD_1440.designWidth -> TvDesignPreset.QHD_1440
                viewportWidth >= TvDesignPreset.FULL_HD_1080.designWidth -> TvDesignPreset.FULL_HD_1080
                else -> TvDesignPreset.HD720
            }
        }
    }
}
