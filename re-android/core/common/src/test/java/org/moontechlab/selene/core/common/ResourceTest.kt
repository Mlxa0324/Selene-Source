package org.moontechlab.selene.core.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ResourceTest {

    @Test
    fun `loading exposes no data and preserves optional fallback value`() {
        val empty = Resource.Loading<String>()
        assertEquals(null, empty.data)

        val withData = Resource.Loading(data = "cached")
        assertEquals("cached", withData.data)
    }

    @Test
    fun `success exposes value payload`() {
        val success = Resource.Success(data = 42)

        assertEquals(42, success.data)
    }

    @Test
    fun `error preserves failure type and optional fallback data`() {
        val authError = Resource.Error(
            error = AppError.AuthExpired,
            data = "stale-session",
        )
        val networkError = Resource.Error<String>(
            error = AppError.Network(message = "timeout"),
        )

        assertTrue(authError.error is AppError.AuthExpired)
        assertEquals("stale-session", authError.data)
        assertTrue(networkError.error is AppError.Network)
    }
}
