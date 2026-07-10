package uk.oxiang.ivy.tv.core.design

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme
import uk.oxiang.ivy.tv.core.design.canvas.LocalTvDesignMetrics
import uk.oxiang.ivy.tv.core.design.canvas.TvDesignMetrics
import uk.oxiang.ivy.tv.core.design.theme.TvFocusEffectMode
import uk.oxiang.ivy.tv.core.design.theme.TvThemeBackground
import uk.oxiang.ivy.tv.core.design.theme.TvThemeBackgroundCatalog
import uk.oxiang.ivy.tv.core.design.theme.TvThemePalette
import uk.oxiang.ivy.tv.core.design.theme.TvThemePaletteCatalog

/**
 * 当前 TV 主题色的组合本地值。
 *
 * 默认奈飞红，未套用作用域时页面读取到的仍是合法主题色。
 */
val LocalTvThemePalette = compositionLocalOf { TvThemePaletteCatalog.default }

/**
 * 当前 TV 页面背景色的组合本地值。
 *
 * 默认深蓝灰。
 */
val LocalTvThemeBackground = compositionLocalOf { TvThemeBackgroundCatalog.default }

/**
 * 当前 TV 卡片焦点效果模式的组合本地值。
 *
 * 默认放大镜模式。
 */
val LocalTvFocusEffectMode = compositionLocalOf { TvFocusEffectMode.default }

/**
 * TV 端统一主题入口。
 *
 * 三组维度（主题色/背景色/焦点效果模式）各自独立可切换，对齐 Flutter
 * `TvThemeService`/`TvTheme`。
 */
object TvTheme {
    /**
     * 读取当前主题色。
     *
     * @param palette 当前作用域内的主题色，通常来自 [LocalTvThemePalette]。
     * @return 深色 TV 色板，主色跟随 [palette]。
     */
    fun darkColors(palette: TvThemePalette, background: TvThemeBackground) = darkColorScheme(
        primary = palette.accent,
        onPrimary = palette.selectedText,
        background = background.color,
        surface = TvTokens.Surface,
        onBackground = TvTokens.TextPrimary,
        onSurface = TvTokens.TextPrimary,
        surfaceVariant = TvTokens.SurfaceElevated,
        onSurfaceVariant = TvTokens.TextSecondary,
        secondary = TvTokens.TextSecondary,
        onSecondary = Color.White,
    )

    /**
     * 使用当前作用域中的三维主题状态和设计画布指标包装新的子树。
     *
     * `Navigation Compose` 的新路由或 `Dialog` 组合创建的子树默认不会继承
     * 当前 [CompositionLocalProvider] 作用域，这里显式透传，避免独立弹窗/路由
     * 脱离父级主题作用域。对应 Flutter `TvTheme.wrapScope`。
     *
     * @param palette 当前主题色。
     * @param background 当前页面背景色。
     * @param focusEffectMode 当前卡片焦点效果模式。
     * @param designMetrics 当前设计画布指标。
     * @param content 需要透传主题作用域的子树内容。
     */
    @Composable
    fun wrapScope(
        palette: TvThemePalette,
        background: TvThemeBackground,
        focusEffectMode: TvFocusEffectMode,
        designMetrics: TvDesignMetrics,
        content: @Composable () -> Unit,
    ) {
        CompositionLocalProvider(
            LocalTvThemePalette provides palette,
            LocalTvThemeBackground provides background,
            LocalTvFocusEffectMode provides focusEffectMode,
            LocalTvDesignMetrics provides designMetrics,
        ) {
            content()
        }
    }
}

/**
 * 应用 TV 端主题。
 *
 * @param palette 当前主题色，默认读取 [LocalTvThemePalette]。
 * @param background 当前页面背景色，默认读取 [LocalTvThemeBackground]。
 * @param content 需要套用 TV 主题的页面内容。
 */
@Composable
fun SeleneTvTheme(
    palette: TvThemePalette = LocalTvThemePalette.current,
    background: TvThemeBackground = LocalTvThemeBackground.current,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = TvTheme.darkColors(palette, background),
        content = content,
    )
}
