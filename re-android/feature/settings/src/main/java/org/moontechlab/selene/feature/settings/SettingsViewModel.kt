package org.moontechlab.selene.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.datastore.AppPreferences
import org.moontechlab.selene.core.datastore.AppPreferencesRepository

data class SettingsUiState(
    val darkTheme: Boolean = false,
    val isLocalMode: Boolean = false,
    val showLive: Boolean = true,
    val showSourceBrowser: Boolean = true,
)

class SettingsViewModel(
    private val repository: AppPreferencesRepository = AppPreferencesRepository(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(SettingsUiState())

    val uiState: StateFlow<SettingsUiState> = state.asStateFlow()

    init {
        viewModelScope.launch(dispatchers.main) {
            repository.preferences.collect { preferences ->
                state.value = preferences.toUiState()
            }
        }
    }

    fun toggleDarkTheme() = updatePreferences { copy(darkTheme = !darkTheme) }

    fun toggleLocalMode() = updatePreferences { copy(isLocalMode = !isLocalMode) }

    fun toggleLiveVisibility() = updatePreferences { copy(showLive = !showLive) }

    fun toggleSourceBrowserVisibility() = updatePreferences { copy(showSourceBrowser = !showSourceBrowser) }

    private fun updatePreferences(transform: AppPreferences.() -> AppPreferences) {
        viewModelScope.launch(dispatchers.io) {
            repository.update { preferences -> preferences.transform() }
        }
    }

    private fun AppPreferences.toUiState(): SettingsUiState = SettingsUiState(
        darkTheme = darkTheme,
        isLocalMode = isLocalMode,
        showLive = showLive,
        showSourceBrowser = showSourceBrowser,
    )
}
