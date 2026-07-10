package uk.oxiang.ivy.tv.core.design.theme

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 三维主题体系契约测试：主题色/背景色/焦点效果模式各自独立解析，互不影响。
 *
 * 对齐 Flutter `TvThemeService`：默认奈飞红 + 深蓝灰 + 放大镜模式，三组维度
 * 各自持久化 key 互相独立（真正的 DataStore 读写往返由 core-common 覆盖）。
 */
class TvThemeCatalogTest {

    @Test
    fun themePalette_defaultsToNetflixRed_notIvyGreen() {
        assertThat(TvThemePaletteCatalog.default).isEqualTo(TvThemePaletteCatalog.netflixRed)
        assertThat(TvThemePaletteCatalog.default.key).isEqualTo(TvThemePaletteKey.NETFLIX_RED)
    }

    @Test
    fun themePalette_fromKey_resolvesEachStorageKeyIndependently() {
        assertThat(TvThemePaletteCatalog.fromKey("netflix_red")).isEqualTo(TvThemePaletteCatalog.netflixRed)
        assertThat(TvThemePaletteCatalog.fromKey("ivy_green")).isEqualTo(TvThemePaletteCatalog.ivyGreen)
        assertThat(TvThemePaletteCatalog.fromKey("soft_blue")).isEqualTo(TvThemePaletteCatalog.softBlue)
    }

    @Test
    fun themePalette_fromKey_fallsBackToDefault_whenKeyUnrecognized() {
        assertThat(TvThemePaletteCatalog.fromKey("unknown_key")).isEqualTo(TvThemePaletteCatalog.default)
    }

    @Test
    fun themeBackground_defaultsToDeepBlue() {
        assertThat(TvThemeBackgroundCatalog.default).isEqualTo(TvThemeBackgroundCatalog.deepBlue)
        assertThat(TvThemeBackgroundCatalog.default.key).isEqualTo(TvThemeBackgroundKey.DEEP_BLUE)
    }

    @Test
    fun themeBackground_fromKey_resolvesIndependentlyOfPalette() {
        assertThat(TvThemeBackgroundCatalog.fromKey("deep_black")).isEqualTo(TvThemeBackgroundCatalog.deepBlack)
        assertThat(TvThemeBackgroundCatalog.fromKey("unknown")).isEqualTo(TvThemeBackgroundCatalog.default)
    }

    @Test
    fun focusEffectMode_defaultsToMagnifier_notSmoothFrame() {
        assertThat(TvFocusEffectMode.default).isEqualTo(TvFocusEffectMode.MAGNIFIER)
    }

    @Test
    fun focusEffectMode_fromKey_resolvesIndependentlyOfPaletteAndBackground() {
        assertThat(TvFocusEffectMode.fromKey("smooth_frame")).isEqualTo(TvFocusEffectMode.SMOOTH_FRAME)
        assertThat(TvFocusEffectMode.fromKey("unknown")).isEqualTo(TvFocusEffectMode.default)
    }

    @Test
    fun threeDimensions_resolveIndependently_forMixedKeyCombination() {
        // 验证三组维度混搭时互不干扰：奈飞红 + 深黑夜幕 + 平滑外框。
        val palette = TvThemePaletteCatalog.fromKey("netflix_red")
        val background = TvThemeBackgroundCatalog.fromKey("deep_black")
        val focusMode = TvFocusEffectMode.fromKey("smooth_frame")

        assertThat(palette).isEqualTo(TvThemePaletteCatalog.netflixRed)
        assertThat(background).isEqualTo(TvThemeBackgroundCatalog.deepBlack)
        assertThat(focusMode).isEqualTo(TvFocusEffectMode.SMOOTH_FRAME)
    }
}
