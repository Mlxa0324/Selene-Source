package org.moontechlab.selene.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun SettingsRoute(
    state: SettingsUiState,
    onToggleDarkTheme: () -> Unit,
    onToggleLocalMode: () -> Unit,
    onToggleLiveVisibility: () -> Unit,
    onToggleSourceBrowserVisibility: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenHistory: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(text = "我的与设置", style = MaterialTheme.typography.headlineSmall)
        SettingRow(title = "深色主题", checked = state.darkTheme, onCheckedChange = onToggleDarkTheme)
        SettingRow(title = "本地模式", checked = state.isLocalMode, onCheckedChange = onToggleLocalMode)
        SettingRow(title = "显示直播 Tab", checked = state.showLive, onCheckedChange = onToggleLiveVisibility)
        SettingRow(
            title = "显示资源站 Tab",
            checked = state.showSourceBrowser,
            onCheckedChange = onToggleSourceBrowserVisibility,
        )
        Button(onClick = onOpenFavorites) {
            Text("打开收藏")
        }
        Button(onClick = onOpenHistory) {
            Text("打开历史记录")
        }
    }
}

@Composable
private fun SettingRow(
    title: String,
    checked: Boolean,
    onCheckedChange: () -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        horizontalArrangement = Arrangement.SpaceBetween,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(text = title, style = MaterialTheme.typography.titleMedium)
        Switch(checked = checked, onCheckedChange = { onCheckedChange() })
    }
}
