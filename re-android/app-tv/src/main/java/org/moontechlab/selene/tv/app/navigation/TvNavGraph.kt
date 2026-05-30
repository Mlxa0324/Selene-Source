package org.moontechlab.selene.tv.app.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument

/**
 * 搭建 TV 根导航图。
 *
 * @param navController 全局导航控制器。
 * @param modifier 页面内容承载的外层修饰器。
 */
@Composable
fun TvNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier,
) {
    NavHost(
        navController = navController,
        startDestination = TvDestination.Home.route,
        modifier = modifier,
    ) {
        // 顶层页面先使用最小占位壳，后续功能模块逐步替换。
        composable(TvDestination.Home.route) {
            TvPlaceholderScreen(label = "Home")
        }
        composable(TvDestination.Search.route) {
            TvPlaceholderScreen(label = "Search")
        }
        composable(TvDestination.History.route) {
            TvPlaceholderScreen(label = "History")
        }
        composable(TvDestination.Favorites.route) {
            TvPlaceholderScreen(label = "Favorites")
        }
        composable(TvDestination.Settings.route) {
            TvPlaceholderScreen(label = "Settings")
        }
        composable(TvDestination.Live.route) {
            TvPlaceholderScreen(label = "Live")
        }
        composable(
            route = TvDestination.Player.route,
            arguments = listOf(
                navArgument("videoId") {
                    // 播放器路由先保留基础参数契约，后续再接真实视频信息。
                    type = NavType.StringType
                },
            ),
        ) { backStackEntry ->
            val videoId = backStackEntry.arguments?.getString("videoId").orEmpty()
            TvPlaceholderScreen(label = "Player: $videoId")
        }
    }
}

/**
 * 展示当前导航节点的最小占位内容。
 *
 * @param label 页面中心展示的占位标题。
 */
@Composable
private fun TvPlaceholderScreen(label: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = 24.dp),
        )
    }
}
