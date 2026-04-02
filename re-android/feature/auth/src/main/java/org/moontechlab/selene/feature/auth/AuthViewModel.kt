package org.moontechlab.selene.feature.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.DemoSessionAuthApi
import org.moontechlab.selene.core.network.SessionAuthApi

data class AuthUiState(
    val serverUrl: String = "",
    val username: String = "",
    val password: String = "",
    val subscriptionUrl: String = "",
    val isLocalMode: Boolean = false,
    val isSubmitting: Boolean = false,
    val loginCompleted: Boolean = false,
    val errorMessage: String? = null,
) {
    val canSubmit: Boolean
        get() = if (isLocalMode) {
            subscriptionUrl.isNotBlank() && !isSubmitting
        } else {
            serverUrl.isNotBlank() && username.isNotBlank() && password.isNotBlank() && !isSubmitting
        }
}

class AuthViewModel(
    private val sessionStore: CookieSessionStore = CookieSessionStore(),
    private val authApi: SessionAuthApi = DemoSessionAuthApi(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val mutableUiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = mutableUiState.asStateFlow()

    fun updateLocalMode(enabled: Boolean) {
        mutableUiState.value = mutableUiState.value.copy(
            isLocalMode = enabled,
            loginCompleted = false,
            errorMessage = null,
        )
    }

    fun updateServerUrl(value: String) {
        mutableUiState.value = mutableUiState.value.copy(serverUrl = value, loginCompleted = false, errorMessage = null)
    }

    fun updateUsername(value: String) {
        mutableUiState.value = mutableUiState.value.copy(username = value, loginCompleted = false, errorMessage = null)
    }

    fun updatePassword(value: String) {
        mutableUiState.value = mutableUiState.value.copy(password = value, loginCompleted = false, errorMessage = null)
    }

    fun updateSubscriptionUrl(value: String) {
        mutableUiState.value = mutableUiState.value.copy(subscriptionUrl = value, loginCompleted = false, errorMessage = null)
    }

    fun submit() {
        val state = mutableUiState.value
        if (!state.canSubmit) return

        mutableUiState.value = state.copy(isSubmitting = true, loginCompleted = false, errorMessage = null)
        viewModelScope.launch(dispatchers.io) {
            runCatching {
                if (state.isLocalMode) {
                    sessionStore.save(
                        baseUrl = state.subscriptionUrl,
                        cookie = "local-mode",
                        isLocalMode = true,
                    )
                } else {
                    val session = authApi.login(
                        baseUrl = state.serverUrl,
                        username = state.username,
                        password = state.password,
                    )
                    sessionStore.save(
                        baseUrl = session.baseUrl,
                        cookie = session.cookie,
                        isLocalMode = false,
                    )
                }
            }.onSuccess {
                mutableUiState.value = mutableUiState.value.copy(
                    isSubmitting = false,
                    loginCompleted = true,
                    errorMessage = null,
                )
            }.onFailure { throwable ->
                mutableUiState.value = mutableUiState.value.copy(
                    isSubmitting = false,
                    loginCompleted = false,
                    errorMessage = throwable.message ?: "登录失败",
                )
            }
        }
    }

    fun consumeLoginCompleted() {
        mutableUiState.value = mutableUiState.value.copy(loginCompleted = false)
    }
}
