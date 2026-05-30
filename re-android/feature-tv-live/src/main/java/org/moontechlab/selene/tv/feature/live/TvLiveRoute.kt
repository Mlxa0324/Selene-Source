package org.moontechlab.selene.tv.feature.live

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

/**
 * TV 直播占位路由。
 */
@Composable
fun TvLiveRoute() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // 直播首期保持占位，避免误导用户以为已接入频道源。
        Text(
            text = "正在开发",
            style = MaterialTheme.typography.headlineMedium,
        )
    }
}
