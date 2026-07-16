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
        assertThat(source).contains("TvPosterGridSkeleton(contentFocusRequester = resolvedContentFocus)")
        assertThat(source).contains("contentFocusRequester = resolvedContentFocus")
        assertThat(source).contains("firstItemFocusRequester = resolvedContentFocus")
        // 紧凑页头随网格滚动 + 删除全部 + 公共确认框。
        assertThat(source).contains("TvScrollablePageHeader")
        assertThat(source).contains("headerContent")
        assertThat(source).contains("删除全部")
        assertThat(source).contains("TvConfirmDialog")
        assertThat(source).contains("onClearAll")
        assertThat(source).contains("onDeleteVideo")
        assertThat(source).contains("onItemLongClick")
        assertThat(source).contains("title = null")
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
