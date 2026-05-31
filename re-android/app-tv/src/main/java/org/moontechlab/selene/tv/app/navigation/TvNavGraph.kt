package org.moontechlab.selene.tv.app.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import org.moontechlab.selene.tv.app.TvAppContainer
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesRoute
import org.moontechlab.selene.tv.feature.history.TvHistoryRoute
import org.moontechlab.selene.tv.feature.detail.TvDetailRoute
import org.moontechlab.selene.tv.feature.home.TvHomeRoute
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryRoute
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryUiState
import org.moontechlab.selene.tv.feature.live.TvLiveRoute
import org.moontechlab.selene.tv.feature.player.TvPlayerRoute
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
    appContainer: TvAppContainer,
    modifier: Modifier = Modifier,
) {
    NavHost(
        navController = navController,
        startDestination = TvDestination.Home.route,
        modifier = modifier,
    ) {
        composable(TvDestination.Home.route) {
            val homeViewModel = remember(appContainer) {
                appContainer.createHomeViewModel()
            }
            val homeState by homeViewModel.state.collectAsState()
            LaunchedEffect(homeViewModel) {
                homeViewModel.load()
            }
            TvHomeRoute(state = homeState)
        }
        composable(TvDestination.Movie.route) {
            TvVideoLibraryRoute(state = TvVideoLibraryUiState.forCategory("movie"))
        }
        composable(TvDestination.Tv.route) {
            TvVideoLibraryRoute(state = TvVideoLibraryUiState.forCategory("tv"))
        }
        composable(TvDestination.Anime.route) {
            TvVideoLibraryRoute(state = TvVideoLibraryUiState.forCategory("anime"))
        }
        composable(TvDestination.Show.route) {
            TvVideoLibraryRoute(state = TvVideoLibraryUiState.forCategory("show"))
        }
        composable(TvDestination.Search.route) {
            TvSearchRoute(
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.History.route) {
            TvHistoryRoute(
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Favorites.route) {
            TvFavoritesRoute(
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Settings.route) {
            TvSettingsRoute()
        }
        composable(TvDestination.Live.route) {
            TvLiveRoute()
        }
        composable(
            route = TvDestination.Detail.route,
            arguments = listOf(
                navArgument(TvDestination.Detail.videoIdArg) {
                    // 详情路由参数用于首页和搜索结果传递视频身份。
                    type = NavType.StringType
                },
            ),
        ) { backStackEntry ->
            val videoId = backStackEntry.arguments
                ?.getString(TvDestination.Detail.videoIdArg)
                .orEmpty()
            TvDetailRoute(
                onPlayPressed = {
                    navController.navigate(TvDestination.Player.createRoute(videoId))
                },
            )
        }
        composable(
            route = TvDestination.Player.route,
            arguments = listOf(
                navArgument(TvDestination.Player.videoIdArg) {
                    // 播放器路由参数用于详情页传递当前视频身份。
                    type = NavType.StringType
                },
            ),
        ) {
            // 当前播放器模块先由自身 ViewModel 承载状态，路由参数契约保留给详情页接入。
            TvPlayerRoute()
        }
    }
}
