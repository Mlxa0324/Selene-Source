package org.moontechlab.selene.feature.startup

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.network.CookieSessionStore

enum class StartupDestination {
    Splash,
    Home,
    Auth,
}

data class StartupUiState(
    val destination: StartupDestination = StartupDestination.Splash,
)

fun interface AuthGateway {
    suspend fun autoLogin(): Boolean
}

class StartupViewModel(
    private val sessionStore: CookieSessionStore,
    private val authGateway: AuthGateway,
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.io)
    private val mutableUiState = MutableStateFlow(StartupUiState())
    val uiState: StateFlow<StartupUiState> = mutableUiState.asStateFlow()

    init {
        scope.launch {
            val session = sessionStore.currentSession()
            val destination = when {
                session == null -> StartupDestination.Auth
                session.isLocalMode -> StartupDestination.Home
                sessionStore.hasValidSession() && authGateway.autoLogin() -> StartupDestination.Home
                else -> {
                    sessionStore.clear()
                    StartupDestination.Auth
                }
            }
            mutableUiState.value = StartupUiState(destination = destination)
        }
    }

    override fun onCleared() {
        super.onCleared()
        scope.cancel()
    }
}
