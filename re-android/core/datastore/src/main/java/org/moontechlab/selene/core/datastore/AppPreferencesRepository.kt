package org.moontechlab.selene.core.datastore

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class AppPreferences(
    val darkTheme: Boolean = false,
    val isLocalMode: Boolean = false,
    val showLive: Boolean = true,
    val showSourceBrowser: Boolean = true,
)

interface AppPreferencesPersistence {
    fun restore(): AppPreferences
    fun persist(preferences: AppPreferences)
}

private object NoOpAppPreferencesPersistence : AppPreferencesPersistence {
    override fun restore(): AppPreferences = AppPreferences()

    override fun persist(preferences: AppPreferences) = Unit
}

class SharedPreferencesAppPreferencesPersistence(
    private val sharedPreferences: SharedPreferences,
) : AppPreferencesPersistence {
    override fun restore(): AppPreferences {
        return AppPreferences(
            darkTheme = sharedPreferences.getBoolean(KEY_DARK_THEME, false),
            isLocalMode = sharedPreferences.getBoolean(KEY_LOCAL_MODE, false),
            showLive = sharedPreferences.getBoolean(KEY_SHOW_LIVE, true),
            showSourceBrowser = sharedPreferences.getBoolean(KEY_SHOW_SOURCE_BROWSER, true),
        )
    }

    override fun persist(preferences: AppPreferences) {
        sharedPreferences.edit()
            .putBoolean(KEY_DARK_THEME, preferences.darkTheme)
            .putBoolean(KEY_LOCAL_MODE, preferences.isLocalMode)
            .putBoolean(KEY_SHOW_LIVE, preferences.showLive)
            .putBoolean(KEY_SHOW_SOURCE_BROWSER, preferences.showSourceBrowser)
            .apply()
    }

    companion object {
        private const val PREFERENCES_NAME = "selene_preferences"
        private const val KEY_DARK_THEME = "dark_theme"
        private const val KEY_LOCAL_MODE = "local_mode"
        private const val KEY_SHOW_LIVE = "show_live"
        private const val KEY_SHOW_SOURCE_BROWSER = "show_source_browser"

        fun fromContext(context: Context): SharedPreferencesAppPreferencesPersistence {
            val sharedPreferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            return SharedPreferencesAppPreferencesPersistence(sharedPreferences = sharedPreferences)
        }
    }
}

class AppPreferencesRepository(
    private val persistence: AppPreferencesPersistence = NoOpAppPreferencesPersistence,
) {
    private val preferencesState = MutableStateFlow(persistence.restore())

    val preferences: StateFlow<AppPreferences> = preferencesState.asStateFlow()

    suspend fun update(transform: (AppPreferences) -> AppPreferences) {
        preferencesState.value = transform(preferencesState.value)
        persistence.persist(preferencesState.value)
    }
}
