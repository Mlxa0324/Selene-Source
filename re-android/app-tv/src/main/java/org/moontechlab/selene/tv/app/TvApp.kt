package org.moontechlab.selene.tv.app
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import org.moontechlab.selene.tv.core.design.layout.TvDesignCanvas
import org.moontechlab.selene.tv.core.design.layout.TvDesignPreset
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressAction
import org.moontechlab.selene.tv.core.design.focus.TvRemotePressPolicy
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
            var showCategoryFilter by remember { mutableStateOf(false) }
            val isPrimaryRoute = currentRoute in TvDestination.primaryMenuDestinations.map { it.route }
            LaunchedEffect(currentRoute) {
                // 切换顶层页面后重置筛选面板可见态。
                showCategoryFilter = false
                if (!isPrimaryRoute) {
                    // 子页面（搜索/历史/收藏/设置/播放器）无顶部导航，直接落焦到内容区。
                    contentFocusRequester.requestFocus()
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background),
            ) {
                if (currentRoute in TvDestination.primaryMenuDestinations.map { it.route }) {
                    // 顶级导航只在主标签页展示，子页面（搜索/历史/收藏/设置/播放器）不显示。
                    TvTopNavigationBar(
                        currentRoute = currentRoute,
                        contentFocusRequester = contentFocusRequester,
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
                            showCategoryFilter = !showCategoryFilter
                        },
                    )
                }

                TvNavGraph(
                    navController = navController,
                    appContainer = appContainer,
                    contentFocusRequester = contentFocusRequester,
                    showCategoryFilter = showCategoryFilter,
                    onServerConfigSaved = {
                        serverConfigVersion++
                    },
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}

/**
 * 渲染对齐 Flutter TV 的顶部导航。
 *
 * @param currentRoute 当前选中的路由。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param onNavigate 顶部入口点击后的跳转回调。
 */
@Composable
private fun TvTopNavigationBar(
    currentRoute: String?,
    contentFocusRequester: FocusRequester,
    onNavigate: (TvDestination) -> Unit,
    onFilterToggle: () -> Unit = {},
) {
    val topDestinationFocusRequesters = rememberTopDestinationFocusRequesters()
    val selectedTopDestination = remember(currentRoute) {
        // 只有顶层入口需要承接初始焦点，详情页等非顶层页面不强行抢焦点。
        TvDestination.topLevelDestinations.firstOrNull { destination ->
            destination.route == currentRoute
        }
    }
    val selectedTopDestinationFocusRequester = selectedTopDestination
        ?.let { destination -> topDestinationFocusRequesters[destination.route] }

    LaunchedEffect(selectedTopDestination?.route) {
        if (selectedTopDestinationFocusRequester != null) {
            // 首屏真实焦点先落到当前入口，用户按一次下键即可进入内容卡片。
            selectedTopDestinationFocusRequester.requestFocus()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = TvTokens.PageHorizontalPadding,
                top = 28.dp,
                end = TvTokens.PageHorizontalPadding,
                bottom = 24.dp,
            ),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "IvyTV",
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontSize = 32.sp,
                    fontWeight = FontWeight.ExtraBold,
                ),
                color = Color.White,
            )

            Spacer(modifier = Modifier.weight(1f))

            TvDestinationGroup(
                destinations = TvDestination.quickAccessDestinations,
                currentRoute = currentRoute,
                contentFocusRequester = contentFocusRequester,
                topDestinationFocusRequesters = topDestinationFocusRequesters,
                horizontalSpacing = 10.dp,
                navigateOnFocus = false,
                onNavigate = onNavigate,
            )

            Spacer(modifier = Modifier.width(24.dp))

            TvClockText()
        }

        TvDestinationGroup(
            destinations = TvDestination.primaryMenuDestinations,
            currentRoute = currentRoute,
            contentFocusRequester = contentFocusRequester,
            topDestinationFocusRequesters = topDestinationFocusRequesters,
            horizontalSpacing = 12.dp,
            navigateOnFocus = true,
            onNavigate = onNavigate,
            onFilterToggle = onFilterToggle,
        )
    }
}

/**
 * 渲染同一分区内的一组路由按钮。
 *
 * @param destinations 当前分区包含的路由集合。
 * @param currentRoute 当前选中的路由。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param navigateOnFocus 是否在组内焦点移动时直接切换路由。
 * @param onNavigate 顶部标签点击后的跳转回调。
 */
@Composable
private fun TvDestinationGroup(
    destinations: List<TvDestination>,
    currentRoute: String?,
    contentFocusRequester: FocusRequester,
    topDestinationFocusRequesters: Map<String, FocusRequester>,
    horizontalSpacing: androidx.compose.ui.unit.Dp = 10.dp,
    navigateOnFocus: Boolean,
    onNavigate: (TvDestination) -> Unit,
    onFilterToggle: () -> Unit = {},
) {
    var hasGroupFocus by remember { mutableStateOf(false) }
    var pendingInternalFocusRoute by remember { mutableStateOf<String?>(null) }
    val activePillFocusRequester = currentRoute?.let { topDestinationFocusRequesters[it] }

    fun moveFocusInsideGroup(targetDestination: TvDestination?) {
        val targetFocusRequester = targetDestination
            ?.let { destination -> topDestinationFocusRequesters[destination.route] }
            ?: return

        // 左右键明确标记为组内移动，避免目标 tab 获焦后被外部进入逻辑拉回当前 tab。
        pendingInternalFocusRoute = targetDestination.route
        hasGroupFocus = true
        targetFocusRequester.requestFocus()
    }

    Row(
        modifier = Modifier.onFocusChanged { focusState ->
            if (!focusState.hasFocus) {
                // 离开整组后重置状态，下一次从内容区进入时不误触发切页。
                hasGroupFocus = false
            }
        },
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
                contentFocusRequester = contentFocusRequester,
                focusRequester = topDestinationFocusRequesters[destination.route],
                onFocused = {
                    val isPendingInternalMove = pendingInternalFocusRoute == destination.route
                    val movingInsideGroup = hasGroupFocus || isPendingInternalMove
                    if (isPendingInternalMove) {
                        // 本次左右键落焦已消费，后续外部进入仍需要走选中项重定向。
                        pendingInternalFocusRoute = null
                    }
                    if (!movingInsideGroup && !isSelected && activePillFocusRequester != null) {
                        // 从内容区上来的焦点落到非当前 tab 时，重定向到选中 tab，
                        // 确保下键始终回到正确的内容区位置。
                        activePillFocusRequester.requestFocus()
                    } else {
                        // Flutter TV 主菜单左右移动时焦点即切页；快捷入口仍保持确认键进入。
                        if (navigateOnFocus && movingInsideGroup && !isSelected) {
                            onNavigate(destination)
                        }
                        hasGroupFocus = true
                    }
                },
                onClick = { onNavigate(destination) },
                onMoveLeft = { moveFocusInsideGroup(previousDestination) },
                onMoveRight = { moveFocusInsideGroup(nextDestination) },
                onFilterToggle = onFilterToggle,
            )
        }
    }
}

/**
 * TV 顶部导航胶囊按钮。
 *
 * @param label 按钮文案。
 * @param selected 是否为当前路由。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param onFocused 焦点进入按钮时的回调。
 * @param onClick 点击后的跳转回调。
 * @param onMoveLeft 左键移动到组内上一个按钮。
 * @param onMoveRight 右键移动到组内下一个按钮。
 */
@Composable
private fun TvNavigationPill(
    label: String,
    iconGlyph: String?,
    selected: Boolean,
    contentFocusRequester: FocusRequester,
    focusRequester: FocusRequester?,
    onFocused: () -> Unit,
    onClick: () -> Unit,
    onMoveLeft: () -> Unit,
    onMoveRight: () -> Unit,
    onFilterToggle: () -> Unit = {},
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val pressPolicy = remember { TvRemotePressPolicy(hasLongPressHandler = false) }
    val shape = RoundedCornerShape(TvTokens.TopActionRadius)
    val backgroundColor = when {
        selected -> TvTokens.FocusFill
        isFocused -> TvTokens.FocusFill
        else -> TvTokens.Surface
    }

    Box(
        modifier = Modifier
            .height(TvTokens.TopActionHeight)
            .clip(shape)
            .background(backgroundColor)
            .border(
                width = 2.dp,
                color = if (isFocused) TvTokens.FocusBorder else Color.Transparent,
                shape = shape,
            )
            .focusProperties {
                // 向下焦点目标交给 Compose 默认搜索，避免遥控器只在顶部导航区域循环。
                down = contentFocusRequester
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
                if (event.key == Key.DirectionLeft || event.key == Key.DirectionRight) {
                    if (event.type == KeyEventType.KeyDown) {
                        // 顶部导航左右键使用显式相邻目标，避免默认几何搜索被重定向逻辑抵消。
                        if (event.key == Key.DirectionLeft) {
                            onMoveLeft()
                        } else {
                            onMoveRight()
                        }
                    }
                    return@onPreviewKeyEvent true
                }
                if (event.key != Key.DirectionCenter && event.key != Key.Enter) {
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
                    // 已选中分类 tab 的确认键切换筛选面板；未选中的保持导航行为。
                    if (selected) {
                        onFilterToggle()
                    } else {
                        onClick()
                    }
                }
                true
            }
            .onFocusChanged { focusState ->
                if (focusState.isFocused) {
                    // 顶部主菜单需要复刻 Flutter TV 的焦点即切换交互。
                    onFocused()
                }
            }
            .pointerInput(onClick) {
                detectTapGestures(
                    onTap = {
                        // 鼠标和触摸点击不再依赖 clickable，避免生成额外焦点节点。
                        onClick()
                    },
                )
            }
            .focusable(interactionSource = interactionSource)
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
                        fontSize = 19.sp,
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
                color = if (selected || isFocused) Color.White else TvTokens.TextPrimary,
            )
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
