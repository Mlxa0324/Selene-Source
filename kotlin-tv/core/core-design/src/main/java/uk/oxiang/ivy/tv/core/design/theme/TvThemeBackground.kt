package uk.oxiang.ivy.tv.core.design.theme

import androidx.compose.ui.graphics.Color

/**
 * TV 页面背景色标识。
 *
 * 对齐 Flutter `TvThemeBackground` 的 2 套可选背景，默认深蓝灰。
 *
 * @property storageKey 持久化存储标识。
 */
enum class TvThemeBackgroundKey(val storageKey: String) {
    /** 深蓝灰背景，默认背景。 */
    DEEP_BLUE("deep_blue"),

    /** 深黑夜幕背景。 */
    DEEP_BLACK("deep_black"),
}

/**
 * TV 页面背景配置。
 *
 * 独立承载 TV 页面级底色，避免和焦点主色耦合在一起。
 *
 * @property key 背景唯一标识。
 * @property label 设置页展示名称。
 * @property color 页面级背景色。
 */
data class TvThemeBackground(
    val key: TvThemeBackgroundKey,
    val label: String,
    val color: Color,
)

/**
 * TV 页面背景色目录。
 *
 * 数值精确对齐 Flutter `TvThemeBackground.deepBlue`/`deepBlack`。
 */
object TvThemeBackgroundCatalog {
    /** 深蓝灰背景。 */
    val deepBlue = TvThemeBackground(
        key = TvThemeBackgroundKey.DEEP_BLUE,
        label = "深蓝灰",
        color = Color(0xFF1A1D29),
    )

    /** 深黑夜幕背景。 */
    val deepBlack = TvThemeBackground(
        key = TvThemeBackgroundKey.DEEP_BLACK,
        label = "深黑夜幕",
        color = Color(0xFF0A0D0E),
    )

    /** 当前可选背景色列表。 */
    val all = listOf(deepBlue, deepBlack)

    /** 默认 TV 页面背景——深蓝灰。 */
    val default = deepBlue

    /**
     * 根据存储标识解析背景色。
     *
     * @param key 持久化存储标识。
     * @return 匹配的背景色；未匹配时回退默认深蓝灰。
     */
    fun fromKey(key: String): TvThemeBackground {
        return all.firstOrNull { background -> background.key.storageKey == key } ?: default
    }
}

/**
 * TV 页面共享中性色。
 *
 * 集中管理非主题主色的背景和卡片底色，保证首页、详情页和列表页一致。
 * 对齐 Flutter `TvThemeColors`（`lib/tv_app/services/tv_theme_service.dart`）。
 */
object TvThemeColors {
    /** 右侧内容区和选集、换源等卡片底色，以及海报卡片封面未获焦背景色。 */
    val cardSurface = Color(0xFF4B4E5A)

    /** 卡片底色上的弱边框色，海报卡片封面未获焦时使用。 */
    val cardSurfaceBorder = Color(0xFF616574)
}

/**
 * TV 卡片焦点效果模式。
 *
 * 用于控制首页横向列表和纵向 Grid 的卡片焦点表现，两个效果互斥。
 * 对齐 Flutter `TvFocusEffectMode`，默认放大镜模式。
 *
 * @property storageKey 持久化存储标识。
 * @property label 设置页展示名称。
 */
enum class TvFocusEffectMode(val storageKey: String, val label: String) {
    /** 仅保留当前卡片自身放大和焦点边框。默认模式。 */
    MAGNIFIER("magnifier", "放大镜"),

    /** 平滑移动的共享外边框。 */
    SMOOTH_FRAME("smooth_frame", "平滑外框");

    companion object {
        /** 默认焦点效果——放大镜，不是平滑外框。 */
        val default = MAGNIFIER

        /**
         * 根据存储标识解析焦点效果。
         *
         * @param key 持久化存储标识。
         * @return 匹配的焦点效果；未匹配时回退默认放大镜。
         */
        fun fromKey(key: String): TvFocusEffectMode {
            return entries.firstOrNull { mode -> mode.storageKey == key } ?: default
        }
    }
}
