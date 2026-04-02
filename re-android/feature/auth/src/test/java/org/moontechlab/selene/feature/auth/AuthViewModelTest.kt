package org.moontechlab.selene.feature.auth

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.network.CookieSessionStore
import org.moontechlab.selene.core.network.CookieSession
import org.moontechlab.selene.core.network.SessionAuthApi

@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {

    @Test
    fun `server mode submit stores cookie session and marks login complete`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val store = CookieSessionStore()
        val viewModel = AuthViewModel(
            sessionStore = store,
            authApi = FakeSessionAuthApi(cookie = "auth=server-token"),
            dispatchers = AuthTestDispatchers(dispatcher),
        )

        viewModel.updateServerUrl("https://demo.example.com")
        viewModel.updateUsername("demo")
        viewModel.updatePassword("secret")
        viewModel.submit()
        advanceUntilIdle()

        val session = store.currentSession()
        assertEquals("https://demo.example.com", session?.baseUrl)
        assertEquals("auth=server-token", session?.cookie)
        assertFalse(session?.isLocalMode ?: true)
        assertTrue(viewModel.uiState.value.loginCompleted)
        assertNull(viewModel.uiState.value.errorMessage)
    }

    @Test
    fun `local mode submit stores local session and marks login complete`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val store = CookieSessionStore()
        val viewModel = AuthViewModel(
            sessionStore = store,
            dispatchers = AuthTestDispatchers(dispatcher),
        )

        viewModel.updateLocalMode(true)
        viewModel.updateSubscriptionUrl("https://demo.example.com/subscription.txt")
        viewModel.submit()
        advanceUntilIdle()

        val session = store.currentSession()
        assertEquals("https://demo.example.com/subscription.txt", session?.baseUrl)
        assertEquals("local-mode", session?.cookie)
        assertTrue(session?.isLocalMode == true)
        assertTrue(viewModel.uiState.value.loginCompleted)
        assertNull(viewModel.uiState.value.errorMessage)
    }

    @Test
    fun `server mode submit surfaces auth error and keeps session empty`() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val store = CookieSessionStore()
        val viewModel = AuthViewModel(
            sessionStore = store,
            authApi = FakeSessionAuthApi(failure = IllegalStateException("login failed")),
            dispatchers = AuthTestDispatchers(dispatcher),
        )

        viewModel.updateServerUrl("https://demo.example.com")
        viewModel.updateUsername("demo")
        viewModel.updatePassword("secret")
        viewModel.submit()
        advanceUntilIdle()

        assertNull(store.currentSession())
        assertFalse(viewModel.uiState.value.loginCompleted)
        assertFalse(viewModel.uiState.value.isSubmitting)
        assertEquals("login failed", viewModel.uiState.value.errorMessage)
    }
}

private class AuthTestDispatchers(
    private val dispatcher: TestDispatcher,
) : CoroutineDispatchers {
    override val io = dispatcher
    override val default = dispatcher
    override val main = dispatcher
}

private class FakeSessionAuthApi(
    private val cookie: String = "auth=test-token",
    private val failure: Throwable? = null,
) : SessionAuthApi {
    override suspend fun login(baseUrl: String, username: String, password: String): CookieSession {
        failure?.let { throw it }
        return CookieSession(
            baseUrl = baseUrl,
            cookie = cookie,
            isLocalMode = false,
        )
    }

    override suspend fun validateSession(session: CookieSession): Boolean = true
}
