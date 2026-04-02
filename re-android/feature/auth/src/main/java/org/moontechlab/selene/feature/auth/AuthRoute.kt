package org.moontechlab.selene.feature.auth

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun AuthRoute(
    state: AuthUiState,
    onLocalModeChanged: (Boolean) -> Unit,
    onServerUrlChanged: (String) -> Unit,
    onUsernameChanged: (String) -> Unit,
    onPasswordChanged: (String) -> Unit,
    onSubscriptionUrlChanged: (String) -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = "Selene 登录")
        Spacer(modifier = Modifier.height(16.dp))
        Text(text = if (state.isLocalMode) "本地模式" else "服务器模式")
        Spacer(modifier = Modifier.height(12.dp))
        Switch(
            checked = state.isLocalMode,
            onCheckedChange = onLocalModeChanged,
        )
        Spacer(modifier = Modifier.height(16.dp))
        if (state.isLocalMode) {
            OutlinedTextField(
                value = state.subscriptionUrl,
                onValueChange = onSubscriptionUrlChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("订阅地址") },
                singleLine = true,
            )
        } else {
            OutlinedTextField(
                value = state.serverUrl,
                onValueChange = onServerUrlChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("服务器地址") },
                singleLine = true,
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.username,
                onValueChange = onUsernameChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("用户名") },
                singleLine = true,
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = state.password,
                onValueChange = onPasswordChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("密码") },
                singleLine = true,
            )
        }
        Spacer(modifier = Modifier.height(16.dp))
        state.errorMessage?.takeIf { it.isNotBlank() }?.let { message ->
            Text(
                text = message,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(12.dp))
        }
        Button(
            onClick = onSubmit,
            enabled = state.canSubmit,
        ) {
            Text(if (state.isSubmitting) "登录中..." else "进入 Selene")
        }
    }
}
