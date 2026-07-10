package org.moontechlab.selene.tv.core.player.webview

import com.google.common.truth.Truth.assertThat
import java.io.File
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

    /**
     * Android 13/BlueStacks 的 ICU 正则实现会把 `\{` 视为非法量词起始，
     * 因此 cachedRanges 解析不能继续依赖花括号字面量正则。
     */
    @Test
    fun cached_ranges_parser_uses_json_structure_instead_of_curly_brace_regex() {
        val source = readBridgeSource()

        assertThat(source).contains("JsonParser.parseString(payload)")
        assertThat(source).contains("getAsJsonArray(\"cachedRanges\")")
        assertThat(source).doesNotContain("\\\\{\\\\s*\\\\\\\"startMs\\\\\\\"")
    }

    /**
     * 读取桥接器源码，用于锁定 Android 运行时兼容实现。
     *
     * @return 当前桥接器源码文本。
     */
    private fun readBridgeSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/player/webview/WebViewPlayerBridge.kt")
            .readText()
    }
}
