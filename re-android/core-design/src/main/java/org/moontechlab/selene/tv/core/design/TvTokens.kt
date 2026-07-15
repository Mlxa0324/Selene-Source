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
     * TV 默认选中主色，贴近 Flutter TV 默认奈飞红。
     */
    val IvyGreen = Color(0xFFE50914)

    /**
     * TV 默认选中主色别名，供新样式语义化调用。
     */
    val Accent = IvyGreen

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
            "deep_blue" -> Background
            "pure_black" -> Color(0xFF000000)
            "dark_purple" -> Color(0xFF2D1B4E)
            "deep_green" -> Color(0xFF064E3B)
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
     * TV 顶部快捷入口高度。
     */
    val TopActionHeight = 38.dp

    /**
     * TV 顶部快捷入口圆角。
     */
    val TopActionRadius = 22.dp

    /**
     * 胶囊按钮内字符图标字号（⌕ 等）。
     *
     * 与 [ActionIconSize] 矢量图标视觉等重，全局搜索/详情顶栏共用。
     */
    val TopActionIconGlyph: TextUnit = 24.sp

    /**
     * 按钮内矢量图标统一尺寸（详情全屏/收藏/底部胶囊等）。
     *
     * 与 [TopActionIconGlyph] 对齐观感，避免一处偏大一处偏小。
     */
    val ActionIconSize = 22.dp

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
     * TV 表单输入框/开关/滑杆背景色。
     */
    val FormFieldBackground = Color(0xFF0E1112)

    /**
     * TV 表单分区面板背景色。
     */
    val FormCardBackground = Color(0xFF15191B)

    /**
     * TV 表单默认边框色。
     */
    val FormBorder = Color(0xFF293136)

    /**
     * TV 表单标签/提示文字颜色。
     */
    val FormTextSecondary = Color(0xFF98A2A8)

    /**
     * TV 表单单行高度。
     */
    val FormRowHeight = 52.dp

    /**
     * TV 表单分区内边距。
     */
    val FormPanelPadding = 24.dp

    /**
     * TV 表单行水平内边距。
     */
    val FormRowHorizontalPadding = 20.dp
}
