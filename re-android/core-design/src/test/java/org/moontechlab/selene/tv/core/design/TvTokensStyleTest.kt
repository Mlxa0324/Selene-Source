package org.moontechlab.selene.tv.core.design

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 Kotlin TV 默认视觉 token 是否贴近 Flutter TV 默认主题。
 */
class TvTokensStyleTest {
    /**
     * 默认背景应使用 Flutter TV 的深蓝灰底色。
     */
    @Test
    fun defaultBackground_matchesFlutterTvDeepBlue() {
        assertThat(TvTokens.Background).isEqualTo(Color(0xFF1A1D29))
    }

    /**
     * 设置页提供的背景标识必须映射为对应详情页基础色，未知值回退默认深蓝。
     */
    @Test
    fun configuredBackground_resolvesSettingPaletteAndFallsBackToDeepBlue() {
        assertThat(TvTokens.resolveBackgroundColor("deep_blue")).isEqualTo(Color(0xFF1A1D29))
        assertThat(TvTokens.resolveBackgroundColor("charcoal")).isEqualTo(Color(0xFF121212))
        assertThat(TvTokens.resolveBackgroundColor("slate")).isEqualTo(Color(0xFF0F172A))
        assertThat(TvTokens.resolveBackgroundColor("graphite")).isEqualTo(Color(0xFF1C1C1E))
        // 历史 key 兼容映射，避免旧用户存盘后回退异常。
        assertThat(TvTokens.resolveBackgroundColor("pure_black")).isEqualTo(Color(0xFF121212))
        assertThat(TvTokens.resolveBackgroundColor("dark_purple")).isEqualTo(Color(0xFF0F172A))
        assertThat(TvTokens.resolveBackgroundColor("deep_green")).isEqualTo(Color(0xFF1C1C1E))
        assertThat(TvTokens.resolveBackgroundColor("unknown")).isEqualTo(TvTokens.Background)
    }

    /**
     * 默认选中主色应使用 Flutter TV 默认奈飞红。
     */
    @Test
    fun defaultAccent_matchesFlutterTvNetflixRed() {
        TvTokens.applyThemeKey("netflix_red")
        assertThat(TvTokens.IvyGreen).isEqualTo(Color(0xFFE50914))
        assertThat(TvTokens.Accent).isEqualTo(Color(0xFFE50914))
    }

    /**
     * 设置页主题色标识必须映射为对应主色，未知值回退奈飞红。
     */
    @Test
    fun configuredTheme_resolvesAccentPaletteAndFallsBackToNetflixRed() {
        assertThat(TvTokens.resolveAccentColor("teal")).isEqualTo(Color(0xFF14B8A6))
        assertThat(TvTokens.resolveAccentColor("violet")).isEqualTo(Color(0xFF8B5CF6))
        assertThat(TvTokens.resolveAccentColor("ice_blue")).isEqualTo(Color(0xFF3B82F6))
        assertThat(TvTokens.resolveAccentColor("emerald")).isEqualTo(Color(0xFF10B981))
        // 历史 key 兼容。
        assertThat(TvTokens.resolveAccentColor("amber")).isEqualTo(Color(0xFF8B5CF6))
        assertThat(TvTokens.resolveAccentColor("dark_gray")).isEqualTo(Color(0xFF10B981))
        assertThat(TvTokens.resolveAccentColor("unknown")).isEqualTo(Color(0xFFE50914))
        TvTokens.applyThemeKey("teal")
        assertThat(TvTokens.Accent).isEqualTo(Color(0xFF14B8A6))
        TvTokens.applyThemeKey("netflix_red")
    }

    /**
     * 默认海报占位色应使用统一的中性浅灰，避免首屏无图时出现杂色。
     */
    @Test
    fun posterPlaceholder_usesNeutralGray() {
        assertThat(TvTokens.PosterPlaceholder).isEqualTo(Color(0xFF3C424A))
    }

    /**
     * 首页首屏尺寸应对齐 Flutter TV 当前卡片和边距密度。
     */
    @Test
    fun homeDensity_matchesFlutterTvHomeLayout() {
        assertThat(TvTokens.PageHorizontalPadding).isEqualTo(50.dp)
        assertThat(TvTokens.CardSpacing).isEqualTo(16.dp)
        assertThat(TvTokens.PosterWidth).isEqualTo(158.dp)
        assertThat(TvTokens.PosterHeight).isEqualTo(288.dp)
        assertThat(TvTokens.PosterCoverHeight).isEqualTo(225.dp)
    }
}
