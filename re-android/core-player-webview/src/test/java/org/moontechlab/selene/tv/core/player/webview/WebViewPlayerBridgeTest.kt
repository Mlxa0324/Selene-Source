package org.moontechlab.selene.tv.core.player.webview

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

        val state = bridge.mapEvent("""{"positionMs":1200,"durationMs":2400,"isPlaying":true}""")

        assertThat(state.positionMs).isEqualTo(1_200L)
        assertThat(state.durationMs).isEqualTo(2_400L)
        assertThat(state.isPlaying).isTrue()
    }
}
