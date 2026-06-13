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
     * 默认选中主色应使用 Flutter TV 默认奈飞红。
     */
    @Test
    fun defaultAccent_matchesFlutterTvNetflixRed() {
        assertThat(TvTokens.IvyGreen).isEqualTo(Color(0xFFE50914))
    }

    /**
     * 首页首屏尺寸应对齐 Flutter TV 当前卡片和边距密度。
     */
    @Test
    fun homeDensity_matchesFlutterTvHomeLayout() {
        assertThat(TvTokens.PageHorizontalPadding).isEqualTo(46.dp)
        assertThat(TvTokens.CardSpacing).isEqualTo(18.dp)
        assertThat(TvTokens.PosterWidth).isEqualTo(158.dp)
        assertThat(TvTokens.PosterHeight).isEqualTo(300.dp)
        assertThat(TvTokens.PosterCoverHeight).isEqualTo(237.dp)
    }
}
