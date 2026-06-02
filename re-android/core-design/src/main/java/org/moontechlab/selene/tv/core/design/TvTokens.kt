package org.moontechlab.selene.tv.core.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

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
     * TV 端页面卡片背景色。
     */
    val Surface = Color(0xFF272C30)

    /**
     * TV 端页面悬浮背景色。
     */
    val SurfaceElevated = Color(0xFF343946)

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
    val PageHorizontalPadding = 36.dp

    /**
     * TV 页面顶部留白。
     */
    val PageTopPadding = 24.dp

    /**
     * TV 页面区块纵向间距。
     */
    val SectionSpacing = 28.dp

    /**
     * TV 页面卡片间距。
     */
    val CardSpacing = 22.dp

    /**
     * TV 页面纵向内容底部留白。
     */
    val PageBottomPadding = 32.dp

    /**
     * TV 海报卡片宽度。
     */
    val PosterWidth = 168.dp

    /**
     * TV 海报卡片高度。
     */
    val PosterHeight = 304.dp

    /**
     * TV 海报封面高度。
     */
    val PosterCoverHeight = 244.dp

    /**
     * TV 顶部快捷入口高度。
     */
    val TopActionHeight = 44.dp

    /**
     * TV 顶部快捷入口圆角。
     */
    val TopActionRadius = 22.dp

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
}
