package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV Activity 的全屏窗口契约。
 */
class MainActivityContractTest {
    /**
     * TV 根 Activity 必须隐藏系统栏，避免 1080P 画布高度被状态栏吃掉后缩放错误。
     */
    @Test
    fun main_activity_enters_immersive_tv_mode_before_set_content() {
        val source = File("src/main/java/org/moontechlab/selene/tv/app/MainActivity.kt").readText()

        assertThat(source).contains("enterImmersiveTvMode()")
        assertThat(source).contains("WindowCompat.setDecorFitsSystemWindows(window, false)")
        assertThat(source).contains("WindowInsetsCompat.Type.systemBars()")
        assertThat(source).contains("WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE")
        assertThat(source.indexOf("enterImmersiveTvMode()")).isLessThan(source.indexOf("setContent {"))
    }
}
