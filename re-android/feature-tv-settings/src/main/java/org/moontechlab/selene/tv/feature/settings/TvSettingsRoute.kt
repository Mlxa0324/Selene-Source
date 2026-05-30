package org.moontechlab.selene.tv.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * TV 设置路由。
 *
 * @param state 设置界面状态。
 */
@Composable
fun TvSettingsRoute(
    state: TvSettingsUiState = TvSettingsUiState(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(36.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "设置",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(text = "服务器：${state.serverUrl}")
        Text(text = "账号：${state.account}")
        Text(text = "弹幕：${if (state.danmakuEnabled) "开启" else "关闭"}")
    }
}
