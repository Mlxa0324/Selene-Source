package org.moontechlab.selene.tv.core.design.layout

/**
 * TV 设计视口预设。
 *
 * @property designWidth 设计稿宽度。
 * @property designHeight 设计稿高度。
 */
enum class TvDesignPreset(
    val designWidth: Int,
    val designHeight: Int,
) {
    /**
     * 根据当前视口自动选择设计稿预设。
     */
    AUTO(0, 0),

    /**
     * 720P 设计稿预设。
     */
    HD720(1280, 720),

    /**
     * 1080P 设计稿预设。
     */
    FULL_HD_1080(1920, 1080),

    /**
     * 1440P 设计稿预设。
     */
    QHD_1440(2560, 1440),
}
