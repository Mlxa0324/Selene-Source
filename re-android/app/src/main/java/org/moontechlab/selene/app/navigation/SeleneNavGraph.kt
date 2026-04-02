package org.moontechlab.selene.app.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavHostController
import androidx.navigation.navArgument
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.navOptions
import org.moontechlab.selene.core.datastore.AppPreferencesRepository
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository
import org.moontechlab.selene.core.download.DownloadsRepository
import org.moontechlab.selene.core.model.VideoEpisode
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.RetrofitSeleneApi
import org.moontechlab.selene.core.network.RetrofitSessionAuthApi
import org.moontechlab.selene.core.network.SharedPreferencesSessionPersistence
import org.moontechlab.selene.feature.auth.AuthRoute
import org.moontechlab.selene.feature.auth.AuthViewModel
import org.moontechlab.selene.feature.benchmark.BenchmarkRoute
import org.moontechlab.selene.feature.detail.DetailRoute
import org.moontechlab.selene.feature.detail.DetailViewModel
import org.moontechlab.selene.feature.downloads.DownloadsRoute
import org.moontechlab.selene.feature.downloads.DownloadsViewModel
import org.moontechlab.selene.feature.favorites.FavoritesRoute
import org.moontechlab.selene.feature.favorites.FavoritesViewModel
import org.moontechlab.selene.feature.home.HomeRoute
import org.moontechlab.selene.feature.home.HomeViewModel
import org.moontechlab.selene.feature.history.HistoryRoute
import org.moontechlab.selene.feature.history.HistoryViewModel
import org.moontechlab.selene.feature.live.LiveRoute
import org.moontechlab.selene.feature.live.LiveViewModel
import org.moontechlab.selene.feature.player.PlayerRoute
import org.moontechlab.selene.feature.player.PlayerViewModel
import org.moontechlab.selene.feature.search.SearchRepository
import org.moontechlab.selene.feature.search.SearchViewModel
import org.moontechlab.selene.feature.search.SearchRoute
import org.moontechlab.selene.feature.settings.SettingsRoute
import org.moontechlab.selene.feature.settings.SettingsViewModel
import org.moontechlab.selene.feature.sourcebrowser.SourceBrowserRoute
import org.moontechlab.selene.feature.sourcebrowser.SourceBrowserViewModel
import org.moontechlab.selene.feature.startup.AuthGateway
import org.moontechlab.selene.feature.startup.StartupDestination
import org.moontechlab.selene.feature.startup.StartupViewModel
import org.moontechlab.selene.feature.detail.DetailRepository

@Composable
fun SeleneNavGraph(
    navController: NavHostController,
    preferencesRepository: AppPreferencesRepository,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current.applicationContext
    val sessionStore = remember(context) {
        CookieSessionStore(
            persistence = SharedPreferencesSessionPersistence.fromContext(context),
        )
    }
    val seleneApi = remember(sessionStore) { RetrofitSeleneApi(sessionStore = sessionStore) }
    val sessionAuthApi = remember { RetrofitSessionAuthApi() }
    val favoritesRepository = remember { FavoritesRepository() }
    val historyRepository = remember { PlaybackHistoryRepository() }
    val downloadsRepository = remember { DownloadsRepository() }
    val startupViewModel = remember(sessionStore, sessionAuthApi) {
        StartupViewModel(
            sessionStore = sessionStore,
            authGateway = AuthGateway {
                val session = sessionStore.currentSession()
                if (session == null || session.isLocalMode) {
                    false
                } else {
                    sessionAuthApi.validateSession(session)
                }
            },
        )
    }
    val authViewModel = remember(sessionStore, sessionAuthApi) {
        AuthViewModel(
            sessionStore = sessionStore,
            authApi = sessionAuthApi,
        )
    }
    val searchViewModel = remember(sessionStore) {
        SearchViewModel(
            repository = SearchRepository(
                sessionStore = sessionStore,
                api = seleneApi,
            ),
        )
    }
    val detailViewModel = remember(favoritesRepository, sessionStore) {
        DetailViewModel(
            repository = DetailRepository(
                sessionStore = sessionStore,
                api = seleneApi,
            ),
            favoritesRepository = favoritesRepository,
        )
    }
    val playerViewModel = remember(favoritesRepository, historyRepository) {
        PlayerViewModel(
            favoritesRepository = favoritesRepository,
            historyRepository = historyRepository,
            downloadsRepository = downloadsRepository,
        )
    }
    val liveViewModel = remember { LiveViewModel() }
    val sourceBrowserViewModel = remember { SourceBrowserViewModel() }
    val downloadsViewModel = remember(downloadsRepository) {
        DownloadsViewModel(repository = downloadsRepository)
    }
    val favoritesViewModel = remember(favoritesRepository) {
        FavoritesViewModel(repository = favoritesRepository)
    }
    val historyViewModel = remember(historyRepository) {
        HistoryViewModel(repository = historyRepository)
    }
    val homeViewModel = remember(favoritesRepository, historyRepository) {
        HomeViewModel(
            favoritesRepository = favoritesRepository,
            historyRepository = historyRepository,
        )
    }
    val settingsViewModel = remember(preferencesRepository) {
        SettingsViewModel(repository = preferencesRepository)
    }
    val currentBackStack by navController.currentBackStackEntryAsState()
    val settingsState by settingsViewModel.uiState.collectAsState()
    val currentDestination = currentBackStack?.destination
    val visibleBottomDestinations = remember(settingsState) {
        SeleneDestination.defaultBottomNavDestinations.filter { destination ->
            when (destination) {
                SeleneDestination.Live -> settingsState.showLive
                SeleneDestination.Resource -> settingsState.showSourceBrowser
                else -> true
            }
        }
    }
    val showBottomBar = currentDestination
        ?.hierarchy
        ?.any { destination ->
            visibleBottomDestinations.any { it.route == destination.route }
        } == true

    Scaffold(
        modifier = modifier,
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    visibleBottomDestinations.forEach { destination ->
                        val selected = currentDestination
                            ?.hierarchy
                            ?.any { it.route == destination.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(destination.route, navOptions {
                                    launchSingleTop = true
                                    restoreState = true
                                    popUpTo(navController.graph.startDestinationId) {
                                        saveState = true
                                    }
                                })
                            },
                            icon = { Text(destination.label.take(1)) },
                            label = { Text(destination.label) },
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = SeleneDestination.Startup.route,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(route = SeleneDestination.Startup.route) {
                val startupState by startupViewModel.uiState.collectAsState()
                LaunchedEffect(startupState.destination) {
                    when (startupState.destination) {
                        StartupDestination.Splash -> Unit
                        StartupDestination.Home -> navController.navigate(SeleneDestination.Home.route) {
                            popUpTo(SeleneDestination.Startup.route) { inclusive = true }
                        }
                        StartupDestination.Auth -> navController.navigate(SeleneDestination.Auth.route) {
                            popUpTo(SeleneDestination.Startup.route) { inclusive = true }
                        }
                    }
                }
                Text(text = "正在启动 Selene...")
            }
            composable(route = SeleneDestination.Auth.route) {
                val authState by authViewModel.uiState.collectAsState()
                LaunchedEffect(authState.loginCompleted) {
                    if (authState.loginCompleted) {
                        authViewModel.consumeLoginCompleted()
                        navController.navigate(SeleneDestination.Home.route) {
                            popUpTo(SeleneDestination.Auth.route) { inclusive = true }
                        }
                    }
                }
                AuthRoute(
                    state = authState,
                    onLocalModeChanged = authViewModel::updateLocalMode,
                    onServerUrlChanged = authViewModel::updateServerUrl,
                    onUsernameChanged = authViewModel::updateUsername,
                    onPasswordChanged = authViewModel::updatePassword,
                    onSubscriptionUrlChanged = authViewModel::updateSubscriptionUrl,
                    onSubmit = authViewModel::submit,
                )
            }
            composable(route = SeleneDestination.Home.route) {
                val state by homeViewModel.uiState.collectAsState()
                HomeRoute(
                    state = state,
                    onOpenSearch = { navController.navigate(SeleneDestination.Search.route) },
                    onOpenProfile = { navController.navigate(SeleneDestination.Profile.route) },
                    onOpenFavorite = { item ->
                        navController.navigate(
                            SeleneDestination.Detail.createRoute(
                                videoId = item.videoId,
                                sourceKey = item.sourceKey,
                            ),
                        )
                    },
                    onResumeHistory = { item ->
                        navController.navigate(
                            SeleneDestination.Player.createRoute(
                                videoId = item.videoId,
                                title = item.title,
                                sourceKey = item.sourceKey,
                                sourceName = item.sourceName,
                                episodeTitle = item.episodeTitle,
                                playUrl = item.playUrl,
                            ),
                        )
                    },
                )
            }
            composable(route = SeleneDestination.Search.route) {
                val state by searchViewModel.uiState.collectAsState()
                SearchRoute(
                    state = state,
                    onQueryChanged = searchViewModel::updateQuery,
                    onSearch = searchViewModel::search,
                    onResultClick = { result ->
                        navController.navigate(
                            SeleneDestination.Detail.createRoute(
                                videoId = result.id,
                                sourceKey = result.sourceKey,
                            ),
                        )
                    },
                )
            }
            composable(route = SeleneDestination.Live.route) {
                val state by liveViewModel.uiState.collectAsState()
                LiveRoute(
                    state = state,
                    onGroupSelected = liveViewModel::selectGroup,
                    onPlayChannel = { channel ->
                        navController.navigate(
                            SeleneDestination.Player.createRoute(
                                videoId = "live:${channel.name}",
                                title = channel.name,
                                sourceKey = "live",
                                sourceName = "直播",
                                episodeTitle = "直播",
                                playUrl = channel.url,
                            ),
                        )
                    },
                )
            }
            composable(route = SeleneDestination.Resource.route) {
                val state by sourceBrowserViewModel.uiState.collectAsState()
                SourceBrowserRoute(
                    state = state,
                    onSourceSelected = sourceBrowserViewModel::selectSource,
                    onEntryClick = { entry ->
                        navController.navigate(
                            SeleneDestination.Detail.createRoute(
                                videoId = entry.id,
                                sourceKey = entry.sourceKey,
                            ),
                        )
                    },
                )
            }
            composable(route = SeleneDestination.Download.route) {
                val state by downloadsViewModel.uiState.collectAsState()
                DownloadsRoute(
                    state = state,
                    onToggleTask = downloadsViewModel::toggleTask,
                    onRemoveTask = downloadsViewModel::removeTask,
                )
            }
            composable(route = SeleneDestination.Profile.route) {
                SettingsRoute(
                    state = settingsState,
                    onToggleDarkTheme = settingsViewModel::toggleDarkTheme,
                    onToggleLocalMode = settingsViewModel::toggleLocalMode,
                    onToggleLiveVisibility = settingsViewModel::toggleLiveVisibility,
                    onToggleSourceBrowserVisibility = settingsViewModel::toggleSourceBrowserVisibility,
                    onOpenFavorites = { navController.navigate(SeleneDestination.Favorites.route) },
                    onOpenHistory = { navController.navigate(SeleneDestination.History.route) },
                )
            }
            composable(route = SeleneDestination.Benchmark.route) { BenchmarkRoute() }
            composable(route = SeleneDestination.Favorites.route) {
                val state by favoritesViewModel.uiState.collectAsState()
                FavoritesRoute(
                    state = state,
                    onOpenDetail = { item ->
                        navController.navigate(
                            SeleneDestination.Detail.createRoute(
                                videoId = item.videoId,
                                sourceKey = item.sourceKey,
                            ),
                        )
                    },
                    onToggleFavorite = favoritesViewModel::toggleFavorite,
                )
            }
            composable(route = SeleneDestination.History.route) {
                val state by historyViewModel.uiState.collectAsState()
                HistoryRoute(
                    state = state,
                    onResumePlayback = { item ->
                        navController.navigate(
                            SeleneDestination.Player.createRoute(
                                videoId = item.videoId,
                                title = item.title,
                                sourceKey = item.sourceKey,
                                sourceName = item.sourceName,
                                episodeTitle = item.episodeTitle,
                                playUrl = item.playUrl,
                            ),
                        )
                    },
                    onRemove = historyViewModel::remove,
                )
            }
            composable(
                route = SeleneDestination.Detail.route,
                arguments = listOf(
                    navArgument("videoId") { type = NavType.StringType },
                    navArgument("sourceKey") {
                        type = NavType.StringType
                        defaultValue = ""
                    },
                ),
            ) { backStackEntry ->
                val state by detailViewModel.uiState.collectAsState()
                val videoId = backStackEntry.arguments?.getString("videoId").orEmpty()
                val sourceKey = backStackEntry.arguments?.getString("sourceKey").orEmpty()
                LaunchedEffect(videoId, sourceKey) {
                    detailViewModel.load(
                        id = videoId,
                        sourceKey = sourceKey,
                    )
                }
                DetailRoute(
                    state = state,
                    onPlayEpisode = { videoId, title, sourceKey, sourceName, episode ->
                        navController.navigate(
                            SeleneDestination.Player.createRoute(
                                videoId = videoId,
                                title = title,
                                sourceKey = sourceKey,
                                sourceName = sourceName,
                                episodeTitle = episode.title,
                                playUrl = episode.playUrl,
                            ),
                        )
                    },
                    onToggleFavorite = detailViewModel::toggleFavorite,
                )
            }
            composable(
                route = SeleneDestination.Player.route,
                arguments = listOf(
                    navArgument("videoId") { type = NavType.StringType },
                    navArgument("title") { type = NavType.StringType },
                    navArgument("sourceKey") { type = NavType.StringType },
                    navArgument("sourceName") { type = NavType.StringType },
                    navArgument("episodeTitle") { type = NavType.StringType },
                    navArgument("playUrl") { type = NavType.StringType },
                ),
            ) { backStackEntry ->
                val state by playerViewModel.uiState.collectAsState()
                val videoId = backStackEntry.arguments?.getString("videoId").orEmpty()
                val title = backStackEntry.arguments?.getString("title").orEmpty()
                val sourceKey = backStackEntry.arguments?.getString("sourceKey").orEmpty()
                val sourceName = backStackEntry.arguments?.getString("sourceName").orEmpty()
                val episodeTitle = backStackEntry.arguments?.getString("episodeTitle").orEmpty()
                val playUrl = backStackEntry.arguments?.getString("playUrl").orEmpty()
                LaunchedEffect(videoId, title, sourceKey, sourceName, episodeTitle, playUrl) {
                    playerViewModel.loadEpisode(
                        videoId = videoId,
                        title = title,
                        sourceKey = sourceKey,
                        sourceName = sourceName,
                        episode = VideoEpisode(
                            index = 0,
                            title = episodeTitle,
                            playUrl = playUrl,
                        ),
                    )
                }
                PlayerRoute(
                    state = state,
                    onPlay = playerViewModel::play,
                    onPause = playerViewModel::pause,
                    onToggleFavorite = playerViewModel::toggleFavorite,
                    onAddDownload = playerViewModel::addDownload,
                )
            }
        }
    }
}
