package org.moontechlab.selene.tv.app.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.compose.ui.platform.LocalContext
import coil.Coil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.app.TvAppContainer
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSurface
import org.moontechlab.selene.tv.feature.favorites.TvFavoritesRoute
import org.moontechlab.selene.tv.feature.history.TvHistoryRoute
import org.moontechlab.selene.tv.feature.detail.TvDetailRoute
import org.moontechlab.selene.tv.feature.home.TvHomeSectionMoreTarget
import org.moontechlab.selene.tv.feature.home.TvHomeRoute
import org.moontechlab.selene.tv.feature.home.TvVideoLibraryRoute
import org.moontechlab.selene.tv.feature.live.TvLiveRoute
import org.moontechlab.selene.tv.feature.player.TvPlayerRoute
import org.moontechlab.selene.tv.feature.search.TvSearchRoute
import org.moontechlab.selene.tv.feature.settings.TvDanmakuMatchRoute
import org.moontechlab.selene.tv.feature.settings.TvSettingsRoute

/**
 * 搭建 TV 根导航图。
 *
 * @param navController 全局导航控制器。
 * @param contentFocusRequester 当前内容区入口焦点请求器。
 * @param modifier 页面内容承载的外层修饰器。
 */
@Composable
fun TvNavGraph(
    navController: NavHostController,
    appContainer: TvAppContainer,
    contentFocusRequester: FocusRequester? = null,
    showCategoryFilter: Boolean = false,
    onServerConfigSaved: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val playbackRequestStore = remember { TvPlaybackRequestStore() }
    var danmakuMatchPlaybackRequest by remember {
        mutableStateOf<org.moontechlab.selene.tv.core.player.api.PlaybackRequest?>(null)
    }

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
            val homeScope = rememberCoroutineScope()
            LaunchedEffect(homeViewModel) {
                homeViewModel.load()
            }
            TvHomeRoute(
                state = homeState,
                contentFocusRequester = contentFocusRequester,
                onRetry = {
                    // 错误态按钮只发起新一轮首页加载，不直接处理网络细节。
                    homeScope.launch {
                        homeViewModel.load()
                    }
                },
                onVideoClick = { videoId ->
                    // 首页所有视频卡片统一进入原生 TV 详情页。
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
                onSectionMoreClick = { target ->
                    // 首页分区查看更多沿用既有顶层页面，避免额外引入中转页。
                    navController.navigate(target.toDestination().route)
                },
            )
        }
        composable(TvDestination.Movie.route) {
            TvRemoteVideoLibraryRoute(
                categoryKey = "movie",
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
                showFilter = showCategoryFilter,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Tv.route) {
            TvRemoteVideoLibraryRoute(
                categoryKey = "tv",
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
                showFilter = showCategoryFilter,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Anime.route) {
            TvRemoteVideoLibraryRoute(
                categoryKey = "anime",
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
                showFilter = showCategoryFilter,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Show.route) {
            TvRemoteVideoLibraryRoute(
                categoryKey = "show",
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
                showFilter = showCategoryFilter,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Search.route) {
            val searchViewModel = remember(appContainer) {
                appContainer.createSearchViewModel()
            }
            val searchState by searchViewModel.state.collectAsState()
            val searchScope = rememberCoroutineScope()

            // 进入搜索页时加载历史
            LaunchedEffect(Unit) {
                searchViewModel.loadHistory()
            }

            TvSearchRoute(
                state = searchState,
                onAppendChar = { char -> searchViewModel.appendChar(char) },
                onDeleteLastChar = { searchViewModel.deleteLastChar() },
                onClearQuery = { searchViewModel.clearQuery() },
                onSearchCurrentQuery = {
                    searchViewModel.submitQuery(searchState.query)
                },
                onQueryClick = { query -> searchViewModel.setQuery(query) },
                onSearchHistoryClick = { query ->
                    searchViewModel.submitQuery(query)
                },
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
                onBack = {
                    navController.popBackStack()
                },
            )
        }
        composable(TvDestination.History.route) {
            val historyViewModel = remember(appContainer) {
                appContainer.createHistoryViewModel()
            }
            val historyState by historyViewModel.state.collectAsState()
            LaunchedEffect(historyViewModel) {
                historyViewModel.load()
            }
            TvHistoryRoute(
                state = historyState,
                contentFocusRequester = contentFocusRequester,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Favorites.route) {
            val favoritesViewModel = remember(appContainer) {
                appContainer.createFavoritesViewModel()
            }
            val favoritesState by favoritesViewModel.state.collectAsState()
            LaunchedEffect(favoritesViewModel) {
                favoritesViewModel.load()
            }
            TvFavoritesRoute(
                state = favoritesState,
                contentFocusRequester = contentFocusRequester,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Settings.route) {
            val context = LocalContext.current
            val settingsViewModel = remember(appContainer, context) {
                appContainer.createSettingsViewModel(
                    loadCacheSize = {
                        withContext(Dispatchers.IO) {
                            val diskSize = Coil.imageLoader(context).diskCache?.size ?: 0L
                            formatBytes(diskSize)
                        }
                    },
                    clearCache = {
                        withContext(Dispatchers.IO) {
                            Coil.imageLoader(context).diskCache?.clear()
                        }
                        appContainer.clearDoubanCache()
                    },
                )
            }
            val settingsState by settingsViewModel.state.collectAsState()
            val settingsScope = rememberCoroutineScope()
            TvSettingsRoute(
                state = settingsState,
                contentFocusRequester = contentFocusRequester,
                onServerUrlChange = settingsViewModel::updateServerUrl,
                onAccountChange = settingsViewModel::updateAccount,
                onPasswordChange = settingsViewModel::updatePassword,
                onServerConfigSave = {
                    settingsScope.launch {
                        settingsViewModel.performSaveServerConfig()
                        onServerConfigSaved()
                    }
                },
                onThemeSelected = { key ->
                    settingsViewModel.updateThemeKey(key)
                    settingsScope.launch { settingsViewModel.performSaveTheme() }
                },
                onBackgroundSelected = { key ->
                    settingsViewModel.updateBackgroundKey(key)
                    settingsScope.launch { settingsViewModel.performSaveBackground() }
                },
                onFocusEffectSelected = { key ->
                    settingsViewModel.updateFocusEffectKey(key)
                    settingsScope.launch { settingsViewModel.performSaveFocusEffect() }
                },
                onImageSourceSelected = { key ->
                    settingsViewModel.updateImageSourceKey(key)
                    settingsScope.launch { settingsViewModel.performSaveImageSource() }
                },
                onPlayerKernelSelected = { key ->
                    settingsViewModel.updatePlayerKernelKey(key)
                    settingsScope.launch { settingsViewModel.performSavePlayerKernel() }
                },
                onAdFilterToggle = { enabled ->
                    settingsViewModel.updateAdFilterEnabled(enabled)
                    settingsScope.launch { settingsViewModel.performSaveAdFilter() }
                },
                onDanmakuApiChange = settingsViewModel::updateDanmakuApi,
                onDanmakuEnabledToggle = { enabled ->
                    settingsViewModel.updateDanmakuEnabled(enabled)
                },
                onDanmakuOpacityChange = settingsViewModel::updateDanmakuOpacity,
                onDanmakuFontScaleChange = settingsViewModel::updateDanmakuFontScale,
                onDanmakuDisplayAreaChange = settingsViewModel::updateDanmakuDisplayArea,
                onDanmakuPreventOverlapToggle = settingsViewModel::updateDanmakuPreventOverlap,
                onDanmakuSyncSpeedToggle = settingsViewModel::updateDanmakuSyncVideoSpeed,
                onDanmakuSave = {
                    settingsScope.launch { settingsViewModel.performSaveDanmaku() }
                },
                onDanmakuMatchClick = {
                    danmakuMatchPlaybackRequest = null
                    navController.navigate(TvDestination.DanmakuMatch.createRoute(""))
                },
                onCacheClear = {
                    settingsScope.launch { settingsViewModel.performClearCache() }
                },
                onNoticeDismiss = settingsViewModel::dismissNotice,
            )
        }
        composable(
            route = TvDestination.DanmakuMatch.route,
            arguments = listOf(
                navArgument(TvDestination.DanmakuMatch.queryArg) {
                    // 默认搜索词来自播放器片名，也允许设置页传入空字符串。
                    type = NavType.StringType
                },
            ),
        ) { backStackEntry ->
            val query = backStackEntry.arguments
                ?.getString(TvDestination.DanmakuMatch.queryArg)
                .orEmpty()
            val initialQuery = TvDestination.DanmakuMatch.parseQuery(query)
            val danmakuMatchViewModel = remember(initialQuery, appContainer) {
                appContainer.createDanmakuMatchViewModel(initialQuery = initialQuery)
            }
            val danmakuMatchState by danmakuMatchViewModel.state.collectAsState()
            val danmakuMatchScope = rememberCoroutineScope()
            TvDanmakuMatchRoute(
                state = danmakuMatchState,
                contentFocusRequester = contentFocusRequester,
                onDeleteLastClick = danmakuMatchViewModel::deleteLastCharacter,
                onClearClick = danmakuMatchViewModel::clearQuery,
                onRestoreClick = danmakuMatchViewModel::restoreInitialQuery,
                onSearchClick = {
                    danmakuMatchScope.launch {
                        danmakuMatchViewModel.submitSearch()
                    }
                },
                onEpisodeSelected = { anime, episode, episodeIndex ->
                    val playbackRequest = danmakuMatchPlaybackRequest
                    if (playbackRequest != null) {
                        danmakuMatchScope.launch {
                            // 选择候选后保存当前集和后续集映射，再回到播放器。
                            appContainer.saveDanmakuManualSelection(
                                playbackRequest = playbackRequest,
                                anime = anime,
                                selectedEpisode = episode,
                                selectedEpisodeOffset = episodeIndex,
                                searchKeyword = danmakuMatchState.query,
                            )
                            navController.popBackStack()
                        }
                    }
                },
                onBackClick = {
                    navController.popBackStack()
                },
            )
        }
        composable(TvDestination.Live.route) {
            TvLiveRoute(contentFocusRequester = contentFocusRequester)
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
            val videoKey = backStackEntry.arguments
                ?.getString(TvDestination.Detail.videoIdArg)
                .orEmpty()
            val source = TvDestination.Detail.parseSource(videoKey)
            val videoId = TvDestination.Detail.parseVideoId(videoKey)
            val videoTitle = TvDestination.Detail.parseTitle(videoKey)
            val detailPlayerSession = remember(source, videoId, appContainer) {
                appContainer.createWebViewPlayerSession()
            }
            val detailViewModel = remember(source, videoId, videoTitle, appContainer) {
                appContainer.createDetailViewModel(source, videoTitle, playerEngine = detailPlayerSession.engine)
            }
            val detailState by detailViewModel.state.collectAsState()
            LaunchedEffect(source, videoId, detailViewModel) {
                detailViewModel.load(videoId)
            }
            TvDetailRoute(
                state = detailState,
                onSourceSelected = { sourceId -> detailViewModel.selectSource(sourceId) },
                onEpisodeSelected = { episodeId -> detailViewModel.selectEpisode(episodeId) },
                onPlayPressed = {
                    detailState.playbackRequest?.let { request ->
                        val sources = detailState.detail?.sources.orEmpty().map {
                            org.moontechlab.selene.tv.core.player.api.PlaybackSource(it.id, it.name)
                        }
                        val episodes = detailState.currentSource?.episodes.orEmpty().map {
                            org.moontechlab.selene.tv.core.player.api.PlaybackEpisode(it.id, it.title)
                        }
                        val requestId = playbackRequestStore.save(request, sources, episodes)
                        navController.navigate(TvDestination.Player.createRoute(requestId))
                    }
                },
                onFavoriteToggle = { detailViewModel.toggleFavorite() },
                onResumeFromRecord = { detailViewModel.resumeFromRecord() },
                onDismissResume = { detailViewModel.dismissResumePrompt() },
                onEpisodeGroupSelected = { group -> detailViewModel.selectEpisodeGroup(group) },
                onHistoryClick = { navController.navigate(TvDestination.History.route) },
                onExitClick = { navController.popBackStack() },
                playerSurface = {
                    WebViewPlayerSurface(
                        playbackRequest = detailState.playbackRequest,
                        modifier = Modifier.fillMaxSize(),
                        commandBus = detailPlayerSession.commandBus,
                        onPlaybackEvent = detailPlayerSession.engine::updateFromWebView,
                    )
                },
            )
        }
        composable(
            route = TvDestination.Player.route,
            arguments = listOf(
                navArgument(TvDestination.Player.requestIdArg) {
                    // 播放器路由参数只保存短 ID，完整播放请求由暂存器提供。
                    type = NavType.StringType
                },
            ),
        ) { backStackEntry ->
            val requestId = backStackEntry.arguments
                ?.getString(TvDestination.Player.requestIdArg)
                .orEmpty()
            val playbackContext = remember(requestId) {
                playbackRequestStore.getContext(requestId)
            }
            val playbackRequest = playbackContext?.request
            val webViewPlayerSession = remember(requestId, appContainer) {
                appContainer.createWebViewPlayerSession()
            }
            val playerViewModel = remember(requestId, playbackRequest, appContainer) {
                appContainer.createPlayerViewModel(
                    playbackRequest = playbackRequest,
                    playerEngine = webViewPlayerSession.engine,
                    availableSources = playbackContext?.sources.orEmpty(),
                    allEpisodes = playbackContext?.episodes.orEmpty(),
                )
            }
            TvPlayerRoute(
                playbackRequest = playbackRequest,
                viewModel = playerViewModel,
                playerSurface = { state ->
                    WebViewPlayerSurface(
                        playbackRequest = state.playbackRequest,
                        modifier = Modifier.fillMaxSize(),
                        commandBus = webViewPlayerSession.commandBus,
                        onPlaybackEvent = webViewPlayerSession.engine::updateFromWebView,
                    )
                },
                onDanmakuMatchRequested = { query ->
                    danmakuMatchPlaybackRequest = playbackRequest
                    navController.navigate(TvDestination.DanmakuMatch.createRoute(query))
                },
                onExitRequested = {
                    // 播放器自身只发出退出意图，实际退栈由应用导航图负责。
                    navController.popBackStack()
                },
            )
        }
    }
}

/**
 * 将首页更多入口目标映射为 TV 顶层导航路由。
 *
 * @return 对应的顶层导航目标。
 */
internal fun TvHomeSectionMoreTarget.toDestination(): TvDestination {
    return when (this) {
        TvHomeSectionMoreTarget.History -> TvDestination.History
        TvHomeSectionMoreTarget.Movie -> TvDestination.Movie
        TvHomeSectionMoreTarget.Tv -> TvDestination.Tv
        TvHomeSectionMoreTarget.Anime -> TvDestination.Anime
        TvHomeSectionMoreTarget.Show -> TvDestination.Show
        TvHomeSectionMoreTarget.Favorites -> TvDestination.Favorites
    }
}

/**
 * 远端分类视频库路由。
 *
 * @param categoryKey 分类标识。
 * @param appContainer 应用依赖容器。
 */
@Composable
private fun TvRemoteVideoLibraryRoute(
    categoryKey: String,
    appContainer: TvAppContainer,
    contentFocusRequester: FocusRequester? = null,
    showFilter: Boolean = false,
    onVideoClick: (String) -> Unit = {},
) {
    val viewModel = remember(categoryKey, appContainer) {
        appContainer.createVideoLibraryViewModel(categoryKey)
    }
    val state by viewModel.state.collectAsState()
    val categoryScope = rememberCoroutineScope()
    LaunchedEffect(categoryKey, appContainer) {
        viewModel.load()
    }
    TvVideoLibraryRoute(
        state = state,
        contentFocusRequester = contentFocusRequester,
        showFilter = showFilter,
        onVideoClick = onVideoClick,
        onFilterOptionSelected = { filterKey, optionKey ->
            viewModel.applyFilter(filterKey, optionKey)
            categoryScope.launch { viewModel.load() }
        },
        onFilterOptionFocused = { filterKey, optionKey ->
            viewModel.applyFilter(filterKey, optionKey)
        },
        onApproachingEnd = {
            categoryScope.launch { viewModel.loadNextPage() }
        },
    )
}

/**
 * 格式化字节数为人类可读文案。
 */
private fun formatBytes(bytes: Long): String {
    if (bytes <= 0) return "0 MB"
    val mb = bytes / (1024.0 * 1024.0)
    return if (mb < 1.0) {
        "%.1f KB".format(bytes / 1024.0)
    } else if (mb < 1024.0) {
        "%.1f MB".format(mb)
    } else {
        "%.1f GB".format(mb / 1024.0)
    }
}
