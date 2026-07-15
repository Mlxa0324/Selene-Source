package org.moontechlab.selene.tv.app
import androidx.activity.compose.BackHandler
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.background
import coil.Coil
import coil.ImageLoader
import okhttp3.OkHttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import kotlinx.coroutines.delay
import org.moontechlab.selene.tv.app.navigation.TvDestination
import org.moontechlab.selene.tv.app.navigation.TvNavGraph
import org.moontechlab.selene.tv.core.design.SeleneTvTheme
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.layout.LocalTvTopChromeHeightPx
import org.moontechlab.selene.tv.core.design.layout.TvDesignCanvas
import org.moontechlab.selene.tv.core.design.layout.TvDesignPreset
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressAction
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressPolicy
import org.moontechlab.selene.tv.core.design.focus.isTvConfirmKey
import org.moontechlab.selene.tv.core.design.focus.rememberTvEdgeShakeState
import org.moontechlab.selene.tv.core.design.focus.tvEdgeShake
import org.moontechlab.selene.tv.feature.home.CategoryFilterOverlayState
import org.moontechlab.selene.tv.feature.home.LocalCategoryFilterOverlayState
import org.moontechlab.selene.tv.feature.home.TvCategoryFilterOverlayLayer
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/**
 * 组装 TV 原生工程的 Compose 根节点。
 */
@Composable
fun TvApp() {
    SeleneTvTheme {
        TvDesignCanvas(
            preset = TvDesignPreset.QHD_1440,
        ) {
            val context = LocalContext.current
            val navController = rememberNavController()
            // 服务器配置变更时重新创建容器，确保新配置在后续请求中生效。
            var serverConfigVersion by remember { mutableStateOf(0) }
            val appContainer = remember(serverConfigVersion) {
                TvAppContainer(
                    gatewayConfig = TvLocalGatewayConfig.fromBuildConfig(),
                    appContext = context.applicationContext,
                )
            }

            // Coil 配置：对 doubanio.com 图片附加 Referer 头，避免 403 空白封面。
            LaunchedEffect(Unit) {
                withContext(Dispatchers.IO) {
                    val customClient = OkHttpClient.Builder()
                        // 图片加载也直连，避免系统代理拖慢封面请求。
                        .proxy(java.net.Proxy.NO_PROXY)
                        // 封面请求同样输出全局耗时日志，便于对比接口与图片谁更慢。
                        .eventListenerFactory(org.moontechlab.selene.tv.core.network.ResponseTimingEventListenerFactory())
                        .addInterceptor { chain ->
                            val request = chain.request()
                            if (request.url.host.contains("doubanio.com")) {
                                chain.proceed(
                                    request.newBuilder()
                                        .header("Referer", "https://movie.douban.com/")
                                        .header("User-Agent",
                                            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                                            "AppleWebKit/537.36 (KHTML, like Gecko) " +
                                            "Chrome/121.0.0.0 Safari/537.36")
                                        .build(),
                                )
                            } else {
                                chain.proceed(request)
                            }
                        }
                        .build()

                    Coil.setImageLoader(
                        ImageLoader.Builder(context)
                            .okHttpClient { customClient }
                            .build(),
                    )
                }
            }
            val currentBackStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = currentBackStackEntry?.destination?.route
            val contentFocusRequester = remember(currentRoute) {
                // 顶层页面切换后必须换一个请求器，避免请求到旧页面保留的隐藏卡片。
                FocusRequester()
            }
            // 顶栏焦点请求器提到壳层：内容区返回键可直接落到「当前 tab」。
            val topDestinationFocusRequesters = rememberTopDestinationFocusRequesters()
            var topNavHasFocus by remember { mutableStateOf(false) }
            var showCategoryFilter by remember { mutableStateOf(false) }
            // 顶栏实测高度：overlay 落点 = 顶栏下沿。
            var topChromeHeightPx by remember { mutableIntStateOf(0) }
            // 分类筛选全屏图层状态：分类页写入 filters，壳层绘制 overlay。
            val categoryFilterOverlayState = remember { CategoryFilterOverlayState() }
            val isPrimaryRoute = currentRoute in TvDestination.primaryMenuDestinations.map { it.route }

            // 筛选从 tab 打开后顶栏 canFocus=false，关闭时需等重组再落焦当前 tab。
            var pendingRestoreTopTabFocus by remember { mutableStateOf(false) }
            // 切入电影/剧集/动漫/综艺时短暂提示确认键可呼出筛选。
            var showCategoryFilterHint by remember { mutableStateOf(false) }

            fun focusCurrentPrimaryTab(): Boolean {
                val route = currentRoute ?: return false
                if (!isPrimaryRoute) {
                    return false
                }
                val requester = topDestinationFocusRequesters[route] ?: return false
                // 仅成功获焦后再标记顶栏持焦，避免失败时误判导致返回被吞或切到首页。
                val ok = runCatching { requester.requestFocus() }.getOrDefault(false)
                if (ok) {
                    topNavHasFocus = true
                }
                return ok
            }

            /**
             * 主菜单页返回：
             * 1) 筛选打开 → 关闭并落焦**当前**分类 tab（不 pop 回首页）
             * 2) 焦点在内容区 → 落焦当前 tab
             * 顶栏已持焦且无筛选时不拦截（留给系统/上层）。
             */
            fun handlePrimaryContentBack(): Boolean {
                if (!isPrimaryRoute) {
                    return false
                }
                if (showCategoryFilter) {
                    showCategoryFilter = false
                    // 顶栏 canFocus 要等下一帧恢复，延后 requestFocus。
                    pendingRestoreTopTabFocus = true
                    return true
                }
                if (topNavHasFocus) {
                    return false
                }
                return focusCurrentPrimaryTab()
            }

            // 筛选打开时也要消费返回（焦点从 tab 打开后 topNavHasFocus 可能仍为 true）。
            BackHandler(enabled = isPrimaryRoute && (showCategoryFilter || !topNavHasFocus)) {
                handlePrimaryContentBack()
            }
            LaunchedEffect(currentRoute) {
                // 切换顶层页面后重置筛选面板可见态。
                showCategoryFilter = false
                pendingRestoreTopTabFocus = false
                if (!isPrimaryRoute) {
                    // 子页面（搜索/设置/播放器等）无顶部主导航，直接落焦到内容区。
                    contentFocusRequester.requestFocus()
                }
            }
            // 进入支持筛选的分类 tab：短暂提示「确认键可打开分类筛选」。
            LaunchedEffect(currentRoute) {
                val supportsFilter = TvDestination.primaryMenuDestinations.any { destination ->
                    destination.route == currentRoute && destination.supportsCategoryFilter()
                }
                if (!supportsFilter) {
                    showCategoryFilterHint = false
                    return@LaunchedEffect
                }
                showCategoryFilterHint = true
                delay(2_800)
                showCategoryFilterHint = false
            }
            // 筛选关闭后顶栏恢复可焦，再落到当前 tab（电影/剧集/动漫/综艺等）。
            LaunchedEffect(showCategoryFilter, pendingRestoreTopTabFocus, currentRoute) {
                if (showCategoryFilter || !pendingRestoreTopTabFocus) {
                    return@LaunchedEffect
                }
                for (attempt in 0 until 16) {
                    delay(32)
                    if (focusCurrentPrimaryTab()) {
                        pendingRestoreTopTabFocus = false
                        return@LaunchedEffect
                    }
                }
                pendingRestoreTopTabFocus = false
            }
            LaunchedEffect(isPrimaryRoute) {
                if (!isPrimaryRoute) {
                    topChromeHeightPx = 0
                }
            }

            CompositionLocalProvider(
                LocalTvTopChromeHeightPx provides topChromeHeightPx,
                LocalCategoryFilterOverlayState provides categoryFilterOverlayState,
            ) {
                // 底层：顶栏 + 内容；顶层：分类筛选 overlay（从屏顶滑到顶栏下）。
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(MaterialTheme.colorScheme.background)
                        .onPreviewKeyEvent { event ->
                            // 模拟器 Esc 与返回键一致：关筛选 / 内容区 → 当前主 tab。
                            val isBackOrEsc = event.key == Key.Back || event.key == Key.Escape
                            if (!isBackOrEsc || !isPrimaryRoute) {
                                return@onPreviewKeyEvent false
                            }
                            // 筛选打开时一律拦截；否则仅内容区拦截（顶栏持焦时不抢）。
                            if (topNavHasFocus && !showCategoryFilter) {
                                return@onPreviewKeyEvent false
                            }
                            if (event.type == KeyEventType.KeyDown) {
                                return@onPreviewKeyEvent handlePrimaryContentBack()
                            }
                            // KeyUp 一并消费，避免再被系统 pop 回首页。
                            if (event.type == KeyEventType.KeyUp) {
                                return@onPreviewKeyEvent true
                            }
                            false
                        },
                ) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        // 顶栏固定占位；筛选打开时禁止左/右 tab 获焦，直到返回关闭。
                        if (isPrimaryRoute) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .onSizeChanged { size ->
                                        if (size.height > 0 && size.height != topChromeHeightPx) {
                                            topChromeHeightPx = size.height
                                        }
                                    },
                            ) {
                                TvTopNavigationBar(
                                    currentRoute = currentRoute,
                                    contentFocusRequester = contentFocusRequester,
                                    topDestinationFocusRequesters = topDestinationFocusRequesters,
                                    topNavHasFocus = topNavHasFocus,
                                    // 筛选打开期间左右顶栏均不可获焦。
                                    focusEnabled = !showCategoryFilter,
                                    onTopNavHasFocusChange = { focused -> topNavHasFocus = focused },
                                    onNavigate = { destination ->
                                        if (destination.route != currentRoute) {
                                            // 点击顶部标签时只保留顶层单实例，避免重复入栈。
                                            navController.navigate(destination.route) {
                                                popUpTo(navController.graph.startDestinationId) {
                                                    saveState = true
                                                }
                                                launchSingleTop = true
                                                restoreState = true
                                            }
                                        }
                                    },
                                    onFilterToggle = {
                                        // 从当前 tab 打开筛选：焦点会进面板，顶栏标记需清掉，
                                        // 否则返回键会被当成「已在顶栏」而漏拦、pop 回首页。
                                        if (!showCategoryFilter) {
                                            topNavHasFocus = false
                                            showCategoryFilterHint = false
                                        }
                                        showCategoryFilter = !showCategoryFilter
                                    },
                                )
                            }
                        }

                        TvNavGraph(
                            navController = navController,
                            appContainer = appContainer,
                            contentFocusRequester = contentFocusRequester,
                            showCategoryFilter = showCategoryFilter,
                            onServerConfigSaved = {
                                serverConfigVersion++
                            },
                            // 顶栏下方剩余高度。
                            modifier = Modifier.weight(1f).fillMaxWidth(),
                        )
                    }

                    // 分类筛选独立图层：纯色底 + 贴屏顶；关闭时淡出。
                    TvCategoryFilterOverlayLayer(
                        visible = showCategoryFilter,
                        topChromeHeightPx = topChromeHeightPx,
                        state = categoryFilterOverlayState,
                    )

                    // 切入支持筛选的分类 tab 时，底部轻提示确认键用法。
                    if (showCategoryFilterHint && !showCategoryFilter) {
                        TvCategoryFilterHintBar(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .padding(bottom = 48.dp),
                        )
                    }
                }
            }
        }
    }
}

/**
 * 渲染对齐 Flutter TV 的顶部导航。
 *
 * @param currentRoute 当前选中的路由。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param topDestinationFocusRequesters 顶层入口焦点请求器（壳层持有，便于内容区返回落焦）。
 * @param topNavHasFocus 顶栏是否持有焦点（壳层与顶栏双向同步）。
 * @param onTopNavHasFocusChange 顶栏焦点变化回调。
 * @param onNavigate 顶部入口点击后的跳转回调。
 */
@Composable
private fun TvTopNavigationBar(
    currentRoute: String?,
    contentFocusRequester: FocusRequester,
    topDestinationFocusRequesters: Map<String, FocusRequester>,
    topNavHasFocus: Boolean,
    focusEnabled: Boolean = true,
    onTopNavHasFocusChange: (Boolean) -> Unit,
    onNavigate: (TvDestination) -> Unit,
    onFilterToggle: () -> Unit = {},
) {
    val selectedTopDestination = remember(currentRoute) {
        // 只有顶层入口需要承接初始焦点，详情页等非顶层页面不强行抢焦点。
        TvDestination.topLevelDestinations.firstOrNull { destination ->
            destination.route == currentRoute
        }
    }
    val selectedTopDestinationFocusRequester = selectedTopDestination
        ?.let { destination -> topDestinationFocusRequesters[destination.route] }
    var pendingInternalFocusRoute by remember { mutableStateOf<String?>(null) }
    // 主菜单上键进快捷区时记录来源 tab，快捷区下键原路返回。
    var lastActionSourceRoute by remember { mutableStateOf<String?>(null) }
    val primaryRoutes = remember {
        TvDestination.primaryMenuDestinations.map { destination -> destination.route }.toSet()
    }
    val firstQuickAccessRoute = TvDestination.quickAccessDestinations.firstOrNull()?.route

    fun moveFocusToRoute(route: String) {
        val requester = topDestinationFocusRequesters[route] ?: return
        pendingInternalFocusRoute = route
        onTopNavHasFocusChange(true)
        runCatching { requester.requestFocus() }
    }

    LaunchedEffect(selectedTopDestination?.route) {
        if (selectedTopDestinationFocusRequester != null) {
            // 首屏真实焦点先落到当前入口，用户按一次下键即可进入内容卡片。
            selectedTopDestinationFocusRequester.requestFocus()
            onTopNavHasFocusChange(true)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = TvTokens.PageHorizontalPadding,
                // 顶栏略留上边距，避免 Logo/搜索贴屏幕上沿；仍比旧版 28dp 紧凑。
                top = 22.dp,
                end = TvTokens.PageHorizontalPadding,
                bottom = 10.dp,
            )
            .onFocusChanged { focusState ->
                // 整顶栏（主菜单 + 右上角快捷）共用焦点态。
                onTopNavHasFocusChange(focusState.hasFocus)
            },
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "IvyTV",
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontSize = 26.sp,
                    fontWeight = FontWeight.ExtraBold,
                ),
                color = Color.White,
            )

            Spacer(modifier = Modifier.weight(1f))

            // 右上角快捷区：胶囊样式；下键回到主菜单来源项；首项左键回主菜单末项（收藏夹↔搜索）。
            TvDestinationGroup(
                destinations = TvDestination.quickAccessDestinations,
                currentRoute = currentRoute,
                contentFocusRequester = contentFocusRequester,
                topDestinationFocusRequesters = topDestinationFocusRequesters,
                horizontalSpacing = 10.dp,
                navigateOnFocus = false,
                itemStyle = TvNavItemStyle.Pill,
                topNavHasFocus = topNavHasFocus,
                focusEnabled = focusEnabled,
                pendingInternalFocusRoute = pendingInternalFocusRoute,
                onPendingInternalFocusConsumed = { pendingInternalFocusRoute = null },
                onTopNavGainedFocus = { onTopNavHasFocusChange(true) },
                onRequestInternalFocus = ::moveFocusToRoute,
                onNavigate = onNavigate,
                onMoveDownFromGroup = {
                    val sourceRoute = lastActionSourceRoute
                        ?.takeIf { route -> route in primaryRoutes }
                        ?: currentRoute?.takeIf { route -> route in primaryRoutes }
                        ?: TvDestination.primaryMenuDestinations.first().route
                    moveFocusToRoute(sourceRoute)
                },
                // 搜索再左 → 收藏夹（主菜单末项），形成左右互跳。
                onExitLeftFromFirst = {
                    val lastPrimaryRoute = TvDestination.primaryMenuDestinations.last().route
                    lastActionSourceRoute = lastPrimaryRoute
                    moveFocusToRoute(lastPrimaryRoute)
                },
            )

            Spacer(modifier = Modifier.width(24.dp))

            TvClockText()
        }

        // 左侧主菜单：与 LOGO 左对齐；无背景文字 + 选中主题色下划线。
        TvDestinationGroup(
            destinations = TvDestination.primaryMenuDestinations,
            currentRoute = currentRoute,
            contentFocusRequester = contentFocusRequester,
            topDestinationFocusRequesters = topDestinationFocusRequesters,
            // 恢复接近原先胶囊行的视觉间距（胶囊时 12 间距 + 左右 16 内边距 ≈ 文案间更疏）。
            horizontalSpacing = 28.dp,
            navigateOnFocus = true,
            itemStyle = TvNavItemStyle.TextUnderline,
            topNavHasFocus = topNavHasFocus,
            focusEnabled = focusEnabled,
            pendingInternalFocusRoute = pendingInternalFocusRoute,
            onPendingInternalFocusConsumed = { pendingInternalFocusRoute = null },
            onTopNavGainedFocus = { onTopNavHasFocusChange(true) },
            onRequestInternalFocus = ::moveFocusToRoute,
            onNavigate = onNavigate,
            onFilterToggle = onFilterToggle,
            onMoveUpFromItem = { sourceRoute ->
                lastActionSourceRoute = sourceRoute
                val targetRoute = firstQuickAccessRoute ?: return@TvDestinationGroup
                moveFocusToRoute(targetRoute)
            },
            // 收藏夹再右 → 搜索（快捷首项），与上键跨组并列。
            onExitRightFromLast = { sourceRoute ->
                lastActionSourceRoute = sourceRoute
                val targetRoute = firstQuickAccessRoute ?: return@TvDestinationGroup
                moveFocusToRoute(targetRoute)
            },
        )
    }
}

/**
 * 顶部导航项视觉样式。
 */
private enum class TvNavItemStyle {
    /** 右上角快捷：圆角胶囊底 + 焦点描边。 */
    Pill,

    /** 主菜单：无背景，主题色文字，选中显示下划线。 */
    TextUnderline,
}

/**
 * 渲染同一分区内的一组路由按钮。
 *
 * @param destinations 当前分区包含的路由集合。
 * @param currentRoute 当前选中的路由。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param navigateOnFocus 是否在组内焦点移动时直接切换路由。
 * @param itemStyle 本组导航项视觉样式（主菜单文字下划线 / 快捷胶囊）。
 * @param topNavHasFocus 整顶栏（主菜单+快捷）是否已持有焦点。
 * @param pendingInternalFocusRoute 显式组内/跨组移动的目标路由。
 * @param onPendingInternalFocusConsumed 消费一次 pending 落焦标记。
 * @param onTopNavGainedFocus 标记顶栏已获焦。
 * @param onRequestInternalFocus 组内左右移动时请求焦点。
 * @param onNavigate 顶部标签点击后的跳转回调。
 * @param onMoveUpFromItem 组内某项上键（主菜单 → 右上角快捷）。
 * @param onMoveDownFromGroup 组内下键（快捷区 → 主菜单来源项）。
 * @param onExitLeftFromFirst 组内首项再左（快捷搜索 → 主菜单末项收藏夹）。
 * @param onExitRightFromLast 组内末项再右（主菜单收藏夹 → 快捷搜索）。
 */
@Composable
private fun TvDestinationGroup(
    destinations: List<TvDestination>,
    currentRoute: String?,
    contentFocusRequester: FocusRequester,
    topDestinationFocusRequesters: Map<String, FocusRequester>,
    horizontalSpacing: androidx.compose.ui.unit.Dp = 10.dp,
    navigateOnFocus: Boolean,
    itemStyle: TvNavItemStyle = TvNavItemStyle.Pill,
    topNavHasFocus: Boolean,
    focusEnabled: Boolean = true,
    pendingInternalFocusRoute: String?,
    onPendingInternalFocusConsumed: () -> Unit,
    onTopNavGainedFocus: () -> Unit,
    onRequestInternalFocus: (String) -> Unit,
    onNavigate: (TvDestination) -> Unit,
    onFilterToggle: () -> Unit = {},
    onMoveUpFromItem: ((sourceRoute: String) -> Unit)? = null,
    onMoveDownFromGroup: (() -> Unit)? = null,
    onExitLeftFromFirst: (() -> Unit)? = null,
    onExitRightFromLast: ((sourceRoute: String) -> Unit)? = null,
) {
    val activePillFocusRequester = currentRoute?.let { topDestinationFocusRequesters[it] }

    Row(
        horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        destinations.forEachIndexed { index, destination ->
            val isSelected = destination.route == currentRoute
            val previousDestination = destinations.getOrNull(index - 1)
            val nextDestination = destinations.getOrNull(index + 1)
            TvNavigationPill(
                label = destination.label,
                iconGlyph = destination.iconGlyph,
                selected = isSelected,
                style = itemStyle,
                supportsCategoryFilter = destination.supportsCategoryFilter(),
                contentFocusRequester = contentFocusRequester,
                focusRequester = topDestinationFocusRequesters[destination.route],
                focusEnabled = focusEnabled,
                // 快捷区自管下键回主菜单，不再直达内容区。
                useContentAsDownTarget = onMoveDownFromGroup == null,
                onFocused = {
                    val isPendingInternalMove = pendingInternalFocusRoute == destination.route
                    // 顶栏内跨组（主菜单↔快捷）与组内左右都算“内部移动”，禁止拉回选中主 tab。
                    val movingInsideTopNav = topNavHasFocus || isPendingInternalMove
                    if (isPendingInternalMove) {
                        onPendingInternalFocusConsumed()
                    }
                    if (!movingInsideTopNav && !isSelected && activePillFocusRequester != null) {
                        // 从内容区上来的焦点落到非当前 tab 时，重定向到选中 tab，
                        // 确保下键始终回到正确的内容区位置。
                        runCatching { activePillFocusRequester.requestFocus() }
                    } else {
                        // Flutter TV 主菜单左右移动时焦点即切页；快捷入口仍保持确认键进入。
                        if (navigateOnFocus && movingInsideTopNav && !isSelected) {
                            onNavigate(destination)
                        }
                        onTopNavGainedFocus()
                    }
                },
                onClick = { onNavigate(destination) },
                // 组内有邻居则移动；首/末可走跨组出口（收藏夹↔搜索），否则边界抖动。
                onMoveLeft = previousDestination?.route?.let { route ->
                    { onRequestInternalFocus(route) }
                } ?: onExitLeftFromFirst,
                onMoveRight = nextDestination?.route?.let { route ->
                    { onRequestInternalFocus(route) }
                } ?: onExitRightFromLast?.let { exit ->
                    { exit(destination.route) }
                },
                onMoveUp = onMoveUpFromItem?.let { moveUp ->
                    { moveUp(destination.route) }
                },
                onMoveDown = onMoveDownFromGroup,
                onFilterToggle = onFilterToggle,
            )
        }
    }
}

/**
 * TV 顶部导航项按钮。
 *
 * @param label 按钮文案。
 * @param selected 是否为当前路由。
 * @param style 视觉样式（胶囊 / 文字下划线）。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param useContentAsDownTarget 下键是否落到内容区；快捷区为 false，由 [onMoveDown] 回主菜单。
 * @param onFocused 焦点进入按钮时的回调。
 * @param onClick 点击后的跳转回调。
 * @param onMoveLeft 左键移动到组内上一个按钮。
 * @param onMoveRight 右键移动到组内下一个按钮。
 * @param onMoveUp 上键（主菜单进右上角快捷）。
 * @param onMoveDown 下键（快捷区回主菜单）。
 */
@Composable
private fun TvNavigationPill(
    label: String,
    iconGlyph: String?,
    selected: Boolean,
    style: TvNavItemStyle = TvNavItemStyle.Pill,
    supportsCategoryFilter: Boolean = false,
    contentFocusRequester: FocusRequester,
    focusRequester: FocusRequester?,
    focusEnabled: Boolean = true,
    useContentAsDownTarget: Boolean = true,
    onFocused: () -> Unit,
    onClick: () -> Unit,
    onMoveLeft: (() -> Unit)? = null,
    onMoveRight: (() -> Unit)? = null,
    onMoveUp: (() -> Unit)? = null,
    onMoveDown: (() -> Unit)? = null,
    onFilterToggle: () -> Unit = {},
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val pressPolicy = remember { TvRemotePressPolicy(hasLongPressHandler = false) }
    val edgeShake = rememberTvEdgeShakeState()
    val isTextUnderline = style == TvNavItemStyle.TextUnderline
    val pillShape = RoundedCornerShape(TvTokens.TopActionRadius)
    val pillBackground = when {
        isTextUnderline -> Color.Transparent
        selected || isFocused -> TvTokens.FocusFill
        else -> TvTokens.Surface
    }
    // 主菜单：未选中正文色；选中/获焦（焦点即切页）统一 Accent 字 + 线。
    // 快捷胶囊：选中/获焦白字，否则正文色。
    val labelColor = when {
        isTextUnderline && (selected || isFocused) -> TvTokens.Accent
        isTextUnderline -> TvTokens.TextPrimary
        selected || isFocused -> Color.White
        else -> TvTokens.TextPrimary
    }
    // 主菜单：选中或获焦才画主题色下划线，未选中不画线。
    val underlineColor = when {
        !isTextUnderline -> Color.Transparent
        selected || isFocused -> TvTokens.Accent
        else -> Color.Transparent
    }

    val focusAndClickModifier = Modifier
        .tvEdgeShake(edgeShake)
        .focusProperties {
            // 分类筛选打开时整顶栏不可获焦（左主菜单 + 右快捷）。
            canFocus = focusEnabled
            // 主菜单下键进内容；快捷区下键由 onMoveDown 显式回主菜单，禁用默认 down。
            down = if (useContentAsDownTarget) {
                contentFocusRequester
            } else {
                FocusRequester.Cancel
            }
            // 快捷区最上：上键 Cancel，配合抖动反馈。
            if (onMoveUp == null) {
                up = FocusRequester.Cancel
            }
        }
        .then(
            if (focusRequester != null) {
                // 请求器必须挂在真实 focusable 之前，确保初始焦点落到按钮本身。
                Modifier.focusRequester(focusRequester)
            } else {
                Modifier
            },
        )
        .onPreviewKeyEvent { event ->
            if (!focusEnabled) {
                return@onPreviewKeyEvent false
            }
            if (event.key == Key.DirectionLeft || event.key == Key.DirectionRight) {
                val handler = if (event.key == Key.DirectionLeft) onMoveLeft else onMoveRight
                if (handler != null) {
                    if (event.type == KeyEventType.KeyDown) {
                        handler.invoke()
                    }
                } else {
                    // 组内首/末项：到底抖动，禁止逃出顶栏组。
                    edgeShake.consumeBoundaryKey(
                        event = event,
                        left = event.key == Key.DirectionLeft,
                        right = event.key == Key.DirectionRight,
                    )
                }
                return@onPreviewKeyEvent true
            }
            if (event.key == Key.DirectionUp) {
                if (onMoveUp != null) {
                    if (event.type == KeyEventType.KeyDown) {
                        onMoveUp()
                    }
                } else {
                    // 右上角搜索等：上键到底抖动。
                    edgeShake.consumeBoundaryKey(event = event, up = true)
                }
                return@onPreviewKeyEvent true
            }
            if (event.key == Key.DirectionDown && onMoveDown != null) {
                if (event.type == KeyEventType.KeyDown) {
                    onMoveDown()
                }
                return@onPreviewKeyEvent true
            }
            if (!event.key.isTvConfirmKey()) {
                return@onPreviewKeyEvent false
            }
            val action = when (event.type) {
                KeyEventType.KeyDown -> pressPolicy.onKeyDown(
                    isRepeat = pressPolicy.isPressing,
                )
                KeyEventType.KeyUp -> pressPolicy.onKeyUp()
                else -> TvRemotePressAction.None
            }
            if (action == TvRemotePressAction.ShortPress) {
                // 对齐 Flutter：电影/剧集/动漫/综艺在当前 tab 确认键向下弹出分类筛选。
                when {
                    selected && supportsCategoryFilter -> onFilterToggle()
                    !selected -> onClick()
                    else -> Unit
                }
            }
            true
        }
        .onFocusChanged { focusState ->
            if (focusState.isFocused) {
                onFocused()
            }
        }
        .pointerInput(onClick) {
            detectTapGestures(
                onTap = { onClick() },
            )
        }
        .focusable(enabled = focusEnabled, interactionSource = interactionSource)

    if (isTextUnderline) {
        // 主菜单：无背景；未选中正文色；选中 Accent 字 + 紧贴下划线。
        // IntrinsicSize.Max：宽度跟字，禁止 fillMaxWidth 撑满 Row 挤掉后续 tab。
        // start 无额外 padding，与上方 IvyTV LOGO 左缘对齐。
        Box(
            modifier = Modifier
                .height(TvTokens.TopActionHeight)
                .then(focusAndClickModifier),
            contentAlignment = Alignment.CenterStart,
        ) {
            Column(
                modifier = Modifier.width(IntrinsicSize.Max),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.titleMedium.copy(
                        // 略收字号，降低顶栏行高占用。
                        fontSize = 17.sp,
                        fontWeight = if (selected || isFocused) {
                            FontWeight.ExtraBold
                        } else {
                            FontWeight.Bold
                        },
                        letterSpacing = 0.3.sp,
                    ),
                    color = labelColor,
                    maxLines = 1,
                )
                // 字与线 1dp 贴合；线高 2dp 更克制。
                Spacer(modifier = Modifier.height(1.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(2.dp)
                        .widthIn(min = 12.dp)
                        .clip(RoundedCornerShape(1.dp))
                        .background(underlineColor),
                )
            }
        }
    } else {
        // 右上角快捷：胶囊底 + 焦点描边。
        Box(
            modifier = Modifier
                .height(TvTokens.TopActionHeight)
                .clip(pillShape)
                .background(pillBackground)
                .border(
                    width = 2.dp,
                    color = if (isFocused) TvTokens.FocusBorder else Color.Transparent,
                    shape = pillShape,
                )
                .then(focusAndClickModifier)
                .padding(horizontal = 16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (!iconGlyph.isNullOrBlank()) {
                    Text(
                        text = iconGlyph,
                        style = MaterialTheme.typography.titleMedium.copy(
                            // 与详情/底部操作图标视觉等重（TvTokens.TopActionIconGlyph）。
                            fontSize = TvTokens.TopActionIconGlyph,
                            fontWeight = FontWeight.Bold,
                        ),
                        color = Color.White,
                    )
                }
                Text(
                    text = label,
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontSize = 16.sp,
                        fontWeight = if (selected || isFocused) FontWeight.Bold else FontWeight.SemiBold,
                    ),
                    color = labelColor,
                )
            }
        }
    }
}

/**
 * 记住顶层入口到焦点请求器的映射。
 *
 * @return 每个顶层入口独立持有的焦点请求器。
 */
@Composable
private fun rememberTopDestinationFocusRequesters(): Map<String, FocusRequester> {
    return remember {
        TvDestination.topLevelDestinations.associate { destination ->
            // 独立请求器避免快捷入口和主菜单之间互相覆盖真实焦点。
            destination.route to FocusRequester()
        }
    }
}

/**
 * TV 顶部当前时间。
 */
@Composable
private fun TvClockText() {
    var currentTime by remember { mutableStateOf(formatCurrentTime()) }

    LaunchedEffect(Unit) {
        while (true) {
            currentTime = formatCurrentTime()
            delay(30_000)
        }
    }

    Text(
        text = currentTime,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

/**
 * 格式化顶部时间。
 *
 * @return HH:mm 格式时间。
 */
private fun formatCurrentTime(): String {
    return LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm"))
}


/**
 * 是否支持分类筛选面板。
 *
 * 对齐 Flutter TV：电影 / 剧集 / 动漫 / 综艺在当前 tab 确认键弹出筛选。
 */
private fun TvDestination.supportsCategoryFilter(): Boolean {
    return this is TvDestination.Movie ||
        this is TvDestination.Tv ||
        this is TvDestination.Anime ||
        this is TvDestination.Show
}

/**
 * 分类 tab 轻提示：告知用户确认键可呼出筛选。
 *
 * 切入电影 / 剧集 / 动漫 / 综艺时短暂展示，不抢焦点。
 */
@Composable
private fun TvCategoryFilterHintBar(
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(TvTokens.Surface.copy(alpha = 0.92f))
            .border(
                width = 1.dp,
                color = TvTokens.TextSecondary.copy(alpha = 0.25f),
                shape = RoundedCornerShape(20.dp),
            )
            .padding(horizontal = 20.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "按确认键可打开分类筛选",
            style = MaterialTheme.typography.bodyMedium,
            color = TvTokens.TextPrimary,
            maxLines = 1,
        )
    }
}
