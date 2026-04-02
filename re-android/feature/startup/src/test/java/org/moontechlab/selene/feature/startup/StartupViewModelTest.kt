package org.moontechlab.selene.feature.startup

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.network.CookieSessionStore

@OptIn(ExperimentalCoroutinesApi::class)
class StartupViewModelTest {

    @Test
    fun `local mode enters home immediately`() = runTest {
        val testDispatchers = TestCoroutineDispatchers(StandardTestDispatcher(testScheduler))
        val store = CookieSessionStore().apply {
            save(baseUrl = "", cookie = "", isLocalMode = true)
        }

        val viewModel = StartupViewModel(
            sessionStore = store,
            authGateway = FakeAuthGateway(autoLoginResult = false),
            dispatchers = testDispatchers,
        )

        advanceUntilIdle()

        assertEquals(StartupDestination.Home, viewModel.uiState.value.destination)
    }

    @Test
    fun `server mode with valid session enters home`() = runTest {
        val testDispatchers = TestCoroutineDispatchers(StandardTestDispatcher(testScheduler))
        val store = CookieSessionStore().apply {
            save(
                baseUrl = "https://demo.example.com",
                cookie = "auth=abc",
                isLocalMode = false,
            )
        }

        val viewModel = StartupViewModel(
            sessionStore = store,
            authGateway = FakeAuthGateway(autoLoginResult = true),
            dispatchers = testDispatchers,
        )

        advanceUntilIdle()

        assertEquals(StartupDestination.Home, viewModel.uiState.value.destination)
    }

    @Test
    fun `missing session or failed auto login enters auth`() = runTest {
        val testDispatchers = TestCoroutineDispatchers(StandardTestDispatcher(testScheduler))
        val store = CookieSessionStore()
        val viewModel = StartupViewModel(
            sessionStore = store,
            authGateway = FakeAuthGateway(autoLoginResult = false),
            dispatchers = testDispatchers,
        )

        advanceUntilIdle()

        assertEquals(StartupDestination.Auth, viewModel.uiState.value.destination)
    }

    @Test
    fun `failed remote auto login clears stale session`() = runTest {
        val testDispatchers = TestCoroutineDispatchers(StandardTestDispatcher(testScheduler))
        val store = CookieSessionStore().apply {
            save(
                baseUrl = "https://demo.example.com",
                cookie = "auth=expired",
                isLocalMode = false,
            )
        }

        val viewModel = StartupViewModel(
            sessionStore = store,
            authGateway = FakeAuthGateway(autoLoginResult = false),
            dispatchers = testDispatchers,
        )

        advanceUntilIdle()

        assertEquals(StartupDestination.Auth, viewModel.uiState.value.destination)
        assertEquals(null, store.currentSession())
    }
}

private class FakeAuthGateway(
    private val autoLoginResult: Boolean,
) : AuthGateway {
    override suspend fun autoLogin(): Boolean = autoLoginResult
}

private class TestCoroutineDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}
