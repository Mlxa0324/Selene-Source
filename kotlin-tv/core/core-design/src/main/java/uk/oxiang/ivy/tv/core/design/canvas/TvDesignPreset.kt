package uk.oxiang.ivy.tv.core.design.canvas

/**
 * TV 设计稿预设。
 *
 * 对齐 Flutter `lib/tv_app/widgets/tv_design_canvas.dart` 的 `TvDesignPreset`。
 *
 * @property designWidth 设计稿宽度，`AUTO` 为 0（运行时按视口解析）。
 * @property designHeight 设计稿高度，`AUTO` 为 0（运行时按视口解析）。
 */
enum class TvDesignPreset(val designWidth: Int, val designHeight: Int) {
    /** 自动根据当前视口选择最合适的设计稿。 */
    AUTO(0, 0),

    /** 720p 设计稿。 */
    HD720(1280, 720),

    /** 1080p 设计稿。 */
    FULL_HD1080(1920, 1080),

    /** 1440p 设计稿。 */
    QHD1440(2560, 1440),
}
