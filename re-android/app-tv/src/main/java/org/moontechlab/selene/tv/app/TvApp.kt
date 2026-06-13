package org.moontechlab.selene.tv.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
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
import androidx.compose.ui.graphics.Color
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
import java.time.LocalTime
import java.time.format.DateTimeFormatter

/**
 * 组装 TV 原生工程的 Compose 根节点。
 */
@Composable
fun TvApp() {
    SeleneTvTheme {
        val navController = rememberNavController()
        val appContainer = remember {
            TvAppContainer(
                gatewayConfig = TvLocalGatewayConfig.fromBuildConfig(),
            )
        }
        val currentBackStackEntry by navController.currentBackStackEntryAsState()
        val currentRoute = currentBackStackEntry?.destination?.route

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background),
        ) {
            if (currentRoute != TvDestination.Player.route) {
                // 顶级导航只在普通页面展示，播放器页独占全屏。
                TvTopNavigationBar(
                    currentRoute = currentRoute,
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
                )
            }

            TvNavGraph(
                navController = navController,
                appContainer = appContainer,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

/**
 * 渲染对齐 Flutter TV 的顶部导航。
 *
 * @param currentRoute 当前选中的路由。
 * @param onNavigate 顶部入口点击后的跳转回调。
 */
@Composable
private fun TvTopNavigationBar(
    currentRoute: String?,
    onNavigate: (TvDestination) -> Unit,
) {
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
                horizontalSpacing = 10.dp,
                onNavigate = onNavigate,
            )

            Spacer(modifier = Modifier.width(24.dp))

            TvClockText()
        }

        TvDestinationGroup(
            destinations = TvDestination.primaryMenuDestinations,
            currentRoute = currentRoute,
            horizontalSpacing = 12.dp,
            onNavigate = onNavigate,
        )
    }
}

/**
 * 渲染同一分区内的一组路由按钮。
 *
 * @param destinations 当前分区包含的路由集合。
 * @param currentRoute 当前选中的路由。
 * @param onNavigate 顶部标签点击后的跳转回调。
 */
@Composable
private fun TvDestinationGroup(
    destinations: List<TvDestination>,
    currentRoute: String?,
    horizontalSpacing: androidx.compose.ui.unit.Dp = 10.dp,
    onNavigate: (TvDestination) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        destinations.forEach { destination ->
            val isSelected = destination.route == currentRoute
            TvNavigationPill(
                label = destination.label,
                iconGlyph = destination.iconGlyph,
                selected = isSelected,
                onClick = { onNavigate(destination) },
            )
        }
    }
}

/**
 * TV 顶部导航胶囊按钮。
 *
 * @param label 按钮文案。
 * @param selected 是否为当前路由。
 * @param onClick 点击后的跳转回调。
 */
@Composable
private fun TvNavigationPill(
    label: String,
    iconGlyph: String?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(
        if (selected || isFocused) TvTokens.TopActionRadius else TvTokens.CardRadius,
    )
    val backgroundColor = when {
        selected -> TvTokens.Accent
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
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
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
