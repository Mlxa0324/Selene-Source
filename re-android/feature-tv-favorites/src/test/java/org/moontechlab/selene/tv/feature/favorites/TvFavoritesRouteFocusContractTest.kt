package org.moontechlab.selene.tv.feature.favorites

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 收藏夹页面焦点契约。
 */
class TvFavoritesRouteFocusContractTest {
    /**
     * 收藏夹加载、空态和错误态必须承接顶部导航下探入口。
     */
    @Test
    fun loading_empty_and_error_states_attach_content_focus_requester() {
        val source = readRouteSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("TvPosterGridSkeleton(contentFocusRequester = contentFocusRequester)")
        assertThat(source).contains("contentFocusRequester = contentFocusRequester")
        assertThat(source).contains("firstItemFocusRequester = contentFocusRequester")
    }

    /**
     * 读取收藏夹路由源码。
     *
     * @return 当前 TvFavoritesRoute 源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/favorites/TvFavoritesRoute.kt")
            .readText()
    }
}
