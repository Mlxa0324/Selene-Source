package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 手机扫码草稿解析契约。
 */
class TvMobileSettingsBridgeTest {
    @Test
    fun fromFormFields_normalizes_image_source_and_bool() {
        val draft = TvMobileSettingsDraft.fromFormFields(
            mapOf(
                "serverUrl" to " http://tv.local ",
                "username" to " admin ",
                "password" to "secret",
                "doubanImageSource" to "直连",
                "adFilterEnabled" to "on",
                "danmakuBaseApi" to " https://dm.example ",
            ),
        )

        assertThat(draft.serverUrl).isEqualTo("http://tv.local")
        assertThat(draft.username).isEqualTo("admin")
        assertThat(draft.password).isEqualTo("secret")
        assertThat(draft.doubanImageSource).isEqualTo("直连")
        assertThat(draft.adFilterEnabled).isTrue()
        assertThat(draft.danmakuBaseApi).isEqualTo("https://dm.example")
    }

    @Test
    fun fromFormFields_falls_back_unknown_image_source() {
        val draft = TvMobileSettingsDraft.fromFormFields(
            mapOf("doubanImageSource" to "unknown-proxy"),
        )
        assertThat(draft.doubanImageSource).isEqualTo(TvMobileSettingsDraft.DEFAULT_IMAGE_SOURCE)
    }
}
