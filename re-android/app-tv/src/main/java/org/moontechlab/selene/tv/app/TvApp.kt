package org.moontechlab.selene.tv.app

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import org.moontechlab.selene.tv.app.navigation.TvDestination
import org.moontechlab.selene.tv.app.navigation.TvNavGraph

/**
 * 组装 TV 原生工程的 Compose 根节点。
 */
@Composable
fun TvApp() {
    val navController = rememberNavController()
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = currentBackStackEntry?.destination?.route

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
        ) {
            if (currentRoute != TvDestination.Player.route) {
                // 顶级导航只在普通页面展示，播放器页独占全屏。
                TvTopLevelTabs(
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
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

/**
 * 渲染 TV 顶级导航占位壳。
 *
 * @param currentRoute 当前选中的路由。
 * @param onNavigate 顶部标签点击后的跳转回调。
 */
@Composable
private fun TvTopLevelTabs(
    currentRoute: String?,
    onNavigate: (TvDestination) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TvDestination.topLevelDestinations.forEach { destination ->
            val isSelected = destination.route == currentRoute
            TextButton(
                onClick = { onNavigate(destination) },
            ) {
                val label = if (isSelected) {
                    "[${destination.route}]"
                } else {
                    destination.route
                }
                Text(text = label)
            }
        }
    }
}
