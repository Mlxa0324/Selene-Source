package org.moontechlab.selene.feature.settings

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.datastore.AppPreferencesRepository
import org.moontechlab.selene.core.datastore.AppPreferences
import org.moontechlab.selene.core.datastore.AppPreferencesPersistence

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    @Test
    fun `toggle actions persist updated preferences`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val repository = AppPreferencesRepository()
        val viewModel = SettingsViewModel(
            repository = repository,
            dispatchers = SettingsTestDispatchers(dispatcher),
        )

        advanceUntilIdle()
        assertFalse(viewModel.uiState.value.darkTheme)
        assertTrue(viewModel.uiState.value.showLive)

        viewModel.toggleDarkTheme()
        viewModel.toggleLiveVisibility()
        viewModel.toggleSourceBrowserVisibility()
        advanceUntilIdle()

        assertTrue(viewModel.uiState.value.darkTheme)
        assertFalse(viewModel.uiState.value.showLive)
        assertFalse(viewModel.uiState.value.showSourceBrowser)
    }

    @Test
    fun `repository restores persisted preferences on startup`() = runTest {
        val repository = AppPreferencesRepository(
            persistence = FakeAppPreferencesPersistence(
                preferences = AppPreferences(
                    darkTheme = true,
                    showLive = false,
                    showSourceBrowser = false,
                ),
            ),
        )

        assertTrue(repository.preferences.value.darkTheme)
        assertFalse(repository.preferences.value.showLive)
        assertFalse(repository.preferences.value.showSourceBrowser)
    }
}

private class SettingsTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}

private class FakeAppPreferencesPersistence(
    var preferences: AppPreferences = AppPreferences(),
) : AppPreferencesPersistence {
    override fun restore(): AppPreferences = preferences

    override fun persist(preferences: AppPreferences) {
        this.preferences = preferences
    }
}
