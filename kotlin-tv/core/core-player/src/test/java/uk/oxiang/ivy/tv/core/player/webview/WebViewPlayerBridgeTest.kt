package uk.oxiang.ivy.tv.core.player.webview

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 WebView 播放事件桥接契约。
 */
class WebViewPlayerBridgeTest {
    /**
     * JS 上报的播放事件需要映射为原生可读状态。
     */
    @Test
    fun onPlaybackEvent_maps_js_payload_to_player_state() {
        val bridge = WebViewPlayerBridge()

        val state = bridge.mapEvent(
            """
            {
              "positionMs": 1200,
              "durationMs": 2400,
              "isPlaying": true,
              "networkSpeedBytesPerSecond": 512000,
              "cachedRanges": [
                {"startMs": 1000, "endMs": 2000},
                {"startMs": 2200, "endMs": 2400}
              ]
            }
            """.trimIndent(),
        )

        assertThat(state.positionMs).isEqualTo(1_200L)
        assertThat(state.durationMs).isEqualTo(2_400L)
        assertThat(state.isPlaying).isTrue()
        assertThat(state.networkSpeedBytesPerSecond).isEqualTo(512_000L)
        assertThat(state.cachedRanges).containsExactly(
            WebViewCachedRange(startMs = 1_000L, endMs = 2_000L),
            WebViewCachedRange(startMs = 2_200L, endMs = 2_400L),
        ).inOrder()
    }
}
