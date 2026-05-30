package org.moontechlab.selene.tv.core.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * TV 端统一主题入口。
 */
object TvTheme {
    /**
     * 深色 TV 色板。
     */
    val DarkColors = darkColorScheme(
        primary = TvTokens.IvyGreen,
        background = TvTokens.Background,
        surface = Color(0xFF111418),
        onPrimary = Color.Black,
        onBackground = TvTokens.TextPrimary,
        onSurface = TvTokens.TextPrimary,
    )
}

/**
 * 应用 TV 端主题。
 *
 * @param content 需要套用 TV 主题的页面内容。
 */
@Composable
fun SeleneTvTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = TvTheme.DarkColors,
        content = content,
    )
}
