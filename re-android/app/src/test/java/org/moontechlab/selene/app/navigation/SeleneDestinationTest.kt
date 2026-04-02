package org.moontechlab.selene.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SeleneDestinationTest {

    @Test
    fun `top level destinations expose stable routes`() {
        assertEquals("home", SeleneDestination.Home.route)
        assertEquals("search", SeleneDestination.Search.route)
        assertEquals("live", SeleneDestination.Live.route)
        assertEquals("resource", SeleneDestination.Resource.route)
        assertEquals("download", SeleneDestination.Download.route)
        assertEquals("profile", SeleneDestination.Profile.route)
    }

    @Test
    fun `benchmark route exists but stays hidden from default bottom navigation`() {
        val allRoutes = SeleneDestination.topLevelDestinations.map { it.route }
        assertTrue(allRoutes.contains("benchmark"))

        val bottomRoutes = SeleneDestination.defaultBottomNavDestinations.map { it.route }
        assertFalse(bottomRoutes.contains("benchmark"))
    }

    @Test
    fun `supporting routes are stable and parameter builders encode payloads`() {
        assertEquals("startup", SeleneDestination.Startup.route)
        assertEquals("auth", SeleneDestination.Auth.route)
        assertEquals("favorites", SeleneDestination.Favorites.route)
        assertEquals("history", SeleneDestination.History.route)
        assertEquals("detail/{videoId}?sourceKey={sourceKey}", SeleneDestination.Detail.route)
        assertEquals(
            "detail/video-001?sourceKey=ffm3u8",
            SeleneDestination.Detail.createRoute(
                videoId = "video-001",
                sourceKey = "ffm3u8",
            ),
        )
        assertEquals(
            "player/{videoId}/{title}/{sourceKey}/{sourceName}/{episodeTitle}/{playUrl}",
            SeleneDestination.Player.route,
        )
        assertEquals(
            "player/video-001/%E4%B8%89%E4%BD%93/ffm3u8/%E9%9D%9E%E5%87%A1%E5%BD%B1%E8%A7%86/%E7%AC%AC1%E9%9B%86/https%3A%2F%2Fexample.com%2Fdemo.m3u8",
            SeleneDestination.Player.createRoute(
                videoId = "video-001",
                title = "三体",
                sourceKey = "ffm3u8",
                sourceName = "非凡影视",
                episodeTitle = "第1集",
                playUrl = "https://example.com/demo.m3u8",
            ),
        )
    }
}
