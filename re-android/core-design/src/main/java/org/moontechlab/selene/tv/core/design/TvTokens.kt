package org.moontechlab.selene.tv.core.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * TV 端视觉 token 集合。
 */
object TvTokens {
    /**
     * 默认主题色：奈飞红。
     */
    private val DefaultAccent = Color(0xFFE50914)

    /**
     * 当前进程内生效的主题色。
     *
     * 设置页切换主题后由 [applyThemeKey] 更新；Compose 需配合外观版本号重组才能立刻重绘。
     */
    @Volatile
    private var accentOverride: Color = DefaultAccent

    /**
     * TV 默认选中主色，贴近 Flutter TV 默认奈飞红。
     *
     * 历史命名保留 IvyGreen，实际默认值已是奈飞红。
     */
    val IvyGreen: Color
        get() = accentOverride

    /**
     * TV 默认选中主色别名，供新样式语义化调用。
     */
    val Accent: Color
        get() = accentOverride

    /**
     * 根据设置页主题色标识解析主色。
     *
     * @param themeKey 设置页保存的主题标识。
     * @return 对应主题色；未知标识回退奈飞红。
     */
    fun resolveAccentColor(themeKey: String): Color {
        return when (themeKey.trim()) {
            "netflix_red" -> Color(0xFFE50914)
            "teal" -> Color(0xFF14B8A6)
            // 星云紫：Twitch / Discord 系，替代旧「暖橙」。
            "violet", "amber" -> Color(0xFF8B5CF6)
            // 冰蓝略偏品牌蓝，更接近大厂按钮主色。
            "ice_blue" -> Color(0xFF3B82F6)
            // 翡翠绿：Spotify 系，替代旧「墨灰」。
            "emerald", "dark_gray" -> Color(0xFF10B981)
            else -> DefaultAccent
        }
    }

    /**
     * 应用设置页主题色到全局 Accent。
     *
     * @param themeKey 设置页保存的主题标识。
     */
    fun applyThemeKey(themeKey: String) {
        accentOverride = resolveAccentColor(themeKey)
    }

    /**
     * TV 快捷入口和弱焦点的半透明白色蒙层。
     */
    val FocusFill = Color(0x26FFFFFF)

    /**
     * TV 默认焦点描边色。
     */
    val FocusBorder = Color.White

    /**
     * TV 页面默认背景色。
     */
    val Background = Color(0xFF1A1D29)

    /**
     * 根据设置页背景标识解析详情等页面的基础背景色。
     *
     * @param backgroundKey 设置页保存的背景标识。
     * @return 对应背景色；未知标识回退默认深蓝。
     */
    fun resolveBackgroundColor(backgroundKey: String): Color {
        return when (backgroundKey) {
            // 深蓝灰：当前默认，接近奈飞/视频站冷色底。
            "deep_blue" -> Background
            // 炭黑：Spotify / YouTube Material Dark（#121212），避免刺眼纯黑。
            "charcoal", "pure_black" -> Color(0xFF121212)
            // 石板：Tailwind slate-900，现代后台深色。
            "slate", "dark_purple" -> Color(0xFF0F172A)
            // 石墨：Apple 系统深色底 #1C1C1E。
            "graphite", "deep_green" -> Color(0xFF1C1C1E)
            else -> Background
        }
    }

    /**
     * TV 端页面卡片背景色。
     */
    val Surface = Color(0xFF272C30)

    /**
     * TV 端页面悬浮背景色。
     */
    val SurfaceElevated = Color(0xFF343946)

    /**
     * TV 海报在封面未显示前使用的统一浅灰占位色。
     */
    val PosterPlaceholder = Color(0xFF3C424A)

    /**
     * TV 端分割线与描边颜色。
     */
    val Outline = Color(0xFF4B515C)

    /**
     * TV 错误状态颜色。
     */
    val Danger = Color(0xFFE25555)

    /**
     * TV 主要文字颜色。
     */
    val TextPrimary = Color(0xFFF7F8FA)

    /**
     * TV 次级文字颜色。
     */
    val TextSecondary = Color(0xFFB6C2BF)

    /**
     * TV 焦点描边宽度。
     */
    val FocusBorderWidth = 3.dp

    /**
     * TV 卡片圆角。
     */
    val CardRadius = 8.dp

    /**
     * TV 页面水平安全边距。
     */
    val PageHorizontalPadding = 50.dp

    /**
     * TV 页面顶部留白（页面自带标题时用；顶栏下方内容页宜更小）。
     */
    val PageTopPadding = 12.dp

    /**
     * TV 页面区块纵向间距。
     *
     * 首页多层横向海报带需要略大的纵向呼吸，避免标题贴着上一行封面。
     */
    val SectionSpacing = 28.dp

    /**
     * TV 页面卡片间距。
     */
    val CardSpacing = 16.dp

    /**
     * TV 页面纵向内容底部留白。
     */
    val PageBottomPadding = 32.dp

    /**
     * TV 海报卡片宽度。
     */
    val PosterWidth = 158.dp

    /**
     * TV 海报卡片高度。
     */
    val PosterHeight = 288.dp

    /**
     * TV 海报封面高度。
     */
    val PosterCoverHeight = 225.dp

    /**
     * TV 顶部快捷入口 / 详情底栏胶囊高度。
     */
    val TopActionHeight = 40.dp

    /**
     * TV 顶部快捷入口圆角。
     */
    val TopActionRadius = 20.dp

    /**
     * 胶囊按钮左右内边距（图标/文字到边框的距离）。
     */
    val TopActionHorizontalPadding = 18.dp

    /**
     * 胶囊内图标与文字间距。
     */
    val TopActionIconTextSpacing = 6.dp

    /**
     * 胶囊按钮标签字号。
     */
    val TopActionLabelSize: TextUnit = 15.sp

    /**
     * 胶囊按钮内字符图标字号（⌕ ⚙ 等）。
     *
     * 略小于旧值，避免图标压过文字。
     */
    val TopActionIconGlyph: TextUnit = 18.sp

    /**
     * 按钮内矢量图标统一尺寸（详情底栏等）。
     *
     * 与 [TopActionIconGlyph] 对齐观感。
     */
    val ActionIconSize = 18.dp

    /**
     * TV 弹窗水平内边距。
     */
    val DialogHorizontalPadding = 34.dp

    /**
     * TV 弹窗垂直内边距。
     */
    val DialogVerticalPadding = 28.dp

    /**
     * TV 弹窗内容间距。
     */
    val DialogContentSpacing = 18.dp

    /**
     * TV 弹窗按钮间距。
     */
    val DialogButtonSpacing = 14.dp

    // ── 表单专用 Token ──

    /**
     * TV 表单输入框/开关/滑杆背景色（内凹于卡片）。
     */
    val FormFieldBackground = Color(0xFF12161F)

    /**
     * TV 表单分区面板背景色（略浮于页面底色）。
     */
    val FormCardBackground = Color(0xFF222833)

    /**
     * TV 表单默认边框色。
     */
    val FormBorder = Color(0xFF343B4A)

    /**
     * TV 表单标签/提示文字颜色。
     */
    val FormTextSecondary = Color(0xFF9AA3B2)

    /**
     * TV 表单单行高度。
     */
    val FormRowHeight = 52.dp

    /**
     * TV 表单分区内边距。
     */
    val FormPanelPadding = 22.dp

    /**
     * TV 表单行水平内边距。
     */
    val FormRowHorizontalPadding = 18.dp

    /**
     * TV 表单卡片圆角（略大于海报卡，更偏设置面板）。
     */
    val FormCardRadius = 14.dp

    /**
     * TV 表单字段圆角。
     */
    val FormFieldRadius = 12.dp

    /**
     * TV 表单分区标题左侧强调条宽度。
     */
    val FormSectionAccentWidth = 3.dp
}
