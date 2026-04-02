package org.moontechlab.selene.core.network

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CookieSessionStoreTest {

    @Test
    fun `save persists base url cookie and local mode flag`() = runTest {
        val store = CookieSessionStore()

        store.save(
            baseUrl = "https://demo.example.com",
            cookie = "auth=abc",
            isLocalMode = true,
        )

        val session = store.currentSession()
        assertEquals("https://demo.example.com", session?.baseUrl)
        assertEquals("auth=abc", session?.cookie)
        assertTrue(session?.isLocalMode == true)
    }

    @Test
    fun `clear removes active session`() = runTest {
        val store = CookieSessionStore()
        store.save(
            baseUrl = "https://demo.example.com",
            cookie = "auth=abc",
            isLocalMode = false,
        )

        store.clear()

        assertNull(store.currentSession())
        assertFalse(store.hasValidSession())
    }

    @Test
    fun `store restores session from persistence on creation`() = runTest {
        val store = CookieSessionStore(
            persistence = FakeSessionPersistence(
                session = CookieSession(
                    baseUrl = "https://demo.example.com",
                    cookie = "auth=restored",
                    isLocalMode = false,
                ),
            ),
        )

        val session = store.currentSession()

        assertEquals("https://demo.example.com", session?.baseUrl)
        assertEquals("auth=restored", session?.cookie)
        assertFalse(session?.isLocalMode ?: true)
    }

    @Test
    fun `save and clear synchronize persistence`() = runTest {
        val persistence = FakeSessionPersistence()
        val store = CookieSessionStore(persistence = persistence)

        store.save(
            baseUrl = "https://demo.example.com",
            cookie = "auth=abc",
            isLocalMode = false,
        )
        assertEquals("auth=abc", persistence.session?.cookie)

        store.clear()

        assertNull(persistence.session)
    }
}

private class FakeSessionPersistence(
    var session: CookieSession? = null,
) : SessionPersistence {
    override fun restore(): CookieSession? = session

    override fun persist(session: CookieSession?) {
        this.session = session
    }
}
