package org.moontechlab.selene.core.network

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DemoSeleneApiTest {

    @Test
    fun `search returns server aggregated cards`() = runTest {
        val api = DemoSeleneApi()

        val results = api.search("三体")

        assertEquals(1, results.size)
        assertEquals("video-santi-server", results.first().id)
        assertEquals("Selene 聚合", results.first().sourceName)
    }

    @Test
    fun `detail returns server detail entry`() = runTest {
        val api = DemoSeleneApi()

        val detail = api.fetchDetail("video-santi-server")

        assertEquals("video-santi-server", detail.id)
        assertEquals(2, detail.episodes.size)
        assertTrue(detail.description.contains("服务器"))
    }
}
