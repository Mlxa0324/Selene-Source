package org.moontechlab.selene.tv.core.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme

/**
 * TV 端统一主题入口。
 */
object TvTheme {
    /**
     * 深色 TV 色板。
     */
    val DarkColors = darkColorScheme(
        primary = TvTokens.Accent,
        onPrimary = Color.White,
        background = TvTokens.Background,
        surface = TvTokens.Surface,
        onBackground = TvTokens.TextPrimary,
        onSurface = TvTokens.TextPrimary,
        surfaceVariant = TvTokens.SurfaceElevated,
        onSurfaceVariant = TvTokens.TextSecondary,
        secondary = TvTokens.TextSecondary,
        onSecondary = Color.White,
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
