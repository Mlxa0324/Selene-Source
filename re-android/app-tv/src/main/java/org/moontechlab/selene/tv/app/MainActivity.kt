package org.moontechlab.selene.tv.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * TV 壳宿主 Activity。
 *
 * 这里只挂载 Compose 根节点，不承载业务逻辑，
 * 保持页面路由和状态都收敛在 Compose 树内部。
 */
class MainActivity : ComponentActivity() {
    /**
     * 创建页面并挂载 TV 根应用。
     *
     * @param savedInstanceState 系统提供的恢复状态。
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enterImmersiveTvMode()
        setContent {
            // 业务导航统一从 Compose 根节点进入。
            TvApp()
        }
    }

    /**
     * 进入 TV 全屏沉浸模式。
     *
     * Kotlin TV 的 2K 设计稿需要按完整屏幕高度缩放。
     * 如果保留系统状态栏，1080P 真实高度会从 1080 变成 1032，
     * 画布就会错误地按高度缩到 0.7167，导致整体内容偏小。
     */
    private fun enterImmersiveTvMode() {
        // 让 Compose 直接拿到完整窗口尺寸，避免系统栏预先吃掉画布高度。
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val insetsController = WindowInsetsControllerCompat(window, window.decorView)
        // TV 壳默认全屏展示，系统栏按需临时唤起即可。
        insetsController.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        insetsController.hide(WindowInsetsCompat.Type.systemBars())
    }
}
