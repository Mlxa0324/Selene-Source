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
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesRoute
import org.moontechlab.selene.tv.feature.history.TvHistoryRoute
import org.moontechlab.selene.tv.feature.home.TvHomeRoute
import org.moontechlab.selene.tv.feature.live.TvLiveRoute
import org.moontechlab.selene.tv.feature.search.TvSearchRoute
import org.moontechlab.selene.tv.feature.settings.TvSettingsRoute

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
        composable(TvDestination.Home.route) {
            TvHomeRoute()
        }
        composable(TvDestination.Search.route) {
            TvSearchRoute()
        }
        composable(TvDestination.History.route) {
            TvHistoryRoute()
        }
        composable(TvDestination.Favorites.route) {
            TvFavoritesRoute()
        }
        composable(TvDestination.Settings.route) {
            TvSettingsRoute()
        }
        composable(TvDestination.Live.route) {
            TvLiveRoute()
        }
        composable(
            route = TvDestination.Player.route,
            arguments = listOf(
                navArgument(TvDestination.Player.videoIdArg) {
                    // 播放器路由先保留基础参数契约，后续再接真实视频信息。
                    type = NavType.StringType
                },
            ),
        ) { backStackEntry ->
            val videoId = backStackEntry.arguments
                ?.getString(TvDestination.Player.videoIdArg)
                .orEmpty()
            TvPlayerPlaceholder(videoId = videoId)
        }
    }
}

/**
 * 展示全屏播放器的临时占位内容。
 *
 * @param videoId 当前视频 ID。
 */
@Composable
private fun TvPlayerPlaceholder(videoId: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // 播放器主壳会在详情和全屏任务中接入，这里先保留路由参数通路。
        Text(
            text = "Player: $videoId",
            modifier = Modifier.padding(horizontal = 24.dp),
        )
    }
}
