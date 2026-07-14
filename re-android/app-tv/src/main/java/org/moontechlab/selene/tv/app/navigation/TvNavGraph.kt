package org.moontechlab.selene.tv.app.navigation

import android.util.Log
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import coil.Coil
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.app.TvAppContainer
import org.moontechlab.selene.tv.app.TvSharedPlayerHost
import org.moontechlab.selene.tv.app.TvSharedPlayerSession
import org.moontechlab.selene.tv.core.player.exo.ExoPlayerEngine
import org.moontechlab.selene.tv.core.player.exo.ExoPlayerSurface
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
    val context = LocalContext.current
    val playbackRequestStore = remember { TvPlaybackRequestStore() }
    var danmakuMatchPlaybackRequest by remember {
        mutableStateOf<org.moontechlab.selene.tv.core.player.api.PlaybackRequest?>(null)
    }
    val sharedPlayerHost = remember(appContainer, context) {
        TvSharedPlayerHost(
            createExoSession = {
                val engine = appContainer.createExoPlayerEngine(context) as ExoPlayerEngine
                TvSharedPlayerSession(
                    kernel = "exo",
                    playerEngine = engine,
                    exoEngine = engine,
                )
            },
            createWebViewSession = {
                val session = appContainer.createWebViewPlayerSession()
                TvSharedPlayerSession(
                    kernel = "webview",
                    playerEngine = session.engine,
                    webViewSession = session,
                )
            },
        )
    }
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStackEntry?.destination?.route.orEmpty()

    LaunchedEffect(currentRoute) {
        if (currentRoute.isNotBlank() && currentRoute !in playbackFlowRoutes) {
            // 只有离开整条播放流后才统一释放共享播放器资源，详情/全屏/弹幕匹配内部切换不释放。
            sharedPlayerHost.clearPlaybackFlow()
        }
    }

    NavHost(
        navController = navController,
        startDestination = TvDestination.Home.route,
        modifier = modifier,
    ) {
        composable(TvDestination.Home.route) { backStackEntry ->
            val homeViewModel = remember(appContainer) {
                appContainer.createHomeViewModel()
            }
            val homeState by homeViewModel.state.collectAsState()
            val homeScope = rememberCoroutineScope()
            LaunchedEffect(homeViewModel) {
                homeViewModel.load()
            }
            LaunchedEffect(backStackEntry, homeViewModel) {
                backStackEntry.savedStateHandle
                    .getStateFlow(HOME_CONTINUE_WATCHING_REFRESH_KEY, false)
                    .collect { shouldRefresh ->
                        if (!shouldRefresh) {
                            return@collect
                        }
                        homeViewModel.refreshContinueWatching()
                        backStackEntry.savedStateHandle[HOME_CONTINUE_WATCHING_REFRESH_KEY] = false
                    }
            }
            // 从详情/全屏返回：进度写库成功会置脏。
            // ON_RESUME 立即刷一次；另轮询兜底（写库比返回慢时也能刷到最新进度）。
            val homeLifecycleOwner = LocalLifecycleOwner.current
            DisposableEffect(homeLifecycleOwner, homeViewModel, appContainer) {
                val observer = LifecycleEventObserver { _, event ->
                    if (event != Lifecycle.Event.ON_RESUME) {
                        return@LifecycleEventObserver
                    }
                    if (!appContainer.consumeContinueWatchingDirty()) {
                        return@LifecycleEventObserver
                    }
                    homeScope.launch {
                        homeViewModel.refreshContinueWatching()
                    }
                }
                homeLifecycleOwner.lifecycle.addObserver(observer)
                onDispose {
                    homeLifecycleOwner.lifecycle.removeObserver(observer)
                }
            }
            LaunchedEffect(homeViewModel, appContainer) {
                while (true) {
                    delay(1_500)
                    if (appContainer.consumeContinueWatchingDirty()) {
                        homeViewModel.refreshContinueWatching()
                    }
                }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
                },
            )
        }
        composable(TvDestination.Search.route) {
            val searchViewModel = remember(appContainer) {
                appContainer.createSearchViewModel()
            }
            val searchState by searchViewModel.state.collectAsState()
            // 进入搜索页时加载历史/推荐
            LaunchedEffect(Unit) {
                searchViewModel.bootstrap()
            }

            TvSearchRoute(
                state = searchState,
                onAppendChar = { char -> searchViewModel.appendChar(char) },
                onDeleteLastChar = { searchViewModel.deleteLastChar() },
                onClearQuery = { searchViewModel.clearQuery() },
                onSearchCurrentQuery = { searchViewModel.submitCurrentQuery() },
                onHotQueryClick = { query -> searchViewModel.setQuery(query) },
                onSearchHistoryClick = { query -> searchViewModel.submitHistoryQuery(query) },
                onSuggestionClick = { query -> searchViewModel.submitSuggestionQuery(query) },
                onClearHistory = { searchViewModel.clearHistory() },
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
                },
                onBack = { navController.popBackStack() },
                onConsumeBack = { searchViewModel.handleBack() },
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                    navController.navigate(TvDestination.Detail.createRoute(videoId)) {
                        // 全局单详情：新开详情前清掉旧详情，避免返回栈堆积。
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
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
                // updateAdFilterEnabled 内部已立即持久化，避免双重保存。
                onAdFilterToggle = settingsViewModel::updateAdFilterEnabled,
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
                onRegenerateQr = settingsViewModel::regenerateQrCode,
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
            var playerKernel by remember { mutableStateOf(appContainer.peekPlayerKernel()) }
            LaunchedEffect(Unit) {
                playerKernel = appContainer.getPlayerKernel()
            }
            LaunchedEffect(playerKernel, source, videoId) {
                // 详情页每次进入或切换内核时都打印一次真实选核结果，方便 adb 直接判定当前是否真走 Exo。
                Log.i(
                    TV_NAV_LOG_TAG,
                    "detailRoute kernel=$playerKernel source=$source videoId=$videoId",
                )
            }
            val sharedPlayerSession = remember(playerKernel, sharedPlayerHost) {
                sharedPlayerHost.openOrReuseSession(playerKernel)
            }
            val detailSessionKey = remember(source, videoId, playerKernel) {
                listOf(source, videoId, playerKernel).joinToString(separator = "::")
            }
            val detailViewModel = remember(
                detailSessionKey,
                source,
                videoTitle,
                appContainer,
                sharedPlayerHost,
                sharedPlayerSession,
            ) {
                sharedPlayerHost.openOrReuseDetailViewModel(detailSessionKey) {
                    appContainer.createDetailViewModel(
                        source = source,
                        videoTitle = videoTitle,
                        playerEngine = sharedPlayerSession.playerEngine,
                    )
                }
            }
            val detailState by detailViewModel.state.collectAsState()
            // 离开详情（系统返回/销毁）时用最新快照落库，不依赖“随便看看”按钮。
            val detailProgressSnapshot = remember {
                DetailPlaybackProgressSnapshot()
            }
            detailProgressSnapshot.request = detailState.playbackRequest
            detailProgressSnapshot.positionMs = detailState.previewPositionMs
                .takeIf { positionMs -> positionMs > 0L }
                ?: detailState.playbackRequest?.startPositionMs
                ?: 0L
            detailProgressSnapshot.durationMs = detailState.previewDurationMs
            val flushDetailProgress: () -> Unit = {
                appContainer.persistPlaybackProgressAsync(
                    request = detailProgressSnapshot.request,
                    positionMs = detailProgressSnapshot.positionMs,
                    durationMs = detailProgressSnapshot.durationMs,
                )
            }
            BackHandler {
                flushDetailProgress()
                navController.popBackStack()
            }
            DisposableEffect(detailSessionKey) {
                onDispose {
                    // 任意离开详情（含返回首页、替换路由）都落一次当前进度。
                    flushDetailProgress()
                }
            }
            LaunchedEffect(source, videoId, detailViewModel) {
                detailViewModel.ensureLoaded(videoId)
            }
            LaunchedEffect(detailState.playbackRequest, detailState.currentSourceId, detailState.detail) {
                detailState.playbackRequest?.let { request ->
                    val sources = detailState.detail?.sources.orEmpty().map { sourceItem ->
                        org.moontechlab.selene.tv.core.player.api.PlaybackSource(sourceItem.id, sourceItem.name)
                    }
                    val episodes = detailState.currentSource?.episodes.orEmpty().map { episode ->
                        org.moontechlab.selene.tv.core.player.api.PlaybackEpisode(episode.id, episode.title, episode.url)
                    }
                    sharedPlayerHost.updatePlaybackContext(
                        request = request,
                        sources = sources,
                        episodes = episodes,
                    )
                }
            }
            TvDetailRoute(
                state = detailState,
                backgroundKey = appContainer.peekBackgroundKey(),
                onSourceSelected = { sourceId -> detailViewModel.selectSource(sourceId) },
                onEpisodeSelected = { episodeId -> detailViewModel.selectEpisode(episodeId) },
                onPlayPressed = {
                    // 进全屏前先落库，避免只在全屏看很久、详情侧仍是旧点。
                    flushDetailProgress()
                    detailState.playbackRequest?.let { request ->
                        val sources = detailState.detail?.sources.orEmpty().map {
                            org.moontechlab.selene.tv.core.player.api.PlaybackSource(it.id, it.name)
                        }
                        val episodes = detailState.currentSource?.episodes.orEmpty().map {
                            org.moontechlab.selene.tv.core.player.api.PlaybackEpisode(it.id, it.title, it.url)
                        }
                        sharedPlayerHost.updatePlaybackContext(
                            request = request,
                            sources = sources,
                            episodes = episodes,
                        )
                        val requestId = playbackRequestStore.save(request, sources, episodes)
                        navController.navigate(TvDestination.Player.createRoute(requestId))
                    }
                },
                onFavoriteToggle = { detailViewModel.toggleFavorite() },
                onResumeFromRecord = { detailViewModel.resumeFromRecord() },
                onDismissResume = { detailViewModel.dismissResumePrompt() },
                onEpisodeGroupSelected = { group -> detailViewModel.selectEpisodeGroup(group) },
                onHistoryClick = { navController.navigate(TvDestination.History.route) },
                // 与首页右上角「搜索」同一入口：进入壳层搜索页。
                onSearchClick = {
                    flushDetailProgress()
                    navController.navigate(TvDestination.Search.route) {
                        launchSingleTop = true
                    }
                },
                onExitClick = {
                    flushDetailProgress()
                    navController.previousBackStackEntry
                        ?.savedStateHandle
                        ?.set(HOME_CONTINUE_WATCHING_REFRESH_KEY, true)
                    navController.popBackStack()
                },
                onRecommendClick = { card ->
                    // 相关推荐与首页豆瓣卡片一致：用 douban 来源 + 标题进入详情兜底搜索。
                    val videoKey = TvDestination.Detail.createVideoKeyWithTitle(
                        source = card.source.ifBlank { "douban" },
                        videoId = card.id,
                        title = card.title,
                    )
                    // 全局只保留一个活跃详情页：替换当前详情，返回不再回到旧详情。
                    navController.navigate(TvDestination.Detail.createRoute(videoKey)) {
                        popUpTo(TvDestination.Detail.route) {
                            inclusive = true
                        }
                        launchSingleTop = true
                    }
                },
                playerSurface = if (playerKernel == "exo") {
                    {
                        ExoPlayerSurface(
                            exoPlayer = sharedPlayerSession.exoEngine?.exoPlayer,
                            isActive = currentRoute == TvDestination.Detail.route,
                            resizeMode = detailState.playbackRequest?.resizeMode
                                ?: org.moontechlab.selene.tv.core.player.api.TvResizeMode.FIT,
                            engine = sharedPlayerSession.exoEngine,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                } else {
                    {
                        WebViewPlayerSurface(
                            session = sharedPlayerSession.webViewSession,
                            playbackRequest = detailState.playbackRequest,
                            isActive = currentRoute == TvDestination.Detail.route,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
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
            val playbackContext = sharedPlayerHost.currentContext
                ?: playbackRequestStore.getContext(requestId)?.toSharedPlaybackContext()
            LaunchedEffect(requestId, playbackContext) {
                if (sharedPlayerHost.currentContext == null && playbackContext != null) {
                    sharedPlayerHost.updatePlaybackContext(
                        request = playbackContext.request,
                        sources = playbackContext.sources,
                        episodes = playbackContext.episodes,
                    )
                }
            }
            val playbackRequest = playbackContext?.request
            var playerKernel by remember { mutableStateOf(appContainer.peekPlayerKernel()) }
            LaunchedEffect(Unit) {
                playerKernel = appContainer.getPlayerKernel()
            }
            LaunchedEffect(playerKernel, requestId, playbackRequest?.videoId, playbackRequest?.sourceId) {
                // 全屏播放器也记录同一份选核日志，避免详情页和全屏页使用了不同内核却看不出来。
                Log.i(
                    TV_NAV_LOG_TAG,
                    "playerRoute kernel=$playerKernel requestId=$requestId source=${playbackRequest?.sourceId.orEmpty()} videoId=${playbackRequest?.videoId.orEmpty()}",
                )
            }
            val sharedPlayerSession = remember(playerKernel, sharedPlayerHost) {
                sharedPlayerHost.openOrReuseSession(playerKernel)
            }
            val playerViewModel = remember(requestId, playbackRequest, appContainer, sharedPlayerSession, playbackContext) {
                appContainer.createPlayerViewModel(
                    playbackRequest = playbackRequest,
                    playerEngine = sharedPlayerSession.playerEngine,
                    availableSources = playbackContext?.sources.orEmpty(),
                    allEpisodes = playbackContext?.episodes.orEmpty(),
                )
            }
            val playerUiState by playerViewModel.state.collectAsState()
            // 全屏页销毁时兜底落库用的最新进度快照（需 collect 才能随播放推进）。
            val playerProgressSnapshot = remember {
                DetailPlaybackProgressSnapshot()
            }
            playerProgressSnapshot.request = playerUiState.playbackRequest
            playerProgressSnapshot.positionMs = playerUiState.currentPositionMs
                .takeIf { positionMs -> positionMs > 0L }
                ?: playerUiState.playbackRequest?.startPositionMs
                ?: 0L
            playerProgressSnapshot.durationMs = playerUiState.durationMs
            DisposableEffect(requestId) {
                onDispose {
                    appContainer.persistPlaybackProgressAsync(
                        request = playerProgressSnapshot.request,
                        positionMs = playerProgressSnapshot.positionMs,
                        durationMs = playerProgressSnapshot.durationMs,
                    )
                }
            }
            TvPlayerRoute(
                playbackRequest = playbackRequest,
                viewModel = playerViewModel,
                playerSurface = if (playerKernel == "exo") {
                    { playerUiState ->
                        ExoPlayerSurface(
                            exoPlayer = sharedPlayerSession.exoEngine?.exoPlayer,
                            isActive = currentRoute == TvDestination.Player.route,
                            resizeMode = playerUiState.selectedResizeMode,
                            engine = sharedPlayerSession.exoEngine,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                } else {
                    { state ->
                        WebViewPlayerSurface(
                            session = sharedPlayerSession.webViewSession,
                            playbackRequest = state.playbackRequest,
                            isActive = currentRoute == TvDestination.Player.route,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                },
                onDanmakuMatchRequested = { query ->
                    danmakuMatchPlaybackRequest = playbackRequest
                    navController.navigate(TvDestination.DanmakuMatch.createRoute(query))
                },
                onExitRequested = {
                    appContainer.persistPlaybackProgressAsync(
                        request = playerProgressSnapshot.request,
                        positionMs = playerProgressSnapshot.positionMs,
                        durationMs = playerProgressSnapshot.durationMs,
                        onFinished = {
                            // 全屏退出也可能直接回首页路径；用脏标记保证首页 ON_RESUME 刷新。
                            runCatching {
                                navController.getBackStackEntry(TvDestination.Home.route)
                                    .savedStateHandle[HOME_CONTINUE_WATCHING_REFRESH_KEY] = true
                            }
                        },
                    )
                    // 播放器自身只发出退出意图，实际退栈由应用导航图负责。
                    navController.popBackStack()
                },
            )
        }
    }
}

/**
 * 详情/全屏离开时用于落库的最新播放进度快照。
 */
private class DetailPlaybackProgressSnapshot {
    var request: PlaybackRequest? = null
    var positionMs: Long = 0L
    var durationMs: Long = 0L
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

/** TV 导航图日志标签。 */
private const val TV_NAV_LOG_TAG = "SeleneTvNav"

/** 共享播放器允许保活的播放流路由集合。 */
private val playbackFlowRoutes = setOf(
    TvDestination.Detail.route,
    TvDestination.Player.route,
    TvDestination.DanmakuMatch.route,
)

/** 详情返回首页后触发继续观看局部刷新的 saved-state key。 */
private const val HOME_CONTINUE_WATCHING_REFRESH_KEY = "home_refresh_continue_watching"

/**
 * 将旧的导航暂存上下文映射为共享播放器上下文。
 *
 * @return 共享播放器可复用的播放上下文。
 */
private fun TvPlaybackContext.toSharedPlaybackContext() = org.moontechlab.selene.tv.app.TvSharedPlaybackContext(
    request = request,
    sources = sources,
    episodes = episodes,
)

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
