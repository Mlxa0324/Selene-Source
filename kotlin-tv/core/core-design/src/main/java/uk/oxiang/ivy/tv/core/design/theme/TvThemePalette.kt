package uk.oxiang.ivy.tv.core.design.theme

import androidx.compose.ui.graphics.Color

/**
 * TV 主题色标识。
 *
 * 对齐 Flutter `TvThemePalette` 的 3 套可选主题色，默认奈飞红。
 *
 * @property storageKey 持久化存储标识，与 Flutter 端字符串保持一致，方便对照。
 */
enum class TvThemePaletteKey(val storageKey: String) {
    /** 奈飞红，默认主题。 */
    NETFLIX_RED("netflix_red"),

    /** Ivy 绿。 */
    IVY_GREEN("ivy_green"),

    /** 柔和蓝。 */
    SOFT_BLUE("soft_blue"),
}

/**
 * TV 主题色调色板。
 *
 * 只承载 TV 端焦点、选中态和主按钮颜色，避免影响普通端主题。
 *
 * @property key 主题唯一标识。
 * @property label 设置页展示名称。
 * @property accent 主色，用于选中态和主要按钮。
 * @property focus 焦点描边色。
 * @property focusFill 焦点弱背景色。
 * @property disabledFill 禁用按钮背景色。
 * @property selectedText 主色背景上的文字颜色。
 */
data class TvThemePalette(
    val key: TvThemePaletteKey,
    val label: String,
    val accent: Color,
    val focus: Color,
    val focusFill: Color,
    val disabledFill: Color,
    val selectedText: Color,
)

/**
 * TV 主题色调色板目录。
 *
 * 数值精确对齐 Flutter `lib/tv_app/services/tv_theme_service.dart` 的
 * `TvThemePalette.netflixRed`/`ivyGreen`/`softBlue`。
 */
object TvThemePaletteCatalog {
    /** 奈飞红主题。 */
    val netflixRed = TvThemePalette(
        key = TvThemePaletteKey.NETFLIX_RED,
        label = "奈飞红",
        accent = Color(0xFFE50914),
        focus = Color(0xFFFF3B45),
        focusFill = Color(0xFF2D1719),
        disabledFill = Color(0xFF3F2527),
        selectedText = Color.White,
    )

    /** Ivy 绿主题。 */
    val ivyGreen = TvThemePalette(
        key = TvThemePaletteKey.IVY_GREEN,
        label = "Ivy 绿",
        accent = Color(0xFF26C96F),
        focus = Color(0xFF42D37B),
        focusFill = Color(0xFF1D2A24),
        disabledFill = Color(0xFF33413A),
        selectedText = Color.Black,
    )

    /** 柔和蓝主题。 */
    val softBlue = TvThemePalette(
        key = TvThemePaletteKey.SOFT_BLUE,
        label = "柔和蓝",
        accent = Color(0xFF5B7CFA),
        focus = Color(0xFF7F99FF),
        focusFill = Color(0xFF222A46),
        disabledFill = Color(0xFF343B50),
        selectedText = Color.White,
    )

    /** 所有可选 TV 主题色，展示顺序对齐 Flutter `TvThemePalette.values`。 */
    val all = listOf(netflixRed, ivyGreen, softBlue)

    /** 默认 TV 主题色——奈飞红，不是 Ivy 绿。 */
    val default = netflixRed

    /**
     * 根据存储标识解析主题色。
     *
     * @param key 持久化存储标识。
     * @return 匹配的主题色；未匹配时回退默认奈飞红。
     */
    fun fromKey(key: String): TvThemePalette {
        return all.firstOrNull { palette -> palette.key.storageKey == key } ?: default
    }
}
