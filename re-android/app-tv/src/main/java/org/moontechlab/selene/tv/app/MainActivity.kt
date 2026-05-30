package org.moontechlab.selene.tv.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

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
        setContent {
            // 业务导航统一从 Compose 根节点进入。
            TvApp()
        }
    }
}
