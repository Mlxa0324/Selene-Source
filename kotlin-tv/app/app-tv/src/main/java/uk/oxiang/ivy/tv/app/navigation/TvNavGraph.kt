package uk.oxiang.ivy.tv.app.navigation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import kotlinx.coroutines.launch
import uk.oxiang.ivy.tv.app.TvAppContainer
import uk.oxiang.ivy.tv.core.common.model.TvHomePayload
import uk.oxiang.ivy.tv.core.common.model.TvVideoCard
import uk.oxiang.ivy.tv.core.design.layout.TvEmptyStatePanel
import uk.oxiang.ivy.tv.core.design.layout.TvPageScaffold
import uk.oxiang.ivy.tv.core.design.layout.TvPageSection
import uk.oxiang.ivy.tv.core.design.layout.TvPosterItem
import uk.oxiang.ivy.tv.core.design.layout.TvPosterRail
import uk.oxiang.ivy.tv.core.design.layout.TvStatePanel
import uk.oxiang.ivy.tv.core.design.layout.TvStatePanelKind

/**
 * 搭建 TV 根导航图（骨架阶段）。
 *
 * 只接线首页与设置两个真实页面；其余顶层目的地先展示占位内容，具体业务
 * Composable 由各 feature 子任务在自己的 `implement.md` 中接入后替换。
 *
 * @param navController 全局导航控制器。
 * @param appContainer 应用依赖容器。
 * @param contentFocusRequester 当前内容区入口焦点请求器。
 * @param modifier 页面内容承载的外层修饰器。
 */
@Composable
fun TvNavGraph(
    navController: NavHostController,
    appContainer: TvAppContainer,
    modifier: Modifier = Modifier,
    contentFocusRequester: FocusRequester? = null,
) {
    NavHost(
        navController = navController,
        startDestination = TvDestination.Home.route,
        modifier = modifier,
    ) {
        composable(TvDestination.Home.route) {
            TvHomeRoutePlaceholder(
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
                onVideoClick = { videoId ->
                    navController.navigate(TvDestination.Detail.createRoute(videoId))
                },
            )
        }
        composable(TvDestination.Movie.route) {
            TvPlaceholderRoute(destination = TvDestination.Movie, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Tv.route) {
            TvPlaceholderRoute(destination = TvDestination.Tv, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Anime.route) {
            TvPlaceholderRoute(destination = TvDestination.Anime, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Show.route) {
            TvPlaceholderRoute(destination = TvDestination.Show, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Live.route) {
            TvPlaceholderRoute(destination = TvDestination.Live, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Search.route) {
            TvPlaceholderRoute(destination = TvDestination.Search, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.History.route) {
            TvPlaceholderRoute(destination = TvDestination.History, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Favorites.route) {
            TvPlaceholderRoute(destination = TvDestination.Favorites, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Settings.route) {
            TvSettingsRoutePlaceholder(
                appContainer = appContainer,
                contentFocusRequester = contentFocusRequester,
            )
        }
        composable(TvDestination.Detail.route) {
            TvPlaceholderRoute(destination = TvDestination.Detail, contentFocusRequester = contentFocusRequester)
        }
        composable(TvDestination.Player.route) {
            TvPlaceholderRoute(destination = TvDestination.Player, contentFocusRequester = contentFocusRequester)
        }
    }
}

/**
 * 首页骨架路由：直接消费 [TvAppContainer.homeRepository]，验证 core-common
 * 首页聚合契约在 app-tv 侧的接线可用性。完整首页交互留给 feature-home 子任务。
 *
 * @param appContainer 应用依赖容器。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param onVideoClick 卡片点击回调。
 */
@Composable
private fun TvHomeRoutePlaceholder(
    appContainer: TvAppContainer,
    contentFocusRequester: FocusRequester?,
    onVideoClick: (String) -> Unit,
) {
    var homePayload by remember { mutableStateOf<TvHomePayload?>(null) }
    var loadError by remember { mutableStateOf<String?>(null) }
    val coroutineScope = rememberCoroutineScope()

    fun loadHome() {
        loadError = null
        coroutineScope.launch {
            runCatching { appContainer.homeRepository.loadHome() }
                .onSuccess { payload -> homePayload = payload }
                .onFailure { throwable -> loadError = throwable.message ?: "首页加载失败" }
        }
    }

    LaunchedEffect(appContainer) {
        loadHome()
    }

    val payload = homePayload
    when {
        loadError != null -> {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "首页加载失败",
                message = loadError.orEmpty(),
                actionLabel = "重试",
                onAction = { loadHome() },
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = 46.dp, vertical = 24.dp),
            )
        }

        payload == null -> {
            TvStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "首页加载中",
                message = "正在获取最新内容",
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = 46.dp, vertical = 24.dp),
            )
        }

        payload.sections.isEmpty() -> {
            TvEmptyStatePanel(
                title = "暂无内容",
                message = "首页分区暂时没有数据",
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = 46.dp, vertical = 24.dp),
            )
        }

        else -> {
            TvPageScaffold {
                Column(verticalArrangement = Arrangement.spacedBy(28.dp)) {
                    payload.sections.forEachIndexed { sectionIndex, section ->
                        TvPageSection(title = section.title, insetContent = false) {
                            TvPosterRail(
                                items = section.videos.map { video -> video.toPosterItem() },
                                firstItemFocusRequester = if (sectionIndex == 0) contentFocusRequester else null,
                                onItemClick = { item -> onVideoClick(item.id) },
                                focusMemoryGroupKey = section.key,
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 将首页视频卡片映射为 [TvPosterItem]。
 *
 * @return 供 [TvPosterRail] 渲染的海报模型。
 */
private fun TvVideoCard.toPosterItem(): TvPosterItem {
    return TvPosterItem(
        id = id,
        source = source,
        title = title,
        subtitle = year,
        posterUrl = posterUrl,
        totalEpisodes = totalEpisodes,
        episodeIndex = episodeIndex,
        progressFraction = if (totalTime > 0) playTime.toFloat() / totalTime.toFloat() else 0f,
    )
}

/**
 * 设置骨架路由：验证 [TvAppContainer.settingsRepository] 和
 * [TvAppContainer.preferencesStore] 的接线可用性。完整设置页交互留给
 * feature-settings 子任务。
 *
 * @param appContainer 应用依赖容器。
 * @param contentFocusRequester 内容区入口焦点请求器。
 */
@Composable
private fun TvSettingsRoutePlaceholder(
    appContainer: TvAppContainer,
    contentFocusRequester: FocusRequester?,
) {
    val hasGatewayConfig = appContainer.settingsRepository != null
    TvEmptyStatePanel(
        title = "设置",
        message = if (hasGatewayConfig) {
            "已检测到本地后台网关配置，完整设置页由 feature-settings 子任务实现"
        } else {
            "尚未配置本地后台网关，完整设置页由 feature-settings 子任务实现"
        },
        contentFocusRequester = contentFocusRequester,
        modifier = Modifier.fillMaxSize().padding(horizontal = 46.dp, vertical = 24.dp),
    )
}

/**
 * 通用占位路由，用于尚未接入具体 feature 页面的顶层目的地。
 *
 * @param destination 当前占位目的地。
 * @param contentFocusRequester 内容区入口焦点请求器。
 */
@Composable
private fun TvPlaceholderRoute(
    destination: TvDestination,
    contentFocusRequester: FocusRequester?,
) {
    TvEmptyStatePanel(
        title = destination.label,
        message = "该页面由对应 feature 子任务实现",
        contentFocusRequester = contentFocusRequester,
        modifier = Modifier.fillMaxSize().padding(horizontal = 46.dp, vertical = 24.dp),
    )
}
